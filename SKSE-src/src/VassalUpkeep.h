#pragma once

// ============================================================================
// VassalUpkeep ― スイート・ヴァッサルの「維持費2種」を C++ の時計(〔クロノス〕)に載せたものです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   旧＝`ASTR2PlayerAliasScript.OnUpdateGameTime` の巡回（Papyrus・6h自己再予約）の中の2ブロックです。
//   新＝〔クロノス〕 に「6ゲーム時間ごと」で定期登録します。LF減衰(LifeForceDecay)と同じ形です。
//
//   ① 死霊の維持費（1体ずつ）＝最大LF × ASTR2_VassalUpkeepRate ÷ 割引（最低1）
//        払える→払う＋ミス0／払えない→LFは引かずミス+1、3連続で塵化（C++が通知→ASTR2_VassalDiedで既存の灰化へ）
//   ② 生者の手下税＝淫紋の段階が下がった段数 × (最大LF × ASTR2_VassalTaxRate ÷ 割引)。足りなければLF0まで
//        淫紋の段階＝寵愛残り(ASTR2_VassalLastLove / ASTR2_VassalLoveDays)から Sigil::UpdateNpcSigil で更新
//   割引 = 1 + (サキュバスLv-1)×0.1 + Hスキルの総合ランク×0.05（旧Papyrusと同式）
//   ✨ 召喚スキル経験値 = **割引前**の規定額（最大LF×率）× 0.1（固定・MCM化しません）
//
//   手下の一覧＝追従クエスト ASTR2VassalFollowQuest(0101D7DC) のエイリアス枠です（死霊も生者も必ず入ります）。
//   死霊/生者の区別＝〔SkyVault〕 ASTR2_VassalLiving（0=死霊/1=生者・Papyrusが書きます）。召喚体フラグはロード後に戻る恐れがあるので使いません。
//   〔門番〕：サキュバスです／デメリットON（〔SkyVault〕 ASTR2_DisadvantagesOn）。死体(IsDead)はPapyrus巡回が灰化します。
//
//   〔SkyVault〕キー（holder=0 は設定・holder=手下 はその子の状態）
//     設定 : ASTR2_VassalUpkeepRate(F 0.01) / ASTR2_VassalTaxRate(F 0.01) / ASTR2_VassalLoveDays(I 3)
//            ASTR2_VassalUpkeepNotifyPaid(I 0) / ASTR2_VassalUpkeepNotifyMiss(I 1)
//     個別 : ASTR2_VassalLiving(I) / ASTR2_VassalUpkeepMiss(I) / ASTR2_VassalSigilLvl(I 6) / ASTR2_VassalLastLove(F 日) / ASTR2_VassalHasSchlong(I)
// ============================================================================

namespace RE::BSScript { class IVirtualMachine; }

namespace VassalUpkeep
{
    // kDataLoaded 後（Chronos::Install の後）に呼びます＝定期ジョブを登録します。
    void Install();
    // Papyrusネイティブ ASTR2Native.ArmVassalLoveTimer（生者の寵愛切れ死タイマー張り替え）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);

    // 🧟 スイート・ヴァッサルの「今の蘇生可能日数」＝計算の単一の正です(徹底して二重に持ちません)。
    //   Papyrus ASTConjCost.CalcVassalDays（MCM表示/実挙動）と NailDesc（呪文DESC）が両方これを呼びます。
    //   式 = min(999, baseDays[〔SkyVault〕 ASTR2_VassalBaseDays] × サキュバスLv × (1+召喚/100))。
    float VassalDaysNow();
}
