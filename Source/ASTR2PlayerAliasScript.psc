Scriptname ASTR2PlayerAliasScript extends ReferenceAlias
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; プレイヤーに付けるReferenceAliasです。QuestのOnPlayerLoadGameは環境次第で不発になりますが、
; ReferenceAliasのOnPlayerLoadGameは確実に鳴ります（OStimと同じ方式＝OStimPlayerAliasScript）。
; ロード時にConfig.jsonのAutoImportがONなら、HUDウィジェット準備を待って自動インポートします。

Float Property FollowerTickHours = 6.0 Auto Hidden   ; サーヴァント フォロワー放置加点の間隔です（ゲーム時間）

Event OnPlayerLoadGame()
    ; ★ロード毎の張り直し一式＝キー/OStimイベント/HPバー/LF最大値/LFティック＋C++ドレイン完了の受け口です。
    ;   extends Quest の ASTR2MainScript では OnPlayerLoadGame が鳴らず、Maintenanceが実質MCMを閉じた時しか
    ;   走りません。本物のロードフックであるここから呼びます＝Maintenanceが設計どおり毎ロード効きます。
    ASTR2MainScript ASTMain = ASTR2MainScript.Get()
    If ASTMain != None
        ASTMain.Maintenance()
        ASTMain.ScheduleAwakeningCheck()   ; 覚醒をまだ訊いていないセーブの保険です（主経路はOnInit→OnUpdate）
    EndIf
    If JsonUtil.GetIntValue("ASuccubusTaleR2/Config", "AutoImport", 0) == 1
        RegisterForSingleUpdate(3.0)   ; HUDウィジェット生成を待ってから適用します
    EndIf
    RegisterForSingleUpdateGameTime(FollowerTickHours)   ; サーヴァント フォロワー放置加点ループを開始します（6ゲーム時間ごと）
    ; 🕯️ 寵愛切れ死タイマーの張り直しです＝〔クロノス〕のTimeoutはセッション限りで消えるので、ロード毎に全ての生者の手下へ張り直します（C++がlastLoveから残り時間で復元）。
    Actor pcLove = Game.GetPlayer()
    Int loveI = StorageUtil.FormListCount(pcLove, "ASTR2_VassalList") - 1
    If loveI >= 0
        ASTR2Native.UpkeepStart()   ; ▶️ ロード時＝手下(死霊/生者)が1体でも居れば維持費ジョブを再開します（enabledはロードで持ち越すため）
    EndIf
    While loveI >= 0
        Actor loveV = StorageUtil.FormListGet(pcLove, "ASTR2_VassalList", loveI) as Actor
        If loveV != None && !loveV.IsDead() && SkyVault.GetInt(loveV, "ASTR2_VassalLiving", 0) == 1
            ASTR2Native.ArmVassalLoveTimer(loveV)
        EndIf
        loveI -= 1
    EndWhile
    UnregisterForKey(0x23)   ; 旧H用キー登録を解除します（起動はセダクション経由へ移行済み）＝既存セーブの旧登録を解除・新ゲームは未登録です
    RegisterForModEvent("ASTR2_ExciteNode", "OnAstr2ExciteNode")   ; Hスキル→興奮ブースト（C++が相手＋行為名を飛ばす）
    RegisterForModEvent("ASTR2_VassalRisen", "OnVassalRisen")      ; 🧟 スイート・ヴァッサル：生者の手下が起き上がり完了→生者化した通知（C++ VassalRaiseが送出）
    RegisterForModEvent("ASTR2_VassalDied", "OnVassalDied")        ; 🧟 スイート・ヴァッサル：手下の死亡を即掃除（C++ TESDeathEventシンクが送出＝再アニメ死霊でも確実）
    RegisterForModEvent("ASTR2_VassalLoveExpired", "OnVassalLoveExpired")   ; 🕯️ 寵愛切れ専用です（気絶ガードなしで生者をKill＝死体化）
    ASTR2Native.SetSkillXpBonus(ASTLvlManager.Get().GetSkillXpBonus() as Float)   ; 🌟 スキルXPボーナスをC++フックへ復元します（dll側の値は再起動で0に戻るのでロード時に再プッシュ）
EndEvent

; 新ゲーム（アライアス初回充填）でも興奮ブーストのmodイベント購読を張ります（ロードはOnPlayerLoadGame）。
Event OnInit()
    RegisterForModEvent("ASTR2_ExciteNode", "OnAstr2ExciteNode")
    RegisterForModEvent("ASTR2_VassalRisen", "OnVassalRisen")
    RegisterForModEvent("ASTR2_VassalDied", "OnVassalDied")        ; 🧟 スイート・ヴァッサル：手下の死亡を即掃除（C++ TESDeathEventシンクが送出）
    RegisterForModEvent("ASTR2_VassalLoveExpired", "OnVassalLoveExpired")   ; 🕯️ 寵愛切れ専用です（気絶ガードなしで生者をKill＝死体化）
    RegisterForSingleUpdateGameTime(FollowerTickHours)   ; 新ゲーム/初回でも巡回(寿命/寵愛/手下税)を起動します＝ここで登録しないと新ゲームで巡回が一度も回らず手下が不死になります
    ASTR2Native.SetSkillXpBonus(ASTLvlManager.Get().GetSkillXpBonus() as Float)   ; 🌟 スキルXPボーナスをC++フックへ復元します（新ゲーム/初回）
EndEvent

; 🧟 スイート・ヴァッサル：生者の手下が起き上がり完了→生者化した直後にC++から飛ぶ通知です（sender=その手下）。
;   起き上がりで残る紫FX(ReanimateFXShader 075272)を外します＝「起き上がってエフェクトが消える」演出です。
Event OnVassalRisen(String eventName, String strArg, Float numArg, Form sender)
    Actor vassal = sender as Actor
    If vassal == None
        Return
    EndIf
    ; 🧹 起き上がりで残る見た目(紫FX/常駐シェーダー)を外します＝生命管理はVassalList＋PlayerAlias巡回（非魔法）が持ちます。
    ; ★スイート・ヴァッサル(00BF77)のReanimate効果は【Dispelしません】＝Dispelすると生者化済の手下もcrumble→即灰化するためです。
    ;   残る紫FX/常駐シェーダーは下の StopAllShaders で外します＝効果は残したまま見た目だけ消します（永続Durationのまま放置＝crumbleのトリガー無し）。
    ; 🔵 青白い発光の根治です＝DeadThrall HitShader(075272・FXPersist)はエンジンが"魔法効果"として貼った常駐シェーダーなので、
    ;    Papyrusの EffectShader.Stop() では構造的に外せません（Stopはplay()した分だけ＝今まで空振りでした）。PO3 StopAllShadersは
    ;    ProcessListsのShader/Artを全finishするので075272に当たります。生者経路限定なので死霊の見た目は無傷です。
    PO3_SKSEFunctions.StopAllShaders(vassal)
    ; ※Reanimate効果は C++ ResurrectToLiving が生者化の直後（紐付け解除の前）に外します＝ここでは外しません。

    ; 🤝 味方(従者)化＝生者化が完了したこの地点で付けます（Resurrect(C++)のAI再起動より後なので味方化が飛ばない安全地点です）。
    ;    完成形の味方化ロジックはこのフックに集約しています。
    Actor pcV = Game.GetPlayer()
    vassal.SetActorValue("Aggression", 0)          ; 敵対を解除します（元が敵でも襲いません）
    vassal.StopCombat()
    vassal.SetPlayerTeammate(True)                  ; 味方化します（一緒に戦う）
    vassal.IgnoreFriendlyHits(True)                 ; 味方の誤爆で敵対しません（EFF流）
    Faction followerFacV = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction   ; CurrentFollowerFaction＝エンジンがセル移動で連れ回します
    If followerFacV != None
        vassal.AddToFaction(followerFacV)
        vassal.SetFactionRank(followerFacV, 0)
    EndIf
    Faction minionFacV = Game.GetFormFromFile(0x0101D278, "A Succubus Tale R2.esp") as Faction   ; 手下マーカーです（吸い殺し保護）
    If minionFacV != None
        vassal.AddToFaction(minionFacV)
    EndIf
    ASTConjCost.AssignVassalSlot(vassal)           ; 🧷 揺るがない追従です（専用クエストのReferenceAliasにForceRef）
    vassal.EvaluatePackage()
    ; 🧟 この手下を生命管理リストへ登録し、寵愛切れのタイマーを張ります。生者には魔法の寿命がなく、討たれるか寵愛切れでしか死にません。
    StorageUtil.FormListAdd(pcV, "ASTR2_VassalList", vassal, False)   ; False=重複不可＝二重登録を防ぎます（死霊経路と統一）
    SkyVault.SetFloat(vassal, "ASTR2_VassalRaiseTime", Utility.GetCurrentGameTime())   ; 〔SkyVault〕＝C++ VassalUpkeepが維持費の個別化で読みます
    SkyVault.SetInt(vassal, "ASTR2_VassalLiving", 1)                                  ; 〔SkyVault〕＝C++ VassalUpkeepも読みます
    SkyVault.SetFloat(vassal, "ASTR2_VassalLastLove", Utility.GetCurrentGameTime())   ; 〔SkyVault〕＝C++ VassalUpkeepも読みます（lastLove）
    ASTR2Native.ArmVassalLoveTimer(vassal)   ; 🕯️ 寵愛切れのタイマーを張ります。loveDays後に寵愛が尽きて死亡します。
    ASTR2Native.UpkeepStart()                ; ▶️ 手下が増えた＝維持費ジョブを稼働します（0体で止まってても再開）
    ; 👑 〔サーヴァントシップ〕のtier3(眷属)＝関係ランク3(Ally)を恒久同期＝BanditFaction敵対をペアごと上書きします。
    ASTR2Servantship.AddPoints(vassal, 90.0)

    ; 🩷 淫紋＝生者の手下の眷属の証です。寵愛満タン(段階6)で刻みます。以後はC++ VassalUpkeep(6h)が寵愛残りに応じ段階更新＆手下税を徴収します。
    ASTTattooScript tatR = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTTattooScript
    If tatR != None
        tatR.ApplyNpcSigil(vassal, 1.0)
    EndIf
    SkyVault.SetInt(vassal, "ASTR2_VassalSigilLvl", 6)
    SkyVault.SetInt(vassal, "ASTR2_VassalHasSchlong", OActorUtil.HasSchlong(vassal) as Int)   ; C++はシーン外で竿の有無を判定できない＝ここで控えて淫紋テクスチャの振り分けに使います
EndEvent

; 🧟💀 手下の死亡を即掃除します＝C++ TESDeathEventシンク(VassalDeath.cpp)が「手下ファクションの死亡」を拾って飛ばします。
;   再アニメされた死霊は ReferenceAlias.OnDeath が鳴かないのでこのC++死亡イベントが本命です（生者もこれで拾えます）。
;   sender=死んだアクターです。VassalListに居る＝うちの手下の時だけ即AshifyVassalします（居なければ空振り＝二重掃除なし）。
Event OnVassalDied(String eventName, String strArg, Float numArg, Form sender)
    Actor v = sender as Actor
    If v == None
        Return
    EndIf
    ; 生者(living=1)は本当に死んだ時だけです＝気絶(bleedout)を死と誤りません。死霊(living=0)は即死なので無条件で通します。
    If SkyVault.GetInt(v, "ASTR2_VassalLiving", 0) == 1 && !v.IsDead()
        Return
    EndIf
    Actor pcD = Game.GetPlayer()
    If StorageUtil.FormListHas(pcD, "ASTR2_VassalList", v)
        ASTConjCost.AshifyVassal(v)
    EndIf
EndEvent

; 🕯️ 寵愛切れによる意図的な死です。C++のAshifyLoveExpiredが送出します。OnVassalDiedの気絶ガードを通さない専用経路なので、
;    生きてる生者でも無条件でAshifyします（戦闘死/コンソールキルの気絶誤判定除外とは別物です）。
Event OnVassalLoveExpired(String eventName, String strArg, Float numArg, Form sender)
    Actor v = sender as Actor
    If v == None
        Return
    EndIf
    Actor pcL = Game.GetPlayer()
    If StorageUtil.FormListHas(pcL, "ASTR2_VassalList", v)
        ASTConjCost.AshifyVassal(v)
    EndIf
EndEvent

; 👣 生者の手下の置いてけぼり保険です＝プレイヤーのロケーション変化時、離れすぎた生者の手下をMoveToで手繰り寄せます。
;    正規フォロワー化(CurrentFollowerFaction)で大半は連れ回せますが、外セルへ出た時に自宅パッケージへ戻る取りこぼしを拾います。waitなし。
Event OnLocationChange(Location akOldLoc, Location akNewLoc)
    Actor pcRef = Game.GetPlayer()
    Int vi = StorageUtil.FormListCount(pcRef, "ASTR2_VassalList") - 1
    While vi >= 0
        Actor v = StorageUtil.FormListGet(pcRef, "ASTR2_VassalList", vi) as Actor
        If v != None && !v.IsDead() && SkyVault.GetInt(v, "ASTR2_VassalLiving", 0) == 1
            If v.GetDistance(pcRef) > 4000.0   ; 離れすぎ＝置いてけぼり→手繰り寄せます
                v.MoveTo(pcRef)
            EndIf
        EndIf
        vi -= 1
    EndWhile
EndEvent

; Hスキル→興奮ブースト受けです：C++が「相手(sender)＋その相手にしてる技術行為名(strArg・カンマ連結)」を毎ノード飛ばします。
;   ここで孫ランクの平均→控えめ倍率→OActorで相手の興奮増加倍率をセットします（"上手いほど相手が早くイく"）。
;   重い計算はC++に寄せ済＝ここは数発/シーンの軽い処理です。強さ=ASTR2_TechExciteStrength(アビリティコンフィグ・0=オフ)。
Event OnAstr2ExciteNode(String eventName, String strArg, Float numArg, Form sender)
    Actor partner = sender as Actor
    If partner == None
        Return
    EndIf
    Float strength = StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02)
    If strength <= 0.0
        Return
    EndIf
    String[] acts = StringUtil.Split(strArg, ",")
    Int sum = 0
    Int cnt = 0
    Int i = 0
    While i < acts.Length
        If acts[i] != ""
            sum += ASTR2Technique.GetActionRank(acts[i])   ; 孫ランク（その行為の上手さ1-10）
            cnt += 1
        EndIf
        i += 1
    EndWhile
    If cnt == 0
        Return
    EndIf
    Float avgRank = (sum as Float) / (cnt as Float)         ; 同じ相手に複数行為なら平均します
    Float mult = 1.0 + avgRank * strength                   ; 控えめ：強さ0.02なら rank10で×1.2
    OActor.SetExcitementMultiplier(partner, mult)
EndEvent

Event OnUpdate()
    ASTR2MCMScript.Get().LoadSettingsFromJson(true)
EndEvent

; 〔サーヴァントシップ〕：お供にしてる魅了NPCにゲーム時間で点を加算します（ASTR2Servantship.AddFollowerTime を駆動）。
; 対象＝プレイヤーの仲間(IsPlayerTeammate)かつ Servantshipファクション(0101C7AF)所属＝魅了して仲間化した子だけです（普通の旅仲間は除外）。
; ※OnUpdate(auto-import)とは別イベントなので衝突しません。OnUpdateGameTimeは引数なし＝経過時間は予約間隔(FollowerTickHours)です。
Event OnUpdateGameTime()
    Actor pcRef = Game.GetPlayer()
    Faction servFac = Game.GetFormFromFile(0x0101C7AF, "A Succubus Tale R2.esp") as Faction
    If pcRef != None && servFac != None
        Actor[] near = OActorUtil.GetActorsInRangeV2(pcRef, 4000.0)
        Int i = 0
        While i < near.Length
            Actor a = near[i]
            If a != None && a != pcRef && a.IsPlayerTeammate() && a.IsInFaction(servFac)
                ASTR2Servantship.AddFollowerTime(a, FollowerTickHours)
            EndIf
            i += 1
        EndWhile
    EndIf

    ; 🧟💠 ここから下は手下の"相乗り"分です＝テイム中の死霊/生者が居る時だけ処理します（居なければ上の〔サーヴァントシップ〕処理だけで抜ける＝相乗り分スキップ）。
    If StorageUtil.FormListCount(pcRef, "ASTR2_VassalList") > 0
    ; 🧟 手下の状態を定期的に確認します。死霊は使役の期限（VassalDaysが999未満なら寿命あり）が切れたら灰化させます。生者の寵愛切れはC++へ移設済みなので、ここでは死亡済みの手下の後始末だけを行います。手下はASTR2_VassalListでまとめて管理します。
    ;    死霊の維持費・生者の手下税(淫紋の段階更新込み)は C++ VassalUpkeep（〔クロノス〕・6ゲーム時間ごと）へ移設済です。
    Float nowDay = Utility.GetCurrentGameTime()
    Int vi = StorageUtil.FormListCount(pcRef, "ASTR2_VassalList") - 1
    While vi >= 0
        Actor v = StorageUtil.FormListGet(pcRef, "ASTR2_VassalList", vi) as Actor
        If v == None
            StorageUtil.FormListRemoveAt(pcRef, "ASTR2_VassalList", vi)   ; 消えた参照(亡霊化など)の掃除です
        ElseIf v.IsDead()
            ; 💀 死亡→後始末します（完全巻き戻し）。AshifyVassalが後始末(死霊は灰化・生者は死体)＋ResetActor(基テンプレへ)＋List除去＋スロット解放まで実施します（Deleteはしません）。ここで個別除去はしません。
            ASTConjCost.AshifyVassal(v)
        Else
            Float days = StorageUtil.GetFloatValue(v, "ASTR2_VassalDays", 999.0)
            Float raiseTime = SkyVault.GetFloat(v, "ASTR2_VassalRaiseTime", nowDay)
            Bool isLiving = (SkyVault.GetInt(v, "ASTR2_VassalLiving", 0) == 1)
            ; ⏳ Duration切れ＝魔法の寿命で崩れます。死霊(操り人形)のみ＝生者は寿命なし＝永遠（死ぬのは寵愛切れだけ）。
            Bool expireDur = (!isLiving && days < 999.0 && (nowDay - raiseTime) > days)
            ; 💋 生者の寵愛切れによる死はC++のVassalUpkeepへ移設しています。淫紋の6段階が尽きたところで死に、手下税と同じタイミングで判定します。
            If expireDur   ; 死霊のDuration切れのみ（生者の寵愛切れ死はC++ VassalUpkeepへ移設＝二重処理を防ぐ）
                ASTConjCost.AshifyVassal(v)   ; 灰化します（崩れ去る）＋リスト除去
            EndIf
        EndIf
        vi -= 1
    EndWhile
    EndIf   ; 🧟💠 手下の相乗り分の〔ゲート〕閉じです（VassalList>0の時だけここまで処理しました）

    RegisterForSingleUpdateGameTime(FollowerTickHours)   ; 次のtickを予約します（ループ継続・〔サーヴァントシップ〕のため常に回ります）
EndEvent

; ===== ネイル装備検知（7つの大罪）=====
; プレイヤーがネイルを着脱→NailManagerに効果セットの張り直しを依頼します（相乗り/コンプ判定はNailManager側）。
Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
    Int idx = ASTR2NailManager.IdxFromArmor(akBaseObject)
    If idx >= 0
        ASTR2NailManager.Get().RefreshEffects(idx)     ; ネイル着けた→効果セットを算出します
    EndIf
EndEvent

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
    If ASTR2NailManager.IdxFromArmor(akBaseObject) >= 0
        ASTR2NailManager.Get().RefreshEffects(-1)       ; ネイル外した→効果OFF
    EndIf
EndEvent

