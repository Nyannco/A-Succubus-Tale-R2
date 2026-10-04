#pragma once

// ============================================================================
//  魔法マジカコスト（スキル変動tier＋コスト列一本化）
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   対象6魔法(Drain/Lust/Nightmare/Consume/Weakness/Ravenous)のマジカ消費を独自式で管理します。
//   ・表示＆消費＝CalculateMagickaCost(11213)フック一本化（InstallCostHook）：
//       魔法メニューのコスト列/カードに独自の計算値を出し、バニラが詠唱時にその値で消費します。
//       表示レベル(素人〜達人)もtierへ追従します(MGEF minimumSkillをruntime書換)。〔門番〕もバニラ任せです(マジカ不足で不発)。
//   ・★Ravenousだけ毎秒×人数をC++(CombatDrain)で維持します＝TrySpendPerSec使用（他5本はバニラ任せ）。
//   ・Flow(エッセンス・フロウ)はマジカコストなし＝対象外です。
//
//  式(裏ランク=2役)：
//       dispTier = min( 学派スキルのマスタリ段階(素人1/見習い2/一人前3/熟練者4/達人5) , 裏ランク )  ← ② 表示レベルの頭打ち
//       costTier = 裏ランク + (dispTier − 1)                                                       ← ① rankで散らす＋スキル上乗せ
//       毎秒 = 20 × ①^ステージ × costTier × (1 − 減率)
//       発動 = 20 × ①^ステージ × costTier × ③ × (1 − 減率)
//       ステージ = floor((サキュバスLv-1)/10)(0〜9)／減率 = min(スピーチ×0.5%, ②cap)
//       ※裏ランク(Drain5/Lust2/Nightmare3/Consume4/Weakness4/Ravenous5)＝①コストを散らす基準＋②表示レベルの上限です(威力/XPは無関係)。
//       ※半額perk/Fortify/エンチャント(バニラ減)は除外＝tierと二重になりません。
//  MCM： ①ASTR2_ManaCostStepMul(規定1.67) ②ASTR2_ManaCostCapPct(規定100) ③ASTR2_ManaCostBurstMul(規定2)
// ============================================================================

namespace RE { class Actor; }

namespace ManaCost {
    // 対象6魔法です（コスト計算の種別）。Flowはコストなしですので含めません。
    enum class SpellKind { kDrain, kLust, kNightmare, kConsume, kWeakness, kRavenous };

    // 減率＝スピーチ減のみです（バニラ減=半額perk/Fortify/エンチャントは除外）。0〜1・②capで頭打ちです。
    //   quiet=true＝ログを出しません（コスト列フックが高頻度で呼ぶ表示経路用）。
    float ComputeReduction(RE::Actor* caster, SpellKind kind, bool quiet = false);

    // 素コスト（減算前）＝20×①^stage×costUnit（発動系は×③）。hook/TrySpendが使います。costUnit＝costTier。
    float ComputePerSec(int costUnit);
    float ComputeBurst(int costUnit);

    // 毎tick消費します（キャッシュ済み reduction を渡します）。マジカ不足なら false です。Ravenous(CombatDrain)が使用します。costUnit＝costTier。
    bool TrySpendPerSec(RE::Actor* caster, int costUnit, float reduction);

    // ★指定呪文の costTier（裏ランクで散らす＋スキル上乗せ）＝表示(DetourCalc)とRavenous実消費(CombatDrain)で共用＝定義は1か所です。
    int CostTierFor(RE::Actor* caster, SpellKind kind);

    // ★コスト列フック（A案）＝MagicItem::CalculateMagickaCost(11213)を対象6呪文だけ
    //   横取りして独自の計算値を返します。魔法メニューのコスト列/カードに実コストが出て、バニラが
    //   詠唱時にその値で消費し、表示レベルもtierへ追従します。plugin.cpp の kDataLoaded から1回呼び出します。
    void InstallCostHook();
}
