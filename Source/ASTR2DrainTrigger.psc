Scriptname ASTR2DrainTrigger extends ActiveMagicEffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 🩸 戦闘ドレインは濃縮ビーム(MGEF 01013622/Absorb)の駆動役です。
; ★吸収の実処理と1秒刻みはC++(CombatDrain.cpp)へ移設したため、ここは開始/終了の合図だけです。
;   OnEffectStartでC++に「このビームがこの相手に当たり始めた」を伝え、OnEffectFinishで止めます。
;   C++が実時間で「当てて+1秒→以後1秒ごと」に吸収します（戦闘中のVMの混雑に影響されず定刻に発火）。
;   威力式/耐性/弱能/ラスト/殺害/術者回復/淫魔力（LF）化はすべてC++側です。後でまとめて記録(XP/破壊育成/記録)するのは ASTDrainScript.OnCombatDrainDone です。
; ★殺害可否(canKill)はここで既存のCanKillTarget()を1回だけ算出してC++へ渡します
;   （MCM AllowKill* / StorageUtil WasEnemy はPapyrusにしかないため、C++では再実装せず最小限かつ忠実にします）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ASTDrainScript ds = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTDrainScript
    Bool canKill = false
    If ds != None
        canKill = ds.CanKillTarget(akTarget, akCaster)
    EndIf
    ASTR2Native.CombatDrainBegin(akCaster, akTarget, canKill)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    ASTR2Native.CombatDrainEnd(akTarget)
EndEvent
