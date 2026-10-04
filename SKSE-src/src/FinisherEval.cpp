#include "PCH.h"
#include "FinisherEval.h"

#include <vector>

// ============================================================================
// フィニッシュ判定の材料集めです（詳細は FinisherEval.h）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   Papyrus: Int[] ASTR2Native.GetFinisherFlags(Actor[] akActors, Actor akCaster,
//                                               Float afFloorPct, Float afFloorAbs)
//   返り値＝akActorsと同じ並びのInt配列です。各要素はビットの詰め合わせです：
//     1   生きている（死体は以降のビットを立てません）
//     2   下限(floor)まで削れている  ＝ 現在HP <= max(最大HP×afFloorPct, afFloorAbs) + 1.0
//     4   特別NPC（ユニーク / Essential / Protected / 本物のフォロワー）
//     8   山賊ファクション所属
//     16  術者に敵対している
//     32  戦闘中
//     64  召喚体（Reanimate蘇生体＝commanded）
//     128 使役中の手下（ASTR2ActiveMinionFaction）
//   ★Papyrus側はこのビットを算術(% と /)で解きます＝Math.LogicalAndのような
//     ネイティブ呼び出しを使わず、VM内で完結してタダ同然です。
//   ★下限の式は ASTDrainScript.TryFinisher / Drain本体と完全に同じにしてあります
//     （max(最大HP×FloorPctH, FloorAbs) ＋ regen微戻りの +1.0 余裕）。
// ============================================================================

namespace {
    // A Succubus Tale R2.esp のローカルFormID（ロード順は LookupForm が解決します）
    constexpr RE::FormID kMinionFacLocal = 0x01D278;    // ASTR2ActiveMinionFaction
    // バニラ（Skyrim.esm）は固定IDなので直引きします
    constexpr RE::FormID kFollowerFacID = 0x0005C84E;   // CurrentFollowerFaction
    constexpr RE::FormID kBanditFacID = 0x0001BCC0;     // BanditFaction

    RE::TESFaction* g_minionFac = nullptr;
    RE::TESFaction* g_followerFac = nullptr;
    RE::TESFaction* g_banditFac = nullptr;
    bool g_resolved = false;

    void ResolveFactions() {
        if (g_resolved) {
            return;
        }
        g_followerFac = RE::TESForm::LookupByID<RE::TESFaction>(kFollowerFacID);
        g_banditFac = RE::TESForm::LookupByID<RE::TESFaction>(kBanditFacID);
        if (auto* dh = RE::TESDataHandler::GetSingleton()) {
            g_minionFac = dh->LookupForm<RE::TESFaction>(kMinionFacLocal, "A Succubus Tale R2.esp");
        }
        if (!g_minionFac) {
            spdlog::warn("[FinisherEval] ActiveMinionFaction が見つからず＝手下保護ビットは常に0になる");
        }
        g_resolved = true;
    }

    std::vector<std::int32_t> GetFinisherFlags(RE::StaticFunctionTag*,
                                               std::vector<RE::Actor*> a_actors,
                                               RE::Actor* a_caster,
                                               float a_floorPct,
                                               float a_floorAbs,
                                               float a_tolPct) {
        ResolveFactions();
        std::vector<std::int32_t> out;
        out.reserve(a_actors.size());
        auto* player = RE::PlayerCharacter::GetSingleton();

        for (auto* actor : a_actors) {
            std::int32_t f = 0;
            if (!actor || actor == player || actor->IsDead()) {
                out.push_back(f);   // 死体・プレイヤー・空は全ビット0＝Papyrus側で素通りされます
                continue;
            }
            f |= 1;   // 生きています

            // --- 下限(floor)まで削れているか ---
            auto* avo = actor->AsActorValueOwner();
            if (avo) {
                const float cur = avo->GetActorValue(RE::ActorValue::kHealth);
                const float perm = avo->GetPermanentActorValue(RE::ActorValue::kHealth);
                const float temp = actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary,
                                                               RE::ActorValue::kHealth);
                const float maxHP = perm + temp;   // 最大HP＝恒久値＋一時バフ（オーガズムバフ等も入ります）
                float floorHP = maxHP * a_floorPct;
                if (floorHP < a_floorAbs) {
                    floorHP = a_floorAbs;
                }
                // ★許容幅は「最大HPの割合」で取ります（実機で確認）。固定+1.0HPだと、最大HPが
                //   数千万ある相手では、下限ぴったりに削った直後の数HPの再生で永久に条件を満たさず、
                //   フィニッシュが一生発動しませんでした（実測：下限8,836,279に対し現在HP8,836,281＝+2で不成立でした）。
                float tol = maxHP * a_tolPct;
                if (tol < 1.0f) {
                    tol = 1.0f;
                }
                if (cur <= floorHP + tol) {
                    f |= 2;
                }
            }

            // --- 特別NPC（ユニーク/Essential/Protected/本物のフォロワー） ---
            if (auto* base = actor->GetActorBase()) {
                if (base->IsUnique() || base->IsEssential() || base->IsProtected()) {
                    f |= 4;
                }
            }
            if (g_followerFac && actor->IsInFaction(g_followerFac)) {
                f |= 4;
            }

            // --- 敵判定の材料 ---
            if (g_banditFac && actor->IsInFaction(g_banditFac)) {
                f |= 8;
            }
            if (a_caster && actor->IsHostileToActor(a_caster)) {
                f |= 16;
            }
            if (actor->IsInCombat()) {
                f |= 32;
            }

            // --- 保護の材料 ---
            if (actor->IsCommandedActor()) {
                f |= 64;
            }
            if (g_minionFac && actor->IsInFaction(g_minionFac)) {
                f |= 128;
            }

            out.push_back(f);
        }
        return out;
    }
}

namespace FinisherEval {
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetFinisherFlags", "ASTR2Native", GetFinisherFlags);
        spdlog::info("[FinisherEval] Papyrus native ASTR2Native.GetFinisherFlags 登録");
        return true;
    }
}
