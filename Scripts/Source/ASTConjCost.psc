Scriptname ASTConjCost extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; スイート・ヴァッサルは Aimed spell（球を撃つ呪文）です。このスクリプトは SPEL 0100BF77 の Script効果(MGEF 0101D7F4)に付く「ロジック役」です。
; ★起こす処理は同じスペルの Reanimate効果(MGEF 0100BF75)がエンジンで直接行います。ここでは起こしません。
;   仕事は、死体/クエストNPCをガードして常に死霊として登録することです（生者化はキス、すなわち Reviving Grace で行います）。Lv9かつ999日ではLivingReadyを付与します。これはキス生者化の資格の目印です。
;   ★LFコストは発射の瞬間にC++(PowerReset.cpp SpellCastフック)が判定・支払いします。ここでは見ません。
; Duration(未熟灰化)/寵愛切れは ASTR2PlayerAliasScript の巡回が見ます（瞬間effectでタイマーを保持できないためです）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    Actor player = Game.GetPlayer()

    ; 🎯 球が当たった相手が akTarget です。死体NPCなら蘇生します（起こしは同じスペルのReanimate効果=00BF75がエンジンで実行します）／生者・自分・None は何もしません。
    If akTarget == None || akTarget == player
        StopReanimFX(akTarget)   ; 自分/None に当たった場合は、もや(075272)を残しません
        Return
    EndIf
    If !akTarget.IsDead()
        ; 生者に当たった場合、Reanimate効果はエンジンが空振りします（起きていません）。もやだけ外して終わりです。
        StopReanimFX(akTarget)
        Debug.Notification("$ASTR2_Msg_VassalTargetAlive")   ; 生者に当たった場合、対象が生きているので失敗です
        Return
    EndIf
    Actor corpse = akTarget

    ; 🚫 クエストのエイリアスに入っている相手は蘇生しません。
    ;   バニラのクエストスクリプトは「その相手はすぐ死ぬ」前提でOnHit等を無防備に書いています（判定がイベントの"中"にあり
    ;   、誰の攻撃でも必ずスタックが1本立ちます）。永続化すると鳴り止まなくなり、VM飽和→running 126,041・papyrusMem 248%
    ;   →セーブ中にCTDしました（実機で確認しました。例はカルティストやDLC2WE09ActorScriptです）。バニラのReferenceAliasスクリプト977本中
    ;   98本がOnHitを持ちます。珍しい事故ではないので、入口で弾きます。エイリアスを外す(Clear)案はクエストを壊す危険が
    ;   後々まで残るので不採用としています。
    ;   ★Reanimate効果は命中で既に起こし始めているので、CancelRaise で崩して巻き戻します（登録前なので味方の印は無く、軽いです）。
    If IsHeldByForeignQuest(corpse)
        Debug.Notification("$ASTR2_Msg_VassalQuestNpc")
        CancelRaise(corpse)
        Return
    EndIf

    ; 💜 LFコストはここでは見ません。発射の瞬間にC++(PowerReset.cpp SpellCastフック)が判定・支払い済みです
    ;   （仕様は「起動→コストチェック→発射」です。不足なら弾自体が出ないので、この効果は来ません）。

    ; 🧟 着弾した時は常に死霊として蘇生します（生者化はキスの時だけで、これが Reviving Grace です）。
    ;    sucLv は、下の「Lv9かつ999日ならLivingReadyを付与する（キス生者化の資格）」という判定に使います。
    ;    CalcVassalDaysは内部で自前にLvを読むので、ここのsucLvには依存しません。
    ASTLvlManager lvlMgr = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    Int sucLv = 1
    If lvlMgr != None
        sucLv = lvlMgr.SuccubusLvl.GetValueInt()
    EndIf

    ; 🧟 死霊として登録します（死霊のまま操り人形にします）。生者化しないため OnVassalRisen は飛びません。そこで、ここで登録します。
    Faction minionFac = Game.GetFormFromFile(0x0101D278, "A Succubus Tale R2.esp") as Faction
    If minionFac != None
        corpse.AddToFaction(minionFac)   ; 吸い殺しから守る手下マーカーを付けます
    EndIf
    StorageUtil.FormListAdd(player, "ASTR2_VassalList", corpse, False)   ; False=重複不可。同じ子の二重登録を防ぎます（キル漏れや撃ち直しによる重複への対策です）
    SkyVault.SetFloat(corpse, "ASTR2_VassalRaiseTime", Utility.GetCurrentGameTime())   ; 蘇生時刻です。未熟Duration切れ判定の起点になり、★〔SkyVault〕としてC++維持費の個別化も読みます
    StorageUtil.SetFloatValue(corpse, "ASTR2_VassalDays", CalcVassalDays())                     ; 使役日数です。<999は未熟で、切れたら灰化します
    SkyVault.SetInt(corpse, "ASTR2_VassalLiving", 0)                                            ; 0は死霊です。★〔SkyVault〕としてC++ VassalUpkeepも読みます
    SkyVault.SetInt(corpse, "ASTR2_VassalUpkeepMiss", 0)                                        ; 維持費の連続未払い回数です（撃ち直しで前の子の残りを持ち越しません）
    ASTR2Native.UpkeepStart()   ; ▶️ 死霊を作ったので維持費ジョブを稼働します（0体で止まっていても再開します）
    If sucLv >= 9 && CalcVassalDays() >= 999.0
        ; 💋 Lv9以上 かつ 死霊維持可能日数999到達（高サキュバスLv または 大きく上がった召喚）で起こした死霊は、キスで生者化できます。
        ;    具体的には、LivingReadyファクションに入れます（Reviving Graceの資格判定の目印です）。起こした時点で判定し、動的更新はしません。
        Faction livingReady = Game.GetFormFromFile(0x0101E81B, "A Succubus Tale R2.esp") as Faction   ; ASTR2_LivingReadyFaction
        If livingReady != None
            corpse.AddToFaction(livingReady)
        EndIf
    EndIf
    AssignVassalSlot(corpse)   ; 🧷 死霊もスロットへ入れ、alias OnDeathで「死亡即掃除」の対象にします（＋追従packageも付きます）。
EndEvent

; 🚫 その相手が「他MOD/バニラのクエストのエイリアス」に入っているかを調べます。入っていたら蘇生させません。
;    ASTR2自身のクエスト(スイート・ヴァッサルの追従クエスト等)は除外します。前に手下だった子を蘇生し直せなくなるのを防ぎます。
;    判定では、ASTR2のFormID上位バイト(ロード順)と同じ範囲のクエストを"自分のもの"とみなします。
;    ログには相手/クエスト/そのエイリアスに付いているスクリプト名まで残します。何に弾かれたかが後で分かります。
Bool Function IsHeldByForeignQuest(Actor akRef) Global
    Alias[] als = PO3_SKSEFunctions.GetRefAliases(akRef)
    If als.Length == 0
        Return False
    EndIf
    Form ownForm = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp")
    Int ownBase = 0
    If ownForm != None
        ownBase = ownForm.GetFormID() - 0x013617   ; ASTR2のロード順インデックス部だけが残ります
    EndIf
    Int i = 0
    While i < als.Length
        Quest q = als[i].GetOwningQuest()
        If q != None
            Int qid = q.GetFormID()
            If qid < ownBase || qid >= ownBase + 0x01000000   ; ASTR2のクエストでなければ、よそのクエストが掴んでいます
                Return True
            EndIf
        EndIf
        i += 1
    EndWhile
    Return False
EndFunction

; 🩹 失敗ヒットのもやを除去します。MGEFのHitShader(ReanimateFXShader 075272・FXPersist)はスクリプトのReturnと
;    無関係に当たった相手へ乗ります。失敗(生者/LF不足/自分)時はここで明示的に外します（成功時はgetup完了で
;    ASTR2PlayerAliasScript.OnVassalRisen が外します）。
Function StopReanimFX(Actor a) Global
    If a == None
        Return
    EndIf
    EffectShader fx = Game.GetFormFromFile(0x075272, "Skyrim.esm") as EffectShader
    If fx != None
        fx.Stop(a)
    EndIf
EndFunction

; 🩹 起きかけを巻き戻します。登録前(クエストNPC)の失敗時に、起こしかけを死体に戻します。
;    ★Dispelは起き上がりと同フレーム競合で空振りし、灰化/塵化は放棄済みです。C++が起き上がり完了を見張ってKillし、死体が転がります。
;    まだ味方の印もVassalListも付いていない新鮮な起こしなので、お掃除(ResetActor)は不要で軽いです。
Function CancelRaise(Actor a) Global
    If a == None
        Return
    EndIf
    ASTR2Native.CancelVassalRaise(a)   ; 起き上がり完了(GetUpEnd)でKillします（C++ VassalRaise）
    StopReanimFX(a)   ; もや(075272)も外します
EndFunction

; 🧹 味方マーカーの剥がしは汎用お掃除ライブラリ [ASTR2Cleanup.ResetActor] へ移しました。
;    teammate/関係ランク/Aggression/淫紋(再描画つき)/追従スロット/Servantship＋ファクションは
;      ASTR2Native.ResetRuntimeFactions で基テンプレートへ一律巻き戻します（狙い撃ちゼロのオールリセットです）。
;    灰化/戦闘死/浄化ツールの全経路がこの1本を呼びます。

; 🔥 手下の解放は、寵愛切れ/戦闘死の共通処理です（ASTR2PlayerAliasScriptの巡回/alias OnDeathから呼びます）。死霊は灰化し、生者は死体化します。
;    ★解放では、味方の印を剥がして(ResetActor)Killし、普通の死体に戻します（ESPのReanimate効果はDispelでは崩れないのでKillが本命です）。
;      ★手動Disable()/Delete()も塵化演出もしません。死体を残し、セル再湧きで通常の敵として湧き直します（実機で確認しました）。
Function AshifyVassal(Actor akTarget) Global
    If akTarget == None
        Return
    EndIf
    ; 🧹 味方の印を基テンプレートへ巻き戻します。他MOD復活やセル再湧きが"通常の敵"になるようにするためです（追従スロット/淫紋/Servantship/ファクションもここで一括します）。
    ASTR2Cleanup.ResetActor(akTarget)
    ; 🔥 死霊の場合は、reanimate効果を落としてエンジンに崩させます（死霊崩壊で灰化します）。生者（生者化済み）はこの効果が無いので
    ;    崩れず、下の保険のKillで普通の死体になります。★Disable()/Delete()はしません。永久消滅するとリポップが死にます。
    Spell reanimSpell = Game.GetFormFromFile(0x00BF77, "A Succubus Tale R2.esp") as Spell   ; 本番のスイート・ヴァッサルです（Reanimate効果を持つのでDispelで崩して灰化します）
    If reanimSpell != None
        akTarget.DispelSpell(reanimSpell)
    EndIf
    ; 崩壊が起きず生きたまま(寵愛切れ)残った時の保険です。確実に死なせます（★Deleteはしません。リポップを温存します）。
    If !akTarget.IsDead()
        akTarget.Kill()
    EndIf
    ; 💀 塵化演出は使いません。崩壊シェーダーで"消える見た目"を出しても、Delete/Disableしない方針なので死体は残り
    ;    「塵で消えたのに死体が居る」矛盾になります。Kill済の普通の死体としてそのまま転がしておきます。セル再湧きで通常敵として湧き直します。
    StorageUtil.FormListRemove(Game.GetPlayer(), "ASTR2_VassalList", akTarget, True)
    ; 🧹 この手下の寵愛死タイマー予約＋〔SkyVault〕キーを掃除します。全解放経路(寵愛切れ/戦闘死/巡回/覚醒OFF/MCM個別リセット)で共通に完全掃除します。
    ;    ★全部idempotentです。死霊(タイマー無し)/二重呼び/既Unset/既-1でも安全なno-opです。AshifyVassalは解放/死の一方向なので、キーを残したい経路はありません。
    ASTR2Native.CancelVassalLoveTimer(akTarget)   ; 生者の寵愛死タイマー予約を消します（亡霊発火を防ぎます。死霊は元々無いのでno-opです）
    SkyVault.Unset(akTarget, "ASTR2_VassalLiving")
    SkyVault.Unset(akTarget, "ASTR2_VassalRaiseTime")
    SkyVault.Unset(akTarget, "ASTR2_VassalLastLove")
    SkyVault.Unset(akTarget, "ASTR2_VassalSigilLvl")
    SkyVault.Unset(akTarget, "ASTR2_VassalUpkeepMiss")
    SkyVault.Unset(akTarget, "ASTR2_VassalHasSchlong")
    SkyVault.Unset(akTarget, "ASTR2_VassalUpkeepLast")
    ; 🧹 最後の1体が消えたら、術者(プレイヤー)側に残るreanimate/従徒蘇生効果も落とします（透明追従者や「危なそうな呪文」への対策です）。
    ;    ★Dispelは同じ呪文の全インスタンスに効きます。生き残りが居ると道連れになるので、**居なくなった時だけ**切ります。
    Actor pcA = Game.GetPlayer()
    If StorageUtil.FormListCount(pcA, "ASTR2_VassalList") <= 0
        If reanimSpell != None
            pcA.DispelSpell(reanimSpell)
        EndIf
    EndIf
EndFunction

; 🌙 覚醒OFF（人間に戻る）ではサキュバスの力が消え、スイート・ヴァッサルの手下を死霊/生者とも全部即解除します。
;   ★維持費/手下税/死タイマーの"時間ジョブ"は ASTR2_Awake=0 で〔クロノス〕が〔門番〕停止するので触りません。ここでは対象(手下本体)の掃除だけです。
;   再覚醒は新規召喚です（復元しません）。VassalListを末尾から解放します（AshifyVassalが中でListからも外します）。
Function OnAwakeOff() Global
    Actor pc = Game.GetPlayer()
    Int vi = StorageUtil.FormListCount(pc, "ASTR2_VassalList") - 1
    While vi >= 0
        Actor v = StorageUtil.FormListGet(pc, "ASTR2_VassalList", vi) as Actor
        If v != None
            AshifyVassal(v)   ; 解放します。faction/淫紋/alias/VassalList除去＋寵愛死タイマーcancel＋〔SkyVault〕キーUnsetまで一括します（AshifyVassal内で完全に掃除します）
        EndIf
        vi -= 1
    EndWhile
EndFunction

; 🧷 揺るがない追従を作ります。手下専用クエスト(ASTR2VassalFollowQuest 0101D7DC)の空きReferenceAliasに実体を充填します。
;    エイリアスの追従パッケージが最優先で貼り付くので、OStim/H/自宅AIに負けません。GetNumAliasesで動的なので、後でスロット増設にも自動対応します。
Function AssignVassalSlot(Actor corpse) Global
    If corpse == None
        Return
    EndIf
    Quest q = Game.GetFormFromFile(0x0101D7DC, "A Succubus Tale R2.esp") as Quest
    If q == None
        Return
    EndIf
    Int n = q.GetNumAliases()
    ReferenceAlias freeSlot = None
    Int i = 0
    While i < n
        ReferenceAlias ra = q.GetNthAlias(i) as ReferenceAlias
        If ra != None
            ObjectReference r = ra.GetReference()
            If r == (corpse as ObjectReference)
                Return   ; 既に登録済みなので二重充填しません
            ElseIf r == None && freeSlot == None
                freeSlot = ra   ; 最初の空きスロットを覚えます
            EndIf
        EndIf
        i += 1
    EndWhile
    If freeSlot != None
        freeSlot.ForceRefIfEmpty(corpse)
    EndIf
EndFunction

; 🧷 追従スロットを解放します（灰化/解除/死亡時）。その手下が入っているエイリアスをClearして空きに戻します。
Function ClearVassalSlot(Actor corpse) Global
    If corpse == None
        Return
    EndIf
    Quest q = Game.GetFormFromFile(0x0101D7DC, "A Succubus Tale R2.esp") as Quest
    If q == None
        Return
    EndIf
    Int n = q.GetNumAliases()
    Int i = 0
    While i < n
        ReferenceAlias ra = q.GetNthAlias(i) as ReferenceAlias
        If ra != None && ra.GetReference() == (corpse as ObjectReference)
            ra.Clear()
            Return
        EndIf
        i += 1
    EndWhile
EndFunction

; 💋 生者化（キス会話）です。会話フラグメントから呼びます。安全なら生者化し、非安全なら示唆通知します。
;   会話条件で「LivingReadyな死霊」に絞ってあるので、ここは安全判定＋生者化だけです。
;   生者化はC++ ConvertVassalToLivingで行います（Resurrect+commanded解除+ASTR2_VassalRisen送出→OnVassalRisenが味方化/Servantship/淫紋/living=1）。
Function TryReviveVassal(Actor vassal) Global
    If vassal == None
        Return
    EndIf
    If !IsSafeToRevive()
        Debug.Notification("$ASTR2_Msg_ReviveNotSafe")   ; 安全な場所でないと生者化できない、という通知です。
        Return
    EndIf
    ; もう生者化するのでLivingReadyマーカーを外します（二度と出さないためです）。
    Faction livingReady = Game.GetFormFromFile(0x0101E81B, "A Succubus Tale R2.esp") as Faction
    If livingReady != None
        vassal.RemoveFromFaction(livingReady)
    EndIf
    ; 💋 特定キス OCR_FM_Kiss1 をC++直起動します（OStim"Threads"窓口。Papyrus より速く動きます）。
    ;    女性PC固定なので相手の性別は問いません（OCRのキスscene は intendedSex:any なので FF含め再生されます）。
    ;    endAfter=true はキス終了でスレッドを終了します／undress=false は服のままです。tid<0 は起動不可を表します(OStim/OCR無し等)。
    ;    キス起動が成立したら、生者化は"キス終了後"(OnOstimEnd→OnReviveSceneEnded)に行います。これはキスで蘇る演出です。起動不可なら即生者化にフォールバックします。
    Actor[] lineup = new Actor[2]
    lineup[0] = Game.GetPlayer()
    lineup[1] = vassal
    Int tid = ASTR2Native.StartSequenceScene(lineup, "OCR_FM_Kiss1", true, false)
    If tid >= 0
        ; 💋 キス起動成立時は、生者化を"キス終了後"に行います（OnOstimEnd→OnReviveSceneEnded）。保留印を立てます。
        StorageUtil.SetFormValue(Game.GetPlayer(), "ASTR2_RevivePending", vassal)
    Else
        ; キス起動不可(OStim/OCR不在・死霊不適格等)の時は、キス無しで即・生者化します（フォールバック）。
        DoReviveConvert(vassal)
    EndIf
EndFunction

; 💋 キス終了後に呼ばれます。保留印があればその相手を生者化＋ピンク霧します。ASTR2MainScript.OnOstimEnd から呼ばれます。
Function OnReviveSceneEnded() Global
    Actor pc = Game.GetPlayer()
    Actor pending = StorageUtil.GetFormValue(pc, "ASTR2_RevivePending") as Actor
    If pending != None
        StorageUtil.UnsetFormValue(pc, "ASTR2_RevivePending")
        DoReviveConvert(pending)
    EndIf
EndFunction

; 生者化を実行します。中身は ConvertVassalToLiving（C++）＋ピンク霧の演出です。キス経路/フォールバック両方から呼びます。
Function DoReviveConvert(Actor vassal) Global
    If vassal == None
        Return
    EndIf
    ASTR2Native.ConvertVassalToLiving(vassal)   ; Resurrect+味方化+living=1（C++で立っている死霊を直接操作します）
    PlayReviveGlow(vassal)                        ; ✨ ピンク霧を出します
    ; 💜 Reviving Graceのコストは生者になった時だけ払います（パワーは起動の手段にすぎません）。最大LFの10%です。
    ;    ※不足チェックは起動時(ASTR2RevivingGraceEffect先頭)で済ませてあり、キス中の増減は0で下げ止めます。
    ASTR2LifeForceBarScript lfQuest = ASTR2LifeForceBarScript.Get()
    If lfQuest != None
        Int cost = (lfQuest.LFenergyMax * 0.10) as Int
        lfQuest.LFisBarVisible = True
        lfQuest.LFenergyCurr -= cost
        If lfQuest.LFenergyCurr < 0
            lfQuest.LFenergyCurr = 0
        EndIf
        lfQuest.CheckLifeForce()
    EndIf
EndFunction

; ✨ 生者化のピンク霧です。VisualEffect(VampireMistform複製→#FFC5E1)をvassalに再生します。
;   ★下の glowVFX が 0 の間はスキップします。素材ができたらローカルFormIDへ差し替えるだけです（生者化自体は霧無しでも通ります）。
Function PlayReviveGlow(Actor vassal) Global
    Int glowVFX = 0x01F2E7   ; ASTR2RevivingGraceVE（ASTR2RevivingGraceESシェーダを包むVisual Effectです）
    If glowVFX == 0 || vassal == None
        Return
    EndIf
    VisualEffect glow = Game.GetFormFromFile(glowVFX, "A Succubus Tale R2.esp") as VisualEffect
    If glow != None
        glow.Play(vassal, 3.0)   ; 3秒間ピンク霧を再生します
    EndIf
EndFunction

; 安全な場所かどうかを判定します。条件は非戦闘かつ（屋内または街ロケ）です。屋内はマイホーム/他人の家/宿のことです。街は大きな町(City/Town/Settlement)のことです。
Bool Function IsSafeToRevive() Global
    Actor pc = Game.GetPlayer()
    If pc == None || pc.IsInCombat()
        Return False
    EndIf
    Cell c = pc.GetParentCell()
    If c != None && c.IsInterior()
        Return True
    EndIf
    Location loc = pc.GetCurrentLocation()
    If loc != None
        Keyword kwCity = Game.GetFormFromFile(0x00013168, "Skyrim.esm") as Keyword       ; LocTypeCity
        Keyword kwTown = Game.GetFormFromFile(0x00013166, "Skyrim.esm") as Keyword       ; LocTypeTown
        Keyword kwSettle = Game.GetFormFromFile(0x00013167, "Skyrim.esm") as Keyword     ; LocTypeSettlement
        If (kwCity != None && loc.HasKeyword(kwCity)) || (kwTown != None && loc.HasKeyword(kwTown)) || (kwSettle != None && loc.HasKeyword(kwSettle))
            Return True
        EndIf
    EndIf
    Return False
EndFunction

; 今プレイヤーがスイート・ヴァッサルを使ったら何日蘇生できるかを返します。MCM表示と実挙動で共用します。
; ★計算の単一の正はC++(src/VassalUpkeep.cpp GetReanimVassalDays)です。
;   式 = min(999, baseDays[〔SkyVault〕 ASTR2_VassalBaseDays] × サキュバスLv × (1 + 召喚スキル/100))。
;   baseDaysは〔SkyVault〕にあり、MCMスライダー/Save-Load/この計算で共有します。
Float Function CalcVassalDays() Global
    Return ASTR2Native.GetReanimVassalDays()
EndFunction

; MCM infoに表示するための公開getterです（これを呼んで「現在の蘇生可能日数」を表示します）。
Float Function GetSweetVassalDays() Global
    Return CalcVassalDays()
EndFunction

; 📋 召喚中の眷属の状態テキストです（MCM infoで使います。1体1行で翻訳できます）。死霊(未熟)は残りN日で崩壊します／生者はあとN日で寵愛切れです(寵愛オフなら永続)。
;    名前+数字はLocFmtStr($キー解決＋差込・既存dll)で訳せる完成文字列にします。居なければ空文字にします（MCM側で「なし」と表示できます）。
String Function GetActiveVassalStatusText() Global
    Actor player = Game.GetPlayer()
    Float nowDay = Utility.GetCurrentGameTime()
    Int loveDays = SkyVault.GetInt(None, "ASTR2_VassalLoveDays", 3)
    String out = ""
    Int cnt = StorageUtil.FormListCount(player, "ASTR2_VassalList")
    Int i = 0
    While i < cnt
        Actor v = StorageUtil.FormListGet(player, "ASTR2_VassalList", i) as Actor
        If v != None && !v.IsDead()
            String[] args = new String[2]
            args[0] = v.GetDisplayName()
            String line = ""
            If SkyVault.GetInt(v, "ASTR2_VassalLiving", 0) == 1
                ; 生者は寵愛切れまでです（寵愛日数0＝オフ＝永続）
                If loveDays > 0
                    Int loveLeft = ((loveDays as Float) - (nowDay - SkyVault.GetFloat(v, "ASTR2_VassalLastLove", nowDay))) as Int
                    If loveLeft < 0
                        loveLeft = 0
                    EndIf
                    args[1] = loveLeft as String
                    line = ASTR2Native.LocFmtStr("$ASTR2_Info_VassalLoveLine", args)
                Else
                    line = ASTR2Native.LocFmtStr("$ASTR2_Info_VassalLoveOff", args)
                EndIf
            Else
                ; 死霊(未熟)は崩壊までです（残り日数）
                Float days = StorageUtil.GetFloatValue(v, "ASTR2_VassalDays", 999.0)
                Int durLeft = (days - (nowDay - SkyVault.GetFloat(v, "ASTR2_VassalRaiseTime", nowDay))) as Int
                If durLeft < 0
                    durLeft = 0
                EndIf
                args[1] = durLeft as String
                line = ASTR2Native.LocFmtStr("$ASTR2_Info_VassalDeadLine", args)
            EndIf
            If out == ""
                out = line
            Else
                out = out + "\n" + line
            EndIf
        EndIf
        i += 1
    EndWhile
    Return out
EndFunction
