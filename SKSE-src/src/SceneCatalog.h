#pragma once

#include <string>
#include <vector>
#include <functional>

// ============================================================================
// SceneCatalog ― OStim全シーンの事前カタログです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・Data/SKSE/Plugins/OStim/scenes/**/*.json を起動時に1回パースします（MO2 VFSで全アニメMODがマージ済）。
//   ・家具(furniture) × 人数(actor count) でバケットし、各シーンのスロット性別シグネチャ・要件を保持します。
//   ・カタログは「何P/誰と」の早期絞り込み用の"地図"です。役の確定/起動はOStim自身に任せます。
//   ・まずパーサだけ作り、カタログ内容を ASTR2_CatalogDump.txt に丸ごとダンプして実機で裏取りします。
//   ★出典(OStim 7.4cソース実読)：
//     scene_id = ファイル名から拡張子除去 / 除外 = "destination"持ち(transition)・"noRandomSelection":true /
//     furniture既定 "none" / intendedSex = "male"|"female"のみ厳密・他は agender / 省略時はOStim既定=male。
// ============================================================================

namespace SceneCatalog {
    // シーンJSONをパースしてカタログを構築します（kDataLoaded後に1回・冪等＝再呼び出しで作り直します）。
    void Build();

    // Papyrusネイティブ（ASTR2Catalog.*）を登録します（SKSEPluginLoadで1回）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // ── Hスキル C++化の土台（Technique.cpp 用の契約）─────────
    //   OStimシーンJSONの "actions"（type/actor/target/performer）を全ノード分索引して引けるようにします。
    struct ActionInfo {
        std::string type;     // 行為タイプ（小文字化）です。例 "vaginalsex" / "blowjob"
        int actor = 0;        // 行為の主体スロットです
        int target = -1;      // 対象スロットです（JSON省略時 -1）
        int performer = -1;   // 実行者スロットです（JSON省略時は actor 既定＝OStim準拠）
    };
    // 任意ノード(起動可否問わず＝transition/idle含む)の行為リストです。sceneIdは小文字です。未収録は nullptr です。
    const std::vector<ActionInfo>* GetActionsForScene(const std::string& sceneIdLower);

    // 全索引シーンの (sceneId → actions) を列挙します（孫スキル精査＝各行為の実在アニメ本数集計用）。
    //   fn(sceneIdLower, actions) を索引済み全シーンぶん呼びます。Build後に有効です。
    void ForEachSceneActions(const std::function<void(const std::string&, const std::vector<ActionInfo>&)>& fn);
}
