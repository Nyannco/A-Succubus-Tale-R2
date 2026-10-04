#pragma once

#include <string>
#include <vector>
#include <utility>

// ============================================================================
// Technique ― Hスキルランク化(C++)です。プレイヤー(サキュバス)の行為別スキルを計測します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・OStim公開API NodeChanged(1本イベント) で体位変化を拾い、SceneCatalog の行為索引
//     (type/actor/target/performer) を引いて、攻め/受け＋技術カテゴリへ held秒 を累積します。
//   ・全部C++＝OStim中はカタログ参照(map)だけで軽いです／Papyrus二重イベントのheld秒2倍バグを根治します。
//   ・依存：SceneCatalog::GetActionsForScene（「全ノードの行為索引」を実装しています）。
// ============================================================================

namespace Technique {
    // kDataLoaded後にOStim Thread APIを取得し、ThreadStarted/NodeChanged/ThreadEnded を購読します。
    void Install();

    // Papyrusネイティブ（ASTR2Technique.GetSceneTechSeconds / ResetSceneTech）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // ★TechRank(ランク層)が読む「今のシーンのライブ秒」＝確定秒に足して"H中の伸び"を出します。
    //   シーン外/未累積は0です。スレッドセーフです（内部で g_mutex）。TechRank側は g_cacheMutex を握らずに呼んでください。
    float LiveCatSeconds(int cat);                          // cat 0-7（Hips..ReceiveM）
    float LiveActionSeconds(const char* action, int role);  // role 0=攻めS/1=受けM/2=中立

    // ★Phase2 HUD用：今のノードでプレイヤーがクレジットされてる技術行為(孫)の (正規名, このノードでの重複数)です。
    //   重複数＝同じ行為を何人に同時にしてるか（例:指マン2人=2）＝ライブ進行中秒を×人数して確定(2×)と一致させる用です。
    //   シーン外は空です。CommitSegmentと同じクレジット規則です（挿入HIPSは受けalso／他はactorのみ）。
    std::vector<std::pair<std::string, int>> GetActiveNodeActions();

    // ★リアルタイムHUD用：今の体位(ノード)に入ってからの経過秒です（まだCommitSegmentで確定してない進行中ぶん）。
    //   シーン外は0です。これを確定秒に足すと残り秒/ランクが毎秒ヌルヌル更新されます。
    float CurrentNodeElapsed();

    // ★今/直近の行為cat(0-5)をC++へ公開します（H中ドレインC++がイカせ行為の種目rankに使います）。不明/H外=-1。
    //   Papyrus native GetCurrentActionCat と同じ値（g_curActionCat）を返すだけです・読み取り専用です。
    int GetCurActionCat();

    // ★生のOStim行為名を45孫の正規名へ寄せます（派生名/綴りゆれ/統合を吸収）。孫スキル精査(アニメ本数集計)用に公開します。
    //   ★将来OStimが行為名をリネームしたら、ここ1か所に「新名→旧正規名」を足せば計測もこの集計も両方直ります（橋渡し点）。
    std::string CanonAction(const std::string& rawType);

    // ★生type→素の名前です（"3pp_"接頭辞と末尾連番だけ剥がします）。孫スキル精査(玩具/テコキ射精の横断アニメ本数)用に公開します。
    std::string RawBaseName(const std::string& rawType);
}
