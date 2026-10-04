#pragma once

// ============================================================================
// InfoHtml ― SkyUI MCM の info テキストを色付き（<font>タグ）で描画します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   SkyUI の ConfigPanel.applyInfoText() は info フィールドを TextField.text=（プレーン）で
//   書くので、<font>タグはそのまま文字として表示されます。このネイティブは同じ TextField を
//   GFx SetTextHTML()（html描画）で書き直すので、同じ文字列が色付きで表示されます。葉パス（configpanel.swf より）＝
//   contentHolder.infoPanel.textField。Journal ムービー内の config-panel ベースは自動検出してキャッシュします（ログは1回だけ）。
//   GFx の処理は UI/メインスレッドへキューします。文字列は解決済みである必要があります
//   （$キーは ASTR2Native.LocFmt を使う＝このネイティブは SkyUI の翻訳機を通しません）。
//   Papyrus: ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>...</font>")。
// ============================================================================

namespace InfoHtml {
    // Papyrus ネイティブ ASTR2Native.SetInfoHtml を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
