Scriptname ASTR2MainScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
ASTR2MainScript Function Get() Global
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
EndFunction

; =================================================================
; 💡 どのスクリプトからでも本体を取得するためのアクセサです（デッドロック回避用）
; =================================================================
ASTR2MCMScript Function GetMCM()
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MCMScript
EndFunction
ASTR2LifeForceBarScript Function GetLFBar()
    Return Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
EndFunction
ASTR2ExpBarScript Function GetExpBar()
    Return Game.GetFormFromFile(0x013619, "A Succubus Tale R2.esp") as ASTR2ExpBarScript
EndFunction
ASTLvlManager Function GetLvlManager()
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
EndFunction
ASTDrainScript Function GetDrainScript()
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTDrainScript
EndFunction
ASTR2LogoScript Function GetLogo()
    Return Game.GetFormFromFile(0x013627, "A Succubus Tale R2.esp") as ASTR2LogoScript
EndFunction
ASTR2ActorHpBarScript Function GetActorHpBar()
    Return Game.GetFormFromFile(0x01361A, "A Succubus Tale R2.esp") as ASTR2ActorHpBarScript
EndFunction
; =====================================================================================
; ⚙️ 他のスクリプトへの参照（プロパティ）です。
; =====================================================================================

Float Property LifeForceX Auto
Float Property LifeForceY Auto
Float Property ExpX Auto
Float Property ExpY Auto

Int Property LFDisplayMode Auto
Int Property ExpDisplayMode Auto
Int Property LifeForceCheckKey Auto
Int Property ExpCheckKey Auto
; =====================================================================================
; ⚙️ 起動時にポップアップを出したかを記憶するフラグです。
; =====================================================================================
Bool Property bHasAskedInitialAwakening = false Auto
Bool Property bHasCoreInitialized = false Auto Hidden
; =====================================================================================
; ⚙️ 殺害フラグ用フラグです。
; =====================================================================================

Bool Property AllowKillNPC = false Auto
Bool Property AllowKillUnique = false Auto

; =====================================================================================
; ⚙️ ASTから移植したものです（プロパティ）。
; =====================================================================================

;/ Lvl /;
GlobalVariable Property SuccubusLvl Auto

;/ For use by other scripts /;
bool Property isOArousedInstalled = false Auto
; ★ドレインON/OFFは外部〔SkyVault〕を"単一の正"にします。H中ドレインC++核(HDrain.cpp)の〔門番〕がC++から直読みできます。
;   プロパティ名は据え置きなので、トグル/他ファイルは無改修です（.IsDrainOn がそのまま〔SkyVault〕経由になります）。LF裏打ちと同型です。
;   holder=None(グローバル名前空間／C++側はholder=0で一致)。キー=ASTR2_IsDrainOn（1=ON／既定ON）。
bool Property IsDrainOn
    bool Function Get()
        Return SkyVault.GetInt(None, "ASTR2_IsDrainOn", 1) == 1
    EndFunction
    Function Set(bool value)
        SkyVault.SetInt(None, "ASTR2_IsDrainOn", value as Int)
    EndFunction
EndProperty

;/ Creation Kit References /;
Actor Property playerRef Auto

; 💋 HasMagicEffect判定専用(MCM非依存)。Autoの焼き込み罠を避けFormID直参照のget-onlyに統一(他スペルと同じ理由)。
MagicEffect Property ASTOrgasmHealthBuff
    MagicEffect Function Get()
        return Game.GetFormFromFile(0x012060, "A Succubus Tale R2.esp") as MagicEffect
    EndFunction
EndProperty

;/ 魅了アロウザルゲート調整値（MCM・ASTSedMagEffScriptが参照） /;
float Property seductionLinef  = 99.0 Auto   ; 〔魅了ライン〕です（注入後arousalがこれ以上で陥落します／OSL上限は約99.9996で、100は到達不可です）
float Property seductionBasef  = 50.0 Auto   ; Lv1のスパイク量です
float Property seductionStepf  = 5.0 Auto    ; レベルごとの増分です
float Property seductionBonusf = 10.0 Auto   ; 指向ボーナスです（得意な性別を狙った時）

;/ MOD全体の挙動設定（MCM設定値） /;
; ★デメリット(淫魔力の時間減衰など)のON/OFFは〔SkyVault〕裏打ちです。C++の時計の核が〔門番〕として直読みします。
;   プロパティ名は据え置きなので、MCMトグルも他ファイルも無改修です（LF/IsDrainOnと同じ形）。既定はONです。
bool Property AreDisadvantagesEnabled
    bool Function Get()
        Return SkyVault.GetInt(None, "ASTR2_DisadvantagesOn", 1) == 1
    EndFunction
    Function Set(bool value)
        SkyVault.SetInt(None, "ASTR2_DisadvantagesOn", value as Int)
    EndFunction
EndProperty
bool Property usesTatoo = true Auto

int Property prevLFSpell = -1 Auto Hidden
Float Property kSceneFlagSetTime = 0.0 Auto Hidden   ; 〔看板〕(IsOstimActive)を最後に1にした実時間です（古い〔看板〕の自己修復用）
Bool Property kONKickPending = false Auto Hidden      ; ONモードの配役キックを予約中かどうかです（マス着弾の多重呼び出しを1回に束ねる用）
Bool Property kGreetTokenPending = false Auto Hidden  ; OFFモードのgreetトークン付与を予約中かどうかです（マス着弾を1回に束ねて最寄り1人へForceGreetします）
Actor Property kGreetTokenHolder = None Auto Hidden   ; 今greetトークン(ForceGreet)を持っている1人で、greet会話キャンセル検知のヒントです（GrantGreetTokenが更新します）
Bool Property kGreetDialogueOpen = false Auto Hidden  ; 開いた会話メニューがトークン保持者との会話かどうかです（閉じた時にリレー継続するか判定します）
; 🎣 会話閉じフックの起動予約です（Fragmentでセット→OnMenuClose(Dialogue Menu)で起動します）。0=なし/1=Yes・愛でる/3=3P。
Int Property pendingRoute = 0 Auto Hidden
Actor Property pendingSpeaker Auto Hidden
Bool Property pendingPetHarem = false Auto Hidden
Bool Property kGreetRouteChosen = false Auto Hidden   ; greet会話で選択肢(Yes/No/3p)を押したかどうかで、会話キャンセル(押してない)と区別する印です（TIF Fragment_0がON/OnMenuOpenでOFF）
Bool Property kReenableAddActors = false Auto Hidden  ; OStimの「Add Actors At Start」を一時的に切った→シーン終了後に戻す印です
Actor[] Property kNightmareParticipants Auto Hidden    ; 夢魔シーンの参加者です（H後にEvaluatePackageでAIリセット・夢魔限定／魅了シーンはNone/空で素通り。Phase Bで複数化＝対象＋相方）
Bool Property kNmReady = false Auto Hidden             ; kNightmareParticipantsが有効かどうかで、Actor[]==None比較のcast-errorログ〔地雷〕を避けるフラグです
Actor[] Property kServantSceneActors Auto Hidden       ; 〔サーヴァントシップ〕+3点用です：シーン開始時の参加者を控える→OnOstimEndで加点します（開始即キャンセルでは加点なし＝exploit防止）
Bool Property kSvReady = false Auto Hidden             ; kServantSceneActorsが有効かどうかで、同上です（配列==None比較を避けるフラグ）
Bool Property kHoldSwapDone = false Auto Hidden       ; 当該シーンでHoldスワップ実施済みかどうかです（GetSceneActors準備前は遅延し、scene_changedで再試行します）
Int Property kHoldRetries = 0 Auto Hidden             ; Holdスワップの再試行回数です。壊れシーン(OStimがアクター未確立)で無限ポーリングしない上限打ち切り用です
; =================================================================
; 1. プロパティです（CKでリンクが必要なもの：外部MOD）。
; =================================================================
OsexIntegrationMain Property ostim Auto
OArousedScript Property oAroused Auto

; =================================================================
; 2. 普通の変数です（CKリンク不要：自作スクリプト）。
; =================================================================

; =====================================================================================
; ⚙️ 起動関係のイベントです。
; =====================================================================================
Event OnInit()
    RegisterForSingleUpdate(3.0)
EndEvent

; ★OnPlayerLoadGame() はこの ASTR2MainScript には置きません。
;   extends Quest では OnPlayerLoadGame が ReferenceAlias 専用イベントで永久に鳴らないためです
;   （実証：最初に書くはずの `[LOAD]` 行が、ログ14,170行・ロード99回で0件でした）。
;   ①Maintenance()②[LOAD]区切りログ③覚醒プロンプトの保険は
;   `ASTR2PlayerAliasScript.OnPlayerLoadGame`（ReferenceAliasで確実に鳴る本物のロードフック）に置いています。
;   ④オートインポートは同アライアスが既に同じ処理を持つので、ここには置きません。

Event OnUpdate()
    ; 💾 ロード後の自動インポートはここには無く、ReferenceAlias側(ASTR2PlayerAliasScript.OnUpdate)が持ちます。

    ; ONモードの配役キック：マス着弾で多数の予約が来ても RegisterForSingleUpdate は1個に潰れる→ここで1回だけ起動します
    If kONKickPending
        kONKickPending = false
        TryStartNextONScene()
        Return
    EndIf

    ; 🎫 OFFモードのgreetトークン付与：マス着弾の多重予約を1回に束ねて最寄り1人にForceGreetを渡します（ScheduleGreetTokenのOFF版枠／ON/OFF厳密分岐）
    If kGreetTokenPending
        kGreetTokenPending = false
        GrantGreetToken(playerRef, "charm")
        Return
    EndIf

    ; 1. コアシステムの初期化です。
    If !bHasCoreInitialized
        bHasCoreInitialized = true
        ostim = Outils.GetOStim()
        CheckForIntegrations()
        SuccubusLvl.SetValueInt(0)
        
        ; ドレイン先走り対策です
        ASTR2LogoScript Logo = GetLogo()
        If Logo != None
            Logo.ShowDrainLogo(false)
        EndIf
        
        GetLFBar().InitializeLifeForceOnNewGame()
        GetExpBar().InitializeExpOnNewGame()
        Maintenance()
        
        If !bHasAskedInitialAwakening
            RegisterForMenu("RaceSex Menu")
        EndIf
    EndIf

    ; 2. 覚醒前の場合、ニューゲームか途中導入かを判断して分岐します。
    If !bHasAskedInitialAwakening
        Quest MQ101 = Game.GetForm(0x0003372B) as Quest
        Bool isIntroDone = false
        
        If MQ101 != None
            If MQ101.IsCompleted() || MQ101.GetStage() >= 900
                isIntroDone = true
            EndIf
        EndIf

        If isIntroDone
            ; 🌟 途中導入（既存セーブ）ルート：すでにゲーム本編が始まっている場合です
            If !Utility.IsInMenuMode()
                WaitForSafeAwakening()
            Else
                ; メニューを開いていたら5秒後に再確認します
                RegisterForSingleUpdate(5.0)
            EndIf
        Else
            ; 🌟 ニューゲームルート：まだゲームが始まっていない（ヘルゲンやキャラメイク中）場合です
            ; ここでは何もしません（OnMenuCloseに任せる）が、監視のために5秒ループは回します
            RegisterForSingleUpdate(5.0)
        EndIf
    EndIf
EndEvent


; 🎫 会話メニューが開いた瞬間に「これはトークン保持者(greetで寄ってきた本人)との会話か」を記録します。
;   vendor等の無関係な会話は保持者がIsInDialogueWithPlayer=Falseで素通りで、全会話に飛散させません。
Event OnMenuOpen(String MenuName)
    If MenuName == "Dialogue Menu"
        Bool inDlg = (kGreetTokenHolder != None && kGreetTokenHolder.IsInDialogueWithPlayer())
        kGreetDialogueOpen = inDlg
        kGreetRouteChosen = false   ; 会話開始でリセットします。この会話で選択肢を押したらTIF Fragment_0がONにします
    EndIf
EndEvent

Event OnMenuClose(String MenuName)
    If MenuName == "RaceSex Menu"
        If !bHasAskedInitialAwakening
            ; キャラメイク完了。ニューゲームルートの待機処理へ移ります。
            WaitForSafeAwakening()
        EndIf
        UnregisterForMenu("RaceSex Menu")
    ElseIf MenuName == "Dialogue Menu"
        ; 🎣 フック起動です。Yes/3p/愛でるを選ぶとFragmentが予約(pending)→会話が閉じた瞬間ここで起動します。
        ;   会話UIはもう消えています。チラ見えゼロで、環境で閉じが遅くても閉じイベントで正確に追従します（固定Wait/ポーリング全滅の最終解）。
        If pendingRoute != 0
            Int r = pendingRoute
            Actor sp = pendingSpeaker
            Bool ph = pendingPetHarem
            pendingRoute = 0
            pendingSpeaker = None
            pendingPetHarem = false
            If r == 1
                StartYesRoute(sp, ph)
            ElseIf r == 3
                Start3pRoute(sp)
            EndIf
        ElseIf kGreetDialogueOpen && !kGreetRouteChosen
            ; 🎫 greet会話を選択肢キャンセル(Tab/Esc)した時に、TIF未実行でリレーが止まる穴を塞ぎます（本当のキャンセルだけ最寄りにトークンを渡し直します）。
            GrantGreetToken(playerRef, "cancel")
        EndIf
        kGreetDialogueOpen = false
    EndIf
EndEvent

; =====================================================================================
; 🌟 他MODのメニューが閉じるのを待つ安全待機ループです
; =====================================================================================
Function WaitForSafeAwakening()
    If bHasAskedInitialAwakening
        Return
    EndIf

    ; 1. 他のMODのPOP(メニュー)が開いている間は待ちます
    While Utility.IsInMenuMode()
        Utility.Wait(1.0)
    EndWhile
    
    ; 2. 完全にメニューが閉じたら、そこから5秒待ちます
    Utility.Wait(5.0)
    
    ; 3. 5秒経った後、もしまた別のPOPが開いていたら閉じるまで待ちます
    While Utility.IsInMenuMode()
        Utility.Wait(1.0)
    EndWhile
    
    ; 4. 満を持して覚醒ポップアップを出します。
    ShowInitialAwakeningPrompt()
EndFunction

; =====================================================================================
; 🌟 Maintenance：キー/ModEvent登録・各バー再計算・LF減衰ジョブ張り直しをまとめる共通メンテです（初期化時とロード後に呼びます）
; =====================================================================================

Function Maintenance()
    UnregisterForAllKeys()
    ASTR2MCMScript MCM = GetMCM()
    If LifeForceCheckKey > 0
        RegisterForKey(LifeForceCheckKey)
    EndIf
    
    If ExpCheckKey > 0
        RegisterForKey(ExpCheckKey)
    EndIf
    
    If MCM.DrainSwitchKey > 0
        RegisterForKey(MCM.DrainSwitchKey)
    EndIf
    GetDrainScript().RegisterHDrainDone()   ; 💋 H中ドレインC++核の完了合図(astr2_hdrain_done)の受け口をONにします（記帳処理はASTDrainScript側です）
    GetDrainScript().RegisterCombatDrainDone()   ; 🩸 戦闘ドレインC++核の完了合図(astr2_combatdrain_done)の受け口をONにします（記帳処理はASTDrainScript側です）

    ; 🌟 アクターHPバーのOStim連動を再登録します（ロード後もシーン連動を有効にする）
    GetActorHpBar().OnLoadFunc()

    ; 🔋 ロード時にライフフォース最大値を式で再計算します（既存セーブ/MOD更新でも整合）
    GetLFBar().RecalcMaxStorage()

    GetLFBar().RegisterLFTick()   ; 🔋 C++の時計（〔クロノス〕）が削った時の合図 astr2_lf_tick の受け口を張ります。バー/段階バフの更新用です
    ; 🔋 LF減衰の〔クロノス〕ジョブをロード時に張り直します（enabledはセッション毎にリセットされるので、毎ロード再設定します）。
    ;   サキュバス&デメリットONなら開始します（マーカー="今"で、OFF期間は請求しません）／でなければ停止します（発火しません）。
    SkyVault.SetInt(None, "ASTR2_Awake", (ASTLvlManager.Get().IsSuccubus() as Int))   ; 🔋 覚醒状態を大元フラグへ書き込みます。〔クロノス〕の全ジョブのポーズ判定に使い、人間なら全停止します
    If ASTLvlManager.Get().IsSuccubus() && AreDisadvantagesEnabled
        ASTR2Native.LFDecayStart()
    Else
        ASTR2Native.LFDecayStop()
    EndIf
    ; 🔢 淫魔力/経験値バーの「場所」をC++へ渡します。数字HUD(BarNumbers)がバーに追従して重なります。
    ;   ★ウィジェットが未準備の時は空文字で、C++は次の周期で描くので、ここで待たなくていいです。
    ASTR2Native.BarNumbersBind(GetLFBar().GetBarWidgetRoot(), GetExpBar().GetBarWidgetRoot())
EndFunction

; 🌟 覚醒プロンプトの保険です。まだ「サキュバスになる？」を訊いていないセーブをロードした時に、5秒後のOnUpdateで
;   覚醒分岐へ入れます（主経路はOnInit→OnUpdate。ここは"訊く前にロードし直した"取りこぼし用）。
;   ★RegisterForSingleUpdateは自分のスクリプトにしか張れないので、ロードフック(PlayerAlias)から呼んでもらう形です。
Function ScheduleAwakeningCheck()
    If !bHasAskedInitialAwakening
        RegisterForSingleUpdate(5.0)
    EndIf
EndFunction
; =====================================================================================
; 🌟 初回ポップアップ処理です
; =====================================================================================
Function ShowInitialAwakeningPrompt()
    If bHasAskedInitialAwakening
        Return
    EndIf
    bHasAskedInitialAwakening = true

    Message MsgInitialAwakening = Game.GetFormFromFile(0x01361F, "A Succubus Tale R2.esp") as Message
    Message MsgAwakeningYes = Game.GetFormFromFile(0x013620, "A Succubus Tale R2.esp") as Message
    Message MsgAwakeningNo = Game.GetFormFromFile(0x013621, "A Succubus Tale R2.esp") as Message

    If MsgInitialAwakening != None
        Int choice = MsgInitialAwakening.Show() 
        
        If choice == 0
            ASTLvlManager Lvl = GetLvlManager()
            If Lvl != None && !Lvl.IsSuccubus()
                Lvl.LevelUp()
                OnLoadFunc()
            EndIf

            ; 🎴 ネイル初回配布：覚醒直後に気分を訊いて1本渡します（シンフル・ネイル・ASTR2NailManager）
            ASTR2NailManager.Get().InitialMoodGrant()

            If MsgAwakeningYes != None
                MsgAwakeningYes.Show()
            EndIf
            
            ; 🌟 すべてのメッセージボックスやメニューが完全に閉じられるまで待機し続けます
            While Utility.IsInMenuMode()
                Utility.Wait(0.5)
            EndWhile
            
            ; 完全にゲーム画面に戻った後、エンジンが落ち着くのを1.5秒だけ待ってから命令を出します
            Utility.Wait(1.5)
            
            ; 🌟 ここでトグルのズレをリセットします。強制的にON状態に同期させます
            IsDrainOn = true
            UpdateHUDVisibility()
            
            ASTTattooScript Tattoo = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTTattooScript
            If Tattoo != None
                Tattoo.RefreshTattoo()
            EndIf
            
        ElseIf choice == 1
            If MsgAwakeningNo != None
                MsgAwakeningNo.Show()
            EndIf
            
            ; 🌟 NOの場合も同様に監視します
            While Utility.IsInMenuMode()
                Utility.Wait(0.5)
            EndWhile
            Utility.Wait(0.5)
            
            UpdateHUDVisibility()
        EndIf
    EndIf
EndFunction


; =====================================================================================
; ⌨️ ホットキーを両方のバーの分登録する関数です
; =====================================================================================
Function SetLifeForceKeybind(int newKey)
    UnregisterForKey(LifeForceCheckKey)
    LifeForceCheckKey = newKey
    RegisterForKey(newKey)
EndFunction

Function SetExpKeybind(int newKey)
    UnregisterForKey(ExpCheckKey)
    ExpCheckKey = newKey
    RegisterForKey(newKey)
EndFunction

; =====================================================================================
; 🎯 ホットキーが押されたときの処理です
; =====================================================================================
Event OnKeyDown(Int keyCode)
    ASTR2MCMScript MCM = GetMCM()
    If MCM == None
        Return
    EndIf

    ASTR2LifeForceBarScript lfQuest = GetLFBar()
    ASTR2ExpBarScript expQuest = GetExpBar()
    
    If keyCode == MCM.DrainSwitchKey
        ; 💡 スイッチを切り替えて、画面にロゴ（淫紋）を出す関数を呼びます。
        SwitchDrainModes()
        Return ; ここで処理を終わらせます
    EndIf

    If (MCM.LifeForceCheckKey == MCM.ExpCheckKey) && (keyCode == MCM.LifeForceCheckKey)
        If lfQuest != None && expQuest != None
            Bool nextState = !lfQuest.LFisBarVisible
            
            lfQuest.LFisBarVisible = nextState
            expQuest.ExpisBarVisible = nextState
            
            If MCM.LFDisplayMode == 1
                If nextState == True
                    lfQuest.CheckLifeForce() 
                Else
                    lfQuest.ASTR2LifeForceBar.FadeOutBar() 
                EndIf
            EndIf
            
            If MCM.ExpDisplayMode == 1
                If nextState == True
                    expQuest.CheckExp()      
                Else
                    expQuest.ASTR2ExpBar.FadeOutBar()      
                EndIf
            EndIf
        EndIf
        GetActorHpBar().SyncFromMain()   ; AHPバーをLF/EXP更新後の最新状態へ同期します（共有キー時のズレ防止）
        Return
    EndIf

    If keyCode == MCM.LifeForceCheckKey
        If lfQuest != None
            If MCM.LFDisplayMode == 1
                lfQuest.ToggleVisibility()
            Else
                lfQuest.CheckLifeForce()
            EndIf
        EndIf
    EndIf

    If keyCode == MCM.ExpCheckKey
        If expQuest != None
            If MCM.ExpDisplayMode == 1
                expQuest.ToggleVisibility()
            Else
                expQuest.CheckExp()
            EndIf
        EndIf
    EndIf

    ; LF/EXPを更新した後にAHPバーも同じ状態へ同期します（共有キー時のズレ防止）
    GetActorHpBar().SyncFromMain()
EndEvent

; =====================================================================================
; 📺 HUD（バー/ロゴ）の表示を今の状態に合わせて更新します
; =====================================================================================
Function UpdateHUDVisibility()
    ASTR2MCMScript MCM = GetMCM()
    ASTR2LifeForceBarScript lfQuest = GetLFBar()
    ASTR2ExpBarScript expQuest = GetExpBar()
    ASTLvlManager Lvl = GetLvlManager() 
    ASTR2LogoScript Logo = GetLogo() ; 💡 ロゴスクリプトも取得します。
    
    ; 状態に応じて処理を完全に二分します
    If Lvl != None && Lvl.IsSuccubus() == false
        ; 🌟 [MODオフ時/人間] の分岐です。
        ; バーが裏で表示されないように、Mainのモードを「2 (非表示)」で上書きロックします。
        If MCM != None
            LFDisplayMode = 2
            ExpDisplayMode = 2
        EndIf
        
        ; 既存のバー非表示処理です
        If lfQuest != None
            lfQuest.LFisBarVisible = false 
            lfQuest.FadeOutBar()
        EndIf
        If expQuest != None
            expQuest.ExpisBarVisible = false 
            expQuest.FadeOutBar()
        EndIf
        
        ; 🌟 人間ならロゴも絶対に消します。
        If Logo != None
            Logo.ShowDrainLogo(false)
        EndIf
    Else
        ; 🌟 [MODオン時/サキュバス] の分岐です。
        ; MCMに保存されている「本当の表示設定」を復元します。
        If MCM != None
            LFDisplayMode = MCM.LFDisplayMode
            ExpDisplayMode = MCM.ExpDisplayMode
            
            ; ホットキーの同期処理です
            If lfQuest != None && expQuest != None
                If MCM.LifeForceCheckKey == MCM.ExpCheckKey && MCM.LifeForceCheckKey > 0
                    Bool syncState = lfQuest.LFisBarVisible
                    expQuest.ExpisBarVisible = syncState
                EndIf
            EndIf
        EndIf
        
        ; 復元した設定で各バースクリプトに更新を任せます。
        If lfQuest != None
            lfQuest.CheckLifeForce()
        EndIf
        If expQuest != None
            expQuest.CheckExp()
        EndIf
        
        ; 🌟 サキュバスならロゴもMCMの設定に合わせて再表示させます。
        If Logo != None
            Logo.UpdateLogoDisplay()
            Logo.ShowDrainLogo(IsDrainOn)
        EndIf
    EndIf
EndFunction

; =====================================================================================
; ⚙️ ASTから移植したものです（Event＆Function）
; =====================================================================================
Function RefreshBuffsDebuffsEnergy()
    int newLfSpell = prevLFSpell
    
    ASTR2LifeForceBarScript Bar = GetLFBar()
    ASTLvlManager Lvl = GetLvlManager() ; 💡 ここで必要な瞬間にGetします。
    
    int currentEnergy = Bar.LFenergyCurr
    int maxEnergy = Bar.LFenergyMax

    If (Lvl.IsSuccubus() && AreDisadvantagesEnabled)
        If currentEnergy <= (maxEnergy * 0.25) 
            If currentEnergy > (maxEnergy * 0.06)
                newLfSpell = 0
            Else
                newLfSpell = 1
            EndIf
        ElseIf currentEnergy >= (maxEnergy * 0.75) 
            If currentEnergy < (maxEnergy * 0.94)
                newLfSpell = 2
            Else
                newLfSpell = 3
            EndIf
        Else 
            newLfSpell = -1
        EndIf
    Else
        newLfSpell = -1
    EndIf

    If (prevLFSpell != newLfSpell)
        LFMessage(newLfSpell)
        prevLFSpell = newLfSpell
    EndIf
    ; 🌟 再生バフは、サキュバスソウル基準×LF係数で再計算します。LF残量が変わるたび更新します。
    If Lvl != None
        Lvl.ApplyRegenBuffs()
    EndIf
EndFunction

Function LFMessage(int i)
    If i == 0
        Debug.Notification("$ASTR2_Debug_LFLow1")
    ElseIf i == 1
        Debug.Notification("$ASTR2_Debug_LFLow2")
    ElseIf i == 2
        Debug.Notification("$ASTR2_Debug_LFHigh1")
    ElseIf i == 3
        Debug.Notification("$ASTR2_Debug_LFHigh2")
    EndIf
EndFunction

Event OnOstimOrgasm(string eventName, string strArg, float numArg, Form sender)
    Actor Act = sender as Actor
    ASTLvlManager Lvl = GetLvlManager() ; 💡 ここで必要な瞬間にGetします。

    ; 🌟 オーガズムバフの予約印です。イベントの"先頭"で立てます（自分も相手も共通・キャストはシーン終了時）。
    ;   ★ここより下(Drain/Hスキルサンプル)でシーンが切れたり処理が止まっても印は残ります。取りこぼしません。
    ;   実際にフィニッシュ絡みで下流が丸ごと流れ、イッたのに印が付かない事故が出たため先頭へ移しました。
    If Act != None
        StorageUtil.SetIntValue(Act, "ASTR2_OrgBuffPending", 1)
    EndIf

    ; 🩹 Hスキルサンプルです。先に sceneId/pos を捕獲します。下流のフィニッシャーが
    ;   OThread.Stop(0) でシーンを切っても、Detect系は OMetadata の静的メタ読みで、捕獲値からサンプルできます。
    ;   そのため、フィニッシュ時も欠落しません。
    String techScene = ""
    Int techPos = -1
    If ostim != None && ostim.IsPlayerInvolved()
        techScene = OThread.GetScene(0)
        techPos = OThread.GetActorPosition(0, playerRef)
    EndIf

    ; 💋 H中ドレイン本体はここから呼びません（フルC++化）。C++核 HDrain.cpp が ostim_orgasm を
    ;   直受けして〔門番〕/威力/HP減/LF加算まで済ませ、記帳処理は ASTDrainScript.OnHDrainDone（astr2_hdrain_done）が持ちます。


    ; 🌟 イカせXP：NPCをイカせたら1回だけ（シーン単位de-dup）pendingに積みます。付与はシーン終了時です(FlushSceneXp)。
    If Act != None && Act != playerRef
        If StorageUtil.GetFloatValue(Act, "ASTR2_OrgasmScene", -1.0) != kSceneFlagSetTime
            StorageUtil.SetFloatValue(Act, "ASTR2_OrgasmScene", kSceneFlagSetTime)
            Lvl.AddPendingOrgasm()
        EndIf
    EndIf

    ; 🌟 イカせ記録：NPCをイカせた回数と、一番イカせた相手を記録します（プレイヤー参加シーンのみ・オーガズム毎に1カウント）
    If Act != None && Act != playerRef && ostim != None && ostim.IsPlayerInvolved()
        Lvl.RecordOrgasm(Act)
        ASTR2Servantship.OnOrgasm(Act)   ; 〔サーヴァントシップ〕 +0.5点です（イカせた・基礎）
        ; 👅 Hスキル報酬：イカせた瞬間の行為(孫)に+10秒を与えます（相手イカせ毎回・techScene/techPosは上で捕獲済）。C++が今ノードのプレイヤー行為へ加算します。要dllリビルドで有効化します。
        ASTR2Technique.AddOrgasmBonus(techScene, techPos)
    EndIf

    ; ※オーガズムバフの予約印はこのイベントの先頭で立て済みです（下流で止まっても取りこぼさないため）

    ; 🌟 H中フィニッシュ再判定（イカせ再トリガ）：全員floor到達後は reachedFloor が二度と立たず再発火しないため、
    ;   イカせ(オーガズム)を再トリガにして「全員floor＆殺せる相手あり」を詰めます（取りこぼし生存の対策）。
    ;   ※mode2(フィニッシュ後ロック)は魅了パッケージ剥がし(FREEZE対策)で解消した可能性大→復活させて様子見します。
    If IsDrainOn && ostim != None && ostim.IsPlayerInvolved()
        GetDrainScript().TryFinisher(playerRef)
    EndIf
EndEvent

Event OnOstimEnd(string eventName, string strArg, float numArg, Form sender)
    ; 🌟 オーガズムバフ（自分）：H中に撃たずここでまとめます。H中の負荷を増やしません
    GetLvlManager().TryOrgasmBuffPlayer()
    While ostim.AnimationRunning()
        Utility.Wait(0.1)
    EndWhile

    ; 💋 生者化演出：直前がリヴァイヴィングのキスなら、ここで生者化＋ピンク霧を出します（保留印はASTConjCost.TryReviveVassalが立てます／通常Hはno-opでStorageUtil読み1回だけです）。
    ASTConjCost.OnReviveSceneEnded()

    Utility.Wait(3)
    
    ; 〔看板〕(IsOstimActive)を下ろすのは C++(HpBarFeed の ThreadEnded→=0) が駆動します。Papyrus側で手動=0にはしません。
    ; ※開始=1(A)/失敗ロールバック=0(B・1201含む)/HealStaleSceneFlag(D)は据え置きです。C++が拾えない経路の保険です。
    ; 🌟 シーン終了：貯めた「イカせXP＋吸い切りボーナスXP」をまとめて付与します（GrantXp経由で総経験値にも集計します）
    GetLvlManager().FlushSceneXp()

    ; 🌟 〔サーヴァントシップ〕 +3点（H完遂）：開始時に控えた参加NPCへ加点します。開始→即キャンセル(end未到達)なら控えが使われず加点なしで、exploit防止になります。名前どおり"終了で加点"です
    If kSvReady
        Int sv = 0
        While sv < kServantSceneActors.Length
            If kServantSceneActors[sv] != None && kServantSceneActors[sv] != playerRef
                ASTR2Servantship.OnSexEnd(kServantSceneActors[sv])
                CleanupActor(kServantSceneActors[sv], True)   ; ★H後の魅了解除を保証します。FinalizeSceneがタイムアウトでcleanupをスキップしても、参加者が必ず解除される→再greet(1発で2回H)を断ちます。〔サーヴァントシップ〕faction/ポイントは別管理で温存します
                ; 🧟 H完遂で参加している手下の寵愛タイマーをリセットします（最後の接触を更新し、放置で死体化するまでの猶予が延びます）
                If StorageUtil.FormListHas(playerRef, "ASTR2_VassalList", kServantSceneActors[sv])
                    SkyVault.SetFloat(kServantSceneActors[sv], "ASTR2_VassalLastLove", Utility.GetCurrentGameTime())   ; ★〔SkyVault〕で、C++ VassalUpkeep(手下税/淫紋)も読みます
                    ASTR2Native.ArmVassalLoveTimer(kServantSceneActors[sv])   ; 🕯️ H完遂で寵愛切れ死タイマーを延長します（期限リセット・生者だけ内部判定）
                EndIf
                ; 🌟 オーガズムバフ（相手）：このシーンでイッた非敵対NPCへHP最大＋再生3種を与えます（判定は関数側）
                GetLvlManager().TryOrgasmBuffNpc(kServantSceneActors[sv])
            EndIf
            sv += 1
        EndWhile
        kServantSceneActors = PapyrusUtil.ActorArray(0)
        kSvReady = false
    EndIf

    ; 🌙 夢魔シーンの参加者をAIリセットします（H後の棒立ち/ベッド戻りムラ対策・夢魔限定で、魅了シーンはNone/空で素通りします）
    If kNmReady
        Int nr = 0
        While nr < kNightmareParticipants.Length
            Actor np = kNightmareParticipants[nr]
            If np != None && np != playerRef
                np.EvaluatePackage()
            EndIf
            nr += 1
        EndWhile
        kNightmareParticipants = PapyrusUtil.ActorArray(0)
        kNmReady = false
    EndIf

    ; 自動配役のために黙らせていた「Add Actors At Start」を元に戻します
    RestoreAddActorsMenu()
    ; ONモードなら次の組み合わせを自動で予約します（OFFはForceGreet任せで、Main側は何もしません）
    ScheduleONKick()
EndEvent

; 🔄 C++(ThreadEnded)が〔看板〕(IsOstimActive)を0にした"瞬間"に飛びます。シーン終了の確定イベントです（C++が送出します）。
;   起動側がostim_startで駆動するのと対：終了側はここで「次の魅了NPCへの受け渡し」を駆動します。
;   〔看板〕はもう0なので、近くで待機中(シーン中Followへ降格していた)魅了NPCを再評価し、自分から挨拶し直させます(ホッドの受け渡し)。
;   ★Wait(3)の勘待ちは使いません。C++の実イベントで「〔看板〕0になった今」を正確に掴みます（起動側と設計統一・時間依存ゼロ）。
Event OnAstr2SceneFlagCleared(string eventName, string strArg, float numArg, Form sender)
    GrantGreetToken(playerRef, "sceneEnd")
EndEvent

; 🚑 無アニメ launch失敗の復旧です。C++が「QuickStartしたのにThreadStartedが来ない」を検知して飛ばします。
;   無アニメ死だとostim_start/end両方不発→cleanup/受け渡しが全部止まる→ここで〔看板〕0復帰＋亡霊Stop(0)＋受け渡し起動を手動で回します。
Event OnAstr2SceneLaunchFailed(string eventName, string strArg, float numArg, Form sender)
    ASTR2Native.LogSceneLaunchFail(strArg)   ; 🩹 全失敗をローリングログ ASTR2_SceneLaunchFail.txt へ記録(B-3・時刻+reason+セル+戦闘中/200行トリム=C++)。バグ判断はプレイヤーなので、戦闘/移動キャンセルも拾います
    ; プレイヤーへ通知します。何が起きたか分かるようにするためです（バグ報告の材料にも）。理由はC++ watchdogがstrArgで渡します(combat/cellmove/timeout)。
    ; ★strArg空は旧・無アニメ経路(理由なし)なので通知しません。従来挙動を維持します。
    String prepMsg = "$ASTR2_Msg_SceneCancel"
    If strArg == "combat"
        prepMsg = "$ASTR2_Msg_SceneCancelCombat"
    ElseIf strArg == "cellmove"
        prepMsg = "$ASTR2_Msg_SceneCancelMove"
    ElseIf strArg == "timeout"
        prepMsg = "$ASTR2_Msg_SceneCancelTimeout"
    EndIf
    If strArg != ""
        Debug.Notification(prepMsg)
    EndIf
    GlobalVariable g = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If g != None
        g.SetValue(0.0)
    EndIf
    If ostim != None && OThread.GetThreadCount() > 0
        OThread.Stop(0)
    EndIf
    GrantGreetToken(playerRef, "launchFail")
EndEvent

; 🎬 OStimの行為切替(ostim_scenechanged)：Holdスワップ再試行です（Hスキル計測の本処理はC++側です）。
Event OnOstimSceneChanged(string eventName, string strArg, float numArg, Form sender)
    TrySwapHold()   ; ostim_startでGetSceneActorsが未準備(None)だった分の再試行です。取れ次第Holdへスワップします
EndEvent

; 🎬 体位(アニメ/ノード)切替(ostim_animationchanged)：Holdスワップ再試行です（Hスキル計測の本処理はC++側です）。
;   ★scenechangedと両方発火します（ログ確認済）。どちらの契機でも取りこぼさないよう両方で再試行を拾います。
Event OnOstimAnimChanged(string eventName, string strArg, float numArg, Form sender)
    TrySwapHold()   ; ostim_startでGetSceneActorsが未準備(None)だった分の再試行です。取れ次第Holdへスワップします
EndEvent

; =========================================================
; 🎬 シーン開始イベントです（参加者POPは起動前に出すよう変更し、ここはノーオペです）
; =========================================================
; 🔁 参加者が「準備でき次第」Holdへスワップします。ostim_startの瞬間はASTR2Native.GetSceneActors()がまだNoneです
;   （C++キャッシュはThreadStartedで埋まる＝数百ms後／ostim.GetActors()は揮発でNoneなので使いません）。
;   なのでostim_start＋各scene_changed/anim_changedで試行し、安定して取れたら1回だけ実行します(kHoldSwapDone)。
Function TrySwapHold()
    If kHoldSwapDone
        Return
    EndIf
    ; ★空の時は GetSceneActors を呼びません。空配列→None代入のcast-errorログを断ちます(Aパターン)。準備前はcount=0で素直に待機します。
    If ASTR2Native.GetSceneActorCount() <= 0
        If HoldRetryExhausted()   ; ★壊れシーンで永遠に叩き続けません。上限で打ち切ります（OStim側デッドロックの巻き添え防止）
            Return
        EndIf
        Return
    EndIf
    Actor[] sceneActors = ASTR2Native.GetSceneActors()   ; 安定して取得します（プレイヤー除外済）
    If sceneActors.Length == 0   ; count>0〔ゲート〕通過後は非None確定です。==None比較(cast-errorログ〔地雷〕)を避け.Lengthで判定します
        If HoldRetryExhausted()
            Return
        EndIf
        Return
    EndIf
    ; ★済みフラグはここで、"実際にスワップする"確定直後に立てます（多人数の3重実行防止）。
    ;   旧位置(関数末尾)だと判定→確定の隙間にostim_start＋scene_changed/anim_changedが割り込み、全部「まだ」で
    ;   通過してRecordScene/SwapToHoldPackageが人数×回走りました（VM混雑で隙間が拡大し、1対1では出ず多人数で顕在化します）。
    kHoldSwapDone = true
    SwapToHoldPackage(sceneActors)
    ; 〔サーヴァントシップ〕の控えも同じ安定アクターで行います（旧 ostim.GetActors() がNoneで壊れていた分の代替）。
    ;   プレイヤー参加シーンのみで、加点(+3)はOnOstimEndで行います（開始即キャンセルはscene_changed未到達で控え無しで、exploit防止になります）。
    If ostim != None && ostim.IsPlayerInvolved()
        kServantSceneActors = sceneActors
        kSvReady = true
        GetLvlManager().RecordScene(sceneActors)        ; ★生涯記録もここで行います。ostim_startはNoneで取れず、準備でき次第1回だけ行います(kHoldSwapDoneで重複防止)
    EndIf
EndFunction

; 🛑 Holdスワップ再試行の上限管理です。壊れシーンはOStimがアクター配列を確立できず count が永遠に0の時で、
;   毎scene_changed/anim_changedで GetSceneActorCount/GetSceneActors を叩き続けます。OStim側と競合しフリーズを長引かせます。
;   回数を数えて上限（10回）で「諦めます」。kHoldSwapDone=trueにして以後叩きません。上限到達で true を返します。
;   ★これはASTR2の無限ポーリングを止める衛生策です。焼いている本体はOStim(OBarsScript)なので、これだけで固着が完全に
;   止まらない場合はOStim側要因です（壊れシーン回避）。判定材料としてログに残します。
Bool Function HoldRetryExhausted()
    kHoldRetries += 1
    If kHoldRetries >= 10
        kHoldSwapDone = true
        Return true
    EndIf
    Return false
EndFunction

; 🛠️ 位置フリーズ/walk-home対策：シーン開始(ostim_start)で参加者の集めるパッケージ(Follow/ForceGreet)を外し、
;   代わりに「その場待機(StayAtCurrentLocation)」Holdパッケージ(0x01D277)を乗せるヘルパーです。
;   ・Followの"動く"がOStimの位置決めと喧嘩→参加NPCが硬直します
;   ・ただ剥がすだけだとEvaluatePackageで再選択→ベースAI(家へ)に落ちて walk-homeします（H中に相手が家へ歩きます）
;   Holdなら再評価されても"その場待機"が選ばれベースに落ちません。両方を断ちます。
;   ostim.GetActors()は最終ロスターで、OStimが補充した魅了NPCも拾います。ostim_startは成立時だけで、失敗時は乗せません
;   (Follow維持で再挑戦)。Holdはシーン終了時にCleanupActorが外します。プレイヤーは対象外です。
Function SwapToHoldPackage(Actor[] actors)
    If actors.Length == 0   ; 呼び元(TrySwapHold)が非None確定で渡します。==None比較のcast-errorログ〔地雷〕を避けます
        Return
    EndIf
    Actor pcRef = Game.GetPlayer()
    Package FollowPack = Game.GetFormFromFile(0x00433C, "A Succubus Tale R2.esp") as Package
    Package ForceGreetPack = Game.GetFormFromFile(0x01410C, "A Succubus Tale R2.esp") as Package
    Package HoldPack = Game.GetFormFromFile(0x01D277, "A Succubus Tale R2.esp") as Package
    Int i = 0
    While i < actors.Length
        Actor a = actors[i]
        If a != None && a != pcRef
            If FollowPack != None
                ActorUtil.RemovePackageOverride(a, FollowPack)
            EndIf
            If ForceGreetPack != None
                ActorUtil.RemovePackageOverride(a, ForceGreetPack)
            EndIf
            If HoldPack != None
                ActorUtil.AddPackageOverride(a, HoldPack, 100)   ; その場待機で、eval再選択でもベースAI(家へ)に落としません。優先度100=Follow(50)等に確実に勝たせます
            EndIf
            a.EvaluatePackage()
        EndIf
        i += 1
    EndWhile
EndFunction

; OnOstimStart：ostim_start は家具/ポジション確定後にシーンが始まる時に飛びます。ここは現状ノーオペです
; （参加者popは出さず、カタログコア直起動に一本化しています）。
Event OnOstimStart(string eventName, string strArg, float numArg, Form sender)
    GlobalVariable g = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable

    If ostim != None
        ; 🕳️ 空シーン検知(観測のみ)：参加者0でのostim_startはOStim空シーン暴発の疑い＝永続Rare(ASTR2SKSE.log)に記録だけします。Stop/看板は触りません。
        Actor[] sActors = ostim.GetActors()
        If sActors.Length == 0
            ASTR2Log.Rare("EMPTY-SCENE", "ostim_start with 0 actors (suspected OStim empty-scene misfire) flag=" + g.GetValue() + " threads=" + OThread.GetThreadCount() + " playerInvolved=" + ostim.IsPlayerInvolved())
        EndIf

        ; 🛠️ 位置フリーズ/walk-home対策：参加者をHold待機へスワップします。★ostim.GetActors()(sActors)は揮発でNone〔地雷〕
        ;   （HPバー/RecordSceneも同じNoneで被弾）。このためswap源には使いません。安定なASTR2Native.GetSceneActors()を使いますが
        ;   それも起動直後はまだ未準備(None)なので、フラグを落として即試行→取れなければ各scene_changedで再試行します(TrySwapHold)。
        kHoldSwapDone = false
        kHoldRetries = 0   ; 再試行カウンタも新シーンでリセットします
        kServantSceneActors = PapyrusUtil.ActorArray(0)   ; 控えもリセットします。取れ次第TrySwapHoldで控えます(プレイヤー参加時)
        TrySwapHold()
    EndIf

    ; 🌟 生涯記録：プレイヤーが参加するシーンならH回数＋相手（ユニーク）を刻みます
    If ostim != None && ostim.IsPlayerInvolved()
        ; ★〔看板〕desync補正：シーンが実際に始まったのに〔看板〕が0なら1へ戻します。FinalizeSceneがタイムアウトで早戻し
        ;   した後に遅れて起動したケースです。flag0のままだとForceGreet条件(IsOstimActive==0)が通り「1発で2回H/
        ;   割り込み」になります。実際の起動イベントを基準に真偽を直します。
        If g != None && g.GetValue() == 0.0
            g.SetValue(1.0)
            ASTR2Log.Rare("DESYNC", "ostim_start with flag=0 -> re-assert 1 (late scene after FinalizeScene timeout)")
        EndIf
        ; ★控え(kServantSceneActors)も生涯記録(RecordScene)も TrySwapHold へ移設します。ここ(ostim_start)は
        ;   ostim.GetActors()も ASTR2Native.GetSceneActors()もまだNone〔地雷〕です。安定アクターが取れ次第、
        ;   TrySwapHoldがプレイヤー参加ブロックで1回だけ控え＋記録します（None素通りで記録ゼロだった対策）。
        ASTR2Technique.OnSceneStart()   ; HスキルPhase0：開始時に行為を捕まえます（ostim_scene_changed不発で[TECH]0件だった対策）
        FinalizeSceneCleanup(playerRef)   ; ★起動した瞬間に実参加者の魅了を解除します(固定Wait待ちは使わず、イベント駆動です)
    EndIf
EndEvent

Function OnLoadFunc()
    ASTLvlManager Lvl = GetLvlManager() ; 💡 ここで必要な瞬間にGetします。
    
    If Lvl.IsSuccubus()
        RegisterForKey(LifeForceCheckKey)
        RegisterForModEvent("ostim_orgasm", "OnOstimOrgasm")
        RegisterForModEvent("ostim_end", "OnOstimEnd")
        RegisterForModEvent("ostim_start", "OnOstimStart")   ; ostim_start（シーン開始）を購読します
        RegisterForModEvent("ostim_scenechanged", "OnOstimSceneChanged")   ; HスキルPhase0：行為切替(ノード遷移)ごとにASTR2Techniqueへ渡します。★実イベント名はアンダースコア無し(OStim.dllで確定)。旧"ostim_scene_changed"は誤りで永久不発でした
        RegisterForModEvent("ostim_animationchanged", "OnOstimAnimChanged")   ; ★体位の手動切替はこちらが飛ぶ可能性があり(手動ナビ)、scenechangedと両方仕掛けてどちらが発火するか診断します
        RegisterForModEvent("ASTR2_SceneFlagCleared", "OnAstr2SceneFlagCleared")   ; C++(ThreadEnded)が〔看板〕0にした瞬間がシーン終了の確定で、次の魅了NPCへの受け渡しを駆動します
        RegisterForModEvent("ASTR2_SceneLaunchFailed", "OnAstr2SceneLaunchFailed")   ; C++が無アニメ launch失敗を検知して飛ばす→〔看板〕0+Stop(0)+受け渡しで復旧します
        RegisterForMenu("Dialogue Menu")   ; 🎫 greet会話を選択肢キャンセルした時のリレー継続を検知します（OnMenuOpen/Closeで保持者との会話か判定します）

    Else
        UnregisterForKey(LifeForceCheckKey)
        UnregisterForModEvent("ostim_orgasm")
        UnregisterForModEvent("ostim_end")
        UnregisterForModEvent("ostim_start")
        UnregisterForModEvent("ostim_scenechanged")
        UnregisterForModEvent("ostim_animationchanged")
        UnregisterForModEvent("ASTR2_SceneFlagCleared")
        UnregisterForModEvent("ASTR2_SceneLaunchFailed")
        UnregisterForMenu("Dialogue Menu")
    EndIf
EndFunction

Function SwitchDrainModes()
    IsDrainOn = !IsDrainOn
    
    If IsDrainOn
        Debug.Notification("$ASTR2_Debug_DrainOn")
    Else
        Debug.Notification("$ASTR2_Debug_DrainOff")
    EndIf
    
    GetLogo().ShowDrainLogo(IsDrainOn)
EndFunction

; =================================================================
; 💡 OStim等の導入チェックです
; =================================================================
Function CheckForIntegrations()
    If ostim
        isOArousedInstalled = false
        If Game.GetModByName("OAroused.esp") != 255
            oAroused = Game.GetFormFromFile(0x800, "OAroused.esp") as OArousedScript
            isOArousedInstalled = true
        ElseIf Game.GetModByName("OSLAroused.esp") != 255
            oAroused = Game.GetFormFromFile(0x800, "OSLAroused.esp") as OArousedScript
            isOArousedInstalled = true
        EndIf
    EndIf
EndFunction

; =========================================================
; 🔵 OFFモード：Yes選択時の処理です
; =========================================================
; 💠 周囲のランク4愛玩を距離順に集めます（愛でるハーレム用・話者/playerは除外・生存のみ）。
Actor[] Function CollectPetsInRange(Actor akPlayer, Actor akSpeaker)
    Actor[] nearby = OActorUtil.GetActorsInRangeV2(akPlayer, 1000.0)
    Actor[] pets = PapyrusUtil.ActorArray(0)
    Int i = 0
    While i < nearby.Length
        Actor a = nearby[i]
        If a != None && a != akPlayer && a != akSpeaker && !a.IsDead() && ASTR2Servantship.GetTier(a) == 4
            pets = PapyrusUtil.PushActor(pets, a)
        EndIf
        i += 1
    EndWhile
    Return SortByDistance(pets, akPlayer)
EndFunction

; 🎣 会話フラグメント(Fragment_1)から「会話が閉じたら起動」を予約します。OnMenuClose(Dialogue Menu)が拾って起動します。
;   固定Wait/ポーリングは会話閉じの環境差で全滅→閉じイベント駆動が最終解です。Dialogue MenuはMaintenanceで常時Register済なので再登録不要です。route=1:Yes・愛でる/3:3P。
Function QueueLaunchOnDialogueClose(Actor akSpeaker, Int aiRoute, Bool abPetHarem = false)
    pendingSpeaker = akSpeaker
    pendingRoute = aiRoute
    pendingPetHarem = abPetHarem
EndFunction

Function StartYesRoute(Actor akSpeaker, Bool abPetHarem = false)
    If akSpeaker == None
        Return
    EndIf
    Actor akPlayer = Game.GetPlayer()

    HealStaleSceneFlag()   ; 直前のシーン失敗で〔看板〕が1のまま残っていたら先に下ろします（OFF会話が固まるのを防ぎます）
    ; シーン進行中なら二重開始しません（「OStim中に再度シーン」を原理で封じます）
    GlobalVariable IsOstimActive = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If IsOstimActive != None && IsOstimActive.GetValue() != 0.0
        Return
    EndIf
    ; 〔看板〕を立てます（会話→シーン）
    If IsOstimActive != None
        IsOstimActive.SetValue(1.0)
    EndIf
    kSceneFlagSetTime = Utility.GetCurrentRealTime()
    ReEvalNearbyGreeters(akPlayer)   ; 周囲の進行中ForceGreetを即ドロップします（会話割り込み抑制）
    ; ※ここでは魅了を解除しません（シーン確立後 FinalizeSceneCleanup で実参加者だけ解除します）

    ; ★2P起動は役割を固定せずOStimに選ばせます（役割を固定すると♀dom+♂sub等でアニメ在庫が無く
    ;   失敗/長待ちになります）。RoleFinder直起動に一本化し、TreatAsMale固定は使いません。
    ; 🎣 Wait無しです。OnMenuClose(Dialogue Menu)フックが会話の閉じた瞬間にここを呼びます。会話UIはもう消えています（チラ見えゼロ・環境で閉じが遅くても正確で、環境で閉じが変わるならフックが正解です）。
    ; 配役を[pc,speaker]に固定してRoleFinderへ渡します。候補が空ならNPCメニューは出ず、位置選択へ自動直行します(「yes=配役固定→位置のみ」)。
    Actor[] pair = FilterSceneReady(TwoActorArray(akPlayer, akSpeaker))   ; 3D未ロード除外(setRotation null-CTD防止)
    If pair.Length < 2
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        Return
    EndIf
    If !PreLaunchOK(pair)   ; 戦闘ガード(player込)+亡霊Stop(0)+Suppressを行います（戦闘ならfalse・〔看板〕off+通知済）
        Return
    EndIf
    ASTR2Native.ScenePreparingBegin()   ; ★準備中HUD表示を開始します（会話選択後・家具/メンバー/位置メニュー〜起動までずっと）
    ; 💠 愛玩ハーレム＝愛でる(abPetHarem)なら周囲のランク4愛玩を候補にします（SelectAndLaunchが追加メニューを出します）。魅了Yes(false)は空で、1対1据え置きです。
    Actor[] petCands = PapyrusUtil.ActorArray(0)
    If abPetHarem
        petCands = CollectPetsInRange(akPlayer, akSpeaker)
    EndIf
    Int tid = ASTR2RoleFinder.SelectAndLaunch(akPlayer, akSpeaker, petCands, "none")
    If tid == -1
        ASTR2Native.ScenePreparingEnd()   ; 中止/キャンセルでHUDを消します
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()   ; SelectAndLaunchが$ASTR2_Pick_*を通知済みです
        GrantGreetToken(akPlayer, "yesFail")   ; 起動失敗/キャンセル(-1)で最寄りにgreetトークンを渡し直します（Escキャンセル後の無反応を防ぎます）
    EndIf
EndFunction

; =========================================================
; 🔵 OFFモード：No選択時の処理です（お断り）
; =========================================================
Function StartNoRoute(Actor akSpeaker)
    If akSpeaker == None
        Return
    EndIf
    akSpeaker.UnequipAll()
    CleanupActor(akSpeaker, True)   ; 魅了を完全解除します（裸にして帰します）
    ; 断った本人は魅了解除でトークン保持者が消えるので、次の最寄り魅了NPCへgreetトークンを渡します（無反応化を防ぎます）。
    GrantGreetToken(playerRef, "no")
EndFunction

; =========================================================
; 🔇 シーン開始時：周囲の魅了NPCのForceGreetを即ドロップします（迫ってくる感は維持しつつ会話割り込みを抑えます）
; =========================================================
; 〔看板〕1中はForceGreetパッケージ条件(IsOstimActive==0)が失敗します。進行中で寄ってきていた子は再評価が遅れて
; 挨拶を完遂してしまう→ここで明示的にEvaluatePackageし直して即Followに降ろします。シーン終了(〔看板〕0)で自然に復活します。
Function ReEvalNearbyGreeters(Actor akPlayer)
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    Actor[] cands = CollectCandidates(OActorUtil.GetActorsInRangeV2(akPlayer, 2000.0), akPlayer, None, CandidateFaction)
    Int i = 0
    While i < cands.Length
        cands[i].EvaluatePackage()
        i += 1
    EndWhile
EndFunction

; 🎫 greetトークン：話す権利(ForceGreet)を最寄りの魅了NPC1人だけに持たせます（ONの中央旗ロックのOFF版）。
;   集める(Follow=全員)と話す権利(ForceGreet=1人)を分離します。swarm/バニラ会話割り込みを根絶します。OFF専用です（ONはトークン無しでMainが自動進行します）。
;   ★ステートレスです。呼ぶたびにライブのパッケージ状態から再計算します（保持者変数を持ちません）。E話しかけで別人とHしてもトークンがズレません。
;   ★ダイアログ自体はCandidateFactionで〔ゲート〕します。E話しかけは魅了持ち全員に効きます（このトークンはForceGreetの”自動接近”だけを1人に絞ります）。
Function GrantGreetToken(Actor akPlayer, String src)
    ASTR2MCMScript MCM = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MCMScript
    If MCM != None && MCM.bRandomSelectionEnabled
        Return   ; ONモードはトークン不要です（Mainが自動で次を回します）
    EndIf
    Package ForceGreetPack = Game.GetFormFromFile(0x01410C, "A Succubus Tale R2.esp") as Package
    If ForceGreetPack == None
        Return
    EndIf
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    Actor[] cands = SortByDistance(CollectCandidates(OActorUtil.GetActorsInRangeV2(akPlayer, 2000.0), akPlayer, None, CandidateFaction), akPlayer)
    ; ① 全員からForceGreetを回収します（トークンを一旦ゼロにして、swarm/古いgreetを消します）
    Int i = 0
    While i < cands.Length
        ActorUtil.RemovePackageOverride(cands[i], ForceGreetPack)
        i += 1
    EndWhile
    ; ② 最寄り1人に付与します。ただしクエスト会話/シーン拘束中(GetCurrentScene!=None)は飛ばして次の最寄りへ回します。
    ;    これは来れないNPC(メインクエ進行中等)にトークンを乗せて詰むのを防ぐためです。全員ふさがりなら最寄り(0)へ渡し、消しません(最後はE話しかけが拾います)。
    Int holder = -1
    i = 0
    While i < cands.Length && holder < 0
        ; ★死霊(会話不可＝再アニメ手下 or スイート・ヴァッサルの死霊)はgreetトークンから除外します。話せる最寄りへ渡します。魅了/集合/OStim参加は維持します（死霊もOStimは可）。
        Bool isThrall = cands[i].IsCommandedActor() || SkyVault.GetInt(cands[i], "ASTR2_VassalLiving", 1) == 0
        If !isThrall && cands[i].GetCurrentScene() == None
            holder = i
        EndIf
        i += 1
    EndWhile
    ; 全員クエスト会話中でも話せる最寄りへ渡します（後で空きます）。★死霊は永久に話せないので除外します。全員死霊/該当無しなら誰にも渡しません。
    If holder < 0
        i = 0
        While i < cands.Length && holder < 0
            If !(cands[i].IsCommandedActor() || SkyVault.GetInt(cands[i], "ASTR2_VassalLiving", 1) == 0)
                holder = i
            EndIf
            i += 1
        EndWhile
    EndIf
    If holder >= 0
        ActorUtil.AddPackageOverride(cands[holder], ForceGreetPack, 100)   ; 付与時と同じ優先度(100)です
    EndIf
    ; ③ パッケージ変更を反映します（剥がした子=greet落ち／保持者=greet発火）
    i = 0
    While i < cands.Length
        cands[i].EvaluatePackage()
        i += 1
    EndWhile
    ; キャンセル検知用のヒントです。今トークンを持っている本人を控えます（OnMenuOpenで「保持者との会話か」を判定します）
    If holder >= 0
        kGreetTokenHolder = cands[holder]
    Else
        kGreetTokenHolder = None
    EndIf
EndFunction

; 🎫 greet会話で選択肢(Yes/No/3p)を押した瞬間にTIF Fragment_0が呼びます。会話キャンセル(押していない)と区別する印です。
;   〔看板〕の立つタイミング(セリフ長で変動)に依存せず「選んだか否か」を確実に判定します。OnMenuOpenでfalseに戻ります。
Function MarkGreetRouteChosen()
    kGreetRouteChosen = true
EndFunction

; =========================================================
; 🔵 OFFモード：3P選択時の処理です（RoleFinder経由・最大5人ルート）
; =========================================================
Function Start3pRoute(Actor akSpeaker)
    If akSpeaker == None
        Return
    EndIf
    Actor akPlayer = Game.GetPlayer()
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    HealStaleSceneFlag()   ; 直前のシーン失敗で〔看板〕が1のまま残っていたら先に下ろします（3Pが無反応/固まるのを防ぎます）
    ; 先手を打って〔看板〕（話しかけるな）を立てておきます（進行中なら二重開始しません）
    GlobalVariable IsOstimActive = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If IsOstimActive != None && IsOstimActive.GetValue() != 0.0
        Return
    EndIf
    If IsOstimActive != None
        IsOstimActive.SetValue(1.0)
    EndIf
    kSceneFlagSetTime = Utility.GetCurrentRealTime()
    ReEvalNearbyGreeters(akPlayer)   ; 周囲の進行中ForceGreetを即ドロップします（会話割り込み抑制）

    ; player＋話者(akSpeaker)が確定枠です。周囲の魅了持ちを距離順に候補プール化します（話者は除外します）。
    Actor[] nearbyActors = OActorUtil.GetActorsInRangeV2(akPlayer, 1000.0)
    Actor[] pool = SortByDistance(CollectCandidates(nearbyActors, akPlayer, akSpeaker, CandidateFaction), akPlayer)

    ; 🎣 Wait無しです。OnMenuClose(Dialogue Menu)フックが会話の閉じた瞬間にここを呼びます。会話UIはもう消えています（チラ見えゼロ・環境で閉じが遅くても正確で、環境で閉じが変わるならフックが正解です）。
    ; 候補プール(魅了NPC)を3D除外→RoleFinderのピッカー(speaker確定枠+候補から選ぶ)→OThreadBuilder直起動します。
    ;   候補ゼロなら SelectAndLaunch が位置選択へ自動直行します(=実質2P)。
    pool = FilterSceneReady(pool)
    If !PreLaunchOK(pool)   ; 戦闘ガード(player込)+亡霊Stop(0)+Suppress
        Return
    EndIf
    ASTR2Native.ScenePreparingBegin()   ; ★準備中HUD表示を開始します（会話選択後・家具/メンバー/位置メニュー〜起動までずっと）
    Int tid = ASTR2RoleFinder.SelectAndLaunch(akPlayer, akSpeaker, pool, "none")
    If tid == -1
        ASTR2Native.ScenePreparingEnd()   ; 中止/キャンセルでHUDを消します
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()
        GrantGreetToken(akPlayer, "3pFail")   ; 起動失敗/キャンセル(-1)で最寄りにgreetトークンを渡し直します（Escキャンセル後の無反応を防ぎます）
    EndIf
EndFunction

; =========================================================
; 🚦 RoleFinder起動前の共通ガードです（戦闘ガード＋亡霊Stop(0)＋Suppress）
; =========================================================
;   戦闘中ならfalseです(〔看板〕off＋$ASTR2_Debug_CombatCancel通知＋Restore済)。OKならtrueで、呼び側がSelectAndLaunch等を起動します。
;   3Dガード(FilterSceneReady)は対象が経路で違う(yes=pair/3p=pool)ので呼び側で先に通します。
Bool Function PreLaunchOK(Actor[] checkActors)
    GlobalVariable g = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If AnyInCombat(checkActors)
        If g != None
            g.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()
        Debug.Notification("$ASTR2_Debug_CombatCancel")
        Return false
    EndIf
    If ostim != None && !ostim.AnimationRunning() && OThread.GetThreadCount() > 0
        OThread.Stop(0)
    EndIf
    SuppressAddActorsMenu()
    Return true
EndFunction

; =========================================================
; 🧩 小物：2人配列を作ります
; =========================================================
Actor[] Function TwoActorArray(Actor a, Actor b)
    Actor[] arr = PapyrusUtil.ActorArray(2)
    arr[0] = a
    arr[1] = b
    Return arr
EndFunction

; ★戦闘ガード用：参加者(group)＋プレイヤーの誰かが戦闘中かどうかで、狼乱入でOStimがアクター配置
;   できずシーン未確立(threads=0宙ぶらりん)になるのを、QuickStart前に未然キャンセルするための判定です。敵がgroupに居ない状況、
;   つまり"魅了した通常NPCが戦闘に巻き込まれた"だけを見ます。魅了パッケージは保持します。戦闘終了後ForceGreet再評価で自動再開します。
Bool Function AnyInCombat(Actor[] group)
    If playerRef != None && playerRef.IsInCombat()
        Return true
    EndIf
    Int i = 0
    While i < group.Length
        If group[i] != None && group[i].IsInCombat()
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; =========================================================
; 🔵 共通関数：指定したNPCの魅了状態（AIと魔法）を完全に解除します
; =========================================================
Function CleanupActor(Actor akTarget, Bool bRemoveMagic = False)
    If akTarget == None
        Return
    EndIf
    ; 🚪 〔門番〕として、魅了した相手だけ後始末します（ホワイトリスト）。ASTR2_OrigAggrは魅了確定時
    ;   魅了確定時(!alreadyCharmedの分岐)で必ず付きます。未記録(<0)なら、この子は魅了していません
    ;   （スイート・ヴァッサルの生者の手下、他MOD参加者、普通の仲間など）。FollowPackの剥がしとEvaluatePackageで非魅了の追従AIを
    ;   壊さないようスキップします。魅了済みは必ずOrigAggr>=0so取りこぼし無しです（再greet exploitの心配はありません）。
    If StorageUtil.GetFloatValue(akTarget, "ASTR2_OrigAggr", -1.0) < 0.0
        Return
    EndIf
    ; 名簿から削除します
    ASTR2Make3pScript Make3p = ASTR2Make3pScript.Get()
    If Make3p != None
        Make3p.RemoveCandidate(akTarget)
    EndIf
    
    ; 魅了ファクションを剥奪します
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    If CandidateFaction != None
        akTarget.RemoveFromFaction(CandidateFaction)
    EndIf
    
    ; Allyファクション0100433Dも剥奪します
    Faction AllyFaction = Game.GetFormFromFile(0x0100433D, "A Succubus Tale R2.esp") as Faction
    If AllyFaction != None
        akTarget.RemoveFromFaction(AllyFaction)
    EndIf

    ; 魅了前のAggressionへ復元します（“もやもや解除後も殺せない”を防ぎます）
    ; ※OStimシーン中は復元しません。敵が興奮中に再敵対して攻撃し、OStimでCTDになるのを防ぐためです（シーン後は鎮静のままで、ドレインのwasEnemyは残るので殺せます）
    If !OActor.IsInOStim(akTarget)
        Float origAggr = StorageUtil.GetFloatValue(akTarget, "ASTR2_OrigAggr", -1.0)
        If origAggr >= 0.0
            akTarget.SetActorValue("Aggression", origAggr)
        EndIf
        StorageUtil.UnsetFloatValue(akTarget, "ASTR2_OrigAggr")
        StorageUtil.UnsetIntValue(akTarget, "ASTR2_WasEnemy")
    EndIf

    ; 集合/待機パッケージ（Follow/ForceGreet/Hold）を剥がします。★シーン中(IsInOStim)は剥がしません。
    ;   Holdを外すとEvaluatePackageで再選択され、ベースAI(家へ)に落ちて walk-homeします。終了時(OnOstimEndでIsInOStimが偽のとき)に外します。
    If !OActor.IsInOStim(akTarget)
        Package FollowPack = Game.GetFormFromFile(0x00433C, "A Succubus Tale R2.esp") as Package
        Package ForceGreetPack = Game.GetFormFromFile(0x01410C, "A Succubus Tale R2.esp") as Package
        Package HoldPack = Game.GetFormFromFile(0x01D277, "A Succubus Tale R2.esp") as Package
        If FollowPack != None
            ActorUtil.RemovePackageOverride(akTarget, FollowPack)
        EndIf
        If ForceGreetPack != None
            ActorUtil.RemovePackageOverride(akTarget, ForceGreetPack)
        EndIf
        If HoldPack != None
            ActorUtil.RemovePackageOverride(akTarget, HoldPack)
        EndIf
    EndIf

    ; 魔法のもやもやを除去します（単体300/エリア600/マス900の3種すべて）
    If bRemoveMagic
        Spell SingleSeductionSpell = Game.GetFormFromFile(0x002DB3, "A Succubus Tale R2.esp") as Spell
        If SingleSeductionSpell != None
            akTarget.DispelSpell(SingleSeductionSpell)
        EndIf

        Spell AreaSeductionSpell = Game.GetFormFromFile(0x00BA13, "A Succubus Tale R2.esp") as Spell
        If AreaSeductionSpell != None
            akTarget.DispelSpell(AreaSeductionSpell)
        EndIf
    
        Spell MassSeductionSpell = Game.GetFormFromFile(0x004E05, "A Succubus Tale R2.esp") as Spell
        If MassSeductionSpell != None
            akTarget.DispelSpell(MassSeductionSpell)
        EndIf
    EndIf

    ; AIパッケージを再評価します（★シーン中はEvaluatePackageを打たず、Hold維持でwalk-homeを防ぎ、終了時に再評価して通常AIへ戻します）
    akTarget.BlockActivation(false)
    If !OActor.IsInOStim(akTarget)
        akTarget.EvaluatePackage()
    EndIf
EndFunction

; =========================================================
; 🎬 シーン確立後、実際に参加した人だけ魅了を解除します（不参加者はキープします）
; =========================================================
; ★イベント駆動：QuickStart後のwaitポーリング待ちは使いません。OnOstimStart(ostim_start)が
;   「シーンが実際に起動した瞬間」にこれを呼びます。固定の待機秒数で計る方式は環境により過不足が出て不安定なため、
;   環境に依存しないイベント方式を採用しています。メニューに何秒かかっても誤判定しません。実際にOStimに入っている魅了者だけ解除します（不参加者はキープし、補充で増えた人も拾います）。
;   ※不成立(ostim_startが来ない)は時間判定しません。〔看板〕はC++(ThreadEnded)/HealStaleSceneFlag(D)が下ろします。
;     起動損ねた亡霊スレッドのStop(0)は「次のQuickStartの直前」で掃除します(各起動経路で、時間ではなくイベント駆動です)。
Function FinalizeSceneCleanup(Actor akPlayer)
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    Actor[] nearbyActors = OActorUtil.GetActorsInRangeV2(akPlayer, 2000.0)
    Int k = 0
    While k < nearbyActors.Length
        Actor a = nearbyActors[k]
        If a != None && a != akPlayer && a.IsInFaction(CandidateFaction) && OActor.IsInOStim(a)
            CleanupActor(a, True)
        EndIf
        k += 1
    EndWhile
    RestoreAddActorsMenu()   ; シーン確立時に、開始時に抑制したAddActorsメニューを戻します
EndFunction

Function ReceiveMagicTarget(Actor akTarget)
    If akTarget == None
        Return
    EndIf
    ; ファクション/パッケージ付与は魔法側(ASTSedMagEffScript)で完了済みです。
    ; 失敗で残った古い〔看板〕があれば先に自己修復します（ON/OFF両方の復活トリガで、魔法を撃つたびに行います）
    HealStaleSceneFlag()
    ; ONモードのキックを「予約」します。マスで複数人が同時に当たっても起動は1回に束ねます（配役窓の乱立を防ぎます）。
    ; OFFは greetトークン（最寄り1人にForceGreetします）を予約します。同じく1回に束ねて最寄りを確定します。両関数とも内部でモード自己ガードします。
    ScheduleONKick()       ; ONのときは自動配役キックです（OFFは即returnします）
    ScheduleGreetToken()   ; OFFのときはgreetトークンを付与します（ONは即returnします）
EndFunction

; =========================================================
; 🧛‍♀️ ONモード：配役キックを1回に束ねて予約します（マスの多重起動を直列化します）
; =========================================================
; RegisterForSingleUpdateはスクリプト単位で1個に潰れるので、マスで何人当たっても
; OnUpdate は1回しか飛びません（配役窓の乱立を原理で封じます）。
Function ScheduleONKick()
    ASTR2MCMScript MCM = GetMCM()
    If MCM == None || !MCM.bRandomSelectionEnabled
        Return
    EndIf
    kONKickPending = true
    RegisterForSingleUpdate(1.0)
EndFunction

; =========================================================
; 🎫 OFFモード：greetトークン付与を1.0s遅延で予約します（ScheduleONKickのOFF版）
; =========================================================
; マス着弾で多数当たっても RegisterForSingleUpdate は1個に潰れ、OnUpdateで1回だけ GrantGreetToken を呼んで最寄り計算を束ねます。
Function ScheduleGreetToken()
    ASTR2MCMScript MCM = GetMCM()
    If MCM == None || MCM.bRandomSelectionEnabled
        Return   ; ONモードは ScheduleONKick に任せます（greetトークンは使いません）
    EndIf
    kGreetTokenPending = true
    RegisterForSingleUpdate(1.0)
EndFunction

; =========================================================
; 🔇 OStimの「Add Actors At Start」メニューを一時的に黙らせます
;    （自動配役中にNPC名前選択窓が割り込むのを防ぎます／シーン後にOnOstimEndで復元します）
; =========================================================
Function SuppressAddActorsMenu()
    If ostim != None && ostim.AddActorsAtStart
        ostim.AddActorsAtStart = false
        kReenableAddActors = true
    EndIf
EndFunction

; =========================================================
; 🔁 黙らせた「Add Actors At Start」を元に戻します（OnOstimEndが来ない失敗経路の漏れ対策です）
;    ※一度漏れると次のSuppressが空振りして次の成功シーンまでfalseに固定され、フリーズ要因になります。失敗時は必ずここで戻します。
; =========================================================
Function RestoreAddActorsMenu()
    If kReenableAddActors && ostim != None
        ostim.AddActorsAtStart = true
        kReenableAddActors = false
    EndIf
EndFunction

; =========================================================
; 🩹 〔看板〕の自己修復：シーン失敗/ミスマッチで〔看板〕(IsOstimActive)が1のまま残った時、
;    OStimが実際に動いていなくて一定時間(40秒)経っていたら“古い〔看板〕”として下ろします。
;    準備中(40秒未満)や本物のシーン中(AnimationRunning)は絶対に触りません。誤爆を防ぐためです。
; =========================================================
Function HealStaleSceneFlag()
    GlobalVariable IsOstimActive = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If IsOstimActive == None || IsOstimActive.GetValue() == 0.0
        Return
    EndIf
    ; OStimが動いていないのに〔看板〕が1なら、失敗/中断で残った古い〔看板〕です。ただし立てたばかり(0〜40秒)は
    ; シーン準備中の可能性があるので触りません。マス連打で"他シーンの準備中〔看板〕"を誤爆0化するのを防ぎます。
    ; ※flagAge<0 は、GetCurrentRealTimeがゲーム再起動でリセットされ、別セッションで立った〔看板〕なので、確実に古く、下ろします(セーブロード跨ぎに対応します)。
    Float flagAge = Utility.GetCurrentRealTime() - kSceneFlagSetTime
    If ostim != None && !ostim.AnimationRunning() && (flagAge > 40.0 || flagAge < 0.0)
        IsOstimActive.SetValue(0.0)
    EndIf
EndFunction

; =========================================================
; 🧛‍♀️ ONモード：「ONモード：成立する最大構成（最大5人）を選んで自動開始」
; =========================================================
Function TryStartNextONScene()
    ASTR2MCMScript MCM = GetMCM()
    ; ONモード（自動）でなければ何もしません（OFFはForceGreetに任せます）
    If MCM == None || !MCM.bRandomSelectionEnabled
        Return
    EndIf
    If ostim == None
        Return
    EndIf

    HealStaleSceneFlag()   ; 失敗で残った古い〔看板〕を先に下ろします（残っていなければ何もしません）

    GlobalVariable IsOstimActive = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    ; シーン中／準備中なら触りません（古い残骸は上のHealで既に0化済みです）
    If ostim.AnimationRunning() || (IsOstimActive != None && IsOstimActive.GetValue() != 0.0)
        Return
    EndIf
    ; 先に〔看板〕を立てて二重起動を防ぎます（「OStim中に再度選択画面」を封じます）
    If IsOstimActive != None
        IsOstimActive.SetValue(1.0)
    EndIf
    kSceneFlagSetTime = Utility.GetCurrentRealTime()

    Actor akPlayer = Game.GetPlayer()
    Faction CandidateFaction = Game.GetFormFromFile(0x013BA5, "A Succubus Tale R2.esp") as Faction
    Actor[] nearbyActors = OActorUtil.GetActorsInRangeV2(akPlayer, 2000.0)
    Actor[] pool = SortByDistance(CollectCandidates(nearbyActors, akPlayer, None, CandidateFaction), akPlayer)   ; 近い順に並べます

    If pool.Length == 0
        ; 候補が居なかったので〔看板〕を下ろして通常に戻します
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        Return
    EndIf

    ; ON自動起動はカタログコアのLaunchBestFromCandidatesで行います(idleを除外し、RealMalesで配役し、OThreadBuilderで直起動します)。
    ;   直起動で無アニメ無音死を根絶します。プレイヤーは内部で必ず参加します。
    ;   周辺処理はyes/3pと同じ枠で、FilterSceneReady(3D)→PreLaunchOK(戦闘ガード+亡霊Stop(0)+Suppress)→起動→-1で〔看板〕offという流れです。
    ;   ★ON参加者プレビュー(ShowParticipantInfo)は出さず、完全自動起動です。
    pool = FilterSceneReady(pool)   ; メニュー無しでも待ち窓でセル越え等があり得るので、起動直前の3D再チェックです
    If !PreLaunchOK(pool)           ; 戦闘ならfalseを返します(内部で〔看板〕をoffにし、通知し、Restoreします)
        Return
    EndIf
    ASTR2Native.ScenePreparingBegin()   ; ★準備中HUDの表示を開始します（自動ON起動時、起動までずっと表示します）
    Int tid = ASTR2RoleFinder.LaunchBestFromCandidates(akPlayer, pool, "none")
    If tid == -1
        ASTR2Native.ScenePreparingEnd()   ; 中止でHUDを消します
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()
    EndIf
EndFunction

; ---- シーン安全ガード：3D未ロードのアクターを除外します ----
; OStimのGameActor::setRotationのnull-deref CTDを防ぎます(例：ロードドア通過中のNPC)。
Bool Function IsSceneReady(Actor a)
    Return a != None && a.Is3DLoaded() && !a.IsDisabled() && !a.IsDead()
EndFunction

; FilterSceneReady：シーン準備OKのアクターだけを含む新しい配列を返します(数える時も詰める時も同じ判定を使います)。
Actor[] Function FilterSceneReady(Actor[] arr)
    Int n = 0
    Int i = 0
    While i < arr.Length
        If IsSceneReady(arr[i])
            n += 1
        EndIf
        i += 1
    EndWhile
    Actor[] result = PapyrusUtil.ActorArray(n)
    Int k = 0
    i = 0
    While i < arr.Length && k < n
        If IsSceneReady(arr[i])
            result[k] = arr[i]
            k += 1
        EndIf
        i += 1
    EndWhile
    Return result
EndFunction

; =========================================================
; 🧩 周囲から「魅了持ち」だけをプールに集めます
; =========================================================
; CollectCandidates：nearbyから、魅了持ち(013BA5)でプレイヤーと除外者以外のアクターだけを抜き出してプール化します
Actor[] Function CollectCandidates(Actor[] nearby, Actor akPlayer, Actor akExclude, Faction CandidateFaction)
    Int n = 0
    Int i = 0
    Actor a
    While i < nearby.Length
        a = nearby[i]
        If a != None && a != akPlayer && a != akExclude && a.IsInFaction(CandidateFaction) && IsSceneReady(a)
            n += 1
        EndIf
        i += 1
    EndWhile

    Actor[] result = PapyrusUtil.ActorArray(n)
    Int k = 0
    i = 0
    While i < nearby.Length && k < n
        a = nearby[i]
        If a != None && a != akPlayer && a != akExclude && a.IsInFaction(CandidateFaction) && IsSceneReady(a)
            result[k] = a
            k += 1
        EndIf
        i += 1
    EndWhile
    Return result
EndFunction

; =========================================================
; 🧭 アクター配列をプレイヤーに近い順（昇順）に並べ替えます
; =========================================================
; SortByDistance：centerに近い順へ並べ替えた新配列を返します（挿入ソートを使います）。配役を「近い人優先」にする土台です。
Actor[] Function SortByDistance(Actor[] arr, ObjectReference center)
    Int n = arr.Length
    Actor[] result = PapyrusUtil.ActorArray(n)
    Float[] dist = Utility.CreateFloatArray(n)
    Int i = 0
    While i < n
        result[i] = arr[i]
        If arr[i] != None
            dist[i] = center.GetDistance(arr[i])
        Else
            dist[i] = 1000000.0
        EndIf
        i += 1
    EndWhile
    ; 距離が小さい順に挿入ソートします
    i = 1
    While i < n
        Actor curA = result[i]
        Float curD = dist[i]
        Int j = i - 1
        While j >= 0 && dist[j] > curD
            result[j + 1] = result[j]
            dist[j + 1] = dist[j]
            j -= 1
        EndWhile
        result[j + 1] = curA
        dist[j + 1] = curD
        i += 1
    EndWhile
    Return result
EndFunction

; =========================================================
; 🌙 ナイトメア・エンブレイス（Nightmare Embrace）：寝ている相手をOStimへ誘います（Lv5未満=1対1／Lv5+=相方を足して複数・OStim準拠）。
; =========================================================
; ASTR2NightmareEffect の成功時に呼ばれます（akGroupはプレイヤーと対象、Lv5以上なら相方を加えた確定グループで、必ず2人以上あり、Noneは含みません）。
; dom/subは固定せず、OActorUtil.Sortで竿持ちやdomを前にするOStim正規順に並べ、カタログコア直起動(LaunchNightmare)へ渡します。
; （プレイヤー♀をdom固定にすると「♀dom+♂sub」のアニメ在庫が無く確定失敗するためで、混合シーンと同根の罠です）。
; StartYesRoute の安全装置を踏襲します（〔看板〕の二重起動を防止し、3DガードでCTDを回避し、後始末もします）。
Function StartNightmareScene(Actor akTarget, Actor[] akGroup)
    If akTarget == None
        Return
    EndIf
    Actor akPlayer = Game.GetPlayer()

    HealStaleSceneFlag()   ; 直前のシーン失敗で〔看板〕が1のまま残っていたら先に下ろします
    GlobalVariable IsOstimActive = Game.GetFormFromFile(0x018C69, "A Succubus Tale R2.esp") as GlobalVariable
    If IsOstimActive != None && IsOstimActive.GetValue() != 0.0
        Return   ; もうシーン中なら二重開始しません
    EndIf
    If IsOstimActive != None
        IsOstimActive.SetValue(1.0)   ; 〔看板〕を立てます
    EndIf
    kSceneFlagSetTime = Utility.GetCurrentRealTime()

    ; グループは呼び元(NightmareEffect)が確定済みで、プレイヤーと対象、(Lv5なら)相方からなり、必ず2人以上でNoneは含みません。
    ; ここでは竿持ちやdomを前にするOStim正規順に並べ替えるだけで、役割もアニメもOStimに選ばせます。
    Actor[] group = OActorUtil.Sort(akGroup, OActorUtil.EmptyArray())

    SuppressAddActorsMenu()            ; NPC名前選択窓を出しません
    group = FilterSceneReady(group)    ; 3D未ロードを脱落させます（ドア通過中のsetRotationヌルCTDを回避します）
    If group.Length < 2
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()         ; 失敗でOnOstimEndが来ないのでここで戻します
        Return
    EndIf

    ; ★起こす前に「寝ているベッド」を捕獲します（下のMoveToでベッドから出るため先に取ります）。
    ; これをLaunchNightmareへ渡します。ベッド用シーンがあればNone/ベッドの2択メニューになり、無ければ自動で立ちます。
    ObjectReference bedRef = akTarget.GetFurnitureReference()

    ; 寝ている相手＆相方を起こします（寝姿勢/ベッド占有のままOStimに渡すと即start→endでアボートします）。
    ; まず全員 SetAlert＋MoveTo でベッドから強制退出→立ちidle→全員awake(GetSleepState==0)まで待ちます。
    Actor wnpc
    Int wi = 0
    While wi < group.Length
        wnpc = group[wi]
        If wnpc != None && wnpc != akPlayer
            wnpc.SetAlert(true)
            wnpc.MoveTo(wnpc)   ; ★furnitureベッドから強制退出させます（SetAlert/IdleだけだとsleepState=3のまま起きません）
        EndIf
        wi += 1
    EndWhile
    Utility.Wait(0.5)
    wi = 0
    While wi < group.Length
        wnpc = group[wi]
        If wnpc != None && wnpc != akPlayer
            Debug.SendAnimationEvent(wnpc, "IdleStop")
            Debug.SendAnimationEvent(wnpc, "IdleForceDefaultState")
            wnpc.EvaluatePackage()   ; sleepパッケージを再評価して立ちパッケージへ移行を促します
        EndIf
        wi += 1
    EndWhile
    Int wakeGuard = 0
    While !AllAwake(group, akPlayer) && wakeGuard < 20
        Utility.Wait(0.25)   ; 最大5秒、全員が起きる(awake)のを待ちます
        wakeGuard += 1
    EndWhile
    Utility.Wait(0.5)   ; 立ち上がりの余韻です（足りなければ実機で調整します）

    ; ★戦闘ガードです(狼乱入バグを防ぎます)。参加者の誰かが戦闘中ならOStimを起動しません。魅了は保持します(cleanupしません)。
    If AnyInCombat(group)
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()
        Debug.Notification("$ASTR2_Debug_CombatCancel")   ; 相手が戦闘態勢のときの起動キャンセル通知です
        Return
    EndIf
    ; ★起動前に、前回起動に失敗した亡霊スレッド(ID0)を掃除してCTDを防ぎます(時間判定ではなくイベント駆動です)。
    If ostim != None && !ostim.AnimationRunning() && OThread.GetThreadCount() > 0
        OThread.Stop(0)
    EndIf
    ; ★カタログコア直起動(LaunchNightmare)にして、QuickStart丸投げをやめます。無アニメ死をゼロにし、lineup固定で
    ;   人数を固定し(QuickStartのAddActors横入りを封じます)、ベッド対応します(None/ベッドの2択、または自動立ちです)。
    ASTR2Native.ScenePreparingBegin()   ; ★準備中HUD表示を開始します（起こし待ちの後、家具選択〜起動まで。起こし処理中は対象外）
    Int threadID = ASTR2RoleFinder.LaunchNightmare(group, bedRef)
    ; ★成立cleanupはOnOstimStart(ostim_start)が拾うので待ちません。即-1だけ案内します。参加者は受理時に覚えます。
    If threadID != -1
        kNightmareParticipants = group   ; H後にAIリセットする参加者として覚えます（OnOstimEndの夢魔限定処理に使います）
        kNmReady = true
    Else
        ASTR2Native.ScenePreparingEnd()   ; 中止/キャンセルでHUDを消します
        If IsOstimActive != None
            IsOstimActive.SetValue(0.0)
        EndIf
        RestoreAddActorsMenu()
        Debug.Notification("$ASTR2_Debug_NoAnimGroup")   ; アニメ無しです（既存キーを再利用します）
    EndIf
EndFunction

; 夢魔の起こし待ちに使う関数です。グループ内の全NPC（プレイヤーを除く）が起きている(GetSleepState==0)かを返します。
Bool Function AllAwake(Actor[] grp, Actor pc)
    Int i = 0
    While i < grp.Length
        Actor a = grp[i]
        If a != None && a != pc && a.GetSleepState() != 0
            Return false
        EndIf
        i += 1
    EndWhile
    Return true
EndFunction
