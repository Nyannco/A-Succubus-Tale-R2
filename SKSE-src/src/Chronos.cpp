#include "PCH.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"

#include <atomic>
#include <chrono>
#include <cmath>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// ============================================================================
// 〔クロノス〕の実装です。設計と用語は Chronos.h に全部書いてあります。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・時刻マーカーは 〔SkyVault〕（holder=0・キー ASTR2_Chrono_*）＝コセーブでセーブごとに永続します。
//   ・〔門番〕（プレイヤーがセルに居る＝ロード済み）を通った時だけ時刻ジョブを動かします。
//   ・鼓動は当面 std::thread（Papyrus無し）です。将来はエンジン更新フックへの置換を検討しています。
//   ・RE::/〔SkyVault〕 操作は AddTask でゲームスレッドへ回します（他のC++と同じ流儀です）。
// ============================================================================

namespace Chronos
{
    namespace {
        constexpr int   kWakeMs        = 250;    // 鼓動の間隔です（実時間ミリ秒）。ジョブは申告した頻度でしか動きません
        constexpr float kDefaultTScale = 20.0f;  // タイムスケールが読めない時の保険です（バニラ既定）

        // ---- 永続マーカー（〔SkyVault〕 holder=0）----
        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }
        inline std::string LastKey(const std::string& n) { return "ASTR2_Chrono_last_" + n; } // 定期型＝最後に発火したゲーム内時刻です
        inline std::string AtKey(const std::string& n)   { return "ASTR2_Chrono_at_"   + n; } // 期限型＝発火する目標ゲーム内時刻です（-1=予約なし）

        // ① 定期型：マーカーは〔SkyVault〕側です。ここは間隔とfnと稼働フラグだけ持ちます。
        struct Interval {
            std::string name;
            float       hours   = 1.0f;
            bool        enabled = true;   // Start/Stopで切替（既定=有効＝従来ジョブは登録即稼働します）
            IntervalJob fn;
        };
        // ② 期限型：ハンドラfnだけ持ちます（目標時刻は〔SkyVault〕に永続します）。
        struct OneShot {
            std::string name;
            OneShotJob  fn;
        };
        // ③ 実時間くり返し型です（HUD専用）。
        struct Realtime {
            std::string name;
            float       every = 1.0f;
            float       acc   = 0.0f;
            RealtimeJob fn;
        };

        std::mutex            g_mutex;
        std::vector<Interval> g_intervals;
        std::vector<OneShot>  g_oneshots;
        std::vector<Realtime> g_realtimes;
        std::atomic<bool>     g_running{ false };

        // 定期型1件を評価します（g_mutexロック済みで呼びます）。発火するなら経過(>0)を返してマーカーを更新し、しなければ0を返します。
        //   ★ここでは fn を呼びません＝呼び出しはロックを外してから（ハンドラが〔クロノス〕を呼び返してもデッドロックしません）。
        //   a_forceNow=trueなら間隔未満でも溜まった分を出します。
        float EvalIntervalLocked(Interval& job, double now, bool a_forceNow) {
            auto* v = Vault();
            if (!v || job.hours <= 0.0f) return 0.0f;
            const std::string key = LastKey(job.name);
            const double last = static_cast<double>(v->GetFloat(0, key.c_str(), -1.0f));
            if (last < 0.0) {                                  // 未発火＝今を基準に置くだけです（catch-upしません）
                v->SetFloat(0, key.c_str(), static_cast<float>(now));
                return 0.0f;
            }
            if (now <= last) return 0.0f;                      // 時刻が進んでいない/巻き戻った＝何もしません
            if (!a_forceNow && (now - last) < job.hours) return 0.0f; // 間隔にまだ満たないので何もしません
            const float elapsed = static_cast<float>(now - last);
            v->SetFloat(0, key.c_str(), static_cast<float>(now));
            spdlog::info("[Chronos] {} 発火（経過{:.1f}h）", job.name, elapsed);
            return elapsed;
        }

        // 1周ぶんの処理です（ゲームスレッド）。
        void Tick() {
            // ---- ③ 実時間くり返し型＝〔門番〕の外（メニュー等でも回す・HUD用）----
            //   ★発火するfnはロック内で集めて、呼ぶのはロック外（ハンドラの〔クロノス〕呼び返しでデッドロックしません）。
            {
                using clock = std::chrono::steady_clock;
                static clock::time_point s_lastReal = clock::now();
                const auto nowReal = clock::now();
                const float dtReal = std::chrono::duration<float>(nowReal - s_lastReal).count();
                s_lastReal = nowReal;
                std::vector<RealtimeJob> due;
                {
                    std::lock_guard<std::mutex> lock(g_mutex);
                    for (auto& job : g_realtimes) {
                        if (job.every <= 0.0f) continue;
                        job.acc += dtReal;
                        if (job.acc < job.every) continue;
                        job.acc = 0.0f;
                        if (job.fn) due.push_back(job.fn);
                    }
                }
                for (auto& fn : due) fn();
            }

            // ★〔門番〕＝セーブがロードされ、プレイヤーがセルに居る時だけ時刻ジョブを動かします。
            //   メインメニュー(バニラ既定=1日目8時)でマーカーが焼き付く事故を根絶します（判定は既存の流用です）。
            auto* pc = RE::PlayerCharacter::GetSingleton();
            if (!pc || !pc->GetParentCell()) return;

            // ★大元ポーズ＝覚醒OFF(人間)中は時刻ジョブを全部止めます（覚醒契約の"全停止"）。
            //   C++はGlobal SuccubusLvlが0にならない設計なので人間化を検知できない→Papyrusが〔SkyVault〕の
            //   awakeフラグを覚醒ON=1/OFF=0で立てます。ここが0なら定期/期限は一切発火しません
            //   （③実時間くり返し=HUDは上で既に回しました＝バーが隠れるので実害ありません）。
            //   ★切り替わった時だけ1行ログ＝毎tickスパムにせず、大元ポーズの効きを実機で確認できるようにします。
            {
                auto* v = Vault();
                const int awake = v ? v->GetInt(0, "ASTR2_Awake", 1) : 1;
                static int s_lastAwake = -1;
                if (awake != s_lastAwake) {
                    spdlog::info("[Chronos] 大元{}（覚醒{}）", awake ? "再開" : "ポーズ", awake ? "ON" : "OFF");
                    s_lastAwake = awake;
                }
                if (awake == 0) return;
            }

            const double now = NowGameHours();
            if (now <= 0.0) return;                            // 暦がまだありません

            // 発火するものをロック内で集め、呼ぶのはロック外（ハンドラが〔クロノス〕を呼び返してもデッドロックしません）。
            std::vector<std::pair<IntervalJob, float>> dueIntervals;
            std::vector<OneShotJob>                    dueOneshots;
            {
                std::lock_guard<std::mutex> lock(g_mutex);
                // ---- ① 定期型 ----
                for (auto& job : g_intervals) {
                    if (!job.enabled) continue;               // 停止中（覚醒OFF/デメリットOFF等）は発火しません
                    const float elapsed = EvalIntervalLocked(job, now, false);
                    if (elapsed > 0.0f && job.fn) dueIntervals.emplace_back(job.fn, elapsed);
                }
                // ---- ② 期限型（永続の一発）----
                if (auto* v = Vault()) {
                    for (auto& job : g_oneshots) {
                        const std::string key = AtKey(job.name);
                        const double target = static_cast<double>(v->GetFloat(0, key.c_str(), -1.0f));
                        if (target < 0.0) continue;            // 予約がありません
                        if (now < target) continue;            // まだ来ていません
                        v->SetFloat(0, key.c_str(), -1.0f);    // 消化＝予約をクリアします（永続）
                        spdlog::info("[Chronos] {} 期限到達（目標{:.1f}h）", job.name, target);
                        if (job.fn) dueOneshots.push_back(job.fn);
                    }
                }
            }
            for (auto& pr : dueIntervals) pr.first(pr.second);
            for (auto& fn : dueOneshots) fn();
        }
    }

    double NowGameHours() {
        auto* cal = RE::Calendar::GetSingleton();
        if (!cal) return -1.0;
        const double days = std::floor(static_cast<double>(cal->GetDaysPassed()));
        const double hour = static_cast<double>(cal->GetHour());
        return days * 24.0 + hour;
    }

    float Timescale() {
        auto* cal = RE::Calendar::GetSingleton();
        const float ts = cal ? cal->GetTimescale() : 0.0f;
        return (ts > 0.0f) ? ts : kDefaultTScale;
    }

    // ---- ① 定期型 ----
    void RegisterInterval(const char* a_name, float a_intervalGameHours, IntervalJob a_fn) {
        if (!a_name || a_intervalGameHours <= 0.0f) return;
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_intervals) {
            if (job.name == a_name) {                          // 登録し直し＝間隔/fn差し替え（マーカーは永続なので据え置きます）
                job.hours = a_intervalGameHours;
                job.fn = std::move(a_fn);
                spdlog::info("[Chronos] {} 再登録（{}時間間隔）", a_name, a_intervalGameHours);
                return;
            }
        }
        Interval job;
        job.name = a_name;
        job.hours = a_intervalGameHours;
        job.fn = std::move(a_fn);
        g_intervals.push_back(std::move(job));
        spdlog::info("[Chronos] {} 登録（{}時間間隔）", a_name, a_intervalGameHours);
    }

    void SetInterval(const char* a_name, float a_intervalGameHours) {
        if (!a_name || a_intervalGameHours <= 0.0f) return;
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_intervals) {
            if (job.name != a_name) continue;
            job.hours = a_intervalGameHours;                   // マーカーは触らない＝溜まった分は次の判定で正しく出ます
            return;
        }
    }

    void RunDueNow(const char* a_name) {
        if (!a_name) return;
        const double now = NowGameHours();
        if (now <= 0.0) return;
        IntervalJob fn;
        float elapsed = 0.0f;
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto& job : g_intervals) {
                if (job.name != a_name) continue;
                if (job.enabled) { elapsed = EvalIntervalLocked(job, now, true); if (elapsed > 0.0f) fn = job.fn; }
                break;
            }
        }
        if (fn && elapsed > 0.0f) fn(elapsed);   // ★ロック外で呼びます
    }

    void StartInterval(const char* a_name) {
        if (!a_name) return;
        const double now = NowGameHours();
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_intervals) {
            if (job.name != a_name) continue;
            job.enabled = true;
            if (auto* v = Vault(); v && now > 0.0)         // マーカーを今に置きます（OFF期間は請求しません）
                v->SetFloat(0, LastKey(job.name).c_str(), static_cast<float>(now));
            spdlog::info("[Chronos] {} 開始（マーカー=今）", a_name);
            return;
        }
    }

    void StopInterval(const char* a_name) {
        if (!a_name) return;
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_intervals) {
            if (job.name != a_name) continue;
            job.enabled = false;
            if (auto* v = Vault()) v->SetFloat(0, LastKey(job.name).c_str(), -1.0f);  // マーカーを消去します＝再開時は今を基準に置きます
            spdlog::info("[Chronos] {} 停止", a_name);
            return;
        }
    }

    // ---- ② 期限型（永続の一発）----
    void RegisterAt(const char* a_name, OneShotJob a_fn) {
        if (!a_name) return;
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_oneshots) {
            if (job.name == a_name) { job.fn = std::move(a_fn); return; }  // ハンドラ差し替え（予約は永続なので据え置きます）
        }
        OneShot job;
        job.name = a_name;
        job.fn = std::move(a_fn);
        g_oneshots.push_back(std::move(job));
        spdlog::info("[Chronos] {} 期限ハンドラ登録", a_name);
    }

    void ScheduleAt(const char* a_name, float a_delayGameHours) {
        if (!a_name || a_delayGameHours < 0.0f) return;
        const double now = NowGameHours();
        if (now <= 0.0) return;                                // 〔門番〕の外（メニュー等）では予約しません
        if (auto* v = Vault()) {
            const double target = now + static_cast<double>(a_delayGameHours);
            v->SetFloat(0, AtKey(a_name).c_str(), static_cast<float>(target));
            spdlog::info("[Chronos] {} 予約（{:.1f}h後＝目標{:.1f}h）", a_name, a_delayGameHours, target);
        }
    }

    void CancelAt(const char* a_name) {
        if (!a_name) return;
        if (auto* v = Vault()) v->SetFloat(0, AtKey(a_name).c_str(), -1.0f);
    }

    // ---- ③ 実時間くり返し型（HUD専用）----
    void RegisterRealtime(const char* a_name, float a_everyRealSeconds, RealtimeJob a_fn) {
        if (!a_name || a_everyRealSeconds <= 0.0f) return;
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto& job : g_realtimes) {
            if (job.name == a_name) { job.every = a_everyRealSeconds; job.fn = std::move(a_fn); return; }
        }
        Realtime job;
        job.name = a_name;
        job.every = a_everyRealSeconds;
        job.fn = std::move(a_fn);
        g_realtimes.push_back(std::move(job));
        spdlog::info("[Chronos] {} 登録（実時間{}秒ごと）", a_name, a_everyRealSeconds);
    }

    void Install() {
        bool expected = false;
        if (!g_running.compare_exchange_strong(expected, true)) return;   // 二重起動しません
        std::thread([]() {
            while (true) {
                std::this_thread::sleep_for(std::chrono::milliseconds(kWakeMs));
                SKSE::GetTaskInterface()->AddTask([]() { Tick(); });
            }
        }).detach();
        spdlog::info("[Chronos] 核 起動（{}ms 鼓動・マーカーはSkyVault永続）", kWakeMs);
    }

    void OnLoadGame() {
        // 永続マーカー（〔SkyVault〕）はロードでそのまま復元される＝ここでは何もしません（リセット/張り直しはありません）。
        spdlog::info("[Chronos] ロード＝永続マーカーで自動再開");
    }
}
