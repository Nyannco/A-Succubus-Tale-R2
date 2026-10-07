Scriptname ASTR2Make3pScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 💡 完全自律型呼び出しメソッド（FormIDはCreation Kitで割り当てたQuestのものに書き換えてください）
ASTR2Make3pScript Function Get() Global
    return Game.GetFormFromFile(0x013B9E, "A Succubus Tale R2.esp") as ASTR2Make3pScript
EndFunction

; 🌟 候補者マーカーFactionをGetFormFromFileで直引きします。FormID 0x013BA5（SSEEdit確認済）。
;   Autoプロパティを使わないのは、VMAD割り当てが不要で、旧セーブへのNone焼き込みも避けられるためです。
Faction Function GetCandidateFaction() Global
    return Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
EndFunction

; =========================================================
; 🎯 候補者リストへの追加と削除
; =========================================================

; 魅了した時に呼びます（候補者入り）
Function AddCandidate(Actor akTarget)
    Faction candFac = GetCandidateFaction()
    If akTarget != None && candFac != None
        akTarget.AddToFaction(candFac)
    EndIf
EndFunction

; 魅了が解けた・シーンが終わった時に呼びます（候補者から外す）
Function RemoveCandidate(Actor akTarget)
    Faction candFac = GetCandidateFaction()
    If akTarget != None && candFac != None
        akTarget.RemoveFromFaction(candFac)
    EndIf
EndFunction
