Scriptname ASTR2CharmMinionMark extends ActiveMagicEffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 魅了した相手(サキュバス・チャーム/Charm・60秒)を「使役中のミニオン」として印付けします。ActiveMinionFaction
; (0101D278)に加えます。印が付いている間はASTDrainScript.CanKillTargetがFalseを返します。ドレインの
; フィニッシュも戦闘ドレインもこの相手を殺しません(floorで助かる)。印は魅了が切れると外れます。
; 再び殺せるようになります。自律設計で、ファクションはGetFormFromFileで解決し、このスクリプトをCharmの
; マジックエフェクトに付けるだけで済みます(配線するプロパティなし・スクリプト名だけ)。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akTarget != None
        Faction minionFac = Game.GetFormFromFile(0x0101D278, "A Succubus Tale R2.esp") as Faction
        If minionFac != None
            akTarget.AddToFaction(minionFac)
        EndIf
    EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    If akTarget != None
        Faction minionFac = Game.GetFormFromFile(0x0101D278, "A Succubus Tale R2.esp") as Faction
        If minionFac != None
            akTarget.RemoveFromFaction(minionFac)
        EndIf
    EndIf
EndEvent
