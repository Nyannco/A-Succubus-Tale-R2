#pragma once

// ============================================================================
// LifeForceDecay ― 淫魔力(LF)の時間減衰を C++ の〔クロノス〕に載せたものです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   旧＝`ASTR2LifeForceBarScript.OnUpdateGameTime` の自己再予約タイマーです（Papyrus・常駐）。
//   新＝〔クロノス〕に「MCMスライダーの時間間隔で」定期登録し、発火時に〔SkyVault〕のLFを直接削ります。
//        Papyrusには「表示を更新して」の合図(modevent astr2_lf_tick)を1本飛ばすだけです。
//
//   減衰式は旧Papyrusと1:1＝**経過ゲーム時間 × サキュバスLv × 2.5**
//     （旧式 `(経過日 / 0.0417) * (Lv * 2.5)`＝0.0417日≒1時間ですので中身は同じです）。
//
//   〔門番〕（どれかが欠けたら減らしません・理由はログに出します）
//     ① サキュバスである       : GLOB MSRTSuccubusLvl > 0
//     ② デメリットがON         : 〔SkyVault〕 ASTR2_DisadvantagesOn（既定1）※MCMトグルの裏打ち
//   ★機能OFF中は「減らさない」だけ＝時計は回り続けるので、ONに戻した時に止まってた分をまとめて
//     請求することはありません。
//
//   〔SkyVault〕キー
//     ASTR2_LF_Curr / ASTR2_LF_Max   既存（LFバーのプロパティ裏打ち）
//     ASTR2_DisadvantagesOn  Int     1=デメリットON（既定1）
//     ASTR2_LFUpdateFreq     Int     減衰の間隔＝ゲーム内時間（既定3・MCMスライダー）
// ============================================================================

namespace LifeForceDecay
{
    // kDataLoaded＝〔クロノス〕へ定期登録します。
    void Install();

    // MCMスライダーが動いた時に間隔を追従させます（Papyrusから毎ロード/変更時に呼ばれる想定）。
    void SyncInterval();

    // 「今すぐ1回だけ減衰を計算して」＝Papyrus側 UpdateLifeForce() の受け皿。
    void TickNow();

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);
}
