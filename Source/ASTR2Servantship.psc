Scriptname ASTR2Servantship Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; ===== C++列挙native（一覧のC++化／実装=src/ServantRoster.cpp）＝MCMは BuildRoster()1回＋getter で受けます（ティアごとに名簿をフル走査しないため1パス列挙＋キャッシュです） =====
Function BuildRoster() Global Native                                    ; 〔SkyVault〕名簿を1パス列挙→tier別にキャッシュします。
String[] Function GetRosterRows(Int tier, Int maxCount) Global Native   ; ティアの表示行 "名前   T.ff"（capN件・BuildRoster後に読みます）。
Actor[] Function GetRosterActors(Int tier, Int maxCount) Global Native  ; 同順のActor（個別リセットの行↔Actor紐付け）。
Int Function GetRosterCount(Int tier) Global Native                     ; ティアの生存サーヴァント総数（cap無視＝真の総数）。

; =====================================================================================
; 👑 〔サーヴァントシップ〕（Servantship）共通ロジックです。
;   サキュバスがNPCを手懐ける「per-NPC関係値」です。獲物→虜→僕→眷属→愛玩の5ティアです。
;   ・ティア(0-4)は ASTR2_ServantshipFaction(0101C7AF) の rank に格納します（会話条件で読めます）。
;   ・蓄積ポイントは 〔SkyVault〕("ASTR2_SvPoints",holder=actor)／名簿は 〔SkyVault〕 List("ASTR2_ServantList",global)＝C++が1パス列挙できる形です（旧StorageUtilはEnsureMigratedで一度きり移行します）。
;   ・H終了=+3 / イカせ=+0.5 / フォロワー放置=ゲーム時間×0.5 で貯まります（上げるだけで下げません）。しきい値 12/40/90。
;   ・自動昇格は眷属(3)で頭打ちです。愛玩(4)は会話の選択肢のみです（IsPetEligible/PromoteToPet）。
;   ・どこからでも ASTR2Servantship.OnSexEnd(npc) 等の1行で呼べます（Hidden/Global）。
;   ティア対応: 0 獲物Prey / 1 虜Captive / 2 僕Vassal / 3 眷属Thrall / 4 愛玩Pet
;   （バニラRank 0知人/1Friend/2Confidant/3Ally/4Lover と1:1です。サーヴァントのティア→バニラRank連動は眷属(3)到達時のみ＝ApplyTierでAlly(3)へ昇格します）
; =====================================================================================

; =========================================================
; 🔑 ファクション取得（未ロード時はNone＝全関数がNoneでReturnします）。
; =========================================================
Faction Function GetSvFaction() Global
    Return Game.GetFormFromFile(0x0101C7AF, "A Succubus Tale R2.esp") as Faction
EndFunction

; 💠 愛玩eligible露出用ファクション(ASTR2_PetEligibleFaction)です（CK会話条件で「点数180到達=eligible」を読むため。点数は〔SkyVault〕保存でCK条件から読めないのでfaction化しています）。
Faction Function GetPetEligibleFaction() Global
    Return Game.GetFormFromFile(0x0101F2EC, "A Succubus Tale R2.esp") as Faction   ; ASTR2_PetEligibleFaction
EndFunction

; =========================================================
; 📇 名簿＝〔SkyVault〕リスト(holder=None=global)＝C++が1パス列挙できる形／点数も〔SkyVault〕(holder=actor)＝C++が進捗計算に読みます（一覧のC++化）。
;   旧StorageUtil(名簿/点数)は EnsureMigrated が一度きりで〔SkyVault〕へ移します（フラグ ASTR2_RosterMigrated）。以後StorageUtilは無視します。全公開入口の頭で呼びます（移行後は1intチェックで軽いです）。
; =========================================================
Function EnsureMigrated() Global
    If SkyVault.GetInt(None, "ASTR2_RosterMigrated", 0) == 1
        Return
    EndIf
    Actor pc = Game.GetPlayer()
    Int n = StorageUtil.FormListCount(pc, "ASTR2_ServantList")
    Int i = 0
    While i < n
        Actor a = StorageUtil.FormListGet(pc, "ASTR2_ServantList", i) as Actor
        If a != None
            SkyVault.ListAdd(None, "ASTR2_ServantList", a, True)                                        ; 名簿membership
            SkyVault.SetFloat(a, "ASTR2_SvPoints", StorageUtil.GetFloatValue(a, "ASTR2_SvPoints", 0.0))  ; 各人の点数
        EndIf
        i += 1
    EndWhile
    SkyVault.SetInt(None, "ASTR2_RosterMigrated", 1)
EndFunction

; 名簿ヘルパー（〔SkyVault〕リスト・holder=None=global）
Int Function RosterCount() Global
    Return SkyVault.ListCount(None, "ASTR2_ServantList")
EndFunction
Actor Function RosterGet(Int i) Global
    Return SkyVault.ListGet(None, "ASTR2_ServantList", i) as Actor
EndFunction
Function RosterAdd(Actor akNpc) Global
    SkyVault.ListAdd(None, "ASTR2_ServantList", akNpc, True)   ; True=unique(dedup)
EndFunction
Function RosterRemove(Actor akNpc) Global   ; 〔SkyVault〕はindex削除のみなので、indexを探して消します（unique登録なので1件）。
    Int n = RosterCount()
    Int i = 0
    While i < n
        If RosterGet(i) == akNpc
            SkyVault.ListRemoveAt(None, "ASTR2_ServantList", i)
            Return
        EndIf
        i += 1
    EndWhile
EndFunction
; 点数ヘルパー（〔SkyVault〕・holder=actor）
Float Function GetSvPoints(Actor akNpc) Global
    Return SkyVault.GetFloat(akNpc, "ASTR2_SvPoints", 0.0)
EndFunction
Function SetSvPoints(Actor akNpc, Float v) Global
    SkyVault.SetFloat(akNpc, "ASTR2_SvPoints", v)
EndFunction

; =========================================================
; 🌟 メインスクリプトからのイベント口です（カウントはメインスクリプト、点数の重みはここが持ちます）。
; =========================================================
; 🎛️ Hスキルの効き具合を決める調整キーです。
;   「上手いサキュバスほどHで虜にしやすい」＝Hスキルの総合ランクで加点に倍率をかけます。
;   mult = 1 + (総合rank-3) × k。k=ASTR2_SvTechInfluence（既定0.2）。
;     k=0.2 → rank3で±0 / rank10で×2.4 / rank1で×0.6   k=0 → Hスキル無効(常に×1)
Float Function SvTechMult() Global
    Float k = StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2)
    Float mult = 1.0 + ((ASTR2Technique.GetDisplayTotalRank() - 3) as Float) * k
    If mult < 0.1
        mult = 0.1
    EndIf
    Return mult
EndFunction

; H（OStimシーン）終了＝+3点 ×Hスキル倍率です。
Function OnSexEnd(Actor akNpc) Global
    AddPoints(akNpc, 3.0 * SvTechMult())
EndFunction

; イカせ（相手にオーガズム付与）＝+0.5点 ×Hスキル倍率です（OStimは1シーンで何度も鳴る＝重みは控えめ）。
Function OnOrgasm(Actor akNpc) Global
    AddPoints(akNpc, 0.5 * SvTechMult())
EndFunction

; お供(フォロワー)でいる間、ゲーム時間で少しずつ加算します（Romanceのフォロワー放置と同じ思想）。
; 駆動はメインスクリプトの定期ループから AddFollowerTime(npc, 経過ゲーム時間) を呼びます。
Function AddFollowerTime(Actor akNpc, Float hours) Global
    If akNpc == None || hours <= 0.0
        Return
    EndIf
    AddPoints(akNpc, hours * 0.5)   ; +0.5/ゲーム時間（Romanceの+2/6h≒0.33に近い値です）
EndFunction

; =========================================================
; ➕ ポイント加算 → ティア再計算 → factionへ反映（上げる為のシステムで下がることはありません）
; =========================================================
Function AddPoints(Actor akNpc, Float amount) Global
    If akNpc == None
        Return
    EndIf
    EnsureMigrated()
    Float pts = GetSvPoints(akNpc) + amount
    SetSvPoints(akNpc, pts)
    ApplyTier(akNpc, PointsToTier(pts))
    If GetTier(akNpc) >= 1
        RegisterServant(akNpc)   ; 既存サーヴァント(既に最大ティアで昇格しない子)の名簿バックフィル＝再加点時に拾います。dedupなので重複は無害です。
    EndIf
    RefreshPetEligible(akNpc)   ; 💠 愛玩eligible露出＝180到達でファクションへ入れます（会話①のCK条件用・点数割れで外します）。
    RefreshEnvyBuff()   ; 💠 嫉妬のネイル＝加点で昇格しうる＝tier合計が変われば魔法5スキルを張り直します。
EndFunction

; =========================================================
; 📊 ポイント → ティア（しきい値は TierThreshold が単一の正）
;   自動昇格は眷属(3)で頭打ちです。愛玩(4)は会話の選択肢のみです（下 IsPetEligible/PromoteToPet）。
; =========================================================
Int Function PointsToTier(Float pts) Global
    If pts >= TierThreshold(3)
        Return 3   ; 眷属 Thrall（自動はここまで）
    ElseIf pts >= TierThreshold(2)
        Return 2   ; 僕 Vassal
    ElseIf pts >= TierThreshold(1)
        Return 1   ; 虜 Captive
    EndIf
    Return 0       ; 獲物 Prey
EndFunction

; =========================================================
; 🏷️ ティアをfaction rankへ反映します。下げません（上げるだけです）。tier>=1のみ加入します。
; =========================================================
Function ApplyTier(Actor akNpc, Int tier) Global
    Faction sv = GetSvFaction()
    If sv == None || akNpc == None
        Return
    EndIf
    Int cur = GetTier(akNpc)
    If tier <= cur
        Return   ; 同値or格下げは何もしません（昇格のみ）。
    EndIf
    If !akNpc.IsInFaction(sv)
        akNpc.AddToFaction(sv)
    EndIf
    akNpc.SetFactionRank(sv, tier)

    ; 👑 ティア→バニラRank連動＝眷属(3)到達でリレーションシップをAlly(3)へ恒久昇格します。
    ;   眷属(3)のみ連動します（虜1/僕2/愛玩4は連動しません）。上げるだけ＝既存の高Rankは下げません。
    If tier == 3
        Int preRank = akNpc.GetRelationshipRank(Game.GetPlayer())
        If preRank < 3
            akNpc.SetRelationshipRank(Game.GetPlayer(), 3)
        EndIf
    EndIf
    RegisterServant(akNpc)   ; 一覧表示用の名簿へ登録します（tier≥1で手懐けた子・dedup）。
    If tier >= 3
        RefreshTier3Count()   ; 💠 tier3クロス＝人数を数え直して〔SkyVault〕へ（アンリーシュド・フューリー用・C++が読む）。
    EndIf
EndFunction

; =========================================================
; 🔎 現ティア取得（faction未所属＝0＝獲物Prey）
; =========================================================
Int Function GetTier(Actor akNpc) Global
    Faction sv = GetSvFaction()
    If sv == None || akNpc == None
        Return 0
    EndIf
    If !akNpc.IsInFaction(sv)
        Return 0
    EndIf
    Int r = akNpc.GetFactionRank(sv)
    If r < 0
        Return 0
    EndIf
    Return r
EndFunction

; =========================================================
; 💋 魅了の色気注入量へ乗せるボーナスです（ティア×4 ＝ 0/4/8/12/16）。
; =========================================================
Float Function GetSeductionBonus(Actor akNpc) Global
    Return (GetTier(akNpc) * 4) as Float
EndFunction

; =========================================================
; 💍 愛玩(tier4)は自動でなく会話の選択肢で昇格します（Romanceの交際と同じ作法）。
;   点数が tier4 しきい値(180)に達すると IsPetEligible が真→会話側が選択肢を出します。
;   →PromoteToPet で愛玩になります。自動昇格(PointsToTier)は眷属(3)止まりです。
; =========================================================
Bool Function IsPetEligible(Actor akNpc) Global
    If akNpc == None
        Return false
    EndIf
    Return GetPoints(akNpc) >= TierThreshold(4) && GetTier(akNpc) < 4
EndFunction

; 💠 eligible露出＝IsPetEligibleに合わせて ASTR2PetEligibleFaction へ出し入れします（CK会話①の条件用）。
;   呼び元＝AddPoints(180クロス/点数割れ)・PromoteToPet(昇格=候補外)・ResetServant(浄化)です。ファクション未作成(None)なら無害なno-opです。
Function RefreshPetEligible(Actor akNpc) Global
    Faction pe = GetPetEligibleFaction()
    If pe == None || akNpc == None
        Return
    EndIf
    If IsPetEligible(akNpc)
        If !akNpc.IsInFaction(pe)
            akNpc.AddToFaction(pe)
        EndIf
    ElseIf akNpc.IsInFaction(pe)
        akNpc.RemoveFromFaction(pe)
    EndIf
EndFunction

; 💠 tier3以上のサーヴァント人数を 〔SkyVault〕 Int `ASTR2_Tier3Count` へ維持します（C++のアンリーシュド・フューリー倍率が読む）。
;   名簿(ASTR2_ServantList)を数え直します＝単一の正(=名簿)から再計算するので、インクリメント式のdriftがありません。生存&tier>=3のみです。
;   呼び元＝ApplyTier(tier3クロス時)・PromoteToPet(安全)・ResetServant(減)です。holder=None(=global 0)＝C++は GetInt(0,...) で読みます。
Function RefreshTier3Count() Global
    EnsureMigrated()
    Int n = RosterCount()
    Int cnt = 0
    Int i = 0
    While i < n
        Actor a = RosterGet(i)
        If a != None && !a.IsDead() && GetTier(a) >= 3
            cnt += 1
        EndIf
        i += 1
    EndWhile
    SkyVault.SetInt(None, "ASTR2_Tier3Count", cnt)
EndFunction

; =========================================================
; 💠 嫉妬のネイル(idx5)＝全サーヴァントのtier合計を魔法5スキル(破壊/回復/変性/召喚/幻惑)に加算します＝囲うほど魔法が強化されます(独占)。
;   ・tier素点をそのまま合算します（tier4=4/tier3=3/tier2=2/tier1=1・係数なし）。生存のみ。名簿=単一の正からその場で計算します(drift無し)。
;   ・差分管理＝前回焼いたぶん(ASTR2_EnvyApplied)との差だけ ModActorValue します＝ロードで二重掛けしません／ネイル外し=フラグ0=target0で全戻しします。
;   ・契約＝有効フラグ 〔SkyVault〕 "ASTR2_NailActive_5"（NailManagerが装備/コンプで更新）。装備/コンプ変化での張り直しは
;     ApplyEffectSetからこの関数を1回呼んでもらいます（受動statバフなので再読トリガーが要ります）。tier変化点(加点/昇格/解除)からも呼びます。
;   ・呼び出しは低頻度(tier変化 or ネイル着替え)なので負荷ゼロです。フラグOFF&適用0ならdelta0で即returnします。
;   上限キャップは設けていません＝大量に囲うと+数百も有り得ます。バランス調整が要る場合はここで target を上限clampします。
; =========================================================
Function RefreshEnvyBuff() Global
    Actor pc = Game.GetPlayer()
    If pc == None
        Return
    EndIf
    EnsureMigrated()
    Int target = 0
    If SkyVault.GetInt(None, "ASTR2_NailActive_5", 0) == 1
        Int n = RosterCount()
        Int i = 0
        While i < n
            Actor a = RosterGet(i)
            If a != None && !a.IsDead()
                target += GetTier(a)
            EndIf
            i += 1
        EndWhile
    EndIf
    Int applied = SkyVault.GetInt(None, "ASTR2_EnvyApplied", 0)
    Int delta = target - applied
    If delta == 0
        Return
    EndIf
    Float d = delta as Float
    pc.ModActorValue("Destruction", d)
    pc.ModActorValue("Restoration", d)
    pc.ModActorValue("Alteration", d)
    pc.ModActorValue("Conjuration", d)
    pc.ModActorValue("Illusion", d)
    SkyVault.SetInt(None, "ASTR2_EnvyApplied", target)
EndFunction

Function PromoteToPet(Actor akNpc) Global
    Faction sv = GetSvFaction()
    If sv == None || akNpc == None
        Return
    EndIf
    If !akNpc.IsInFaction(sv)
        akNpc.AddToFaction(sv)
    EndIf
    akNpc.SetFactionRank(sv, 4)
    RegisterServant(akNpc)   ; 一覧表示用の名簿へ登録します。
    RefreshPetEligible(akNpc)   ; 💠 昇格＝もう候補でないのでeligibleファクションから外します。
    RefreshTier3Count()   ; 💠 tier3以上の人数を更新します（3→4は≥3のままだが整合のため）。
    RefreshEnvyBuff()   ; 💠 嫉妬のネイル＝tier合計が増えたので魔法5スキルを張り直します。
EndFunction

; =========================================================
; 💠 愛玩(tier4)の貢ぎ＝サーヴァント名簿の愛玩ごとに「LF最大の pct%」をプレイヤーへ献上します（お供でも放置でも＝名簿ベースなので場所は不問）。
;   タイミングはメインスクリプトの淫魔力徴収tickに相乗りします＝そこから1回だけ呼びます（別タイマーを持ちません）。
;   pct＝〔SkyVault〕 `ASTR2_PetTributePct`（MCM 0.1〜90／既定1.0＝1%のスライダー）。生存愛玩のみ。XPは付けません（受動収入なので育成に効かせない）。
;   LF付与はサキュバス・ドレインと同じ流儀です（spaceにクランプ→LFenergyCurr加算→UpdateLifeForce）。
; =========================================================
Function PayPetTribute() Global
    Actor pc = Game.GetPlayer()
    ASTR2LifeForceBarScript LFBar = ASTR2LifeForceBarScript.Get()
    If pc == None || LFBar == None || LFBar.LFenergyMax <= 0
        Return
    EndIf
    ; ⏳ 時間〔門番・ゲート〕＝前回の貢ぎから減衰間隔(energyUpdateFreq・既定3h)未満なら払いません。
    ;   呼び口 astr2_lf_tick は アンリーシュド・フューリー が毎秒／サキュバス・ドレイン・スイート・ヴァッサルも飛ばすので、時間で絞らないと毎秒 max×pct% 供給＝
    ;     アンリーシュド・フューリーが即回復＆過剰供給になります。実際にゲーム内時間が進んだ時だけ払います＝数時間ごとの貢ぎに戻します。
    Float freq = LFBar.energyUpdateFreq as Float
    If freq < 0.1
        freq = 0.1
    EndIf
    Float nowHour = Utility.GetCurrentGameTime() * 24.0
    Float lastHour = SkyVault.GetFloat(None, "ASTR2_PetTributeLastHour", -9999.0)
    If nowHour - lastHour < freq
        Return   ; まだ間隔未満＝今回は払いません（毎秒tickの空振り＝軽い早期return）。
    EndIf
    SkyVault.SetFloat(None, "ASTR2_PetTributeLastHour", nowHour)   ; 今回の貢ぎ時刻を記録します（次の間隔起点＝減衰と同じ絶対グリッド）。
    Float pct = SkyVault.GetFloat(None, "ASTR2_PetTributePct", 1.0)   ; MCM(0.1〜90)・既定1%
    If pct <= 0.0
        Return
    EndIf
    Int per = ((LFBar.LFenergyMax as Float) * pct / 100.0) as Int     ; 愛玩1体あたりの貢ぎ量です。
    If per <= 0
        per = 1
    EndIf
    EnsureMigrated()
    Int total = 0
    Int n = RosterCount()
    Int i = 0
    While i < n
        Actor a = RosterGet(i)
        If a != None && !a.IsDead() && GetTier(a) >= 4
            total += per
        EndIf
        i += 1
    EndWhile
    If total <= 0
        Return
    EndIf
    Int spaceLeft = LFBar.LFenergyMax - LFBar.LFenergyCurr
    If spaceLeft <= 0
        Return   ; 満タン＝献上しても入りません。
    EndIf
    Int added = total
    If added > spaceLeft
        added = spaceLeft
    EndIf
    LFBar.LFenergyCurr += added
    LFBar.UpdateLifeForce()
EndFunction

; =========================================================
; 🔗 外部値から取り込みます（クロスヘア同期パワー用・バニラRank→ティア・上げるだけで下げません）。
;   ※Romance(Intimacy/Love 0-100→ティア)の取込は検討中です。現状はバニラRankのみ1:1対応です。
; =========================================================
Function SyncFromExternal(Actor akNpc) Global
    If akNpc == None
        Return
    EndIf
    EnsureMigrated()
    Int importedTier = akNpc.GetRelationshipRank(Game.GetPlayer())   ; バニラRank -4..+4
    If importedTier < 0
        importedTier = 0
    ElseIf importedTier > 4
        importedTier = 4
    EndIf
    Int cur = GetTier(akNpc)
    If importedTier > cur
        ApplyTier(akNpc, importedTier)
        SeedPointsForTier(akNpc, importedTier)   ; ポイントもしきい値までシード＝以後の蓄積が継続します。
        Debug.Notification("$ASTR2_Msg_SyncVanilla")   ; バニラ関係から同期成功の通知です。
    Else
        Debug.Notification("$ASTR2_Msg_SyncFail")      ; 取り込めるものが無い／既に同等以上です。
    EndIf
    ; Romance源（OCR_Lover_Value_Intimacy/Love＝OStimCommunityResource.esp定義）からの取込＋ "$ASTR2_Msg_SyncRomance" 通知は検討中です（要 OCR FormID＋Intimacy→ティアのマッピング）。
EndFunction

; =========================================================
; 🌱 ティアの下限しきい値までポイントをシードします（下げません）。
; =========================================================
Function SeedPointsForTier(Actor akNpc, Int tier) Global
    Float need = TierThreshold(tier)
    If need > GetSvPoints(akNpc)
        SetSvPoints(akNpc, need)
    EndIf
EndFunction

; =========================================================
; 📐 各ティアの下限しきい値＝ティア閾値の単一の正（PointsToTierもここを参照）
; =========================================================
Float Function TierThreshold(Int tier) Global
    If tier >= 4
        Return 180.0   ; 愛玩は会話選択です。この値は「選択肢が出る条件」(IsPetEligible)に使います。
    ElseIf tier == 3
        Return 90.0
    ElseIf tier == 2
        Return 40.0
    ElseIf tier == 1
        Return 12.0
    EndIf
    Return 0.0
EndFunction

; =========================================================
; 🧮 蓄積ポイント取得（デバッグ/UI用）
; =========================================================
Float Function GetPoints(Actor akNpc) Global
    If akNpc == None
        Return 0.0
    EndIf
    EnsureMigrated()
    Return GetSvPoints(akNpc)
EndFunction

; =========================================================
; 📋 サーヴァント名簿（MCM一覧表示用）＝手懐けた子(tier≥1)を〔SkyVault〕リストに控えます。
;   ・ApplyTier/PromoteToPet から RegisterServant で登録します（dedup・永続=〔SkyVault〕リスト）。
;   ・表示はティアをライブ読みします(GetTier)＝3→4昇格した子は次にMCMを開くと自動で愛玩(4)の欄へ移動します。
; =========================================================
Function RegisterServant(Actor akNpc) Global
    If akNpc == None
        Return
    EndIf
    EnsureMigrated()
    RosterAdd(akNpc)   ; 〔SkyVault〕リストへ(unique/dedup)。
EndFunction

; 浄化：サーヴァント/手下を完全リセット＝ティア0・点数0・名簿除去（StripVassalMarkersから呼びます）。
;   ApplyTierは上げるだけ(下げ不可)なので、faction rankを直接外します＝GetTierが0(獲物)を返します。これで昇格の連動(tier3→Rank3)も再発火しません。
;   ※関係ランク0は呼び元(StripVassalMarkers)が実施済なので、ここでは触りません。
Function ResetServant(Actor akNpc) Global
    If akNpc == None
        Return
    EndIf
    EnsureMigrated()
    Faction sv = GetSvFaction()
    If sv != None && akNpc.IsInFaction(sv)
        akNpc.RemoveFromFaction(sv)                                          ; ① ティア→0（faction未所属＝GetTier 0）
    EndIf
    SetSvPoints(akNpc, 0.0)                  ; ② 蓄積ポイント→0（GetPointsが読む値）
    RosterRemove(akNpc)                      ; ③ 名簿から除去（RegisterServantの逆）
    RefreshPetEligible(akNpc)   ; 💠 浄化＝eligibleファクションからも外します（tier0/pts0で非該当）。
    RefreshTier3Count()   ; 💠 ≥3だった子が抜けたら人数を減らします（数え直し）。
    RefreshEnvyBuff()   ; 💠 嫉妬のネイル＝サーヴァントが抜けた＝tier合計が減ったので魔法5スキルを張り直します。
EndFunction


; MCM一覧の名簿取得APIです。上部の native `BuildRoster()` を1回叩いてから `GetRosterRows/GetRosterActors/GetRosterCount(tier)` で受けます（実装=src/ServantRoster.cpp）。
;   個別リセットの「表示行↔実体Actor」も `GetRosterActors` から取ります。進捗"T.ff"はC++側(progressString)がProgressStringと1:1で計算します。
