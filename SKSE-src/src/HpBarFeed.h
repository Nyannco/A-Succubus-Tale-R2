#pragma once
// ============================================================================
// HpBarFeed ― HPバー用のOStim参加者プロバイダです
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・OStim の ThreadStarted/Ended を購読し、プレイヤーのHシーン参加者(プレイヤー除く)を
//     C++内にキャッシュします（読みは AddTask 遅延＝再入デッドロックを避ける実機確認済みのパターンです）。
//   ・Papyrus ネイティブ ASTR2Native.GetSceneActors() でそのキャッシュを返します。
//   狙い＝HPバーの OThread.GetActors（OStimロック競合＝フタナリ破綻シーンのデッドロックの元）の廃止です。
//   Papyrus側は「安全なキャッシュを受け取るだけ」＝OStimを叩かない＝再入が起きようがありません。
//   同じ"プレイヤーのシーン開始/終了"ライフサイクルで〔看板〕 IsOstimActive(Global 0x018C69)
//     も駆動します（ThreadStarted→=1再assert／ThreadEnded→=0）＝desync を根治します。詳細は .cpp の SetOstimFlag にあります。
// ============================================================================

namespace HpBarFeed {
    // OStim API を取得し ThreadStarted/Ended を購読します（kDataLoaded 後に1回）。
    void Install();

    // Papyrus ネイティブ関数を登録します（SKSEPluginLoad で1回）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // 今の参加者(プレイヤー除く・最大4)のFormIDをC++内から取ります＝HPバーの毎秒更新(HpBarHud)が使います。
    std::vector<RE::FormID> SceneNpcs();
}
