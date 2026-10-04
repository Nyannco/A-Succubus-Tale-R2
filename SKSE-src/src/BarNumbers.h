#pragma once

// ============================================================================
// BarNumbers ― 淫魔力バー／経験値バーの上に「現在値 / 最大値」を重ねて出します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・バー本体(SkyUIウィジェット custommeter.swf)は**そのまま流用します**＝見た目/位置/色/フェードは不変です。
//     その上に **C++が文字レイヤーを重ねます**（createTextField 方式）。
//   ・文字レイヤーは**ウィジェットの中（WidgetRootの子）**に作ります＝メニュー等でHUDが消える時はバーと一緒に
//     消えます・フェードも一緒・MCMで動かしても一緒に動きます（_root直下だと出っぱなしになります）。
//   ・位置は**器（meter.background）の範囲をgetBoundsで測ります**＝アンカー設定や残量(fill)の伸び縮みに
//     左右されません。毎周期測り直します＝MCMで幅を変えても追従します。
//   ・並びは**左右は器の中央／文字の下端を器の下端に合わせます**（枠の高さ＝実際の文字の高さ）。
//
//   表記＝K/M/Gで短くします。有効桁はMCMで2桁/3桁を切り替えます：
//       999 → "999" ／ 12,345 → "12.3K" ／ 2,880,916 → "2.88M" ／ 10,000,000 → "10.0M"
//   経験値は**Lv100に到達したらカンスト表示**（"MAX"）にします。
//
//   値の出どころ（全部〔SkyVault〕＝C++から直読み）
//     ASTR2_LF_Curr / ASTR2_LF_Max     淫魔力
//     ASTR2_Xp_Curr / ASTR2_Xp_Req     経験値（次のLvまで）
//     ASTR2_BarNumOn      Int  1=数字を出す（既定1）※MCMトグル
//     ASTR2_BarNumDigits  Int  有効桁 2 or 3（既定3）※MCMトグル
// ============================================================================

namespace BarNumbers
{
    // 〔クロノス〕へ実時間の更新ジョブを登録します（kDataLoaded 後に1回）。
    void Install();

    // Papyrus ネイティブを登録します（ASTR2Native.BarNumbersBind）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);
}
