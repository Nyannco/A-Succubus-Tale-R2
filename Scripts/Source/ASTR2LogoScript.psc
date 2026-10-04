Scriptname ASTR2LogoScript extends SKI_WidgetBase  
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =================================================================
; 💡 完全自律型の Get() メソッド群
; =================================================================
ASTR2LogoScript Function Get() Global
    return Game.GetFormFromFile(0x013627, "A Succubus Tale R2.esp") as ASTR2LogoScript
EndFunction
ASTR2MainScript Function GetMain()
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
EndFunction
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
ASTTattooScript Function GetTattoo()
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTTattooScript
EndFunction

Float Property MyDefX = 1050.0 Auto
Float Property MyDefY = 520.0 Auto
Float Property LogoSize = 40.0 Auto
; ==========================================================
; SkyUI ウィジェット必須設定
; ==========================================================
String Function GetWidgetSource()
    return "skyui/ASTLogoWidget.swf"
EndFunction

String Function GetWidgetType()
    return "ASTR2LogoScript"
EndFunction

Bool Function IsExtending()
	Return True
EndFunction

Event OnWidgetReset()
    Parent.OnWidgetReset()
    
    string[] hudModes = new string[2]
    hudModes[0] = "All"
    hudModes[1] = "StealthMode"
    Modes = hudModes
    
    HAnchor = "left"
    VAnchor = "top"
    X = 1050.0
    Y = 520.0
    Alpha = 0.0
    
    Float[] numberArgs = new Float[6]
    numberArgs[0] = 250.0
    numberArgs[1] = 25.0
    numberArgs[2] = 0xFFFFFF
    numberArgs[3] = -1
    numberArgs[4] = -1
    numberArgs[5] = 1.0
    UI.InvokeFloatA(HUD_MENU, WidgetRoot + ".initNumbers", numberArgs)

    String[] stringArgs = new String[1]
    stringArgs[0] = "Left"
    UI.InvokeStringA(HUD_MENU, WidgetRoot + ".initStrings", stringArgs)

    UI.Invoke(HUD_MENU, WidgetRoot + ".initCommit")
    UpdateLogoDisplay()
    
    ; 🌟 ウィジェット全体のサイズを強制的に変更します
    UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", LogoSize)
    UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", LogoSize)

    ; 🌟 _visibleは使わず、Alpha(透明度)だけで判定します
    ASTR2MainScript Main = GetMain()
    
    If Main != None
        Utility.Wait(0.5)
        Main.UpdateHUDVisibility()
    EndIf
EndEvent


; ==========================================================
; ロゴ表示機能
; ==========================================================
Function ShowDrainLogo(bool isOn)
    ; 💡 確実に届くよう Ready チェックを解除します
    If isOn
        Alpha = 100.0
    Else
        Alpha = 0.0
    EndIf
EndFunction
; ==========================================================
; MCM を閉じたとき、またはモード切り替え時に呼び出される統合更新処理です
; ==========================================================
Function UpdateLogoDisplay()
    ; 💡 確実に届くよう Ready チェックを解除します
    ASTR2MCMScript MCM = GetMCM()
    If MCM != None
        Int mode = MCM.LogoDisplayMode
        
        If mode == 3 || mode == 4
            MyDefX = MCM.LogoSmallX
            MyDefY = MCM.LogoSmallY
            LogoSize = MCM.LogoSizeSmall
        Else
            MyDefX = MCM.LogoX
            MyDefY = MCM.LogoY
            LogoSize = MCM.LogoSize
        EndIf
        
        X = MyDefX
        Y = MyDefY
        UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", LogoSize)
        UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", LogoSize)
    EndIf
EndFunction
