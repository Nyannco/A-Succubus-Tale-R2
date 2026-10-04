#include "PCH.h"
#include "LifeForceDecay.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"

#include <cmath>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace LifeForceDecay
{
    namespace {
        constexpr const char* kJobName = "淫魔力の減衰";
        constexpr const char* kKeyCurr  = "ASTR2_LF_Curr";
        constexpr const char* kKeyMax   = "ASTR2_LF_Max";
        constexpr const char* kKeyDisOn = "ASTR2_DisadvantagesOn";
        constexpr const char* kKeyFreq  = "ASTR2_LFUpdateFreq";
        // ★自前マーカー(ASTR2_LF_LastHour)は廃止＝時刻管理は〔クロノス〕が一元で持ちます。

        constexpr float kRatePerHour  = 2.5f;   // 減衰＝経過時間 × Lv × これ（旧Papyrus式と同値）
        constexpr int   kDefaultFreqH = 3;      // MCMスライダー既定＝3ゲーム時間

        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }

        int SuccubusLevel() { return SuccLevel::Raw(0); }

        // 設定された間隔です（ゲーム内時間）。0以下や未設定は既定3です。
        float IntervalHours() {
            auto* v = Vault();
            int h = v ? v->GetInt(0, kKeyFreq, kDefaultFreqH) : kDefaultFreqH;
            if (h <= 0) h = kDefaultFreqH;
            return static_cast<float>(h);
        }

        // 発火本体＝**〔クロノス〕が渡す経過(elapsed)ぶんだけ削ります**（時刻管理は〔クロノス〕が一元で持ちます＝自前マーカー無し）。
        //   ★安全網でサキュバス/デメリットをここでも見ます（本来はStart/Stopで止まります＝二重の保険）。
        void DrainBy(float a_elapsed) {
            auto* v = Vault();
            if (!v || a_elapsed <= 0.0f) return;

            const int lv = SuccubusLevel();
            if (lv <= 0) return;                                  // サキュバスではありません
            if (v->GetInt(0, kKeyDisOn, 1) != 1) return;         // デメリットがOFFです
            const int cur = v->GetInt(0, kKeyCurr, 0);
            if (cur <= 0) return;                                 // 既に0です
            const int sub = static_cast<int>(a_elapsed * lv * kRatePerHour);
            if (sub <= 0) return;

            const int next = (cur > sub) ? (cur - sub) : 0;
            v->SetInt(0, kKeyCurr, next);
            spdlog::info("[LFTick] 減衰 Lv={} 経過={:.1f}h -LF={} → {}/{}",
                         lv, a_elapsed, sub, next, v->GetInt(0, kKeyMax, 0));

            // Papyrusへ「表示を更新して」の合図だけ飛ばします（バー再描画＋段階バフ）。
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "astr2_lf_tick", "", static_cast<float>(next), nullptr };
                src->SendEvent(&ev);
            }
        }

        // ---- Papyrus ネイティブ ----
        void Papyrus_LFDecayTickNow(RE::StaticFunctionTag*) { TickNow(); }
        void Papyrus_LFDecaySyncInterval(RE::StaticFunctionTag*) { SyncInterval(); }
        void Papyrus_LFDecayStart(RE::StaticFunctionTag*) { Chronos::StartInterval(kJobName); } // 覚醒/デメリットONで呼びます
        void Papyrus_LFDecayStop(RE::StaticFunctionTag*)  { Chronos::StopInterval(kJobName); }  // 覚醒OFF/デメリットOFFで呼びます
    }

    void Install() {
        // 登録＝〔クロノス〕の定期ジョブです。渡された経過ぶんだけ削ります（自前で時刻を測りません）。
        Chronos::RegisterInterval(kJobName, IntervalHours(), [](float e) { DrainBy(e); });
    }

    void SyncInterval() {
        Chronos::SetInterval(kJobName, IntervalHours());
    }

    void TickNow() {
        // 「今すぐ1回」＝〔クロノス〕の同じマーカーで溜まった分を即反映します（二重に削りません）。表示を今にしたい瞬間用です。
        Chronos::RunDueNow(kJobName);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("LFDecayTickNow", "ASTR2Native", Papyrus_LFDecayTickNow);
        a_vm->RegisterFunction("LFDecaySyncInterval", "ASTR2Native", Papyrus_LFDecaySyncInterval);
        a_vm->RegisterFunction("LFDecayStart", "ASTR2Native", Papyrus_LFDecayStart);
        a_vm->RegisterFunction("LFDecayStop",  "ASTR2Native", Papyrus_LFDecayStop);
        spdlog::info("[LFTick] Papyrus natives (TickNow/SyncInterval/Start/Stop) 登録");
        return true;
    }
}
