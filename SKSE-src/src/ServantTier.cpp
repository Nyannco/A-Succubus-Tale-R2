#include "PCH.h"
#include "ServantTier.h"
#include <functional>

// per-NPCサーヴァントtierをfaction rankから読みます。Papyrus ASTR2Servantship.GetTier の C++版です。
//   ASTR2_ServantshipFaction のローカルFormID＝0x01C7AF（Papyrus 0x0101C7AF から先頭ロード順バイトを剥がした値です。
//   VassalDeathの手下faction 0x0101D278→0x01D278 と同じ流儀です）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace ServantTier {
    int Get(RE::Actor* a_npc) {
        if (!a_npc) {
            return 0;
        }
        auto* dh = RE::TESDataHandler::GetSingleton();
        if (!dh) {
            return 0;
        }
        auto* fac = dh->LookupForm<RE::TESFaction>(0x01C7AF, "A Succubus Tale R2.esp");
        if (!fac) {
            return 0;
        }
        // ★RE::ActorにGetFactionRankはないので、VisitFactions(Actor.h:591)で該当factionのrankを拾います
        //   （Actorレベルの巡回so実行時SetFactionRankの変更も反映＝Papyrus GetFactionRank相当）。
        int rank = -1;
        a_npc->VisitFactions([&](RE::TESFaction* a_faction, std::int8_t a_rank) -> bool {
            if (a_faction == fac) {
                rank = a_rank;
                return true;   // 見つかりました＝巡回を停止します
            }
            return false;      // 続行します
        });
        return rank < 0 ? 0 : rank;   // 非所属/負は0（Papyrus GetTierと同じ）
    }
}
