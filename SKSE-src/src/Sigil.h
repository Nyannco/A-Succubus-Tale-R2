#pragma once
// ============================================================================
// Sigil ― 淫紋(ロゴ)システムを C++ で持つサブシステムです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   方針「最低限Papyrus・できる限りC++」に沿い、SKEE(NiOverride)をC++から直接呼び、
//   VMの列に並ばず淫紋の検出・選択・適用を行います。
//
//   （RE::BSScript::IVirtualMachine は PCH.h 経由で可視＝前方宣言しません＝他ヘッダと同じ流儀です）
// ============================================================================

namespace Sigil
{
    // SKEE(RaceMenu)の C++ 窓口を取得します。kPostLoad で1回呼びます。
    void AcquireSkee();

    // Papyrus ネイティブを登録します（ASTR2Native.SigilApplyPlayer 等）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // ---- C++からのNPC淫紋 窓口（中身はPapyrusネイティブと同一の実装を呼ぶだけ）----
    //   Papyrus を経由せず、C++サブシステム（DrainMark の痕など）が淫紋を貼り・更新・消すために公開します。
    //   frac=残り割合(0〜1)→段階6〜1／hasSchlong=竿の有無でテクスチャを振り分けます。
    // 💋 1回制限の痕（DrainMark）＝位置は男=背中／女・フタ=胸です。
    //   股間紋(ウィークネス/手下)とは別枠so、同じ相手に両方付いても被らず、互いに消しません。
    void ApplyDrainMark(RE::Actor* a_npc, float a_frac);
    int  UpdateDrainMark(RE::Actor* a_npc, float a_frac);   // 戻り=段階(1-6)
    void ClearDrainMark(RE::Actor* a_npc);

    void ApplyNpcSigil(RE::Actor* a_npc, float a_frac, bool a_hasSchlong);
    int  UpdateNpcSigil(RE::Actor* a_npc, float a_frac, bool a_hasSchlong);   // 戻り=段階(1-6)
    void ClearNpcSigil(RE::Actor* a_npc);
}
