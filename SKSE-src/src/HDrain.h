#pragma once

// =====================================================================================
//  HDrain ― H中ドレインの「核」をC++でフルC++化します。Papyrusは「完了後の委譲」だけです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
// -----------------------------------------------------------------------------------
//  設計＝Option C：OStimの ostim_orgasm ModEvent を C++ で直受け(OrgasmSink)し、
//        イッた本人(sender=actor)を HDrainOrgasm へ渡す＝Papyrusトリガー無し・遅延無しです。
//  hot(このモジュール)＝〔門番〕3つ→威力式(1:1移植)→HP減→LF加算(〔SkyVault〕)→吸収FX即時です。
//  cold(Papyrus OnHDrainDone)＝XP/記録/破壊育成/OCum/頭数＝完了modevent astr2_hdrain_done で委譲します。
//
//  〔門番〕(guards)＝Papyrusの OnOstimOrgasm が持っていた3条件をC++へ移植します：
//    ① IsDrainOn        : ドレインモードON（〔SkyVault〕 "ASTR2_IsDrainOn" Int・1=on）
//    ② IsPlayerInvolved : プレイヤーが同じOStimスレッドに居る（g_api GetPlayerThreadID/GetActors）
//    ③ DrainVictim無し  : 相手が二度吸いマーカー(MGEF 0100E528)を持っていない
//
//  入力の出どころ（全てC++可読）：LF/ドレイン3値=〔SkyVault〕 ／ tier=ServantTier::Get ／
//    種目cat=Technique::GetCurActionCat ／ cat秒=Technique::LiveCatSeconds ／ Lv=global直読みです。
// =====================================================================================

namespace HDrain {
    // ostim_orgasm の ModEvent sink を張る＝データロード後に1回呼びます（plugin.cpp から）。
    void Install();

    // 💋 色欲/H中ドレインの素の威力(表示用・相手maxHP項抜き)＝calcDamage×totalMult＝実核DoDrainと同式です(材料〔SkyVault〕共有なので一致)。
    //   ★実量は相手最大HPで変動します(表示は素の推定)。ASTDrainScript.GetHDrainPerOrgasm と NailDesc(色欲DESC{1})が共用＝重複なしです。
    int HDrainOrgasmBaseNow();
}
