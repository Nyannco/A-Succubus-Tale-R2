Scriptname ASTR2ServantSyncEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =========================================================
; 🔗 サーヴァント・シンク（Servant Sync）パワーの効果です（クロスヘアで狙った1人を取り込む）。
;   セルフのレッサーパワーから発動し、見ているNPCのバニラのRank（将来的にRomanceの値の取り込みも検討中）を
;   実効のティアへ、上がる方向にだけ取り込みます（全員を自動で対象にせず、狙った1人だけを手動で取り込みます）。
;   ※プレイヤー向けの通知（名前入り）はMESGとトークンが必要なため、現状はログのみです。
; =========================================================
Event OnEffectStart(Actor akTarget, Actor akCaster)
    Actor npc = Game.GetCurrentCrosshairRef() as Actor
    If npc == None || npc == akCaster
        Return
    EndIf
    Int before = ASTR2Servantship.GetTier(npc)
    ASTR2Servantship.SyncFromExternal(npc)
    ; ★同期成功（ティアが上がった）時だけ、ドレインの吸収演出を流用して「取り込んだ」印象を出します。
    If ASTR2Servantship.GetTier(npc) > before
        ASTDrainFx fx = ASTDrainFx.Get()
        If fx
            fx.AbsorbEffectStart(npc, akCaster)   ; 吸収VFX（相手↔術者）と画面のイメージスペースを出し、約3秒で自動停止します。
        EndIf
    EndIf
EndEvent
