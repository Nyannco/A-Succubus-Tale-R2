#pragma once

// ============================================================================
// FactionReset ― 汎用「ランタイム・ファクション全リセット」のnativeです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   目的＝スイート・ヴァッサル等でアクターに"ゲーム中に足したファクション"を、名指し(狙い撃ち)せず
//         まとめて基テンプレート(ActorBase)構成へ巻き戻します＝通常状態(元の敵/中立)へ戻します。
//   仕組み＝Actor::VisitFactions の実体が示す通り、実効ファクション＝
//         [ActorBase->factions(基)] ＋ [ExtraFactionChanges.factionChanges(ランタイム上書き)]。
//         そのため ExtraFactionChanges の配列を空にすれば、基テンプレートの構成にそのまま戻ります
//         （本MODが足した物・他MODが足した物・種類を問わず一律に落ちます＝オールリセット）。
//   ★FormID名指しゼロ＝「入ってるか不明な特定MODのファクションを狙い撃ちで剥がす」を避けます。
//   Papyrus: ASTR2Native.ResetRuntimeFactions(Actor akActor)
//   お掃除ライブラリ ASTR2Cleanup.ResetActor から呼ばれます（灰化/戦闘死/浄化ツールで共用します）。
// ============================================================================

namespace FactionReset {
    // Papyrus ネイティブ関数を登録します（SKSEPluginLoad で1回）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
