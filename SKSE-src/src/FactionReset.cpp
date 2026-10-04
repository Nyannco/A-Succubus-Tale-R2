#include "PCH.h"
#include "FactionReset.h"

// ============================================================================
// 汎用「ランタイム・ファクション全リセット」native の実体です。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   Actor::VisitFactions(commonlib実体)＝ ActorBase->factions(基) を回した後に
//   ExtraFactionChanges.factionChanges(ランタイム上書き) を回す二層構造です。
//   ＝ factionChanges を空にすれば実効ファクションは基テンプレートだけになります
//     ＝ 本MOD/他MODが"ゲーム中に足した"ファクションが種類問わず一律に落ちます（オールリセット）。
//   ★RE::オブジェクト操作は必ずゲームスレッド(AddTask)で行います（別スレッド直触りはCTDします）。
// ============================================================================

namespace {
    void ResetRuntimeFactions_Impl(RE::FormID a_id) {
        SKSE::GetTaskInterface()->AddTask([a_id]() {
            auto* a = RE::TESForm::LookupByID<RE::Actor>(a_id);
            if (!a) {
                return;
            }
            auto* changes = a->extraList.GetByType<RE::ExtraFactionChanges>();
            if (!changes) {
                // ランタイムでファクションを触られていません＝既に基テンプレートのまま＝やることはありません。
                spdlog::info("[FactionReset] 0x{:X} no ExtraFactionChanges (already base) -> nothing to reset", a_id);
                return;
            }
            const std::uint32_t n = changes->factionChanges.size();
            // 🔍 何を落とすかを全部ログします＝後で「IOSS等が含まれてたか」を追えます（読むだけ＝狙い撃ちではありません）。
            for (auto& fr : changes->factionChanges) {
                if (fr.faction) {
                    spdlog::info("[FactionReset] 0x{:X} clearing faction 0x{:X} (rank {})",
                        a_id, fr.faction->GetFormID(), static_cast<int>(fr.rank));
                }
            }
            changes->factionChanges.clear();   // ランタイム上書きを空にします＝基テンプレート構成へ巻き戻ります
            a->EvaluatePackage();              // AIに再評価させます＝味方→元の反応(敵/中立)へ戻します
            spdlog::info("[FactionReset] 0x{:X} runtime factions reset to base ({} cleared)", a_id, n);
        });
    }

    void ResetRuntimeFactions(RE::StaticFunctionTag*, RE::Actor* a_actor) {
        if (!a_actor) {
            return;
        }
        ResetRuntimeFactions_Impl(a_actor->GetFormID());
    }
}

namespace FactionReset {
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("ResetRuntimeFactions", "ASTR2Native", ResetRuntimeFactions);
        spdlog::info("[FactionReset] Papyrus native ASTR2Native.ResetRuntimeFactions 登録");
        return true;
    }
}
