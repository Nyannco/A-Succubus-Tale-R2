;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname TIF__0101F851 Extends TopicInfo Hidden

;BEGIN FRAGMENT Fragment_0
Function Fragment_0(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
ASTR2MainScript Main = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
If Main != None
    Main.QueueLaunchOnDialogueClose(akSpeaker, 1, true)
EndIf
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment
