#pragma once

// =====================================================================================
//  CombatDrain ― 戦闘ドレイン（破壊魔法・濃縮ビーム）の「核」をC++で実装します。
// -------------------------------------------------------------------------------------
//  動機＝旧Papyrus(ASTR2DrainTrigger.RegisterForUpdate(1.0)→ASTDrainScript.Drain())は
//        ①最初の吸収が+1秒後になります ②戦闘中はVM渋滞で1秒tickが数秒に伸びます＝「当てても吸わない」体感です。
//  設計＝HDrainの手本を踏襲します。ビームのMGEF(01013622/Absorb)はそのまま＝Papyrusは開始/終了の合図だけです：
//        ASTR2DrainTrigger.OnEffectStart → CombatDrainBegin(caster, target, canKill)
//        ASTR2DrainTrigger.OnEffectFinish → CombatDrainEnd(target)
//        ★殺害可否(canKill)はBegin時にPapyrus CanKillTarget()で1回算出して渡します
//          （C++でMCM AllowKill*/StorageUtil WasEnemy/faction判定を再実装しません＝最小＆忠実です）。
//  hot(このモジュール)＝〔クロノス〕実時間で「当てて+1秒→以後1秒ごと」に定刻でドレインします（VM渋滞に非依存です）。
//        威力式は ASTDrainScript.Drain() の戦闘枝を1:1移植（破壊係数×耐性×サキュバス・ウィークネス×アラウジング・ラスト×Hスキル総合）→
//        HP減→術者回復＋余剰LF×tier→LFプール加算(〔SkyVault〕)。
//  後処理(Papyrus OnCombatDrainDone・1秒に1回＝旧と同頻度)＝おまけXP/LF-XP/破壊育成/総吸収記録/FX/バー更新。
//        殺害は Papyrus KillTarget(Essential処理込み)へ委譲します（稀イベントですので遅延は許容します）。
//        結果値(absorbed/acceptedLF/killed/lfFull)は 〔SkyVault〕(sender=npc)へ置いて完了modeventを送出します。
//
//  入力の出どころ（全てC++可読）：LF/ドレインつまみ=〔SkyVault〕 ／ tier=ServantTier::Get ／
//    Hスキル総合rank=TechRank::GetDisplayTotalRank ／ Lv=global直読み ／ サキュバス・ウィークネス・アラウジング・ラスト=対象の効果を直検査。
// =====================================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace CombatDrain {
    // 〔クロノス〕実時間チェッカを張ります＝データロード後に1回（plugin.cpp から）。
    void Install();
    // Papyrus native（CombatDrainBegin / CombatDrainEnd）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝MCM getterと同じ実体です（重複なし・NailDescから呼びます）。
    float RavenousRangeM();    // 効果範囲(m・半径)です
    int   RavenousMaxTgts();   // 同時吸引の最大人数です
    int   DrainBaseNow();      // 🩸 ドレイン基礎量/秒 2+(Lv-1)×8（サキュバス・ドレイン/ラヴェナス・ドレインの威力表示・計算の定義は1か所です）
    float RegenPctNow();       // 💧 コンスーム・エッセンスの回復%/秒（計算の定義は1か所です）
    int   WeaknessResistDownNow(); // 🩸 サキュバス・ウィークネスの耐性ダウン実効値（計算の定義は1か所です）
}
