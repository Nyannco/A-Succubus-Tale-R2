Scriptname ASTLvlManager extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

ASTLvlManager Function Get() Global
    return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
EndFunction
; =================================================================
; 💡 デッドロック解除用の共通呼び出しボタンです。
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

GlobalVariable Property SuccubusLvl Auto
; ★経験値は〔SkyVault〕で裏打ちし、C++（バーの数字HUD）が直接読めます。プロパティ名は据え置きなので、
;   ExpBar/MCM/他ファイルは無改修です（LF・IsDrainOnと同じ手）。
float Property XpRequired
    float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_Xp_Req", 200.0)
    EndFunction
    Function Set(float value)
        SkyVault.SetFloat(None, "ASTR2_Xp_Req", value)
    EndFunction
EndProperty
float Property CurrXp
    float Function Get()
        Return SkyVault.GetFloat(None, "ASTR2_Xp_Curr", 0.0)
    EndFunction
    Function Set(float value)
        SkyVault.SetFloat(None, "ASTR2_Xp_Curr", value)
    EndFunction
EndProperty
float Property LustArousal = 0.0 Auto
int Property calcDamage Auto
int Property progressSpeed = 2 Auto

;/ Spells /;
spell Property command Auto
; 💋 下記はMCM(ASTR2MCMScript)のアビリティ一覧表示専用の参照です。Autoプロパティ(VMAD割当)だと既存セーブに
;   古い値(None)が焼き込まれアイコンが欠ける罠があるため、Sp()のFormID直参照にget-onlyで統一しました(習得線SpellsAtLevelと同じ単一の正)。
Spell Property reanimate
    Spell Function Get()
        return Sp(0x00BF77)     ; 甘屍招来 Sweet Vassal
    EndFunction
EndProperty
Spell Property SeductionArea
    Spell Function Get()
        return Sp(0x00BA13)     ; 妖艶結界 Area Seduction
    EndFunction
EndProperty
Spell Property ConsumeLifeForce
    Spell Function Get()
        return Sp(0x00BA0F)     ; 淫魔再生 Consume Essence
    EndFunction
EndProperty
Spell Property SeductionFFAimed
    Spell Function Get()
        return Sp(0x002DB3)     ; 妖艶誘惑 Whisper Seduction
    EndFunction
EndProperty
Spell Property MassSeductionFFSelf
    Spell Function Get()
        return Sp(0x004E05)     ; 妖艶大結界 Mass Seduction
    EndFunction
EndProperty
Spell Property SuccubusWeakness
    Spell Function Get()
        return Sp(0x005E37)     ; 淫魔弱能 Weakness
    EndFunction
EndProperty
Spell Property Lust
    Spell Function Get()
        return Sp(0x00B4A6)     ; 色欲絶頂 Arousing Lust
    EndFunction
EndProperty
Spell[] Property DrainSpellLevels
    Spell[] Function Get()
        Spell[] s = new Spell[2]   ; MCMが参照するのは[1]のみ([0]は元から空)
        s[1] = Sp(0x007924)        ; 吸淫魔力 Drain
        return s
    EndFunction
EndProperty

; 🌟 Lv連動ステータス曲線（Mag/HP最大＝Base + Span×((Lv-1)/99)^Power／両端 Lv1=Base・Lv100=Base+Span）
Float Property StatCurveBase  = 100.0 Auto     ; Lv1のボーナスです
Float Property StatCurveSpan  = 99900.0 Auto   ; Lv1→Lv100の増分です（100000-100）
Float Property StatCurvePower = 3.0 Auto       ; 後半の"がっと"具合です（大きいほど前半少なく後半で激増します）
Spell _orgSelfSpellCache                       ; 自分用スペル ASTOrgasmBuff01(0x01012065)です。自律解決し、起動後1回キャッシュします（プロパティ割当不要）
ActiveMagicEffect _orgBuffEff                  ; 今かかっているオーガズムバフの効果インスタンスです。残り時間をここから読みます（MCM表示用）
MagicEffect _orgHmsEffCache                    ; 重ね掛け防止用のオーガズムバフ固有効果 ASTOrgasmHMSBuff(0130B4)です。チート共有の012060を避けます
Float _recordedSceneStamp                      ; 生涯記録(RecordScene)を刻んだシーンの印です。同じシーンで二重計上しないためです

; 🌟 オーガズムバフ（H後のごほうび・量と時間をLv連動で動的に書き込みます）
Spell _orgNpcSpellCache                        ; 相手用スペル ASTR2OrgasmBuffNPC(0101D7E0)です。自律解決し、起動後1回キャッシュします（プロパティ割当不要）
Float Property OrgBuffBase  = 100.0 Auto       ; プレイヤーH/M/S：Lv1の上昇量です
Float Property OrgBuffSpan  = 99900.0 Auto     ; プレイヤーH/M/S：Lv1→Lv100の増分です（Lv100で+100000）
Float Property OrgBuffPower = 3.0 Auto         ; 曲線の後半の伸び率です（ソウルと同じ3.0）
Int Property OrgDurBase = 300 Auto             ; 効果時間：Lv1＝300秒(5分)
Int Property OrgDurMax  = 3600 Auto            ; 効果時間：Lv100＝3600秒(60分)
; 相手の基礎再生が0の時に足す底上げです。バニラ標準値に揃えます（%倍率は「基礎×%」なので、基礎0だと何倍しても0のまま＝実機で判明）
Float Property OrgNpcHealRateFloor = 0.7 Auto  ; HealRate のバニラ標準です
Float Property OrgNpcMagRateFloor  = 3.0 Auto  ; MagickaRate のバニラ標準です
Float Property OrgNpcStamRateFloor = 5.0 Auto  ; StaminaRate のバニラ標準です
Float Property OrgNpcHpBase = 100.0 Auto       ; 相手HP最大：Lv1の上昇量です
Float Property OrgNpcHpSpan = 9900.0 Auto      ; 相手HP最大：Lv1→Lv100の増分です（Lv100で+10000）

;/ Balance values /;
; ★〔SkyVault〕で裏打ちします（C++ HDrainが同キーを直読みする単一の正です）。プロパティ名据置で読み手は無改修です。
int Property baseDamage
    int Function Get()
        Return SkyVault.GetInt(None, "ASTR2_BaseDamage", 5)
    EndFunction
    Function Set(int value)
        SkyVault.SetInt(None, "ASTR2_BaseDamage", value)
    EndFunction
EndProperty
int Property damageIncrease
    int Function Get()
        Return SkyVault.GetInt(None, "ASTR2_DamageInc", 5)
    EndFunction
    Function Set(int value)
        SkyVault.SetInt(None, "ASTR2_DamageInc", value)
    EndFunction
EndProperty
int Property baseLustArousal = 10 Auto

float Property XpRequiredBase = 100.0 Auto
float Property XpIncreaseValue = 2.0 Auto

; 🌟 新XP収入システム：カーブはNormal固定／progressSpeedは「XP収入倍率」で表現します。
Float Property xpIncomeMult = 1.0 Auto Hidden   ; progressSpeed由来の収入倍率です（VF2.0/F1.5/N1.0/S0.5/VS0.25）
Float Property LFXpAccum = 0.0 Auto Hidden       ; 1000淫魔力（LF）マイルストーン用の累計カウンタです（端数は持ち越します）
Float Property XpPer1000LF = 100.0 Auto          ; 1000淫魔力（LF）あたりの基礎XPです（Normal基準・要ならMCMで調整します）
Float Property XpPerHead = 20.0 Auto             ; 魅了NPC1頭(殺害/下限到達)あたりの基礎XPです（Normal基準）
Float Property XpPerOrgasm = 5.0 Auto            ; H中イカせ1回あたりの基礎XPです（Normal基準・floorボーナスより小さめ）
Float Property CumLFMult = 1.0 Auto              ; OCum：男性NPCから搾り取った精子量1あたりのライフフォース加算量です（仮値／NPC精子量は最大≒30＝最大30淫魔力（LF）/人/シーン）。XPでなく淫魔力（LF）へ加算します（経験値が増えすぎるためです）
Int Property pendingHeadCount = 0 Auto Hidden    ; シーン中の「下限到達(吸い切り)」数→シーン終了でまとめて付与します
Int Property pendingOrgasmCount = 0 Auto Hidden  ; シーン中の「イカせ」数→シーン終了でまとめて付与します

Float Property TotalXpEarned Auto ; 💡 MCM表示用のトータル獲得経験値です（累積消費型）
Bool Property bIsSleep = False Auto ; 💡 システムがスリープ状態かを記憶するフラグです

; =================================================================
; 🌟 レベルアップとスリープ復帰をまとめて管理します。
; =================================================================
int Function LevelUp()
    ASTR2MainScript Main = GetMain()
    ASTTattooScript TattooScript = GetTattoo()
    ASTR2LifeForceBarScript LFBar = GetLFBar()

    int sucLvl = SuccubusLvl.GetValueInt()

    ; 🌟 スリープ状態からの安全復帰ルートです（レベルと経験値を完全保持して復活します）
    If bIsSleep
        bIsSleep = False ; スリープ解除です
        Debug.Notification("$ASTR2_Debug_SuccubusBirth")

        Main.IsDrainOn = True
        ReAddAllSpells() ; 覚醒(スリープ復帰)で1..現在Lvの魔法を全部戻します（下位Lv分も含めて再付与します）
        
        calcDamage = CalculateDamage()
        LustArousal = CalculateLustArousal()

        TattooScript.RefreshTattoo() ; 淫紋の再適用です
        Main.OnLoadFunc()
        
        SkyVault.SetInt(None, "ASTR2_Awake", 1)   ; 覚醒するとMODの大元がONになります（〔クロノス〕の全ジョブを許可し、人間化中の全停止を解除します）。
        ; 覚醒時にLF減衰の時計を開始します（デメリットONなら開始・OFFなら止めたまま）。マーカーはStart側で"今"に置きます
        If Main.AreDisadvantagesEnabled
            ASTR2Native.LFDecayStart()
        Else
            ASTR2Native.LFDecayStop()
        EndIf
        LFBar.UpdateLifeForce()

        ASTR2NailManager.Get().RefreshFromEquipped()   ; 🎴 覚醒ONで装備中ネイルの効果を張り直します（休眠から復帰します）
        GetExpBar().CheckExp()
        Return sucLvl
    EndIf

    ; 🌟 完全に新規でサキュバスになるルートです（初回覚醒）
    If !IsSuccubus() && sucLvl == 0
        XpRequired = XpRequiredBase
        Debug.Notification("$ASTR2_Debug_SuccubusBirth")
        SuccubusLvl.SetValueInt(1)
        sucLvl = 1

        Main.IsDrainOn = True
        ReAddAllSpells()   ; 初回覚醒はLv1なので実質lv1分です（覚醒ONは全再付与に統一）

        TotalXpEarned = 0.0
        SaveXpTotal = 0.0   ; ★覚醒時はLv計算(1000万ゴール)の獲得量を0から数えます（前プレイ/セーブ跨ぎを持ち込みません）
        
        calcDamage = CalculateDamage()
        LustArousal = CalculateLustArousal()

        TattooScript.currTattooLvl = 1
        TattooScript.RefreshTattoo()

        Main.OnLoadFunc()
        
        SkyVault.SetInt(None, "ASTR2_Awake", 1)   ; 覚醒するとMODの大元がONになります（〔クロノス〕の全ジョブを許可し、人間化中の全停止を解除します）。
        ; 覚醒時にLF減衰の時計を開始します（デメリットONなら開始・OFFなら止めたまま）。マーカーはStart側で"今"に置きます
        If Main.AreDisadvantagesEnabled
            ASTR2Native.LFDecayStart()
        Else
            ASTR2Native.LFDecayStop()
        EndIf
        LFBar.UpdateLifeForce()
        ASTR2NailManager.Get().RefreshFromEquipped()   ; 🎴 覚醒ONで装備中ネイルの効果を張り直します
        GetExpBar().CheckExp()   ; ★初回覚醒でもExpバーを即表示してLFと揃えます（呼び忘れ修正・もう片方のルートには有り）

    ElseIf sucLvl < 100
        ; 通常のレベルアップ処理です
        Debug.Notification("$ASTR2_Debug_LevelUp")
        TotalXpEarned += XpRequired
        CurrXp -= XpRequired

        SuccubusLvl.SetValueInt(sucLvl + 1)
        sucLvl += 1 

        If sucLvl < 10
            XpRequired = (XpRequired * XpIncreaseValue)   ; Lv1-10 指数×2.0（MCM収入倍率も効きます）
        ElseIf sucLvl <= 29
            XpRequired = 80000.0                          ; Lv11-30 緩やか（8万・MCM倍率は無視で全員同じです）
        ElseIf sucLvl <= 98
            XpRequired = 110000.0                         ; Lv31-99 少し多め（11万・MCM倍率は無視で全員同じです）
        ElseIf sucLvl == 99
            XpRequired = 10000000.0 - SaveXpTotal         ; ★Lv99→100 帳尻＝到達でちょうど総獲得1000万（倍率差をここで吸収）
            XpRequired = PapyrusUtil.ClampFloat(XpRequired, 1000.0, 10000000.0)   ; 安全網（帳尻がマイナス/過大でも事故りません）
        EndIf

        ; ★余剰XPは切り捨てず次レベルへ持ち越します（上限は安全網の1000万だけ）。旧方式はXpRequiredで頭打ちでした。
        ;   1000淫魔力（LF）ごとに小刻みに渡していた頃は事実上発動しなかったが、バッチ化すると「まとめて渡した分が
        ;   消える」ことで成長が遅くなるためです。持ち越し分はCheckForLvlUpのループが次レベルへ順に消化します。
        CurrXp = PapyrusUtil.ClampFloat(CurrXp, 0, 10000000.0)

        AddSpellsFromLevel(sucLvl)
        
        calcDamage = CalculateDamage()
        LustArousal = CalculateLustArousal()

        int newTatLvl = 1
        If sucLvl >= 10
            newTatLvl = 6
        ElseIf sucLvl >= 8
            newTatLvl = 5
        ElseIf sucLvl >= 6
            newTatLvl = 4
        ElseIf sucLvl >= 4
            newTatLvl = 3
        ElseIf sucLvl >= 2
            newTatLvl = 2
        EndIf

        TattooScript.currTattooLvl = newTatLvl
        TattooScript.RefreshTattoo()
        GetExpBar().CheckExp()
    EndIf
EndFunction


; ★XPをまとめて渡す方式(AddLifeForceXpのバッチ化)にしたので、1回の呼び出しで複数レベル上がれるようにループします。
;   ガードは2つ必須です。①Lv100(上限)ではLevelUpが何もせずCurrXpも減らないため無限ループになります
;   ②guardで空回りの上限を切ります（想定外の状態でフレームを食い潰さない安全網）。
bool Function CheckForLvlUp()
    Bool leveled = false
    Int guard = 0
    While CurrXp >= XpRequired && SuccubusLvl.GetValueInt() < 100 && guard < 100
        LevelUp()
        leveled = true
        guard += 1
    EndWhile
    Return leveled
EndFunction
; =================================================================
; 🌟 サキュバスかどうかを判定します（スリープ中は外部システムに対して「人間」として振る舞います）。
; =================================================================
bool Function IsSuccubus()
    If bIsSleep
        Return False ; スリープ中なら人間扱いにしてシステムを止めます
    EndIf
    If SuccubusLvl.GetValueInt() > 0
        Return True
    EndIf
    Return False
EndFunction

int Function CalculateDamage()
    return ((baseDamage + (damageIncrease * (SuccubusLvl.GetValueInt() - 1))) as int)
EndFunction

int Function CalculateLustArousal()
    return ((baseLustArousal * SuccubusLvl.GetValueInt()) as int)
EndFunction

; =================================================================
; 🌟 破壊的リセットをしない、安全クリーンアップ型のスリープ関数です。
; =================================================================
Function UnSuccuby()
    ASTR2MainScript Main = GetMain()
    ASTTattooScript TattooScript = GetTattoo()
    ASTR2LifeForceBarScript LFBar = GetLFBar()

    ; 🌟 レベル・経験値の破棄（0リセット）はしません。
    ; 内部データは保持したまま、システムをスリープ状態へ移行します
    bIsSleep = True
    SkyVault.SetInt(None, "ASTR2_Awake", 0)   ; 覚醒OFFでMODの大元がOFFになります（〔クロノス〕の全ジョブを停止し、維持費/痕なども止まります）。
    ASTR2Native.LFDecayStop()   ; 覚醒OFFでLF減衰を停止します（発火しません）
    ASTConjCost.OnAwakeOff()    ; 🌙 覚醒OFFでスイート・ヴァッサルの手下(死霊/生者)を全て即解除します（faction/淫紋/alias/死タイマー/〔SkyVault〕キーまで一括掃除・時間ジョブはAwake〔門番〕で自動停止）
    ASTR2Native.WeaknessSigilClearAll()   ; 🔮 覚醒OFFでNPCのウィークネス淫紋を全て消します（放置するとDuration切れまで残るため、MOD撤去前に印を残しません）
    ASTR2Native.DrainMarkClearAll()       ; 💋 覚醒OFFで痕(1回制限)のNPC淫紋も全て消します（巡回は大元ポーズで止まるので能動的にクリアします）
    ASTR2Native.FuryForceOff()            ; 🔥 覚醒OFFでアンリーシュド・フューリーを強制解除します（バフ撤去＋累計消費LF×10%を変性XPへ＋停止）。人間中に効果を残しません
    ASTR2NailManager.Get().RefreshEffects(-1)   ; 🎴 覚醒OFFでシンフル・ネイルの効果を全てOFFにします（アイテム/習得フラグは保持して休眠させます・A案）

    RemoveAllSpells()   ; ★覚醒OFFで覚えている魔法・パーク・Reviving Graceを"全部"除去します（完全クリーン・再覚醒で全戻し）

    ; 🌟 Lv連動ステータス（Mag/HP最大・両再生・声）を人間化で全部0へ戻します
    ClearLevelStats()
    
    ASTR2MCMScript MCM = GetMCM()
    If MCM != None && Main != None
        If MCM.DrainSwitchKey > 0
            Main.UnregisterForKey(MCM.DrainSwitchKey)
        EndIf
        MCM.DrainSwitchKey = -1
        Main.IsDrainOn = False
        Main.GetLogo().ShowDrainLogo(False)
    EndIf

    Main.OnLoadFunc()
    
    LFBar.LFenergyCurr = 400
    Main.RefreshBuffsDebuffsEnergy()
    
    ; 🌟 アンインストール対策として「スキン（淫紋）の完全剥離」を確実に実行します。
    TattooScript.RefreshTattoo()
EndFunction

; レベルアップ時にステータスを再同期し、Reviving Graceを判定し、そのLvの魔法だけ付与します（挙動不変）
Function AddSpellsFromLevel(int lvl)
    ; 🌟 Lv連動ステータス（Mag/HP最大・両再生・声）です。
    ApplyLevelStats()
    ; 💋 Reviving GraceはLv9以上＆維持日数999で一度だけ習得します（条件付きゆえper-Lvブロックとは別枠です）
    TryLearnRevivingGrace()
    GrantSpellsForLevel(lvl, True)   ; レベルアップは新規習得なので通知ありです
    ; 🔋 このLvでライフフォース最大値を再計算します
    GetLFBar().RecalcMaxStorage()
EndFunction

; FormID直参照の短縮ヘルパです（プロパティのセーブ焼き込みに依存せず、既存セーブでも確実にSPELを引けます）
Spell Function Sp(int id)
    Return Game.GetFormFromFile(id, "A Succubus Tale R2.esp") as Spell
EndFunction

; 【習得呪文の単一の正】各Lvで覚える呪文は、付与(Grant)も除去(Remove)もここだけ見ます。二度書きが無く、対称を保証します。
;   ★全てFormID直参照です。プロパティ参照だと既存セーブに古い値(None)が焼き込まれてAddSpell(None)で付かない事故が起きます
;     （実機で確認しました。Drain/Area/Mass等が付かない件の根治です／Furyが先に同じ理由でFormID直参照化済み）。
;   ★パーク(使役数)は型が違うのでGrant側で別扱いです。Reviving Grace(Lv9)は条件付き別枠(TryLearnRevivingGrace)soここに入れません。
Spell[] Function SpellsAtLevel(int lvl)
    Spell[] s
    If lvl == 1
        s = new Spell[4]
        s[0] = Sp(0x007924)     ; 吸淫魔力 Drain
        s[1] = Sp(0x002DB3)     ; 妖艶誘惑 Whisper Seduction
        s[2] = Sp(0x0101C7B1)   ; 絆取込 Servant Sync
        s[3] = Sp(0x02089D)     ; 艶彩罪爪 Sinful Nail（気分配布パワー・1日1回=Power）
    ElseIf lvl == 2
        s = new Spell[6]
        s[0] = Sp(0x00B4A6)     ; 色欲絶頂 Arousing Lust
        s[1] = Sp(0x01BCE2)     ; 淫華封結 Create Shard
        s[2] = Sp(0x01D7EA)     ; 甘露錬丹 Distill Essence
        s[3] = Sp(0x01BCE9)     ; 夢魔誘襲 Nightmare Embrace
        s[4] = Sp(0x00BF77)     ; 甘屍招来 Sweet Vassal
        s[5] = Sp(0x01D7F1)     ; 甘種火宿 Ember Essence
    ElseIf lvl == 3
        s = new Spell[1]
        s[0] = Sp(0x00BA0F)     ; 淫魔再生 Consume Essence
    ElseIf lvl == 4
        s = new Spell[1]
        s[0] = Sp(0x00B4AA)     ; 淫魔解放 Unleashed Fury
    ElseIf lvl == 5
        s = new Spell[1]
        s[0] = Sp(0x00DA62)     ; 淫魔奴隷 Charm（command）
    ElseIf lvl == 6
        s = new Spell[1]
        s[0] = Sp(0x00BA13)     ; 妖艶結界 Area Seduction
    ElseIf lvl == 7
        s = new Spell[1]
        s[0] = Sp(0x005E37)     ; 淫魔弱能 Weakness
    ElseIf lvl == 8
        s = new Spell[1]
        s[0] = Sp(0x004E05)     ; 妖艶大結界 Mass Seduction
    ElseIf lvl == 9
        s = new Spell[1]
        s[0] = Sp(0x02087E)     ; 甘露循環 Essence Flow
    ElseIf lvl == 10
        s = new Spell[1]
        s[0] = Sp(0x020881)     ; 吸淫飽食 Ravenous Drain
    EndIf
    Return s
EndFunction

; ★そのLvの魔法/パークを付与します（showMsg=trueで習得通知ありのレベルアップ時向け／覚醒ONの全再付与はfalseで無音です）。
Function GrantSpellsForLevel(int lvl, bool showMsg = false)
    Actor Player = Game.GetPlayer()
    Spell[] s = SpellsAtLevel(lvl)
    If s
        Int i = 0
        While i < s.Length
            If s[i]
                Player.AddSpell(s[i], showMsg)
            EndIf
            i += 1
        EndWhile
    EndIf
    If lvl == 2
        Player.AddPerk(Game.GetFormFromFile(0x01F2E9, "A Succubus Tale R2.esp") as Perk)   ; 🧟 スイート・ヴァッサルの使役数パークです（Spellと型が違うので別扱いです）
    EndIf
EndFunction

; ★覚醒ONで1..現在Lvの魔法を全部戻します（ステータス1回・XP一切触らない・付与は冪等なので二重取りしません）。
;   ★Reviving Graceは別枠(TryLearnRevivingGrace＝HasSpell判定)so、RemoveAllSpellsで消えません。ここでも自然に温存されます。
Function ReAddAllSpells()
    ApplyLevelStats()
    TryLearnRevivingGrace()   ; 初回習得の判定＋既存習得者の印立て
    ; ★Reviving Graceは習得済みなら維持日数に依らず必ず戻します（覚醒OFFで消してもロストしません）
    If bRevivingGraceEarned
        Actor pc = Game.GetPlayer()
        Spell grace = Game.GetFormFromFile(0x0101ED82, "A Succubus Tale R2.esp") as Spell
        If grace != None && !pc.HasSpell(grace)
            pc.AddSpell(grace, False)   ; 復帰では通知しません（初回習得だけ通知します）
        EndIf
    EndIf
    Int lv = SuccubusLvl.GetValueInt()
    Int i = 1
    While i <= lv
        GrantSpellsForLevel(i)
        i += 1
    EndWhile
    GetLFBar().RecalcMaxStorage()
EndFunction

; ★覚醒OFFで覚えている魔法・パーク・Reviving Graceを"全部"除去します（人間中は魔法ゼロの完全クリーンな状態です）。
;   ★SpellsAtLevelの単一の正を全Lv回して除去します。Grantと対称で消し忘れがありません。パーク/Reviving Graceは別枠なので個別に処理します。
;   ★Reviving Graceも消しますが、再覚醒時は bRevivingGraceEarned の印で維持日数に依らず戻します（ReAddAllSpells）のでロストしません。
Function RemoveAllSpells()
    Actor Player = Game.GetPlayer()
    Player.RemoveSpell(Sp(0x0101ED82))   ; 💋 寵愛賦与 Reviving Grace（印で再覚醒時に戻します。条件付きの別枠です）
    Player.RemovePerk(Game.GetFormFromFile(0x01F2E9, "A Succubus Tale R2.esp") as Perk)   ; 🧟 スイート・ヴァッサルの使役数パークです
    Int lv = 1
    While lv <= 10
        Spell[] s = SpellsAtLevel(lv)
        If s
            Int i = 0
            While i < s.Length
                If s[i]
                    Player.RemoveSpell(s[i])
                EndIf
                i += 1
            EndWhile
        EndIf
        lv += 1
    EndWhile
EndFunction

; =================================================================
; 💋 Reviving Grace の習得を判定します（極めた末に得る力です）
;   Lv9以上 かつ 死霊維持日数999到達で一度だけ習得します。〔ゲート〕はLivingReadyファクション
;   付与（ASTConjCost）と同一です。固定Lv付与でなく条件付きなので専用枠にします。
; =================================================================
; 💋 一度でも習得したら立てる永続印です。覚醒OFFで消しても、再覚醒で維持日数に依らず必ず戻すためです（HasSpellだけだと999未満で二度と戻りません）
Bool Property bRevivingGraceEarned = false Auto Hidden

Function TryLearnRevivingGrace()
    Actor Player = Game.GetPlayer()
    Spell grace = Game.GetFormFromFile(0x0101ED82, "A Succubus Tale R2.esp") as Spell
    If grace == None
        Return
    EndIf
    If Player.HasSpell(grace)
        bRevivingGraceEarned = true   ; 既に持っている場合は習得済みの印を立てます（覚醒OFF→ONで消えても戻せるように）
        Return
    EndIf
    If SuccubusLvl.GetValueInt() >= 9 && ASTConjCost.CalcVassalDays() >= 999.0
        Player.AddSpell(grace, True)   ; True=習得通知（極めた末の力なので見せます）
        bRevivingGraceEarned = true    ; ★以後は維持日数に依らず再覚醒で戻します
    EndIf
EndFunction

; =================================================================
; 🌟 Lv連動ステータス（旧SuccubusSoul/FortifyMagicka/Rate/声アビリティを一本化し、Lv100までスケールします）
;   ・Mag最大/HP最大＝曲線 Base+Span×((Lv-1)/99)^Power（Lv1解放）
;   ・声(Speechcraft)＝+1/Lv（Lv1解放）／Mag再生＝+1%/Lv(Lv3解放)／HP再生＝+1%/Lv(Lv5解放)
;   ・StorageUtilで前回適用分を記憶し差分だけModActorValueします。二重適用は無く、ロード/スリープ復帰でも収束します
; =================================================================

; Mag/HP最大の曲線ボーナスです（Lv1解放・両端 Lv1=Base / Lv100=Base+Span）
Float Function StatCurveBonus()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl < 1
        Return 0.0
    EndIf
    Float t = (lvl - 1) as Float / 99.0
    Return StatCurveBase + StatCurveSpan * Math.Pow(t, StatCurvePower)
EndFunction

; MCM表示用の公開getterです（現在Lvのボーナスを返します）
Int Function GetMagMaxBonus()
    Return StatCurveBonus() as Int
EndFunction
Int Function GetHpMaxBonus()
    Return StatCurveBonus() as Int
EndFunction
Int Function GetSpeechBonus()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl >= 1
        Return lvl
    EndIf
    Return 0
EndFunction
Int Function GetMagRateBonus()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl >= 3
        Return lvl
    EndIf
    Return 0
EndFunction
Int Function GetHpRateBonus()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl >= 5
        Return lvl
    EndIf
    Return 0
EndFunction
Int Function GetStamMaxBonus()
    Return StatCurveBonus() as Int
EndFunction
Int Function GetStamRateBonus()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl >= 7
        Return lvl
    EndIf
    Return 0
EndFunction
; スキル経験値ボーナス%は、ソウル分とオーガズムバフ分の合算です。C++フックがこれを読んで全スキルXPに×(1+N/100)します。MCM表示にも使います。
;   ソウル分＝Lv10解放10%＋極大シャード作成数/1万（上限100%）／バフ分＝オーガズムバフ中だけ Lv×1%（Lv100で+100%）。
Int Function GetSkillXpBonus()
    ; バフ分は ASTR2OrgasmXpEffect が効果の開始/終了で積み下ろします。切れたら自動で0になります（取り残しはありません）
    Return GetSkillXpBonusSoul() + StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_OrgXpPct", 0)
EndFunction

; 恒久ぶん（常時かかっている分）＝Lv10解放の+10% ＋ 極大の淫魔晶1万個ごとに+1%（合計上限100%）。
;   MCMの「常時バフ」欄はこちらを使います。オーガズムバフの一時的な上乗せが混ざって数字が跳ねないように
;   するためです。合算値(GetSkillXpBonus)はC++フックへ押す実効値の方です。
Int Function GetSkillXpBonusSoul()
    If SuccubusLvl.GetValueInt() < 10
        Return 0
    EndIf
    Int bonus = 10 + (StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_GrandShardCount", 0) / 10000)
    If bonus > 100
        bonus = 100
    EndIf
    Return bonus
EndFunction

; =========================================================
; 🌟 オーガズムバフ（H後のごほうび）
; =========================================================
; Lv別に10本あった呪文レコード(ASTOrgasmBuff01-10)は使わず、01の1本だけを使い回して
; 「撃つ直前に量と時間を書き込む」方式にしました。レコードを増やさずLv100までスケールできます。

; Lv連動の量＝ソウルと同じ形の曲線 `Base + Span×((Lv-1)/99)^Power`（Lv1で Base・Lv100で Base+Span）
Float Function OrgasmCurve(Float afBase, Float afSpan)
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl < 1
        Return 0.0
    ElseIf lvl > 100
        lvl = 100
    EndIf
    Float t = (lvl - 1) as Float / 99.0
    Return afBase + afSpan * Math.Pow(t, OrgBuffPower)
EndFunction

; 効果時間(秒)は、Lv1で OrgDurBase・Lv100で OrgDurMax になる線形です（時間は体感しやすさ優先で曲線にしていません）
Int Function OrgasmDurSec()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl < 1
        Return OrgDurBase
    ElseIf lvl > 100
        lvl = 100
    EndIf
    Return (OrgDurBase + ((OrgDurMax - OrgDurBase) as Float) * ((lvl - 1) as Float / 99.0)) as Int
EndFunction

; Lv×1%（上限100%）は、プレイヤーのスキル経験値ボーナスと相手の再生3種に共通で使う割合です
Int Function OrgasmLvPct()
    Int lvl = SuccubusLvl.GetValueInt()
    If lvl < 1
        Return 0
    ElseIf lvl > 100
        lvl = 100
    EndIf
    Return lvl
EndFunction

; MCM表示用の公開getterです（現在Lvでのオーガズムバフの中身を返します）
Int Function GetOrgasmStatBonus()      ; 自分のH/M/S最大の上昇量です
    Return OrgasmCurve(OrgBuffBase, OrgBuffSpan) as Int
EndFunction
Int Function GetOrgasmDurSec()         ; 効果時間(秒)は自分・相手で共通です
    Return OrgasmDurSec()
EndFunction
Int Function GetOrgasmXpPct()          ; 自分のバフ中のスキル経験値ボーナス%です
    Return OrgasmLvPct()
EndFunction
Int Function GetOrgasmNpcHpBonus()     ; 相手のHP最大の上昇量です
    Return OrgasmCurve(OrgNpcHpBase, OrgNpcHpSpan) as Int
EndFunction
Int Function GetOrgasmNpcRegenPct()    ; 相手のHP/マジカ/スタミナ再生の上昇%です
    Return OrgasmLvPct()
EndFunction
; 自分にかかっているオーガズムバフの残り秒です（0ならかかっていません）。MCM表示に使います
Int Function GetOrgasmBuffLeftSec()
    If _orgBuffEff == None
        Return 0
    EndIf
    Int left = (_orgBuffEff.GetDuration() - _orgBuffEff.GetTimeElapsed()) as Int
    If left < 0
        left = 0
    EndIf
    Return left
EndFunction
; 効果インスタンスの受け渡しです。ASTR2OrgasmXpEffectが開始時に自分を預け、終了時にNoneで返します
;   （残り時間はエンジンが持っている値を直接読むので、セーブ跨ぎでもズレません）
Function SetOrgasmBuffEffect(ActiveMagicEffect akEff)
    _orgBuffEff = akEff
EndFunction

; H中にイッた印が立っていればプレイヤーへバフを撃ちます。呼び元は ASTR2MainScript.OnOstimEnd です（シーン終了時）
;   ★H中は印(ASTR2_OrgasmScene)を置くだけでキャストせず、H中のVM負荷を増やしません
;   ★既にバフが残っている時は撃ちません（重ね掛けしないので軽いです）
Function TryOrgasmBuffPlayer()
    Actor pc = Game.GetPlayer()
    If StorageUtil.GetIntValue(pc, "ASTR2_OrgBuffPending", 0) == 0
        Return                                            ; このHでイッていません
    EndIf
    StorageUtil.UnsetIntValue(pc, "ASTR2_OrgBuffPending")  ; 印は使い捨てです
    ; ★重ね掛け防止は「オーガズムバフ固有の効果 ASTOrgasmHMSBuff(0130B4)」で見ます。
    ;   012060(ASTOrgasmHealthBuff)はチートアビリティ ASTR2_Test とも共有で、チートON中は常時trueになり永遠スキップしていました（修正済みです）。
    If _orgHmsEffCache == None
        _orgHmsEffCache = Game.GetFormFromFile(0x010130B4, "A Succubus Tale R2.esp") as MagicEffect
    EndIf
    If _orgHmsEffCache != None && pc.HasMagicEffect(_orgHmsEffCache)
        Return
    EndIf
    CastOrgasmBuff()
EndFunction

; プレイヤーのオーガズムバフを実際に撃ちます（H/M/S最大＋スキル経験値を上げます）
Function CastOrgasmBuff()
    If _orgSelfSpellCache == None
        _orgSelfSpellCache = Game.GetFormFromFile(0x01012065, "A Succubus Tale R2.esp") as Spell
    EndIf
    If _orgSelfSpellCache == None
        Return
    EndIf
    Spell sp = _orgSelfSpellCache
    Int mag = OrgasmCurve(OrgBuffBase, OrgBuffSpan) as Int
    Int dur = OrgasmDurSec()
    Int i = 0
    While i < sp.GetNumEffects()
        If i == 4
            sp.SetNthEffectMagnitude(i, OrgasmLvPct() as Float)   ; 5つ目はスキル経験値の表示に使います（ESPに足せば有効になり、無ければ素通りします）
        Else
            sp.SetNthEffectMagnitude(i, mag as Float)             ; H/M/S＋表示係は同じ量で、元レコードの作りを踏襲します
        EndIf
        sp.SetNthEffectDuration(i, dur)
        i += 1
    EndWhile
    sp.Cast(Game.GetPlayer())
EndFunction

; 基礎再生(HealRate等)が0の相手をバニラ標準値へ底上げします。再生は「基礎×%倍率」なので基礎が0だと
;   本MODの+N%が丸ごと空振りします（実機で確認しました。HealRateが0.00のNPCで回復ゼロでした）。
;   ★一度だけ・0の子だけに適用します（StorageUtilの印で二重には積みません）。既に値がある子には触りません。
Function FixZeroRate(Actor akNpc, String asAv, Float afFloor, String svKey)
    If akNpc.GetActorValue(asAv) > 0.0
        Return
    EndIf
    If StorageUtil.GetIntValue(akNpc, svKey, 0) == 1
        Return
    EndIf
    akNpc.ModActorValue(asAv, afFloor)
    StorageUtil.SetIntValue(akNpc, svKey, 1)
EndFunction

; 相手のオーガズムバフです（HP最大＋再生3種）。呼び元は ASTR2MainScript.OnOstimEnd の参加者ループです
;   条件は、①このシーンでイッたこと、②プレイヤーに敵対していないこと、③まだバフが残っていないことです
;   ★相手用スペル ASTR2OrgasmBuffNPC(0101D7E0) の効果順＝0:Health最大 / 1:HealRateMult / 2:MagickaRateMult / 3:StaminaRateMult（ESP側の並び順が前提です）
Function TryOrgasmBuffNpc(Actor akNpc)
    Actor pc = Game.GetPlayer()
    If _orgNpcSpellCache == None
        _orgNpcSpellCache = Game.GetFormFromFile(0x0101D7E0, "A Succubus Tale R2.esp") as Spell
    EndIf
    If akNpc == None || akNpc == pc || _orgNpcSpellCache == None
        Return
    EndIf
    ASTR2MainScript Main = GetMain()
    ; ①イッた子だけが対象です（MainがOnOstimOrgasmの先頭で立てた予約印で判定します）
    If StorageUtil.GetIntValue(akNpc, "ASTR2_OrgBuffPending", 0) == 0
        Return
    EndIf
    StorageUtil.UnsetIntValue(akNpc, "ASTR2_OrgBuffPending")   ; 印は使い捨てです
    ; ②敵対中は付けません（H後に魅了が解けて敵へ戻った相手も含めてここで弾かれます）
    If akNpc.IsHostileToActor(pc)
        Return
    EndIf
    ; ③重ね掛けしません（プレイヤー側と同じ流儀で軽いです）
    If akNpc.HasMagicEffect(Main.ASTOrgasmHealthBuff)
        Return
    EndIf
    ; ④基礎再生が0の相手を底上げして、%倍率が空振りするのを防ぎます（MOD追加NPCで0のまま放置されている事があります）
    FixZeroRate(akNpc, "HealRate",    OrgNpcHealRateFloor, "ASTR2_RateFloor_HP")
    FixZeroRate(akNpc, "MagickaRate", OrgNpcMagRateFloor,  "ASTR2_RateFloor_Mag")
    FixZeroRate(akNpc, "StaminaRate", OrgNpcStamRateFloor, "ASTR2_RateFloor_Stam")
    Int hp  = OrgasmCurve(OrgNpcHpBase, OrgNpcHpSpan) as Int
    Int pct = OrgasmLvPct()
    Int dur = OrgasmDurSec()
    Int n = _orgNpcSpellCache.GetNumEffects()
    Int i = 0
    While i < n
        If i == 0
            _orgNpcSpellCache.SetNthEffectMagnitude(i, hp as Float)    ; HP最大です
        Else
            _orgNpcSpellCache.SetNthEffectMagnitude(i, pct as Float)   ; 再生3種です（%）
        EndIf
        _orgNpcSpellCache.SetNthEffectDuration(i, dur)
        i += 1
    EndWhile
    ; ★RemoteCastで当てます。Cast()は「その相手自身に詠唱させる」形なので、AIがビジー/詠唱できない状態だと
    ;   静かに失敗します（実機で確認しました。EFF経由で連れてきたフォロワー2人に100%乗りませんでした）。RemoteCastは
    ;   詠唱動作を介さずに効果を置きます。blameも本人なので、ビーム扱いされず誰も敵対しません。
    _orgNpcSpellCache.RemoteCast(akNpc, akNpc, akNpc)
EndFunction

; 現在Lvから全ボーナスを算出→差分だけ適用します（AddSpellsFromLevelから毎レベル呼びます）
Function ApplyLevelStats()
    Actor pc = Game.GetPlayer()
    ; Max（実数・常時でサキュバスソウル基準そのままです）
    ApplyAvDelta(pc, "Magicka",     StatCurveBonus(),          "ASTR2_LvStat_Mag")
    ApplyAvDelta(pc, "Health",      StatCurveBonus(),          "ASTR2_LvStat_HP")
    ApplyAvDelta(pc, "Stamina",     StatCurveBonus(),          "ASTR2_LvStat_Stam")
    ApplyAvDelta(pc, "Speechcraft", GetSpeechBonus() as Float, "ASTR2_LvStat_Speech")
    ; 再生（%）は、サキュバスソウル基準×淫魔力バフ(LF係数)で再計算して付与します
    ApplyRegenBuffs()
    ; スキルXPボーナス%をC++フックへプッシュします（Lv10で10%＋極大シャード数/1万・上限100%）
    ASTR2Native.SetSkillXpBonus(GetSkillXpBonus() as Float)
EndFunction

; 人間に戻る時は、全ボーナスを0へ戻します（ModActorValueで積んだ分を差し引きます）
Function ClearLevelStats()
    Actor pc = Game.GetPlayer()
    ApplyAvDelta(pc, "Magicka",         0.0, "ASTR2_LvStat_Mag")
    ApplyAvDelta(pc, "Health",          0.0, "ASTR2_LvStat_HP")
    ApplyAvDelta(pc, "Stamina",         0.0, "ASTR2_LvStat_Stam")
    ApplyAvDelta(pc, "Speechcraft",     0.0, "ASTR2_LvStat_Speech")
    ApplyAvDelta(pc, "MagickaRateMult", 0.0, "ASTR2_LvStat_MagRate")
    ApplyAvDelta(pc, "HealRateMult",    0.0, "ASTR2_LvStat_HPRate")
    ApplyAvDelta(pc, "StaminaRateMult", 0.0, "ASTR2_LvStat_StamRate")
    ASTR2Native.SetSkillXpBonus(0.0)   ; 🌟 人間化でスキルXPボーナスも解除します（フックの倍率を1.0へ戻します）
EndFunction

; 再生（%）は、サキュバスソウル基準×淫魔力バフ(LF残量)係数で再計算して付与します。Lv変化(ApplyLevelStats)とLF変化(ASTR2MainScript.RefreshBuffsDebuffsEnergy)の両方から呼びます。
; 基準はLv解放〔ゲート〕済みです(Mag=Lv3/HP=Lv5/Stam=Lv7)。
Function ApplyRegenBuffs()
    Actor pc = Game.GetPlayer()
    Float factor = LFRegenFactor()
    ApplyAvDelta(pc, "MagickaRateMult", GetMagRateBonus() * factor,  "ASTR2_LvStat_MagRate")
    SkyVault.SetFloat(None, "ASTR2_SoulMagRate", GetMagRateBonus() * factor)   ; 🔗 エッセンス・フロウのC++版が読めるようにミラーします（StorageUtilはC++から使えないためで、既存のStorageUtil書き込みは上のApplyAvDeltaで維持します）
    ApplyAvDelta(pc, "HealRateMult",    GetHpRateBonus() * factor,   "ASTR2_LvStat_HPRate")
    ApplyAvDelta(pc, "StaminaRateMult", GetStamRateBonus() * factor, "ASTR2_LvStat_StamRate")
EndFunction

; 淫魔力バフ係数は、淫魔力（LF）残量%に応じた再生倍率です（枯渇0.3/低0.7/中1.0/高1.2/満1.5）。不利益OFFまたは非サキュバスのときは1.0(基準そのまま)です。
Float Function LFRegenFactor()
    If !IsSuccubus()
        Return 1.0
    EndIf
    ASTR2MainScript main = GetMain()
    If main == None || !main.AreDisadvantagesEnabled
        Return 1.0
    EndIf
    ASTR2LifeForceBarScript bar = GetLFBar()
    If bar == None || bar.LFenergyMax <= 0
        Return 1.0
    EndIf
    Float pct = (bar.LFenergyCurr as Float) / (bar.LFenergyMax as Float)
    If pct <= 0.06
        Return 0.3
    ElseIf pct <= 0.25
        Return 0.7
    ElseIf pct < 0.75
        Return 1.0
    ElseIf pct < 0.94
        Return 1.2
    EndIf
    Return 1.5
EndFunction

; 目標ボーナスと前回適用分の差だけをModActorValueします（keyに適用済み量を記憶するので、再呼び出しで収束し二重適用はありません）
Function ApplyAvDelta(Actor pc, String av, Float target, String svKey)
    Float prev = StorageUtil.GetFloatValue(pc, svKey, 0.0)
    Float delta = target - prev
    If delta != 0.0
        pc.ModActorValue(av, delta)
        StorageUtil.SetFloatValue(pc, svKey, target)
    EndIf
EndFunction

Function RefreshXpIncreaseValue()
    ; カーブはNormal固定(2.0)で、Lv10まで累計51,100です。progressSpeedは「XP収入倍率」で表現します。
    ; ※旧来はカーブ倍率を1.2〜3.0で変えていました→9レベルぶん指数で暴走しました(4〜1800プレー)。
    ;   収入倍率(線形)に変更し、範囲を50〜400プレーに圧縮しました。倍率はNormal100プレーの逆数です。
    XpIncreaseValue = 2.0
    If progressSpeed == 0
        xpIncomeMult = 2.0    ; Very Fast（収入2倍で約50プレーでLv10です）
    ElseIf progressSpeed == 1
        xpIncomeMult = 1.5    ; Fast（約67プレーです）
    ElseIf progressSpeed == 2
        xpIncomeMult = 1.0    ; Normal（基準・約100プレーです）
    ElseIf progressSpeed == 3
        xpIncomeMult = 0.5    ; Slow（約200プレーです）
    ElseIf progressSpeed == 4
        xpIncomeMult = 0.25   ; Very Slow（約400プレーです）
    EndIf
EndFunction

; =================================================================
; 🌟 XP付与の共通入口です（全ソースがここを通り、収入倍率を一括適用します）
; =================================================================
Function GrantXp(Float baseXp)
    If baseXp <= 0.0
        Return
    EndIf
    ; ★Lv11以降はMCM収入倍率を無視して全員同じペースにします（Lv100の1000万ゴールへ揃え、Lv1-10だけ倍率を適用します）
    Float mult = xpIncomeMult
    If SuccubusLvl.GetValueInt() > 10
        mult = 1.0
    EndIf
    Float gained = baseXp * mult
    CurrXp += gained
    AddXpTotals(gained)   ; 総獲得経験値を集計します。全XP源がここを通ります（ドレインおまけ①/1000淫魔力（LF）②/頭数③すべてです）
    CheckForLvlUp()
    GetExpBar().CheckExp()   ; ←EXPバーを即時更新します（シーン終了flush等の反映漏れを防ぎ、獲得した瞬間にバーへ反映します）
EndFunction

; =================================================================
; 🌟 総獲得経験値を集計します（セーブ内 SaveXpTotal ＋ 生涯 JSON total_xp）
;    GrantXpから「実際にCurrXpへ入ったXP量」で呼ばれ、全XP源を漏れなく拾います。
;    ※旧来はRecordDrainでドレインおまけ分だけ拾っていました→メインXP源(②③)が漏れて大幅にundercountしていました。
; =================================================================
Function AddXpTotals(Float amt)
    If amt <= 0.0
        Return
    EndIf
    Float cap = 10000000.0
    ; セーブ内（新ゲームで0に戻ります）
    SaveXpTotal += amt
    If SaveXpTotal > cap
        SaveXpTotal = cap
    EndIf
    ; 生涯（JSON・セーブをまたいで永続します）
    String f = RecordFile()
    Float xp = JsonUtil.GetFloatValue(f, "total_xp") + amt
    If xp > cap
        xp = cap
    EndIf
    JsonUtil.SetFloatValue(f, "total_xp", xp)
EndFunction

; （LogTotals＝テスト確認用トータルのスナップショット出力。配布版ではログを出さないため撤去）

Bool Property bXpTotalsMigrated = False Auto Hidden   ; SaveXpTotalを既獲得XPで一度だけ埋めたかどうかの記録です（既存セーブの移行に使います）

; （SessionInit＝ログ区切り専用関数。配布版ではログを出さないため撤去。bXpTotalsMigratedは手動リセット永続化で引き続き使用）

; ライフフォース獲得で、累計1000ごとに固定XPを与えます（端数は次回へ持ち越します）。メインのXP源です。
;   ★1000ごとにWhileで回していましたが、吸収量が数百万になると1回の呼び出しで数千周し、その各周で
;     GrantXp(JSON読み書き＋レベル判定＋EXPバー更新)とログ1行が走っていました。H中の渋滞の主因です。
;     「何回分たまったか」を割り算で出して**1回にまとめて**渡す形にしました（付与量は同じです）。
Function AddLifeForceXp(Float lfAmount)
    If lfAmount <= 0.0
        Return
    EndIf
    LFXpAccum += lfAmount
    If LFXpAccum < 1000.0
        Return
    EndIf
    Int steps = (LFXpAccum / 1000.0) as Int      ; たまった1000淫魔力（LF）の回数です
    LFXpAccum -= (steps * 1000) as Float         ; 端数だけ次回へ持ち越します
    GrantXp(XpPer1000LF * steps)
EndFunction

; ゲーム中に集めた淫魔力（LF）（ドレイン吸収以外の精子/フィニッシュ吸い殺し等）を「総吸収量」へ加算します。
;   ★per-NPCランキングには乗せません（集計スカラーだけです）。マイナス(消費)は扱わず、獲得分のみです。誕生400は含めません。
;   RecordDrainと同じく生涯(lf_absorbed)とセーブ内(SaveLfTotal)へ加え、MCM「淫魔力総吸収量」が全獲得を反映して現在淫魔力（LF）と整合します。
Function RecordLifeForceGain(Float lfGain)
    If lfGain <= 0.0
        Return
    EndIf
    String f = RecordFile()
    ; ★上限なし（capなし）です。ドレイン1回の吸収量がそのまま1000万を超えうるので、
    ;   天井を置くと実質「1回でカンスト」になってしまいます。Floatの精度は"値に対する比率"で効きます。
    ;   刻みが1回の吸収量を上回るまでは誤差ゼロ同然なので、天井を置く必要はありません。
    JsonUtil.SetFloatValue(f, "lf_absorbed", JsonUtil.GetFloatValue(f, "lf_absorbed") + lfGain)
    SaveLfTotal += lfGain
EndFunction

; OCumでは男性NPCから搾り取った精子量を「ライフフォース」へ加算します（H中・1シーン1回で、呼び出し側でde-dupします）。
;   ★XPでなく淫魔力（LF）プール(LFenergyCurr)へ直接加算します（OCom併用でXPが増えすぎるためです）。
;   1000淫魔力（LF）マイルストーンXPには乗せず、XPは一切増やしません。♀/未初期化(-1)はDrain側で除外済みです。
;   実際に入った分(あふれ除外)を総吸収量にも計上して、現在淫魔力（LF）と整合させます。
Function AddCumLifeForce(Float cumAmount)
    If cumAmount <= 0.0
        Return
    EndIf
    ASTR2LifeForceBarScript lfb = GetLFBar()
    If lfb == None
        Return
    EndIf
    Int gain = (cumAmount * CumLFMult) as Int
    If gain <= 0
        Return
    EndIf
    Int spaceLeft = lfb.LFenergyMax - lfb.LFenergyCurr
    If spaceLeft < 0
        spaceLeft = 0
    EndIf
    Int added = gain
    If added > spaceLeft
        added = spaceLeft        ; カンスト時は入る分だけにします（あふれは集めた量に数えません。ドレインと同じです）
    EndIf
    lfb.LFenergyCurr += added
    lfb.CheckLifeForce()
    If added > 0
        RecordLifeForceGain(added as Float)   ; 精子→LFも総吸収量へ加えます
    EndIf
EndFunction

; H中のイベントは「貯めて」シーン終了でまとめて付与します（イカせ＋吸い切りボーナスです）。
Function AddPendingHead()
    pendingHeadCount += 1
EndFunction
Function AddPendingOrgasm()
    ; イカせボーナスは1シーン「最初の1回だけ」で、何回イカせても加算しません（終了時flushで1回分だけ付与します）。
    If pendingOrgasmCount < 1
        pendingOrgasmCount = 1
    EndIf
EndFunction

; シーン終了で、貯めた「イカせXP＋吸い切りボーナスXP」を合算して GrantXp を呼びます（総経験値へも自動で集計します）。
Function FlushSceneXp()
    Float baseXp = (pendingHeadCount * XpPerHead) + (pendingOrgasmCount * XpPerOrgasm)
    If baseXp > 0.0
        GrantXp(baseXp)
    EndIf
    pendingHeadCount = 0
    pendingOrgasmCount = 0
EndFunction

; =================================================================
; 🌟 生涯記録（JSONで、セーブをまたいで永続する一生もののデータです）
;    保存先: data/skse/plugins/StorageUtilData/ASuccubusTaleR2/Records.json
;    レベルや現在XP/LFはここには入れず、セーブ内のままです（ニューゲームで0に戻ります）。
;    ここに入れるのは「累計・回数・人数・一番吸った相手」だけです。
; =================================================================
String Function RecordFile() Global
    Return "ASuccubusTaleR2/Records"
EndFunction

; --- セーブ内（このセーブ限り＝新ゲームで0に戻る）累計。生涯ぶんはJSON側に持ちます ---
Float Property SaveXpTotal Auto Hidden
Float Property SaveLfTotal Auto Hidden
Int Property SaveSexCount Auto Hidden
Int Property SaveOrgasmCount Auto Hidden   ; セーブ内の、NPCをイカせた累計回数です

; ドレインのチョークポイント(ASTDrainScript.Drain)から毎回呼びます。
; lfGainは実際にライフフォースへ入った量、expGainは獲得経験値です。生涯(JSON)とセーブ内の両系統へ反映します。
Function RecordDrain(Actor akVictim, Float lfGain, Float expGain)
    String f = RecordFile()
    Actor pc = Game.GetPlayer()

    If lfGain > 0.0
        ; ===== 生涯ライフフォース吸収量（JSON・★上限なし） =====
        JsonUtil.SetFloatValue(f, "lf_absorbed", JsonUtil.GetFloatValue(f, "lf_absorbed") + lfGain)
        ; ===== セーブ内ライフフォース吸収量（同上） =====
        SaveLfTotal += lfGain

        ; ★固有NPCは個別ランキング、汎用NPCは種類名で合算ランキングにします（uniqで振り分けます）
        If IsUniqActor(akVictim)
            ; --- 相手別の累計（生涯：JSONのFormList＋FloatListをFormListFindでペア管理）→ 生涯TOP3更新 ---
            int gi = JsonUtil.FormListFind(f, "drain_victims", akVictim)
            Float gTotal = lfGain
            If gi == -1
                JsonUtil.FormListAdd(f, "drain_victims", akVictim, false)
                JsonUtil.FloatListAdd(f, "drain_totals", lfGain)
            Else
                gTotal = JsonUtil.FloatListGet(f, "drain_totals", gi) + lfGain
                JsonUtil.FloatListSet(f, "drain_totals", gi, gTotal)
            EndIf
            UpdateRankingJson(f, "rank_forms", "rank_ramounts", "rank_names", akVictim, gTotal)

            ; --- 相手別の累計（セーブ内：プレイヤーにぶら下げたFormList＋FloatList）→ セーブ内TOP3更新 ---
            int si = StorageUtil.FormListFind(pc, "ASTR2_DrainVictimsSave", akVictim)
            Float sTotal = lfGain
            If si == -1
                StorageUtil.FormListAdd(pc, "ASTR2_DrainVictimsSave", akVictim, false)
                StorageUtil.FloatListAdd(pc, "ASTR2_DrainTotalsSave", lfGain)
            Else
                sTotal = StorageUtil.FloatListGet(pc, "ASTR2_DrainTotalsSave", si) + lfGain
                StorageUtil.FloatListSet(pc, "ASTR2_DrainTotalsSave", si, sTotal)
            EndIf
            UpdateRankingSave(pc, "ASTR2_RankForms", "ASTR2_RankAmts", "ASTR2_RankNames", akVictim, sTotal)
        Else
            ; 汎用NPCは種類名（基底名）で合算します（生涯＋セーブ内の両方です）
            String bn = ResolveActorName(akVictim)
            AddGenJson(f, "gdrain_names", "gdrain_amts", bn, lfGain)
            AddGenSave(pc, "ASTR2_GDrainNames", "ASTR2_GDrainAmts", bn, lfGain)
        EndIf
    EndIf

    ; ※経験値の総獲得集計は GrantXp 側へ一本化しました（全XP源、つまりドレインおまけ/1000LFマイルストーン/頭数を確実に拾います）。
    ;   旧コードはここで expGain のドレインおまけ分しか拾えず、メインXP源(1000LF/頭数)が漏れて大幅にundercountしていました。
    ;   expGain引数は呼び出し側(ASTDrainScript)互換のため残置しており未使用です。
EndFunction

; 生涯TOP3ランキング（JSON・FormListで個体識別）を更新します。同一個体を除いて挿入し、降順に並べて上位3件を残します。
; formKey/amtKey でランキング種別を切り替えます（ドレイン量＝rank_*／H回数＝bedrank_*）。
Function UpdateRankingJson(String f, String formKey, String amtKey, String nameKey, Form vForm, Float amt)
    Form[] forms = new Form[4]
    Float[] amts = new Float[4]
    String[] names = new String[4]
    int n = JsonUtil.FormListCount(f, formKey)
    int w = 0
    int i = 0
    While i < n
        Form ef = JsonUtil.FormListGet(f, formKey, i)
        Float ea = JsonUtil.FloatListGet(f, amtKey, i)
        String en = JsonUtil.StringListGet(f, nameKey, i)   ; 既存エントリの凍結名を保持します
        If ef != vForm && w < 3
            forms[w] = ef
            amts[w] = ea
            names[w] = en
            w += 1
        EndIf
        i += 1
    EndWhile
    forms[w] = vForm
    amts[w] = amt
    names[w] = ResolveActorName(vForm)   ; 新エントリは今この瞬間に名前を凍結します（後で参照が消えても残ります）
    w += 1
    SortDescForm(forms, amts, names, w)
    JsonUtil.FormListClear(f, formKey)
    JsonUtil.FloatListClear(f, amtKey)
    JsonUtil.StringListClear(f, nameKey)
    int keep = w
    If keep > 3
        keep = 3
    EndIf
    i = 0
    While i < keep
        JsonUtil.FormListAdd(f, formKey, forms[i], true)
        JsonUtil.FloatListAdd(f, amtKey, amts[i])
        JsonUtil.StringListAdd(f, nameKey, names[i], true)
        i += 1
    EndWhile
EndFunction

; セーブ内TOP3ランキングです（StorageUtilでプレイヤーにFormListをぶら下げます）。ロジックは生涯版と同じです。
Function UpdateRankingSave(Actor pc, String formKey, String amtKey, String nameKey, Form vForm, Float amt)
    Form[] forms = new Form[4]
    Float[] amts = new Float[4]
    String[] names = new String[4]
    int n = StorageUtil.FormListCount(pc, formKey)
    int w = 0
    int i = 0
    While i < n
        Form ef = StorageUtil.FormListGet(pc, formKey, i)
        Float ea = StorageUtil.FloatListGet(pc, amtKey, i)
        String en = StorageUtil.StringListGet(pc, nameKey, i)   ; 既存エントリの凍結名を保持します
        If ef != vForm && w < 3
            forms[w] = ef
            amts[w] = ea
            names[w] = en
            w += 1
        EndIf
        i += 1
    EndWhile
    forms[w] = vForm
    amts[w] = amt
    names[w] = ResolveActorName(vForm)
    w += 1
    SortDescForm(forms, amts, names, w)
    StorageUtil.FormListClear(pc, formKey)
    StorageUtil.FloatListClear(pc, amtKey)
    StorageUtil.StringListClear(pc, nameKey)
    int keep = w
    If keep > 3
        keep = 3
    EndIf
    i = 0
    While i < keep
        StorageUtil.FormListAdd(pc, formKey, forms[i], true)
        StorageUtil.FloatListAdd(pc, amtKey, amts[i])
        StorageUtil.StringListAdd(pc, nameKey, names[i], true)
        i += 1
    EndWhile
EndFunction

; Form配列とFloat配列を量の降順に連動ソートします（選択ソートで、countは4以下です）。
Function SortDescForm(Form[] forms, Float[] amts, String[] names, int count)
    int i = 0
    While i < count - 1
        int best = i
        int j = i + 1
        While j < count
            If amts[j] > amts[best]
                best = j
            EndIf
            j += 1
        EndWhile
        If best != i
            Float ta = amts[i]
            amts[i] = amts[best]
            amts[best] = ta
            Form tf = forms[i]
            forms[i] = forms[best]
            forms[best] = tf
            String tn = names[i]
            names[i] = names[best]
            names[best] = tn
        EndIf
        i += 1
    EndWhile
EndFunction

; 相手の表示名をその場で解決します（個体名→基底NPC名→基底フォーム名の順です）。記録時に呼んで凍結します（参照が後で消えても名前を残します）。
String Function ResolveActorName(Form vForm)
    If vForm == None
        Return ""
    EndIf
    Actor a = vForm as Actor
    String nm = ""
    If a != None
        nm = a.GetDisplayName()
        If nm == "" && a.GetActorBase() != None
            nm = a.GetActorBase().GetName()
        EndIf
    EndIf
    If nm == ""
        nm = vForm.GetName()
    EndIf
    Return nm
EndFunction

; 固有NPC（名前付き個人で、フォロワーMODも含みます）かどうかを判定します。ランキングを「個別 vs 種類合算」に振り分ける主軸です。
Bool Function IsUniqActor(Actor a)
    Return a != None && a.GetActorBase() != None && a.GetActorBase().IsUnique()
EndFunction

; 汎用NPCを種類名（基底名："山賊"/"衛兵"等）で合算します。名前キーは動的参照の消失と無関係に永続します。JSON版です。
Function AddGenJson(String f, String namesKey, String amtsKey, String nm, Float amt)
    If nm == ""
        Return
    EndIf
    Int gi = JsonUtil.StringListFind(f, namesKey, nm)
    If gi == -1
        JsonUtil.StringListAdd(f, namesKey, nm, true)
        JsonUtil.FloatListAdd(f, amtsKey, amt)
    Else
        JsonUtil.FloatListSet(f, amtsKey, gi, JsonUtil.FloatListGet(f, amtsKey, gi) + amt)
    EndIf
EndFunction

; セーブ内版です（StorageUtilでプレイヤーにぶら下げます）。
Function AddGenSave(Actor pc, String namesKey, String amtsKey, String nm, Float amt)
    If nm == ""
        Return
    EndIf
    Int si = StorageUtil.StringListFind(pc, namesKey, nm)
    If si == -1
        StorageUtil.StringListAdd(pc, namesKey, nm, true)
        StorageUtil.FloatListAdd(pc, amtsKey, amt)
    Else
        StorageUtil.FloatListSet(pc, amtsKey, si, StorageUtil.FloatListGet(pc, amtsKey, si) + amt)
    EndIf
EndFunction

; 種類合算ランキングの rank番目（0始まり）の行 "名前 (量)" を返します（量の降順で、同値はindexの先勝ちです）。空の場合は --- を返します。
String Function GenRankRowJson(String f, String namesKey, String amtsKey, Int rank)
    Int n = JsonUtil.StringListCount(f, namesKey)
    Int i = 0
    While i < n
        Float ai = JsonUtil.FloatListGet(f, amtsKey, i)
        Int greater = 0
        Int j = 0
        While j < n
            Float aj = JsonUtil.FloatListGet(f, amtsKey, j)
            If aj > ai || (aj == ai && j < i)
                greater += 1
            EndIf
            j += 1
        EndWhile
        If greater == rank
            Return JsonUtil.StringListGet(f, namesKey, i) + " (" + (ai as Int) + ")"
        EndIf
        i += 1
    EndWhile
    Return "$ASTR2_Rec_None"
EndFunction

String Function GenRankRowSave(Actor pc, String namesKey, String amtsKey, Int rank)
    Int n = StorageUtil.StringListCount(pc, namesKey)
    Int i = 0
    While i < n
        Float ai = StorageUtil.FloatListGet(pc, amtsKey, i)
        Int greater = 0
        Int j = 0
        While j < n
            Float aj = StorageUtil.FloatListGet(pc, amtsKey, j)
            If aj > ai || (aj == ai && j < i)
                greater += 1
            EndIf
            j += 1
        EndWhile
        If greater == rank
            Return StorageUtil.StringListGet(pc, namesKey, i) + " (" + (ai as Int) + ")"
        EndIf
        i += 1
    EndWhile
    Return "$ASTR2_Rec_None"
EndFunction

; シーン開始(OnOstimStart)から呼びます。H回数＋Hした相手（ユニーク）を生涯＆セーブ内の両系統へ記録します。
Function RecordScene(Actor[] sceneActors)
    If sceneActors.Length == 0   ; 呼び元(TrySwapHold)が非None確定で渡すので、==None比較のcast-errorログ〔地雷〕を避けます
        Return
    EndIf
    ; ★同じシーンで二重に数えません（実機で確認しました。1回のHでH回数が3重計上されていました）。
    ;   呼び元の TrySwapHold は「済みフラグを最後に立てる」作りなので、4人シーンで anim_changed が固まって飛ぶと
    ;   複数の呼び出しがフラグの隙間を同時に通り抜けます（VMが混むほど隙間が広がり、人数が増えて初めて顕在化します）。
    ;   ここでシーンの印を見て弾けば、何回呼ばれても計上は1回で、呼ばれ方に依存しません。
    Float sceneStamp = GetMain().kSceneFlagSetTime
    If sceneStamp == _recordedSceneStamp
        Return
    EndIf
    _recordedSceneStamp = sceneStamp
    String f = RecordFile()
    Actor pc = Game.GetPlayer()

    ; H回数を数えます（生涯＋セーブ内）
    JsonUtil.SetIntValue(f, "sex_count", JsonUtil.GetIntValue(f, "sex_count") + 1)
    SaveSexCount += 1

    ; Hした人数（同じ相手は二度数えません。allowDuplicate=false）と相手別H回数を数えます
    int i = 0
    While i < sceneActors.Length
        Actor a = sceneActors[i]
        If a != None && a != pc
            JsonUtil.FormListAdd(f, "partners", a, false)
            StorageUtil.FormListAdd(pc, "ASTR2_PartnersSave", a, false)

            ; ★固有は個別に、汎用は種類合算にします
            If IsUniqActor(a)
                ; --- 相手別のH回数（生涯：JSONのFormList＋IntListをペア管理）→ 生涯「一番Hした相手」TOP3 ---
                int gbi = JsonUtil.FormListFind(f, "bed_partners", a)
                int gCount = 1
                If gbi == -1
                    JsonUtil.FormListAdd(f, "bed_partners", a, false)
                    JsonUtil.IntListAdd(f, "bed_counts", 1)
                Else
                    gCount = JsonUtil.IntListGet(f, "bed_counts", gbi) + 1
                    JsonUtil.IntListSet(f, "bed_counts", gbi, gCount)
                EndIf
                UpdateRankingJson(f, "bedrank_forms", "bedrank_amts", "bedrank_names", a, gCount as Float)

                ; --- 相手別のH回数（セーブ内：プレイヤーにぶら下げ）→ セーブ内「一番Hした相手」TOP3 ---
                int sbi = StorageUtil.FormListFind(pc, "ASTR2_BedPartnersSave", a)
                int sCount = 1
                If sbi == -1
                    StorageUtil.FormListAdd(pc, "ASTR2_BedPartnersSave", a, false)
                    StorageUtil.IntListAdd(pc, "ASTR2_BedCountsSave", 1)
                Else
                    sCount = StorageUtil.IntListGet(pc, "ASTR2_BedCountsSave", sbi) + 1
                    StorageUtil.IntListSet(pc, "ASTR2_BedCountsSave", sbi, sCount)
                EndIf
                UpdateRankingSave(pc, "ASTR2_BedRankForms", "ASTR2_BedRankAmts", "ASTR2_BedRankNames", a, sCount as Float)
            Else
                String bnb = ResolveActorName(a)
                AddGenJson(f, "gbed_names", "gbed_amts", bnb, 1.0)
                AddGenSave(pc, "ASTR2_GBedNames", "ASTR2_GBedAmts", bnb, 1.0)
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

; OnOstimOrgasm（NPCがイカむ）から呼びます。イカせた回数＋一番イカせた相手を生涯＆セーブ内へ記録します。
Function RecordOrgasm(Actor a)
    If a == None
        Return
    EndIf
    String f = RecordFile()
    Actor pc = Game.GetPlayer()

    ; イカせた回数を数えます（生涯＋セーブ内）
    JsonUtil.SetIntValue(f, "orgasm_count", JsonUtil.GetIntValue(f, "orgasm_count") + 1)
    SaveOrgasmCount += 1

    ; ★固有は個別に、汎用は種類合算にします
    If IsUniqActor(a)
        ; --- 相手別のイカせ回数（生涯）→ 生涯「一番イカせた相手」TOP3 ---
        int gci = JsonUtil.FormListFind(f, "climax_partners", a)
        int gCount = 1
        If gci == -1
            JsonUtil.FormListAdd(f, "climax_partners", a, false)
            JsonUtil.IntListAdd(f, "climax_counts", 1)
        Else
            gCount = JsonUtil.IntListGet(f, "climax_counts", gci) + 1
            JsonUtil.IntListSet(f, "climax_counts", gci, gCount)
        EndIf
        UpdateRankingJson(f, "climaxrank_forms", "climaxrank_amts", "climaxrank_names", a, gCount as Float)

        ; --- 相手別のイカせ回数（セーブ内）→ セーブ内「一番イカせた相手」TOP3 ---
        int sci = StorageUtil.FormListFind(pc, "ASTR2_ClimaxPartnersSave", a)
        int sCount = 1
        If sci == -1
            StorageUtil.FormListAdd(pc, "ASTR2_ClimaxPartnersSave", a, false)
            StorageUtil.IntListAdd(pc, "ASTR2_ClimaxCountsSave", 1)
        Else
            sCount = StorageUtil.IntListGet(pc, "ASTR2_ClimaxCountsSave", sci) + 1
            StorageUtil.IntListSet(pc, "ASTR2_ClimaxCountsSave", sci, sCount)
        EndIf
        UpdateRankingSave(pc, "ASTR2_ClimaxRankForms", "ASTR2_ClimaxRankAmts", "ASTR2_ClimaxRankNames", a, sCount as Float)
    Else
        String bnc = ResolveActorName(a)
        AddGenJson(f, "gclimax_names", "gclimax_amts", bnc, 1.0)
        AddGenSave(pc, "ASTR2_GClimaxNames", "ASTR2_GClimaxAmts", bnc, 1.0)
    EndIf
EndFunction

; MCM「セーブ内だけ消去」から呼びます。このセーブ限りの記録を全部0にします（生涯JSONには触れません）。
Function ResetRecordsSave()
    Actor pc = Game.GetPlayer()
    SaveXpTotal = 0.0
    SaveLfTotal = 0.0
    bXpTotalsMigrated = True   ; 手動リセットは「以後0から数える」確定です。次ロードで既獲得XPを再注入させません（リセットを永久化します）。
    SaveSexCount = 0
    StorageUtil.FormListClear(pc, "ASTR2_PartnersSave")
    StorageUtil.FormListClear(pc, "ASTR2_RankForms")
    StorageUtil.FloatListClear(pc, "ASTR2_RankAmts")
    StorageUtil.FormListClear(pc, "ASTR2_DrainVictimsSave")
    StorageUtil.FloatListClear(pc, "ASTR2_DrainTotalsSave")
    StorageUtil.FormListClear(pc, "ASTR2_BedPartnersSave")
    StorageUtil.IntListClear(pc, "ASTR2_BedCountsSave")
    StorageUtil.FormListClear(pc, "ASTR2_BedRankForms")
    StorageUtil.FloatListClear(pc, "ASTR2_BedRankAmts")
    ; 名前リスト＋イカせ記録（セーブ内）も消去します
    StorageUtil.StringListClear(pc, "ASTR2_RankNames")
    StorageUtil.StringListClear(pc, "ASTR2_BedRankNames")
    SaveOrgasmCount = 0
    StorageUtil.FormListClear(pc, "ASTR2_ClimaxPartnersSave")
    StorageUtil.IntListClear(pc, "ASTR2_ClimaxCountsSave")
    StorageUtil.FormListClear(pc, "ASTR2_ClimaxRankForms")
    StorageUtil.FloatListClear(pc, "ASTR2_ClimaxRankAmts")
    StorageUtil.StringListClear(pc, "ASTR2_ClimaxRankNames")
    ; 種類合算（汎用NPC・セーブ内）も消去します
    StorageUtil.StringListClear(pc, "ASTR2_GDrainNames")
    StorageUtil.FloatListClear(pc, "ASTR2_GDrainAmts")
    StorageUtil.StringListClear(pc, "ASTR2_GBedNames")
    StorageUtil.FloatListClear(pc, "ASTR2_GBedAmts")
    StorageUtil.StringListClear(pc, "ASTR2_GClimaxNames")
    StorageUtil.FloatListClear(pc, "ASTR2_GClimaxAmts")
EndFunction

; MCM「生涯も消去」から呼びます。JSONの生涯データを全部クリアします（レベル等には触れません）。
Function ResetRecordsLifetime()
    String f = RecordFile()
    JsonUtil.SetFloatValue(f, "lf_absorbed", 0.0)
    JsonUtil.SetFloatValue(f, "total_xp", 0.0)
    JsonUtil.SetIntValue(f, "sex_count", 0)
    JsonUtil.FormListClear(f, "partners")
    JsonUtil.FormListClear(f, "drain_victims")
    JsonUtil.FloatListClear(f, "drain_totals")
    JsonUtil.FormListClear(f, "rank_forms")
    JsonUtil.FloatListClear(f, "rank_ramounts")
    JsonUtil.FormListClear(f, "bed_partners")
    JsonUtil.IntListClear(f, "bed_counts")
    JsonUtil.FormListClear(f, "bedrank_forms")
    JsonUtil.FloatListClear(f, "bedrank_amts")
    ; 名前リスト＋イカせ記録（生涯）も消去します
    JsonUtil.StringListClear(f, "rank_names")
    JsonUtil.StringListClear(f, "bedrank_names")
    JsonUtil.SetIntValue(f, "orgasm_count", 0)
    JsonUtil.FormListClear(f, "climax_partners")
    JsonUtil.IntListClear(f, "climax_counts")
    JsonUtil.FormListClear(f, "climaxrank_forms")
    JsonUtil.FloatListClear(f, "climaxrank_amts")
    JsonUtil.StringListClear(f, "climaxrank_names")
    ; 種類合算（汎用NPC・生涯）も消去します
    JsonUtil.StringListClear(f, "gdrain_names")
    JsonUtil.FloatListClear(f, "gdrain_amts")
    JsonUtil.StringListClear(f, "gbed_names")
    JsonUtil.FloatListClear(f, "gbed_amts")
    JsonUtil.StringListClear(f, "gclimax_names")
    JsonUtil.FloatListClear(f, "gclimax_amts")
    JsonUtil.Save(f)
EndFunction
