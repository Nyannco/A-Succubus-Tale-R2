Scriptname ASTR2ActorHpBarScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

ASTR2ActorHpBarScript Function Get() Global
    Return Game.GetFormFromFile(0x01361A, "A Succubus Tale R2.esp") as ASTR2ActorHpBarScript
EndFunction

; --- 4本のバー（SSEEditで割り当て。既定位置は各バーのMyDefX/MyDefYで設定） ---
ASTR2CustomBarScript Property ASTR2ActorHpBar1 Auto
ASTR2CustomBarScript Property ASTR2ActorHpBar2 Auto
ASTR2CustomBarScript Property ASTR2ActorHpBar3 Auto
ASTR2CustomBarScript Property ASTR2ActorHpBar4 Auto

; --- 内部状態 ---
Bool Property IsHSceneActive = false Auto Hidden ; OStimシーン中はtrueです
Bool bKeyShown = false                            ; KeySecモードです。シーン中はホットキーで切り替わります
Bool bPreviewing = false                          ; MCMを閉じた時の位置プレビューが動作中です
Actor[] _sceneNpcs                                ; キャッシュしたシーンのNPCです（プレイヤーを除き、最大4人です）
Int _emptyRetries                                 ; キャッシュが空の間、GetActorsを上限つきでリトライします
                                                  ; （フタナリ破綻シーンのガードです。GetActorsが永遠にNoneを返す場合は数tickで諦めます）
Bool[] _wasAtFloor                                ; スロット別に、下限フラッシュを「到達した瞬間だけ」出すone-shotガードです。
ASTDrainScript _drain                             ; 下限%の算出(FloorAbs/FloorPctH)に使います。シーン開始で1回キャッシュします。
Bool _arraysReady                                 ; 配列メンバを初回確保したかどうかです（None化を防いで「配列==None」比較のスパムを根絶します）。

Event OnInit()
    OnLoadFunc()
EndEvent

; 初期化時と、ロード毎に Main.Maintenance() から呼ばれます（mod-event登録はロードで失われます）
Function OnLoadFunc()
    ; 🛡️ 配列メンバは常に確保してNone化させません。Papyrusは「配列 == None」比較自体で
    ;   Cannot cast None to X[] をログに吐く〔地雷〕です。Noneにしなければ比較ごと消せます（毎tickのスパムを根絶します）。
    If !_arraysReady
        _sceneNpcs = new Actor[4]
        _wasAtFloor = new Bool[4]
        _arraysReady = true
    EndIf
    RegisterForModEvent("ostim_start", "OnAST_OStimStart")
    RegisterForModEvent("ostim_end", "OnAST_OStimEnd")
    ; 参加者の出入りはイベントで拾います（毎秒ポーリングしないのはデッドロック回避のためです）。
    RegisterForModEvent("ostim_thirdactor_join", "OnAST_RosterChanged")
    RegisterForModEvent("ostim_thirdactor_leave", "OnAST_RosterChanged")
    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    If MCM != None && !MCM.bActorHpDefInit
        MCM.InitActorHpDefaults() ; 各バーのMyDefX/MyDefYからバーごとのX/Yを初期設定します
    EndIf
    Int k = MCM.ActorHpCheckKey
    If k > 0
        RegisterForKey(k)
    EndIf
EndFunction

; ホットキー変更時にMCMから呼ばれます（Main.SetLifeForceKeybindと同じ作りです）
Function SetActorHpKey(int oldKey, int newKey)
    If oldKey > 0
        UnregisterForKey(oldKey)
    EndIf
    If newKey > 0
        RegisterForKey(newKey)
    EndIf
EndFunction

; ===== シーン開始：参加者を一度だけキャッシュし、安全な更新ループを開始 =====
Event OnAST_OStimStart(String eventName, String strArg, Float numArg, Form sender)
    ASTLvlManager Lvl = ASTR2BarUtil.GetLvlManager()
    If Lvl == None || !Lvl.IsSuccubus()
        Return
    EndIf
    IsHSceneActive = true
    bKeyShown = false
    _emptyRetries = 0   ; 新しいシーンなので空リトライ回数をリセットします。
    _wasAtFloor = new Bool[4]   ; 下限フラッシュのone-shotガードを新しいシーンでリセットします。
    _drain = ASTR2BarUtil.GetMain().GetDrainScript()   ; 下限%の算出用にドレインを1回キャッシュします。
    RecacheParticipants()
    RefreshNow()
EndEvent

; ===== シーン終了：キャッシュを破棄してフェードアウト =====
Event OnAST_OStimEnd(String eventName, String strArg, Float numArg, Form sender)
    IsHSceneActive = false
    _sceneNpcs = new Actor[4]
    RefreshNow()
EndEvent

; 参加者の増減（3人目以降の出入り）です。この単発イベントの時だけ取り直します（毎秒ではなく安全です）
Event OnAST_RosterChanged(String eventName, String strArg, Float numArg, Form sender)
    If IsHSceneActive
        RecacheParticipants()
        RefreshNow()
    EndIf
EndEvent

; MCMプレビューの5秒ワンショット専用です（H中の毎秒ループは〔クロノス〕へ移したので、ここには来ません）。
Event OnUpdate()
    If bPreviewing
        bPreviewing = false
        If IsHSceneActive
            RefreshNow() ; プレビュー中にシーンが始まったので通常表示へ戻します。
        Else
            HideAllBars()
        EndIf
        Return
    EndIf
    RefreshNow()   ; 念のための保険です（予約元が消えた古いセーブからの遅延到着などに備えます）。
EndEvent

; KeySecモードのホットキーです（挙動は不変で、専用キーはトグル、共有キーはMain経由で同期します）
Event OnKeyDown(int keyCode)
    If !IsHSceneActive
        Return ; シーン外では表示も処理も行いません
    EndIf
    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    If keyCode == MCM.ActorHpCheckKey && MCM.ActorHpCheckKey > 0 && MCM.ActorHpDisplayMode == 1
        Bool sharesLF = (MCM.ActorHpCheckKey == MCM.LifeForceCheckKey && MCM.LFDisplayMode == 1)
        Bool sharesExp = (MCM.ActorHpCheckKey == MCM.ExpCheckKey && MCM.ExpDisplayMode == 1)
        If sharesLF || sharesExp
            Return ; 共有キーです。MainがLF/Expを切り替えた直後に、こちらを更新してくれます
        EndIf
        bKeyShown = !bKeyShown ; 専用キーです。自分のぶんをトグルします
        RefreshNow()
    EndIf
EndEvent

; MainがLF/Expを切り替えた直後に呼ばれます。シーン中だけAHPを淫魔力（LF）に同期します
Function SyncFromMain()
    If IsHSceneActive
        RefreshNow()
    EndIf
EndFunction

; 中枢の状態機械です。表示方針は不変で、データ経路だけがキャッシュ方式になりました。
Function RefreshNow()
    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    Bool shouldShow = false
    If IsHSceneActive
        Int mode = MCM.ActorHpDisplayMode
        If mode == 0
            shouldShow = true
        ElseIf mode == 1
            ; KeySecです。このバーがLF/Exp（同じくKeySec）とホットキーを共有している場合は、そのバーに合わせます
            If MCM.ActorHpCheckKey == MCM.LifeForceCheckKey && MCM.LifeForceCheckKey > 0 && MCM.LFDisplayMode == 1
                shouldShow = ASTR2BarUtil.GetLFBar().LFisBarVisible
            ElseIf MCM.ActorHpCheckKey == MCM.ExpCheckKey && MCM.ExpCheckKey > 0 && MCM.ExpDisplayMode == 1
                shouldShow = ASTR2BarUtil.GetExpBar().ExpisBarVisible
            Else
                shouldShow = bKeyShown
            EndIf
        ElseIf mode == 3
            shouldShow = true
        EndIf
        ; mode 2（Hide）はfalseのままです
    EndIf

    If shouldShow
        ; 参加者がまだ取れていない時だけ取り直します（4Pの確立遅れ対策です。取れたら以後は呼びません。遷移中のポーリングを避けるためです）。
        ; 上限つきです。GetActorsが永遠にNoneを返す破綻シーン(フタナリ等)で毎tick叩き続けるのを防ぎます。デッドロック再発防止です。
        ; 5回(≒5秒)で諦めます。以後のtickはキャッシュHPを読むだけです。GetActorsを二度と呼びません（バーは出ませんがフリーズはしません）。
        If IsHSceneActive && !HasAnyNpc() && _emptyRetries < 5
            RecacheParticipants()
            _emptyRetries += 1
        EndIf
        ; _wasAtFloor は OnLoadFunc/シーン開始で常に非Noneなので「== None」比較はしません（毎tickのスパム源になるためです）。
        If _drain == None
            _drain = ASTR2BarUtil.GetMain().GetDrainScript()
        EndIf
        ApplyBar(ASTR2ActorHpBar1, _sceneNpcs[0], MCM.ActorHpBar1X, MCM.ActorHpBar1Y, 0)
        ApplyBar(ASTR2ActorHpBar2, _sceneNpcs[1], MCM.ActorHpBar2X, MCM.ActorHpBar2Y, 1)
        ApplyBar(ASTR2ActorHpBar3, _sceneNpcs[2], MCM.ActorHpBar3X, MCM.ActorHpBar3Y, 2)
        ApplyBar(ASTR2ActorHpBar4, _sceneNpcs[3], MCM.ActorHpBar4X, MCM.ActorHpBar4Y, 3)
        BindBarsToClock()   ; 以後の毎秒のHP%更新は〔クロノス〕（C++）が回します。
    Else
        HideAllBars()
        ASTR2Native.HpBarUnbind()
    EndIf
EndFunction

; =====================================================================================
; ⏰ H中の毎秒更新は 〔クロノス〕（C++の時計）が持ちます（常時動くタイマーは
;   原則C++です。PapyrusのVMは全MOD共有なので、H中ずっと回るループは他MODを詰まらせるためです）。
;   ・ウィジェットの場所(WidgetRoot)をC++へ1回渡すだけです。以後はC++が実時間1秒ごとに
;        変化があったバーだけ setPercent を投げます（下限到達のフラッシュもC++です）。
;   ・表示モード/位置/色/フェード/プレビューは今までどおりPapyrusです。低頻度なので負荷になりません。
; =====================================================================================
Function BindBarsToClock()
    String[] roots = new String[4]
    roots[0] = GetWidgetRootOf(ASTR2ActorHpBar1)
    roots[1] = GetWidgetRootOf(ASTR2ActorHpBar2)
    roots[2] = GetWidgetRootOf(ASTR2ActorHpBar3)
    roots[3] = GetWidgetRootOf(ASTR2ActorHpBar4)
    ASTR2Native.HpBarBind(roots)
EndFunction

; ウィジェットの場所（"_root.WidgetContainer.widgetN"）を返します。未準備なら空文字を返し、C++はその枠を飛ばします。
String Function GetWidgetRootOf(ASTR2CustomBarScript bar)
    If bar == None || !bar.Ready
        Return ""
    EndIf
    Return bar.WidgetRoot
EndFunction

; シーン参加者を（再）キャッシュします。開始時／名簿変更時／空の間だけ呼ばれ、tick毎には呼ばれません。
Function RecacheParticipants()
    _sceneNpcs = CollectSceneNpcs()
EndFunction

Bool Function HasAnyNpc()
    ; _sceneNpcs は OnLoadFunc/RecacheParticipants で常に非Noneなので「== None」比較はしません（毎tickのスパム源になるためです）。
    Int i = 0
    While i < _sceneNpcs.Length
        If _sceneNpcs[i] != None
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; シーン参加者を集めます（プレイヤーを除き、最大4人です）。castの前にNoneガードします。
; 参加者取得はC++ネイティブ ASTR2Native.GetSceneActors() を使います。
;   C++が ThreadStarted で AddTask 遅延読み(再入回避)して安全にキャッシュした「プレイヤー除く参加者」を
;   受け取るだけです。Papyrus側からOStimを叩きません。フタナリ破綻シーンのロック競合デッドロックが根治します。
;   ※ostim_start直後はC++キャッシュ確立前で空が返り得ます。tickの上限リトライ(_emptyRetries)が数tickで拾います。
Actor[] Function CollectSceneNpcs()
    Actor[] npcs = new Actor[4]
    ; 空の時は GetSceneActors を呼びません。空配列がNone代入になって起きる「Cannot cast None to Actor[]」ログ連発を断ちます。
    ;   GetSceneActorCount は Int 返しでNone化しません。先に見て >0 の時だけ取得します。
    If ASTR2Native.GetSceneActorCount() <= 0
        Return npcs ; 空です（dll未ロード/シーン外/キャッシュ未確立のときに安全に空になります）
    EndIf
    Actor[] fromCpp = ASTR2Native.GetSceneActors()   ; プレイヤーは除外済みです（最大で数人です）
    If fromCpp.Length == 0   ; count>0〔ゲート〕を通過後なので非None確定です。==None比較(cast-errorログの〔地雷〕)を避けて.Lengthで判定します。
        Return npcs ; 念のための二重ガードです（count>0でも直後に解決不能化する超レアな競合です）。
    EndIf
    Int found = 0
    Int i = 0
    While i < fromCpp.Length && found < 4
        If fromCpp[i] != None
            npcs[found] = fromCpp[i]
            found += 1
        EndIf
        i += 1
    EndWhile
    Return npcs
EndFunction

; アクターがいればHPを表示し、いなければその行を隠します。HP読み取りはバニラでロック不要です（tick毎でも安全です）。
Function ApplyBar(ASTR2CustomBarScript bar, Actor npc, Float px, Float py, Int slot)
    If npc == None
        ASTR2BarUtil.RenderBar(bar, false, 0.0, px, py, 0xFF0000, 0x4A0000)
        _wasAtFloor[slot] = false
        Return
    EndIf
    Float pct = npc.GetActorValuePercentage("Health")
    ; 🔆 ドレイン下限に「到達した瞬間」だけ白く一瞬フラッシュします（吸い尽くしたサインです）。
    ;   one-shotなので下限に張り付いている間は光らせ続けません（到達のtickだけ flashNow=true にします）。
    Bool atFloor = IsAtDrainFloor(npc, pct)
    Bool flashNow = atFloor && !_wasAtFloor[slot]
    _wasAtFloor[slot] = atFloor
    ASTR2BarUtil.RenderBar(bar, true, pct, px, py, 0xFF0000, 0x4A0000, flashNow, 0xFFFFFF)
EndFunction

; HP%がドレイン下限(=max(FloorAbs, 最大HP×FloorPctH))に到達したかを返します。ドレインは無改造で、プロパティを読むだけです。
Bool Function IsAtDrainFloor(Actor npc, Float pct)
    If _drain == None
        Return false
    EndIf
    Float cur = npc.GetActorValue("Health")
    Float maxHP = 0.0
    If pct > 0.0
        maxHP = cur / pct   ; GetActorValuePercentage=cur/max なので、cur/pct で実効最大HPになります
    EndIf
    Float floorHP = _drain.FloorAbs
    If maxHP * _drain.FloorPctH > floorHP
        floorHP = maxHP * _drain.FloorPctH
    EndIf
    Float floorPct = _drain.FloorPctH
    If maxHP > 0.0
        floorPct = floorHP / maxHP
    EndIf
    Return pct <= (floorPct + 0.02)   ; 小さい余裕です。下限張り付きを取りこぼしません
EndFunction

; ===== MCMを閉じた時のプレビュー：4本をMCM位置に5秒表示してフェード =====
Function PreviewPositions()
    If IsHSceneActive
        Return ; シーン進行中なら既に表示されています
    EndIf
    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    PreviewOne(ASTR2ActorHpBar1, MCM.ActorHpBar1X, MCM.ActorHpBar1Y)
    PreviewOne(ASTR2ActorHpBar2, MCM.ActorHpBar2X, MCM.ActorHpBar2Y)
    PreviewOne(ASTR2ActorHpBar3, MCM.ActorHpBar3X, MCM.ActorHpBar3Y)
    PreviewOne(ASTR2ActorHpBar4, MCM.ActorHpBar4X, MCM.ActorHpBar4Y)
    bPreviewing = true
    RegisterForSingleUpdate(5.0)
EndFunction

Function PreviewOne(ASTR2CustomBarScript bar, Float px, Float py)
    ASTR2BarUtil.RenderBar(bar, true, 0.6, px, py, 0xFF0000, 0x4A0000)
EndFunction

Function HideAllBars()
    ASTR2BarUtil.RenderBar(ASTR2ActorHpBar1, false, 0.0, 0.0, 0.0, 0xFF0000, 0x4A0000)
    ASTR2BarUtil.RenderBar(ASTR2ActorHpBar2, false, 0.0, 0.0, 0.0, 0xFF0000, 0x4A0000)
    ASTR2BarUtil.RenderBar(ASTR2ActorHpBar3, false, 0.0, 0.0, 0.0, 0xFF0000, 0x4A0000)
    ASTR2BarUtil.RenderBar(ASTR2ActorHpBar4, false, 0.0, 0.0, 0.0, 0xFF0000, 0x4A0000)
EndFunction
