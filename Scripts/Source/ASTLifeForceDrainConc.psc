Scriptname ASTLifeForceDrainConc extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; 💡 プロパティは持たず、Get() と Game.GetPlayer() で取得します。

bool isOn = false

; ★コンスーム・エッセンスの効果です。最大HP基準の%で回復し、1秒tickで処理します。効率には上限があり、端数はフラッシュで使い切り、Restorationスキルを育てます。
Float Property RegenPctPerSec  = 3.0 Auto  ; 緊急回復用です。最大HPの%/秒で回復します（エッセンス・フロウの1%より速く、押し続けですぐ効きます）。
Float Property LFperPctBase    = 3.5 Auto  ; 回復1%あたりの淫魔力（LF）です（Lvに連動し、そのLvで吸える量から逆算します）。
Float Property RefLevel        = 3.0 Auto  ; コンスーム・エッセンスの習得Lvです（淫魔力（LF）とブーストの基準）。
Float Property RestoSkillRate   = 2.5 Auto  ; 淫魔力（LF）消費1あたりのRestoration育成xpです（ハイブリッドの消費連動分で、Lvで自動スケールします）。
Float Property RestoBaseXp      = 8.0 Auto  ; Restoration育成の固定ベースxpです（低Lv保証で、lfCostが小さい低Lvでも最低限育ちます）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    isOn = true

    ASTR2LifeForceBarScript Bar = ASTR2LifeForceBarScript.Get()
    Bar.UpdateLifeForce()
    
    
    RegisterForSingleUpdate(0.5)
EndEvent

Event OnUpdate()
    If isOn
        ASTR2LifeForceBarScript Bar = ASTR2LifeForceBarScript.Get()
        ASTR2MainScript Main = ASTR2MainScript.Get()
        Actor pc = Game.GetPlayer()

        ; 💰 マジカ消費はバニラに一本化しています（Concentrationは CalculateMagickaCost フックで毎秒消費し、マジカ切れはバニラが停止して OnEffectFinish で isOn=false になります）。

        Float hpPct = pc.GetActorValuePercentage("Health")

        ; ★HPが満タンなら回復は不要なので、淫魔力（LF）を消費しません（垂れ流し防止）。押し続け中も監視を続け、HPが減ったら自動で回復を再開します。
        If hpPct >= 1.0
            RegisterForSingleUpdate(1.0)
        ElseIf hpPct > 0.0
            ; --- %回復は最大HP×3%/秒です。fortify込みの最大HPを%から逆算します（高HP環境では実数回復だと効果が薄いため、割合%を基準にします）。LvとRestorationでブーストします ---
            Float lvl = Main.SuccubusLvl.GetValue()
            Float curHP = pc.GetActorValue("Health")
            Float maxHP = curHP / hpPct
            Float boost = 1.0 + (lvl - RefLevel) * 0.05 + pc.GetActorValue("Restoration") / 200.0 + ASTR2Technique.GetDisplayCatRank(1) * 0.05   ; ＋Hスキル（口・舌技cat1）rank0で±0/rank10で+0.5
            Float pctThis = StorageUtil.GetFloatValue(pc, "ASTR2_ConsumeRegenPct", RegenPctPerSec) * boost   ; 威力はMCMスライダー(既定=RegenPctPerSec)
            ; 満タンを超えないよう、足りない分までで止めます。
            Float missingPct = (1.0 - hpPct) * 100.0
            If pctThis > missingPct
                pctThis = missingPct
            EndIf
            ; 淫魔力（LF）の消費は 回復%×LFperPct です（Lvに連動し、エッセンス・フロウと同じ考え方）。最低1。
            Float lfPerPct = StorageUtil.GetFloatValue(pc, "ASTR2_ConsumeLFPerPct", LFperPctBase) * (lvl / RefLevel)   ; コストはMCMスライダー(既定=LFperPctBase)
            int lfCost = (pctThis * lfPerPct) as int
            If lfCost < 1
                lfCost = 1
            EndIf

            If Bar.LFenergyCurr >= lfCost
                ; 通常消費＆%回復
                Bar.LFenergyCurr -= lfCost
                pc.RestoreActorValue("Health", maxHP * (pctThis / 100.0))
                Game.AdvanceSkill("Restoration", RestoBaseXp + lfCost * StorageUtil.GetFloatValue(pc, "ASTR2_ConsumeRestoRate", RestoSkillRate))   ; ハイブリッドは 固定ベース（低Lv保証）＋淫魔力（LF）消費連動（Lvで加速）です。育つ速さはMCMスライダー（既定=RestoSkillRate）。
                Bar.CheckLifeForce()                ; バー即時更新
                Main.RefreshBuffsDebuffsEnergy()    ; ★段階バフ（ステータス表示）も即時更新し、表示ラグを解消します。
                RegisterForSingleUpdate(1.0)
            ElseIf Bar.LFenergyCurr > 0
                ; ★端数ありの場合は、残りの淫魔力（LF）で回復できる%だけ回復して0にし、フラッシュさせます（切れた瞬間に光り、端数も使い切ります）。
                Float remLF = Bar.LFenergyCurr as Float
                Float remPct = remLF / lfPerPct
                pc.RestoreActorValue("Health", maxHP * (remPct / 100.0))
                Game.AdvanceSkill("Restoration", RestoBaseXp + remLF * RestoSkillRate)   ; 端数もハイブリッド（ベース＋消費連動）
                Bar.LFenergyCurr = 0
                Bar.CheckLifeForce()                ; ★淫魔力（LF）が0に到達するとフラッシュ条件が成立します（光ります）。
                Main.RefreshBuffsDebuffsEnergy()
            Else
                ; 既に0なので停止します（次のupdateを呼びません）。
            EndIf
        EndIf
    EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    ASTR2LifeForceBarScript Bar = ASTR2LifeForceBarScript.Get()
    Bar.UpdateLifeForce()
    isOn = false
    
EndEvent