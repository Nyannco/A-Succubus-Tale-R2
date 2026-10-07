Scriptname ASTR2ExpBarScript extends Quest

; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
ASTR2ExpBarScript Function Get() Global
    Return Game.GetFormFromFile(0x013619, "A Succubus Tale R2.esp") as ASTR2ExpBarScript
EndFunction

; 🔌 バー本体です（このフォーム自身に同居します）
ASTR2CustomBarScript Property ASTR2ExpBar Auto
; 📦 MCMで動いたら入る箱です
Float Property ExpX Auto
Float Property ExpY Auto
Int Property ExpDisplayMode Auto
Int Property ExpCheckKey Auto
; 🎯 競合ゼロの専用レーンです
Float Property ExpDisplayX Auto
Float Property ExpDisplayY Auto
Int Property ExpActualDisplayMode Auto
Bool Property ExpisBarVisible = False Auto
Float _mode3LastPct                   ; mode3「変化時のみ表示」：最後に表示を発火したときのpct（差分の基準）です
Bool _mode3Showing                    ; mode3の数秒表示タイマーが動作中かどうかのフラグです（RegisterForSingleUpdate予約中）

Event OnKeyDown(Int keyCode)
    If keyCode == ExpCheckKey && ExpCheckKey > 0
        ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
        If MCM != None
            ExpActualDisplayMode = MCM.ExpDisplayMode
        EndIf
        ; モード1（KeySec）だけ：押して3秒出して消す
        If ExpActualDisplayMode == 1
            CheckExp()
            Utility.Wait(3.0)
            If ExpActualDisplayMode == 1 && ASTR2ExpBar != None
                ASTR2ExpBar.FadeOutBar()
            EndIf
        EndIf
    EndIf
EndEvent

Function InitializeExpOnNewGame()
    CheckExp()
EndFunction

Function CheckExp()
    ASTLvlManager Lvl = ASTR2BarUtil.GetLvlManager()
    ; 🌟 サキュバスでないなら消して終了します
    If Lvl == None || !Lvl.IsSuccubus()
        If ASTR2ExpBar != None
            ASTR2ExpBar.FadeOutBar()
        EndIf
        Return
    EndIf

    ; LvlManagerが持つ実際の経験値を直接読みます
    Float currentXP = Lvl.CurrXp
    Float maxXP = Lvl.XpRequired
    Float pct = 0.0
    If maxXP > 0.0
        pct = currentXP / maxXP
    EndIf
    If pct > 1.0
        pct = 1.0
    ElseIf pct < 0.0
        pct = 0.0
    EndIf

    ASTR2MCMScript MCM = ASTR2BarUtil.GetMCM()
    If MCM != None
        If ExpActualDisplayMode != MCM.ExpDisplayMode
            ExpActualDisplayMode = MCM.ExpDisplayMode
            If ExpActualDisplayMode == 0
                ExpisBarVisible = True
            ElseIf ExpActualDisplayMode == 1
                ExpisBarVisible = False
            ElseIf ExpActualDisplayMode == 2
                ExpisBarVisible = False
            ElseIf ExpActualDisplayMode == 3
                ExpisBarVisible = True
                _mode3LastPct = pct        ; mode3へ切替えた直後の誤発火防止のため、今のpctを基準にします
                _mode3Showing = false
            EndIf
        EndIf
        If MCM.ExpX > 0
            ExpDisplayX = MCM.ExpX
            ExpDisplayY = MCM.ExpY
        EndIf
    EndIf

    Bool shouldShow = false
    If ExpActualDisplayMode == 0
        shouldShow = true
    ElseIf ExpActualDisplayMode == 1
        shouldShow = ExpisBarVisible
    ElseIf ExpActualDisplayMode == 3
        ; mode3「変化時のみ表示」：pctが前回表示発火から閾値(5%)以上動いたときだけ数秒出します
        ;   （EXP獲得やレベルアップで大きく動いた瞬間だけ表示して消えます）
        Float expDelta = pct - _mode3LastPct
        If expDelta < 0.0
            expDelta = -expDelta
        EndIf
        If expDelta >= 0.05
            _mode3LastPct = pct
            _mode3Showing = true
            RegisterForSingleUpdate(3.0)   ; 3秒後 OnUpdate で消します（表示中に再変化したら予約し直して延長します）
        EndIf
        shouldShow = _mode3Showing
    EndIf
    ; mode 2 (Hide) は false のままにします
    ASTR2BarUtil.RenderBar(ASTR2ExpBar, shouldShow, pct, ExpDisplayX, ExpDisplayY, 0x73bbf7, 0x73bbf7)
EndFunction

; ⏳ mode3「変化時のみ表示」の数秒タイマー満了でバーをフェードアウトします（RegisterForSingleUpdate(3.0)の受け）
Event OnUpdate()
    _mode3Showing = false
    If ASTR2ExpBar != None
        ASTR2ExpBar.FadeOutBar()
    EndIf
EndEvent

; 🔘 ホットキー：表示/非表示を切り替えます
Function ToggleVisibility()
    If ASTR2ExpBar != None
        If ExpisBarVisible == False
            ExpisBarVisible = True
            ASTR2ExpBar.FadeInBar()
            CheckExp()
        Else
            ExpisBarVisible = False
            ASTR2ExpBar.FadeOutBar()
        EndIf
        ; 🩸 KeySecでHPバーがこのバーの表示に相乗りしているとき、押した瞬間に追従させます（LFバーと同じ理由）。
        ASTR2MainScript Main = ASTR2BarUtil.GetMain()
        If Main != None
            Main.GetActorHpBar().SyncFromMain()
        EndIf
    EndIf
EndFunction

Function FadeOutBar()
    ASTR2ExpBar.FadeOutBar()
EndFunction

; 🔢 数字HUD用で、このバーのウィジェットの場所（"_root.WidgetContainer.widgetN"）を返します。
;   未準備なら空文字で、C++側はその周期をスキップして次で描きます。
String Function GetBarWidgetRoot()
    If ASTR2ExpBar == None || !ASTR2ExpBar.Ready
        Return ""
    EndIf
    Return ASTR2ExpBar.WidgetRoot
EndFunction
