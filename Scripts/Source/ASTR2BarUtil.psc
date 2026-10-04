Scriptname ASTR2BarUtil Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =====================================================================================
; 🎛️ バー共通土台（ActorHP / 淫魔力（LF） / Exp 共有）
;   ・"バーへの押し込み方"だけを1箇所にまとめます：位置反映・色・SetPercent・表示/非表示。
;   ・「いつ・何を・どう出すか」の方針は各バー側が持ちます。土台は是非を決めず渡されたとおりに描きます。
;   ・ASTR2Log / ASTR2Technique と同じ Hidden + Global関数の流儀です。
; =====================================================================================

; --- 共有アクセサ（各バーが参照する相手は同じで、定型文を1本化） ---
ASTR2MainScript Function GetMain() Global
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
EndFunction
ASTR2MCMScript Function GetMCM() Global
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MCMScript
EndFunction
ASTLvlManager Function GetLvlManager() Global
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
EndFunction
ASTR2LifeForceBarScript Function GetLFBar() Global
    Return Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
EndFunction
ASTR2ExpBarScript Function GetExpBar() Global
    Return Game.GetFormFromFile(0x013619, "A Succubus Tale R2.esp") as ASTR2ExpBarScript
EndFunction

; --- バー1本へ現在状態を反映します（呼び手が shouldShow・pct・位置・色 を決めて渡します） ---
Function RenderBar(ASTR2CustomBarScript bar, Bool shouldShow, Float pct, Float x, Float y, Int primaryColor, Int secondaryColor, Bool flashNow = false, Int flashColor = -1) Global
    If bar == None
        Return
    EndIf
    If !shouldShow
        bar.FadeOutBar()
        Return
    EndIf
    If bar.X != x || bar.Y != y
        bar.X = x
        bar.Y = y
    EndIf
    ; flashNow=true のときだけ flashColor で一瞬フラッシュします（custommeter.swf の点滅機構で startFlash を使用）。
    ; ★ swfの点滅は startFlash 専用で、setPercent第2引数(即スナップ)でも setColors第3引数(MeterWidgetが捨てる)でも光りません。
    ; 既存呼び出し(7引数)は flashNow=false で、従来どおり点滅しません。
    bar.SetColors(primaryColor, secondaryColor, flashColor)
    bar.SetPercent(pct)
    bar.FadeInBar()
    If flashNow
        bar.StartFlash(flashColor)
    EndIf
EndFunction
