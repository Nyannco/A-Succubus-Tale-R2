Scriptname TIF__ASTR2_GreetYes Extends TopicInfo Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

Function Fragment_0(ObjectReference akSpeakerRef)
    Actor akSpeaker = akSpeakerRef as Actor
    ; 選択肢を押した瞬間にマーカーON＝会話キャンセルと区別します（Main側のOnMenuClose判定に使います）
    ASTR2MainScript Main = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
    If Main != None
        Main.MarkGreetRouteChosen()
    EndIf
EndFunction

Function Fragment_1(ObjectReference akSpeakerRef)
    Actor akSpeaker = akSpeakerRef as Actor
    
    ; 🔵 メインスクリプトへ引き継ぎます
    ASTR2MainScript Main = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
    If Main != None
        Main.QueueLaunchOnDialogueClose(akSpeaker, 1, false)   ; 🎣 会話が閉じた瞬間に起動を予約します（OnMenuClose拾い・開始演出のちらつきを防ぎます）
    EndIf
    
EndFunction
