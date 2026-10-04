#pragma once

// =====================================================================================
//  Fury ― アンリーシュド・フューリー（Voice パワーのトグル・チャネル）
// -------------------------------------------------------------------------------------
//  入口＝SPEL 00B4AA(Lesser Power/Voice) → PowerResetのSpellCastフックが実発動の瞬間に
//        Fury::Toggle() を呼びます＝押すたびにON/OFFを切り替えます（OnEffectStart駆動でなくSpellCastに一本化）。
//        （マジカ再生+20%は 00B4A7 の PeakValueMod/MagickaRate が従来どおり出します＝固定・別管理です）
//  ON  ＝サキュバスLvで解放された強化を適用し、毎秒LF消費を開始します（〔クロノス〕実時間1秒）。
//  OFF ＝再押し／LF0／覚醒OFF のどれかで解除します＝強化を全て撤去し、「累計消費LF×10%」を変性XPへ加算します。
//
//  維持コスト＝最大LF × (11-Lv)×0.1%/秒（Lv10=0.1%…Lv4=0.7%・習熟すると安くなります）。
//  強化（Lvで解放）：
//    Lv4 破壊+ / Lv5 移動×1.5・ジャンプ×2.0・落下耐性% / Lv6 回復+・魔法耐性%
//    Lv7 召喚+ / Lv8 幻惑+ / Lv9 変性+ / Lv10 ダメージカット%
//    ★スキル+(式B)= 基礎(MCMスライダー ASTR2_FuryBase) × (1 + Lv×0.2 + tier3人数 + 変性/100)
//    ★％項目(式A・cap100)= 10 × (1 + Lv×0.1 + tier3人数×0.3 + 変性/100)  ← 魔法耐性/落下耐性/ダメカ
//    ★移動/ジャンプ＝固定倍率／マジカ再生+20%＝MGEF側（触りません）
//  入力(全てC++可読)：Lv=global直読み／変性=player AV／tier3人数=〔SkyVault〕ASTR2_Tier3Count／
//    基礎値=〔SkyVault〕ASTR2_FuryBase（MCM）／LF=〔SkyVault〕。
//  ★覚醒契約：UnSuccuby(覚醒OFF)が FuryForceOff() を呼びます＋毎秒tickでも ASTR2_Awake==0 なら自動OFFになります。
// =====================================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace Fury {
    void Install();
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
    // ON/OFFトグル（ゲームスレッドで実行）。PowerResetのSpellCastフックが実発動の瞬間に呼びます＝
    //   OnEffectStartの再発火に依存せず、再キャストで確実に切り替えます（旧native FuryToggle経由は撤去済＝SpellCastに一本化）。
    void Toggle();

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝MCM getterと同じ実体です。重複なし・NailDescから呼びます。
    std::int32_t FuryBoostNow();    // 式B＝5スキル共通+N
    std::int32_t FuryResistNow();   // 式A＝%耐性(魔法/落下/ダメカ・cap100)
    std::int32_t FuryCostNow();     // 維持 淫魔力/秒
}
