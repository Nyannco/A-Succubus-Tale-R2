Scriptname ASTR2CustomBarScript Extends SKI_WidgetBase
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =====================================================================================
; ⚙️ アローサルの仕組みとカラーに完全同期させた設定
; =====================================================================================

Float _width          = 250.0
Float _height         = 25.0
Int   _primaryColor   = 13828073
Int   _secondaryColor = 3342336
Int   _flashColor     = -1
String _fillDirection = "Left"
Float _percent        = 0.0
Float Property MyDefX = 0.0 Auto
Float Property MyDefY = 0.0 Auto

String Function GetWidgetType()
    Return "ASTR2CustomBarScript"
EndFunction

String Function GetWidgetSource()
    Return "skyui/custommeter.swf"
EndFunction

Bool Function IsExtending()
	Return True
EndFunction

; =====================================================================================
; 🚀 バーを画面に呼び出すシステム（右上基準）
; =====================================================================================
Event OnWidgetReset()
    Parent.OnWidgetReset()

    ; 📍 基準点をセットします
    HAnchor = "left"
    VAnchor = "top"
    
    If MyDefX != 0.0
        X = MyDefX
        Y = MyDefY
        Alpha = 0.0
    Else
        Alpha = 0.0
    EndIf

     ; 📍 画面に呼び出すための初期化コマンドをまとめて送ります
     ; バーのサイズや色、塗りつぶし方向などの初期設定をまとめて行います
    Float[] numberArgs = new Float[6]
    numberArgs[0] = _width
    numberArgs[1] = _height
    numberArgs[2] = _primaryColor As Float
    numberArgs[3] = _secondaryColor As Float
    numberArgs[4] = _flashColor As Float
    numberArgs[5] = _percent
    UI.InvokeFloatA(HUD_MENU, WidgetRoot + ".initNumbers", numberArgs)

    String[] stringArgs = new String[1]
    stringArgs[0] = _fillDirection
    UI.InvokeStringA(HUD_MENU, WidgetRoot + ".initStrings", stringArgs)

    UI.Invoke(HUD_MENU, WidgetRoot + ".initCommit")
    ASTR2MainScript Main = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
    If Main != None
        Utility.Wait(0.5)
        Main.UpdateHUDVisibility()
    EndIf
EndEvent


; =====================================================================================
; 🛠️ 外部からこのバーを操作するためのコマンド群です
; =====================================================================================

Function SetPercent(Float a_percent)
    _percent = a_percent
    If (Ready)
        Float[] args = new Float[2]
        args[0] = a_percent
        args[1] = False As Float 
        UI.InvokeFloatA(HUD_MENU, WidgetRoot + ".setPercent", args)
    EndIf
EndFunction

Function SetColors(Int a_primaryColor, Int a_secondaryColor = -1, Int a_flashColor = -1)
    _primaryColor = a_primaryColor
    _secondaryColor = a_secondaryColor
    _flashColor = a_flashColor

    If (Ready)
        Int[] args = new Int[3]
        args[0] = _primaryColor
        args[1] = _secondaryColor
        args[2] = _flashColor
        UI.InvokeIntA(HUD_MENU, WidgetRoot + ".setColors", args)
    EndIf
EndFunction

; 🔆 一瞬フラッシュ：flashColorをセットし、startFlashを呼びます（custommeter.swf の点滅機構）。
;   ★ swfの点滅は startFlash 専用で、setPercent第2引数(即スナップ)でも setColors第3引数(MeterWidgetが捨てる)でも光りません。
Function StartFlash(Int a_flashColor = -1)
    If (Ready)
        Int[] cargs = new Int[1]
        cargs[0] = a_flashColor
        UI.InvokeIntA(HUD_MENU, WidgetRoot + ".setFlashColor", cargs)
        Bool[] fargs = new Bool[1]
        fargs[0] = True                          ; 既に点滅中でも強制的に再発火させます
        UI.InvokeBoolA(HUD_MENU, WidgetRoot + ".startFlash", fargs)
    EndIf
EndFunction

Function FadeOutBar()
    FadeTo(0.0, 1.0)
EndFunction

Function FadeInBar()
    FadeTo(100.0, 1.0)
EndFunction

