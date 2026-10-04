#pragma once

// ============================================================================
// Skill XP Boost ― サキュバスソウルの「全バニラスキルXP +N%」機能です。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   PlayerCharacter::AddSkillExperience(ActorValue, float) を MinHook で横取りし、
//   付与される経験値に ×(1 + bonus/100) を掛けます。bonus%(0..500) は Papyrus(ASTLvlManager)が
//   ASTR2Native.SetSkillXpBonus() で随時プッシュします（Lv10で10%＋極大シャード数/1万・上限500%）。
//   ★C++乗算なので「バニラのアクティブ効果欄」には出ません＝表示はMCM側で行います。
//   関数アドレス＝RELOCATION_ID(39413, 40488)（CommonLibSSE-NG PlayerCharacter.cpp 実測）。
// ============================================================================

namespace SkillXpBoost {
    // AddSkillExperience を検出します（write_branch）。トランポリンは plugin.cpp で一括確保済みです。kDataLoadedで1回呼びます。
    void Install();

    // Papyrusネイティブ ASTR2Native.SetSkillXpBonus(Float) を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
