Scriptname ASTDrainScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; ★ヘルパー解決のlazyキャッシュです（初回1回だけ GetFormFromFile→以降は付箋を読むだけ＝毎tick解決を廃止）。
;   自律設計(GetFormFromFile型)は維持します。返るのは毎回同じ永続フォーム＝挙動は完全に同一です。
ASTR2MainScript _mainCache
ASTR2MCMScript _mcmCache
ASTR2LifeForceBarScript _lfBarCache
ASTR2ExpBarScript _expBarCache
ASTLvlManager _lvlCache
Faction _followerFacCache
Faction _banditFacCache         ; 🅰️ BanditFaction(0001BCC0)＝気づいていない山賊も「元から敵」で殺せるように
Faction _minionFacCache         ; 🛡️ ActiveMinionFaction(0101D278)＝チャーム/蘇生で使役中＝絶対に殺さない目印です
Float Property FloorTolPct = 0.01 Auto   ; 下限到達とみなす許容幅＝最大HPのこの割合（固定1HPだと高HPの相手で永久に成立しません）
; ★CanKillTargetのシーン単位キャッシュ（軽量化A）＝シーン中に変わらない判定を覚えておく枠です。
Actor[] _ckRef                  ; 枠に登録済みの相手です
Bool[] _ckSpecial               ; ユニーク/Essential/Protected/本物のフォロワーです（シーン中不変）
Bool[] _ckBandit                ; BanditFaction所属です（シーン中不変）
Bool[] _ckDone                  ; 上2つを計算済みかどうかです
Float _ckStamp                  ; このキャッシュが属するシーンの印です（kSceneFlagSetTime）

; 💡 自分自身を呼び出せる完全自律型の Get() メソッドです。
ASTDrainScript Function Get() Global
    return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTDrainScript
EndFunction

; =================================================================
; 📋 MCMアビリティ一覧の「現在の威力」表示用getterです（表示層の共通ルール＝各機能がgetterを供給します）。
; =================================================================
Int Function GetBaseDrainPerSec() Global   ; 現在の基礎ドレイン量/秒＝2+(Lv-1)×8（補正抜きの素の値）
    ; ★計算の単一の正はC++(src/CombatDrain.cpp DrainBaseNow)へ移しました（二重持ちを無くすため）。MCM表示・呪文DESCで共用します。
    Return ASTR2Native.GetDrainBaseNow()
EndFunction
Int Function GetReanimCost() Global   ; スイート・ヴァッサルの現在コストです（MCM可変・★〔SkyVault〕 ASTR2_ReanimCost・既定5000＝発射時にC++ PowerResetが同値を直読みします）
    Return (SkyVault.GetFloat(None, "ASTR2_ReanimCost", 5000.0)) as Int
EndFunction
Float Function GetRegenPctPerSec() Global   ; コンスーム・エッセンスの現在の回復＝最大HPの何%/秒（Lv+Restoration補正込み）
    ; ★計算の単一の正はC++(src/CombatDrain.cpp RegenPctNow)へ移しました（二重持ちを無くすため）。MCM表示・呪文DESCで共用します。
    Return ASTR2Native.GetRegenPctNow()
EndFunction
Int Function GetHDrainPerOrgasm() Global   ; H中ドレインの現在威力/オーガズム（相手なし＝素の推定・実量は相手HPで変動します）
    ; ★計算の単一の正はC++(src/HDrain.cpp HDrainOrgasmBaseNow＝実核DoDrainと同式 calcDamage×totalMult)へ移しました（二重持ちを無くすため／是正＝旧表示の乗算×destFactorから実量ベースへ）。MCM表示・色欲{1}DESCで共用します。
    Return ASTR2Native.GetHDrainPerOrgasmNow()
EndFunction

Int Function GetOrgasmLFPer100HP() Global   ; オーガズム吸収＝相手最大HP100あたりのボーナス淫魔力（LF）＝OrgasmLFRate×Lv×100（Lv31で155）。実際は相手最大HP×OrgasmLFRate×Lv・上限OrgasmLFCap/回。調整の指標用です。
    ASTLvlManager lvl = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    ASTDrainScript ds = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTDrainScript
    If lvl == None || ds == None
        Return 0
    EndIf
    Int sucLvl = lvl.SuccubusLvl.GetValueInt()
    Return (ds.OrgasmLFRate * sucLvl * 100.0) as Int
EndFunction
Int Function GetWeaknessResistDown() Global   ; サキュバス・ウィークネスが相手の魔法耐性を下げる総量＝ESP20＋Lv連動の追加減算(WeaknessBase+PerLv×(Lv-6)²)
    ; ★計算の単一の正はC++(src/CombatDrain.cpp WeaknessResistDownNow)へ移しました（二重持ちを無くすため）。MCM表示・呪文DESCで共用します。
    Return ASTR2Native.GetWeaknessDownNow()
EndFunction
Float Function GetWeaknessHMult() Global   ; サキュバス・ウィークネスのH中ドレイン威力倍率です（基礎1.2 ×Hスキル手技cat2）
    Return 1.2 * (1.0 + ASTR2Technique.GetDisplayCatRank(2) * 0.05)   ; rank0で1.2/rank10で1.8
EndFunction
; =================================================================
; 💡 デッドロック解除用の共通呼び出しボタンです（lazyキャッシュ＝初回だけ解決）。
; =================================================================
ASTR2MainScript Function GetMain()
    If _mainCache == None
        _mainCache = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MainScript
    EndIf
    Return _mainCache
EndFunction
ASTR2MCMScript Function GetMCM()
    If _mcmCache == None
        _mcmCache = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MCMScript
    EndIf
    Return _mcmCache
EndFunction
ASTR2LifeForceBarScript Function GetLFBar()
    If _lfBarCache == None
        _lfBarCache = Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
    EndIf
    Return _lfBarCache
EndFunction
ASTR2ExpBarScript Function GetExpBar()
    If _expBarCache == None
        _expBarCache = Game.GetFormFromFile(0x013619, "A Succubus Tale R2.esp") as ASTR2ExpBarScript
    EndIf
    Return _expBarCache
EndFunction
ASTLvlManager Function GetLvlManager()
    If _lvlCache == None
        _lvlCache = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    EndIf
    Return _lvlCache
EndFunction


; =====================================================================================
; ⚙️ MCM等からいじる設定用のプロパティです。
; =====================================================================================
Float Property HSexBoostMult = 2.0 Auto   ; 🌟H中ドレイン威力の倍率の【ベース既定】です。実値はC++ HDrainが〔SkyVault〕ASTR2_HSexBoostBase×レベル×総合ランクで算出します。スライダー未設定時のフォールバック値です。
Float Property HSexBoostLvRate   ; ★H中倍率のレベル係数：×(1+(Lv-1)×HSexBoostLvRate)＝Lv10で+45%。コード固定です。★〔SkyVault〕裏打ち＝C++ HDrainが同キーを直読みします
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_HSexBoostLvRate", 0.05)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_HSexBoostLvRate", value)
    EndFunction
EndProperty
Float Property TechDrainRate   ; ★Hスキル連動の係数：H中 amount×(1+種目rank×TechDrainRate)。0=オフ。★MCM非公開＝rank(変動値)が変化を担うので係数はコード固定です。★〔SkyVault〕裏打ち＝C++ HDrainが同キーを直読みします
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_TechDrainRate", 0.05)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_TechDrainRate", value)
    EndFunction
EndProperty

Float Property DestSkillRate    = 1.5 Auto     ; ドレインでの破壊スキル育成率です
; ★H中オーガズム上乗せ淫魔力（LF）＋シップ（淫魔力の成長・HPには触れません）
; H中オーガズム毎のボーナス淫魔力（LF） = 削ったHP(absorbed) × Rate × サキュバスLv。★〔SkyVault〕裏打ち＝C++ドレイン核が同値を直読みします(GetFloat 0,"ASTR2_OrgLFRate")／MCMスライダーは無改修です(プロパティ名据置)
Float Property OrgasmLFRate
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_OrgLFRate", 0.5)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_OrgLFRate", value)
    EndFunction
EndProperty
; 上乗せ淫魔力（LF）の天井/オーガズム。★〔SkyVault〕裏打ち＝C++ドレイン核が同値を直読みします(GetFloat 0,"ASTR2_OrgLFCap")／MCMスライダーは無改修です(プロパティ名据置)
Float Property OrgasmLFCap
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_OrgLFCap", 2000.0)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_OrgLFCap", value)
    EndFunction
EndProperty
Float Property ServantLFPerTier   ; シップtierごとの淫魔力（LF）倍率加算です（0/+25/+50/+75/+100%）。★〔SkyVault〕裏打ち＝C++ HDrainが同キーを直読みします
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_ServantLFPerTier", 0.25)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_ServantLFPerTier", value)
    EndFunction
EndProperty
; ★Weakness耐性ダウン（サキュバスLv連動）：ESP magnitude=20(全魔法に効く実耐性ダウン)＋スクリプトで"追加"減算（ドレイン特化）。
;   追加 = WeaknessBase + WeaknessPerLv×(サキュバスLv-6)^2 ＝習得Lv7で控えめ(=1)→後半2乗で加速。GetActorValueは既にESP-20込み→更に引く。
;   ドレイン総減算 = 20 + 追加。過剰なら耐性が負→resistFactor>1.0で増幅。
; ★伸び係数と上限capはMCM可変＝StorageUtil "ASTR2_WeaknessPerLv"(既定1.0=2乗係数)/"ASTR2_WeaknessCap"(既定100=追加分の上限)＝アビリティコンフィグ。2乗の高Lv爆発を上限で抑えます

; ★H中floorの下限です（よろけ回避・可変）。Drain本体とTryFinisher(フィニッシュ判定)で共有し、閾値を一本化します。
; ★〔SkyVault〕裏打ち（二重持ち解消）＝C++ HDrain/HpBarHud が同じキーを直読み＝単一の正です。プロパティ名据置で読み手は無改修です。
Float Property FloorAbs    ; H中floorの絶対下限です（超低HP NPCの保険）
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_FloorAbs", 15.0)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_FloorAbs", value)
    EndFunction
EndProperty
Float Property FloorPctH   ; H中floor＝最大HP×この%（高HP NPCのよろけ回避）
    Float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_FloorPctH", 0.10)
    EndFunction
    Function Set(Float value)
        SkyVault.SetFloat(None, "ASTR2_FloorPctH", value)
    EndFunction
EndProperty

; =================================================================
; 🌟 殺害可否の集約判定です（Drain本体＆フィニッシュの参加者ループで共用します）。
; ※本物のフォロワー(CurrentFollowerFaction 0005C84E)で特別判定＝OStim一時teammate/魅了NPCは特別扱いしません。
; =================================================================
; ★軽量化A：判定の"答え"は一切変えず、エンジンへの問い合わせ回数だけ減らします。
;   実測＝H中はVMが詰まっていてネイティブ呼び出し1回に25〜50msかかります（ActorValue2回読むだけで50ms）。
;   この関数は旧実装で約18回/人/tick叩いており、そのうち**ログ1行のためだけに7回**使っていました。
;   ①シーン中に変わらない判定（ユニーク/Essential/Protected/本物のフォロワー/山賊ファクション）は
;     シーン単位でキャッシュ ②ログは"結果が変わった時だけ" ③特別NPCなら敵判定を計算しません（短絡）。
Bool Function CanKillTarget(Actor akTarget, Actor akCaster)
    Int slot = CkSlot(akTarget)
    Bool res = true
    Bool inVassalList = false
    Bool isCmd = false
    ; 🛡️ チャーム/蘇生で使役中の手下(ActiveMinionFaction)は絶対に殺しません＝フィニッシュも戦闘ドレインも共通で下限のまま残します
    Bool isMinion = IsActiveMinion(akTarget)
    If isMinion
        res = false
    Else
        ; 🛡️ 蘇生した手下（死霊/生者問わず）＝VassalListで確実に保護（faction付与が死霊アンデッドに効かない事故を回避＝二重の保険）
        inVassalList = StorageUtil.FormListHas(Game.GetPlayer(), "ASTR2_VassalList", akTarget)
        isCmd = akTarget.IsCommandedActor()   ; ★Reanimate蘇生体（プレイヤーの召喚体）＝実体そのものを見るのでref変化と無関係に守れます
        If inVassalList || isCmd
            res = false
        Else
            ; --- シーン中不変の判定＝キャッシュから読む（初回だけ実際に問い合わせる） ---
            Bool isSpecialNPC = false
            Bool isBandit = false
            If slot >= 0 && _ckDone[slot]
                isSpecialNPC = _ckSpecial[slot]
                isBandit = _ckBandit[slot]
            Else
                ActorBase tb = akTarget.GetActorBase()
                If _followerFacCache == None
                    _followerFacCache = Game.GetFormFromFile(0x0005C84E, "Skyrim.esm") as Faction
                EndIf
                Bool isRealFollower = (_followerFacCache != None && akTarget.IsInFaction(_followerFacCache))
                isSpecialNPC = tb.IsUnique() || tb.IsEssential() || tb.IsProtected() || isRealFollower
                ; 🅰️ 山賊は「気づいていなくても元から敵」＝BanditFaction所属で敵判定（未察知の山賊を取りこぼしません）
                If _banditFacCache == None
                    _banditFacCache = Game.GetFormFromFile(0x0001BCC0, "Skyrim.esm") as Faction
                EndIf
                isBandit = (_banditFacCache != None && akTarget.IsInFaction(_banditFacCache))
                If slot >= 0
                    _ckSpecial[slot] = isSpecialNPC
                    _ckBandit[slot] = isBandit
                    _ckDone[slot] = true
                EndIf
            EndIf
            ASTR2MainScript ASTMain = GetMain()
            If isSpecialNPC
                res = ASTMain.AllowKillUnique
            Else
                ; ★特別NPCでない時だけ敵判定を計算します（旧実装は常に計算＝3回分の問い合わせを無駄にしていました）
                Bool wasEnemy = StorageUtil.GetIntValue(akTarget, "ASTR2_WasEnemy", 0) == 1
                Bool isEnemy = akTarget.IsHostileToActor(akCaster) || akTarget.IsInCombat() || wasEnemy || isBandit
                res = ASTMain.AllowKillNPC || isEnemy
            EndIf
        EndIf
    EndIf
    Return res
EndFunction

; 🌟 C++が集めた材料(ビット)から「殺していいか」を判断します＝TryFinisher専用の軽量版です。
;   ★判断の中身は CanKillTarget と同じルール（変えたら両方直すこと）。違いは材料の取り方だけ：
;     こちらはビットを算術で解く＝ネイティブ呼び出しゼロ。StorageUtilは"必要な時だけ"読みます：
;     ・ASTR2_WasEnemy ＝ 他の材料で敵と判定できなかった時だけ（ほとんど読まれません）
;     ・ASTR2_VassalList ＝「殺せる」と出た時だけ（保護の最終確認）
Bool Function CanKillFromFlags(Actor akTarget, Int f, ASTR2MainScript ASTMain)
    Int r = f / 2                       ; bit1(生存)は呼び元で確認済みなので捨てます
    Bool floored = (r % 2) == 1         ; bit2 下限到達（ここでは使わない）
    r = r / 2
    Bool special = (r % 2) == 1         ; bit4 特別NPC
    r = r / 2
    Bool bandit = (r % 2) == 1          ; bit8 山賊
    r = r / 2
    Bool hostile = (r % 2) == 1         ; bit16 敵対
    r = r / 2
    Bool inCombat = (r % 2) == 1        ; bit32 戦闘中
    r = r / 2
    Bool commanded = (r % 2) == 1       ; bit64 召喚体（Reanimate蘇生体）
    r = r / 2
    Bool minion = (r % 2) == 1          ; bit128 使役中の手下
    ; 🛡️ 手下・召喚体は絶対に殺しません
    If minion || commanded
        Return False
    EndIf
    Bool res
    If special
        res = ASTMain.AllowKillUnique
    Else
        res = ASTMain.AllowKillNPC || hostile || inCombat || bandit
        If !res
            res = StorageUtil.GetIntValue(akTarget, "ASTR2_WasEnemy", 0) == 1   ; ここでしか読みません
        EndIf
    EndIf
    Bool inVassalList = false
    If res
        ; 🛡️ 蘇生した手下＝名簿で最終確認（faction付与が死霊に効かない事故への二重の保険）
        inVassalList = StorageUtil.FormListHas(Game.GetPlayer(), "ASTR2_VassalList", akTarget)
        If inVassalList
            res = false
        EndIf
    EndIf
    Return res
EndFunction

; シーン単位のキャッシュ枠を返します（-1＝枠なし＝従来どおり毎回問い合わせます）。
;   シーンが変わったら（kSceneFlagSetTimeが変わったら）まるごと捨てます＝別のシーン/別の相手を引きずりません。
;   配列の読み書きはVM内で完結＝エンジンへの問い合わせが発生しないのでほぼ無コストです。
Int Function CkSlot(Actor akTarget)
    Float stamp = GetMain().kSceneFlagSetTime
    If stamp != _ckStamp || _ckRef.Length < 1
        _ckStamp = stamp
        _ckRef = new Actor[8]
        _ckSpecial = new Bool[8]
        _ckBandit = new Bool[8]
        _ckDone = new Bool[8]
    EndIf
    Int i = 0
    While i < _ckRef.Length
        If _ckRef[i] == akTarget
            Return i
        EndIf
        i += 1
    EndWhile
    i = 0
    While i < _ckRef.Length
        If _ckRef[i] == None
            _ckRef[i] = akTarget
            _ckDone[i] = false
            Return i
        EndIf
        i += 1
    EndWhile
    ; 枠が尽きた（戦闘で大人数を相手にした等）＝作り直して先頭に登録します（際限なく増やしません）
    _ckRef = new Actor[8]
    _ckSpecial = new Bool[8]
    _ckBandit = new Bool[8]
    _ckDone = new Bool[8]
    _ckRef[0] = akTarget
    Return 0
EndFunction

; =================================================================
; 🛡️ チャーム(60s)/蘇生(永続)で使役中の手下か＝ActiveMinionFaction(0101D278)所属で判定（マーカーは付箋キャッシュ）
; =================================================================
Bool Function IsActiveMinion(Actor akTarget)
    If akTarget == None
        Return False
    EndIf
    If _minionFacCache == None
        _minionFacCache = Game.GetFormFromFile(0x0101D278, "A Succubus Tale R2.esp") as Faction
    EndIf
    Return _minionFacCache != None && akTarget.IsInFaction(_minionFacCache)
EndFunction

; =================================================================
; 💀 不死/保護を外してからKill（同フレームのbleedout演出で1tick目に死なない問題の回避）
; =================================================================
Function KillTarget(Actor akTarget, Actor akCaster)
    ActorBase tb = akTarget.GetActorBase()
    Bool flipped = false
    If tb.IsEssential()
        tb.SetEssential(false)
        flipped = true
    EndIf
    If tb.IsProtected()
        tb.SetProtected(false)
        flipped = true
    EndIf
    If flipped
        Utility.Wait(0.1)
    EndIf
    akTarget.Kill(akCaster)
EndFunction

; =================================================================
; 🌟 H中フィニッシュ：参加者全員がfloorに達したら、シーン強制終了＋殺せる相手を残りHPごと吸い殺します。
;   ・殺すのは canKill 準拠です（MCM許可/敵）。魅了済み町人(canKill=False)はfloorで生存します。
;   ・発動条件＝全員floor以下 ＆ 殺せる相手が最低1人。
;   ・頭数XPは下限到達時に付与済み→ここでは付与しません（残HPは淫魔力（LF）のみ加算＝1000淫魔力（LF）マイルストーンに寄与）。
; =================================================================
Function TryFinisher(Actor akCaster)
    Int tid = 0   ; プレイヤーのシーンスレッドです（後段のOThread.Stopで使います）
    ; ★OStimを叩かずC++キャッシュ(ASTR2Native／HpBarFeed)から参加者を読みます＝OStim負荷ゼロ・ロックフリー。
    ;   GetSceneActorCountを先に見て空(キャッシュ未確立/シーン外)を弾きます＝空配列のNone化回避＋IsRunning判定も兼ねます
    ;   ＝OThreadへのアクセス2回(IsRunning/GetActors)を丸ごと削減します（OStim負荷の軽減）。
    If ASTR2Native.GetSceneActorCount() <= 0
        Return
    EndIf
    Actor[] actors = ASTR2Native.GetSceneActors()
    Actor player = Game.GetPlayer()
    ; ★軽量化B：参加者ごとの材料（下限到達/特別NPC/山賊/敵対/戦闘中/召喚体/手下）を
    ;   C++で一括収集します＝毎tickの問い合わせが「参加者×十数回」から**1回**になります。
    ;   floorの式(max(最大HP×FloorPctH, FloorAbs)＋1.0余裕)はC++側も完全に同じです。
    Int[] flags = ASTR2Native.GetFinisherFlags(actors, akCaster, FloorPctH, FloorAbs, FloorTolPct)

    ASTR2MainScript ASTMain = GetMain()
    Bool allFloored = true
    Bool anyKillable = false
    Int i = 0
    While i < actors.Length && i < flags.Length
        Int f = flags[i]
        If f != 0    ; 0＝プレイヤー/死体/解決不能＝素通り（C++が既に弾いている）
            ; ★「全員下限」は"殺せる相手"だけで判定します。手下/フォロワーは
            ;   そもそも殺さないので、彼らが下限に居るのを待つ意味がありません。しかも**本MODのオーガズムバフ**
            ;   （最大HP+1万・再生+100%）を渡した相手は下限に留まれないため、永久に揃わずフィニッシュが不発に
            ;   なっていました（自分のバフで自分の処刑を妨害していた＝実機ログで確認）。
            ;   ビットは算術(%と/)で解きます＝Math.LogicalAnd(ネイティブ)を使わず＝VM内で完結しほぼ無コストです。
            If CanKillFromFlags(actors[i], f, ASTMain)
                anyKillable = true
                If ((f / 2) % 2) == 0    ; bit2＝下限到達
                    allFloored = false
                EndIf
            EndIf
        EndIf
        i += 1
    EndWhile

    ; 🌟 惜しい＝殺せる相手はいるが全員同時floorが揃っていない（各自バラバラにイク＆regen微戻りで揃わない）
    ;    →参加NPC全員を一斉Climaxで強制絶頂→sendOrgasmEvent→OnOstimOrgasmでドレイン→同時floorへ押し込みます
    ;    （1シーン1回・新フラグ ASTR2_ClimaxFinishScene／アニメ停滞は ignoreStall=true で無視します）。
    ;    ★「絶頂で終了」設定がOFFなら、Climaxで OStim が勝手に終了しないため、下のOThread.Stopと競合しません。
    If anyKillable && !allFloored
        Float sceneStamp = GetMain().kSceneFlagSetTime
        If StorageUtil.GetFloatValue(player, "ASTR2_ClimaxFinishScene", -1.0) != sceneStamp
            StorageUtil.SetFloatValue(player, "ASTR2_ClimaxFinishScene", sceneStamp)
            Int c = 0
            While c < actors.Length && c < flags.Length
                Actor ca = actors[c]
                ; ★殺せる相手だけイカせます＝手下は下限判定から外したので
                ;   強制絶頂させる必要もありません（余計なイカせ回数の計上とドレインを増やしません）。
                If ca != None && ca != player && flags[c] != 0 && CanKillFromFlags(ca, flags[c], ASTMain)
                    OActor.Climax(ca, true)   ; みんな一緒にイカせる＝強制絶頂（次tickでfloor揃え→本発火）
                EndIf
                c += 1
            EndWhile
        EndIf
        Return
    EndIf

    If !allFloored || !anyKillable
        Return
    EndIf

    ; 🌟 発動：シーンを切る→殺せる相手を残りHPごと吸い殺します
    OThread.Stop(tid)
    Utility.Wait(0.3)   ; シーン終了の反映を待ってからKill

    ASTR2LifeForceBarScript lfQ = GetLFBar()
    ASTLvlManager Lvl = GetLvlManager()
    i = 0
    While i < actors.Length
        Actor a = actors[i]
        If a != None && a != player && !a.IsDead() && CanKillTarget(a, akCaster)
            Float remHP = a.GetActorValue("Health")
            If remHP > 0.0
                Int rem = Math.Ceiling(remHP) as Int
                If lfQ != None && rem > 0
                    Int spaceLeft = lfQ.LFenergyMax - lfQ.LFenergyCurr
                    If spaceLeft < 0
                        spaceLeft = 0
                    EndIf
                    Int added = rem
                    If added > spaceLeft
                        added = spaceLeft        ; あふれは集めた量に数えません（ドレインと同じ）
                    EndIf
                    lfQ.LFenergyCurr += added
                    If Lvl != None && added > 0
                        Lvl.RecordLifeForceGain(added as Float)   ; (C)フィニッシュ吸い殺しも総吸収量へ計上します
                    EndIf
                EndIf
                If Lvl != None
                    Lvl.AddLifeForceXp(remHP)
                EndIf
            EndIf
            KillTarget(a, akCaster)
        EndIf
        i += 1
    EndWhile
    If lfQ != None
        lfQ.CheckLifeForce()
        GetMain().RefreshBuffsDebuffsEnergy()   ; 段階バフ（ステータス表示）も即更新＝表示ラグ解消
    EndIf
EndFunction

; =====================================================================================
; 💋 H中ドレインの"cold記帳"（フルC++化）
;   hot(〔門番〕/威力/HP減/淫魔力（LF）加算)は C++核 HDrain.cpp が済ませ、直後に astr2_hdrain_done を送ります。
;   ここはレイテンシ非依存の記帳(おまけXP/淫魔力（LF）-XP/破壊育成/総吸収記録/頭数/OCum)＋吸収FXだけです。
;   結果値(absorbed/acceptedLF/floored/lfFull)は C++が〔SkyVault〕(sender=npc) へ置いてあります。
;   ★登録 RegisterHDrainDone はロード時に起動処理から1回呼びます（登録はセーブへ永続します）。
; =====================================================================================
Function RegisterHDrainDone()
    RegisterForModEvent("astr2_hdrain_done", "OnHDrainDone")
EndFunction

Event OnHDrainDone(string eventName, string strArg, float numArg, Form sender)
    Actor npc = sender as Actor
    If npc == None
        Return
    EndIf
    Float absorbed   = SkyVault.GetFloat(npc, "ASTR2_HDrain_Absorbed", 0.0)
    Float acceptedLF = SkyVault.GetFloat(npc, "ASTR2_HDrain_AcceptedLF", 0.0)
    Bool  floored    = (SkyVault.GetInt(npc, "ASTR2_HDrain_Floored", 0) == 1)
    Bool  lfFull     = (SkyVault.GetInt(npc, "ASTR2_HDrain_LFFull", 0) == 1)
    ASTLvlManager Lvl = GetLvlManager()
    ASTR2MainScript ASTMain = GetMain()
    If Lvl == None
        Return
    EndIf
    ; ① おまけXP＝実吸収×H率(0.05)。満タン中はノーカウントです（あふれ除外・Papyrus Drainと同じ）
    Float expGain = 0.0
    If absorbed > 0.0 && !lfFull
        expGain = absorbed * 0.05
        Lvl.GrantXp(expGain)
    EndIf
    ; ② 実際に入った淫魔力（LF）ぶん＝1000淫魔力（LF）マイルストーン＋破壊スキル育成（獲得淫魔力（LF）連動）
    If acceptedLF > 0.0
        Lvl.AddLifeForceXp(acceptedLF)
        Game.AdvanceSkill("Destruction", acceptedLF * DestSkillRate)
    EndIf
    ; 総吸収記録（あふれ除外）
    If acceptedLF > 0.0 || expGain > 0.0
        Lvl.RecordDrain(npc, acceptedLF, expGain)
    EndIf
    ; ③ 頭数ボーナス＝H中の吸い切り(floor到達)。シーン終了でまとめて付与します（pending）
    If floored
        Lvl.AddPendingHead()
    EndIf
    ; ④ OCum精子搾取ボーナス＝H中♂から1シーン1回、精子量を淫魔力（LF）へ（de-dup=kSceneFlagSetTime）
    Float cumAmt = StorageUtil.GetFloatValue(npc, "CumStoredAmountV2", -1.0)
    If cumAmt > 0.0 && ASTMain != None
        Float cumStamp = ASTMain.kSceneFlagSetTime
        If StorageUtil.GetFloatValue(npc, "ASTR2_CumXpScene", -1.0) != cumStamp
            StorageUtil.SetFloatValue(npc, "ASTR2_CumXpScene", cumStamp)
            Lvl.AddCumLifeForce(cumAmt)
        EndIf
    EndIf
    ; 💥 吸収FX（C++核が数値を済ませた直後＝演出。FXのC++即時化はPhase 2b）
    ASTDrainFx Fx = ASTDrainFx.Get()
    If Fx
        Fx.AbsorbEffectStart(npc, Game.GetPlayer())
    EndIf
    ; 💧 LFバー＆段階バフを即更新（C++が〔SkyVault〕 LFを直更新済みなので表示を追従させます）＝旧Drainのinline更新の代替
    GetLFBar().CheckLifeForce()
    If ASTMain != None
        ASTMain.RefreshBuffsDebuffsEnergy()
    EndIf
EndEvent

; =====================================================================================
; 🩸 戦闘ドレインの"cold記帳"（フルC++化）
;   hot(威力/耐性/弱能/ラスト/HP減/術者回復/淫魔力（LF）加算)は C++核 CombatDrain.cpp が1秒ごとに済ませ、直後に
;   astr2_combatdrain_done を送ります。ここはレイテンシ非依存の記帳(おまけXP/淫魔力（LF）-XP/破壊育成/総吸収記録)＋殺害仕上げ＋FX/バー更新だけです。
;   結果値(absorbed/acceptedLF/killed/lfFull)は C++が〔SkyVault〕(sender=npc) へ置いてあります。
;   ★戦闘ドレインは頭数ボーナスが付きません（従来どおり＝おまけXPのみ）／OCumはH専用なので付きません。
;   ★登録 RegisterCombatDrainDone はロード時に起動処理から1回呼びます（登録はセーブへ永続します）。
; =====================================================================================
Function RegisterCombatDrainDone()
    RegisterForModEvent("astr2_combatdrain_done", "OnCombatDrainDone")
EndFunction

Event OnCombatDrainDone(string eventName, string strArg, float numArg, Form sender)
    Actor npc = sender as Actor
    If npc == None
        Return
    EndIf
    Float absorbed   = SkyVault.GetFloat(npc, "ASTR2_CDrain_Absorbed", 0.0)
    Float acceptedLF = SkyVault.GetFloat(npc, "ASTR2_CDrain_AcceptedLF", 0.0)
    Bool  killed     = (SkyVault.GetInt(npc, "ASTR2_CDrain_Killed", 0) == 1)
    Bool  lfFull     = (SkyVault.GetInt(npc, "ASTR2_CDrain_LFFull", 0) == 1)
    ASTLvlManager Lvl = GetLvlManager()
    If Lvl == None
        Return
    EndIf
    ; ① おまけXP＝実吸収×戦闘率(0.01)。満タン中はノーカウントです（あふれ除外・旧Drainと同じ）
    Float expGain = 0.0
    If absorbed > 0.0 && !lfFull
        expGain = absorbed * 0.01
        Lvl.GrantXp(expGain)
    EndIf
    ; ② 実際に入った淫魔力（LF）ぶん＝1000淫魔力（LF）マイルストーン＋破壊スキル育成（獲得淫魔力（LF）連動・cap無し）
    If acceptedLF > 0.0
        Lvl.AddLifeForceXp(acceptedLF)
        Game.AdvanceSkill("Destruction", acceptedLF * DestSkillRate)
    EndIf
    ; 総吸収記録（あふれ除外）
    If acceptedLF > 0.0 || expGain > 0.0
        Lvl.RecordDrain(npc, acceptedLF, expGain)
    EndIf
    ; 💀 殺害＝Essential/Protected処理込みの KillTarget で仕上げます（C++は判定だけ・稀イベントなので委譲します）。頭数は戦闘では付けません。
    If killed
        KillTarget(npc, Game.GetPlayer())
    EndIf
    ; 💥 吸収FX＋淫魔力（LF）バー/段階バフ更新（C++が〔SkyVault〕 淫魔力（LF）を直更新済みなので表示を追従させます）
    ASTDrainFx Fx = ASTDrainFx.Get()
    If Fx
        Fx.AbsorbEffectStart(npc, Game.GetPlayer())
    EndIf
    GetLFBar().CheckLifeForce()
    GetMain().RefreshBuffsDebuffsEnergy()
EndEvent





