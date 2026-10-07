#pragma once

// ============================================================================
// ProbeDump ― 【調整用・診断】右Ctrl(PROBE)でエンジン内部の状態を ASTR2SKSE.log の [Probe] へ全部流します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   Papyrusでは見えない層をC++で読むだけです＝何も書き換えません。
//   出すもの：召喚体フラグ/ライフステート/teammate/操っている人(commandingActor)/プレイヤーの操っている一覧/
//             かかっている魔法効果の全部(名前・種類・呪文・かけた人・経過/持続・無効/解除済)/掴んでいるクエストエイリアス全部/
//             今のAIパッケージ/上書きファクション全部
//   見張り：手下枠(ASTR2VassalFollowQuest)の子の「召喚体フラグ」「ライフステート」が変わった瞬間を
//           [Probe][watch] に時刻つきで自動記録（実時間0.5秒ごと・〔クロノス〕）＝いつ召喚体扱いに戻るかが分かります。
//   Papyrus: ASTR2Native.ProbeDumpCpp(Actor akTarget, String label)
// ============================================================================

namespace ProbeDump
{
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
    // kDataLoaded 後（Chronos::Install の後）に呼びます＝見張りを登録します。
    void Install();
}
