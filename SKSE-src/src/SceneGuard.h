#pragma once

#include <cstdint>

// ============================================================================
// SceneGuard ― H(OStim)中セーフティ：シーン中に近接の敵対NPCをC++で軽くポーリングし、
//   見つかったら「当たる前に」シーンを強制終了して、H中に攻撃される→ネイティブCTD を回避します。
//   （起動時ガード`AnyInCombat`はシーン開始のみ＝この穴＝"シーン中に寄ってくる敵"を埋める安全網です）
//   ★検知＝軽くC++走査します(0.5秒・ProcessLists)／停止＝`OThread.Stop(0)`をVM経由で1回呼びます／通知＝Debug通知($key)を出します。
//   ★根治ではなくベストエフォートです＝発生率を大きく下げる網です（100%ではありません）。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace SceneGuard {
    // kDataLoaded：OStim Thread API を取得します（シーン参加者の除外に使います）。
    void Install();

    // Technique.cpp のシーン開始/終了フックから呼びます（監視の開始/停止）。
    void OnSceneStart(std::uint32_t threadID);
    void OnSceneEnd();
}
