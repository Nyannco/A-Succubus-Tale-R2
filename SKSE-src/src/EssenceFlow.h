#pragma once

// =====================================================================================
//  EssenceFlow ― エッセンス・フロウ（Voice パワーのトグル・チャネル）（Fury同型でC++化）
// -------------------------------------------------------------------------------------
//  入口＝SPEL 0102087E(ASTR2EssenceFlowPower / Power・Voice・Self・FireAndForget) →
//        PowerReset(SpellCast 0x09)が実発動の瞬間に EssenceFlow::Toggle() を呼びます＝再使用で確実にON/OFFを切り替えます。
//        （MGEF 0102087F は最小＝castを成立させる殻・実処理は全部C++です）
//  ON  ＝起動時マジカ消費(〔門番〕)＋ソウルのマジカ再生を回復へ転用します(〔SkyVault〕ASTR2_SoulMagRate分をMagickaRateMultからカットします)。
//        効果時間は無く（純トグル＝"効果を纏う"＝常時消費します）、〔クロノス〕実時間1秒tickで「最大HP×回復%」を自動回復します。
//  回復% ＝ kRegenPctPerSec × boost（boost = 1 + (Lv-9)×0.05 + Restoration/200 + Hスキル自慰cat4×0.05）。
//  LFコスト＝Fury式＝最大LF×(11-Lv)×0.1%/秒(下限1)＝回復有無に関わらず毎秒消費します。〔SkyVault〕ASTR2_LF_Curr を減算＋astr2_lf_tick でバー再描画します。
//  OFF ＝再使用／LF切れ(即)／覚醒OFF のどれかで解除します＝転用を復元し＋水色モヤ停止します。
//  水色モヤ＝EFSH 01020880(ASTR2EssenceFlowES)をON中 InstantiateHitShader(-1)／OFFで finish（Fury同型）。
//  ★入力は全てC++可読です：Lv=global直読み／Restoration=player AV／Hスキル=TechRank(既存C++)／
//    ソウルMagRate=〔SkyVault〕（別モジュールがミラーします）／LF=〔SkyVault〕。
// =====================================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace EssenceFlow {
    void Install();
    // ON/OFFトグル（ゲームスレッドで実行）。PowerReset の SpellCast フックが実発動の瞬間に呼びます。
    void Toggle();
    // ステータスinfo表示用の現在値getter（ASTR2Native.GetEssenceFlowHealNow/CostNow）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝MCM getterと同じ実体を返します（重複なし・NailDescから直接呼びます）。
    float FlowHealNow();   // 回復%/秒
    int   FlowCostNow();   // 維持 淫魔力/秒
}
