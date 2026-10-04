#pragma once

// ============================================================================
// HpBarHud ― H中のアクターHPバーの「毎秒の更新」を C++ が持ちます。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   旧＝`ASTR2ActorHpBarScript` が H中ずっと1秒ごとに自分を再予約し、参加者4人ぶんのHPを読んで
//       SkyUIウィジェット(custommeter.swf)へ setPercent を投げていました＝H中ずっとPapyrusが回ります。
//   新＝**ウィジェットはそのまま流用**し、毎秒の更新だけ〔クロノス〕の実時間くり返し型に載せます。
//       C++は参加者(HpBarFeed)とHPを直接読み、**変化があったバーだけ** HUD Menu へ Invoke します。
//
//   Papyrusが今までどおり持つもの＝表示モード(Always/KeySec/Hide/Change)・MCMの位置・色・
//     フェードイン/アウト・プレビューです。**低頻度なので負荷になりません**。
//   C++が持つもの＝H中の毎秒の「HP%の反映」と「ドレイン下限に到達した瞬間のフラッシュ」です。
//
//   ウィジェットの場所(WidgetRoot＝"_root.WidgetContainer.widgetN"のような文字列)は
//     Papyrusしか知らないので、シーン開始時に Bind で渡してもらいます。
// ============================================================================

namespace HpBarHud
{
    // 〔クロノス〕へ実時間1秒の更新ジョブを登録します（kDataLoaded 後に1回）。
    void Install();

    // Papyrus ネイティブを登録します（ASTR2Native.HpBarBind / HpBarUnbind）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);
}
