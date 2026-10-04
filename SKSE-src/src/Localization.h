#pragma once

// ============================================================================
// Localization (LocFmt) ― MCM/UI テキストを「訳した文字列＋実数」で出します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   SkyUI は文字列全体がちょうど1つの $key の時だけ訳すので、"$KEY " + 数値 だと $key が生のまま残ります。
//   これは $key の訳文を C++ で解決し（現在言語の Interface/Translations ファイルを解析・english フォールバック付き）、
//   {0}/{1}/... を渡された値（int に切り捨て）で置換して、完成した文字列を返します。
//   Papyrus: SetInfoText(ASTR2Native.LocFmt("$ASTR2_Info_X", vals))。
//   どの言語でも動きます＝A Succubus Tale R2_<sLanguage>.txt を読みます（+ english フォールバック）。
//   調査: CPP_SKSE_REFERENCE.md "山E"。
// ============================================================================

namespace Localization {
    // 現在言語の翻訳ファイル（+ english フォールバック）を解析して検索キャッシュに読み込みます。
    // kDataLoaded で1回だけ呼びます。
    void Build();

    // Papyrus ネイティブ ASTR2Native.LocFmt / LocFmtF を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // C++から訳文を使う入口です（Papyrusを経由せず画面通知などへ出す用）。
    //   $キーを引いて {0},{1},… へ args を差し込んだ完成文を返します。キー未収録なら生キーを返します
    //   ＝画面に生キーが出ます＝翻訳漏れが目で分かります（Papyrus側 LocFmtStr と同じ流儀）。
    std::string LocFmtStrCpp(const std::string& key, const std::vector<std::string>& args);
}
