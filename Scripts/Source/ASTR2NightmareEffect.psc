Scriptname ASTR2NightmareEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

ASTR2MainScript Main

; ============================================
;  ナイトメア・エンブレイス(Nightmare Embrace) - 寝ている相手に魔法を当てます
;  通知は$KEY単体で使います(キーは文字列の先頭に置くこと)。
;  成功確率 = base(Lv) + 興奮ボーナス + サーヴァントtierボーナス・100で頭打ちです。
; ============================================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; 💰 マジカ消費はバニラに一本化しています（CalculateMagickaCostフック＝ManaCost.cpp）＝ここでは払いません。
    Main = ASTR2MainScript.Get()

    If akTarget == None
        Return
    EndIf
    ; 子供は決して有効な対象ではありません -- 念のための二重保険です。ナイトメア・エンブレイスのMGEFのESP種族条件で既に子供は弾かれ、
    ; OnEffectStartはそもそも発火しません。ここは通常不到達です(なのでメッセージも実際は出ません)。
    ; ですがESP条件が外れた場合に備え、Papyrus側でも除外しDispelします。
    If akTarget.IsChild()
        Debug.Notification("$ASTR2_Debug_NightmareChild")
        Dispel()   ; このマジックエフェクトを除去します＝子供に失敗バフを残しません
        Return
    EndIf

    ; --- (1) 対象ごとの12時間ロック ---
    Float lockUntil = StorageUtil.GetFloatValue(akTarget, "ASTR2_NightmareLockUntil", 0.0)
    If Utility.GetCurrentGameTime() < lockUntil
        Debug.Notification("$ASTR2_Debug_NightmareLocked")
        Return
    EndIf

    ; --- (2) 寝ている必要あり(3 = 睡眠中) ---
    If akTarget.GetSleepState() != 3
        Debug.Notification("$ASTR2_Debug_NightmareAwake")
        Return
    EndIf

    ; --- (3) 成功確率 = base + 興奮ボーナス + tierボーナス(100で頭打ち) ---
    ;     base       = nmBase + (Lv-1)*nmPerLv (既定10/8 => Lv1=10% / Lv10=82%)
    ;                  nmBase/nmPerLv = MCMアビリティコンフィグのスライダー(プレイヤーが素の数字を調整)
    ;     arousalBonus = (arousal/100)*Lv*2    (Lv比例; 低Lvは数%)
    ;     tierBonus    = サーヴァントtier * 6  (tier2=+12 / tier4=+24)
    Int succLvl = GetSuccubusLevel()
    ; baseは単一の正(C++ NightmareBaseNow)を呼びます＝nmBase+(Lv-1)×nmPerLvの式をpscに再掲せず一本化します。興奮/tierは対象依存なので下で上乗せします。
    Float baseChance = ASTR2Native.GetNightmareBaseNow()
    Float arousal = OSLArousedNative.GetArousal(akTarget)
    Float arousalBonus = (arousal / 100.0) * succLvl * 2.0
    Int tier = ASTR2Servantship.GetTier(akTarget)
    Float tierBonus = tier * 6.0
    Float successChance = baseChance + arousalBonus + tierBonus
    successChance *= 1.0 + ASTR2Technique.GetDisplayCatRank(0) * 0.05   ; 💋 Hスキル（腰使いcat0）で発動確率を上げます（rank0で±0/rank10で+50%）
    If successChance > 100.0
        successChance = 100.0
    EndIf
    Float roll = Utility.RandomFloat(0.0, 100.0)

    If roll <= successChance
        ; ===== 成功: 甘い夢 -> OStim開始 =====
        Debug.Notification("$ASTR2_Debug_NightmareSuccess")
        ; 🔮 幻惑(Illusion)育成＝成功率が低いほど多く入れます(難しい誘惑の成功ほど育つ)。
        Game.AdvanceSkill("Illusion", 30.0 + (100.0 - successChance) * 0.3)   ; 成功報酬30(最低保証)＋成功率が低いほど加算(×0.3)＝高Lvで成功率100%でも30もらえます
        LockTarget(akTarget)
        Actor[] group = BuildNightmareGroup(akTarget, succLvl, successChance)   ; プレイヤー + 対象 + Lv5の相方(常に>=2)です
        Main.StartNightmareScene(akTarget, group)
        ; 🌙 夢魔痕＝襲った相手(プレイヤー除く)に淫紋を刻みます(a=男背中/女胸・d=トグル非依存・24hで薄れる)。
        Int nmi = 1   ; group[0]=プレイヤーは除外します
        While nmi < group.Length
            If group[nmi] != None && group[nmi] != Game.GetPlayer()
                ASTR2Native.DrainMarkPunch(group[nmi], true)
            EndIf
            nmi += 1
        EndWhile
    Else
        ; ===== 失敗: 起床ロール = (10 - Lv)x10% - 興奮ぶん減(興奮した相手は寝続ける) =====
        ;   kWakeArousalCut=15: Lv6/arousal96 -> 40->26 / Lv1 -> 90->75 / Lv10 -> 0(既に)。
        Float wakeChance = (10 - succLvl) * 10.0 - (arousal / 100.0) * 15.0
        If wakeChance < 0.0
            wakeChance = 0.0
        EndIf
        Float wakeRoll = Utility.RandomFloat(0.0, 100.0)
        If wakeRoll <= wakeChance
            ; --- 起きた -> MoveToでベッドから実際に追い出します(SetAlert/Idleでは寝ている人を起こせない)。
            ;     SetAlertしません: 起こすが警戒状態にはしません。AIは自分で再開します。 ---
            LockTarget(akTarget)
            akTarget.MoveTo(akTarget)   ; 家具からの追い出し = 寝ている人を実際に起こす唯一の手段です
            akTarget.EvaluatePackage()  ; 自分のAIを再開します(夜なら二度寝など)
            Debug.Notification("$ASTR2_Debug_NightmareWoke")
        Else
            ; --- 寝続けた -> ロック無し・再挑戦OK ---
            Debug.Notification("$ASTR2_Debug_NightmareStaySleep")
        EndIf
    EndIf
EndEvent

; ============================================
;  ヘルパー
; ============================================

; 対象に12時間ロックを刻みます(今 + 0.5ゲーム日)
Function LockTarget(Actor akTarget)
    StorageUtil.SetFloatValue(akTarget, "ASTR2_NightmareLockUntil", Utility.GetCurrentGameTime() + 0.5)
EndFunction

; 現在のサキュバスレベルを読みます
Int Function GetSuccubusLevel()
    GlobalVariable lvlGlob = Game.GetFormFromFile(0x000D64, "A Succubus Tale R2.esp") as GlobalVariable
    If lvlGlob != None
        Return lvlGlob.GetValue() as Int
    EndIf
    Return 1
EndFunction

; MCMアビリティ一覧の威力getterです。今のプレイヤーLvでの base 成功確率%を返します:
; nmBase + (Lv-1)*nmPerLv・100で頭打ち(nmBase/nmPerLv = MCMアビリティコンフィグのスライダー
; ASTR2_NightmareBaseChance/PerLv・既定10/8)。注: 興奮 + サーヴァントtierボーナスは対象ごと
; = ここには含めません(これは対象なしで出す base の「現在」確率です)。
Int Function GetNightmareChance() Global
    ; 計算の単一の正はC++(src/SpellInfo.cpp NightmareChanceNow)にあります。MCM表示・呪文DESCで共用します。
    Return ASTR2Native.GetNightmareChanceNow()
EndFunction

; ============================================
;  ナイトメア・エンブレイスのグループを組みます = プレイヤー + 対象 (+ Lv5で寝ている相方)。
;  相方(Lv5以上のみ): ロード済みアクター(PO3 high-process)・睡眠中(sleepState==3)・対象の半径内で、
;  (条件3)対象と近しい関係 OR (条件4)サーヴァントtierが対象以上 かつ >= 2(虜の下限)で資格ありです。
;  資格者はそれぞれ対象自身のsuccessChanceでロールします(対象と同じ確率)。相方は最大3人(= 計5P)です。
;  常に長さ>=2の有効な配列(プレイヤー + 対象)を返します・None/空になりません -- グループ全体をここで組みます
;  (別の「相方」配列を作らない)＝StartNightmareSceneがNone配列に触れないためです(PapyrusUtil.ActorArray(0)は
;  Noneを返す = cast/indexエラーの元)。
; ============================================
Actor[] Function BuildNightmareGroup(Actor akTarget, Int succLvl, Float successChance)
    Actor pc = Game.GetPlayer()
    Actor[] accepted = PapyrusUtil.ActorArray(3)   ; 長さ3(非None); [0..cnt-1]だけ読みます
    Int cnt = 0
    If succLvl >= 5
        Int targetTier = ASTR2Servantship.GetTier(akTarget)
        Float radius = 1024.0       ; 「部屋の隣り合うベッド」
        Int relThreshold = 3        ; バニラRelationshipRank: 4 恋人 / 3 盟友(近しい絆)
        Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)   ; 0 = high-process(プレイヤー近く)
        Int i = 0
        While i < loaded.Length && cnt < 3
            Actor a = loaded[i]
            ; 子供は問答無用で除外します(!IsChild = バニラのネイティブ子供種族チェック) -- rel/tier以前に候補にすらしません。
        If a != None && a != akTarget && a != pc && !a.IsDead() && !a.IsChild() && a.GetSleepState() == 3 && akTarget.GetDistance(a) <= radius
                Bool relClose = akTarget.GetRelationshipRank(a) >= relThreshold    ; 条件3: 対象と近しい
                Int aTier = ASTR2Servantship.GetTier(a)
                Bool tierOK = aTier >= targetTier && aTier >= 2                    ; 条件4: サーヴァントtier(最低でも虜)
                Bool qualifies = relClose || tierOK
                Float pRoll = -1.0
                If qualifies
                    pRoll = Utility.RandomFloat(0.0, 100.0)
                    If pRoll <= successChance
                        accepted[cnt] = a
                        cnt += 1
                        LockTarget(a)   ; 相方にも12時間ロックを付けます
                    EndIf
                EndIf
            EndIf
            i += 1
        EndWhile
    EndIf
    ; 最終グループ = プレイヤー + 対象 + 採用した相方です。長さ2..5・None化しません(PapyrusUtil(>=2)なら安全です)。
    Actor[] group = PapyrusUtil.ActorArray(2 + cnt)
    group[0] = pc
    group[1] = akTarget
    Int j = 0
    While j < cnt
        group[2 + j] = accepted[j]
        j += 1
    EndWhile
    Return group
EndFunction
