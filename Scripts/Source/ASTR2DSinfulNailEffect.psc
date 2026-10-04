Scriptname ASTR2DSinfulNailEffect extends activemagiceffect

; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; シンフル・ネイル（Sinful Nail）Lv1パワーのMGEF（0x02089B）です（1日1回のPower・Spell 0x02089D）。
; 発動すると、気分を訊いて選んだカテゴリからネイルを1本配布して装備します（コンプリート後は4択で「自由に選ぶ」も可能）。
; ロジックは ASTR2NailManager に閉じます（ディスティル・エッセンス（ASTR2DistillEssenceEffect）と同じ流儀）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akTarget != Game.GetPlayer()
        Return
    EndIf
    ASTR2NailManager mgr = ASTR2NailManager.Get()
    If mgr != None
        mgr.DailyMoodGrant()
    EndIf
EndEvent
