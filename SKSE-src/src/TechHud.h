#pragma once

// ============================================================================
// TechHud ― Phase2：H(OStim)中に「今どの技術が育ってるか」をライブ表示するHUDです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   今のノードで育ってる孫を1行ずつ「<孫名>：残りN秒」で「OStim準備中」HUDの上に積みます
//   （VMon↔準備中と同じ72px間隔・左端は準備中と揃えます）。データは TechRank::BuildHudLines()。
//   描画＝ScenePreparing/VMonと同じ HUDMenu uiMovie の _root.createTextField 方式です（AS2）。
//   シーン開始でON(有効なら)／終了で消灯します。MCMトグル ASTR2_TechHudEnabled で on/off できます（既定ON）。
// ============================================================================

namespace TechHud {
    // Papyrusネイティブ（ASTR2Technique.TechHudSetEnabled）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // Technique.cpp のシーン開始/終了フックから呼びます。
    void OnSceneStart();
    void OnSceneEnd();

    // MCMトグル／シーン開始時の設定push用です（Papyrus TechHudSetEnabled から）。
    void SetEnabled(bool on);
}
