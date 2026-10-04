#pragma once

// ============================================================================
// SpellInfo ― 〔アレテイア〕呪文DESC / MCM表示 用の「現在値getter」の集約です。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   各呪文の実数を「計算の単一の正」としてC++に置き、Papyrus(MCM/実挙動)と NailDesc(呪文DESC) が
//   両方これを呼びます＝式の二重持ちを解消します。材料は全てC++可読（Lv=global / AV=player / 〔SkyVault〕 / TechRank）。
//   StorageUtil依存だった値は 〔SkyVault〕 へ移設して同一キーを共有します。
// ============================================================================

namespace RE::BSScript { class IVirtualMachine; }

namespace SpellInfo {
    // Papyrusネイティブを登録します（ASTR2Native.GetNightmareChanceNow 等）。plugin.cpp から呼びます。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // 🌙 ナイトメア・エンブレイスの成功確率(base・対象なし)＝(nmBase+(Lv-1)×nmPerLv)×(1+腰使いcat0×0.05) cap100。単一の正です。
    int NightmareChanceNow();

    // 🩷 セダクション3種(ウィスパー・セダクション/エリア・セダクション/マス・セダクション)の基本スパイク量＝(SedBase+(Lv-1)×SedStep)×(1+攻め技cat6×0.05)。単一の正です。
    float SeductionSpikeNow();

    // 💋 アラウジング・ラストの興奮注入(素)＝LustBase×Lv。単一の正です。
    int LustArousalNow();

    // 🍯 ディスティル・エッセンス(Distill)のサイズ別コスト(size 0=Petty/1=Lesser/2=Common/3=Greater/4=Grand)＝計算の単一の正です。
    //   psc(ASTR2DistillEssenceEffectの支払い)もNailDesc(呪文DESC)も共用します＝旧Autoプロパティ+ハードコピーの二重持ちを解消しました。
    int DistillLifeCost(int size);
    int DistillManaCost(int size);

    // 💎 クリエイト・シャード(Shard)のサイズ別"素"淫魔力コスト(size 0=Petty..4=Grand)＝計算の単一の正です。
    //   psc(ASTR2CreateShardEffectの支払い/GetShardCost)もNailDesc(呪文DESC)も共用します＝リテラル三重持ちを解消しました。
    //   実支払いは別途 MCMスライダー ShardCostMult を掛けます(素コストはこれです)。
    int ShardLifeCost(int size);
}
