Scriptname ASTSedMagEffScript extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

Actor TargetActor
ASTR2MainScript Main

; 発動制限（1日1回）はバニラのGreater Powerが管理します（このスクリプトはクールダウンを持ちません）。

; =========================================================
; 📋 アビリティ一覧用のゲッターです（威力の実数）。
;   魅了の「基本の色気注入量」＝base+(Lv-1)×step の素の値です（得意な性別への加点・〔サーヴァントシップ〕のティア・LFブーストは抜き）。
;   ＝1ヒットでarousalにどれだけ色気を注入するかです。〔魅了ライン〕(seductionLinef・既定99前後)に届けば陥落します。
;   O(1)なので表示時に計算して問題ありません。MCMのアビリティ一覧が呼びます：ASTSedMagEffScript.GetBaseSeductionSpike()
; =========================================================
Float Function GetBaseSeductionSpike() Global
    ; 計算の単一の正はC++(src/SpellInfo.cpp SeductionSpikeNow)にあります（定義を二重に持たないため）。MCM表示・呪文DESCで共用します。
    ; 　材料base/stepは〔SkyVault〕(ASTR2_SedBase/ASTR2_SedStep)・攻め技6ランクもC++が同値(GetTechRank(6)相当)で通します。
    Return ASTR2Native.GetSeductionSpikeNow()
EndFunction

; =========================================================
; 🌟 魔法が当たった瞬間です。
; =========================================================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    TargetActor = akTarget
    Main = ASTR2MainScript.Get()

    ; すでに魅了済みかを見ます（エリアとマスの二重ヒットで二重付与しないため）。
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    Bool alreadyCharmed = (CandidateFaction != None && akTarget.IsInFaction(CandidateFaction))

    ; 発生源のMagicEffect(SKSE GetBaseObject)で3種を判別します（単体0x002DB2 / エリア0x00BA10 / マス0x004E03）。
    String sedName = "?"
    MagicEffect srcEff = GetBaseObject()
    If srcEff == Game.GetFormFromFile(0x002DB2, "A Succubus Tale R2.esp") as MagicEffect
        sedName = "Single"
    ElseIf srcEff == Game.GetFormFromFile(0x00BA10, "A Succubus Tale R2.esp") as MagicEffect
        sedName = "Area"
    ElseIf srcEff == Game.GetFormFromFile(0x004E03, "A Succubus Tale R2.esp") as MagicEffect
        sedName = "Mass"
    EndIf

    ASTR2Make3pScript Make3p = ASTR2Make3pScript.Get()

    ; === 🔥 色気注入（アロウザル加算）→ 〔魅了ライン〕判定（〔門番・ゲート〕）===
    ; 読み書きはOSLのグローバルAPIを直接使います（0x800経由の Main.modifyArousal は機能しないため使いません）。
    ; S = base + (Lv-1)*step + 得意な性別への加点。注入後 arousal が L に達したら陥落、未達は持ち越します。
    Float kLine  = Main.seductionLinef    ; 〔魅了ライン〕（到達で陥落・MCMで可変）
    Float kBonus = Main.seductionBonusf   ; 得意な性別への加点（得意な性別を狙った時）
    ; 基本の色気注入量は GetBaseSeductionSpike() が〔SkyVault〕経由で読みます（定義を二重に持たず、MCMへの移設に追従するため）。

    Float intended = 0.0   ; 届かせた色気＝失敗通知でも使うので関数レベルへ巻き上げます（OSL未導入時は0のまま＝失敗通知には到達しません）。
    Float spike = 0.0      ; この一撃の色気注入量＝幻惑XPの素です（成功30+spike/失敗spike半分）。関数レベルへ巻き上げます（OSL未導入時0＝成功なら30固定）。
    Bool charmedNow = true   ; OSL未導入環境では〔門番・ゲート〕を通せないため、従来通り即魅了でフォールバックします。
    If Main.isOArousedInstalled
        Int sucLvl = Main.SuccubusLvl.GetValueInt()

        ; 得意な性別への加点＝Hスキルの指向設定(ASTR2_TechOrient)に合わせます＝プレイヤーが選んだ指向で「得意」が決まります。
        ;   性別はOStim基準のAppearsFemale（フタもHスキルと同じく♀扱い）。デフォルトは体依存です(フタ=両刀/男女=異性愛・CurOrient内)。
        Bool casterFemale = OUtils.AppearsFemale(akCaster)
        Bool targetFemale = OUtils.AppearsFemale(akTarget)
        Bool sameSex = (casterFemale == targetFemale)
        Int techOrient = ASTR2Technique.CurOrient()
        Bool preferred = false
        If techOrient == 2
            preferred = true              ; 両刀＝誰でも得意です。
        ElseIf techOrient == 1
            preferred = sameSex           ; 同性愛＝同性が得意です。
        Else
            preferred = !sameSex          ; 異性愛＝異性が得意です。
        EndIf

        ; 基本の色気注入量＝getter経由(ASTR2Native.GetSeductionSpikeNow＝base+(Lv-1)*step×攻め技6)で取ります。計算の単一の正はC++/〔SkyVault〕です（定義を二重に持たず、MCM移設に追従）。得意な性別への加点・ティア・LFは補正後に加算します。
        spike = ASTSedMagEffScript.GetBaseSeductionSpike()
        If preferred
            spike += kBonus
        ElseIf sucLvl > 10
            ; Lv11以降は、得意でない性別もLvに応じて段階的に加点を得ます＝性別差を埋めます。
            ;   Lv20で+kBonus満額(得意と同等)→以降はオーバーフロー(arousal上限は触らず振り切る)＝高Lvは誰でも落とせます。
            spike += kBonus * ((sucLvl - 10) as Float) / 10.0
        EndIf
        spike += ASTR2Servantship.GetSeductionBonus(akTarget)   ; 〔サーヴァントシップ〕のティアボーナス(0/4/8/12/16)＝H重ねた相手ほど落ちやすいです。

        ; LF状態ボーナス：術者(PC)が生命力満タンほど色気が上がります（0〜+kLFBonus）。サキュバス・ドレイン→高LF→魅了の好循環です。
        Float kLFBonus = 10.0   ; 満タン時の最大上乗せです（将来アビリティコンフィグに加えるか検討中です）。
        ASTR2LifeForceBarScript LFBar = ASTR2LifeForceBarScript.Get()
        If LFBar != None && LFBar.LFenergyMax > 0
            spike += kLFBonus * ((LFBar.LFenergyCurr as Float) / (LFBar.LFenergyMax as Float))
        EndIf

        ; 💅 色欲のネイル(idx2)＝魅了の色気注入量に加算（Lv連動・Lv100で+10%／魅了は既にインフレ気味なので控えめ）。
        If SkyVault.GetInt(None, "ASTR2_NailActive_2", 0) == 1
            spike *= (1.0 + (sucLvl as Float) * 0.001)   ; Lv100=+10%（Lv1=+0.1%）
        EndIf

        Float preArousal = OSLArousedNative.GetArousal(akTarget)   ; 注入前の値です(満足度クランプ込みの現状)。
        OSLArousedNative.ModifyArousal(akTarget, spike)
        intended = preArousal + spike                        ; サキュバスが届かせた色気＝判定の真値です。OSLの動的上限に潰されません(満足相手の取りこぼし防止)。
        charmedNow = intended >= kLine
        ; 💠 取り放題（愛玩tier4）＝魅了は常時成功します（arousal無関係＝いつでも落とせます）。
        If ASTR2Servantship.GetTier(akTarget) >= 4
            charmedNow = true
        EndIf
    EndIf

    ; 既に魅了済み（エリアとマスの二重ヒット等）＝二重付与しません。色気注入は入れたので終了します。
    If alreadyCharmed
        Return
    EndIf
    ; 新規だが〔魅了ライン〕未達＝まだ落とせません（Arousalは上がっているので次の機会へ持ち越します）。
    If !charmedNow
        ; 🔮幻惑魔法XP（失敗）＝上げた興奮(spike)の半分・切り捨て（成功=30+spike/失敗=spike÷2/dup=0／行き先=幻惑Illusion）。
        Float failXp = ((spike * 0.5) as Int) as Float
        Game.AdvanceSkill("Illusion", failXp)
        ; 失敗通知＝「○○を魅了できなかった (色気/ライン)」です。名前+数字はLocFmtStrで完成文字列にして渡します。
        String[] sedFailArgs = new String[3]
        sedFailArgs[0] = akTarget.GetDisplayName()
        sedFailArgs[1] = (intended as Int) as String
        sedFailArgs[2] = (kLine as Int) as String
        Debug.Notification(ASTR2Native.LocFmtStr("$ASTR2_Debug_NotSeduced", sedFailArgs))
        ; 失敗＝かかった魅了スペルを解除して「もやもや」視覚エフェクトを残しません。
        ;   （arousal上昇はOSL側に入っているのでDispelしても維持＝下地作りは残ります）。
        Spell failSp = None
        If sedName == "Single"
            failSp = Game.GetFormFromFile(0x002DB3, "A Succubus Tale R2.esp") as Spell
        ElseIf sedName == "Area"
            failSp = Game.GetFormFromFile(0x00BA13, "A Succubus Tale R2.esp") as Spell
        ElseIf sedName == "Mass"
            failSp = Game.GetFormFromFile(0x004E05, "A Succubus Tale R2.esp") as Spell
        EndIf
        If failSp != None
            akTarget.DispelSpell(failSp)
        EndIf
        Return
    EndIf

    ; === ここから魅了確定（新規）===
    ; 🔮幻惑魔法XP（成功）＝基礎30＋上げた興奮(spike・超過込み)（成功=30+spike/失敗=spike÷2/dup=0／行き先=幻惑Illusion）。
    Float okXp = 30.0 + spike
    Game.AdvanceSkill("Illusion", okXp)
    ; 共通：候補者リストに登録します（013BA5＝会話/識別の必須キー）。
    If Make3p != None
        Make3p.AddCandidate(akTarget)
    EndIf

    ; 🌟 味方化＋Followで群れを寄せる方式：初回ヒット時だけ Allyファクションと集合パッケージを付与します。
    ; この If は実質常に真です（上の alreadyCharmed 分岐で Return 済のため、ここでは必ず !alreadyCharmed）。
    If !alreadyCharmed
        ; 0100433D＝MSRTPlayerAllyFaction（敵対せず素直に追従させます）。
        Faction AllyFaction = Game.GetFormFromFile(0x0100433D, "A Succubus Tale R2.esp") as Faction
        If AllyFaction != None
            akTarget.AddToFaction(AllyFaction)
        EndIf

        ; 敵対NPC対策：戦闘中に魅了された相手を鎮静します（市民なら実害なし）。
        ; 魅了前の状態を記録します（クリーンアップでAggressionを復元／サキュバス・ドレインで“元敵”を殺せるように）。
        StorageUtil.SetFloatValue(akTarget, "ASTR2_OrigAggr", akTarget.GetActorValue("Aggression"))
        StorageUtil.SetIntValue(akTarget, "ASTR2_WasEnemy", ((akTarget.IsHostileToActor(akCaster) || akTarget.IsInCombat()) as Int))
        akTarget.SetActorValue("Aggression", 0)   ; 敵対心0＝自分から攻撃しなくなります。
        akTarget.StopCombat()
        akTarget.StopCombatAlarm()

        Package FollowPack = Game.GetFormFromFile(0x00433C, "A Succubus Tale R2.esp") as Package

        ; FollowPlayer＝ON/OFF共通（集合＆観客）。優先度90＝NPCの定位置帰り(ベースAI)に勝って留まり／ForceGreet(100)には負けます＝挨拶アプローチは維持します。
        ; ForceGreet（話す権利）はここでは付けません＝OFFは会話の引き継ぎ方式で最寄り1人だけに後付けします（Main.GrantGreetToken／魅了直後にScheduleGreetTokenで遅延予約＝マス束ね）。
        ;   集める(Follow=全員)と話す権利(ForceGreet=1人)を分離します＝群れの会話割り込み・バニラ会話割り込みを根絶します。ONは元々ForceGreet無し＝無改変です。
        If FollowPack != None
            ActorUtil.AddPackageOverride(akTarget, FollowPack, 90)
        EndIf

        akTarget.EvaluatePackage()
    EndIf

    ; ONループのキックです（OFFはパッケージ任せなのでMain側は何もしません）。
    ; ※3択ダイアログ用クエスト(Make3p)はSSEEditで"Start Game Enabled"確認済＝常時起動なのでスクリプト起動は不要です。
    If Main != None
        Utility.Wait(0.1)
        Main.ReceiveMagicTarget(akTarget)
    EndIf
EndEvent


; =========================================================
; 🧹 クリーンアップ処理
; =========================================================
Event OnEffectFinish(Actor akTarget, Actor akCaster)
    CleanUp()
EndEvent

Function CleanUp()
    If TargetActor
        ASTR2Make3pScript Make3p = ASTR2Make3pScript.Get()
        If Make3p != None
            Make3p.RemoveCandidate(TargetActor)   ; 013BA5を剥奪
        EndIf

        ; 0100433D＝Allyファクションも剥奪
        Faction AllyFaction = Game.GetFormFromFile(0x0100433D, "A Succubus Tale R2.esp") as Faction
        If AllyFaction != None
            TargetActor.RemoveFromFaction(AllyFaction)
        EndIf

        ; 魅了前のAggressionへ復元します（“もやもや解除後も殺せない”を防ぐため）。
        ; ※OStimシーン中は復元しません＝敵が興奮中に再敵対→攻撃→OStimでCTDを防ぎます（シーン後は鎮静のまま／サキュバス・ドレインのwasEnemyは残るので殺せます）。
        If !OActor.IsInOStim(TargetActor)
            Float origAggr = StorageUtil.GetFloatValue(TargetActor, "ASTR2_OrigAggr", -1.0)
            If origAggr >= 0.0
                TargetActor.SetActorValue("Aggression", origAggr)
            EndIf
            StorageUtil.UnsetFloatValue(TargetActor, "ASTR2_OrigAggr")
            StorageUtil.UnsetIntValue(TargetActor, "ASTR2_WasEnemy")
        EndIf

        TargetActor.BlockActivation(false)
        
        Package FollowPack = Game.GetFormFromFile(0x00433C, "A Succubus Tale R2.esp") as Package
        Package ForceGreetPack = Game.GetFormFromFile(0x01410C, "A Succubus Tale R2.esp") as Package
        
        If FollowPack != None
            ActorUtil.RemovePackageOverride(TargetActor, FollowPack)
        EndIf
        If ForceGreetPack != None
            ActorUtil.RemovePackageOverride(TargetActor, ForceGreetPack)
        EndIf

        TargetActor.EvaluatePackage()
    EndIf
EndFunction

