Scriptname ASTDrainFx extends Quest  
;Just a copy of main game drain fx
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 💡 以下の Get() メソッドを追加して自律させます
ASTDrainFx Function Get() Global
    return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTDrainFx
EndFunction
; =================================================================
; 💡 デッドロック解除用の共通呼び出し口です
; =================================================================
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

;======================================================================================;

import debug
import game

;======================================================================================;
;  PROPERTIES  /
;=============/
ImageSpaceModifier property TrapImod auto
{IsMod applied with this effect}
VisualEffect property TargetVFX auto
{Visual Effect on Target aiming at Caster}
VisualEffect property CasterVFX auto
{Visual Effect on Caster aming at Target}

Float Property fImodFadeDistance = 2048.0 auto
Float Property fEffectDurationMax = 3.0 auto
{Optional property for controling the time of these effects should they be on a zero duration hit effect Default = 40.0}

;======================================================================================;
;  VARIABLES   /
;=============/

Float fTDistance

;======================================================================================;
;  EVENTS      /
;=============/


Function AbsorbEffectStart(Actor Target, Actor Caster)

		if TrapImod
			if Caster != GetPlayer()
				;We want to base the Imod Strength roughly off the distance the Player is from the caster.
				fTDistance = GetPlayer().GetDistance(Caster)
; 				;debug.trace ("Target Distance is: "+ fTDistance)
				fTDistance = (fImodFadeDistance - fTDistance)
				if fTDistance <= 0
					TrapImod.apply(0.25) 
				else
					fTDistance = (fTDistance / fImodFadeDistance)
					if fTDistance < 0.25
						fTDistance = 0.25
					endif
; 					;debug.trace ("Imod Strength is: "+ fTDistance)
					TrapImod.apply(fTDistance) 
				endif
			else
			TrapImod.apply()                                  ; apply isMod at full strength
			endif
		endif
		if TargetVFX
			TargetVFX.Play(Target,fEffectDurationMax,Caster)              ; Play TargetVFX and aim them at the player
		endif
		if CasterVFX
			CasterVFX.Play(Caster,fEffectDurationMax,Target)
		endif

EndFunction
