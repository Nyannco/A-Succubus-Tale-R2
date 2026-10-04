#pragma once

namespace RE { class Actor; }

// ============================================================================
// ServantTier ― per-NPCのサーヴァントtier(0-4)をC++から読みます（H中ドレイン核のC++化用）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   tierは ASTR2_ServantshipFaction(0101C7AF) の faction rank に格納されているため、C++から直読みできます
//   （engineのfaction＝金庫不要）。Papyrus ASTR2Servantship.GetTier と同じ意味です（非所属/負は0）。
// ============================================================================

namespace ServantTier {
    // NPCのサーヴァントtier(0-4)です。None/非所属/範囲外=0。読み取り専用です。
    int Get(RE::Actor* a_npc);
}
