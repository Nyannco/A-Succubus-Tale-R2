Scriptname ASTR2VassalAliasScript extends ReferenceAlias
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 🧟 スイート・ヴァッサルの追従スロット用です（ASTR2VassalFollowQuest 0101D7DC の各 ReferenceAlias に付けます）。
;   このスロットの手下が死んだ瞬間に後始末します（死霊は灰化／生者は死体が残ります・どちらも印を巻き戻しDeleteはしません）＝戦闘死などへの即時対応です。
;   ★巡回(6hゲーム時間)はスロット外の取りこぼし用バックストップで、即時対応はこのaliasが主に担います。

Event OnDeath(Actor akKiller)
    Actor v = GetActorReference()
    If v == None
        Return
    EndIf
    ASTConjCost.AshifyVassal(v)   ; 後始末を一括で行います（印を基テンプレへ巻き戻し・VassalList除去・スロット解放／死霊は灰化・生者は死体・Deleteはしません）
EndEvent
