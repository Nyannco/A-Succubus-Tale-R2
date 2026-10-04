#pragma once

// ============================================================================
// ScenePreparing ― 「OStimシーン準備中」インジケータ＋準備中watchdog＋セーブ安全弁です（全部C++）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・準備中＝OThreadBuilder.Start 成功後～ ThreadStarted(実開始) までの窓です。ここが"丸腰"(戦闘/セル
//     移動を見ていません)＋〔看板〕 IsOstimActive が1のまま詰まる窓＝ここを塞ぎます。
//   ・HUDに「OStim準備中」を点滅表示します（VMon実証の _root.createTextField 方式）。
//   ・watchdog(VassalRaise式 std::thread・100ms・RE::操作は全部 AddTask)：戦闘/プレイヤーのセル移動/
//     5分TO でキャンセル→〔看板〕0＋ModEvent ASTR2_SceneLaunchFailed 送出＝既存Papyrusハンドラが
//     OThread.Stop(0)＋会話の引き継ぎ＋プレイヤー通知で後始末します（休眠フックを本物の安全網へ昇格）。
//   ・ThreadStarted(HpBarFeed.RefreshCache)で自動OFFします。セーブロードで詰まり〔看板〕を解消します。
//   Papyrus: ASTR2Native.ScenePreparingBegin() ← RoleFinder の Launch成功直後が呼びます。
// ============================================================================

namespace ScenePreparing {
    // Papyrus ネイティブ登録します（SKSEPluginLoad で1回）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // シーンが実際に開始した時に呼びます＝準備中OFF＋HUD消し＋watchdog無効化。
    //   HpBarFeed の ThreadStarted(RefreshCache・ゲームスレッド)から呼びます。
    void OnSceneStarted();

    // セーブロード時に呼びます＝準備中を破棄＋「〔看板〕1だがシーン無し」の詰まりを解消（安全弁）。
    //   plugin.cpp の kPostLoadGame から呼びます。
    void OnLoadGame();
}
