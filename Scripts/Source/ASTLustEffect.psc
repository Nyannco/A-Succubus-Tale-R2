Scriptname ASTLustEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; 💡 変数の準備も OnInit も持ちません。

; ★Hスキルのランクで上乗せします。式は arousal注入 ×(1 + 総合ランク × これ) です。係数はコード固定です（変動値をrankが担うのは、ドレイン率と同じ方針です）。
Float Property TechLustBoost = 0.05 Auto   ; rank10で×1.5(+50%)になります。0にするとHスキルの上乗せはオフです。

; =========================================================
; 📋 アビリティ一覧用のゲッターです（威力の実数を表示するのに使います）。
;   ラストの「魅力アップ量」とは、対象の arousal(欲情) をどれだけ上げる下地になるかを示します。
;   素の値は baseLustArousal(10)×サキュバスLv です（淫魔力（LF）比率は含みません）。実戦では今の淫魔力比率(LF/maxLF)が掛かります
;   つまり淫魔力が満タンなら満額になり、空なら0になります。MCMアビリティ一覧が ASTLustEffect.GetBaseLustArousal() を呼びます。O(1)なので表示時に計算して問題ありません。
; =========================================================
Int Function GetBaseLustArousal() Global
    ; ★計算の単一の正はC++(src/SpellInfo.cpp GetLustArousalNow)へ移しました（二重持ちを無くすためです）。材料LustBaseは〔SkyVault〕(ASTR2_LustBase)にあります。MCM表示と呪文DESCで共用します。
    Return ASTR2Native.GetLustArousalNow()
EndFunction

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; 💰 マジカ消費はバニラに一本化しているので、ここでは払いません（CalculateMagickaCostフックはManaCost.cppにあります）。
    ; 🌟 必要なこの瞬間に、必要なものをまとめて取得します。
    ASTR2MainScript main = ASTR2MainScript.Get()
    ASTR2LifeForceBarScript LFBar = ASTR2LifeForceBarScript.Get()
    
    If main != None && main.isOArousedInstalled && LFBar != None && LFBar.LFenergyMax > 0
        ; arousal注入はOSLのグローバルAPIを直接使います。ラストは下地のarousalを大きく盛り、直後の魅了で押し込むための下地です。
        ; ★式は ベース値(LustBaseスライダー)×Lv × 淫魔力比率 × Hスキル倍率(総合ランクで上乗せします) です。
        Float baseInj = (GetBaseLustArousal() as Float) * (LFBar.LFenergyCurr as Float) / (LFBar.LFenergyMax as Float)
        Float techMult = 1.0 + (ASTR2Technique.GetDisplayTotalRank() as Float) * TechLustBoost
        Float injected = baseInj * techMult
        OSLArousedNative.ModifyArousal(akTarget, injected as int)
        ; 📢 興奮上昇の左上通知です（セダクション系と同じLocFmtStr機構で、いくつ上がったか見えます）。
        String[] lustArgs = new String[2]
        lustArgs[0] = akTarget.GetDisplayName()
        lustArgs[1] = (injected as Int) as String
        Debug.Notification(ASTR2Native.LocFmtStr("$ASTR2_Msg_LustRise", lustArgs))
        ; 🔮 幻惑を育成します（育成量は注入arousal量に比例します）。育成量は今後、他のXPと比較して調整します。
        Game.AdvanceSkill("Illusion", injected * 0.3)   ; 0.3は仮のレートです（調整が必要です）
    EndIf
    
    If LFBar != None
        ; LFBarのエネルギーを減らします。
        LFBar.LFenergyCurr -= 50
        If (LFBar.LFenergyCurr < 0)
            LFBar.LFenergyCurr = 0
        EndIf
        
        ; 状態更新を呼び出します。
        LFBar.CheckLifeForce()
    EndIf
EndEvent  
