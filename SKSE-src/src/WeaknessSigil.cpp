#include "PCH.h"
#include "WeaknessSigil.h"
#include "Chronos.h"
#include "Sigil.h"

#include <mutex>
#include <vector>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace WeaknessSigil
{
    namespace {
        constexpr const char* kJobName  = "ウィークネス淫紋";
        constexpr float       kEverySec = 10.0f;    // 段階チェックの間隔です（旧 SigilTickSec=10 と同じ／6段階so粗くてOKです）
        constexpr const char* kEsp      = "A Succubus Tale R2.esp";
        constexpr RE::FormID  kMinionFacID    = 0x01D278;   // ASTR2ActiveMinionFaction（スイート・ヴァッサルの手下＝淫紋の持ち主です）
        constexpr RE::FormID  kWeaknessMgefID = 0x005E36;   // SuccubusWeakness MGEF（耐性ダウン効果本体です）

        struct Entry {
            RE::FormID formID   = 0;
            double     endHours = 0.0;    // 終了予定のゲーム内時刻です（日×24＋時）
            double     spanHours = 0.0;   // 総時間（ゲーム内時間）＝残り割合の分母です
            bool       hasSchlong = false;
        };

        std::mutex         g_mutex;
        std::vector<Entry> g_entries;

        // 覚醒OFF掃除用＝対象NPCから SuccubusWeakness の効果本体(MGEF 005E36)をDispelします（淫紋だけでなく耐性ダウンも消します）。
        void DispelWeaknessEffect(RE::Actor* a_npc) {
            if (!a_npc) return;
            static RE::EffectSetting* wkMgef = []() -> RE::EffectSetting* {
                auto* dh = RE::TESDataHandler::GetSingleton();
                return dh ? dh->LookupForm<RE::EffectSetting>(kWeaknessMgefID, kEsp) : nullptr;
            }();
            if (!wkMgef) return;
            auto* mt = a_npc->AsMagicTarget();
            if (!mt) return;
            auto* list = mt->GetActiveEffectList();
            if (!list) return;
            for (auto* ae : *list) {
                if (ae && ae->GetBaseObject() == wkMgef) ae->Dispel(true);
            }
        }

        bool IsVassal(RE::Actor* a_npc) {
            static RE::TESFaction* minionFac = []() -> RE::TESFaction* {
                auto* dh = RE::TESDataHandler::GetSingleton();
                return dh ? dh->LookupForm<RE::TESFaction>(kMinionFacID, kEsp) : nullptr;
            }();
            return (minionFac && a_npc && a_npc->IsInFaction(minionFac));
        }

        // 実時間の秒 → ゲーム内時間（時）。★バニラの魔法効果と同じ意味の秒＝タイムスケール換算です。
        //   （待機/睡眠でゲーム内が飛べば、そのぶん効果も進みます＝エンジンのDurationと歩調が合います）
        double RealSecToGameHours(float a_realSec) {
            return (static_cast<double>(a_realSec) * static_cast<double>(Chronos::Timescale())) / 3600.0;
        }

        // 10秒ごと（実時間）です。登録中の相手の段階を更新し、終わった分を片付けます。
        void Update() {
            std::lock_guard<std::mutex> lock(g_mutex);
            if (g_entries.empty()) return;

            const double now = Chronos::NowGameHours();
            for (std::size_t i = g_entries.size(); i-- > 0;) {
                Entry& e = g_entries[i];
                auto* npc = RE::TESForm::LookupByID<RE::Actor>(e.formID);
                if (!npc) {                                   // 参照が消えました＝畳みます
                    g_entries.erase(g_entries.begin() + static_cast<std::ptrdiff_t>(i));
                    continue;
                }
                if (IsVassal(npc)) {
                    continue;   // ★ロゴは手下の物＝触りません（ウィークネスの効果自体はエンジンが継続します）
                }
                double frac = (e.spanHours > 0.0) ? ((e.endHours - now) / e.spanHours) : 0.0;
                if (frac <= 0.0) {                            // 時間切れ＝淫紋を消して登録も外します
                    Sigil::ClearNpcSigil(npc);
                    spdlog::info("[WeaknessSigil] 終了 {}（時間切れ）", npc->GetDisplayFullName());
                    g_entries.erase(g_entries.begin() + static_cast<std::ptrdiff_t>(i));
                    continue;
                }
                if (frac > 1.0) frac = 1.0;
                Sigil::UpdateNpcSigil(npc, static_cast<float>(frac), e.hasSchlong);
            }
        }

        // ---- Papyrus ネイティブ ----
        //   効果開始で1回です。durationSec＝MGEFの効果時間です（実時間の秒＝バニラと同じ意味です）。
        //   hasSchlong＝竿の有無です（OActorUtilはPapyrus専用soこちらで判定して渡してもらいます）。
        void Papyrus_Begin(RE::StaticFunctionTag*, RE::Actor* a_npc, float a_durationSec, bool a_hasSchlong) {
            if (!a_npc || a_durationSec <= 0.0f) return;
            if (IsVassal(a_npc)) {
                spdlog::info("[WeaknessSigil] {} はヴァッサル＝淫紋スキップ（効果自体は有効）",
                             a_npc->GetDisplayFullName());
                return;
            }
            const double span = RealSecToGameHours(a_durationSec);
            const double now  = Chronos::NowGameHours();

            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto& e : g_entries) {
                if (e.formID == a_npc->GetFormID()) {        // 重ね掛け＝時間を張り直します
                    e.endHours = now + span;
                    e.spanHours = span;
                    e.hasSchlong = a_hasSchlong;
                    Sigil::ApplyNpcSigil(a_npc, 1.0f, a_hasSchlong);
                    return;
                }
            }
            Entry e;
            e.formID = a_npc->GetFormID();
            e.endHours = now + span;
            e.spanHours = span;
            e.hasSchlong = a_hasSchlong;
            g_entries.push_back(e);
            Sigil::ApplyNpcSigil(a_npc, 1.0f, a_hasSchlong);   // 開始＝満タン段階です
            spdlog::info("[WeaknessSigil] 開始 {}（{:.0f}秒＝ゲーム内{:.2f}h・登録{}件）",
                         a_npc->GetDisplayFullName(), a_durationSec, span, g_entries.size());
        }

        // 効果終了で1回です（エンジンがDurationで切った時・ディスペル・死亡など全部ここです）。
        void Papyrus_End(RE::StaticFunctionTag*, RE::Actor* a_npc) {
            if (!a_npc) return;
            std::lock_guard<std::mutex> lock(g_mutex);
            for (std::size_t i = g_entries.size(); i-- > 0;) {
                if (g_entries[i].formID != a_npc->GetFormID()) continue;
                g_entries.erase(g_entries.begin() + static_cast<std::ptrdiff_t>(i));
            }
            if (IsVassal(a_npc)) {
                return;   // ★手下の淫紋は消しません
            }
            Sigil::ClearNpcSigil(a_npc);
            spdlog::info("[WeaknessSigil] 終了 {}（効果が切れた）", a_npc->GetDisplayFullName());
        }
    }

    // 覚醒OFF＝登録中の全ウィークネス淫紋を今すぐ消して登録を空にします（Duration切れを待ちません）。
    void ClearAll() {
        std::lock_guard<std::mutex> lock(g_mutex);
        int n = 0;
        for (auto& e : g_entries) {
            if (auto* npc = RE::TESForm::LookupByID<RE::Actor>(e.formID)) {
                Sigil::ClearNpcSigil(npc);        // 淫紋(ロゴ)を消します
                DispelWeaknessEffect(npc);        // ★効果本体(耐性ダウン)もDispel＝「効果だけ残る」を解消します
                ++n;
            }
        }
        g_entries.clear();
        spdlog::info("[WeaknessSigil] 覚醒OFF＝全ウィークネス淫紋＋効果をクリア（{}件）", n);
    }

    void Install() {
        Chronos::RegisterRealtime(kJobName, kEverySec, []() { Update(); });
    }

    void Papyrus_ClearAll(RE::StaticFunctionTag*) { ClearAll(); }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("WeaknessSigilBegin", "ASTR2Native", Papyrus_Begin);
        a_vm->RegisterFunction("WeaknessSigilEnd", "ASTR2Native", Papyrus_End);
        a_vm->RegisterFunction("WeaknessSigilClearAll", "ASTR2Native", Papyrus_ClearAll);
        spdlog::info("[WeaknessSigil] Papyrus natives (WeaknessSigilBegin/End/ClearAll) 登録");
        return true;
    }
}
