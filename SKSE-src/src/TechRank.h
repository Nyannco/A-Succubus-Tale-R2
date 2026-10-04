#pragma once

#include <vector>

// ============================================================================
// TechRank ― Hスキルランク層(C++)です。Technique.cpp が計測した「行為別の秒」を 〔SkyVault〕 へ永続し、
//   累積秒→ランク0〜10 を算出します（Papyrus ASTR2Technique のランク系getterを丸ごとC++へ移管）。
//   ★floor-0：未経験(0秒)=ランク0＝「未経験は威力補正なし」を全魔法で成立させます。
//   ★ライブ成長：ランク = 〔SkyVault〕確定秒 ＋ Technique の「今のシーンのライブ秒」なので、H中に伸びます／
//     イカせ+10秒も即反映します（威力にもその場で効きます）。確定はシーン終了時に〔SkyVault〕へ足します＝二重計上はありません。
//   ★保存先＝〔SkyVault〕(クロスMODデータ庫)なので、将来クロスMODとHスキルを共有できる土台です。
//   データ：〔SkyVault〕 holder=0 / キー "ASTR2_TechSec_<cat>"(8) と "ASTR2_TechAct_<行為>_S|_M|_N"(45孫)。
//   ★消費者(スペル/Lust/割引/サーヴァント/MCM/セダクション)はnativeシグネチャ不変so無改修です。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace TechRank {
    // Papyrusネイティブ（ASTR2Technique.*）を登録します。plugin.cpp が Register します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // ロード後/新規時（kPostLoadGame/kNewGame）：〔SkyVault〕の確定秒→C++キャッシュを作り直します。
    void OnLoadGame();

    // Technique.cpp がシーン終了時に呼びます＝このシーンの秒を 〔SkyVault〕 の確定秒へ足します（回収の自己完結C++化）。
    void PersistSceneCat(int cat, float delta);
    void PersistSceneAction(const char* action, int role, float delta);
    // 上を足し終えたら呼びます＝〔SkyVault〕確定秒→キャッシュ再構築（以後getterはキャッシュ＋ライブで即算出）。
    void RebuildCacheFromVault();

    // ★総合ランクです（Papyrus GetDisplayTotalRank と同値・読み取り専用）。維持費/手下税割引のC++用です。
    int GetDisplayTotalRank();
    // ★カテゴリ別ランクです（Papyrus GetDisplayCatRank と同値）。エッセンス・フロウC++版が自慰cat4連動に使います。
    int GetDisplayCatRank(int cat);
    // ★単純カテゴリランクです（Papyrus GetTechRank と同値＝カテゴリ秒直・攻め技cat6等）。セダクション威力C++用です。
    int GetTechRankCpp(int cat);

    // ★Phase2 HUD用：今のノードで育ってる孫の行です（名前$key＋現ランク＋次まで秒）。secToNext=-1は最大ランクです。
    //   nameKey は静的配列を指します（$ASTR2_Act_*）。localizeはTechHud側でLocalizationが解決します。
    struct HudLine { const char* nameKey; int rank; int secToNext; };
    std::vector<HudLine> BuildHudLines();
}
