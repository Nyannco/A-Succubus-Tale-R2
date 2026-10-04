Scriptname ASTR2RevivingGraceEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =========================================================
; 💋 リヴァイヴィング・グレイス（Reviving Grace／レッサーパワー・セルフ）
;   自分に唱える→クロスヘアの相手が「LivingReadyな死霊ヴァッサル」なら生者化を試みます。
;   死霊（DeadThrall）はEでトレードが開き会話が構造的に出せないため、入口を会話からパワーへ移します。
;   実処理はすべて ASTConjCost.TryReviveVassal（安全判定→OStimキス→ConvertVassalToLiving）へ委譲します。
;   ここはクロスヘア取得＋対象の資格判定（会話条件の代わり）だけです。
; =========================================================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; 💜 淫魔力（LF）不足なら何もしません（キスも始めません）。コストは最大LFの10%。支払いは生者になったときだけ(ASTConjCost.DoReviveConvert)。
    ASTR2LifeForceBarScript lfQuest = ASTR2LifeForceBarScript.Get()
    If lfQuest != None
        Int cost = (lfQuest.LFenergyMax * 0.10) as Int
        If lfQuest.LFenergyCurr < cost
            Debug.Notification("$ASTR2_Debug_NotEnoughLF")
            Return
        EndIf
    EndIf
    Actor npc = Game.GetCurrentCrosshairRef() as Actor
    ; 旧・会話条件の再現＝プレイヤーの死霊ヴァッサル(living=0)かつLivingReadyだけ通す。
    Faction livingReady = Game.GetFormFromFile(0x0101E81B, "A Succubus Tale R2.esp") as Faction
    Bool ready = false
    If npc != None && npc != akCaster && livingReady != None
        If StorageUtil.FormListHas(akCaster, "ASTR2_VassalList", npc) && SkyVault.GetInt(npc, "ASTR2_VassalLiving", -1) == 0 && npc.IsInFaction(livingReady) && !npc.IsDead()   ; ★!IsDead()は横たわった死体を弾きます（残骸データがVassalList/living=0/LivingReadyを中途半端に残していてもResurrectで蘇生させない保険）
            ready = true
        EndIf
    EndIf
    If !ready
        Debug.Notification("$ASTR2_Msg_ReviveNotReady")
        Return
    EndIf
    ASTConjCost.TryReviveVassal(npc)
EndEvent
