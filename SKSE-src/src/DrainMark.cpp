#include "PCH.h"
#include "DrainMark.h"
#include "Sigil.h"
#include "SkyVaultAPI.h"
#include "Chronos.h"

#include <atomic>



// ============================================================================
// H中ドレインの「1回制限」＝痕(ゲーム内24時間)と淫紋(6段階で薄れる)の管理です。設計はDrainMark.h。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ★巡回は〔クロノス〕へ相乗りします＝自前スレッドは持ちません（常駐スレッドを増やしません）。
//     〔クロノス〕が1ゲーム時間ごとに呼びます＝段階更新(24h/6段階)と期限切れの掃除です。
// ============================================================================

namespace DrainMark
{
    namespace {
        constexpr const char* kKeyOn   = "ASTR2_DrainMarkOn";     // holder0 Int  1=ON（既定0=OFF）
        constexpr const char* kKeyList = "ASTR2_DrainMarkList";   // holder0 List 痕の残ってるNPC
        constexpr const char* kKeyDay  = "ASTR2_DrainMark_Day";   // holderNPC Float 痕を打ったゲーム内日数
        constexpr const char* kKeyNM   = "ASTR2_DrainMark_NM";    // holderNPC Int 1=夢魔痕(トグル非依存so巡回でOFFでも消しません)

        constexpr float kDurationDays = 1.0f;   // 痕の寿命＝ゲーム内1日(24時間)
        constexpr const char* kJobName = "1回制限の痕";   // 〔クロノス〕へ登録する名前です（1ゲーム時間ごと）
        constexpr float kNoMark       = -999.0f;

        std::atomic<bool>  g_ticking{ false };
        std::atomic<int>   g_remaining{ 0 };

        // ---- 〔SkyVault〕 短縮（HDrain と同じ流儀）----
        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }

        // 今のゲーム内日数です（GameDaysPassed と同じ・タイムスケールに左右されない"ゲーム内24時間"の基準）。
        inline float NowDays() {
            if (auto* cal = RE::Calendar::GetSingleton()) return cal->GetCurrentGameTime();
            return 0.0f;
        }

        // 痕を打った時刻です（無ければ kNoMark）。
        inline float MarkDay(RE::FormID a_id) {
            auto* v = Vault();
            return v ? v->GetFloat(a_id, kKeyDay, kNoMark) : kNoMark;
        }

        inline const char* NameOf(RE::Actor* a_npc) {
            return a_npc ? a_npc->GetDisplayFullName() : "(未ロード)";
        }

        // 痕を1件片付けます＝淫紋を消してキーとリストから落とします。
        //   ★a_why は「なぜ落としたか」＝OFF/期限切れ/記録なし等です。ログに残します（後から理由を追えるように）。
        void DropMark(SkyVaultAPI::IVault* a_vault, RE::FormID a_id, std::int32_t a_index, const char* a_why) {
            auto* npc = RE::TESForm::LookupByID<RE::Actor>(a_id);
            if (npc) {
                Sigil::ClearDrainMark(npc);
            }
            a_vault->Unset(a_id, kKeyDay);
            a_vault->Unset(a_id, kKeyNM);              // 夢魔痕フラグも掃除します
            a_vault->ListRemoveAt(0, kKeyList, a_index);
            spdlog::info("[DrainMark] 痕を落とした {} ({:08X}) 理由={}", NameOf(npc), a_id, a_why);
        }

        // 巡回1周です（ゲームスレッド）。残り件数を返します＝0になったらスレッドを止めます。
        int TickOnce() {
            auto* v = Vault();
            if (!v) return 0;

            // MCMでOFFにされた＝痕を全部畳んで終了します（淫紋も消します＝OFFにしたのに印が残らないようにします）。
            const bool on = (v->GetInt(0, kKeyOn, 0) == 1);
            const float now = NowDays();

            for (std::int32_t i = v->ListCount(0, kKeyList) - 1; i >= 0; --i) {
                const RE::FormID id = v->ListGet(0, kKeyList, i);
                if (id == 0) {                       // 壊れた要素の掃除です
                    v->ListRemoveAt(0, kKeyList, i);
                    spdlog::info("[DrainMark] リストの空要素を掃除 idx={}", i);
                    continue;
                }
                const float t = MarkDay(id);
                const float elapsed = now - t;
                if (!on && v->GetInt(id, kKeyNM, 0) == 0) {   // ★夢魔痕(nm)はトグルOFFでも残します＝ドレイン痕だけOFFで消えます
                    DropMark(v, id, i, "MCMでOFFにされた");
                    continue;
                }
                if (t <= kNoMark + 1.0f) {
                    DropMark(v, id, i, "時刻の記録なし(金庫に無い)");
                    continue;
                }
                if (elapsed >= kDurationDays) {
                    DropMark(v, id, i, "期限切れ(ゲーム内24時間経過)");
                    continue;
                }
                if (elapsed < 0.0f) {
                    DropMark(v, id, i, "時刻が巻き戻った(古いセーブをロード等)");
                    continue;
                }
                // 生きてる痕＝残り割合で淫紋の段階を更新します（3Dが無い＝見えない相手は次に近づいた時でいいです）。
                auto* npc = RE::TESForm::LookupByID<RE::Actor>(id);
                if (npc && npc->Is3DLoaded()) {
                    const float frac = 1.0f - (elapsed / kDurationDays);
                    Sigil::UpdateDrainMark(npc, frac);
                }
            }
            const int left = v->ListCount(0, kKeyList);
            if (left == 0) {
                spdlog::info("[DrainMark] 痕ゼロ（次の登録まで空回り）");
            }
            return left;
        }

        // 巡回は**〔クロノス〕に相乗りします**＝専用スレッドを持ちません（常駐スレッドを増やしません）。
        //   1ゲーム時間ごとに見ます＝段階は24h/6段階＝4時間で1つ落ちるので十分細かく、期限切れの消し忘れも最大1時間です。
        void StartTick() {
            bool expected = false;
            if (!g_ticking.compare_exchange_strong(expected, true)) return;   // 既に登録済みです
            Chronos::RegisterInterval(kJobName, 1.0f, [](float) { g_remaining.store(TickOnce()); });
        }
    }

    bool Enabled() {
        auto* v = Vault();
        return v && v->GetInt(0, kKeyOn, 0) == 1;
    }

    bool IsMarked(RE::Actor* a_npc) {
        if (!a_npc || !Enabled()) return false;      // OFFなら〔門番〕ごと素通りします＝従来と同じ挙動です
        const float t = MarkDay(a_npc->GetFormID());
        if (t <= kNoMark + 1.0f) return false;
        const float elapsed = NowDays() - t;
        return (elapsed >= 0.0f && elapsed < kDurationDays);
    }

    void Mark(RE::Actor* a_npc) { Mark(a_npc, false); }   // ★引数1つ版=HDrain(ドレイン痕)互換＝旧シンボル維持でリンク安定です
    void Mark(RE::Actor* a_npc, bool a_nightmare) {
        if (!a_npc) return;
        if (!a_nightmare && !Enabled()) return;      // ドレイン痕はトグルON時のみ／夢魔痕(a_nightmare)は常時です
        auto* v = Vault();
        if (!v) return;

        const RE::FormID id = a_npc->GetFormID();
        v->SetFloat(id, kKeyDay, NowDays());
        v->SetInt(id, kKeyNM, a_nightmare ? 1 : 0);  // 夢魔痕フラグ＝巡回でトグルOFFでも消しません
        v->ListAdd(0, kKeyList, id, true);           // true=重複不可
        Sigil::ApplyDrainMark(a_npc, 1.0f);          // 打った直後＝満タン段階(6)

        g_remaining.store(v->ListCount(0, kKeyList));
        StartTick();
        spdlog::info("[DrainMark] 痕を打った {} 残り件数={} nm={}", NameOf(a_npc), g_remaining.load(), a_nightmare);
    }

    void Install() {
        spdlog::info("[DrainMark] install（1回制限＝痕24h＋淫紋6段階・巡回は時計の核に相乗り）");
    }

    void OnLoadGame() {
        // セーブに残ってる痕を拾って巡回を再開します（0件なら何も起きません）。
        SKSE::GetTaskInterface()->AddTask([]() {
            auto* v = Vault();
            if (!v) return;
            if (v->ListCount(0, kKeyList) <= 0) {
                g_remaining.store(0);
                return;
            }
            const int left = TickOnce();   // ロード直後に1回そろえます（段階が古いまま/期限切れを残しません）
            g_remaining.store(left);
            if (left > 0) StartTick();
            spdlog::info("[DrainMark] ロード時の痕={}件", left);
        });
    }

    // 覚醒OFF＝痕を全部畳みます（ON/OFFに依らず・残ってる分は淫紋を消してリスト/キーを掃除します）。
    //   巡回(interval)は ASTR2_Awake=0 で止まるので、覚醒OFFの瞬間にここで能動的に消しきります。
    void ClearAll() {
        auto* v = Vault();
        if (!v) return;
        int cleared = 0;
        for (std::int32_t i = v->ListCount(0, kKeyList) - 1; i >= 0; --i) {
            const RE::FormID id = v->ListGet(0, kKeyList, i);
            if (id == 0) { v->ListRemoveAt(0, kKeyList, i); continue; }
            DropMark(v, id, i, "覚醒OFF（人間化＝アンインストール前掃除）");
            ++cleared;
        }
        g_remaining.store(0);
        spdlog::info("[DrainMark] 覚醒OFF＝痕を全部畳んだ（{}件）", cleared);
    }

    void Papyrus_ClearAll(RE::StaticFunctionTag*) { ClearAll(); }
    // 🌙 ナイトメア・エンブレイス用＝痕を打ちます(a_nightmare=trueでトグル非依存・常に付きます)。夢魔psc(ASTR2NightmareEffect)が成功時に呼びます。
    void Papyrus_Punch(RE::StaticFunctionTag*, RE::Actor* a_npc, bool a_nightmare) { Mark(a_npc, a_nightmare); }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("DrainMarkClearAll", "ASTR2Native", Papyrus_ClearAll);
        a_vm->RegisterFunction("DrainMarkPunch",    "ASTR2Native", Papyrus_Punch);
        spdlog::info("[DrainMark] Papyrus native (DrainMarkClearAll/DrainMarkPunch) 登録");
        return true;
    }
}
