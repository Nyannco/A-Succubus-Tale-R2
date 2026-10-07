Scriptname ASTR2LifeForceBarScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

ASTR2LifeForceBarScript Function Get() Global
    Return Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
EndFunction

; 🔌 バー本体です（このフォーム自身に同居します。SSEEditで自分を指します）
ASTR2CustomBarScript Property ASTR2LifeForceBar Auto
; 📦 MCMで動いたら入る箱です
Float Property LifeForceX Auto
Float Property LifeForceY Auto
Int Property LFDisplayMode Auto
Int Property LifeForceCheckKey Auto
; 🎯 競合ゼロの専用レーンです
Float Property LifeForceDisplayX Auto
Float Property LifeForceDisplayY Auto
Int Property LFActualDisplayMode Auto
Int Property LFenergyCurrDef = 400 Auto
; 淫魔力（LF）の現在値/最大値は外部〔SkyVault〕(C++/Papyrus両対応のデータ庫)を「単一の正」にします。H中ドレイン核が
;   C++から直読み直書きできます（StorageUtil依存の壁を消すためです）。プロパティ名は据え置きなので
;   他ファイルは無改修です（.LFenergyCurr/.LFenergyMax がそのまま〔SkyVault〕経由になります）。
;   holder=None(グローバル名前空間で単一のLFプールです。C++側はholder=0で一致します)。キー=ASTR2_LF_Curr / ASTR2_LF_Max。
Int Property LFenergyCurr
    Int Function Get()
        Return SkyVault.GetInt(None, "ASTR2_LF_Curr", LFenergyCurrDef)
    EndFunction
    Function Set(Int value)
        SkyVault.SetInt(None, "ASTR2_LF_Curr", value)
    EndFunction
EndProperty
Int Property LFenergyMax
    Int Function Get()
        ; 〔SkyVault〕未設定(移行直後/新規)なら Lv連動の正しい最大を計算して返します。既存セーブ移行でも最大値が壊れて見えません。
        Int stored = SkyVault.GetInt(None, "ASTR2_LF_Max", -1)
        If stored > 0
            Return stored
        EndIf
        Return ComputeMaxStorage()
    EndFunction
    Function Set(Int value)
        SkyVault.SetInt(None, "ASTR2_LF_Max", value)
    EndFunction
EndProperty
Float Property LFMaxMultiplier = 1.0 Auto
Bool Property LFisBarVisible = False Auto
; ⚙️ ASTから移植したものです
float Property energyIncr = 0.75 Auto
; 減衰の間隔は〔SkyVault〕裏打ちで、〔クロノス〕が直読みします（単位はゲーム内時間で、MCMスライダーで調整します）。
;   プロパティ名は据え置きなのでMCM/Export-Importは無改修です。書いた瞬間にC++の間隔も張り替えます。
int Property energyUpdateFreq
    int Function Get()
        Return SkyVault.GetInt(None, "ASTR2_LFUpdateFreq", 3)
    EndFunction
    Function Set(int value)
        If value <= 0
            value = 3
        EndIf
        SkyVault.SetInt(None, "ASTR2_LFUpdateFreq", value)
        ASTR2Native.LFDecaySyncInterval()   ; 〔クロノス〕へ即反映します（次のコマから新しいグリッドになります）
    EndFunction
EndProperty
Bool _wasEmpty                        ; LF空(0)フラッシュを「到達した瞬間だけ」出す、一度きりのガードです
Float _mode3LastPct                   ; mode3「変化時のみ表示」で、最後に表示発火した時のpctです（差分の基準です）
Bool _mode3Showing                    ; mode3の数秒表示タイマーが動作中かどうかです（RegisterForSingleUpdateで予約中です）

Event OnKeyDown(Int keyCode)
    If keyCode == LifeForceCheckKey && LifeForceCheckKey > 0
        ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
        If MCM != None
            LFActualDisplayMode = MCM.LFDisplayMode
        EndIf
        ; モード1（KeySec）のときだけ、押して3秒出して消します
        If LFActualDisplayMode == 1
            CheckLifeForce()
            Utility.Wait(3.0)
            If LFActualDisplayMode == 1 && ASTR2LifeForceBar != None
                ASTR2LifeForceBar.FadeOutBar()
            EndIf
        EndIf
    EndIf
EndEvent

Function InitializeLifeForceOnNewGame()
    LFenergyCurr = LFenergyCurrDef
    RecalcMaxStorage()
    CheckLifeForce()
EndFunction

; 🔋 最大値を再計算します。式は (2000 + 98000×t³) × MCM倍率（t=(Lv-1)/99）です。
; 淫魔力（LF）最大値の式は、ここだけが「単一の正」として計算式を持ちます（RecalcMaxStorageのSetと、LFenergyMax Getの移行繋ぎが共用します）。
; 淫魔力の最大値は、後半急増カーブ(p=3)です。
;   旧＝`2000 + 400×Lv`＝Lv100で42,000＝Multiplier×100で420万（中途半端でした）。
;   新＝Lv1で2,000／Lv100でちょうど100,000（×100で1,000万）。サキュバスソウルのステータス曲線
;   （Mag/HP最大のp=3後半急増）と同じ思想なので、高Lvの価値が出る形で揃います。
;   ※Lv100超えや0以下が来ても壊れないように、tを0〜1で丸めます。
Int Function ComputeMaxStorage()
    Int sucLvl = ASTR2BarUtil.GetLvlManager().SuccubusLvl.GetValueInt()
    Float t = ((sucLvl - 1) as Float) / 99.0   ; Lv1→0.0 ／ Lv100→1.0
    If t < 0.0
        t = 0.0
    ElseIf t > 1.0
        t = 1.0
    EndIf
    Float baseMax = 2000.0 + 98000.0 * (t * t * t)
    Return (baseMax * LFMaxMultiplier) as Int
EndFunction

Function RecalcMaxStorage()
    LFenergyMax = ComputeMaxStorage()   ; 〔SkyVault〕へ確定値を書きます（以後 LFenergyMax Get は保存値を返します）
EndFunction

; =====================================================================================
; ⏰ 淫魔力の時間減衰は 〔クロノス〕（C++の時計）が持ちます（常時動くタイマーは
;   原則C++です。PapyrusのVMは全MOD共有なので、本MODの定期処理が居座ること自体が他MODを詰まらせるためです）。
;   ・C++が `energyUpdateFreq` 時間ごとの絶対グリッドで発火し→〔SkyVault〕の淫魔力（LF）を直接削って→
;         こちらへは `astr2_lf_tick` を1本だけ飛ばします。Papyrusの仕事は表示の更新だけです。
; =====================================================================================

; C++から「削ったよ」の合図です。バーと段階バフを更新するだけです（計算はC++が済ませてあります）。
Event OnLifeForceTick(String eventName, String strArg, Float numArg, Form sender)
    ASTR2Servantship.PayPetTribute()   ; 🎁 愛玩(tier4)の貢ぎは、LF徴収tickに相乗りします（別タイマーは持たず、貢ぎ%はPayPetTributeが〔SkyVault〕 ASTR2_PetTributePctから読みます。表示更新の前に付与します）
    ASTR2MainScript Main = ASTR2BarUtil.GetMain()
    If Main != None
        Main.RefreshBuffsDebuffsEnergy()
    EndIf
    CheckLifeForce()
EndEvent

; 合図の受け口を張ります（ロード毎に Maintenance から呼ばれます。登録はセーブに残りますが張り直しても無害です）。
Function RegisterLFTick()
    RegisterForModEvent("astr2_lf_tick", "OnLifeForceTick")
EndFunction

; 画面へ反映します。表示モードの解釈は据え置きです（挙動を温存します）。描画は共通土台RenderBarへ渡します。
Function CheckLifeForce()
    ASTLvlManager Lvl = ASTR2BarUtil.GetLvlManager()
    ; 🌟 サキュバスでないなら消して終了します（Expバーと挙動を揃えます）
    If Lvl == None || !Lvl.IsSuccubus()
        If ASTR2LifeForceBar != None
            ASTR2LifeForceBar.FadeOutBar()
        EndIf
        Return
    EndIf

    Float pct = (LFenergyCurr as Float) / (LFenergyMax as Float)
    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    If LFActualDisplayMode != MCM.LFDisplayMode
        LFActualDisplayMode = MCM.LFDisplayMode
        If LFActualDisplayMode == 0
            LFisBarVisible = True
        ElseIf LFActualDisplayMode == 1
            LFisBarVisible = False
        ElseIf LFActualDisplayMode == 2
            LFisBarVisible = False
        ElseIf LFActualDisplayMode == 3
            LFisBarVisible = True
            _mode3LastPct = pct        ; mode3へ切替えた直後の誤発火を防ぐため、今のpctを基準にします
            _mode3Showing = false
        EndIf
    EndIf

    If MCM.LifeForceX > 0
        LifeForceDisplayX = MCM.LifeForceX
        LifeForceDisplayY = MCM.LifeForceY
    EndIf

    Bool shouldShow = false
    If LFActualDisplayMode == 0
        shouldShow = true
    ElseIf LFActualDisplayMode == 1
        shouldShow = LFisBarVisible
    ElseIf LFActualDisplayMode == 3
        ; mode3「変化時のみ表示」では、pctが前回表示発火から閾値(5%)以上動いた時だけ数秒出します
        ;   （LFは減衰で毎tickじわ減ります。閾値なしだと出っぱなしになり、mode0と同じになるためです）
        Float lfDelta = pct - _mode3LastPct
        If lfDelta < 0.0
            lfDelta = -lfDelta
        EndIf
        If lfDelta >= 0.05
            _mode3LastPct = pct
            _mode3Showing = true
            RegisterForSingleUpdate(3.0)   ; 3秒後 OnUpdate で消します（表示中に再変化したら予約し直し、タイマーを延長します）
        EndIf
        shouldShow = _mode3Showing
    EndIf
    ; mode 2 (Hide) は false のままです
    ; 🔆 淫魔力（LF）が空(0)に到達した瞬間だけ、バーと同じピンクで一瞬フラッシュします（回復魔法等で使い切ったサインです）。
    ;   一度きりなので、0に張り付いている間は光らせ続けません（到達のtickだけ flashNow=true）。HPバーの下限フラッシュと同じ思想です。
    Bool lfEmpty = (LFenergyCurr <= 0)
    Bool flashNow = lfEmpty && !_wasEmpty
    _wasEmpty = lfEmpty
    ASTR2BarUtil.RenderBar(ASTR2LifeForceBar, shouldShow, pct, LifeForceDisplayX, LifeForceDisplayY, 0xffc5e1, 0xffc5e1, flashNow, 0xffc5e1)
EndFunction

; ⏳ mode3「変化時のみ表示」の数秒タイマーが満了したら、バーをフェードアウトします（RegisterForSingleUpdate(3.0)の受けです）
Event OnUpdate()
    _mode3Showing = false
    If ASTR2LifeForceBar != None
        ASTR2LifeForceBar.FadeOutBar()
    EndIf
EndEvent

; 🔘 ホットキーで表示と非表示を切り替えます
Function ToggleVisibility()
    If ASTR2LifeForceBar != None
        If LFisBarVisible == False
            LFisBarVisible = True
            ASTR2LifeForceBar.FadeInBar()
            CheckLifeForce()
        Else
            LFisBarVisible = False
            ASTR2LifeForceBar.FadeOutBar()
        EndIf
        ; 🩸 KeySecでHPバーがこのバーの表示に相乗りしている時、押した瞬間に追従させます。
        ;   旧はHPバー側の毎秒ループが自分で気づいて直していました（自己修正）が、そのループを
        ;     〔クロノス〕へ移しました。ポーリングが無くなったのでイベント側から知らせる形にしました。
        ASTR2MainScript Main = ASTR2BarUtil.GetMain()
        If Main != None
            Main.GetActorHpBar().SyncFromMain()
        EndIf
    EndIf
EndFunction

; 「今すぐ1回ぶん減衰を反映して」という関数です。呼び出し元（レベル変更、MCM、コンスーム・エッセンスなど）はそのまま使えます。
;   計算は〔クロノス〕（第1号ジョブ）が持ちます。前回削った時刻からの経過ぶんだけ削るので、
;     定期発火とここが二重に削ることはありません。〔門番〕（覚醒前やデメリットOFFのとき）もC++側が持っています。
;     機能OFF中は減らさず、時刻だけ進めます。止まっていた時間を後から請求しません。
;   戻り値は「サキュバスかつデメリットONだったか」です。旧仕様を維持します（今の呼び出し元は誰も見ていません）。
bool Function UpdateLifeForce()
    ASTR2MainScript Main = ASTR2BarUtil.GetMain()
    ASTLvlManager Lvl = ASTR2BarUtil.GetLvlManager()
    ASTR2Native.LFDecayTickNow()
    Main.RefreshBuffsDebuffsEnergy()
    CheckLifeForce()   ; 🔆 減った分(0到達含む)を即バーへ反映します。淫魔力（LF）空フラッシュの取りこぼしを防ぐためです
    Return (Lvl.IsSuccubus() && Main.AreDisadvantagesEnabled)
EndFunction

Function FadeOutBar()
    ASTR2LifeForceBar.FadeOutBar()
EndFunction

; 🔢 数字HUD用に、このバーのウィジェットの場所（"_root.WidgetContainer.widgetN"）を返します。
;   未準備なら空文字を返します。C++側はその周期をスキップして次で描きます。
String Function GetBarWidgetRoot()
    If ASTR2LifeForceBar == None || !ASTR2LifeForceBar.Ready
        Return ""
    EndIf
    Return ASTR2LifeForceBar.WidgetRoot
EndFunction
