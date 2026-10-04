#pragma once

// ============================================================================
// VassalDeath ― TESDeathEvent シンクで手下の死亡を"確実に"拾います。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   再アニメされた死霊は ReferenceAlias.OnDeath が鳴きません（実機で確認）ので、
//   エンジンの死亡イベントを直接購読して即掃除へ回します＝死亡即掃除の死霊対応です。
//   ゲーム中の全死亡から ASTR2手下ファクション(0101D278)所属だけに絞り、
//   Papyrus へ modevent "ASTR2_VassalDied"(sender=死んだアクター) を送ります。
//   最終判定(VassalListに居るか)と後始末(AshifyVassal)は Papyrus 側(OnVassalDied)です。
// ============================================================================

namespace VassalDeath {
    // kDataLoaded で1回です。TESDeathEvent シンクを設置します。
    void Install();
}
