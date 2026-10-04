Scriptname ASTR2MCMScript extends SKI_ConfigBase

; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =====================================================================================
; 🌟 MCM自身を呼び出す完全自律型の Get() メソッド
; =====================================================================================
ASTR2MCMScript Function Get() Global
    Return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2MCMScript
EndFunction
; =================================================================
; 💡 デッドロック解除用の共通呼び出し
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
ASTR2ActorHpBarScript Function GetActorHpBar()
    Return Game.GetFormFromFile(0x01361A, "A Succubus Tale R2.esp") as ASTR2ActorHpBarScript
EndFunction

; 4本のバー位置を各バーのMyDefX/MyDefY（ESP既定値）で初期化/リセットする
Function InitActorHpDefaults()
    ASTR2ActorHpBarScript AHP = GetActorHpBar()
    If AHP == None
        Return
    EndIf
    If AHP.ASTR2ActorHpBar1 != None
        ActorHpBar1X = AHP.ASTR2ActorHpBar1.MyDefX
        ActorHpBar1Y = AHP.ASTR2ActorHpBar1.MyDefY
    EndIf
    If AHP.ASTR2ActorHpBar2 != None
        ActorHpBar2X = AHP.ASTR2ActorHpBar2.MyDefX
        ActorHpBar2Y = AHP.ASTR2ActorHpBar2.MyDefY
    EndIf
    If AHP.ASTR2ActorHpBar3 != None
        ActorHpBar3X = AHP.ASTR2ActorHpBar3.MyDefX
        ActorHpBar3Y = AHP.ASTR2ActorHpBar3.MyDefY
    EndIf
    If AHP.ASTR2ActorHpBar4 != None
        ActorHpBar4X = AHP.ASTR2ActorHpBar4.MyDefX
        ActorHpBar4Y = AHP.ASTR2ActorHpBar4.MyDefY
    EndIf
    bActorHpDefInit = true
EndFunction

; =====================================================================================
; ⚙️ UIディスプレイ用のプロパティ
; =====================================================================================
Int Property LifeForceCheckKey = -1 Auto
Int Property LFDisplayMode = 0 Auto
Float Property LifeForceX = 980.0 Auto
Float Property LifeForceY = 160.0 Auto
Int Property LFDisplayModeDef = 0 Auto
Float Property LifeForceDefX = 980.0 Auto
Float Property LifeForceDefY = 160.0 Auto

Int Property ExpCheckKey = -1 Auto
Int Property ExpDisplayMode = 0 Auto
Float Property ExpX = 980.0 Auto                  
Float Property ExpY = 185.0 Auto                  
Int Property EXDisplayModeDef = 0 Auto
Float Property ExpDefX = 980.0 Auto
Float Property ExpDefY = 185.0 Auto

Int Property DrainSwitchKey = -1 Auto
Int Property LogoDisplayMode = 3 Auto
Float Property LogoX = 1050.0 Auto
Float Property LogoY = 520.0 Auto
float Property LogoSmallX = 940.0 Auto
float Property LogoSmallY = 150.0 Auto
Float Property LogoSize = 40.0 Auto
Float Property LogoSizeSmall = 10.0 Auto             
Int Property LogoDisplayModeDef = 3 Auto
Float Property LogoDefX = 1050.0 Auto
Float Property LogoDefY = 520.0 Auto
float Property LogoSmallDefX = 940.0 Auto
float Property LogoSmallDefY = 150.0 Auto
Float Property LogoSizeDef = 40.0 Auto
Float Property LogoSizeSmallDef = 10.0 Auto 

Bool Property LifeForceKeyResetToggle = false Auto
Bool Property ExpKeyResetToggle = false Auto
Bool Property DrainKeyResetToggle = false Auto

; --- ActorHp bars (per-bar X/Y, display mode, hotkey, reset). Defaults come from each bar's MyDefX/MyDefY ---
Int Property ActorHpCheckKey = -1 Auto
Int Property ActorHpDisplayMode = 0 Auto
Int Property ActorHpDisplayModeDef = 0 Auto
Float Property ActorHpBar1X = 0.0 Auto
Float Property ActorHpBar1Y = 0.0 Auto
Float Property ActorHpBar2X = 0.0 Auto
Float Property ActorHpBar2Y = 0.0 Auto
Float Property ActorHpBar3X = 0.0 Auto
Float Property ActorHpBar3Y = 0.0 Auto
Float Property ActorHpBar4X = 0.0 Auto
Float Property ActorHpBar4Y = 0.0 Auto
Bool Property ActorHpKeyResetToggle = false Auto
Bool Property bActorHpPosChanged = false Auto Hidden
Bool Property bActorHpDefInit = false Auto Hidden

String[] DisplayModeOptions
String[] ActorHpModeOptions
String[] LogoDisplayModeOptions
Int HeaderLifeForceID
Int SliderLifeForceXID
Int SliderLifeForceYID
Int MenuLifeForceModeID
Int KeyLifeForceCheckID
Int ToggleLifeForceResetID 

Int HeaderExpID
Int SliderExpXID
Int SliderExpYID
Int MenuExpModeID
Int KeyExpCheckID
Int ToggleExpResetID

Int HeaderLogoID
Int SliderLogoXID
Int SliderLogoYID
Int MenuLogoModeID
Int KeyDrainCheckID
Int ToggleDrainResetID
Int SliderLogoSizeID

Int HeaderActorHpID
Int SliderActorHp1XID
Int SliderActorHp1YID
Int SliderActorHp2XID
Int SliderActorHp2YID
Int SliderActorHp3XID
Int SliderActorHp3YID
Int SliderActorHp4XID
Int SliderActorHp4YID
Int MenuActorHpModeID
Int KeyActorHpCheckID
Int ToggleActorHpResetID

Int RecordResetSaveID
Int RecordResetAllID

; 記録ページのホバー解説用に各行のIDを保持
Int XpTotalSaveOID
Int LfTotalSaveOID
Int RecTotalXpOID
Int RecTotalLFOID
Int SexCountSaveOID
Int SexCountOID
Int PartnersSaveOID
Int PartnersOID
Int[] RankSaveOIDs
Int[] RankLifeOIDs
Int[] BedRankSaveOIDs
Int[] BedRankLifeOIDs
Int OrgasmCountSaveOID
Int OrgasmCountOID
Int[] ClimaxRankSaveOIDs
Int[] ClimaxRankLifeOIDs
; 総合ランキング（種類別合算）のOID＝ホバー説明用（H／いかせ × セーブ内／生涯）
Int[] GenBedSaveOIDs
Int[] GenBedLifeOIDs
Int[] GenClimaxSaveOIDs
Int[] GenClimaxLifeOIDs

; H技術スキルページ用（ホバーinfo＆プルダウン）
Int TechTotalOID            ; 総合のOID
Int[] TechCatOID            ; 6種目(cat0-5)のOID
Int[] TechSMOID             ; 攻め(6)/受け(7)のOID
Int[] TechActOID            ; 孫54行為(idx0-53)のOID
; 🔮 サーヴァント個別リセット用（サーヴァントシップページの各行クリック→解放）
Int[] svResetOIDs           ; 各行のOID（全ティア通し・OnPageResetで先行確保）
Actor[] svResetActors       ; svResetOIDs[i]に対応するActor
Int svResetN                ; 充填済み件数（今回の描画で積んだ行数）
String[] BarNumDigitsOptions   ; 🔢 バー数字の桁数プルダウン（0=3桁 / 1=2桁）
String[] ProteusBodyOptions    ; 🧬 〔プロテウス〕手動ボディ選択（0=3BA/1=UBE/2=バニラ）
Int TechAggMenuOID          ; 集計方式プルダウン
Int TechOrientMenuOID       ; 指向プルダウン
String[] TechAggOptions     ; 集計方式の選択肢ラベル[3]
String[] TechOrientOptions  ; 指向の選択肢ラベル[3]

; =====================================================================================
; 🎨 カラーヘッダー用のスイッチ
; =====================================================================================
Bool Property HeaderColorToggle = False Auto
; =====================================================================================
; ⚙️ 従来機能：ゲームプレイ・淫紋用のプロパティ
; =====================================================================================

int tattooLeveledMenuOption
Int Property currLeveledTattosIndex = 0 Auto
int enableGlowOption

int flag

String[] cheatLvlMenuArr
string[] progressSpeedArr
string[] leveledTattos
String[] MenuPages
; =================================================================
; 🌟 変数宣言部（追加）
; =================================================================
Int Property fixedChestIndex = 0 Auto
Int Property fixedBackIndex = 0 Auto
Int Property fixedLegacyIndex = 0 Auto
Int Property fixedLegacyMaleIndex = 0 Auto
Int Property fixedLegacySmallIndex = 0 Auto
Int Property fixedMiscIndex = 0 Auto

Int fixedChestOID
Int fixedBackOID
Int fixedLegacyOID
Int fixedLegacyMaleOID
Int fixedLegacySmallOID
Int fixedMiscOID
Int[] MagicOptionIDs
Int[] ProteusActorOIDs           ; 🌊 個体別ボディ＝各行(NPC)のオプションID
Actor[] ProteusActors            ; 🌊 個体別ボディ＝各行に対応するActor(OIDと並行)
String[] ProteusIndivBodyOptions ; 🌊 ドロップダウン候補[自動/3BA/UBE]
Int proteusIndivCount            ; 🌊 個体別リストの現在行数
Int proteusCatFilterOID          ; 🌊 カテゴリ絞込プルダウンのOID
String[] ProteusCatOptions       ; 🌊 絞込候補[全員/一般/ユニーク/カスタム]


String[] Property fixedChestArr Auto
String[] Property fixedBackArr Auto
String[] Property fixedLegacyArr Auto
String[] Property fixedLegacyMaleArr Auto
String[] Property fixedLegacySmallArr Auto
String[] Property fixedMiscArr Auto
String[] MagicDescTags

Bool Property bRandomSelectionEnabled = true Auto

; 💾 オートエクスポート/オートインポート（OStim風・設定をConfig.jsonに自動保存/自動復元）
Bool Property bAutoExport = false Auto
Bool Property bAutoImport = false Auto

; =====================================================================================
; 🚀 イベント：MCMの初期化
; =====================================================================================
; ★MCMページ一覧を組む。OnConfigInitは初回登録時1回だけ＝OnConfigOpenでも呼んで既存セーブに新ページを反映。
Function BuildMenuPages()
    MenuPages = new String[9]
    MenuPages[0] = "$ASTR2_Page_Config"
    MenuPages[1] = "$ASTR2_Page_Ability"
    MenuPages[2] = "$ASTR2_Page_UI_Display"
    MenuPages[3] = "$ASTR2_Page_Tattoo"
    MenuPages[4] = "$ASTR2_Page_Stats"
    MenuPages[5] = "$ASTR2_Page_Servantship"
    MenuPages[6] = "$ASTR2_Page_Skill"
    MenuPages[7] = "$ASTR2_Page_Records"
    MenuPages[8] = "$ASTR2_Page_Integrations"
    Pages = MenuPages
EndFunction

Event OnConfigOpen()
    BuildMenuPages()   ; 既存セーブでも新ページが出るよう毎回ページ配列を組み直す
EndEvent

Event OnConfigInit()
    ModName = "A Succubus Tale R2"
    
    BuildMenuPages()   ; ★ページ配列はBuildMenuPagesに集約（OnConfigOpenでも呼ぶ＝既存セーブで新ページ反映）
    
    DisplayModeOptions = new String[4]
    DisplayModeOptions[0] = "$ASTR2_Mode_Always"   
    DisplayModeOptions[1] = "$ASTR2_Mode_KeySec"   
    DisplayModeOptions[2] = "$ASTR2_Mode_Hide"     
    DisplayModeOptions[3] = "$ASTR2_Mode_Change"

    ; アクターHP専用の3択（Change無し＝C++直更新で変化検知できないため）
    ActorHpModeOptions = new String[3]
    ActorHpModeOptions[0] = "$ASTR2_Mode_Always"
    ActorHpModeOptions[1] = "$ASTR2_Mode_KeySec"
    ActorHpModeOptions[2] = "$ASTR2_Mode_Hide"

    ; H技術プルダウンの選択肢ラベル（$key・SkyUIが翻訳）
    TechAggOptions = new String[3]
    TechAggOptions[0] = "$ASTR2_TechAgg_0"
    TechAggOptions[1] = "$ASTR2_TechAgg_1"
    TechAggOptions[2] = "$ASTR2_TechAgg_2"
    TechOrientOptions = new String[3]
    TechOrientOptions[0] = "$ASTR2_TechOrient_0"
    TechOrientOptions[1] = "$ASTR2_TechOrient_1"
    TechOrientOptions[2] = "$ASTR2_TechOrient_2"

    LogoDisplayModeOptions = new String[5]
    LogoDisplayModeOptions[0] = "$ASTR2_Mode_Always"
    LogoDisplayModeOptions[1] = "$ASTR2_Mode_KeySec"   
    LogoDisplayModeOptions[2] = "$ASTR2_Mode_Hide"     
    LogoDisplayModeOptions[3] = "$ASTR2_Mode_AlwaysSmall" 
    LogoDisplayModeOptions[4] = "$ASTR2_Mode_KeySecSmall" 

    leveledTattos = new string[4]
    leveledTattos[0] = "$ASTR2_Tattoo_Default" 
    leveledTattos[1] = "$ASTR2_Tattoo_Legacy"   
    leveledTattos[2] = "$ASTR2_Tattoo_Chest"
    leveledTattos[3] = "$ASTR2_Tattoo_Back"

    fixedChestArr = new String[7]
    fixedChestArr[0] = "$ASTR2_Tattoo_None"
    fixedChestArr[1] = "$ASTR2_Tattoo_Chest1"
    fixedChestArr[2] = "$ASTR2_Tattoo_Chest2"
    fixedChestArr[3] = "$ASTR2_Tattoo_Chest3"
    fixedChestArr[4] = "$ASTR2_Tattoo_Chest4"
    fixedChestArr[5] = "$ASTR2_Tattoo_Chest5"
    fixedChestArr[6] = "$ASTR2_Tattoo_Chest6"

    fixedBackArr = new String[7]
    fixedBackArr[0] = "$ASTR2_Tattoo_None"
    fixedBackArr[1] = "$ASTR2_Tattoo_Back1"
    fixedBackArr[2] = "$ASTR2_Tattoo_Back2"
    fixedBackArr[3] = "$ASTR2_Tattoo_Back3"
    fixedBackArr[4] = "$ASTR2_Tattoo_Back4"
    fixedBackArr[5] = "$ASTR2_Tattoo_Back5"
    fixedBackArr[6] = "$ASTR2_Tattoo_Back6"

    fixedLegacyArr = new String[7]
    fixedLegacyArr[0] = "$ASTR2_Tattoo_None"
    fixedLegacyArr[1] = "$ASTR2_Tattoo_Legacy1"
    fixedLegacyArr[2] = "$ASTR2_Tattoo_Legacy2"
    fixedLegacyArr[3] = "$ASTR2_Tattoo_Legacy3"
    fixedLegacyArr[4] = "$ASTR2_Tattoo_Legacy4"
    fixedLegacyArr[5] = "$ASTR2_Tattoo_Legacy5"
    fixedLegacyArr[6] = "$ASTR2_Tattoo_Legacy6"

    fixedLegacyMaleArr = new String[7]
    fixedLegacyMaleArr[0] = "$ASTR2_Tattoo_None"
    fixedLegacyMaleArr[1] = "$ASTR2_Tattoo_LegacyMale1"
    fixedLegacyMaleArr[2] = "$ASTR2_Tattoo_LegacyMale2"
    fixedLegacyMaleArr[3] = "$ASTR2_Tattoo_LegacyMale3"
    fixedLegacyMaleArr[4] = "$ASTR2_Tattoo_LegacyMale4"
    fixedLegacyMaleArr[5] = "$ASTR2_Tattoo_LegacyMale5"
    fixedLegacyMaleArr[6] = "$ASTR2_Tattoo_LegacyMale6"

    fixedLegacySmallArr = new String[5]
    fixedLegacySmallArr[0] = "$ASTR2_Tattoo_None"
    fixedLegacySmallArr[1] = "$ASTR2_Tattoo_LegacySmall1"
    fixedLegacySmallArr[2] = "$ASTR2_Tattoo_LegacySmall2"
    fixedLegacySmallArr[3] = "$ASTR2_Tattoo_LegacySmall3"
    fixedLegacySmallArr[4] = "$ASTR2_Tattoo_LegacySmall4"

    fixedMiscArr = new String[5]
    fixedMiscArr[0] = "$ASTR2_Tattoo_None"
    fixedMiscArr[1] = "$ASTR2_Tattoo_MiscHand"
    fixedMiscArr[2] = "$ASTR2_Tattoo_MiscShoulderBoth"
    fixedMiscArr[3] = "$ASTR2_Tattoo_MiscShoulderL"
    fixedMiscArr[4] = "$ASTR2_Tattoo_MiscShoulderR"

    progressSpeedArr = new string[5]
    progressSpeedArr[0] = "$ASTR2_Speed_VeryFast" 
    progressSpeedArr[1] = "$ASTR2_Speed_Fast"      
    progressSpeedArr[2] = "$ASTR2_Speed_Normal"    
    progressSpeedArr[3] = "$ASTR2_Speed_Slow"      
    progressSpeedArr[4] = "$ASTR2_Speed_VerySlow" 

    MagicOptionIDs = new Int[40]   ; ★32→40（シンフル・ネイル7罪追加で拡張）
    MagicDescTags = new String[40]
    
    cheatLvlMenuArr = new String[5]   ; ★B-2=チート残す＝[5]のまま
    cheatLvlMenuArr[0] = "+1"
    cheatLvlMenuArr[1] = "+5"
    cheatLvlMenuArr[2] = "+10"
    cheatLvlMenuArr[3] = "+30"        ; ★B-2=チート残す＝+30も残す（+10の下）
    cheatLvlMenuArr[4] = "100 (MAX)"

    ; 💾 オート設定フラグをConfig.jsonから復元（新ゲームでも前回の自動設定が効くように）。
    ;    オートインポートONなら、そのまま全設定を読み込む。
    bAutoExport = JsonUtil.GetIntValue(GetJsonPath(), "AutoExport", 0) as Bool
    bAutoImport = JsonUtil.GetIntValue(GetJsonPath(), "AutoImport", 0) as Bool
    If bAutoImport
        LoadSettingsFromJson(true)
    EndIf
EndEvent
; =====================================================================================
; 🎨 自動で色を交互に塗ってくれるオシャレなヘッダー関数（真・完全版！）
; =====================================================================================
Int Function AddColoredHeader(String headerText, int flags = 0)
	String colorPurple = "#73bbf7"
	String colorPink = "#ffc5e1"
	String chosenColor
	If HeaderColorToggle
        chosenColor = colorPink
        HeaderColorToggle = False
    Else
        chosenColor = colorPurple
        HeaderColorToggle = True
    EndIf
    
	Return AddHeaderOption("<font color='" + chosenColor +"'>" + headerText + "</font>", flags)
EndFunction

; 記録ページのランキング1行を作る："名前 (吸収量)"。個体が消えてても基底名は取れる。空なら ---。
String Function RankRowText(Form vForm, String storedName, Float amt)
    ; ①記録時に凍結した名前を最優先（敵/雑魚が消えても残る）。②無ければ参照から解決（旧データ移行用）。
    String nm = storedName
    If nm == "" && vForm != None
        Actor a = vForm as Actor
        If a != None
            nm = a.GetDisplayName()
            If nm == "" && a.GetActorBase() != None
                nm = a.GetActorBase().GetName()
            EndIf
        EndIf
        If nm == ""
            nm = vForm.GetName()
        EndIf
    EndIf
    If nm == ""
        Return "$ASTR2_Rec_None"
    EndIf
    Return nm + " (" + (amt as int) + ")"
EndFunction

; =====================================================================================
; 👅 H技術スキルページ：孫(行為)1行のヘルパー
; =====================================================================================
; 孫(行為idx)1行：applicableなら白／非対象はグレーアウト(ホバー不可)。値は実ランク。
Function AddActionRow(Int idx, String labelKey)
    Int f = OPTION_FLAG_NONE
    ; ★覚醒OFF(人間)＝ページ先頭でflag=DISABLED so、行為行もグレーに揃える（GetLvlManager毎回呼び回避でメンバflag読み）
    If !ASTR2Technique.IsActionApplicableAt(idx) || ASTR2Technique.GetActionAnimCount(idx) == 0 || flag == OPTION_FLAG_DISABLED
        f = OPTION_FLAG_DISABLED
    EndIf
    ; 値＝小数ランク"5.45"(整数部=ランク/小数部=次ランクへの進捗%)。OIDはホバー(次ランクまで何秒)用に控える
    TechActOID[idx] = AddTextOption(labelKey, ASTR2Technique.GetActionRankDecimalAt(idx), f)
EndFunction

; =====================================================================================
; 🎨 イベント：右側の画面を描画する（OnPageReset）
; =====================================================================================
Event OnPageReset(string page)
    HeaderColorToggle = False
    ASTLvlManager Lvl = GetLvlManager()
    ASTR2MainScript ASTMain = GetMain()
    ASTTattooScript Tattoo = GetTattoo()
    ASTR2LifeForceBarScript LFBar = GetLFBar()

    ; ★ランキングOID配列を先行確保＝常に非None。`!= None`比較はNoneをInt[]にcastしてログる地雷なので、
    ;   比較で守らず確保で回避する（Papyrusはゼロ長配列不可＝記録ページと同じ new Int[3]。非records時は全要素0＝
    ;   option IDは0にならないので誤マッチ無し。記録ページ描画時に実OIDで入れ直る＝HPバー流・メイン板実証）。
    RankSaveOIDs    = new Int[3]
    RankLifeOIDs    = new Int[3]
    BedRankSaveOIDs = new Int[3]
    BedRankLifeOIDs = new Int[3]
    ClimaxRankSaveOIDs = new Int[3]
    ClimaxRankLifeOIDs = new Int[3]
    GenBedSaveOIDs     = new Int[3]
    GenBedLifeOIDs     = new Int[3]
    GenClimaxSaveOIDs  = new Int[3]
    GenClimaxLifeOIDs  = new Int[3]
    TechCatOID = new Int[6]   ; H技術6種目のOID(ホバー用・先行確保＝!= None比較を避ける)
    TechSMOID  = new Int[2]   ; 攻め/受けのOID
    TechActOID = new Int[54]  ; 孫(個別行為idx0-53)のOID＝ホバーで「次のランクまであとN秒」を出す用
    svResetOIDs   = new Int[128]    ; 🔮 個別リセット行OID＝先行確保(!= None回避)。最大4ティア×cap30=120<128
    svResetActors = new Actor[128]  ; 各OIDに対応するActor（サーヴァント描画時に実値で入る・他ページ時は全None）

    If (page == "")
        LoadCustomContent("ASuccubusTale/Logo.dds", 26, 23)
    Else
        UnloadCustomContent()
        If Lvl.IsSuccubus()
            flag = OPTION_FLAG_NONE
        Else
            flag = OPTION_FLAG_DISABLED
        EndIf
        SetCursorFillMode(TOP_TO_BOTTOM)
    EndIf

    If page == "$ASTR2_Page_Config" || page == "Mod Configuration"
        GameplayOptionsColumn()
        SetCursorPosition(1)
        ToggleMod()
        AddEmptyOption()
        Disadvantages()
        AddEmptyOption()
        Debug()
        AddEmptyOption()

    ElseIf page == "$ASTR2_Page_Ability"
        SetCursorPosition(0)
        AbilityConfigColumn()

    ElseIf page == "$ASTR2_Page_UI_Display"
        If !bActorHpDefInit
            InitActorHpDefaults()
        EndIf

        SetCursorPosition(0)
        ; 🔢 バーに重ねる数字（淫魔力/経験値の両方に効く共通設定・描画はC++／SkyVault直読み）
        AddColoredHeader("$ASTR2_Header_BarNumbers", flag)
        AddToggleOptionST("barNumOnState", "$ASTR2_Option_BarNumbers", SkyVault.GetInt(None, "ASTR2_BarNumOn", 1) == 1, flag)
        Int barDigitsFlag = flag
        If SkyVault.GetInt(None, "ASTR2_BarNumOn", 1) != 1
            barDigitsFlag = OPTION_FLAG_DISABLED   ; 数字OFFなら桁数はいじれない
        EndIf
        ; ★選択肢は毎回ここで確保＝既存セーブ(OnConfigInit未再走)でも空/Noneにならない（H技術プルダウンと同じ流儀）
        BarNumDigitsOptions = new String[2]
        BarNumDigitsOptions[0] = "$ASTR2_BarNumDigits3"
        BarNumDigitsOptions[1] = "$ASTR2_BarNumDigits2"
        Int barDigIdx = 0
        If SkyVault.GetInt(None, "ASTR2_BarNumDigits", 3) == 2
            barDigIdx = 1
        EndIf
        AddMenuOptionST("barNumDigitsState", "$ASTR2_Option_BarNumDigits", BarNumDigitsOptions[barDigIdx], barDigitsFlag)

        HeaderLifeForceID  = AddColoredHeader("$ASTR2_Header_LifeForceBar", flag)
        SliderLifeForceXID = AddSliderOption("$ASTR2_Option_SliderX", LifeForceX, "{0}", flag)
        SliderLifeForceYID = AddSliderOption("$ASTR2_Option_SliderY", LifeForceY, "{0}", flag)
        MenuLifeForceModeID = AddMenuOption("$ASTR2_Option_DisplayMode", DisplayModeOptions[LFDisplayMode], flag)
        KeyLifeForceCheckID = AddKeyMapOption("$ASTR2_Option_CheckKey", LifeForceCheckKey, flag)
        ToggleLifeForceResetID = AddToggleOption("$ASTR2_Option_ResetPosLF", LifeForceKeyResetToggle, flag)

        HeaderExpID        = AddColoredHeader("$ASTR2_Header_Exp", flag)
        SliderExpXID       = AddSliderOption("$ASTR2_Option_SliderX", ExpX, "{0}", flag)
        SliderExpYID       = AddSliderOption("$ASTR2_Option_SliderY", ExpY, "{0}", flag)
        MenuExpModeID      = AddMenuOption("$ASTR2_Option_DisplayMode", DisplayModeOptions[ExpDisplayMode], flag)
        KeyExpCheckID      = AddKeyMapOption("$ASTR2_Option_CheckKey", ExpCheckKey, flag)
        ToggleExpResetID   = AddToggleOption("$ASTR2_Option_ResetPosExp", ExpKeyResetToggle, flag)

        HeaderLogoID  = AddColoredHeader("$ASTR2_Header_Logo", flag)
        SliderLogoXID = AddSliderOption("$ASTR2_Option_SliderX", LogoX, "{0}", flag)
        SliderLogoYID = AddSliderOption("$ASTR2_Option_SliderY", LogoY, "{0}", flag)
        SliderLogoSizeID = AddSliderOption("$ASTR2_Option_SliderSize", LogoSize, "{0}", flag)
        MenuLogoModeID = AddMenuOption("$ASTR2_Option_DisplayMode", LogoDisplayModeOptions[LogoDisplayMode], flag)
        KeyDrainCheckID = AddKeyMapOption("$ASTR2_Option_CheckKey", DrainSwitchKey, flag)
        ToggleDrainResetID = AddToggleOption("$ASTR2_Option_ResetPosDrain", DrainKeyResetToggle, flag)

        SetCursorPosition(1)
        HeaderActorHpID    = AddColoredHeader("$ASTR2_Header_ActorHp", flag)
        SliderActorHp1XID  = AddSliderOption("$ASTR2_Option_SliderBar1X", ActorHpBar1X, "{0}", flag)
        SliderActorHp1YID  = AddSliderOption("$ASTR2_Option_SliderBar1Y", ActorHpBar1Y, "{0}", flag)
        SliderActorHp2XID  = AddSliderOption("$ASTR2_Option_SliderBar2X", ActorHpBar2X, "{0}", flag)
        SliderActorHp2YID  = AddSliderOption("$ASTR2_Option_SliderBar2Y", ActorHpBar2Y, "{0}", flag)
        SliderActorHp3XID  = AddSliderOption("$ASTR2_Option_SliderBar3X", ActorHpBar3X, "{0}", flag)
        SliderActorHp3YID  = AddSliderOption("$ASTR2_Option_SliderBar3Y", ActorHpBar3Y, "{0}", flag)
        SliderActorHp4XID  = AddSliderOption("$ASTR2_Option_SliderBar4X", ActorHpBar4X, "{0}", flag)
        SliderActorHp4YID  = AddSliderOption("$ASTR2_Option_SliderBar4Y", ActorHpBar4Y, "{0}", flag)
        MenuActorHpModeID  = AddMenuOption("$ASTR2_Option_DisplayMode", ActorHpModeOptions[ActorHpDisplayMode], flag)
        KeyActorHpCheckID  = AddKeyMapOption("$ASTR2_Option_CheckKey", ActorHpCheckKey, flag)
        ToggleActorHpResetID = AddToggleOption("$ASTR2_Option_ResetPosActorHp", ActorHpKeyResetToggle, flag)

        ; 💫 H技術HUD（H中に育ってる行為を1行ずつ表示・描画は魅了板C++／位置と色はC++側that持ち）
        AddColoredHeader("$ASTR2_Header_TechHud", flag)
        AddToggleOptionST("techHudState", "$ASTR2_Option_TechHud", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1) == 1, flag)
        AddSliderOptionST("techHudYState",    "$ASTR2_Option_TechHudY",    StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380) as Float,   "{0}", flag)
        AddSliderOptionST("techHudXState",    "$ASTR2_Option_TechHudX",    StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30) as Float,    "{0}", flag)
        AddSliderOptionST("techHudStepState", "$ASTR2_Option_TechHudStep", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40) as Float, "{0}", flag)
        AddToggleOptionST("techHudResetState", "$ASTR2_Option_ResetPosTechHud", false, flag)   ; 押すと縦/横/行間を既定へ＝他バーの「位置リセット」と同じ流儀

        ; 💔 寵愛警告HUD（生者ヴァッサルの寵愛切れセリフ・描画はメイン板C++／位置はSkyVault直読み・テスト表示で位置合わせ）
        AddColoredHeader("$ASTR2_Header_VLoveHud", flag)
        AddToggleOptionST("vloveHudOnState",    "$ASTR2_Option_VLoveHudOn",   SkyVault.GetInt(None, "ASTR2_VLoveHudOn", 1) == 1, flag)
        AddSliderOptionST("vloveHudYState",     "$ASTR2_Option_VLoveHudY",    SkyVault.GetInt(None, "ASTR2_VLoveHudY", 380) as Float,   "{0}", flag)
        AddSliderOptionST("vloveHudXState",     "$ASTR2_Option_VLoveHudX",    SkyVault.GetInt(None, "ASTR2_VLoveHudX", 30) as Float,    "{0}", flag)
        AddSliderOptionST("vloveHudStepState",  "$ASTR2_Option_VLoveHudStep", SkyVault.GetInt(None, "ASTR2_VLoveHudStep", 40) as Float, "{0}", flag)
        AddTextOptionST("vloveHudResetState",   "$ASTR2_Option_VLoveHudReset", "$ASTR2_Btn_Execute", flag)

        ElseIf page == "$ASTR2_Page_Tattoo" || page == "Tattoo"
        AddColoredHeader("$ASTR2_Header_Tattoo", flag)
        AddToggleOptionST("TattooToggleState", "$ASTR2_Option_ApplyTattoo", ASTMain.usesTatoo, flag)
        ; 🟣 NPC淫紋マスタースイッチ（サキュバス・ウィークネス/スイート・ヴァッサルの効果中に相手NPCへ淫紋表示・ASTTattooScriptが内部で読む）
        AddToggleOptionST("NpcSigilState", "$ASTR2_Option_NpcSigil", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1) == 1, flag)

        int previousFlag = flag
        if !ASTMain.usesTatoo
            flag = OPTION_FLAG_DISABLED
        EndIf

        AddColoredHeader("$ASTR2_Header_TattooConfig", flag)
        
        int typeFlag = flag
        If Tattoo.fixedTattoo
            typeFlag = OPTION_FLAG_DISABLED
        EndIf
        tattooLeveledMenuOption = AddMenuOption("$ASTR2_Option_TattooType", leveledTattos[currLeveledTattosIndex], typeFlag)
        enableGlowOption = AddToggleOption("$ASTR2_Option_GlowEffect", Tattoo.enableGlow, flag)
        AddEmptyOption()
        AddToggleOptionST("FixedTattooState", "$ASTR2_Option_FixedTattoo", Tattoo.fixedTattoo, flag)
        int fixedFlag = flag
        If !Tattoo.fixedTattoo
            fixedFlag = OPTION_FLAG_DISABLED
        EndIf

        fixedChestOID = AddMenuOption("$ASTR2_Option_FixedChest", fixedChestArr[fixedChestIndex], fixedFlag)
        fixedBackOID = AddMenuOption("$ASTR2_Option_FixedBack", fixedBackArr[fixedBackIndex], fixedFlag)
        fixedLegacyOID = AddMenuOption("$ASTR2_Option_FixedLegacy", fixedLegacyArr[fixedLegacyIndex], fixedFlag)
        fixedLegacyMaleOID = AddMenuOption("$ASTR2_Option_FixedLegacyMale", fixedLegacyMaleArr[fixedLegacyMaleIndex], fixedFlag)
        fixedLegacySmallOID = AddMenuOption("$ASTR2_Option_FixedLegacySmall", fixedLegacySmallArr[fixedLegacySmallIndex], fixedFlag)
        fixedMiscOID = AddMenuOption("$ASTR2_Option_FixedMisc", fixedMiscArr[fixedMiscIndex], fixedFlag)
        flag = previousFlag

        ; ━━ プロテウス＝タトゥーページ右列。左＝既存タトゥーは据え置き ━━
        ; ここはプレイヤーぶん＋全体master。一般NPC/ユニーク/カスタムの個別＋OFF分岐は後続ステップ（ボディ検出データ待ち）。
        ProteusBodyOptions = new String[3]
        ProteusBodyOptions[0] = "$ASTR2_Body_3BA"
        ProteusBodyOptions[1] = "$ASTR2_Body_UBE"
        ProteusBodyOptions[2] = "$ASTR2_Body_Vanilla"
        SetCursorPosition(1)
        Int proteusOn = SkyVault.GetInt(None, "ASTR2_ProteusOn", 1)
        Int bodyAuto = SkyVault.GetInt(None, "ASTR2_BodyAutoDetect", 1)
        Int proteusSubFlag = flag              ; プレイヤー節＝全体OFFでグレー
        If proteusOn == 0
            proteusSubFlag = OPTION_FLAG_DISABLED
        EndIf
        Int bodyManualFlag = proteusSubFlag    ; 手動＝全体ON かつ 自動OFF の時だけ有効（自動OFFで手動を有効にする）
        If bodyAuto == 1
            bodyManualFlag = OPTION_FLAG_DISABLED
        EndIf
        AddColoredHeader("$ASTR2_Header_Proteus", flag)
        AddToggleOptionST("proteusOnState", "$ASTR2_Option_ProteusOn", proteusOn == 1, flag)
        AddTextOptionST("bodyRedetectState", "$ASTR2_Option_BodyRedetect", "", proteusSubFlag)   ; 🌊 ボディ判定キャッシュ全消去→次回再判定（全体ONの時だけ有効にする）
        AddColoredHeader("$ASTR2_Header_ProteusPlayer", proteusSubFlag)
        AddToggleOptionST("bodyAutoDetectState", "$ASTR2_Option_BodyAutoDetect", bodyAuto == 1, proteusSubFlag)
        Int proteusCurBody = ASTR2Native.SigilGetBodyType()
        If proteusCurBody < 0 || proteusCurBody > 2
            proteusCurBody = 0
        EndIf
        AddTextOption("$ASTR2_Text_CurrentBody", ProteusBodyOptions[proteusCurBody], proteusSubFlag)
        AddMenuOptionST("bodyManualState", "$ASTR2_Option_BodyManual", ProteusBodyOptions[SkyVault.GetInt(None, "ASTR2_BodyManual", 0)], bodyManualFlag)
        ; 🌊 個体別ボディ＝淫紋を付けたNPCを1行ずつ・名前＋ドロップダウン(自動/3BA/UBE/除外)する。カテゴリで絞込可能です。
        ProteusIndivBodyOptions = new String[4]
        ProteusIndivBodyOptions[0] = "$ASTR2_Body_Auto"
        ProteusIndivBodyOptions[1] = "$ASTR2_Body_3BA"
        ProteusIndivBodyOptions[2] = "$ASTR2_Body_UBE"
        ProteusIndivBodyOptions[3] = "$ASTR2_Body_Exclude"   ; 🌊 再検出まで一覧から除外する。
        ProteusActorOIDs = new Int[128]
        ProteusActors = new Actor[128]
        AddColoredHeader("$ASTR2_Header_ProteusIndiv", proteusSubFlag)
        ; 🌊 表示カテゴリ絞込プルダウン(0=全員/1=一般/2=ユニーク/3=カスタム)＝SigilGetActorCategory(0一般/1ユニーク/2カスタム)で絞ります。
        ProteusCatOptions = new String[5]
        ProteusCatOptions[0] = "$ASTR2_Cat_All"
        ProteusCatOptions[1] = "$ASTR2_Cat_Common"
        ProteusCatOptions[2] = "$ASTR2_Cat_Unique"
        ProteusCatOptions[3] = "$ASTR2_Cat_Custom"
        ProteusCatOptions[4] = "$ASTR2_Cat_NonCommon"   ; 🌊 一般以外＝ユニーク＋カスタム複合のことです。
        Int catFilter = SkyVault.GetInt(None, "ASTR2_ProteusCatFilter", 0)
        proteusCatFilterOID = AddMenuOption("$ASTR2_Option_ProteusCatFilter", ProteusCatOptions[catFilter], proteusSubFlag)
        Int sigTotal = SkyVault.ListCount(None, "ASTR2_SigilUsedActors")
        Int sigI = 0
        Int sigShown = 0
        While sigI < sigTotal && sigShown < 128
            Actor sigAct = SkyVault.ListGet(None, "ASTR2_SigilUsedActors", sigI) as Actor
            Int sigCat = -1
            If sigAct != None
                sigCat = ASTR2Native.SigilGetActorCategory(sigAct)   ; 0一般/1ユニーク/2カスタム
            EndIf
            Bool sigPass = false                              ; カテゴリ絞込
            If catFilter == 0                                 ; 全員
                sigPass = true
            ElseIf catFilter == 4                             ; 一般以外(ユニーク+カスタム)
                sigPass = (sigCat == 1) || (sigCat == 2)
            Else                                              ; 一般/ユニーク/カスタム
                sigPass = (sigCat == (catFilter - 1))
            EndIf
            If sigAct != None && sigAct != Game.GetPlayer() && sigPass
                Int sigBt = ASTR2Native.SigilGetManualBt(sigAct)   ; -1自動/0=3BA/1=UBE/2=バニラ
                Int sigIdx = 0                                      ; -1(自動)や2(バニラ)/その他→自動
                If sigBt == 0
                    sigIdx = 1                                      ; 3BA
                ElseIf sigBt == 1
                    sigIdx = 2                                      ; UBE
                EndIf
                Int sigEff = ASTR2Native.SigilGetEffectiveBt(sigAct)   ; 実効ボディ(手動優先→自動検出・0=3BA/1=UBE/-1=非人型・バニラは3BAに倒す)
                String sigBodyLbl = ASTR2Native.LocFmtF("$ASTR2_Body_NonHuman", 0.0)
                If sigEff == 0
                    sigBodyLbl = ASTR2Native.LocFmtF("$ASTR2_Body_3BA", 0.0)
                ElseIf sigEff == 1
                    sigBodyLbl = ASTR2Native.LocFmtF("$ASTR2_Body_UBE", 0.0)
                EndIf
                ProteusActorOIDs[sigShown] = AddMenuOption("<font color='#ffc5e1'>" + sigAct.GetDisplayName() + " (" + sigBodyLbl + ")</font>", ProteusIndivBodyOptions[sigIdx], proteusSubFlag)   ; 🌊 名前 (実効ボディ)・ピンクで目立たせ
                ProteusActors[sigShown] = sigAct
                sigShown += 1
            EndIf
            sigI += 1
        EndWhile
        proteusIndivCount = sigShown
        If sigShown == 0
            AddTextOption("$ASTR2_Text_ProteusIndivNone", "", OPTION_FLAG_DISABLED)
        EndIf

        ElseIf page == "$ASTR2_Page_Stats" || page == "Stats"
        int currentLvl = Lvl.SuccubusLvl.GetValueInt()
        ; =========================================================
        ; 🌟 1. 左側：サキュバスレベル
        ; =========================================================
        SetCursorPosition(0) ; 左列の先頭からスタート！
        AddColoredHeader("$ASTR2_Header_SuccubusLvl", flag)
        
        If currentLvl >= 100
            AddTextOptionST("NothingState", "$ASTR2_Text_LvlMaxST", "<font color='#ffc5e1'>100</font>", 0)
        Else
            string LvlText = Lvl.SuccubusLvl.GetValueInt()
            AddTextOption("$ASTR2_Text_Lvl", currentLvl as string , flag)
        EndIf

        ; =========================================================
        ; 🌟 2. 左側：習得済み魔法リスト（そのまま下にかきつづけます）
        ; =========================================================
        AddColoredHeader("$ASTR2_Header_LearnedAbilities", flag)

        Actor Player = Game.GetPlayer()
        Spell[] displaySpells = new Spell[18]
        displaySpells[0]  = Game.GetFormFromFile(0x0101C7B1, "A Succubus Tale R2.esp") as Spell   ; サーヴァント・シンク Servant Sync（システム機能＝最上段／Lvプロパティ無し）
        displaySpells[1]  = Lvl.DrainSpellLevels[1]
        displaySpells[2]  = Lvl.SeductionFFAimed
        displaySpells[3]  = Game.GetFormFromFile(0x01BCE2, "A Succubus Tale R2.esp") as Spell     ; クリエイト・シャード Create Shard（Lvプロパティ無し）
        displaySpells[4]  = Lvl.Lust
        displaySpells[5]  = Game.GetFormFromFile(0x01BCE9, "A Succubus Tale R2.esp") as Spell     ; ナイトメア・エンブレイス Nightmare Embrace（Lvプロパティ無し）
        displaySpells[6]  = Lvl.reanimate   ; 🧟 スイート・ヴァッサル Sweet Vassal（Lv2習得・コスト=SkyVault ASTR2_ReanimCost）
        displaySpells[7]  = Game.GetFormFromFile(0x01D7EA, "A Succubus Tale R2.esp") as Spell     ; 🍯 ディスティル・エッセンス Distill Essence（Lv2習得・Lvプロパティ無し）
        displaySpells[8]  = Game.GetFormFromFile(0x01D7F1, "A Succubus Tale R2.esp") as Spell     ; 🍬 エンバー・エッセンス Ember Essence（Lv2習得・火種の残数アビリティ）
        displaySpells[9]  = Lvl.ConsumeLifeForce
        displaySpells[10] = Game.GetFormFromFile(0x00B4AA, "A Succubus Tale R2.esp") as Spell   ; 🔥 アンリーシュド・フューリー Fury（Lv4習得・旧SucPowerプロパティ→FormID直参照）
        displaySpells[11] = Lvl.command
        displaySpells[12] = Lvl.SeductionArea
        displaySpells[13] = Lvl.SuccubusWeakness
        displaySpells[14] = Lvl.MassSeductionFFSelf
        displaySpells[15] = Game.GetFormFromFile(0x01ED82, "A Succubus Tale R2.esp") as Spell   ; 💋 リヴァイヴィング・グレイス Reviving Grace（Lv9習得・生者化）
        displaySpells[16] = Game.GetFormFromFile(0x02087E, "A Succubus Tale R2.esp") as Spell   ; 💧 エッセンス・フロウ Essence Flow（Lv9習得・上位回復・コンスーム・エッセンスの上位／同Lvタイブレーク暫定）
        displaySpells[17] = Game.GetFormFromFile(0x020881, "A Succubus Tale R2.esp") as Spell   ; 🩸 ラヴェナス・ドレイン Ravenous Drain（Lv10習得・範囲ドレイン）

        String[] nameTags = new String[18]
        nameTags[0]  = "$ASTR2_Spell_ServantSync"
        nameTags[1]  = "$ASTR2_Spell_Drain"
        nameTags[2]  = "$ASTR2_Spell_Seduction"
        nameTags[3]  = "$ASTR2_Spell_Shard"
        nameTags[4]  = "$ASTR2_Spell_Lust"
        nameTags[5]  = "$ASTR2_Spell_Nightmare"
        nameTags[6]  = "$ASTR2_Spell_Reanim"
        nameTags[7]  = "$ASTR2_Spell_Distill"
        nameTags[8]  = "$ASTR2_Spell_Ember"
        nameTags[9]  = "$ASTR2_Spell_Consume"
        nameTags[10] = "$ASTR2_Spell_Power"
        nameTags[11] = "$ASTR2_Spell_Command"
        nameTags[12] = "$ASTR2_Spell_Area"
        nameTags[13] = "$ASTR2_Spell_Weakness"
        nameTags[14] = "$ASTR2_Spell_Mass"
        nameTags[15] = "$ASTR2_Spell_Reviving"
        nameTags[16] = "$ASTR2_Spell_Flow"
        nameTags[17] = "$ASTR2_Spell_Ravenous"

        String[] descTags = new String[18]
        descTags[0]  = "$ASTR2_Desc_ServantSync"
        descTags[1]  = "$ASTR2_Desc_Drain"
        descTags[2]  = "$ASTR2_Desc_Seduction"
        descTags[3]  = "$ASTR2_Desc_Shard"
        descTags[4]  = "$ASTR2_Desc_Lust"
        descTags[5]  = "$ASTR2_Desc_Nightmare"
        descTags[6]  = "$ASTR2_Desc_Reanim"
        descTags[7]  = "$ASTR2_Desc_Distill"
        descTags[8]  = "$ASTR2_Desc_Ember"
        descTags[9]  = "$ASTR2_Desc_Consume"
        descTags[10] = "$ASTR2_Desc_Power"
        descTags[11] = "$ASTR2_Desc_Command"
        descTags[12] = "$ASTR2_Desc_Area"
        descTags[13] = "$ASTR2_Desc_Weakness"
        descTags[14] = "$ASTR2_Desc_Mass"
        descTags[15] = "$ASTR2_Desc_Reviving"
        descTags[16] = "$ASTR2_Desc_Flow"
        descTags[17] = "$ASTR2_Desc_Ravenous"

        String[] learnedTags = new String[18]
        learnedTags[0]  = "$ASTR2_Learned_ServantSync"
        learnedTags[1]  = "$ASTR2_Learned_Drain"
        learnedTags[2]  = "$ASTR2_Learned_Seduction"
        learnedTags[3]  = "$ASTR2_Learned_Shard"
        learnedTags[4]  = "$ASTR2_Learned_Lust"
        learnedTags[5]  = "$ASTR2_Learned_Nightmare"
        learnedTags[6]  = "$ASTR2_Learned_Reanim"
        learnedTags[7]  = "$ASTR2_Learned_Distill"
        learnedTags[8]  = "$ASTR2_Learned_Ember"
        learnedTags[9]  = "$ASTR2_Learned_Consume"
        learnedTags[10] = "$ASTR2_Learned_Power"
        learnedTags[11] = "$ASTR2_Learned_Command"
        learnedTags[12] = "$ASTR2_Learned_Area"
        learnedTags[13] = "$ASTR2_Learned_Weakness"
        learnedTags[14] = "$ASTR2_Learned_Mass"
        learnedTags[15] = "$ASTR2_Learned_Reviving"
        learnedTags[16] = "$ASTR2_Learned_Flow"
        learnedTags[17] = "$ASTR2_Learned_Ravenous"

        int i = 0
        int validCount = 0
        While i < displaySpells.Length
            If displaySpells[i] != None && Player.HasSpell(displaySpells[i])
                ; プレイヤーが持っている魔法だけ表示し、ID・用途ラベル・説明文タグを記憶する
                MagicOptionIDs[validCount] = AddTextOption(nameTags[i], learnedTags[i], flag)
                MagicDescTags[validCount] = descTags[i]
                validCount += 1
            EndIf
            i += 1
        EndWhile

        ; 🧟 スイート・ヴァッサルの死霊一覧＝スイート・ヴァッサル習得後だけ・アビリティ一覧の直下(右列)。使役中を1体1行・GetActiveVassalStatusText流用
        If Player.HasSpell(Lvl.reanimate)
            AddColoredHeader("$ASTR2_Header_SweetVassalList", flag)
            String vlist = ASTConjCost.GetActiveVassalStatusText()
            If vlist == ""
                AddTextOption("$ASTR2_Text_VassalListNone", "", OPTION_FLAG_DISABLED)
            Else
                String[] vrows = StringUtil.Split(vlist, "\n")
                Int vi = 0
                While vi < vrows.Length
                    AddTextOption(vrows[vi], "", OPTION_FLAG_DISABLED)
                    vi += 1
                EndWhile
            EndIf
        EndIf

        ; =========================================================
        ; 🌟 3. 左側：サキュバスの経験値とレベル
        ; =========================================================
        SetCursorPosition(1) ; 左列の先頭からスタートします
        
        AddColoredHeader("$ASTR2_Header_SuccubusStats", flag)
        
        int currentXp = Lvl.CurrXp as int
        int reqXp = Lvl.XpRequired as int
        int xpPercent = 0
        If reqXp > 0
            xpPercent = ((Lvl.CurrXp / Lvl.XpRequired) * 100.0) as int
        EndIf
        
        If Lvl.SuccubusLvl.GetValueInt() >= 100
            ; 1行目（元のEXP枠）
            AddTextOption("$ASTR2_Text_Legend1", "$ASTR2_Text_Legend2")
            ; 2行目（新しく出現する隠し枠）
            AddTextOption( "$ASTR2_Text_Legend3", "$ASTR2_Text_Legend4")
        Else
            string xpText = xpPercent + "% (" + currentXp + "/" + reqXp + ")"
            AddTextOption("$ASTR2_Text_NextLvl", xpText, flag)
        EndIf
        ; 経験値トータル(セーブ内)＝このセーブで稼いだ累計（生涯ぶんは記録ページ）
        XpTotalSaveOID = AddTextOption("$ASTR2_Text_XpTotalSave", (Lvl.SaveXpTotal as int) as string, flag)
        ; =========================================================
        ; 🌟 4. 右側：ライフフォース
        ; =========================================================
        AddColoredHeader("$ASTR2_Header_LifeForceStats", flag)
        
        int currentLF = LFBar.LFenergyCurr
        int maxLF = LFBar.LFenergyMax
        int lfPercent = 0
        If maxLF > 0
            lfPercent = (((currentLF as float) / (maxLF as float)) * 100.0) as int
        EndIf
        
        string lfText = lfPercent + "% (" + currentLF + "/" + maxLF + ")"
        AddTextOption("$ASTR2_Text_CurrentLF", lfText, flag)
        ; ライフフォーストータル(セーブ内)＝このセーブで吸った累計（生涯ぶんは記録ページ）
        LfTotalSaveOID = AddTextOption("$ASTR2_Text_LfTotalSave", (Lvl.SaveLfTotal as int) as string, flag)

        ; =========================================================
        ; 🌟 5. 右側：バフ一覧（常時=現在値直読み／LF・H連動=説明）
        ;    ホバー解説は既存の MagicOptionIDs/MagicDescTags 配列に相乗り
        ;    （OnOptionHighlightのループが自動でinfo表示＝色付き行はSetInfoHtml／プレーン行はSetInfoText）。
        ; =========================================================
        ; --- 常時バフ：Lv連動ステータス（サキュバスソウル刷新＝ASTLvlManagerのgetterがスクリプト管理／未解放Lvは0返し） ---
        AddColoredHeader("$ASTR2_Header_BuffPassive", flag)
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_MaxMagicka", "+" + Lvl.GetMagMaxBonus(), flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffMaxMagicka"
        validCount += 1
        Int buffMagR = Lvl.GetMagRateBonus()   ; 再生3種は未解放(getter0)なら「Lv◯で解放」・解放後は「+N%」
        String buffMagRv = "+" + buffMagR + "%"
        If buffMagR == 0
            buffMagRv = ASTR2Native.LocFmtF("$ASTR2_Buff_LockedAt", 3.0)
        EndIf
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_MagickaRate", buffMagRv, flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffMagickaRate"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_MaxHealth", "+" + Lvl.GetHpMaxBonus(), flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffMaxHealth"
        validCount += 1
        Int buffHpR = Lvl.GetHpRateBonus()
        String buffHpRv = "+" + buffHpR + "%"
        If buffHpR == 0
            buffHpRv = ASTR2Native.LocFmtF("$ASTR2_Buff_LockedAt", 5.0)
        EndIf
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_HealthRate", buffHpRv, flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffHealthRate"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_MaxStamina", "+" + Lvl.GetStamMaxBonus(), flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffMaxStamina"
        validCount += 1
        Int buffStR = Lvl.GetStamRateBonus()
        String buffStRv = "+" + buffStR + "%"
        If buffStR == 0
            buffStRv = ASTR2Native.LocFmtF("$ASTR2_Buff_LockedAt", 7.0)
        EndIf
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_StaminaRate", buffStRv, flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffStaminaRate"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_Speech", "+" + Lvl.GetSpeechBonus(), flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffSpeech"
        validCount += 1
        Int xpBonus = Lvl.GetSkillXpBonusSoul()   ; ★恒久分だけ（Lv10解放10%＋極大の淫魔晶/1万・上限100%）＝合算のGetSkillXpBonusだとオーガズムバフ中に跳ねる
        String xpBonusVal = "+" + xpBonus + "%"
        If xpBonus == 0
            xpBonusVal = ASTR2Native.LocFmtF("$ASTR2_Buff_LockedAt", 10.0)
        EndIf
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_SkillXp", xpBonusVal, flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffSkillXp"
        validCount += 1

        ; --- 現在適応中のLFバフ：ApplyRegenBuffs と同じ式で実効値を出します（基準%×LF係数＝表示と実挙動を1:1に） ---
        AddColoredHeader("$ASTR2_Header_BuffLFNow", flag)
        Int regenBase = Lvl.GetMagRateBonus()   ; 再生3種の基準は共通(=Lv)・未解放は0so解放済みの値を拾います
        If Lvl.GetHpRateBonus() > regenBase
            regenBase = Lvl.GetHpRateBonus()
        EndIf
        If Lvl.GetStamRateBonus() > regenBase
            regenBase = Lvl.GetStamRateBonus()
        EndIf
        String lfNowVal
        If !ASTMain.AreDisadvantagesEnabled
            lfNowVal = "$ASTR2_BuffVal_LFOff"
        ElseIf regenBase == 0
            lfNowVal = ASTR2Native.LocFmtF("$ASTR2_Buff_LockedAt", 3.0)   ; 再生が全部未解放になります（Lv3未満）
        Else
            lfNowVal = ASTR2Native.LocFmtF("$ASTR2_BuffVal_LFEff", (regenBase * Lvl.LFRegenFactor()))
        EndIf
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_LFNow", lfNowVal, flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffLFNow"
        validCount += 1

        ; --- H連動系バフ ---
        AddColoredHeader("$ASTR2_Header_BuffHsex", flag)
        MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_HSex", "$ASTR2_BuffVal_HSex", flag)
        MagicDescTags[validCount] = "$ASTR2_Desc_BuffHSex"
        validCount += 1
        ; オーガズムバフはLv連動で実数表示です。バフ中は残り時間つき／切れてる時は「なし（発動時の値）」と表示されます。
        Int orgLeftSec = Lvl.GetOrgasmBuffLeftSec()   ; 0＝今かかっていない状態です（効果インスタンス直読み）
        Float[] orgRowVals
        If orgLeftSec > 0
            ; バフ中＝1行だと右端が見切れるので「強化」「経験値」の2行に分けるます（ホバーは2行とも同じ3段です）
            Int orgLeftMin = (orgLeftSec + 59) / 60   ; 分は切り上げ＝残り数秒でも「残り1分」表示です。
            orgRowVals = new Float[2]
            orgRowVals[0] = Lvl.GetOrgasmStatBonus() as Float
            orgRowVals[1] = orgLeftMin as Float
            MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_Orgasm", ASTR2Native.LocFmt("$ASTR2_BuffVal_OrgasmOn", orgRowVals), flag)
            MagicDescTags[validCount] = "$ASTR2_Desc_BuffOrgasm"
            validCount += 1
            orgRowVals = new Float[2]
            orgRowVals[0] = Lvl.GetOrgasmXpPct() as Float
            orgRowVals[1] = orgLeftMin as Float
            MagicOptionIDs[validCount] = AddTextOption("", ASTR2Native.LocFmt("$ASTR2_BuffVal_OrgasmXpOn", orgRowVals), flag)   ; 2行目はラベル無しです＝上の行の続きになります
            MagicDescTags[validCount] = "$ASTR2_Desc_BuffOrgasm"
            validCount += 1
        Else
            orgRowVals = new Float[2]
            orgRowVals[0] = Lvl.GetOrgasmStatBonus() as Float
            orgRowVals[1] = (Lvl.GetOrgasmDurSec() / 60) as Float
            MagicOptionIDs[validCount] = AddTextOption("$ASTR2_Buff_Orgasm", ASTR2Native.LocFmt("$ASTR2_BuffVal_Orgasm", orgRowVals), flag)
            MagicDescTags[validCount] = "$ASTR2_Desc_BuffOrgasm"
            validCount += 1
        EndIf

        ; =========================================================
        ; 🌸 シンフル・ブレッシング＝シンフル・ネイル7罪の実数一覧（実験用）
        ;   装備した爪(シンフル・ネイル)のカテゴリ(吸/H/殺)で習得済み罪が発揮されます。右＝未収得(グレー)/発動中(現在値)/未発動。装備は1個想定(スロット61)
        ; =========================================================
        AddColoredHeader("$ASTR2_Header_SinBless", flag)
        ; 🖐 装備ネイル（1行・ピンクラベル）｜右＝装備中の爪名／未装備（1個想定so最初に見つけた1本）
        String equippedNailName = ASTR2Native.LocFmtF("$ASTR2_Nail_NotEquipped", 0.0)
        Int ni = 0
        While ni < 7
            Armor nnail = Game.GetFormFromFile(0x020886 + ni, "A Succubus Tale R2.esp") as Armor
            If nnail && Game.GetPlayer().IsEquipped(nnail)
                equippedNailName = nnail.GetName()
            EndIf
            ni += 1
        EndWhile
        AddTextOption("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Nail_EquipLabel", 0.0) + "</font>", equippedNailName, flag)
        ; 🩸 吸いたい
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Greed", "$ASTR2_NailUnk_Greed", 6, "#73bbf7"), NailVal(6, "+" + (ASTR2NailManager.GetGreedPct() as Int) + "%", "#73bbf7"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Greed"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Gula", "$ASTR2_NailUnk_Gula", 3, "#73bbf7"), NailVal(3, "+" + ASTR2Native.Fmt1(ASTR2NailManager.GetGulaPct()) + "%", "#73bbf7"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Gula"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Acedia", "$ASTR2_NailUnk_Acedia", 4, "#73bbf7"), NailVal(4, "+" + (ASTR2NailManager.GetLazySpeedPctNow() as Int) + "%", "#73bbf7"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Acedia"
        validCount += 1
        ; 💋 Hしたい
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Lust", "$ASTR2_NailUnk_Lust", 2, "#ffc5e1"), NailVal(2, "+" + ASTR2Native.Fmt1(ASTR2NailManager.GetLustPctNow()) + "% /+" + ASTR2NailManager.GetLustSedBudget(), "#ffc5e1"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Lust"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Pride", "$ASTR2_NailUnk_Pride", 1, "#ffc5e1"), NailVal(1, "+" + (ASTR2NailManager.GetPrideSpeechPct() as Int) + "% /+" + (ASTR2NailManager.GetPrideTechPct() as Int) + "%", "#ffc5e1"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Pride"
        validCount += 1
        ; 🔪 殺したい
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Wrath", "$ASTR2_NailUnk_Wrath", 0, "#c58fff"), NailVal(0, "+" + (ASTR2NailManager.GetWrathDmgPctNow() as Int) + "%", "#c58fff"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Wrath"
        validCount += 1
        MagicOptionIDs[validCount] = AddTextOption(NailLabel("$ASTR2_Nail_Envy", "$ASTR2_NailUnk_Envy", 5, "#c58fff"), NailVal(5, "+" + ASTR2NailManager.GetEnvyBonusNow(), "#c58fff"), flag)
        MagicDescTags[validCount] = "$ASTR2_NailInfo_Envy"
        validCount += 1

    ; =====================================================================================
    ; 🏆 記録ページ（全項目 セーブ内／生涯 の2本立て。生涯ぶんはJSONで永続）
    ; =====================================================================================
    ElseIf page == "$ASTR2_Page_Records" || page == "Records"
        String recFile = "ASuccubusTaleR2/Records"
        Actor recPC = Game.GetPlayer()

        ; --- 左列：累計の戦果 ---
        SetCursorPosition(0)
        AddColoredHeader("$ASTR2_Header_Records", flag)

        RecTotalXpOID = AddTextOption("$ASTR2_Rec_TotalXp", (JsonUtil.GetFloatValue(recFile, "total_xp") as int) as string, flag)
        RecTotalLFOID = AddTextOption("$ASTR2_Rec_TotalLF", (JsonUtil.GetFloatValue(recFile, "lf_absorbed") as int) as string, flag)

        SexCountSaveOID = AddTextOption("$ASTR2_Rec_SexCountSave", Lvl.SaveSexCount as string, flag)
        SexCountOID = AddTextOption("$ASTR2_Rec_SexCount", JsonUtil.GetIntValue(recFile, "sex_count") as string, flag)

        PartnersSaveOID = AddTextOption("$ASTR2_Rec_PartnersSave", StorageUtil.FormListCount(recPC, "ASTR2_PartnersSave") as string, flag)
        PartnersOID = AddTextOption("$ASTR2_Rec_Partners", JsonUtil.FormListCount(recFile, "partners") as string, flag)

        OrgasmCountSaveOID = AddTextOption("$ASTR2_Rec_OrgasmCountSave", Lvl.SaveOrgasmCount as string, flag)
        OrgasmCountOID = AddTextOption("$ASTR2_Rec_OrgasmCount", JsonUtil.GetIntValue(recFile, "orgasm_count") as string, flag)

        ; --- 左列つづき：一番Hした相手 TOP3（H回数の多い順・セーブ内／生涯） ---
        AddColoredHeader("$ASTR2_Header_TopBedPartner", flag)
        AddColoredHeader("$ASTR2_Rec_RankSave", flag)
        BedRankSaveOIDs = new Int[3]
        int bi = 0
        While bi < 3
            String bRowS = "$ASTR2_Rec_None"
            If bi < StorageUtil.FormListCount(recPC, "ASTR2_BedRankForms")
                Form bvfS = StorageUtil.FormListGet(recPC, "ASTR2_BedRankForms", bi)
                Float bamS = StorageUtil.FloatListGet(recPC, "ASTR2_BedRankAmts", bi)
                bRowS = RankRowText(bvfS, StorageUtil.StringListGet(recPC, "ASTR2_BedRankNames", bi), bamS)
            EndIf
            BedRankSaveOIDs[bi] = AddTextOption("#" + (bi + 1), bRowS, flag)
            bi += 1
        EndWhile

        AddColoredHeader("$ASTR2_Rec_RankLifetime", flag)
        BedRankLifeOIDs = new Int[3]
        bi = 0
        While bi < 3
            String bRowL = "$ASTR2_Rec_None"
            If bi < JsonUtil.FormListCount(recFile, "bedrank_forms")
                Form bvfL = JsonUtil.FormListGet(recFile, "bedrank_forms", bi)
                Float bamL = JsonUtil.FloatListGet(recFile, "bedrank_amts", bi)
                bRowL = RankRowText(bvfL, JsonUtil.StringListGet(recFile, "bedrank_names", bi), bamL)
            EndIf
            BedRankLifeOIDs[bi] = AddTextOption("#" + (bi + 1), bRowL, flag)
            bi += 1
        EndWhile

        ; --- 左列つづき：Hランキング総合（汎用NPCを種類名で合算・セーブ内／生涯） ---
        AddColoredHeader("$ASTR2_Header_TopBedGen", flag)
        AddColoredHeader("$ASTR2_Rec_RankSave", flag)
        GenBedSaveOIDs = new Int[3]
        int gbi = 0
        While gbi < 3
            GenBedSaveOIDs[gbi] = AddTextOption("#" + (gbi + 1), Lvl.GenRankRowSave(recPC, "ASTR2_GBedNames", "ASTR2_GBedAmts", gbi), flag)
            gbi += 1
        EndWhile
        AddColoredHeader("$ASTR2_Rec_RankLifetime", flag)
        GenBedLifeOIDs = new Int[3]
        gbi = 0
        While gbi < 3
            GenBedLifeOIDs[gbi] = AddTextOption("#" + (gbi + 1), Lvl.GenRankRowJson(recFile, "gbed_names", "gbed_amts", gbi), flag)
            gbi += 1
        EndWhile

        ; --- 右列：一番吸った相手 TOP3（セーブ内／生涯）＋リセット ---
        SetCursorPosition(1)
        AddColoredHeader("$ASTR2_Header_TopPartner", flag)

        AddColoredHeader("$ASTR2_Rec_RankSave", flag)
        RankSaveOIDs = new Int[3]
        int ri = 0
        While ri < 3
            String rowS = "$ASTR2_Rec_None"
            If ri < StorageUtil.FormListCount(recPC, "ASTR2_RankForms")
                Form vfS = StorageUtil.FormListGet(recPC, "ASTR2_RankForms", ri)
                Float amS = StorageUtil.FloatListGet(recPC, "ASTR2_RankAmts", ri)
                rowS = RankRowText(vfS, StorageUtil.StringListGet(recPC, "ASTR2_RankNames", ri), amS)
            EndIf
            RankSaveOIDs[ri] = AddTextOption("#" + (ri + 1), rowS, flag)
            ri += 1
        EndWhile

        AddColoredHeader("$ASTR2_Rec_RankLifetime", flag)
        RankLifeOIDs = new Int[3]
        ri = 0
        While ri < 3
            String rowL = "$ASTR2_Rec_None"
            If ri < JsonUtil.FormListCount(recFile, "rank_forms")
                Form vfL = JsonUtil.FormListGet(recFile, "rank_forms", ri)
                Float amL = JsonUtil.FloatListGet(recFile, "rank_ramounts", ri)
                rowL = RankRowText(vfL, JsonUtil.StringListGet(recFile, "rank_names", ri), amL)
            EndIf
            RankLifeOIDs[ri] = AddTextOption("#" + (ri + 1), rowL, flag)
            ri += 1
        EndWhile

        ; --- 右列つづき：一番イカせた相手 TOP3（イカせ回数の多い順・セーブ内／生涯） ---
        AddColoredHeader("$ASTR2_Header_TopClimax", flag)
        AddColoredHeader("$ASTR2_Rec_RankSave", flag)
        ClimaxRankSaveOIDs = new Int[3]
        int ci = 0
        While ci < 3
            String cRowS = "$ASTR2_Rec_None"
            If ci < StorageUtil.FormListCount(recPC, "ASTR2_ClimaxRankForms")
                Form cvfS = StorageUtil.FormListGet(recPC, "ASTR2_ClimaxRankForms", ci)
                Float camS = StorageUtil.FloatListGet(recPC, "ASTR2_ClimaxRankAmts", ci)
                cRowS = RankRowText(cvfS, StorageUtil.StringListGet(recPC, "ASTR2_ClimaxRankNames", ci), camS)
            EndIf
            ClimaxRankSaveOIDs[ci] = AddTextOption("#" + (ci + 1), cRowS, flag)
            ci += 1
        EndWhile

        AddColoredHeader("$ASTR2_Rec_RankLifetime", flag)
        ClimaxRankLifeOIDs = new Int[3]
        ci = 0
        While ci < 3
            String cRowL = "$ASTR2_Rec_None"
            If ci < JsonUtil.FormListCount(recFile, "climaxrank_forms")
                Form cvfL = JsonUtil.FormListGet(recFile, "climaxrank_forms", ci)
                Float camL = JsonUtil.FloatListGet(recFile, "climaxrank_amts", ci)
                cRowL = RankRowText(cvfL, JsonUtil.StringListGet(recFile, "climaxrank_names", ci), camL)
            EndIf
            ClimaxRankLifeOIDs[ci] = AddTextOption("#" + (ci + 1), cRowL, flag)
            ci += 1
        EndWhile

        ; --- 右列つづき：いかせランキング総合（汎用NPCを種類名で合算・セーブ内／生涯） ---
        AddColoredHeader("$ASTR2_Header_TopClimaxGen", flag)
        AddColoredHeader("$ASTR2_Rec_RankSave", flag)
        GenClimaxSaveOIDs = new Int[3]
        int gci = 0
        While gci < 3
            GenClimaxSaveOIDs[gci] = AddTextOption("#" + (gci + 1), Lvl.GenRankRowSave(recPC, "ASTR2_GClimaxNames", "ASTR2_GClimaxAmts", gci), flag)
            gci += 1
        EndWhile
        AddColoredHeader("$ASTR2_Rec_RankLifetime", flag)
        GenClimaxLifeOIDs = new Int[3]
        gci = 0
        While gci < 3
            GenClimaxLifeOIDs[gci] = AddTextOption("#" + (gci + 1), Lvl.GenRankRowJson(recFile, "gclimax_names", "gclimax_amts", gci), flag)
            gci += 1
        EndWhile

        AddColoredHeader("$ASTR2_Header_RecordReset", flag)
        RecordResetSaveID = AddTextOption("$ASTR2_Rec_ResetSave", "$ASTR2_Btn_Execute", flag)
        RecordResetAllID  = AddTextOption("$ASTR2_Rec_ResetAll", "$ASTR2_Btn_Execute", flag)

    ; 🌟 新設：自動検知システムを搭載したスタイリッシュなIntegrationsページ！
    ElseIf page == "$ASTR2_Page_Integrations" || page == "Integrations"
        AddColoredHeader("$ASTR2_Header_InstallCheck", flag)
        
        ; 🟢 OStim 検出状態（HTMLタグでカラー表示！）
        String ostimStatus = "<font color='#FF4444'>False (Not Installed)</font>"
        If ASTMain.ostim != None
            ostimStatus = "<font color='#44FF44'>True (Installed)</font>"
        EndIf
        AddTextOption("OStim", ostimStatus, flag)

        ; 🔢 OStim API版数（古バージョン混入の警戒用）。GetAPIVersion=CommonLib REL::Version形式=major8/minor8/patch12/build4 bit を分解→Nexus表記「7.4c」風に整形
        ;   build番号→a/b/c…（1=a）／patch==0は省略（7.4c）・patch>0は付ける（7.5.1b）／想定外packは生値そのまま（嘘の版数を出さない保険）
        ;   ★patchは12bit・buildは4bit（=/16と*16で切り出す）。7.4cはpatch=0でたまたま8bit読みでも合ってたが、7.5.1b以降はこの12/4読みが必須になります。ただし表示の都合上、小文字での表示はできませんでした。
        If ASTMain.ostim != None
            Int oVer = ASTMain.ostim.GetAPIVersion()
            Int oMajor = oVer / 16777216
            Int oMinor = (oVer - oMajor * 16777216) / 65536
            Int oPatch = (oVer - oMajor * 16777216 - oMinor * 65536) / 16
            Int oBuild = oVer - oMajor * 16777216 - oMinor * 65536 - oPatch * 16
            String oStr
            If oMajor >= 1 && oMajor <= 99   ; 分解が妥当な範囲＝正常
                oStr = oMajor + "." + oMinor
                If oPatch > 0
                    oStr += "." + oPatch
                EndIf
                If oBuild > 0 && oBuild <= 10
                    String[] oSfx = new String[11]
                    oSfx[1] = "a"
                    oSfx[2] = "b"
                    oSfx[3] = "c"
                    oSfx[4] = "d"
                    oSfx[5] = "e"
                    oSfx[6] = "f"
                    oSfx[7] = "g"
                    oSfx[8] = "h"
                    oSfx[9] = "i"
                    oSfx[10] = "j"
                    oStr += oSfx[oBuild]
                ElseIf oBuild > 10
                    oStr += "." + oBuild   ; 11以上はアルファベット外＝数値で保険とする
                EndIf
            Else
                oStr = oVer as String   ; 想定外pack＝生値フォールバック（誤った版数を出さないようにする）
            EndIf
            AddTextOption("$ASTR2_Info_OStimVer", oStr, flag)
        EndIf

        ; 🟢 OSLAroused 検出状態
        String arousedStatus = "<font color='#FF4444'>False (Not Installed)</font>"
        If ASTMain.isOArousedInstalled
            arousedStatus = "<font color='#44FF44'>True (Installed)</font>"
        EndIf
        AddTextOption("OSLAroused", arousedStatus, flag)
        
        AddEmptyOption()
        
        AddHeaderOption("$ASTR2_Header_Debug", flag)
        AddToggleOptionST("checkForIntegrationsState", "$ASTR2_Option_CheckIntegr", false, flag)

    ElseIf page == "$ASTR2_Page_Servantship"
        ; 🔮 サーヴァントシップページ＝ランク別に手懐けた子を動的一覧（魅了板getter・表示専用・開くたび最新／昇格はティアをライブ読みで自動反映）
        Int svCap = StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", 10)
        SetCursorFillMode(TOP_TO_BOTTOM)
        SetCursorPosition(0)
        AddSliderOptionST("servantCapState", "$ASTR2_Option_ServantCap", svCap as Float, "{0}", flag)
        AddEmptyOption()
        Int svTier = 4
        String svName
        Int svTotal
        String[] svList
        String svSuffix
        Float[] svCC
        Int svI
        Actor[] svActors       ; 🔮 各ティアのActor（表示行[N]↔Actor[N]一致・GetServantNamesと同一並び）
        Int svOid              ; 行クリック用OIDの一時受けです
        svResetN = 0           ; この描画ぶんの控えをリセットします
        ASTR2Servantship.BuildRoster()   ; 🚀 C++で名簿を1パス列挙→tier別キャッシュにします
        While svTier >= 1
            If svTier == 2
                SetCursorPosition(1)   ; 僕・虜は右列へ（左＝愛玩/眷属）
                AddSliderOptionST("petTributeState",  "$ASTR2_Option_PetTribute", SkyVault.GetFloat(None, "ASTR2_PetTributePct", 1.0), "{1}%", flag)   ; 🎁 貢ぎ率＝右ペイン先頭
                AddEmptyOption()
            EndIf
            If svTier == 4
                svName = ASTR2Native.LocFmtF("$ASTR2_Servant_Pet", 0.0)
            ElseIf svTier == 3
                svName = ASTR2Native.LocFmtF("$ASTR2_Servant_Thrall", 0.0)
            ElseIf svTier == 2
                svName = ASTR2Native.LocFmtF("$ASTR2_Servant_Vassal", 0.0)
            Else
                svName = ASTR2Native.LocFmtF("$ASTR2_Servant_Captive", 0.0)
            EndIf
            svTotal = ASTR2Servantship.GetRosterCount(svTier)
            svList = ASTR2Servantship.GetRosterRows(svTier, svCap)
            svActors = ASTR2Servantship.GetRosterActors(svTier, svCap)   ; 🔮 行順一致Actor（個別リセットの行↔Actor紐付け・C++キャッシュ読み）
            ; 見出し＝ティア名＋人数（cap超過時は「N人中M表示」）。0人は見出しだけにします。
            If svCap > 0 && svTotal > svList.Length
                svCC = new Float[2]
                svCC[0] = svTotal as Float
                svCC[1] = svList.Length as Float
                svSuffix = ASTR2Native.LocFmt("$ASTR2_Servant_CountCap", svCC)
            Else
                svSuffix = ASTR2Native.LocFmtF("$ASTR2_Servant_Count", svTotal as Float)
            EndIf
            AddColoredHeader(svName + svSuffix, flag)
            svI = 0
            While svI < svList.Length
                svOid = AddTextOption(svList[svI], "$ASTR2_Servant_Release", flag)   ; 🔮 行クリックで個別解放します
                If svResetN < 128 && svI < svActors.Length
                    svResetOIDs[svResetN] = svOid
                    svResetActors[svResetN] = svActors[svI]
                    svResetN += 1
                EndIf
                svI += 1
            EndWhile
            svTier -= 1
        EndWhile

    ElseIf page == "$ASTR2_Page_Skill"
        ; ✅ Hスキル・コンフィグ。総合=GetDisplayTotalRank／種目=GetDisplayCatRank／孫=GetActionRankAt+IsActionApplicableAt(白/グレー・字下げ)。値は魅了板のキャッシュ読み。種目ラベルはピンク/水色交互。
        ASTR2Technique.RebuildTechCache()   ; ★開く時に1回だけ全ランク計算→以下は全部キャッシュ読み（激軽化・魅了板Ver2）
        Int aggSel = StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechAggMode", 0)
        Int oriSel = StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechOrient", ASTR2Technique.CurOrient())   ; 未設定時は体依存デフォルト（フタ=両刀/男女=異性愛）＝固定値は書かない
        ; ★プルダウン選択肢を毎回ここで確保＝既存セーブ(OnConfigInit未再走)でも空/Noneにならない（SetMenuDialogOptionsもこれを使う）
        TechAggOptions = new String[3]
        TechAggOptions[0] = "$ASTR2_TechAgg_0"
        TechAggOptions[1] = "$ASTR2_TechAgg_1"
        TechAggOptions[2] = "$ASTR2_TechAgg_2"
        TechOrientOptions = new String[3]
        TechOrientOptions[0] = "$ASTR2_TechOrient_0"
        TechOrientOptions[1] = "$ASTR2_TechOrient_1"
        TechOrientOptions[2] = "$ASTR2_TechOrient_2"
        String pink = "#ffc5e1"
        String blue = "#73bbf7"
        ; ===== 左列：コンフィグ＋ランク＋詳細(攻め/手わざ/腰使い/キス) =====
        SetCursorFillMode(TOP_TO_BOTTOM)
        SetCursorPosition(0)
        AddColoredHeader("$ASTR2_Header_HSkillConfig", flag)
        TechAggMenuOID = AddMenuOption("$ASTR2_Option_TechAgg", TechAggOptions[aggSel], flag)
        AddEmptyOption()
        AddColoredHeader("$ASTR2_Header_HSkill", flag)
        TechTotalOID = AddTextOption("$ASTR2_Tech_HSkillRank", "" + ASTR2Technique.GetDisplayTotalRank(), flag)
        AddColoredHeader("$ASTR2_Header_HSkillDetail", flag)
        TechSMOID[0]  = AddTextOption("<font color='" + pink + "'>$ASTR2_Tech_AttackS</font>", "<font color='" + pink + "'>" + ASTR2Technique.GetDisplayCatRank(6) + "</font>", flag)
        TechCatOID[2] = AddTextOption("<font color='" + blue + "'>$ASTR2_Tech_Hand</font>", "<font color='" + blue + "'>" + ASTR2Technique.GetDisplayCatRank(2) + "</font>", flag)   ; 手技(idx12-23)
        AddActionRow(12, "$ASTR2_Act_Handjob")
        AddActionRow(13, "$ASTR2_Act_Fingering")
        AddActionRow(14, "$ASTR2_Act_AnalFinger")
        AddActionRow(15, "$ASTR2_Act_Fisting")
        AddActionRow(16, "$ASTR2_Act_AnalFist")
        AddActionRow(17, "$ASTR2_Act_RubClit")
        AddActionRow(18, "$ASTR2_Act_GropeBreast")
        AddActionRow(19, "$ASTR2_Act_GropeButt")
        AddActionRow(20, "$ASTR2_Act_GropeBalls")
        AddActionRow(21, "$ASTR2_Act_OralFinger")
        AddActionRow(22, "$ASTR2_Act_VaginalToy")
        AddActionRow(42, "$ASTR2_Act_DildoVaginal")
        AddActionRow(43, "$ASTR2_Act_DildoAnal")
        AddActionRow(44, "$ASTR2_Act_Spanking")
        AddActionRow(45, "$ASTR2_Act_Choking")
        AddActionRow(23, "$ASTR2_Act_AnalToy")
        TechCatOID[0] = AddTextOption("<font color='" + pink + "'>$ASTR2_Tech_Hips</font>", "<font color='" + pink + "'>" + ASTR2Technique.GetDisplayCatRank(0) + "</font>", flag)   ; 腰使い(0-2)
        AddActionRow(0, "$ASTR2_Act_Vaginal")
        AddActionRow(1, "$ASTR2_Act_Anal")
        AddActionRow(41, "$ASTR2_Act_FaceSit")
        AddActionRow(2, "$ASTR2_Act_Tribbing")
        TechCatOID[5] = AddTextOption("<font color='" + blue + "'>$ASTR2_Tech_Kiss</font>", "<font color='" + blue + "'>" + ASTR2Technique.GetDisplayCatRank(5) + "</font>", flag)   ; キス(idx35-40・6孫)
        AddActionRow(35, "$ASTR2_Act_Kiss")
        AddActionRow(36, "$ASTR2_Act_KissFrench")
        AddActionRow(37, "$ASTR2_Act_KissCheek")
        AddActionRow(38, "$ASTR2_Act_KissFoot")
        AddActionRow(39, "$ASTR2_Act_KissHand")
        AddActionRow(40, "$ASTR2_Act_KissNeck")
        ; ===== 右列：指向＋詳細(受け/口舌/自慰/その他)。先頭は左の見出し6行ぶんスペースで揃える =====
        SetCursorPosition(1)
        AddEmptyOption()
        TechOrientMenuOID = AddMenuOption("$ASTR2_Option_TechOrient", TechOrientOptions[oriSel], flag)
        AddEmptyOption()
        AddEmptyOption()
        AddEmptyOption()
        AddEmptyOption()
        TechSMOID[1]  = AddTextOption("<font color='" + pink + "'>$ASTR2_Tech_ReceiveM</font>", "<font color='" + pink + "'>" + ASTR2Technique.GetDisplayCatRank(7) + "</font>", flag)
        TechCatOID[1] = AddTextOption("<font color='" + blue + "'>$ASTR2_Tech_Mouth</font>", "<font color='" + blue + "'>" + ASTR2Technique.GetDisplayCatRank(1) + "</font>", flag)   ; 口・舌技(idx3-11・アナル舐め=11単独)
        AddActionRow(3, "$ASTR2_Act_Blowjob")
        AddActionRow(4, "$ASTR2_Act_Deepthroat")
        AddActionRow(5, "$ASTR2_Act_Cunnilingus")
        AddActionRow(6, "$ASTR2_Act_LickVagina")
        AddActionRow(7, "$ASTR2_Act_LickPenis")
        AddActionRow(8, "$ASTR2_Act_LickBalls")
        AddActionRow(9, "$ASTR2_Act_LickNipple")
        AddActionRow(10, "$ASTR2_Act_SuckNipple")
        AddActionRow(11, "$ASTR2_Act_AnalLick")
        TechCatOID[4] = AddTextOption("<font color='" + pink + "'>$ASTR2_Tech_Solo</font>", "<font color='" + pink + "'>" + ASTR2Technique.GetDisplayCatRank(4) + "</font>", flag)   ; 自慰(idx29-34)
        AddActionRow(29, "$ASTR2_Act_GrindPenis")
        AddActionRow(30, "$ASTR2_Act_GrindThigh")
        AddActionRow(31, "$ASTR2_Act_GrindFoot")
        AddActionRow(32, "$ASTR2_Act_GrindObject")
        AddActionRow(33, "$ASTR2_Act_MasturbF")
        AddActionRow(34, "$ASTR2_Act_MasturbM")
        TechCatOID[3] = AddTextOption("<font color='" + blue + "'>$ASTR2_Tech_Other</font>", "<font color='" + blue + "'>" + ASTR2Technique.GetDisplayCatRank(3) + "</font>", flag)   ; その他(idx24-28)
        AddActionRow(24, "$ASTR2_Act_Boobjob")
        AddActionRow(25, "$ASTR2_Act_Footjob")
        AddActionRow(26, "$ASTR2_Act_Thighjob")
        AddActionRow(27, "$ASTR2_Act_Buttjob")
        AddActionRow(46, "$ASTR2_Act_Toy")
        AddActionRow(47, "$ASTR2_Act_Ejaculation")
        AddActionRow(48, "$ASTR2_Act_VampBite")
        AddActionRow(49, "$ASTR2_Act_Teasing")
        AddActionRow(50, "$ASTR2_Act_Massage")
        AddActionRow(51, "$ASTR2_Act_BreastSlide")
        AddActionRow(52, "$ASTR2_Act_BreastSmother")
        AddActionRow(53, "$ASTR2_Act_Tail")
        AddActionRow(28, "$ASTR2_Act_RubFace")
    EndIf
EndEvent

; =====================================================================================
; 🕹️ UIメニュー部品の関数群
; =====================================================================================
Function ToggleMod()
    AddColoredHeader("$ASTR2_Header_ToggleMod", OPTION_FLAG_NONE)
    AddToggleOptionST("SuccubusToggleState", "$ASTR2_Option_EnableMod", GetLvlManager().IsSuccubus())
EndFunction

Function GameplayOptionsColumn()
    ASTR2MainScript ASTMain = GetMain()
    ASTLvlManager Lvl = GetLvlManager()
    
    AddColoredHeader("$ASTR2_Header_Gameplay", flag)
    AddMenuOptionST("progressSpeedMenuState", "$ASTR2_Option_Speed", progressSpeedArr[Lvl.progressSpeed], flag)
    AddToggleOptionST("RandomSelectState", "$ASTR2_Option_RandomSelect", bRandomSelectionEnabled, flag)

    AddToggleOptionST("DrainOncePerDayState", "$ASTR2_Option_DrainOncePerDay", SkyVault.GetInt(None, "ASTR2_DrainMarkOn", 0) == 1, flag)
    ; 🔥 甘露丹の火種＝他MODのパワーにも使うかの設定をします（ASTR2のパワーは常に対象になります・既定ON／dllが保持）
    AddToggleOptionST("PowerTokenOtherModsState", "$ASTR2_Option_PowerTokenOtherMods", ASTR2Native.GetPowerTokenOtherMods(), flag)

    ; =======================================================
    ; 🌟 新設：殺害セッティング
    ; =======================================================
    AddEmptyOption() ; 見栄えを良くするために1行空けます
    AddColoredHeader("$ASTR2_Header_KillSettings", flag)
    AddToggleOptionST("AllowKillNPCState", "$ASTR2_Option_AllowKillNPC", ASTMain.AllowKillNPC, flag)
    
    ; 💡 一般NPC殺害がOFFの時は、ユニークNPC殺害もグレーアウトさせる連動ギミック！
    int killFlag = flag
    If !ASTMain.AllowKillNPC
        killFlag = OPTION_FLAG_DISABLED
    EndIf
    AddToggleOptionST("AllowKillUniqueState", "$ASTR2_Option_AllowKillUnique", ASTMain.AllowKillUnique, killFlag)

    ; =======================================================
    ; 🩸 レヴナントセッティング＝ラヴェナス・ドレイン(範囲ドレイン)の吸引対象を広げる（C++直読み）
    ; =======================================================
    AddEmptyOption() ; 見栄えを良くするために1行空けます
    AddColoredHeader("$ASTR2_Header_Ravenous", flag)
    AddToggleOptionST("ravenousNpcState", "$ASTR2_Option_RavenousNpc", SkyVault.GetInt(None, "ASTR2_RavenousNpcToo", 0) == 1, flag)   ; 🩸 一般・ユニークNPCも吸引対象に
    AddToggleOptionST("ravenousFollowerState", "$ASTR2_Option_RavenousFollower", SkyVault.GetInt(None, "ASTR2_RavenousFollowerToo", 0) == 1, flag)   ; 🩸 フォロワーも吸引対象に
    AddEmptyOption() ; 🩸 レヴナントセッティングの下に1行空け
    AddColoredHeader("$ASTR2_Header_ExportImport", flag)
    AddToggleOptionST("AutoExportState", "$ASTR2_Option_AutoExport", bAutoExport, flag)
    AddToggleOptionST("AutoImportState", "$ASTR2_Option_AutoImport", bAutoImport, flag)
    AddTextOptionST("ExportConfigState", "$ASTR2_Option_ExportConfig", "$ASTR2_Btn_Execute", flag)
    AddTextOptionST("ImportConfigState", "$ASTR2_Option_ImportConfig", "$ASTR2_Btn_Execute", flag)
    AddTextOptionST("ResetAllConfigState", "$ASTR2_Option_ResetAll", "$ASTR2_Btn_Execute", flag)
EndFunction

; 🩸 アビリティコンフィグ：ドレインの◎調整値（威力/吸収率/上限/育成速度）。書込先はDrainScriptプロパティ＝push方式。
Function AbilityConfigColumn()
    ASTR2MainScript ASTMain = GetMain()
    ASTDrainScript Drain = GetMain().GetDrainScript()

    ; ===== 左列（呼び出し側でSetCursorPosition(0)済み）＝Hスキル/ドレイン/スイート =====
    ; 🔮 ASTR2専用魔法の魔法コスト（先頭＝魔法全体の話・C++コスト式がSkyVaultを直読み）
    AddColoredHeader("$ASTR2_Header_ManaCost", flag)
    AddSliderOptionST("manaCostStepMulState",  "$ASTR2_Option_ManaCostStepMul",  SkyVault.GetFloat(None, "ASTR2_ManaCostStepMul", 1.67), "{2}", flag)
    AddSliderOptionST("manaCostCapPctState",   "$ASTR2_Option_ManaCostCapPct",   SkyVault.GetFloat(None, "ASTR2_ManaCostCapPct", 100.0), "{0}", flag)
    AddSliderOptionST("manaCostBurstMulState", "$ASTR2_Option_ManaCostBurstMul", SkyVault.GetFloat(None, "ASTR2_ManaCostBurstMul", 5.0), "{0}", flag)

    ; 👅 Hスキル（先頭・効果の強さ系を集約）
    AddColoredHeader("$ASTR2_Header_HSkill", flag)
    AddSliderOptionST("svTechInfluenceState", "$ASTR2_Option_SvTechInfluence", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2), "{2}", flag)
    AddSliderOptionST("techExciteState", "$ASTR2_Option_TechExcite", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02), "{3}", flag)

    ; 🩸 ドレイン
    AddColoredHeader("$ASTR2_Header_DrainTune", flag)
    AddSliderOptionST("drainHSexBoostState", "$ASTR2_Option_DrainHSexBoost", Drain.HSexBoostMult, "{1} x", flag)
    AddSliderOptionST("drainOrgRateState",   "$ASTR2_Option_DrainOrgRate",   Drain.OrgasmLFRate,  "{2}", flag)
    AddToggleOptionST("drainOrgCapOnState",  "$ASTR2_Option_DrainOrgCapOn",  SkyVault.GetInt(None, "ASTR2_OrgLFCapOn", 1) == 1, flag)
    Int orgCapFlag = flag
    If SkyVault.GetInt(None, "ASTR2_OrgLFCapOn", 1) != 1
        orgCapFlag = OPTION_FLAG_DISABLED   ; 上限OFFなら上限値スライダーは触れない
    EndIf
    AddSliderOptionST("drainOrgCapState",    "$ASTR2_Option_DrainOrgCap",    Drain.OrgasmLFCap,   "{0}", orgCapFlag)
    AddSliderOptionST("drainDestRateState",  "$ASTR2_Option_DrainDestRate",  Drain.DestSkillRate, "{1}", flag)

    ; 🔥 アンリーシュド・フューリー＝スキル強化の基礎値（C++ Furyが直読み）
    AddColoredHeader("$ASTR2_Header_Fury", flag)
    AddSliderOptionST("furyBaseState", "$ASTR2_Option_FuryBase", SkyVault.GetInt(None, "ASTR2_FuryBase", 10) as Float, "{0}", flag)

    ; 🧟 スイート・ヴァッサル
    AddColoredHeader("$ASTR2_Header_Reanim", flag)
    AddSliderOptionST("reanimCostState", "$ASTR2_Option_ReanimCost", SkyVault.GetFloat(None, "ASTR2_ReanimCost", 5000.0), "{0}", flag)
    AddSliderOptionST("vassalBaseDaysState", "$ASTR2_Option_VassalBaseDays", SkyVault.GetFloat(None, "ASTR2_VassalBaseDays", 10.0), "{0}", flag)
    AddSliderOptionST("vassalTaxState", "$ASTR2_Option_VassalTax", SkyVault.GetFloat(None, "ASTR2_VassalTaxRate", 0.01) * 100.0, "{1}%", flag)
    AddSliderOptionST("vassalLoveState", "$ASTR2_Option_VassalLove", SkyVault.GetInt(None, "ASTR2_VassalLoveDays", 3) as Float, "{0}", flag)
    ; 💀 死霊(Lv2-8)の維持費＝6Hごとに最大LFの%を1体あたり徴収（生者向けの手下税とは別物）＋支払い/未払いの通知トグル
    AddSliderOptionST("vassalUpkeepState", "$ASTR2_Option_VassalUpkeep", SkyVault.GetFloat(None, "ASTR2_VassalUpkeepRate", 0.01) * 100.0, "{1}%", flag)
    AddToggleOptionST("vassalUpkeepPaidState", "$ASTR2_Option_VassalUpkeepPaid", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyPaid", 0) == 1, flag)
    AddToggleOptionST("vassalUpkeepMissState", "$ASTR2_Option_VassalUpkeepMiss", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyMiss", 1) == 1, flag)

    ; ===== 右列（修得Lv順：シンフル・ネイル→セダクションLv1→クリエイト・シャード/ラスト/ナイトメアLv2→コンスーム・エッセンスLv3→サキュバス・ウィークネスLv7）=====
    SetCursorPosition(1)
    ; 💅 シンフル・ネイル：ネイル装備を必須にするか（ON=装備中のみ効果／OFF=習得済みは常時発動）
    AddColoredHeader("$ASTR2_Header_NailCfg", flag)
    AddToggleOptionST("nailRequireEquipState", "$ASTR2_Option_NailRequireEquip", SkyVault.GetInt(None, "ASTR2_NailRequireEquip", 1) == 1, flag)

    ; 💋 セダクション（魅了アロウザルゲート・OSL未導入はグレー）
    Int prevSedFlag = flag
    If !ASTMain.isOArousedInstalled
        flag = OPTION_FLAG_DISABLED
    EndIf
    AddColoredHeader("$ASTR2_Header_Seduction", flag)
    AddSliderOptionST("seductionLineState",  "$ASTR2_Option_SeductionLine",  ASTMain.seductionLinef,  "{0}", flag)
    AddSliderOptionST("seductionBaseState",  "$ASTR2_Option_SeductionBase",  SkyVault.GetFloat(None, "ASTR2_SedBase", 50.0),  "{0}", flag)
    AddSliderOptionST("seductionStepState",  "$ASTR2_Option_SeductionStep",  SkyVault.GetFloat(None, "ASTR2_SedStep", 5.0),  "{0}", flag)
    AddSliderOptionST("seductionBonusState", "$ASTR2_Option_SeductionBonus", ASTMain.seductionBonusf, "{0}", flag)
    flag = prevSedFlag

    ; 💠 クリエイト・シャード（Lv2）：コスト倍率＋付呪XP倍率（素値はスペル板がStorageUtilで読む）
    AddColoredHeader("$ASTR2_Header_ShardTune", flag)
    AddSliderOptionST("shardCostMultState",  "$ASTR2_Option_ShardCostMult",  SkyVault.GetFloat(None, "ASTR2_ShardCostMult", 1.0),  "{2}", flag)
    AddSliderOptionST("shardEnchXpMultState", "$ASTR2_Option_ShardEnchXpMult", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", 1.0), "{1}", flag)

    ; 💗 アラウジング・ラスト（Lv2）：興奮注入量ベース＋H中ドレインブーストベース（2つともラストの効果）
    AddColoredHeader("$ASTR2_Header_Lust", flag)
    AddSliderOptionST("lustBaseState",  "$ASTR2_Option_LustBase",  SkyVault.GetInt(None, "ASTR2_LustBase", 10) as Float, "{0}", flag)
    AddSliderOptionST("hSexBoostState", "$ASTR2_Option_HSexBoost", SkyVault.GetFloat(None, "ASTR2_HSexBoostBase", 2.0), "{1}", flag)

    ; 🌙 ナイトメア・エンブレイス：素の成功確率の土台2本（補正は別途上乗せ）
    AddColoredHeader("$ASTR2_Header_Nightmare", flag)
    AddSliderOptionST("nmBaseChanceState",  "$ASTR2_Option_NmBaseChance", SkyVault.GetFloat(None, "ASTR2_NightmareBaseChance", 10.0), "{0}", flag)
    AddSliderOptionST("nmChancePerLvState", "$ASTR2_Option_NmPerLv",      SkyVault.GetFloat(None, "ASTR2_NightmareChancePerLv", 8.0), "{0}", flag)

    ; 💚 コンスーム・エッセンス（Lv3）：威力／コスト／回復魔法の育ち
    AddColoredHeader("$ASTR2_Header_ConsumeTune", flag)
    AddSliderOptionST("consumeRegenPctState",  "$ASTR2_Option_ConsumeRegenPct",  SkyVault.GetFloat(None, "ASTR2_ConsumeRegenPct", 3.0),  "{1}", flag)
    AddSliderOptionST("consumeLFPerPctState",  "$ASTR2_Option_ConsumeLFPerPct",  StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", 3.5),  "{1}", flag)
    AddSliderOptionST("consumeRestoRateState", "$ASTR2_Option_ConsumeRestoRate", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", 2.5), "{1}", flag)

    ; 🐍 サキュバス・ウィークネス：耐性ダウンの上限capと成長係数（ASTDrainScriptが読む）
    AddColoredHeader("$ASTR2_Header_Weakness", flag)
    AddSliderOptionST("weaknessCapState",    "$ASTR2_Option_WeaknessCap",    SkyVault.GetFloat(None, "ASTR2_WeaknessCap", 100.0), "{0}", flag)   ; 0〜10000・刻み100
    AddSliderOptionST("weaknessGrowthState", "$ASTR2_Option_WeaknessGrowth", SkyVault.GetFloat(None, "ASTR2_WeaknessPerLv", 1.0), "{1}", flag)
EndFunction


Function Disadvantages()
    ASTR2MainScript ASTMain = GetMain()
    ASTR2LifeForceBarScript LFBar = GetLFBar()
    
    AddColoredHeader("$ASTR2_Header_LifeForceSE", flag)
    AddToggleOptionST("ToggleDisadvantagesState", "$ASTR2_Option_Enable", ASTMain.AreDisadvantagesEnabled, flag)
    int prevFlag = flag
    If !ASTMain.AreDisadvantagesEnabled
        flag = OPTION_FLAG_DISABLED
    EndIf
    AddSliderOptionST("energyIncrState", "$ASTR2_Option_LFMultiplier", LFBar.energyIncr,  "{2} x", a_flags = flag)
    AddSliderOptionST("energyMaxState", "$ASTR2_Option_LFMaxStorage", LFBar.LFMaxMultiplier, "{1} x", a_flags = flag)
    AddSliderOptionST("energyUpdateFreq", "$ASTR2_Option_LFUpdateFreq", LFBar.energyUpdateFreq as float, a_flags = flag)
    flag = prevFlag
EndFunction

bool Property areCheatsAllowed = false Auto
Function Debug()
    AddColoredHeader("$ASTR2_Header_Debug", flag)
    AddTextOptionST("genBugReportState", "$ASTR2_Option_GenBugReport", "$ASTR2_Btn_Execute", flag)   ; 🩹 不具合報告ファイル生成(B-6・誰でも押せる診断so チートの上)
    AddTextOptionST("bugPathState", "$ASTR2_Option_BugReportPath", "", flag)   ; 🩹 格納場所(表示専用・ホバーでSkyVaultのパスをinfo欄に＝押下後もホバーで再表示できる)
    AddEmptyOption()
    AddToggleOptionST("EnableCheatsState", "$ASTR2_Option_EnableCheat", areCheatsAllowed, flag)
    int prevFlag = flag
    If !areCheatsAllowed
        flag = OPTION_FLAG_DISABLED
    EndIf
    AddMenuOptionST("LvlUpMenuState", "$ASTR2_Option_LvlUp", "", flag)
    flag = prevFlag
EndFunction

; =====================================================================================
; 🕹️ 各種オプションが変更されたときの処理（OnOption... 系まとめ）
; =====================================================================================
Event OnOptionSliderOpen(Int option)
    ASTR2MainScript ASTMain = GetMain()
    If option == SliderLifeForceXID
        SetSliderDialogStartValue(LifeForceX)
        SetSliderDialogDefaultValue(LifeForceDefX)             
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderLifeForceYID
        SetSliderDialogStartValue(LifeForceY)
        SetSliderDialogDefaultValue(LifeForceDefY)             
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    ElseIf option == SliderExpXID
        SetSliderDialogStartValue(ExpX)
        SetSliderDialogDefaultValue(ExpDefX)             
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderExpYID
        SetSliderDialogStartValue(ExpY)
        SetSliderDialogDefaultValue(ExpDefY)           
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    ElseIf option == SliderLogoXID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            SetSliderDialogStartValue(LogoSmallX)
            SetSliderDialogDefaultValue(LogoSmallDefX)             
        Else
            SetSliderDialogStartValue(LogoX)
            SetSliderDialogDefaultValue(LogoDefX)
        EndIf           
            SetSliderDialogRange(0, 1920)
            SetSliderDialogInterval(1.0)
        
    ElseIf option == SliderLogoYID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            SetSliderDialogStartValue(LogoSmallY)
            SetSliderDialogDefaultValue(LogoSmallDefY)
        Else
            SetSliderDialogStartValue(LogoY)
            SetSliderDialogDefaultValue(LogoDefY)
        EndIf
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1.0)

    ElseIf option == SliderLogoSizeID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            SetSliderDialogStartValue(LogoSizeSmall)
            SetSliderDialogDefaultValue(LogoSizeSmallDef)
        Else
            SetSliderDialogStartValue(LogoSize)
            SetSliderDialogDefaultValue(LogoSizeDef)
        EndIf
        SetSliderDialogRange(10.0, 200.0)
        SetSliderDialogInterval(1.0)

    ElseIf option == SliderActorHp1XID
        SetSliderDialogStartValue(ActorHpBar1X)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar1.MyDefX)
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp1YID
        SetSliderDialogStartValue(ActorHpBar1Y)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar1.MyDefY)
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp2XID
        SetSliderDialogStartValue(ActorHpBar2X)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar2.MyDefX)
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp2YID
        SetSliderDialogStartValue(ActorHpBar2Y)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar2.MyDefY)
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp3XID
        SetSliderDialogStartValue(ActorHpBar3X)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar3.MyDefX)
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp3YID
        SetSliderDialogStartValue(ActorHpBar3Y)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar3.MyDefY)
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp4XID
        SetSliderDialogStartValue(ActorHpBar4X)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar4.MyDefX)
        SetSliderDialogRange(0, 1920)
        SetSliderDialogInterval(1)
    ElseIf option == SliderActorHp4YID
        SetSliderDialogStartValue(ActorHpBar4Y)
        SetSliderDialogDefaultValue(GetActorHpBar().ASTR2ActorHpBar4.MyDefY)
        SetSliderDialogRange(0, 1080)
        SetSliderDialogInterval(1)
    EndIf
EndEvent

Event OnOptionSliderAccept(Int option, Float value)
    ASTR2MainScript ASTMain = GetMain()
    If option == SliderLifeForceXID
        LifeForceX = value
        SetSliderOptionValue(option, LifeForceX, "{0}")
    ElseIf option == SliderLifeForceYID
        LifeForceY = value
        SetSliderOptionValue(option, LifeForceY, "{0}")

    ElseIf option == SliderExpXID
        ExpX = value
        SetSliderOptionValue(option, ExpX, "{0}")
    ElseIf option == SliderExpYID
        ExpY = value
        SetSliderOptionValue(option, ExpY, "{0}")

    ElseIf option == SliderLogoXID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            LogoSmallX = value
            SetSliderOptionValue(option, LogoSmallX, "{0}")
        Else
            LogoX = value
            SetSliderOptionValue(option, LogoX, "{0}")
        EndIf

    ElseIf option == SliderLogoYID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            LogoSmallY = value
            SetSliderOptionValue(option, LogoSmallY, "{0}")
        Else
            LogoY = value
            SetSliderOptionValue(option, LogoY, "{0}")
        EndIf
    ElseIf option == SliderLogoSizeID
        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            LogoSizeSmall = value
            SetSliderOptionValue(option, LogoSizeSmall, "{0}")
        Else
            LogoSize = value
            SetSliderOptionValue(option, LogoSize, "{0}")
        EndIf

    ElseIf option == SliderActorHp1XID
        ActorHpBar1X = value
        SetSliderOptionValue(option, ActorHpBar1X, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp1YID
        ActorHpBar1Y = value
        SetSliderOptionValue(option, ActorHpBar1Y, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp2XID
        ActorHpBar2X = value
        SetSliderOptionValue(option, ActorHpBar2X, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp2YID
        ActorHpBar2Y = value
        SetSliderOptionValue(option, ActorHpBar2Y, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp3XID
        ActorHpBar3X = value
        SetSliderOptionValue(option, ActorHpBar3X, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp3YID
        ActorHpBar3Y = value
        SetSliderOptionValue(option, ActorHpBar3Y, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp4XID
        ActorHpBar4X = value
        SetSliderOptionValue(option, ActorHpBar4X, "{0}")
        bActorHpPosChanged = true
    ElseIf option == SliderActorHp4YID
        ActorHpBar4Y = value
        SetSliderOptionValue(option, ActorHpBar4Y, "{0}")
        bActorHpPosChanged = true
    EndIf
EndEvent

; =====================================================================================
; 🕹️ メニューを開いたときのプルダウン処理
; =====================================================================================
Event OnOptionMenuOpen(Int option)
    ASTTattooScript Tattoo = GetTattoo()
    If option == proteusCatFilterOID   ; 🌊 カテゴリ絞込プルダウンを開きます
        SetMenuDialogOptions(ProteusCatOptions)
        SetMenuDialogStartIndex(SkyVault.GetInt(None, "ASTR2_ProteusCatFilter", 0))
        SetMenuDialogDefaultIndex(0)
        Return
    EndIf
    Int pmoIdx = 0
    While pmoIdx < proteusIndivCount   ; 🌊 個体別ボディのドロップダウンを開きます＝自動/3BA/UBEを現在値で表示します
        If option == ProteusActorOIDs[pmoIdx]
            SetMenuDialogOptions(ProteusIndivBodyOptions)
            Int pmoCur = ASTR2Native.SigilGetManualBt(ProteusActors[pmoIdx])
            Int pmoStart = 0
            If pmoCur == 0
                pmoStart = 1
            ElseIf pmoCur == 1
                pmoStart = 2
            EndIf
            SetMenuDialogStartIndex(pmoStart)
            SetMenuDialogDefaultIndex(0)
            Return
        EndIf
        pmoIdx += 1
    EndWhile
    If option == MenuLifeForceModeID
        SetMenuDialogOptions(DisplayModeOptions)
        SetMenuDialogStartIndex(LFDisplayMode)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == MenuExpModeID
        SetMenuDialogOptions(DisplayModeOptions)
        SetMenuDialogStartIndex(ExpDisplayMode)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == tattooLeveledMenuOption
        SetMenuDialogOptions(leveledTattos)
        SetMenuDialogStartIndex(currLeveledTattosIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == MenuLogoModeID
        SetMenuDialogOptions(LogoDisplayModeOptions)
        SetMenuDialogStartIndex(LogoDisplayMode)
        SetMenuDialogDefaultIndex(LogoDisplayModeDef)
    ElseIf option == fixedChestOID
        SetMenuDialogOptions(fixedChestArr)
        SetMenuDialogStartIndex(fixedChestIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == fixedBackOID
        SetMenuDialogOptions(fixedBackArr)
        SetMenuDialogStartIndex(fixedBackIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == fixedLegacyOID
        SetMenuDialogOptions(fixedLegacyArr)
        SetMenuDialogStartIndex(fixedLegacyIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == fixedLegacyMaleOID
        SetMenuDialogOptions(fixedLegacyMaleArr)
        SetMenuDialogStartIndex(fixedLegacyMaleIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == fixedLegacySmallOID
        SetMenuDialogOptions(fixedLegacySmallArr)
        SetMenuDialogStartIndex(fixedLegacySmallIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == fixedMiscOID
        SetMenuDialogOptions(fixedMiscArr)
        SetMenuDialogStartIndex(fixedMiscIndex)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == MenuActorHpModeID
        SetMenuDialogOptions(ActorHpModeOptions)
        SetMenuDialogStartIndex(ActorHpDisplayMode)
        SetMenuDialogDefaultIndex(0)
    ElseIf option == TechAggMenuOID
        SetMenuDialogOptions(TechAggOptions)
        SetMenuDialogStartIndex(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechAggMode", 0))
        SetMenuDialogDefaultIndex(0)
    ElseIf option == TechOrientMenuOID
        SetMenuDialogOptions(TechOrientOptions)
        SetMenuDialogStartIndex(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechOrient", ASTR2Technique.CurOrient()))
        SetMenuDialogDefaultIndex(0)
    EndIf
EndEvent

; =====================================================================================
; 🕹️ プルダウンを選んだ後の処理
; =====================================================================================
Event OnOptionMenuAccept(Int option, Int index)
    ASTR2MainScript ASTMain = GetMain()
    ASTTattooScript Tattoo = GetTattoo()

    If option == proteusCatFilterOID   ; 🌊 カテゴリ絞込を確定する＝再描画で絞りこみます
        SkyVault.SetInt(None, "ASTR2_ProteusCatFilter", index)
        SetMenuOptionValue(option, ProteusCatOptions[index])
        ForcePageReset()
        Return
    EndIf
    Int pmaIdx = 0
    While pmaIdx < proteusIndivCount   ; 🌊 個体別ボディの選択確定＝index 0自動/1=3BA/2=UBE/3=リストから除外
        If option == ProteusActorOIDs[pmaIdx]
            If index == 3
                ; 🌊 リストから除外＝確認→YESでリセット(再検出)まで一覧から非表示(C++native＝再登録も止まる)
                If ShowMessage("$ASTR2_Msg_ConfirmExclude", true)
                    ASTR2Native.SigilSetExcluded(ProteusActors[pmaIdx], true)
                    ForcePageReset()   ; その行が消えます
                Else
                    Int pmaCurBt = ASTR2Native.SigilGetManualBt(ProteusActors[pmaIdx])   ; NO＝表示を現在ボディへ戻す
                    Int pmaCurIdx = 0
                    If pmaCurBt == 0
                        pmaCurIdx = 1
                    ElseIf pmaCurBt == 1
                        pmaCurIdx = 2
                    EndIf
                    SetMenuOptionValue(option, ProteusIndivBodyOptions[pmaCurIdx])
                EndIf
            Else
                Int pmaBt = -1
                If index == 1
                    pmaBt = 0
                ElseIf index == 2
                    pmaBt = 1
                EndIf
                ASTR2Native.SigilSetManualBt(ProteusActors[pmaIdx], pmaBt)
                SetMenuOptionValue(option, ProteusIndivBodyOptions[index])
            EndIf
            Return
        EndIf
        pmaIdx += 1
    EndWhile

    If option == MenuLifeForceModeID
        LFDisplayMode = index
        SetMenuOptionValue(option, DisplayModeOptions[LFDisplayMode])
        If ASTMain != None
            ASTMain.LFDisplayMode = index
        EndIf
        
        If LFDisplayMode == 0 || LFDisplayMode == 2 || LFDisplayMode == 3
            LifeForceCheckKey = -1
            SetKeyMapOptionValue(KeyLifeForceCheckID, -1)
            If ASTMain != None
                ASTMain.SetLifeForceKeybind(-1)
            EndIf
        ElseIf LFDisplayMode == 1
            LifeForceCheckKey = 35
            SetKeyMapOptionValue(KeyLifeForceCheckID, 35)
            If ASTMain != None
                ASTMain.SetLifeForceKeybind(35)         
            EndIf
        EndIf
        
    ElseIf option == MenuExpModeID
        ExpDisplayMode = index
        SetMenuOptionValue(option, DisplayModeOptions[ExpDisplayMode])
        If ASTMain != None
            ASTMain.ExpDisplayMode = index
        EndIf
        
        If ExpDisplayMode == 0 || ExpDisplayMode == 2 || ExpDisplayMode == 3
            ExpCheckKey = -1
            SetKeyMapOptionValue(KeyExpCheckID, -1)
            If ASTMain != None
                ASTMain.SetExpKeybind(-1)
            EndIf
        ElseIf ExpDisplayMode == 1
            ExpCheckKey = 35
            SetKeyMapOptionValue(KeyExpCheckID, 35) 
            If ASTMain != None
                ASTMain.SetExpKeybind(35)         
            EndIf
        EndIf
        
    Elseif option == tattooLeveledMenuOption
        currLeveledTattosIndex = index ; 💡 選択されたインデックス(0, 1, 2)を保存します
        
        Tattoo.RefreshTattoo()
        SetMenuOptionValue(tattooLeveledMenuOption, leveledTattos[index])
    ElseIf option == fixedChestOID
        fixedChestIndex = index
        If index > 0
            fixedBackIndex = 0
            fixedLegacyIndex = 0
            fixedLegacyMaleIndex = 0 ; 💡 追加
            fixedLegacySmallIndex = 0
            fixedMiscIndex = 0
        EndIf
        ForcePageReset()
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf
    ElseIf option == fixedBackOID
        fixedBackIndex = index
        If index > 0
            fixedChestIndex = 0
            fixedLegacyIndex = 0
            fixedLegacyMaleIndex = 0 ; 💡 追加
            fixedLegacySmallIndex = 0
            fixedMiscIndex = 0
        EndIf
        ForcePageReset()
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf
    ElseIf option == fixedLegacyOID
        fixedLegacyIndex = index
        If index > 0
            fixedChestIndex = 0
            fixedBackIndex = 0
            fixedLegacyMaleIndex = 0 ; 💡 追加
            fixedLegacySmallIndex = 0
            fixedMiscIndex = 0
        EndIf
        ForcePageReset()
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf
    ElseIf option == fixedLegacyMaleOID
        fixedLegacyMaleIndex = index
        If index > 0
            fixedChestIndex = 0
            fixedBackIndex = 0
            fixedLegacyIndex = 0
            fixedLegacySmallIndex = 0
            fixedMiscIndex = 0
        EndIf
        ForcePageReset()
        ; 🌟 男性用にも安全ガードを適用してフタナリボディを死守します
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf
    ElseIf option == fixedLegacySmallOID
        fixedLegacySmallIndex = index
        If index > 0
            fixedChestIndex = 0
            fixedBackIndex = 0
            fixedLegacyIndex = 0
            fixedLegacyMaleIndex = 0 ; 💡 追加
            fixedMiscIndex = 0
        EndIf
        ForcePageReset()
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf
    ElseIf option == fixedMiscOID
        fixedMiscIndex = index
        If index > 0
            fixedChestIndex = 0
            fixedBackIndex = 0
            fixedLegacyIndex = 0
            fixedLegacyMaleIndex = 0 ; 💡 追加
            fixedLegacySmallIndex = 0
        EndIf
        ForcePageReset()
        If ASTMain.usesTatoo
            Tattoo.RefreshTattoo()
        EndIf

    ElseIf option == MenuLogoModeID
        LogoDisplayMode = index
        SetMenuOptionValue(option, LogoDisplayModeOptions[LogoDisplayMode])
        
        If LogoDisplayMode == 0 || LogoDisplayMode == 2 || LogoDisplayMode == 3
            ; 常時、非表示、常時小 -> ホットキー解除 (-1)
            If DrainSwitchKey != -1 && ASTMain != None
                ASTMain.UnregisterForKey(DrainSwitchKey)
            EndIf
            DrainSwitchKey = -1
        ElseIf LogoDisplayMode == 1 || LogoDisplayMode == 4
            ; トグル、トグル小 -> ホットキー Hキー(DXScanCode: 35) に自動設定
            If DrainSwitchKey != -1 && ASTMain != None
                ASTMain.UnregisterForKey(DrainSwitchKey)
            EndIf
            DrainSwitchKey = 35
            If ASTMain != None
                ASTMain.RegisterForKey(DrainSwitchKey)
            EndIf
        EndIf
        SetKeyMapOptionValue(KeyDrainCheckID, DrainSwitchKey)

        If LogoDisplayMode == 3 || LogoDisplayMode == 4
            SetSliderOptionValue(SliderLogoXID, LogoSmallX, "{0}")
            SetSliderOptionValue(SliderLogoYID, LogoSmallY, "{0}")
            SetSliderOptionValue(SliderLogoSizeID, LogoSizeSmall, "{1}")
        Else
            SetSliderOptionValue(SliderLogoXID, LogoX, "{0}")
            SetSliderOptionValue(SliderLogoYID, LogoY, "{0}")
            SetSliderOptionValue(SliderLogoSizeID, LogoSize, "{1}")
        EndIf
        ASTR2LogoScript.Get().UpdateLogoDisplay()
    ElseIf option == MenuActorHpModeID
        Int ahpOldKey = ActorHpCheckKey
        ActorHpDisplayMode = index
        SetMenuOptionValue(option, ActorHpModeOptions[ActorHpDisplayMode])
        If ActorHpDisplayMode == 0 || ActorHpDisplayMode == 2
            ActorHpCheckKey = -1
            SetKeyMapOptionValue(KeyActorHpCheckID, -1)
            GetActorHpBar().SetActorHpKey(ahpOldKey, -1)
        ElseIf ActorHpDisplayMode == 1
            ActorHpCheckKey = 35
            SetKeyMapOptionValue(KeyActorHpCheckID, 35)
            GetActorHpBar().SetActorHpKey(ahpOldKey, 35)
        EndIf
    ElseIf option == TechAggMenuOID
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechAggMode", index)
        SetMenuOptionValue(option, TechAggOptions[index])
        ASTR2Technique.RebuildTechCache()   ; 集計方式を変えたらキャッシュ再計算→再描画します
        ForcePageReset()
    ElseIf option == TechOrientMenuOID
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechOrient", index)
        SetMenuOptionValue(option, TechOrientOptions[index])
        ASTR2Technique.RebuildTechCache()   ; 指向を変えたらキャッシュ再計算→再描画します
        ForcePageReset()
    EndIf
EndEvent

Event OnOptionSelect(Int option)
    ASTR2MainScript ASTMain = GetMain()
    ASTLvlManager Lvl = GetLvlManager()
    ASTTattooScript Tattoo = GetTattoo()

    ; 🔮 サーヴァント個別リセット（サーヴァントシップページの各行クリック→確認→解放）。動的OIDなので先頭でFind判定します
    Int svRi = svResetOIDs.Find(option)
    If svRi >= 0
        Actor svTgt = svResetActors[svRi]
        If svTgt
            String[] svArg = new String[1]
            svArg[0] = svTgt.GetDisplayName()
            If ShowMessage(ASTR2Native.LocFmtStr("$ASTR2_Msg_ConfirmRelease", svArg))
                If StorageUtil.FormListHas(Game.GetPlayer(), "ASTR2_VassalList", svTgt)
                    ASTConjCost.AshifyVassal(svTgt)       ; スイート・ヴァッサル(VassalList所属)＝正規除去・灰化→リポップで通常敵。生者は中でKill()＋全解除も同期実行
                Else
                    ASTR2Servantship.ResetServant(svTgt)  ; 生きたままServantshipだけ解除（tier0/pts0/名簿除去）
                EndIf
                ForcePageReset()                          ; 表から即消えます
            EndIf
        EndIf
        Return
    EndIf

    If option == ToggleLifeForceResetID
        LifeForceKeyResetToggle = !LifeForceKeyResetToggle
        SetToggleOptionValue(option, LifeForceKeyResetToggle)
        If LifeForceKeyResetToggle == true
            LifeForceX = LifeForceDefX
            LifeForceY = LifeForceDefY
            LFDisplayMode = 0
            LifeForceCheckKey = -1 
            
            SetSliderOptionValue(SliderLifeForceXID, LifeForceX, "{0}")
            SetSliderOptionValue(SliderLifeForceYID, LifeForceY, "{0}")
            SetMenuOptionValue(MenuLifeForceModeID, DisplayModeOptions[LFDisplayMode])
            SetKeyMapOptionValue(KeyLifeForceCheckID, -1) 
            
            LifeForceKeyResetToggle = false
            SetToggleOptionValue(option, LifeForceKeyResetToggle)
        EndIf
        
    ElseIf option == ToggleExpResetID
        ExpKeyResetToggle = !ExpKeyResetToggle
        SetToggleOptionValue(option, ExpKeyResetToggle)
        If ExpKeyResetToggle == true
            ExpX = ExpDefX
            ExpY = ExpDefY
            ExpDisplayMode = 0
            ExpCheckKey = -1 
            
            SetSliderOptionValue(SliderExpXID, ExpX, "{0}")
            SetSliderOptionValue(SliderExpYID, ExpY, "{0}")
            SetMenuOptionValue(MenuExpModeID, DisplayModeOptions[ExpDisplayMode])
            SetKeyMapOptionValue(KeyExpCheckID, -1) 
            
            ExpKeyResetToggle = false
            SetToggleOptionValue(option, ExpKeyResetToggle)
        EndIf
    ElseIf option == ToggleDrainResetID
        DrainKeyResetToggle = !DrainKeyResetToggle
        SetToggleOptionValue(option, DrainKeyResetToggle)
        If DrainKeyResetToggle == true
            ; 1. すべての変数を初期値に戻す
            LogoX = LogoDefX
            LogoY = LogoDefY
            LogoSize = LogoSizeDef
            LogoSmallX = LogoSmallDefX
            LogoSmallY = LogoSmallDefY
            LogoSizeSmall = LogoSizeSmallDef
            LogoDisplayMode = LogoDisplayModeDef

            If DrainSwitchKey != -1 && ASTMain != None
                ASTMain.UnregisterForKey(DrainSwitchKey)
            EndIf
            DrainSwitchKey = -1

            SetSliderOptionValue(SliderLogoXID, LogoX, "{0}")
            SetSliderOptionValue(SliderLogoYID, LogoY, "{0}")
            SetSliderOptionValue(SliderLogoSizeID, LogoSize, "{1}")
            SetMenuOptionValue(MenuLogoModeID, LogoDisplayModeOptions[LogoDisplayMode])
            SetKeyMapOptionValue(KeyDrainCheckID, DrainSwitchKey)
            
            ASTR2LogoScript.Get().UpdateLogoDisplay()
            
            DrainKeyResetToggle = false
            SetToggleOptionValue(option, DrainKeyResetToggle)
        EndIf
    
    ElseIf option == ToggleActorHpResetID
        ActorHpKeyResetToggle = !ActorHpKeyResetToggle
        SetToggleOptionValue(option, ActorHpKeyResetToggle)
        If ActorHpKeyResetToggle == true
            Int ahpOldKey = ActorHpCheckKey
            InitActorHpDefaults()
            ActorHpDisplayMode = 0
            ActorHpCheckKey = -1
            GetActorHpBar().SetActorHpKey(ahpOldKey, -1)

            SetSliderOptionValue(SliderActorHp1XID, ActorHpBar1X, "{0}")
            SetSliderOptionValue(SliderActorHp1YID, ActorHpBar1Y, "{0}")
            SetSliderOptionValue(SliderActorHp2XID, ActorHpBar2X, "{0}")
            SetSliderOptionValue(SliderActorHp2YID, ActorHpBar2Y, "{0}")
            SetSliderOptionValue(SliderActorHp3XID, ActorHpBar3X, "{0}")
            SetSliderOptionValue(SliderActorHp3YID, ActorHpBar3Y, "{0}")
            SetSliderOptionValue(SliderActorHp4XID, ActorHpBar4X, "{0}")
            SetSliderOptionValue(SliderActorHp4YID, ActorHpBar4Y, "{0}")
            SetMenuOptionValue(MenuActorHpModeID, ActorHpModeOptions[ActorHpDisplayMode])
            SetKeyMapOptionValue(KeyActorHpCheckID, -1)

            ActorHpKeyResetToggle = false
            SetToggleOptionValue(option, ActorHpKeyResetToggle)
        EndIf

    ElseIf option == enableGlowOption
        Tattoo.enableGlow = !(Tattoo.enableGlow)
        Tattoo.RefreshTattoo()
        SetToggleOptionValue(option, Tattoo.enableGlow)

    ElseIf option == RecordResetSaveID
        ; 🏆 セーブ内だけ消去します（確認→このセーブ限りの記録を0に。生涯JSONは残す）
        If ShowMessage("$ASTR2_Msg_ResetRecordsSave", true)
            GetLvlManager().ResetRecordsSave()
            ForcePageReset()
        EndIf

    ElseIf option == RecordResetAllID
        ; 🏆 生涯も消去します（確認→生涯JSON＋セーブ内の両方を0に。レベル等には触れない）
        If ShowMessage("$ASTR2_Msg_ResetRecordsAll", true)
            GetLvlManager().ResetRecordsLifetime()
            GetLvlManager().ResetRecordsSave()
            ForcePageReset()
        EndIf

    EndIf
EndEvent

Event OnOptionKeyMapChange(Int option, Int keyCode, String conflictControl, String conflictName)
    ASTR2MainScript ASTMain = GetMain()

    ; =================================================================
    ; 🌟 1. ライフフォースのホットキー
    ; =================================================================
    If option == KeyLifeForceCheckID
        Bool conflict = false
        If (conflictControl != "" || conflictName != "") && keyCode != 1
            If conflictName == "ASuccubusTaleR2"
                conflict = false
            Else
                String msg = ""
                If conflictName != ""
                    msg = "$ASTR2_KeyConflictMsg1{" + conflictControl + "}conflictControl{" + conflictName + "}conflictName"
                Else
                    msg = "$ASTR2_KeyConflictMsg2{" + conflictControl + "}conflictControl"
                EndIf
                conflict = !ShowMessage(msg, true, "$Yes", "$No")
            EndIf
        EndIf

        If !conflict
            If keyCode == 1 
                LifeForceCheckKey = -1
            Else
                LifeForceCheckKey = keyCode
            EndIf
            
            If ASTMain != None
                ASTMain.SetLifeForceKeybind(LifeForceCheckKey)
            EndIf
            
            SetKeyMapOptionValue(KeyLifeForceCheckID, LifeForceCheckKey)
            
            If LifeForceCheckKey != -1
                LFDisplayMode = 1
                SetMenuOptionValue(MenuLifeForceModeID, DisplayModeOptions[LFDisplayMode]) 
            EndIf
        EndIf

    ; =================================================================
    ; 🌟 2. 経験値のホットキー
    ; =================================================================
    ElseIf option == KeyExpCheckID
        Bool conflict = false
        If (conflictControl != "" || conflictName != "") && keyCode != 1
            If conflictName == "ASuccubusTaleR2"
                conflict = false
            Else
                String msg = ""
                If conflictName != ""
                    msg = "$ASTR2_KeyConflictMsg1{" + conflictControl + "}conflictControl{" + conflictName + "}conflictName"
                Else
                    msg = "$ASTR2_KeyConflictMsg2{" + conflictControl + "}conflictControl"
                EndIf
                conflict = !ShowMessage(msg, true, "$Yes", "$No")
            EndIf
        EndIf

        If !conflict
            If keyCode == 1 
                ExpCheckKey = -1
            Else
                ExpCheckKey = keyCode
            EndIf
            
            If ASTMain != None
                ASTMain.SetExpKeybind(ExpCheckKey)
            EndIf
            
            SetKeyMapOptionValue(KeyExpCheckID, ExpCheckKey)
            
            If ExpCheckKey != -1
                ExpDisplayMode = 1
                SetMenuOptionValue(MenuExpModeID, DisplayModeOptions[ExpDisplayMode])
            EndIf
        EndIf
    ; =================================================================
    ; 🌟 3. ドレインモードのホットキー
    ; =================================================================
    ElseIf option == KeyDrainCheckID
        Bool conflict = false
        If (conflictControl != "" || conflictName != "") && keyCode != 1
            If conflictName == "ASuccubusTaleR2"
                conflict = false
            Else
                String msg = ""
                If conflictName != ""
                    msg = "$ASTR2_KeyConflictMsg1{" + conflictControl + "}conflictControl{" + conflictName + "}conflictName"
                Else
                    msg = "$ASTR2_KeyConflictMsg2{" + conflictControl + "}conflictControl"
                EndIf
                conflict = !ShowMessage(msg, true, "$Yes", "$No")
            EndIf
        EndIf

        If !conflict
            If keyCode == 1
                If DrainSwitchKey != -1
                    ASTMain.UnregisterForKey(DrainSwitchKey)
                EndIf
                DrainSwitchKey = -1
            Else
                If DrainSwitchKey != -1
                    ASTMain.UnregisterForKey(DrainSwitchKey)
                EndIf
                DrainSwitchKey = keyCode
                If ASTMain != None
                    ASTMain.RegisterForKey(DrainSwitchKey)
                EndIf
                If LogoDisplayMode == 3 || LogoDisplayMode == 4
                    LogoDisplayMode = 4 ; スモールモード状態なら「トグル小」へ
                    Else
                    LogoDisplayMode = 1 ; 通常状態なら「トグル」へ
                EndIf
                SetMenuOptionValue(MenuLogoModeID, LogoDisplayModeOptions[LogoDisplayMode])
                ASTR2LogoScript.Get().UpdateLogoDisplay()
            EndIf
            SetKeyMapOptionValue(KeyDrainCheckID, DrainSwitchKey)
        EndIf
    ; =================================================================
    ; 4. アクターHPバーのホットキー
    ; =================================================================
    ElseIf option == KeyActorHpCheckID
        Bool conflict = false
        If (conflictControl != "" || conflictName != "") && keyCode != 1
            If conflictName == "ASuccubusTaleR2"
                conflict = false
            Else
                String msg = ""
                If conflictName != ""
                    msg = "$ASTR2_KeyConflictMsg1{" + conflictControl + "}conflictControl{" + conflictName + "}conflictName"
                Else
                    msg = "$ASTR2_KeyConflictMsg2{" + conflictControl + "}conflictControl"
                EndIf
                conflict = !ShowMessage(msg, true, "$Yes", "$No")
            EndIf
        EndIf

        If !conflict
            Int ahpOldKey = ActorHpCheckKey
            If keyCode == 1
                ActorHpCheckKey = -1
            Else
                ActorHpCheckKey = keyCode
            EndIf
            GetActorHpBar().SetActorHpKey(ahpOldKey, ActorHpCheckKey)
            SetKeyMapOptionValue(KeyActorHpCheckID, ActorHpCheckKey)
            If ActorHpCheckKey != -1
                ActorHpDisplayMode = 1
                SetMenuOptionValue(MenuActorHpModeID, ActorHpModeOptions[ActorHpDisplayMode])
            EndIf
        EndIf
    EndIf
EndEvent



; ── ホバー切替用。ホバーするたび表示フェーズをトグル。4行超は現在値を上固定し下を2枚に分割 ──
Int revivingPhase = 0
Int sedPhase = 0
Int drainPhase = 0
Int distillPhase = 0
Int furyPhase = 0

; リヴァイヴィング・グレイスのinfoを描画＝現在値(ピンク・上固定)＋下ブロックをphaseで切替（0=フレーバー／1=習得条件(白)+注意(水色)）
Function RenderRevivingInfo(Int phase)
    String top = "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_RevivingNow", (GetLFBar().LFenergyMax * 0.10) as Float) + "</font>"
    String body
    If phase == 0
        ; 1枚目＝フレーバー＋習得条件(白)＝計3行(現在値含む)
        body = ASTR2Native.LocFmtF("$ASTR2_Desc_Reviving", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_RevivingReq", 0.0)
    Else
        ; 2枚目＝注意書き2行(水色)＝計3行(現在値含む)
        body = "<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_RevivingNote1", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_RevivingNote2", 0.0) + "</font>"
    EndIf
    ASTR2Native.SetInfoHtml(top + "\n" + body)
EndFunction

; 🌸 シンフル・ブレッシング：ラベルを習得状態で出し分け（習得→効果名ownedKey／未習得→「罪名：未知の効果」unkKey）＝未習得は効果を伏せる
String Function NailLabel(String ownedKey, String unkKey, Int idx, String catColor)
    If !ASTR2NailManager.IsOwned(idx)
        Return "<font color='#999999'>" + ASTR2Native.LocFmtF(unkKey, 0.0) + "</font>"   ; 未習得＝薄グレー（DISABLEDだとホバーinfoが出ないので"グレーアウト風"の色で代用）
    EndIf
    String lbl = ASTR2Native.LocFmtF(ownedKey, 0.0)
    If SkyVault.GetInt(None, "ASTR2_NailActive_" + idx, 0) == 1
        ; 発動中＝「:」以降の効果名だけカテゴリ色（区切りは半角:＝ASCIIリテラルでコンパイル可・JP/EN共通）
        String[] parts = StringUtil.Split(lbl, ":")
        If parts.Length >= 2
            Return parts[0] + ":<font color='" + catColor + "'>" + parts[1] + "</font>"
        EndIf
        Return "<font color='" + catColor + "'>" + lbl + "</font>"   ; 「:」が無い時は全体色（保険）
    EndIf
    Return lbl
EndFunction

; 🌸 シンフル・ブレッシング：ホバーinfoを習得状態で出し分け（習得→現在値+効果ownedHtml／未習得→「未知の効果」メッセージ＝効果を伏せる）
Function RenderNailInfo(Int idx, String ownedHtml)
    If ASTR2NailManager.IsOwned(idx)
        ASTR2Native.SetInfoHtml(ownedHtml)
    Else
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_NailUnknownInfo", 0.0))
    EndIf
EndFunction

; 🌸 シンフル・ブレッシング：状態別の値文字列。未習得→未収得／効果ON(カテゴリ相乗)→valOn(現在値)／習得済だが未発動→未発動
String Function NailVal(Int idx, String valOn, String catColor)
    If !ASTR2NailManager.IsOwned(idx)
        Return "<font color='#999999'>" + ASTR2Native.LocFmtF("$ASTR2_NailState_NotOwned", 0.0) + "</font>"   ; 未習得＝薄グレー
    ElseIf SkyVault.GetInt(None, "ASTR2_NailActive_" + idx, 0) == 1
        Return "<font color='" + catColor + "'>" + valOn + "</font>"   ; 発動中＝現在値をカテゴリ色で目立たせる
    Else
        Return "$ASTR2_NailState_Off"
    EndIf
EndFunction

; =====================================================================================
; 💡 ID方式のオプション用：インフォメーションテキスト（説明文）の一括管理
; =====================================================================================
Event OnOptionHighlight(Int option)
    If option == proteusCatFilterOID
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_ProteusCatFilter", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_ProteusCatFilter2", 0.0))   ; 2行固定
        Return
    EndIf
    Int phiIdx = 0
    While phiIdx < proteusIndivCount   ; 🌊 個体別ボディの行ホバー＝共通info
        If option == ProteusActorOIDs[phiIdx]
            ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_ProteusIndiv", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_ProteusIndiv2", 0.0))   ; 2行固定
            Return
        EndIf
        phiIdx += 1
    EndWhile
    If option == SliderLifeForceXID || option == SliderExpXID
        SetInfoText("$ASTR2_Info_SliderX") 
    ElseIf option == SliderLifeForceYID || option == SliderExpYID
        SetInfoText("$ASTR2_Info_SliderY") 
    ElseIf option == MenuLifeForceModeID || option == MenuExpModeID
        SetInfoText("$ASTR2_Info_DisplayMode") 
    ElseIf option == KeyLifeForceCheckID || option == KeyExpCheckID
        SetInfoText("$ASTR2_Info_CheckKey") 
    ElseIf option == ToggleLifeForceResetID || option == ToggleExpResetID
        SetInfoText("$ASTR2_Info_ResetUI") 

    ElseIf option == tattooLeveledMenuOption
        SetInfoText("$ASTR2_Info_TattooType")
    ElseIf option == enableGlowOption
        SetInfoText("$ASTR2_Info_GlowEffect")
        
    ElseIf option == SliderActorHp1XID || option == SliderActorHp2XID || option == SliderActorHp3XID || option == SliderActorHp4XID
        SetInfoText("$ASTR2_Info_SliderXHP")
    ElseIf option == SliderActorHp1YID || option == SliderActorHp2YID || option == SliderActorHp3YID || option == SliderActorHp4YID
        SetInfoText("$ASTR2_Info_SliderYHP")
    ElseIf option == MenuActorHpModeID
        SetInfoText("$ASTR2_Info_ActorHpMode")
    ElseIf option == KeyActorHpCheckID
        SetInfoText("$ASTR2_Info_CheckKey")
    ElseIf option == ToggleActorHpResetID
        SetInfoText("$ASTR2_Info_ResetUI")
    ElseIf option == SliderLogoXID
        SetInfoText("$ASTR2_Info_SliderX") 
    ElseIf option == SliderLogoYID
        SetInfoText("$ASTR2_Info_SliderY") 
    ElseIf option == MenuLogoModeID
        SetInfoText("$ASTR2_Info_LogoDisplayMode") 
    ElseIf option == KeyDrainCheckID
        SetInfoText("$ASTR2_Info_DrainCheckKey") 
    ElseIf option == ToggleDrainResetID
        SetInfoText("$ASTR2_Info_ResetLogoUI")
    ElseIf option == SliderLogoSizeID
        SetInfoText("$ASTR2_Info_LogoSize")
    ElseIf option == fixedChestOID
        SetInfoText("$ASTR2_Info_FixedChest")
    ElseIf option == fixedBackOID
        SetInfoText("$ASTR2_Info_FixedBack")
    ElseIf option == fixedLegacyOID
        SetInfoText("$ASTR2_Info_FixedLegacy")
    ElseIf option == fixedLegacySmallOID
        SetInfoText("$ASTR2_Info_FixedLegacySmall")
    ElseIf option == fixedMiscOID
        SetInfoText("$ASTR2_Info_FixedMisc")
    ElseIf option == fixedLegacyMaleOID
        SetInfoText("$ASTR2_Info_FixedLegacyMale")

    ; 🏆 記録ページ：セーブ内の項目（新ゲームでリセットされる旨）
    ElseIf option == XpTotalSaveOID || option == LfTotalSaveOID || option == SexCountSaveOID || option == PartnersSaveOID || option == OrgasmCountSaveOID
        SetInfoText("$ASTR2_Info_RecordSave")
    ; 記録ページ：生涯の項目（セーブをまたいで永続する旨）
    ElseIf option == RecTotalXpOID || option == RecTotalLFOID || option == SexCountOID || option == PartnersOID || option == OrgasmCountOID
        SetInfoText("$ASTR2_Info_RecordLifetime")
    ; リセット2ボタン
    ElseIf option == RecordResetSaveID
        SetInfoText("$ASTR2_Info_ResetRecSave")
    ElseIf option == RecordResetAllID
        SetInfoText("$ASTR2_Info_ResetRecAll")
    EndIf

    ; ランキング行（セーブ内3行／生涯3行）はループで貼ったIDなので別途判定。
    ; ★配列はOnPageReset冒頭で先行確保済＝常に非None。`!= None`比較はNoneをInt[]にcastしてログる地雷なので使わず.Lengthで回す。
    int rs = 0
    While rs < RankSaveOIDs.Length
        If option == RankSaveOIDs[rs]
            SetInfoText("$ASTR2_Info_RecordSave")
        EndIf
        rs += 1
    EndWhile
    int rl = 0
    While rl < RankLifeOIDs.Length
        If option == RankLifeOIDs[rl]
            SetInfoText("$ASTR2_Info_RecordLifetime")
        EndIf
        rl += 1
    EndWhile
    int bs = 0
    While bs < BedRankSaveOIDs.Length
        If option == BedRankSaveOIDs[bs]
            SetInfoText("$ASTR2_Info_RecordSave")
        EndIf
        bs += 1
    EndWhile
    int bl = 0
    While bl < BedRankLifeOIDs.Length
        If option == BedRankLifeOIDs[bl]
            SetInfoText("$ASTR2_Info_RecordLifetime")
        EndIf
        bl += 1
    EndWhile
    ; 一番イカせた相手 TOP3（セーブ内／生涯）＝ループ貼りIDなので別途判定（配列はOnPageResetで先行確保済）
    int ci = 0
    While ci < ClimaxRankSaveOIDs.Length
        If option == ClimaxRankSaveOIDs[ci]
            SetInfoText("$ASTR2_Info_RecordSave")
        EndIf
        ci += 1
    EndWhile
    int cl = 0
    While cl < ClimaxRankLifeOIDs.Length
        If option == ClimaxRankLifeOIDs[cl]
            SetInfoText("$ASTR2_Info_RecordLifetime")
        EndIf
        cl += 1
    EndWhile
    ; 総合ランキング（種類別合算）H／いかせ＝セーブ内／生涯。種類別かは見出しで分かるので説明文は個別と同じ
    int gb = 0
    While gb < GenBedSaveOIDs.Length
        If option == GenBedSaveOIDs[gb]
            SetInfoText("$ASTR2_Info_RecordSave")
        EndIf
        gb += 1
    EndWhile
    int gbl = 0
    While gbl < GenBedLifeOIDs.Length
        If option == GenBedLifeOIDs[gbl]
            SetInfoText("$ASTR2_Info_RecordLifetime")
        EndIf
        gbl += 1
    EndWhile
    int gc = 0
    While gc < GenClimaxSaveOIDs.Length
        If option == GenClimaxSaveOIDs[gc]
            SetInfoText("$ASTR2_Info_RecordSave")
        EndIf
        gc += 1
    EndWhile
    int gcl = 0
    While gcl < GenClimaxLifeOIDs.Length
        If option == GenClimaxLifeOIDs[gcl]
            SetInfoText("$ASTR2_Info_RecordLifetime")
        EndIf
        gcl += 1
    EndWhile

    ; ===== H技術スキルページのホバー説明（総合／攻め受け／種目共有／プルダウン）=====
    If option == TechTotalOID
        SetInfoText("$ASTR2_Info_TechTotal")
    ElseIf option == TechAggMenuOID
        SetInfoText("$ASTR2_Info_TechAgg")
    ElseIf option == TechOrientMenuOID
        SetInfoText("$ASTR2_Info_TechOrient")
    EndIf
    int tc = 0
    While tc < TechCatOID.Length
        If option == TechCatOID[tc]
            SetInfoText("$ASTR2_Info_TechCat")
        EndIf
        tc += 1
    EndWhile
    int tsm = 0
    While tsm < TechSMOID.Length
        If option == TechSMOID[tsm]
            SetInfoText("$ASTR2_Info_TechSM")
        EndIf
        tsm += 1
    EndWhile
    ; 孫(個別行為)＝次のランクまであと何秒（rank10は「最大ランク」）。グレーアウト行はSkyUIがホバーを拾わない
    int ta = 0
    While ta < TechActOID.Length
        If TechActOID[ta] != 0 && option == TechActOID[ta]
            ; ★秒数だけで判定しない＝GetSecondsToNextRankAtはランク10(最大)でもランク0(未経験)でも0を返すので、ランク実数で見分ける
            Int actRank = ASTR2Technique.GetActionRankAt(ta)
            If actRank >= 10
                SetInfoText("$ASTR2_Info_TechMaxRank")
            ElseIf actRank <= 0
                SetInfoText("$ASTR2_Info_TechUntrained")
            Else
                SetInfoText(ASTR2Native.LocFmtF("$ASTR2_Info_TechNext", ASTR2Technique.GetSecondsToNextRankAt(ta) as Float))
            EndIf
        EndIf
        ta += 1
    EndWhile

    int m = 0
    String dtag
    Float sp
    Float[] shardCosts
    Float[] reanimVals
    Float[] weaknessVals
    String[] ravenVals   ; 小数化：LocFmtStr(文字列差し込み)で範囲mを小数1桁表示するためString[]（魔法メニューと値を一致させる）
    String[] sArg        ; 単値の小数差し込み用(Gula/Lust成功率/Consume)
    String ravenNowKey
    Int ravNpc
    Int ravFol
    String[] flowVals    ; 小数化：回復%/秒を小数1桁表示するためString[]
    Float[] lustVals
    Float[] orgSelf
    Float[] orgNpc
    ASTLvlManager orgLvl
    Int furyLv
    String furySkKey
    String furyRsKey
    String furyFxKey
    String furyL3
    String[] furyA2
    String[] furyA3
    While m < MagicOptionIDs.Length   ; ★上限は配列長に追従（固定数値だと既存セーブで配列が古いサイズのまま＝m>=旧サイズが範囲外読み→info落ちするため）
        If MagicOptionIDs[m] != 0 && option == MagicOptionIDs[m]
            dtag = MagicDescTags[m]
            If dtag == "$ASTR2_Desc_Nightmare"
                ; 夢魔＝①成功確率(実数・ピンク)②影響(水色)③フレーバー
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_NightmareChance", ASTR2NightmareEffect.GetNightmareChance() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_NmFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Nightmare", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Seduction" || dtag == "$ASTR2_Desc_Area" || dtag == "$ASTR2_Desc_Mass"
                ; 魅了系＝現在値(ピンク・上固定)＋下をホバー切替(1枚目=影響する値(水色)／2枚目=フレーバー2行)。4行→2枚に分割
                sp = ASTSedMagEffScript.GetBaseSeductionSpike()
                If sedPhase == 0
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedRise", sp) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedFactors", 0.0) + "</font>")
                Else
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedRise", sp) + "</font>\n" + ASTR2Native.LocFmtF(dtag, 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SedFlavor2", 0.0))
                EndIf
                sedPhase = 1 - sedPhase
            ElseIf dtag == "$ASTR2_Desc_ServantSync"
                ; サーヴァントシンク＝他と異なる特別枠。①対応表(ピンク・横並び)を先頭へ②説明③ティア説明。数値なし＝LocFmtで訳文化のみ
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SyncTable", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_ServantSync", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SyncTier", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Drain"
                ; ドレイン＝量(ピンク・上固定)＋下をホバー切替(1枚目=影響(水色)／2枚目=フレーバー2行)。4行→2枚に分割
                If drainPhase == 0
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainNow", ASTDrainScript.GetBaseDrainPerSec() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainFactors", 0.0) + "</font>")
                Else
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainNow", ASTDrainScript.GetBaseDrainPerSec() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Drain", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainFlavor2", 0.0))
                EndIf
                drainPhase = 1 - drainPhase
            ElseIf dtag == "$ASTR2_Desc_Ravenous"
                ; ラヴェナス・ドレイン＝①現在値(威力/範囲/人数＋NPC/フォロワー状態・ピンク3値)②影響(水色)③フレーバー。NPC/フォロワーON/OFFはSkyVault直読みでNowキーを4択
                ravenVals = new String[3]
                ravenVals[0] = (ASTDrainScript.GetBaseDrainPerSec() as Int) as String   ; 威力＝整数(魔法メニューと一致)
                ravenVals[1] = ASTR2Native.Fmt1(ASTR2Native.GetRavenousRange())          ; 範囲m＝小数1桁
                ravenVals[2] = (ASTR2Native.GetRavenousMaxTargets() as Int) as String    ; 人数＝整数
                ravNpc = SkyVault.GetInt(None, "ASTR2_RavenousNpcToo", 0)
                ravFol = SkyVault.GetInt(None, "ASTR2_RavenousFollowerToo", 0)
                ravenNowKey = "$ASTR2_Info_RavenousNow00"
                If ravNpc == 1 && ravFol == 1
                    ravenNowKey = "$ASTR2_Info_RavenousNow11"
                ElseIf ravNpc == 1
                    ravenNowKey = "$ASTR2_Info_RavenousNow10"
                ElseIf ravFol == 1
                    ravenNowKey = "$ASTR2_Info_RavenousNow01"
                EndIf
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr(ravenNowKey, ravenVals) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_RavenousFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Ravenous", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Consume"
                ; コンスーム・エッセンス＝①再生量(実数%/秒・ピンク)②影響(水色)③フレーバー。getterはFloat返し
                sArg = new String[1]
                sArg[0] = ASTR2Native.Fmt1(ASTDrainScript.GetRegenPctPerSec())   ; 再生%/秒＝小数1桁
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_Info_ConsumeNow", sArg) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_ConsumeFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Consume", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Flow"
                ; エッセンス・フロウ＝①現在値(回復%/秒＋維持LF/秒・ピンク2値)②影響(水色)③フレーバー。コンスーム・エッセンスの上位なので同形。getterはOFF中も「今ONなら幾つ」プレビュー返し
                flowVals = new String[2]
                flowVals[0] = ASTR2Native.Fmt1(ASTR2Native.GetFlowHealNow())              ; 回復%/秒＝小数1桁
                flowVals[1] = (ASTR2Native.GetFlowCostNow() as Int) as String             ; 維持LF/秒＝整数
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_Info_FlowNow", flowVals) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_FlowFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Flow", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Shard"
                ; クリエイト・シャード＝①全サイズ別コスト(5値LocFmt・ピンク)②習得Lv表(水色)③フレーバー。サイズ語は$キー直書き＝コスト数値だけ差し込み
                shardCosts = new Float[5]
                shardCosts[0] = ASTR2CreateShardEffect.GetShardCost(0) as Float
                shardCosts[1] = ASTR2CreateShardEffect.GetShardCost(1) as Float
                shardCosts[2] = ASTR2CreateShardEffect.GetShardCost(2) as Float
                shardCosts[3] = ASTR2CreateShardEffect.GetShardCost(3) as Float
                shardCosts[4] = ASTR2CreateShardEffect.GetShardCost(4) as Float
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_ShardCosts", shardCosts) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_ShardLevels", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Shard", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Reanim"
                ; スイート・ヴァッサル＝①現在値(蘇生日数＋コスト・ピンク2値)②影響値(水色)③フレーバー＝他アビと同形。使役中の一覧は下の「スイート・ヴァッサルの死霊一覧」項目へ分離
                reanimVals = new Float[2]
                reanimVals[0] = ASTConjCost.GetSweetVassalDays()
                reanimVals[1] = ASTDrainScript.GetReanimCost() as Float
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_ReanimNow", reanimVals) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_ReanimFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Reanim", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Reviving"
                ; リヴァイヴィング・グレイス＝現在値(ピンク・上固定)＋下を[フレーバー]⇄[習得条件(白)+注意(水色)]を「ホバーするたび」トグル。SkyUIはハイライト時しかinfo更新しない＝再ホバーで切替
                RenderRevivingInfo(revivingPhase)
                revivingPhase = 1 - revivingPhase
            ElseIf dtag == "$ASTR2_Desc_Weakness"
                ; サキュバス・ウィークネス＝①現在値(耐性ダウン＋H倍率%・ピンク2値)②効果(水色)③フレーバー。HMult×1.2は+20%で表示(LocFmtは小数切り捨てのため)
                weaknessVals = new Float[2]
                weaknessVals[0] = ASTDrainScript.GetWeaknessResistDown() as Float
                weaknessVals[1] = (ASTDrainScript.GetWeaknessHMult() - 1.0) * 100.0
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_WeaknessVals", weaknessVals) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_WeaknessFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Weakness", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Ember"
                ; エンバー・エッセンス＝①火種の残数ライブ(ピンク・native直読み{0})②効果=火種の説明(水色)③フレーバー。アビリティ自体は表示専用なので②は火種の解説
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Desc_Ember", ASTR2Native.GetPowerTokens() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_EmberFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_EmberFlavor", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Distill"
                ; ディスティル・エッセンス＝消費(淫魔力/マジカ・ピンク2行・上固定)＋下をホバー切替(1枚目=効果(水色)／2枚目=フレーバー)。4行→2枚に分割。値は固定実数なので文面直書き
                If distillPhase == 0
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DistillLF", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_DistillMana", 0.0) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DistillFactors", 0.0) + "</font>")
                Else
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DistillLF", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_DistillMana", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Distill", 0.0))
                EndIf
                distillPhase = 1 - distillPhase
            ElseIf dtag == "$ASTR2_Desc_BuffOrgasm"
                ; オーガズムバフ＝①自分の効果(実数・ピンク)②相手への効果(水色)③発動条件のフレーバー
                orgLvl = GetLvlManager()
                orgSelf = new Float[3]
                orgSelf[0] = orgLvl.GetOrgasmStatBonus() as Float
                orgSelf[1] = orgLvl.GetOrgasmXpPct() as Float
                orgSelf[2] = (orgLvl.GetOrgasmDurSec() / 60) as Float
                orgNpc = new Float[2]
                orgNpc[0] = orgLvl.GetOrgasmNpcHpBonus() as Float
                orgNpc[1] = orgLvl.GetOrgasmNpcRegenPct() as Float
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_OrgasmVals", orgSelf) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmt("$ASTR2_Info_OrgasmNpc", orgNpc) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_BuffOrgasm", 0.0))
            ElseIf dtag == "$ASTR2_Desc_Lust"
                ; アラウジング・ラスト＝①現在値(興奮注入量＋H中ドレイン・ピンク2値)②効果(水色)③フレーバー
                lustVals = new Float[2]
                lustVals[0] = ASTLustEffect.GetBaseLustArousal() as Float
                lustVals[1] = ASTDrainScript.GetHDrainPerOrgasm() as Float
                ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_LustVals", lustVals) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Info_LustFactors", 0.0) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Desc_Lust", 0.0))
            ElseIf dtag == "$ASTR2_NailInfo_Greed"
                RenderNailInfo(6, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_NailNow_Greed", ASTR2NailManager.GetGreedPct() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Greed", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Gula"
                sArg = new String[1]
                sArg[0] = ASTR2Native.Fmt1(ASTR2NailManager.GetGulaPct())   ; 天敵吸引%＝小数1桁(魔法メニューと一致)
                RenderNailInfo(3, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_NailNow_Gula", sArg) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Gula", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Acedia"
                RenderNailInfo(4, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_NailNow_Acedia", ASTR2NailManager.GetLazySpeedPctNow()) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Acedia", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Lust"
                sArg = new String[1]
                sArg[0] = ASTR2Native.Fmt1(ASTR2NailManager.GetLustPctNow())   ; 魅了成功率%＝小数1桁(魔法メニューと一致)／使用回数はLustBudget=整数据置
                RenderNailInfo(2, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_NailNow_Lust", sArg) + " / " + ASTR2Native.LocFmtF("$ASTR2_NailNow_LustBudget", ASTR2NailManager.GetLustSedBudget() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Lust", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Pride"
                RenderNailInfo(1, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_NailNow_PrideSpeech", ASTR2NailManager.GetPrideSpeechPct() as Float) + " / " + ASTR2Native.LocFmtF("$ASTR2_NailNow_PrideTech", ASTR2NailManager.GetPrideTechPct() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Pride", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Wrath"
                RenderNailInfo(0, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_NailNow_WrathDmg", ASTR2NailManager.GetWrathDmgPctNow() as Float) + " (" + ASTR2Native.LocFmtF("$ASTR2_NailNow_WrathHp", ASTR2NailManager.GetWrathHpPct() as Float) + ")</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Wrath", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_NailInfo_Envy"
                RenderNailInfo(5, "<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_NailNow_Envy", ASTR2NailManager.GetEnvyBonusNow() as Float) + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_NailFx_Envy", 0.0) + "</font>")
            ElseIf dtag == "$ASTR2_Desc_Power"
                ; 🔥 アンリーシュド・フューリー＝解放済みだけ現在値付き(ピンク)。B=スキル(GetFuryBoostNow・5種共通+N)/A=%耐性(GetFuryResistNow・cap100)/維持(GetFuryCostNow)・C=固定値。Lvで累積キーを選ぶ＝解放済みだけ並ぶ
                orgLvl = GetLvlManager()
                furyLv = orgLvl.SuccubusLvl.GetValueInt()
                furySkKey = "$ASTR2_FurySkills_1"          ; 破壊(Lv4)
                If furyLv >= 9
                    furySkKey = "$ASTR2_FurySkills_5"      ; +変性(Lv9)
                ElseIf furyLv >= 8
                    furySkKey = "$ASTR2_FurySkills_4"      ; +幻惑(Lv8)
                ElseIf furyLv >= 7
                    furySkKey = "$ASTR2_FurySkills_3"      ; +召喚(Lv7)
                ElseIf furyLv >= 6
                    furySkKey = "$ASTR2_FurySkills_2"      ; +回復(Lv6)
                EndIf
                furyFxKey = "$ASTR2_FuryFixed_1"           ; マジカ再生のみ(Lv4)
                If furyLv >= 5
                    furyFxKey = "$ASTR2_FuryFixed_2"       ; +移動速度・ジャンプ(Lv5)
                EndIf
                ; 2行目＝スキル(B)＋維持コスト
                furyA2 = new String[3]
                furyA2[0] = ASTR2Native.LocFmtF(furySkKey, 0.0)
                furyA2[1] = ASTR2Native.GetFuryBoostNow() as String
                furyA2[2] = ASTR2Native.GetFuryCostNow() as String
                ; 3行目＝耐性(A・Lv5+)＋固定(C)／Lv4は耐性なしなので固定のみ
                If furyLv >= 5
                    furyRsKey = "$ASTR2_FuryResist_1"      ; 落下耐性(Lv5)
                    If furyLv >= 10
                        furyRsKey = "$ASTR2_FuryResist_3"  ; +ダメージカット(Lv10)
                    ElseIf furyLv >= 6
                        furyRsKey = "$ASTR2_FuryResist_2"  ; +魔法耐性(Lv6)
                    EndIf
                    furyA3 = new String[3]
                    furyA3[0] = ASTR2Native.LocFmtF(furyRsKey, 0.0)
                    furyA3[1] = ASTR2Native.GetFuryResistNow() as String
                    furyA3[2] = ASTR2Native.LocFmtF(furyFxKey, 0.0)
                    furyL3 = ASTR2Native.LocFmtStr("$ASTR2_FuryInfoL3", furyA3)
                Else
                    furyA3 = new String[1]
                    furyA3[0] = ASTR2Native.LocFmtF(furyFxKey, 0.0)
                    furyL3 = ASTR2Native.LocFmtStr("$ASTR2_FuryInfoL3NoRes", furyA3)
                EndIf
                ; アンリーシュド・フューリー＝値2行(ピンク・上固定)＋下をホバー切替(1枚目=効果説明(水色Desc_Power)／2枚目=フレーバー)。4行→2枚に分割
                If furyPhase == 0
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_FuryInfoL2", furyA2) + "</font>\n<font color='#ffc5e1'>" + furyL3 + "</font>\n<font color='#73bbf7'>" + ASTR2Native.LocFmtF("$ASTR2_Desc_Power", 0.0) + "</font>")
                Else
                    ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_FuryInfoL2", furyA2) + "</font>\n<font color='#ffc5e1'>" + furyL3 + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_FuryFlavor", 0.0))
                EndIf
                furyPhase = 1 - furyPhase
            Else
                SetInfoText(dtag)
            EndIf
        EndIf
        m += 1
    EndWhile
EndEvent

; =====================================================================================
; 🌟 サキュバス化トグル専用のステート
; =====================================================================================
State SuccubusToggleState
    Event OnSelectST()
        ASTR2MainScript ASTMain = GetMain()
        ASTLvlManager Lvl = GetLvlManager()
        ASTTattooScript Tattoo = GetTattoo()

        If Lvl.IsSuccubus()
            String msg = "$ASTR2_Msg_ReturnOriginal"
            Int raceID = Game.GetPlayer().GetRace().GetFormID()

            If raceID == 0x013746 || raceID == 0x088846
                msg = "$ASTR2_Msg_ReturnNord"
            ElseIf raceID == 0x013741 || raceID == 0x08883A
                msg = "$ASTR2_Msg_ReturnBreton"
            ElseIf raceID == 0x013744 || raceID == 0x088844
                msg = "$ASTR2_Msg_ReturnImperial"
            ElseIf raceID == 0x013748 || raceID == 0x088886
                msg = "$ASTR2_Msg_ReturnRedguard"
            ElseIf raceID == 0x013743 || raceID == 0x088840
                msg = "$ASTR2_Msg_ReturnHighElf"
            ElseIf raceID == 0x013749 || raceID == 0x088887
                msg = "$ASTR2_Msg_ReturnWoodElf"
            ElseIf raceID == 0x013742 || raceID == 0x08883C
                msg = "$ASTR2_Msg_ReturnDarkElf"
            ElseIf raceID == 0x013747 || raceID == 0x088884
                msg = "$ASTR2_Msg_ReturnOrc"
            ElseIf raceID == 0x013745 || raceID == 0x088845
                msg = "$ASTR2_Msg_ReturnKhajiit"
            ElseIf raceID == 0x013740 || raceID == 0x088794
                msg = "$ASTR2_Msg_ReturnArgonian"
            EndIf

            If ShowMessage(msg)
                Lvl.UnSuccuby()
                SetToggleOptionValueST(false)
                ForcePageReset()
            Else
                SetToggleOptionValueST(true)
            EndIf
        Else
            If ShowMessage("$ASTR2_Msg_BecomeSuccubus")
                Lvl.LevelUp()
                Tattoo.RefreshTattoo()
                ASTMain.OnLoadFunc()
                SetToggleOptionValueST(true)
                ForcePageReset()
            Else
                SetToggleOptionValueST(false)
            EndIf
        EndIf
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ToggleMod")
    EndEvent
EndState

; =====================================================================================
; 🌟 タトゥー表示トグル専用のステート
; =====================================================================================
State TattooToggleState
    Event OnSelectST()
        ASTR2MainScript ASTMain = GetMain()
        ASTTattooScript Tattoo = GetTattoo()

        ASTMain.usesTatoo = !ASTMain.usesTatoo
        Tattoo.RefreshTattoo()

        SetToggleOptionValueST(ASTMain.usesTatoo)
        ForcePageReset()
    EndEvent

    Event OnDefaultST()
        ASTR2MainScript ASTMain = GetMain()
        ASTTattooScript Tattoo = GetTattoo()

        ASTMain.usesTatoo = true
        Tattoo.RefreshTattoo()

        SetToggleOptionValueST(ASTMain.usesTatoo)
        ForcePageReset()
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ApplyTattoo")
    EndEvent
EndState

; =====================================================================================
; 🌟 固定タトゥー切替トグル専用ステート
; =====================================================================================
; ===== タトゥーページ：NPC淫紋on/off（StorageUtil Int・ASTTattooScript.ApplyNpcSigilが読む・既定1） =====
State NpcSigilState
    Event OnSelectST()
        Bool nv = !(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1) == 1)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1)
        SetToggleOptionValueST(true)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_NpcSigil")
    EndEvent
EndState

; ===== 火種を他MODのパワーにも使うか（dll保持・ASTR2のパワーは常に対象なので設定に関係なく効く） =====
State PowerTokenOtherModsState
    Event OnSelectST()
        Bool nv = !ASTR2Native.GetPowerTokenOtherMods()
        ASTR2Native.SetPowerTokenOtherMods(nv)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        ASTR2Native.SetPowerTokenOtherMods(true)
        SetToggleOptionValueST(true)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_PowerTokenOtherMods")
    EndEvent
EndState

; ===== サーヴァントシップページ：各ランクの表示人数cap（StorageUtil Int・重さの安全弁） =====
State servantCapState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", 10) as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 30.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
        ForcePageReset()   ; ★表示人数が変わるので一覧を組み直す
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", 10)
        SetSliderOptionValueST(10.0, "{0}")
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ServantCap")
    EndEvent
EndState

; ===== サーヴァントシップページ：愛玩(tier4)の貢ぎ率%（SkyVault Float・PayPetTributeが読む） =====
State petTributeState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_PetTributePct", 1.0))
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.1, 90.0)
        SetSliderDialogInterval(0.1)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_PetTributePct", a_value)
        SetSliderOptionValueST(a_value, "{1}%")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_PetTributePct", 1.0)
        SetSliderOptionValueST(1.0, "{1}%")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_PetTribute")
    EndEvent
EndState

; ===== アビリティコンフィグ：アンリーシュド・フューリーのスキル強化 基礎値（SkyVault Int・C++ Furyが直読み） =====
State furyBaseState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_FuryBase", 10) as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(1.0, 100.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_FuryBase", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_FuryBase", 10)
        SetSliderOptionValueST(10.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ; 🔥 1行目=説明／2行目=グループB(今解放済みのスキル)の現在強化量+N(ピンク)＝ベース値を変えると変化がすぐ分かる
        Int fLv = GetLvlManager().SuccubusLvl.GetValueInt()
        String fsk = "$ASTR2_FurySkills_1"          ; 破壊(Lv4)
        If fLv >= 9
            fsk = "$ASTR2_FurySkills_5"             ; +変性
        ElseIf fLv >= 8
            fsk = "$ASTR2_FurySkills_4"             ; +幻惑
        ElseIf fLv >= 7
            fsk = "$ASTR2_FurySkills_3"             ; +召喚
        ElseIf fLv >= 6
            fsk = "$ASTR2_FurySkills_2"             ; +回復
        EndIf
        String[] fa = new String[2]
        fa[0] = ASTR2Native.LocFmtF(fsk, 0.0)
        fa[1] = ASTR2Native.GetFuryBoostNow() as String
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_FuryBase", 0.0) + "\n<font color='#ffc5e1'>" + ASTR2Native.LocFmtStr("$ASTR2_FuryBaseSkills", fa) + "</font>")
    EndEvent
EndState

State FixedTattooState
    Event OnSelectST()
        ASTTattooScript Tattoo = GetTattoo()
        ASTLvlManager Lvl = GetLvlManager()
        
        Tattoo.fixedTattoo = !Tattoo.fixedTattoo

        If Tattoo.fixedTattoo
            ; 1. 全リセット
            fixedChestIndex = 0
            fixedBackIndex = 0
            fixedLegacyIndex = 0
            fixedLegacySmallIndex = 0
            fixedMiscIndex = 0

            Int currentLvl = Lvl.SuccubusLvl.GetValueInt()
            
            ; レベルを1〜6に収める
            If currentLvl < 1
                currentLvl = 1
            EndIf
            
            If currentLvl > 6
                currentLvl = 6
            EndIf

            Int pSex = Game.GetPlayer().GetActorBase().GetSex() ; 0=Male, 1=Female

            ; 2. 自動振り分けロジック
            If currLeveledTattosIndex == 0 ; Default
                If pSex == 1 ; 女性
                    fixedChestIndex = currentLvl
                Else         ; 男性
                    fixedBackIndex = currentLvl
                EndIf

            ElseIf currLeveledTattosIndex == 1 ; Legacy (レガシー)
                ; レガシーはインデックスとMaleプレフィックス判定で自動処理される
                fixedLegacyIndex = currentLvl
                
            ElseIf currLeveledTattosIndex == 2 ; Chest (胸元)
                fixedChestIndex = currentLvl
                
            ElseIf currLeveledTattosIndex == 3 ; Back (背中)
                fixedBackIndex = currentLvl
            EndIf
        EndIf

        Tattoo.RefreshTattoo()
        SetToggleOptionValueST(Tattoo.fixedTattoo)
        ForcePageReset()
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_FixedTattoo")
    EndEvent
EndState




; =====================================================================================
; ⚙️ State群：細かい設定用
; =====================================================================================
State DrainToggleKeymap
    Event OnKeyMapChangeST(int newKeyCode, string conflictControl, string conflictName)
        ASTR2MainScript ASTMain = GetMain()
        ASTMain.UnregisterForKey(DrainSwitchKey)

        ; 💡 SkyrimのMCM仕様：ESCキー（1）が押されたら「未割り当て（-1）」にする
        If newKeyCode == 1
            DrainSwitchKey = -1
        Else
            DrainSwitchKey = newKeyCode
            ASTMain.RegisterForKey(newKeyCode)
        EndIf
        
        SetKeyMapOptionValueST(DrainSwitchKey)
    EndEvent

    Event OnDefaultST()
        ASTR2MainScript ASTMain = GetMain()
        ASTMain.UnregisterForKey(DrainSwitchKey)
        
        ; 💡 デフォルトボタンを押した時も「未割り当て（-1）」に戻す
        DrainSwitchKey = -1
        SetKeyMapOptionValueST(DrainSwitchKey)
    EndEvent
EndState


State ToggleDisadvantagesState
    Event OnSelectST()
        ASTR2MainScript ASTMain = GetMain()
        ASTR2LifeForceBarScript LFBar = GetLFBar()
        ASTMain.AreDisadvantagesEnabled = !ASTMain.AreDisadvantagesEnabled
        If ASTMain.AreDisadvantagesEnabled
            ASTR2Native.LFDecayStart()   ; ONでLF減衰を開始（〔クロノス〕が発火）
        Else
            ASTR2Native.LFDecayStop()    ; OFFでLF減衰を停止（発火しない）
        EndIf
        LFBar.UpdateLifeForce()
        ASTMain.RefreshBuffsDebuffsEnergy()
        SetToggleOptionValueST(ASTMain.AreDisadvantagesEnabled)
    EndEvent
    Event OnDefaultST()
        ASTR2MainScript ASTMain = GetMain()
        ASTR2LifeForceBarScript LFBar = GetLFBar()
        ASTMain.AreDisadvantagesEnabled = true
        ASTR2Native.LFDecayStart()   ; 既定はON。LF減衰を開始します
        LFBar.UpdateLifeForce()
        ASTMain.RefreshBuffsDebuffsEnergy()
        SetToggleOptionValueST(ASTMain.AreDisadvantagesEnabled)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ToggleDisadvantages") 
    EndEvent
EndState

State energyIncrState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetLFBar().energyIncr)
        SetSliderDialogDefaultValue(0.75)
        SetSliderDialogRange(0, 2.0)
        SetSliderDialogInterval(0.25)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetLFBar().energyIncr = a_value
        SetSliderOptionValueST(GetLFBar().energyIncr, "{2} x")
    EndEvent
    Event OnDefaultST()
        GetLFBar().energyIncr = 0.75
        SetSliderOptionValueST(GetLFBar().energyIncr, "{2} x")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_LFMultiplier") 
    EndEvent
EndState

State energyMaxState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetLFBar().LFMaxMultiplier)
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(1.0, 100.0)
        SetSliderDialogInterval(0.1)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetLFBar().LFMaxMultiplier = a_value
        GetLFBar().RecalcMaxStorage()
        SetSliderOptionValueST(GetLFBar().LFMaxMultiplier, "{1} x")
    EndEvent
    Event OnDefaultST()
        GetLFBar().LFMaxMultiplier = 1.0
        GetLFBar().RecalcMaxStorage()
        SetSliderOptionValueST(GetLFBar().LFMaxMultiplier, "{1} x")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_LFMaxStorage") 
    EndEvent
EndState

State energyUpdateFreq
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetLFBar().energyUpdateFreq as float)
        SetSliderDialogDefaultValue(3)
        SetSliderDialogRange(1, 10)
        SetSliderDialogInterval(1)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetLFBar().energyUpdateFreq = a_value as int
        SetSliderOptionValueST(GetLFBar().energyUpdateFreq as float)
    EndEvent
    Event OnDefaultST()
        GetLFBar().energyUpdateFreq = 3
        SetSliderOptionValueST(GetLFBar().energyUpdateFreq as float)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_LFUpdateFreq") 
    EndEvent
EndState

State checkForIntegrationsState
    Event OnSelectST()
        GetMain().CheckForIntegrations()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_CheckIntegr") 
    EndEvent
EndState

; =========================================================
; ★★★ チート効果（アビリティ方式・冪等）★★★
;   ASTR2_Test[0101CD14] は HP/M/S最大+10000・Magicka再生+400 の Constant/Self アビリティ。
;   AddSpell/RemoveSpell を HasSpell で守るので、何度ロード・再適用しても累積しません（即死バグなし）。
; =========================================================
Function ApplyCheatBuff(Bool on)
    Actor Player = Game.GetPlayer()
    Spell cheatBuff = Game.GetFormFromFile(0x0101CD14, "A Succubus Tale R2.esp") as Spell
    If cheatBuff == None
        Return
    EndIf
    If on && !Player.HasSpell(cheatBuff)
        Player.AddSpell(cheatBuff, false)
    ElseIf !on && Player.HasSpell(cheatBuff)
        Player.RemoveSpell(cheatBuff)
    EndIf
EndFunction
; ★★★ チート効果ここまで ★★★

State EnableCheatsState
    Event OnSelectST()
        areCheatsAllowed = !areCheatsAllowed
        SetToggleOptionValueST(areCheatsAllowed)
        ApplyCheatBuff(areCheatsAllowed)   ; ★B-2=残す チート効果ON/OFF（冪等）
        ForcePageReset()
    EndEvent

    Event OnDefaultST()
        areCheatsAllowed = false
        SetToggleOptionValueST(areCheatsAllowed)
        ApplyCheatBuff(false)   ; ★B-2=残す チート効果も外す
        ForcePageReset()
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_EnableCheat")
    EndEvent
EndState


; 🌟 一括レベルアップ用プルダウンステート
State LvlUpMenuState
    Event OnMenuOpenST()
        SetMenuDialogStartIndex(0)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(cheatLvlMenuArr)
    EndEvent

    Event OnMenuAcceptST(int index)
        ASTLvlManager Lvl = GetLvlManager()
        int loopCount = 0
        
        If index == 0      ; +1 レベル
            loopCount = 1
        ElseIf index == 1  ; +5 レベル
            loopCount = 5
        ElseIf index == 2  ; +10 レベル
            loopCount = 10
        ElseIf index == 3  ; +30 レベル
            loopCount = 30
        ElseIf index == 4  ; 現在のレベルから100(MAX)までの差分を計算
            loopCount = 100 - Lvl.SuccubusLvl.GetValueInt()
        EndIf
        
        ; 安全に既存のLevelUpロジックを指定回数ブン回す
        int i = 0
        While i < loopCount
            Lvl.LevelUp()
            i += 1
        EndWhile
        
        ; 選択後にMCMの数値を同期させるためページを即リフレッシュ
        SetMenuOptionValueST("")
        ForcePageReset()
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_LvlUp")
    EndEvent
EndState

; H中ドレイン1日1回制限トグル（ON=AST再現・24h再ドレイン不可＋相手に淫紋6段階）
; 読み書きは SkyVault `ASTR2_DrainMarkOn`（C++の門番が直読み）。
;   JSONキー名は据え置き（既存Exportと互換）。
State DrainOncePerDayState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_DrainMarkOn", 0) == 1)
        SkyVault.SetInt(None, "ASTR2_DrainMarkOn", nv as Int)
        SetToggleOptionValueST(nv)
        JsonUtil.SetIntValue(GetJsonPath(), "DrainOncePerDay", nv as Int)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_DrainMarkOn", 0)
        SetToggleOptionValueST(false)
        JsonUtil.SetIntValue(GetJsonPath(), "DrainOncePerDay", 0)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_DrainOncePerDay")
    EndEvent
EndState



; 🔥 魅了アロウザルゲート 4スライダー
State seductionLineState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().seductionLinef)
        SetSliderDialogDefaultValue(99.0)
        SetSliderDialogRange(50.0, 99.0)   ; OSLのarousal上限は約99.9996＝100以上は到達不可
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().seductionLinef = a_value
        SetSliderOptionValueST(GetMain().seductionLinef)
    EndEvent
    Event OnDefaultST()
        GetMain().seductionLinef = 99.0
        SetSliderOptionValueST(GetMain().seductionLinef)
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedCurrent", ASTSedMagEffScript.GetBaseSeductionSpike()) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SedLearn", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SeductionLine", 0.0))
    EndEvent
EndState

State seductionBaseState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_SedBase", 50.0))
        SetSliderDialogDefaultValue(50.0)
        SetSliderDialogRange(0.0, 100.0)
        SetSliderDialogInterval(5.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_SedBase", a_value)
        SetSliderOptionValueST(a_value)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_SedBase", 50.0)
        SetSliderOptionValueST(50.0)
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedCurrent", ASTSedMagEffScript.GetBaseSeductionSpike()) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SeductionBase", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：ドレイン 4スライダー（書込先=DrainScriptプロパティ・push方式） =====
State drainHSexBoostState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().GetDrainScript().HSexBoostMult)
        SetSliderDialogDefaultValue(2.0)
        SetSliderDialogRange(1.0, 10.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().GetDrainScript().HSexBoostMult = a_value
        SetSliderOptionValueST(GetMain().GetDrainScript().HSexBoostMult, "{1} x")
    EndEvent
    Event OnDefaultST()
        GetMain().GetDrainScript().HSexBoostMult = 2.0
        SetSliderOptionValueST(GetMain().GetDrainScript().HSexBoostMult, "{1} x")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainHVal", ASTDrainScript.GetHDrainPerOrgasm() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainHSexBoost", 0.0))
    EndEvent
EndState

State drainOrgRateState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().GetDrainScript().OrgasmLFRate)
        SetSliderDialogDefaultValue(0.05)
        SetSliderDialogRange(0.0, 1.0)
        SetSliderDialogInterval(0.01)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().GetDrainScript().OrgasmLFRate = a_value
        SetSliderOptionValueST(GetMain().GetDrainScript().OrgasmLFRate, "{2}")
    EndEvent
    Event OnDefaultST()
        GetMain().GetDrainScript().OrgasmLFRate = 0.05
        SetSliderOptionValueST(GetMain().GetDrainScript().OrgasmLFRate, "{2}")
    EndEvent
    Event OnHighlightST()
        Float[] ov = new Float[2]
        ov[0] = ASTDrainScript.GetOrgasmLFPer100HP() as Float
        ov[1] = GetMain().GetDrainScript().OrgasmLFCap
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_DrainOrgVal", ov) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_DrainOrgRate", 0.0))
    EndEvent
EndState

State drainOrgCapState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().GetDrainScript().OrgasmLFCap)
        SetSliderDialogDefaultValue(2000.0)
        SetSliderDialogRange(0.0, 10000.0)
        SetSliderDialogInterval(100.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().GetDrainScript().OrgasmLFCap = a_value
        SetSliderOptionValueST(GetMain().GetDrainScript().OrgasmLFCap, "{0}")
    EndEvent
    Event OnDefaultST()
        GetMain().GetDrainScript().OrgasmLFCap = 2000.0
        SetSliderOptionValueST(GetMain().GetDrainScript().OrgasmLFCap, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_DrainOrgCap")
    EndEvent
EndState

State drainDestRateState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().GetDrainScript().DestSkillRate)
        SetSliderDialogDefaultValue(1.5)
        SetSliderDialogRange(0.0, 10.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().GetDrainScript().DestSkillRate = a_value
        SetSliderOptionValueST(GetMain().GetDrainScript().DestSkillRate, "{1}")
    EndEvent
    Event OnDefaultST()
        GetMain().GetDrainScript().DestSkillRate = 1.5
        SetSliderOptionValueST(GetMain().GetDrainScript().DestSkillRate, "{1}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_DrainDestRate")
    EndEvent
EndState

; ===== アビリティコンフィグ：ASTR2専用魔法の魔法コスト（SkyVault Float・C++コスト式が読む） =====
State manaCostStepMulState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ManaCostStepMul", 1.67))
        SetSliderDialogDefaultValue(1.67)
        SetSliderDialogRange(1.0, 3.0)
        SetSliderDialogInterval(0.01)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ManaCostStepMul", a_value)
        SetSliderOptionValueST(a_value, "{2}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ManaCostStepMul", 1.67)
        SetSliderOptionValueST(1.67, "{2}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ManaCostStepMul")
    EndEvent
EndState

State manaCostCapPctState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ManaCostCapPct", 100.0))
        SetSliderDialogDefaultValue(100.0)
        SetSliderDialogRange(0.0, 100.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ManaCostCapPct", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ManaCostCapPct", 100.0)
        SetSliderOptionValueST(100.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ManaCostCapPct")
    EndEvent
EndState

State manaCostBurstMulState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ManaCostBurstMul", 5.0))
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(1.0, 10.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ManaCostBurstMul", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ManaCostBurstMul", 5.0)
        SetSliderOptionValueST(5.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ManaCostBurstMul")
    EndEvent
EndState

; ===== アビリティコンフィグ：サーヴァント影響スライダー（書込先=StorageUtil Float on Player・Papyrus側が読む） =====
State svTechInfluenceState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2))
        SetSliderDialogDefaultValue(0.2)
        SetSliderDialogRange(0.0, 0.4)
        SetSliderDialogInterval(0.05)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", a_value)
        SetSliderOptionValueST(a_value, "{2}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2)
        SetSliderOptionValueST(0.2, "{2}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_SvTechInfluence", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SvTechInfluence2", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：Hスキル→相手の興奮（StorageUtil Float・魅了板+C++が読む） =====
State techExciteState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02))
        SetSliderDialogDefaultValue(0.02)
        SetSliderDialogRange(0.0, 0.05)
        SetSliderDialogInterval(0.005)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", a_value)
        SetSliderOptionValueST(a_value, "{3}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02)
        SetSliderOptionValueST(0.02, "{3}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_TechExcite")
    EndEvent
EndState

; ===== アビリティコンフィグ：スイート・ヴァッサルの蘇生コスト（StorageUtil Float・ASTConjCostが読む） =====
State reanimCostState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ReanimCost", 5000.0))
        SetSliderDialogDefaultValue(5000.0)
        SetSliderDialogRange(0.0, 10000.0)
        SetSliderDialogInterval(100.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ReanimCost", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ReanimCost", 5000.0)
        SetSliderOptionValueST(5000.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2LifeForceBarScript LFBar = GetLFBar()
        Int lfMax = LFBar.LFenergyMax
        Int lfCur = LFBar.LFenergyCurr
        Int lfPct = 0
        If lfMax > 0
            lfPct = (lfCur * 100) / lfMax
        EndIf
        Float[] lfv = new Float[3]
        lfv[0] = lfPct as Float
        lfv[1] = lfCur as Float
        lfv[2] = lfMax as Float
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmt("$ASTR2_Info_ReanimLF", lfv) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_ReanimCost", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：スイート・ヴァッサルの蘇生維持ベース値（SkyVault Float・ASTConjCost/C++が読む） =====
State vassalBaseDaysState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_VassalBaseDays", 10.0))
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(1.0, 100.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_VassalBaseDays", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_VassalBaseDays", 10.0)
        SetSliderOptionValueST(10.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_VassalDaysNow", ASTConjCost.GetSweetVassalDays()) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_VassalBaseDays", 0.0))
    EndEvent
EndState

; ===== UI表示：H技術HUDのON/OFF（StorageUtilに保存＋C++へ即push・既定ON） =====
State techHudState
    Event OnSelectST()
        Bool nv = !(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1) == 1)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", nv as Int)
        ASTR2Technique.TechHudSetEnabled(nv)   ; H中でも即反映（シーン開始時はPapyrus側がStorageUtilから再push）
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1)
        ASTR2Technique.TechHudSetEnabled(true)
        SetToggleOptionValueST(true)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_TechHud")
    EndEvent
EndState

; ===== UI表示：H技術HUDのレイアウト（Y/X/行間・どれを動かしても3値まとめてC++へpush＝シーン中でも即動く） =====
Function PushTechHudLayout()
    ASTR2Technique.TechHudSetLayout(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380), StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30), StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40))
EndFunction

; 位置を動かした直後だけ白ダミー5行を出す（5秒カウントダウン→0の1秒後に消える・H中はPapyrus側で無反応）
Function PushTechHudLayoutWithPreview()
    PushTechHudLayout()
    ASTR2Technique.TechHudPreview()
EndFunction

; ===== UI表示：バーに重ねる数字（淫魔力/経験値の共通・SkyVault直読みでC++が描く） =====
State barNumOnState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_BarNumOn", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_BarNumOn", nv as Int)
        SetToggleOptionValueST(nv)
        ForcePageReset()   ; 桁数プルダウンのグレーアウトを切り替える
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_BarNumOn", 1)
        SetToggleOptionValueST(true)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_BarNumbers")
    EndEvent
EndState

; ===== アビリティコンフィグ：オーガズム吸収上限のON/OFF（OFFで上限なし・C++が直読み・SkyVault直） =====
State drainOrgCapOnState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_OrgLFCapOn", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_OrgLFCapOn", nv as Int)
        SetToggleOptionValueST(nv)
        ForcePageReset()   ; 上限値スライダーのグレーアウトを切り替える
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_OrgLFCapOn", 1)
        SetToggleOptionValueST(true)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_DrainOrgCapOn")
    EndEvent
EndState

; ===== アビリティコンフィグ：シンフル・ネイルのネイル装備必須ON/OFF（ON=装備中のみ効果・NailManagerが読む） =====
State nailRequireEquipState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_NailRequireEquip", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_NailRequireEquip", nv as Int)
        SetToggleOptionValueST(nv)
        ASTR2NailManager.RefreshNow()   ; 装備必須の切替を効果へ即反映（付け直し）
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_NailRequireEquip", 1)
        SetToggleOptionValueST(true)
        ASTR2NailManager.RefreshNow()
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_NailRequireEquip", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_NailRequireEquip2", 0.0))   ; 2行固定(1行目ON/2行目OFF)
    EndEvent
EndState

State ravenousFollowerState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_RavenousFollowerToo", 0) == 1)
        SkyVault.SetInt(None, "ASTR2_RavenousFollowerToo", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_RavenousFollowerToo", 0)
        SetToggleOptionValueST(false)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_RavenousFollower")
    EndEvent
EndState

State ravenousNpcState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_RavenousNpcToo", 0) == 1)
        SkyVault.SetInt(None, "ASTR2_RavenousNpcToo", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_RavenousNpcToo", 0)
        SetToggleOptionValueST(false)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_RavenousNpc")
    EndEvent
EndState

; 桁数＝0番目が3桁(既定)／1番目が2桁。保存は桁数そのもの(3 or 2)
State barNumDigitsState
    Event OnMenuOpenST()
        Int idx = 0
        If SkyVault.GetInt(None, "ASTR2_BarNumDigits", 3) == 2
            idx = 1
        EndIf
        SetMenuDialogOptions(BarNumDigitsOptions)
        SetMenuDialogStartIndex(idx)
        SetMenuDialogDefaultIndex(0)
    EndEvent
    Event OnMenuAcceptST(Int index)
        Int digits = 3
        If index == 1
            digits = 2
        EndIf
        SkyVault.SetInt(None, "ASTR2_BarNumDigits", digits)
        SetMenuOptionValueST(BarNumDigitsOptions[index])
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_BarNumDigits", 3)
        SetMenuOptionValueST(BarNumDigitsOptions[0])
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_BarNumDigits")
    EndEvent
EndState

; ===== 〔プロテウス〕：全体の大元／プレイヤーの自動検出／手動ボディ選択（SkyVault） =====
State proteusOnState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_ProteusOn", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_ProteusOn", nv as Int)
        SetToggleOptionValueST(nv)
        ForcePageReset()   ; プレイヤー節のグレーアウトを切替
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_ProteusOn", 1)
        SetToggleOptionValueST(true)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml(ASTR2Native.LocFmtF("$ASTR2_Info_ProteusOn", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_ProteusOn2", 0.0))   ; 2行固定表示
    EndEvent
EndState

State bodyAutoDetectState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_BodyAutoDetect", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_BodyAutoDetect", nv as Int)
        SetToggleOptionValueST(nv)
        ForcePageReset()   ; 手動プルダウンのグレーアウトを切替（自動OFFで手動が生きる）
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_BodyAutoDetect", 1)
        SetToggleOptionValueST(true)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_BodyAutoDetect")
    EndEvent
EndState

State bodyManualState
    Event OnMenuOpenST()
        SetMenuDialogOptions(ProteusBodyOptions)
        SetMenuDialogStartIndex(SkyVault.GetInt(None, "ASTR2_BodyManual", 0))
        SetMenuDialogDefaultIndex(0)
    EndEvent
    Event OnMenuAcceptST(Int index)
        SkyVault.SetInt(None, "ASTR2_BodyManual", index)
        SetMenuOptionValueST(ProteusBodyOptions[index])
        ForcePageReset()   ; 現在のボディ表示を即更新（手動＝実効値）
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_BodyManual", 0)
        SetMenuOptionValueST(ProteusBodyOptions[0])
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_BodyManual")
    EndEvent
EndState

State bodyRedetectState
    Event OnSelectST()
        ASTR2Native.SigilResetBodyCache()   ; 🌊 ボディ判定キャッシュ＋使用済み一覧＋除外(C++連動)を全消去。除外も再検出で解除されます
        ShowMessage("$ASTR2_Msg_BodyRedetected", false, "$OK")   ; リセット通知＝OKのみのメッセージボックス（OKで閉じて終了）
        ForcePageReset()   ; OK後に現在ボディ表示を再判定値へ更新＋除外解除で行が戻る
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_BodyRedetect")
    EndEvent
EndState

; HスキルHUDの位置リセット＝縦/横/行間の3つを既定(380/30/40)へ戻す（押すだけのトグル＝ONにはならない）
State techHudResetState
    Event OnSelectST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40)
        PushTechHudLayoutWithPreview()
        SetToggleOptionValueST(false)
        ForcePageReset()   ; 3本のスライダー表示を既定値へ描き直す
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ResetPosTechHud")
    EndEvent
EndState

State techHudYState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380) as Float)
        SetSliderDialogDefaultValue(380.0)
        SetSliderDialogRange(100.0, 700.0)
        SetSliderDialogInterval(10.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", a_value as Int)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(380.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_TechHudY")
    EndEvent
EndState

State techHudXState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30) as Float)
        SetSliderDialogDefaultValue(30.0)
        SetSliderDialogRange(0.0, 700.0)
        SetSliderDialogInterval(10.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", a_value as Int)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(30.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_TechHudX")
    EndEvent
EndState

State techHudStepState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40) as Float)
        SetSliderDialogDefaultValue(40.0)
        SetSliderDialogRange(20.0, 100.0)
        SetSliderDialogInterval(2.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", a_value as Int)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40)
        PushTechHudLayoutWithPreview()
        SetSliderOptionValueST(40.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_TechHudStep")
    EndEvent
EndState

; ===== UI表示：寵愛警告HUD（表示ON/OFFトグル＋位置3スライダー・SkyVault直読みでC++が毎描画で読む／push不要） =====
State vloveHudOnState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_VLoveHudOn", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_VLoveHudOn", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VLoveHudOn", 1)
        SetToggleOptionValueST(true)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VLoveHudOn")
    EndEvent
EndState

State vloveHudYState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_VLoveHudY", 380) as Float)
        SetSliderDialogDefaultValue(380.0)
        SetSliderDialogRange(100.0, 700.0)
        SetSliderDialogInterval(10.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_VLoveHudY", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VLoveHudY", 380)
        SetSliderOptionValueST(380.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VLoveHudY")
    EndEvent
EndState

State vloveHudXState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_VLoveHudX", 30) as Float)
        SetSliderDialogDefaultValue(30.0)
        SetSliderDialogRange(0.0, 700.0)
        SetSliderDialogInterval(10.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_VLoveHudX", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VLoveHudX", 30)
        SetSliderOptionValueST(30.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VLoveHudX")
    EndEvent
EndState

State vloveHudStepState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_VLoveHudStep", 40) as Float)
        SetSliderDialogDefaultValue(40.0)
        SetSliderDialogRange(20.0, 100.0)
        SetSliderDialogInterval(2.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_VLoveHudStep", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VLoveHudStep", 40)
        SetSliderOptionValueST(40.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VLoveHudStep")
    EndEvent
EndState

State vloveHudResetState
    Event OnSelectST()
        SkyVault.SetInt(None, "ASTR2_VLoveHudY", 380)
        SkyVault.SetInt(None, "ASTR2_VLoveHudX", 30)
        SkyVault.SetInt(None, "ASTR2_VLoveHudStep", 40)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VLoveHudReset")
    EndEvent
EndState

; ===== アビリティコンフィグ：クリエイト・シャードのコスト倍率（淫魔晶1個あたりのLFコストに掛かる・ASTR2CreateShardEffectが読む） =====
State shardCostMultState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ShardCostMult", 1.0))
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.25, 3.0)
        SetSliderDialogInterval(0.05)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ShardCostMult", a_value)
        SetSliderOptionValueST(a_value, "{2}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ShardCostMult", 1.0)
        SetSliderOptionValueST(1.0, "{2}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ShardCostMult")
    EndEvent
EndState

; ===== アビリティコンフィグ：クリエイト・シャードの付呪XP倍率（作成で入る付呪経験値に掛かる） =====
State shardEnchXpMultState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", 1.0))
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.0, 3.0)
        SetSliderDialogInterval(0.1)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", 1.0)
        SetSliderOptionValueST(1.0, "{1}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ShardEnchXpMult")
    EndEvent
EndState

; ===== アビリティコンフィグ：コンスーム・エッセンスの威力（回復%/秒のベース・LifeForceDrainConcが読む） =====
State consumeRegenPctState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_ConsumeRegenPct", 3.0))
        SetSliderDialogDefaultValue(3.0)
        SetSliderDialogRange(1.0, 10.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_ConsumeRegenPct", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_ConsumeRegenPct", 3.0)
        SetSliderOptionValueST(3.0, "{1}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ConsumeRegenPct")
    EndEvent
EndState

; ===== アビリティコンフィグ：コンスーム・エッセンスのコスト（体力1%回復あたりの淫魔力ベース） =====
State consumeLFPerPctState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", 3.5))
        SetSliderDialogDefaultValue(3.5)
        SetSliderDialogRange(1.0, 10.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", 3.5)
        SetSliderOptionValueST(3.5, "{1}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ConsumeLFPerPct")
    EndEvent
EndState

; ===== アビリティコンフィグ：コンスーム・エッセンスで入る回復魔法XPのベース =====
State consumeRestoRateState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", 2.5))
        SetSliderDialogDefaultValue(2.5)
        SetSliderDialogRange(0.0, 10.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", 2.5)
        SetSliderOptionValueST(2.5, "{1}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ConsumeRestoRate")
    EndEvent
EndState

; ===== アビリティコンフィグ：死霊の維持費（6H毎・死霊1体あたり最大淫魔力（LF）の%→/100で小数保存・巡回が読む） =====
State vassalUpkeepState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_VassalUpkeepRate", 0.01) * 100.0)
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.0, 5.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_VassalUpkeepRate", a_value / 100.0)
        SetSliderOptionValueST(a_value, "{1}%")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_VassalUpkeepRate", 0.01)
        SetSliderOptionValueST(1.0, "{1}%")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VassalUpkeep")
    EndEvent
EndState

; ===== 死霊の維持費：未払い通知のON/OFF（既定ON） =====
State vassalUpkeepMissState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyMiss", 1) == 1)
        SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyMiss", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyMiss", 1)
        SetToggleOptionValueST(true)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VassalUpkeepMiss")
    EndEvent
EndState

; ===== 死霊の維持費：支払い通知のON/OFF（6H毎で煩わしいため既定OFF） =====
State vassalUpkeepPaidState
    Event OnSelectST()
        Bool nv = !(SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyPaid", 0) == 1)
        SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyPaid", nv as Int)
        SetToggleOptionValueST(nv)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyPaid", 0)
        SetToggleOptionValueST(false)
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VassalUpkeepPaid")
    EndEvent
EndState

; ===== アビリティコンフィグ：使役体の維持コスト（%スライダー→/100で小数保存・ASTDrainScriptが読む） =====
State vassalTaxState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_VassalTaxRate", 0.01) * 100.0)
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.0, 5.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_VassalTaxRate", a_value / 100.0)
        SetSliderOptionValueST(a_value, "{1}%")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_VassalTaxRate", 0.01)
        SetSliderOptionValueST(1.0, "{1}%")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VassalTax")
    EndEvent
EndState

; ===== アビリティコンフィグ：寵愛の猶予日数（Int保存・ASTDrainScriptが読む） =====
State vassalLoveState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_VassalLoveDays", 3) as Float)
        SetSliderDialogDefaultValue(3.0)
        SetSliderDialogRange(0.0, 10.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_VassalLoveDays", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_VassalLoveDays", 3)
        SetSliderOptionValueST(3.0, "{0}")
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_VassalLove")
    EndEvent
EndState

; ===== アビリティコンフィグ：ナイトメア・エンブレイスの素の成功確率（Lv1基準・StorageUtil Float・ASTR2NightmareEffectが読む） =====
State nmBaseChanceState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_NightmareBaseChance", 10.0))
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 30.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_NightmareBaseChance", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_NightmareBaseChance", 10.0)
        SetSliderOptionValueST(10.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_NmCurrent", ASTR2NightmareEffect.GetNightmareChance() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_NmBaseChance", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_NmBaseChance3", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：ナイトメア・エンブレイスのレベル毎の上昇（StorageUtil Float・ASTR2NightmareEffectが読む） =====
State nmChancePerLvState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_NightmareChancePerLv", 8.0))
        SetSliderDialogDefaultValue(8.0)
        SetSliderDialogRange(0.0, 20.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_NightmareChancePerLv", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_NightmareChancePerLv", 8.0)
        SetSliderOptionValueST(8.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_NmCurrent", ASTR2NightmareEffect.GetNightmareChance() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_NmPerLv", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：サキュバス・ウィークネスの耐性ダウン上限cap（StorageUtil Float・ASTDrainScriptが読む） =====
State weaknessCapState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_WeaknessCap", 100.0))
        SetSliderDialogDefaultValue(100.0)
        SetSliderDialogRange(0.0, 10000.0)
        SetSliderDialogInterval(100.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_WeaknessCap", a_value)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_WeaknessCap", 100.0)
        SetSliderOptionValueST(100.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_WeaknessNow", ASTDrainScript.GetWeaknessResistDown() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_WeaknessCap", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：サキュバス・ウィークネスの耐性ダウン成長係数（StorageUtil Float・ASTDrainScriptが読む） =====
State weaknessGrowthState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_WeaknessPerLv", 1.0))
        SetSliderDialogDefaultValue(1.0)
        SetSliderDialogRange(0.0, 5.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_WeaknessPerLv", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_WeaknessPerLv", 1.0)
        SetSliderOptionValueST(1.0, "{1}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_WeaknessNow", ASTDrainScript.GetWeaknessResistDown() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_WeaknessGrowth", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：アラウジング・ラストの興奮注入量ベース（StorageUtil Int・ASTLustEffectが読む） =====
State lustBaseState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetInt(None, "ASTR2_LustBase", 10) as Float)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(5.0, 30.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetInt(None, "ASTR2_LustBase", a_value as Int)
        SetSliderOptionValueST(a_value, "{0}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetInt(None, "ASTR2_LustBase", 10)
        SetSliderOptionValueST(10.0, "{0}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_LustArousalNow", ASTLustEffect.GetBaseLustArousal() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_LustBase", 0.0))
    EndEvent
EndState

; ===== アビリティコンフィグ：H中ドレインブーストのベース（〔SkyVault〕ASTR2_HSexBoostBase・C++のドレイン核が直読み） =====
State hSexBoostState
    ; ★SkyVault裏打ち（holder=None）。C++のドレイン核が同じ値を直読みする（StorageUtilからは読まれません）
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_HSexBoostBase", 2.0))
        SetSliderDialogDefaultValue(2.0)
        SetSliderDialogRange(1.0, 5.0)
        SetSliderDialogInterval(0.5)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_HSexBoostBase", a_value)
        SetSliderOptionValueST(a_value, "{1}")
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_HSexBoostBase", 2.0)
        SetSliderOptionValueST(2.0, "{1}")
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_HSexBoostNow", ASTDrainScript.GetHDrainPerOrgasm() as Float) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_HSexBoost", 0.0))
    EndEvent
EndState

State seductionStepState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(SkyVault.GetFloat(None, "ASTR2_SedStep", 5.0))
        SetSliderDialogDefaultValue(5.0)
        SetSliderDialogRange(0.0, 15.0)
        SetSliderDialogInterval(1.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        SkyVault.SetFloat(None, "ASTR2_SedStep", a_value)
        SetSliderOptionValueST(a_value)
    EndEvent
    Event OnDefaultST()
        SkyVault.SetFloat(None, "ASTR2_SedStep", 5.0)
        SetSliderOptionValueST(5.0)
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedCurrent", ASTSedMagEffScript.GetBaseSeductionSpike()) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SeductionStep", 0.0))
    EndEvent
EndState

State seductionBonusState
    Event OnSliderOpenST()
        SetSliderDialogStartValue(GetMain().seductionBonusf)
        SetSliderDialogDefaultValue(10.0)
        SetSliderDialogRange(0.0, 30.0)
        SetSliderDialogInterval(5.0)
    EndEvent
    Event OnSliderAcceptST(float a_value)
        GetMain().seductionBonusf = a_value
        SetSliderOptionValueST(GetMain().seductionBonusf)
    EndEvent
    Event OnDefaultST()
        GetMain().seductionBonusf = 10.0
        SetSliderOptionValueST(GetMain().seductionBonusf)
    EndEvent
    Event OnHighlightST()
        ASTR2Native.SetInfoHtml("<font color='#ffc5e1'>" + ASTR2Native.LocFmtF("$ASTR2_Info_SedCurrent", ASTSedMagEffScript.GetBaseSeductionSpike()) + "</font>\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SeductionBonus", 0.0) + "\n" + ASTR2Native.LocFmtF("$ASTR2_Info_SeductionBonus2", 0.0))
    EndEvent
EndState

State progressSpeedMenuState
    Event OnMenuOpenST()
        ASTLvlManager Lvl = GetLvlManager()
        SetMenuDialogStartIndex(Lvl.progressSpeed)
        SetMenuDialogDefaultIndex(0)
        Lvl.RefreshXpIncreaseValue()
        SetMenuDialogOptions(progressSpeedArr)
    EndEvent
    Event OnMenuAcceptST(int index)
        ASTLvlManager Lvl = GetLvlManager()
        Lvl.progressSpeed = index
        Lvl.RefreshXpIncreaseValue()
        SetMenuOptionValueST(progressSpeedArr[Lvl.progressSpeed])
    EndEvent
    Event OnDefaultST()
        ASTLvlManager Lvl = GetLvlManager()
        Lvl.progressSpeed = 2
        Lvl.RefreshXpIncreaseValue()
        SetMenuOptionValueST(progressSpeedArr[Lvl.progressSpeed])
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_Speed")
    EndEvent
EndState

Event OnConfigClose()
    ASTR2MainScript ASTMain = GetMain()
    If ASTMain != None
        ASTMain.Maintenance()
        ASTMain.UpdateHUDVisibility()
    EndIf
    ; 🌟 淫魔力（LF）の最大値を再計算＋バー再描画：チートでLvを上げても淫魔力（LF）の最大値が古いまま残り、
    ;   H中の初回ドレインで遅れて再計算→バーが突然減って見える問題への対策（MCM閉じた瞬間に即反映）。
    ;   LFMaxMultiplierスライダー変更の即時反映も兼ねる。
    ASTR2LifeForceBarScript LFBarClose = GetLFBar()
    If LFBarClose != None
        LFBarClose.RecalcMaxStorage()
        LFBarClose.CheckLifeForce()
    EndIf
    ASTR2LogoScript.Get().UpdateLogoDisplay()
    If bActorHpPosChanged
        bActorHpPosChanged = false
        GetActorHpBar().PreviewPositions()
    EndIf
    ; 💾 オートエクスポートONなら、MCMを閉じた時に全設定を静かに保存
    If bAutoExport
        SaveSettingsToJson(true)
    EndIf
EndEvent
; =====================================================================================
; 🌟 殺害オプション専用ステート
; =====================================================================================
State AllowKillNPCState
    Event OnSelectST()
        ASTR2MainScript ASTMain = GetMain()
        ASTMain.AllowKillNPC = !ASTMain.AllowKillNPC
        ; 一般殺害をOFFにしたらユニーク殺害も連動でOFF（値が1のまま残って「OFFなのに殺せる」を防ぐ）
        If !ASTMain.AllowKillNPC
            ASTMain.AllowKillUnique = false
        EndIf
        SetToggleOptionValueST(ASTMain.AllowKillNPC)
        SyncAllowKillMirror(ASTMain)

        ; 💡 ユニークNPCトグルのグレーアウト状態を即座に反映する
        ForcePageReset()
    EndEvent

    Event OnDefaultST()
        ASTR2MainScript ASTMain = GetMain()
        ASTMain.AllowKillNPC = false
        ASTMain.AllowKillUnique = false
        SetToggleOptionValueST(ASTMain.AllowKillNPC)
        SyncAllowKillMirror(ASTMain)
        ForcePageReset()
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_AllowKillNPC")
    EndEvent
EndState

State AllowKillUniqueState
    Event OnSelectST()
        ; 🚨 一般NPC殺害がOFFの時は、強制的に処理を弾くガード
        ASTR2MainScript ASTMain = GetMain()
        If !ASTMain.AllowKillNPC
            Return
        EndIf

        ASTMain.AllowKillUnique = !ASTMain.AllowKillUnique
        SetToggleOptionValueST(ASTMain.AllowKillUnique)
        SyncAllowKillMirror(ASTMain)
    EndEvent

    Event OnDefaultST()
        ASTR2MainScript ASTMain = GetMain()
        ASTMain.AllowKillUnique = false
        SetToggleOptionValueST(ASTMain.AllowKillUnique)
        SyncAllowKillMirror(ASTMain)
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_AllowKillUnique")
    EndEvent
EndState

; 範囲版ドレイン(C++)がAllowKill設定を読めるようSkyVaultへミラーします
Function SyncAllowKillMirror(ASTR2MainScript ASTMain)
    SkyVault.SetInt(None, "ASTR2_AllowKillNPC", ASTMain.AllowKillNPC as Int)
    SkyVault.SetInt(None, "ASTR2_AllowKillUnique", ASTMain.AllowKillUnique as Int)
EndFunction

State RandomSelectState
    Event OnSelectST()
        bRandomSelectionEnabled = !bRandomSelectionEnabled
        SetToggleOptionValueST(bRandomSelectionEnabled)
    EndEvent

    Event OnDefaultST()
        bRandomSelectionEnabled = true
        SetToggleOptionValueST(bRandomSelectionEnabled)
    EndEvent

    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_RandomSelect")
    EndEvent
EndState
; =====================================================================================
; 💾 JSONプロファイル機能（設定の外部保存 ＆ 自動復元）
; =====================================================================================
State ExportConfigState
    Event OnSelectST()
        SaveSettingsToJson()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ExportConfig")
    EndEvent
EndState

; 🩹 不具合報告ファイル生成：ロジックは ASTR2BugReport.Generate() に集約している。押下で生成先フルパスをMessageBoxに告知します
State genBugReportState
    Event OnSelectST()
        String p = ASTR2BugReport.Generate()
        If p != ""
            SkyVault.SetStr(None, "ASTR2_BugReportPath", p)   ; パスをSKSEに焼く＝下の「格納場所」項目のホバーで常時拾えます
            ShowMessage("$ASTR2_Msg_BugReport", false)   ; 本文は生$キー→SkyUIが翻訳(英語版ランタイムはMessageBox本文がCP1252描画＝LocFmtStrのUTF-8生文字は化けます／$キー翻訳経路だけ日本語OK)
            ASTR2Native.SetInfoHtml(p)                    ; 保存先パスをinfo欄に即表示(押下後・ホバー外れても下の格納場所で再表示可)
        Else
            ShowMessage("$ASTR2_Msg_BugReportFail", false)
        EndIf
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_GenBugReport")
    EndEvent
EndState

; 🩹 格納場所（表示専用）：ホバーするたびSkyVaultに保存したパスをinfo欄に表示する。押下後に表示が一瞬で消えても、この項目にホバーすれば何度でも見られるようにします
State bugPathState
    Event OnSelectST()
        ; 押下不要(表示専用)
    EndEvent
    Event OnHighlightST()
        String bp = SkyVault.GetStr(None, "ASTR2_BugReportPath", "")
        If bp != ""
            ASTR2Native.SetInfoHtml(bp)
        Else
            SetInfoText("$ASTR2_Info_BugReportPathEmpty")
        EndIf
    EndEvent
EndState

State ImportConfigState
    Event OnSelectST()
        LoadSettingsFromJson()
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ImportConfig")
    EndEvent
EndState

; 💾 オートエクスポート：ONならMCMを閉じた時(OnConfigClose)に全設定を自動保存
State AutoExportState
    Event OnSelectST()
        bAutoExport = !bAutoExport
        SetToggleOptionValueST(bAutoExport)
        ; トグル自体もJSONに即書き（セーブをまたいで効くように）
        JsonUtil.SetIntValue(GetJsonPath(), "AutoExport", bAutoExport as Int)
        JsonUtil.Save(GetJsonPath())
    EndEvent
    Event OnDefaultST()
        bAutoExport = false
        SetToggleOptionValueST(bAutoExport)
        JsonUtil.SetIntValue(GetJsonPath(), "AutoExport", 0)
        JsonUtil.Save(GetJsonPath())
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_AutoExport")
    EndEvent
EndState

; 💾 設定オールリセット：全設定を初期値に戻す（確認ダイアログ付き・記録/レベルは触れない）
State ResetAllConfigState
    Event OnSelectST()
        If ShowMessage("$ASTR2_Msg_ResetAllConfig", true)
            ResetAllSettings()
        EndIf
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_ResetAllConfig")
    EndEvent
EndState

; 💾 オートインポート：ONならロード時/ニューゲーム時にConfig.jsonから全設定を自動復元
State AutoImportState
    Event OnSelectST()
        bAutoImport = !bAutoImport
        SetToggleOptionValueST(bAutoImport)
        JsonUtil.SetIntValue(GetJsonPath(), "AutoImport", bAutoImport as Int)
        JsonUtil.Save(GetJsonPath())
    EndEvent
    Event OnDefaultST()
        bAutoImport = false
        SetToggleOptionValueST(bAutoImport)
        JsonUtil.SetIntValue(GetJsonPath(), "AutoImport", 0)
        JsonUtil.Save(GetJsonPath())
    EndEvent
    Event OnHighlightST()
        SetInfoText("$ASTR2_Info_AutoImport")
    EndEvent
EndState


; =====================================================================================
; 💾 JSONプロファイル機能（設定の外部保存 ＆ 自動復元）
; =====================================================================================
string Function GetJsonPath()
    return "ASuccubusTaleR2/Config"
EndFunction

; プレイヤーが設定できる全項目をConfig.jsonへ書き出す（記録・レベルは対象外）。
; silent=true（オート時）はポップアップを出さない。
Function SaveSettingsToJson(Bool silent = false)
    string path = GetJsonPath()
    ASTR2MainScript ASTMain = GetMain()
    ASTLvlManager Lvl = GetLvlManager()
    ASTR2LifeForceBarScript LFBar = GetLFBar()
    ASTTattooScript Tattoo = GetTattoo()

    ; --- 自動フラグ ---
    JsonUtil.SetIntValue(path, "AutoExport", bAutoExport as Int)
    JsonUtil.SetIntValue(path, "AutoImport", bAutoImport as Int)
    JsonUtil.SetIntValue(path, "DrainOncePerDay", SkyVault.GetInt(None, "ASTR2_DrainMarkOn", 0))
    JsonUtil.SetIntValue(path, "EnableCheats", areCheatsAllowed as Int)   ; チート許可（セーブ跨ぎ）

    ; --- UI：ライフフォースバー ---
    JsonUtil.SetFloatValue(path, "LifeForceX", LifeForceX)
    JsonUtil.SetFloatValue(path, "LifeForceY", LifeForceY)
    JsonUtil.SetIntValue(path, "LFDisplayMode", LFDisplayMode)
    JsonUtil.SetIntValue(path, "LifeForceCheckKey", LifeForceCheckKey)
    ; --- UI：経験値バー ---
    JsonUtil.SetFloatValue(path, "ExpX", ExpX)
    JsonUtil.SetFloatValue(path, "ExpY", ExpY)
    JsonUtil.SetIntValue(path, "ExpDisplayMode", ExpDisplayMode)
    JsonUtil.SetIntValue(path, "ExpCheckKey", ExpCheckKey)
    ; --- UI：ロゴ ---
    JsonUtil.SetFloatValue(path, "LogoX", LogoX)
    JsonUtil.SetFloatValue(path, "LogoY", LogoY)
    JsonUtil.SetFloatValue(path, "LogoSmallX", LogoSmallX)
    JsonUtil.SetFloatValue(path, "LogoSmallY", LogoSmallY)
    JsonUtil.SetFloatValue(path, "LogoSize", LogoSize)
    JsonUtil.SetFloatValue(path, "LogoSizeSmall", LogoSizeSmall)
    JsonUtil.SetIntValue(path, "LogoDisplayMode", LogoDisplayMode)
    JsonUtil.SetIntValue(path, "DrainSwitchKey", DrainSwitchKey)
    ; --- UI：アクターHPバー ---
    JsonUtil.SetFloatValue(path, "ActorHpBar1X", ActorHpBar1X)
    JsonUtil.SetFloatValue(path, "ActorHpBar1Y", ActorHpBar1Y)
    JsonUtil.SetFloatValue(path, "ActorHpBar2X", ActorHpBar2X)
    JsonUtil.SetFloatValue(path, "ActorHpBar2Y", ActorHpBar2Y)
    JsonUtil.SetFloatValue(path, "ActorHpBar3X", ActorHpBar3X)
    JsonUtil.SetFloatValue(path, "ActorHpBar3Y", ActorHpBar3Y)
    JsonUtil.SetFloatValue(path, "ActorHpBar4X", ActorHpBar4X)
    JsonUtil.SetFloatValue(path, "ActorHpBar4Y", ActorHpBar4Y)
    JsonUtil.SetIntValue(path, "ActorHpDisplayMode", ActorHpDisplayMode)
    JsonUtil.SetIntValue(path, "ActorHpCheckKey", ActorHpCheckKey)

    ; --- ゲームプレイ ---
    JsonUtil.SetIntValue(path, "progressSpeed", Lvl.progressSpeed)
    JsonUtil.SetIntValue(path, "bRandomSelectionEnabled", bRandomSelectionEnabled as Int)
    JsonUtil.SetIntValue(path, "AllowKillNPC", ASTMain.AllowKillNPC as Int)
    JsonUtil.SetIntValue(path, "AllowKillUnique", ASTMain.AllowKillUnique as Int)
    JsonUtil.SetIntValue(path, "AreDisadvantagesEnabled", ASTMain.AreDisadvantagesEnabled as Int)
    JsonUtil.SetFloatValue(path, "energyIncr", LFBar.energyIncr)
    JsonUtil.SetFloatValue(path, "LFMaxMultiplier", LFBar.LFMaxMultiplier)
    JsonUtil.SetIntValue(path, "energyUpdateFreq", LFBar.energyUpdateFreq)

    ; --- 魅了アロウザルゲート（4パラ） ---
    JsonUtil.SetFloatValue(path, "seductionLinef", ASTMain.seductionLinef)
    JsonUtil.SetFloatValue(path, "seductionBasef", SkyVault.GetFloat(None, "ASTR2_SedBase", 50.0))
    JsonUtil.SetFloatValue(path, "seductionStepf", SkyVault.GetFloat(None, "ASTR2_SedStep", 5.0))
    JsonUtil.SetFloatValue(path, "seductionBonusf", ASTMain.seductionBonusf)

    ; --- ドレイン調整値（アビリティコンフィグ） ---
    JsonUtil.SetFloatValue(path, "HSexBoostMult", GetMain().GetDrainScript().HSexBoostMult)
    JsonUtil.SetFloatValue(path, "OrgasmLFRate",  GetMain().GetDrainScript().OrgasmLFRate)
    JsonUtil.SetFloatValue(path, "OrgasmLFCap",   GetMain().GetDrainScript().OrgasmLFCap)
    JsonUtil.SetFloatValue(path, "DestSkillRate", GetMain().GetDrainScript().DestSkillRate)
    JsonUtil.SetFloatValue(path, "SvTechInfluence", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2))
    JsonUtil.SetFloatValue(path, "TechExciteStrength", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02))
    JsonUtil.SetFloatValue(path, "ManaCostStepMul", SkyVault.GetFloat(None, "ASTR2_ManaCostStepMul", 1.67))
    JsonUtil.SetFloatValue(path, "ManaCostCapPct", SkyVault.GetFloat(None, "ASTR2_ManaCostCapPct", 100.0))
    JsonUtil.SetFloatValue(path, "ManaCostBurstMul", SkyVault.GetFloat(None, "ASTR2_ManaCostBurstMul", 5.0))
    JsonUtil.SetFloatValue(path, "ReanimCost", SkyVault.GetFloat(None, "ASTR2_ReanimCost", 5000.0))
    JsonUtil.SetFloatValue(path, "NightmareBaseChance", SkyVault.GetFloat(None, "ASTR2_NightmareBaseChance", 10.0))
    JsonUtil.SetFloatValue(path, "NightmareChancePerLv", SkyVault.GetFloat(None, "ASTR2_NightmareChancePerLv", 8.0))
    JsonUtil.SetFloatValue(path, "VassalBaseDays", SkyVault.GetFloat(None, "ASTR2_VassalBaseDays", 10.0))
    JsonUtil.SetFloatValue(path, "VassalTaxRate", SkyVault.GetFloat(None, "ASTR2_VassalTaxRate", 0.01))
    JsonUtil.SetFloatValue(path, "VassalUpkeepRate", SkyVault.GetFloat(None, "ASTR2_VassalUpkeepRate", 0.01))
    JsonUtil.SetIntValue(path, "BarNumOn", SkyVault.GetInt(None, "ASTR2_BarNumOn", 1))
    JsonUtil.SetIntValue(path, "OrgLFCapOn", SkyVault.GetInt(None, "ASTR2_OrgLFCapOn", 1))
    JsonUtil.SetIntValue(path, "NailRequireEquip", SkyVault.GetInt(None, "ASTR2_NailRequireEquip", 1))
    JsonUtil.SetIntValue(path, "VLoveHudOn", SkyVault.GetInt(None, "ASTR2_VLoveHudOn", 1))
    JsonUtil.SetIntValue(path, "VLoveHudY", SkyVault.GetInt(None, "ASTR2_VLoveHudY", 380))
    JsonUtil.SetIntValue(path, "VLoveHudX", SkyVault.GetInt(None, "ASTR2_VLoveHudX", 30))
    JsonUtil.SetIntValue(path, "VLoveHudStep", SkyVault.GetInt(None, "ASTR2_VLoveHudStep", 40))
    JsonUtil.SetIntValue(path, "BarNumDigits", SkyVault.GetInt(None, "ASTR2_BarNumDigits", 3))
    JsonUtil.SetIntValue(path, "TechHudEnabled", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1))
    JsonUtil.SetIntValue(path, "TechHudY", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380))
    JsonUtil.SetIntValue(path, "TechHudX", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30))
    JsonUtil.SetIntValue(path, "TechHudStep", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40))
    JsonUtil.SetFloatValue(path, "ShardCostMult", SkyVault.GetFloat(None, "ASTR2_ShardCostMult", 1.0))
    JsonUtil.SetFloatValue(path, "ShardEnchXpMult", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", 1.0))
    JsonUtil.SetFloatValue(path, "ConsumeRegenPct", SkyVault.GetFloat(None, "ASTR2_ConsumeRegenPct", 3.0))
    JsonUtil.SetFloatValue(path, "ConsumeLFPerPct", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", 3.5))
    JsonUtil.SetFloatValue(path, "ConsumeRestoRate", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", 2.5))
    JsonUtil.SetIntValue(path, "VassalUpkeepNotifyMiss", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyMiss", 1))
    JsonUtil.SetIntValue(path, "VassalUpkeepNotifyPaid", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyPaid", 0))
    JsonUtil.SetIntValue(path, "VassalLoveDays", SkyVault.GetInt(None, "ASTR2_VassalLoveDays", 3))
    JsonUtil.SetFloatValue(path, "WeaknessCap", SkyVault.GetFloat(None, "ASTR2_WeaknessCap", 100.0))
    JsonUtil.SetFloatValue(path, "WeaknessPerLv", SkyVault.GetFloat(None, "ASTR2_WeaknessPerLv", 1.0))
    JsonUtil.SetIntValue(path, "NpcSigilEnabled", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1))
    JsonUtil.SetIntValue(path, "PowerTokenOtherMods", ASTR2Native.GetPowerTokenOtherMods() as Int)   ; 火種（Ember）を他MODのパワーにも使うか
    JsonUtil.SetIntValue(path, "LustBase", SkyVault.GetInt(None, "ASTR2_LustBase", 10))
    JsonUtil.SetFloatValue(path, "HSexBoostBase", SkyVault.GetFloat(None, "ASTR2_HSexBoostBase", 2.0))
    JsonUtil.SetIntValue(path, "ServantDisplayCap", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", 10))
    JsonUtil.SetFloatValue(path, "PetTributePct", SkyVault.GetFloat(None, "ASTR2_PetTributePct", 1.0))
    JsonUtil.SetIntValue(path, "FuryBase", SkyVault.GetInt(None, "ASTR2_FuryBase", 10))
    JsonUtil.SetIntValue(path, "ProteusOn", SkyVault.GetInt(None, "ASTR2_ProteusOn", 1))
    JsonUtil.SetIntValue(path, "BodyAutoDetect", SkyVault.GetInt(None, "ASTR2_BodyAutoDetect", 1))
    JsonUtil.SetIntValue(path, "BodyManual", SkyVault.GetInt(None, "ASTR2_BodyManual", 0))
    JsonUtil.SetIntValue(path, "RavenousFollowerToo", SkyVault.GetInt(None, "ASTR2_RavenousFollowerToo", 0))
    JsonUtil.SetIntValue(path, "RavenousNpcToo", SkyVault.GetInt(None, "ASTR2_RavenousNpcToo", 0))

    ; --- 淫紋 ---
    JsonUtil.SetIntValue(path, "usesTatoo", ASTMain.usesTatoo as Int)
    JsonUtil.SetIntValue(path, "currLeveledTattosIndex", currLeveledTattosIndex)
    JsonUtil.SetIntValue(path, "enableGlow", Tattoo.enableGlow as Int)
    JsonUtil.SetIntValue(path, "fixedTattoo", Tattoo.fixedTattoo as Int)
    JsonUtil.SetIntValue(path, "fixedChestIndex", fixedChestIndex)
    JsonUtil.SetIntValue(path, "fixedBackIndex", fixedBackIndex)
    JsonUtil.SetIntValue(path, "fixedLegacyIndex", fixedLegacyIndex)
    JsonUtil.SetIntValue(path, "fixedLegacyMaleIndex", fixedLegacyMaleIndex)
    JsonUtil.SetIntValue(path, "fixedLegacySmallIndex", fixedLegacySmallIndex)
    JsonUtil.SetIntValue(path, "fixedMiscIndex", fixedMiscIndex)

    JsonUtil.Save(path)
    If !silent
        ShowMessage("$ASTR2_Msg_ConfigSaved", false, "$OK")
    EndIf
EndFunction

; Config.jsonから全項目を復元して再適用する。silent=true（オート/ロード時）はポップアップ無し。
Function LoadSettingsFromJson(Bool silent = false)
    string path = GetJsonPath()

    If !JsonUtil.Load(path)
        If !silent
            ShowMessage("$ASTR2_Msg_ConfigNoFile", false, "$OK")
        EndIf
        Return
    EndIf

    ASTR2MainScript ASTMain = GetMain()
    ASTLvlManager Lvl = GetLvlManager()
    ASTR2LifeForceBarScript LFBar = GetLFBar()
    ASTR2ExpBarScript ExpBar = GetExpBar()
    ASTTattooScript Tattoo = GetTattoo()

    ; --- 自動フラグ ---
    bAutoExport = JsonUtil.GetIntValue(path, "AutoExport", bAutoExport as Int) as Bool
    bAutoImport = JsonUtil.GetIntValue(path, "AutoImport", bAutoImport as Int) as Bool
    SkyVault.SetInt(None, "ASTR2_DrainMarkOn", JsonUtil.GetIntValue(path, "DrainOncePerDay", SkyVault.GetInt(None, "ASTR2_DrainMarkOn", 0)))
    areCheatsAllowed = JsonUtil.GetIntValue(path, "EnableCheats", areCheatsAllowed as Int) as Bool
    ApplyCheatBuff(areCheatsAllowed)   ; 読込状態を実体に同期（冪等＝即死バグ防止）

    ; --- UI：ライフフォースバー ---
    LifeForceX = JsonUtil.GetFloatValue(path, "LifeForceX", LifeForceX)
    LifeForceY = JsonUtil.GetFloatValue(path, "LifeForceY", LifeForceY)
    LFDisplayMode = JsonUtil.GetIntValue(path, "LFDisplayMode", LFDisplayMode)
    LifeForceCheckKey = JsonUtil.GetIntValue(path, "LifeForceCheckKey", LifeForceCheckKey)
    ; --- UI：経験値バー ---
    ExpX = JsonUtil.GetFloatValue(path, "ExpX", ExpX)
    ExpY = JsonUtil.GetFloatValue(path, "ExpY", ExpY)
    ExpDisplayMode = JsonUtil.GetIntValue(path, "ExpDisplayMode", ExpDisplayMode)
    ExpCheckKey = JsonUtil.GetIntValue(path, "ExpCheckKey", ExpCheckKey)
    ; --- UI：ロゴ ---
    LogoX = JsonUtil.GetFloatValue(path, "LogoX", LogoX)
    LogoY = JsonUtil.GetFloatValue(path, "LogoY", LogoY)
    LogoSmallX = JsonUtil.GetFloatValue(path, "LogoSmallX", LogoSmallX)
    LogoSmallY = JsonUtil.GetFloatValue(path, "LogoSmallY", LogoSmallY)
    LogoSize = JsonUtil.GetFloatValue(path, "LogoSize", LogoSize)
    LogoSizeSmall = JsonUtil.GetFloatValue(path, "LogoSizeSmall", LogoSizeSmall)
    LogoDisplayMode = JsonUtil.GetIntValue(path, "LogoDisplayMode", LogoDisplayMode)
    DrainSwitchKey = JsonUtil.GetIntValue(path, "DrainSwitchKey", DrainSwitchKey)
    ; --- UI：アクターHPバー ---
    ActorHpBar1X = JsonUtil.GetFloatValue(path, "ActorHpBar1X", ActorHpBar1X)
    ActorHpBar1Y = JsonUtil.GetFloatValue(path, "ActorHpBar1Y", ActorHpBar1Y)
    ActorHpBar2X = JsonUtil.GetFloatValue(path, "ActorHpBar2X", ActorHpBar2X)
    ActorHpBar2Y = JsonUtil.GetFloatValue(path, "ActorHpBar2Y", ActorHpBar2Y)
    ActorHpBar3X = JsonUtil.GetFloatValue(path, "ActorHpBar3X", ActorHpBar3X)
    ActorHpBar3Y = JsonUtil.GetFloatValue(path, "ActorHpBar3Y", ActorHpBar3Y)
    ActorHpBar4X = JsonUtil.GetFloatValue(path, "ActorHpBar4X", ActorHpBar4X)
    ActorHpBar4Y = JsonUtil.GetFloatValue(path, "ActorHpBar4Y", ActorHpBar4Y)
    ActorHpDisplayMode = JsonUtil.GetIntValue(path, "ActorHpDisplayMode", ActorHpDisplayMode)
    ActorHpCheckKey = JsonUtil.GetIntValue(path, "ActorHpCheckKey", ActorHpCheckKey)

    ; --- ゲームプレイ ---
    Lvl.progressSpeed = JsonUtil.GetIntValue(path, "progressSpeed", Lvl.progressSpeed)
    bRandomSelectionEnabled = JsonUtil.GetIntValue(path, "bRandomSelectionEnabled", bRandomSelectionEnabled as Int) as Bool
    ASTMain.AllowKillNPC = JsonUtil.GetIntValue(path, "AllowKillNPC", ASTMain.AllowKillNPC as Int) as Bool
    ASTMain.AllowKillUnique = JsonUtil.GetIntValue(path, "AllowKillUnique", ASTMain.AllowKillUnique as Int) as Bool
    ; 一般殺害がOFFならユニーク殺害も強制OFF（読み込んだ設定の不整合＝OFFなのに殺せる、を正す）
    If !ASTMain.AllowKillNPC
        ASTMain.AllowKillUnique = false
    EndIf
    SyncAllowKillMirror(ASTMain)
    ASTMain.AreDisadvantagesEnabled = JsonUtil.GetIntValue(path, "AreDisadvantagesEnabled", ASTMain.AreDisadvantagesEnabled as Int) as Bool
    LFBar.energyIncr = JsonUtil.GetFloatValue(path, "energyIncr", LFBar.energyIncr)
    LFBar.LFMaxMultiplier = JsonUtil.GetFloatValue(path, "LFMaxMultiplier", LFBar.LFMaxMultiplier)
    LFBar.energyUpdateFreq = JsonUtil.GetIntValue(path, "energyUpdateFreq", LFBar.energyUpdateFreq)

    ; --- 魅了アロウザルゲート（4パラ）---
    ASTMain.seductionLinef = JsonUtil.GetFloatValue(path, "seductionLinef", ASTMain.seductionLinef)
    SkyVault.SetFloat(None, "ASTR2_SedBase", JsonUtil.GetFloatValue(path, "seductionBasef", SkyVault.GetFloat(None, "ASTR2_SedBase", 50.0)))
    SkyVault.SetFloat(None, "ASTR2_SedStep", JsonUtil.GetFloatValue(path, "seductionStepf", SkyVault.GetFloat(None, "ASTR2_SedStep", 5.0)))
    ASTMain.seductionBonusf = JsonUtil.GetFloatValue(path, "seductionBonusf", ASTMain.seductionBonusf)

    ; --- ドレイン調整値（アビリティコンフィグ・ロード時に1回プロパティへ書き込む） ---
    GetMain().GetDrainScript().HSexBoostMult = JsonUtil.GetFloatValue(path, "HSexBoostMult", GetMain().GetDrainScript().HSexBoostMult)
    GetMain().GetDrainScript().OrgasmLFRate  = JsonUtil.GetFloatValue(path, "OrgasmLFRate",  GetMain().GetDrainScript().OrgasmLFRate)
    GetMain().GetDrainScript().OrgasmLFCap   = JsonUtil.GetFloatValue(path, "OrgasmLFCap",   GetMain().GetDrainScript().OrgasmLFCap)
    GetMain().GetDrainScript().DestSkillRate = JsonUtil.GetFloatValue(path, "DestSkillRate", GetMain().GetDrainScript().DestSkillRate)
    StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", JsonUtil.GetFloatValue(path, "SvTechInfluence", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_SvTechInfluence", 0.2)))
    StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", JsonUtil.GetFloatValue(path, "TechExciteStrength", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02)))
    SkyVault.SetFloat(None, "ASTR2_ManaCostStepMul", JsonUtil.GetFloatValue(path, "ManaCostStepMul", SkyVault.GetFloat(None, "ASTR2_ManaCostStepMul", 1.67)))
    SkyVault.SetFloat(None, "ASTR2_ManaCostCapPct", JsonUtil.GetFloatValue(path, "ManaCostCapPct", SkyVault.GetFloat(None, "ASTR2_ManaCostCapPct", 100.0)))
    SkyVault.SetFloat(None, "ASTR2_ManaCostBurstMul", JsonUtil.GetFloatValue(path, "ManaCostBurstMul", SkyVault.GetFloat(None, "ASTR2_ManaCostBurstMul", 5.0)))
    SkyVault.SetFloat(None, "ASTR2_ReanimCost", JsonUtil.GetFloatValue(path, "ReanimCost", SkyVault.GetFloat(None, "ASTR2_ReanimCost", 5000.0)))
    SkyVault.SetFloat(None, "ASTR2_NightmareBaseChance", JsonUtil.GetFloatValue(path, "NightmareBaseChance", SkyVault.GetFloat(None, "ASTR2_NightmareBaseChance", 10.0)))
    SkyVault.SetFloat(None, "ASTR2_NightmareChancePerLv", JsonUtil.GetFloatValue(path, "NightmareChancePerLv", SkyVault.GetFloat(None, "ASTR2_NightmareChancePerLv", 8.0)))
    SkyVault.SetFloat(None, "ASTR2_VassalBaseDays", JsonUtil.GetFloatValue(path, "VassalBaseDays", SkyVault.GetFloat(None, "ASTR2_VassalBaseDays", 10.0)))
    SkyVault.SetFloat(None, "ASTR2_VassalTaxRate", JsonUtil.GetFloatValue(path, "VassalTaxRate", SkyVault.GetFloat(None, "ASTR2_VassalTaxRate", 0.01)))
    SkyVault.SetFloat(None, "ASTR2_VassalUpkeepRate", JsonUtil.GetFloatValue(path, "VassalUpkeepRate", SkyVault.GetFloat(None, "ASTR2_VassalUpkeepRate", 0.01)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", JsonUtil.GetIntValue(path, "TechHudEnabled", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1)))
    SkyVault.SetInt(None, "ASTR2_BarNumOn", JsonUtil.GetIntValue(path, "BarNumOn", SkyVault.GetInt(None, "ASTR2_BarNumOn", 1)))
    SkyVault.SetInt(None, "ASTR2_OrgLFCapOn", JsonUtil.GetIntValue(path, "OrgLFCapOn", SkyVault.GetInt(None, "ASTR2_OrgLFCapOn", 1)))
    SkyVault.SetInt(None, "ASTR2_NailRequireEquip", JsonUtil.GetIntValue(path, "NailRequireEquip", SkyVault.GetInt(None, "ASTR2_NailRequireEquip", 1)))
    SkyVault.SetInt(None, "ASTR2_VLoveHudOn", JsonUtil.GetIntValue(path, "VLoveHudOn", SkyVault.GetInt(None, "ASTR2_VLoveHudOn", 1)))
    SkyVault.SetInt(None, "ASTR2_VLoveHudY", JsonUtil.GetIntValue(path, "VLoveHudY", SkyVault.GetInt(None, "ASTR2_VLoveHudY", 380)))
    SkyVault.SetInt(None, "ASTR2_VLoveHudX", JsonUtil.GetIntValue(path, "VLoveHudX", SkyVault.GetInt(None, "ASTR2_VLoveHudX", 30)))
    SkyVault.SetInt(None, "ASTR2_VLoveHudStep", JsonUtil.GetIntValue(path, "VLoveHudStep", SkyVault.GetInt(None, "ASTR2_VLoveHudStep", 40)))
    SkyVault.SetInt(None, "ASTR2_BarNumDigits", JsonUtil.GetIntValue(path, "BarNumDigits", SkyVault.GetInt(None, "ASTR2_BarNumDigits", 3)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", JsonUtil.GetIntValue(path, "TechHudY", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", JsonUtil.GetIntValue(path, "TechHudX", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", JsonUtil.GetIntValue(path, "TechHudStep", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40)))
    ASTR2Technique.TechHudSetEnabled(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1) == 1)   ; Import直後もC++へ反映
    PushTechHudLayout()   ; レイアウト3値もImport直後にC++へ
    SkyVault.SetFloat(None, "ASTR2_ShardCostMult", JsonUtil.GetFloatValue(path, "ShardCostMult", SkyVault.GetFloat(None, "ASTR2_ShardCostMult", 1.0)))
    StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", JsonUtil.GetFloatValue(path, "ShardEnchXpMult", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ShardEnchXpMult", 1.0)))
    SkyVault.SetFloat(None, "ASTR2_ConsumeRegenPct", JsonUtil.GetFloatValue(path, "ConsumeRegenPct", SkyVault.GetFloat(None, "ASTR2_ConsumeRegenPct", 3.0)))
    StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", JsonUtil.GetFloatValue(path, "ConsumeLFPerPct", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeLFPerPct", 3.5)))
    StorageUtil.SetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", JsonUtil.GetFloatValue(path, "ConsumeRestoRate", StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_ConsumeRestoRate", 2.5)))
    SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyMiss", JsonUtil.GetIntValue(path, "VassalUpkeepNotifyMiss", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyMiss", 1)))
    SkyVault.SetInt(None, "ASTR2_VassalUpkeepNotifyPaid", JsonUtil.GetIntValue(path, "VassalUpkeepNotifyPaid", SkyVault.GetInt(None, "ASTR2_VassalUpkeepNotifyPaid", 0)))
    SkyVault.SetInt(None, "ASTR2_VassalLoveDays", JsonUtil.GetIntValue(path, "VassalLoveDays", SkyVault.GetInt(None, "ASTR2_VassalLoveDays", 3)))
    SkyVault.SetFloat(None, "ASTR2_WeaknessCap", JsonUtil.GetFloatValue(path, "WeaknessCap", SkyVault.GetFloat(None, "ASTR2_WeaknessCap", 100.0)))
    SkyVault.SetFloat(None, "ASTR2_WeaknessPerLv", JsonUtil.GetFloatValue(path, "WeaknessPerLv", SkyVault.GetFloat(None, "ASTR2_WeaknessPerLv", 1.0)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", JsonUtil.GetIntValue(path, "NpcSigilEnabled", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1)))
    ASTR2Native.SetPowerTokenOtherMods(JsonUtil.GetIntValue(path, "PowerTokenOtherMods", ASTR2Native.GetPowerTokenOtherMods() as Int) == 1)   ; 火種（Ember）を他MODのパワーにも使うか。値はdll側が保持。
    SkyVault.SetInt(None, "ASTR2_LustBase", JsonUtil.GetIntValue(path, "LustBase", SkyVault.GetInt(None, "ASTR2_LustBase", 10)))
    SkyVault.SetFloat(None, "ASTR2_HSexBoostBase", JsonUtil.GetFloatValue(path, "HSexBoostBase", SkyVault.GetFloat(None, "ASTR2_HSexBoostBase", 2.0)))
    StorageUtil.SetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", JsonUtil.GetIntValue(path, "ServantDisplayCap", StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_ServantDisplayCap", 10)))
    SkyVault.SetFloat(None, "ASTR2_PetTributePct", JsonUtil.GetFloatValue(path, "PetTributePct", SkyVault.GetFloat(None, "ASTR2_PetTributePct", 1.0)))
    SkyVault.SetInt(None, "ASTR2_FuryBase", JsonUtil.GetIntValue(path, "FuryBase", SkyVault.GetInt(None, "ASTR2_FuryBase", 10)))
    SkyVault.SetInt(None, "ASTR2_ProteusOn", JsonUtil.GetIntValue(path, "ProteusOn", SkyVault.GetInt(None, "ASTR2_ProteusOn", 1)))
    SkyVault.SetInt(None, "ASTR2_BodyAutoDetect", JsonUtil.GetIntValue(path, "BodyAutoDetect", SkyVault.GetInt(None, "ASTR2_BodyAutoDetect", 1)))
    SkyVault.SetInt(None, "ASTR2_BodyManual", JsonUtil.GetIntValue(path, "BodyManual", SkyVault.GetInt(None, "ASTR2_BodyManual", 0)))
    SkyVault.SetInt(None, "ASTR2_RavenousFollowerToo", JsonUtil.GetIntValue(path, "RavenousFollowerToo", SkyVault.GetInt(None, "ASTR2_RavenousFollowerToo", 0)))
    SkyVault.SetInt(None, "ASTR2_RavenousNpcToo", JsonUtil.GetIntValue(path, "RavenousNpcToo", SkyVault.GetInt(None, "ASTR2_RavenousNpcToo", 0)))

    ; --- 淫紋 ---
    ASTMain.usesTatoo = JsonUtil.GetIntValue(path, "usesTatoo", ASTMain.usesTatoo as Int) as Bool
    currLeveledTattosIndex = JsonUtil.GetIntValue(path, "currLeveledTattosIndex", currLeveledTattosIndex)
    Tattoo.enableGlow = JsonUtil.GetIntValue(path, "enableGlow", Tattoo.enableGlow as Int) as Bool
    Tattoo.fixedTattoo = JsonUtil.GetIntValue(path, "fixedTattoo", Tattoo.fixedTattoo as Int) as Bool
    fixedChestIndex = JsonUtil.GetIntValue(path, "fixedChestIndex", fixedChestIndex)
    fixedBackIndex = JsonUtil.GetIntValue(path, "fixedBackIndex", fixedBackIndex)
    fixedLegacyIndex = JsonUtil.GetIntValue(path, "fixedLegacyIndex", fixedLegacyIndex)
    fixedLegacyMaleIndex = JsonUtil.GetIntValue(path, "fixedLegacyMaleIndex", fixedLegacyMaleIndex)
    fixedLegacySmallIndex = JsonUtil.GetIntValue(path, "fixedLegacySmallIndex", fixedLegacySmallIndex)
    fixedMiscIndex = JsonUtil.GetIntValue(path, "fixedMiscIndex", fixedMiscIndex)

    ; 🌟 再適用：表示モードをMainへ反映＋ホットキー再登録＋バー/淫紋/淫魔力（LF）の再計算
    ASTMain.LFDisplayMode = LFDisplayMode
    ASTMain.ExpDisplayMode = ExpDisplayMode
    ASTMain.SetLifeForceKeybind(LifeForceCheckKey)
    ASTMain.SetExpKeybind(ExpCheckKey)
    If DrainSwitchKey > 0
        ASTMain.RegisterForKey(DrainSwitchKey)
    EndIf
    GetActorHpBar().SetActorHpKey(-1, ActorHpCheckKey)
    Lvl.RefreshXpIncreaseValue()
    LFBar.RecalcMaxStorage()
    ExpBar.CheckExp()
    LFBar.CheckLifeForce()
    ASTR2LogoScript.Get().UpdateLogoDisplay()
    ASTMain.RefreshBuffsDebuffsEnergy()   ; ②淫魔力デバフ＝AreDisadvantagesEnabledを即反映（次tick待ちを解消）
    Tattoo.RefreshTattoo()                ; ①usesTatoo ON→適用/OFF→除去 を関数内で判定（無条件で呼ぶ＝OFFも効く）

    If !silent
        ShowMessage("$ASTR2_Msg_ConfigLoaded", false, "$OK")
        ForcePageReset()
    EndIf
EndFunction

; プレイヤー設定をすべて初期値（スクリプト宣言のデフォルト）に戻す。記録・レベルには触れない。
Function ResetAllSettings()
    ASTR2MainScript ASTMain = GetMain()
    ASTLvlManager Lvl = GetLvlManager()
    ASTR2LifeForceBarScript LFBar = GetLFBar()
    ASTR2ExpBarScript ExpBar = GetExpBar()
    ASTTattooScript Tattoo = GetTattoo()

    ; 解除用に旧ホットキーを控える
    Int oldDrainKey = DrainSwitchKey
    Int oldActorHpKey = ActorHpCheckKey

    ; --- UI：ライフフォース ---
    LifeForceX = LifeForceDefX
    LifeForceY = LifeForceDefY
    LFDisplayMode = LFDisplayModeDef
    LifeForceCheckKey = -1
    ; --- UI：経験値 ---
    ExpX = ExpDefX
    ExpY = ExpDefY
    ExpDisplayMode = EXDisplayModeDef
    ExpCheckKey = -1
    ; --- UI：ロゴ ---
    LogoX = LogoDefX
    LogoY = LogoDefY
    LogoSmallX = LogoSmallDefX
    LogoSmallY = LogoSmallDefY
    LogoSize = LogoSizeDef
    LogoSizeSmall = LogoSizeSmallDef
    LogoDisplayMode = LogoDisplayModeDef
    DrainSwitchKey = -1
    ; --- UI：アクターHPバー（各バーのMyDefX/Yから再シード）---
    InitActorHpDefaults()
    ActorHpDisplayMode = ActorHpDisplayModeDef
    ActorHpCheckKey = -1

    ; --- ゲームプレイ（各Property宣言のデフォルト値）---
    Lvl.progressSpeed = 2
    bRandomSelectionEnabled = true
    ASTMain.AllowKillNPC = false
    ASTMain.AllowKillUnique = false
    SyncAllowKillMirror(ASTMain)
    ASTMain.AreDisadvantagesEnabled = true
    LFBar.energyIncr = 0.75
    LFBar.LFMaxMultiplier = 1.0
    LFBar.energyUpdateFreq = 3

    ; --- 淫紋 ---
    ASTMain.usesTatoo = true
    currLeveledTattosIndex = 0
    Tattoo.enableGlow = true
    Tattoo.fixedTattoo = false
    fixedChestIndex = 0
    fixedBackIndex = 0
    fixedLegacyIndex = 0
    fixedLegacyMaleIndex = 0
    fixedLegacySmallIndex = 0
    fixedMiscIndex = 0

    ; --- オートフラグもOFFへ ---
    bAutoExport = false
    bAutoImport = false
    areCheatsAllowed = false   ; チートもデフォルト（OFF）へ
    ApplyCheatBuff(false)      ; チート効果も外す

    ; 🌟 再適用：ホットキー解除＋表示モード反映＋各種の再計算
    ASTMain.LFDisplayMode = LFDisplayMode
    ASTMain.ExpDisplayMode = ExpDisplayMode
    ASTMain.SetLifeForceKeybind(-1)
    ASTMain.SetExpKeybind(-1)
    If oldDrainKey > 0
        ASTMain.UnregisterForKey(oldDrainKey)
    EndIf
    GetActorHpBar().SetActorHpKey(oldActorHpKey, -1)
    Lvl.RefreshXpIncreaseValue()
    LFBar.RecalcMaxStorage()
    ExpBar.CheckExp()
    LFBar.CheckLifeForce()
    ASTR2LogoScript.Get().UpdateLogoDisplay()
    ASTMain.RefreshBuffsDebuffsEnergy()   ; ②淫魔力デバフを即反映（LoadSettingsと揃える）
    Tattoo.RefreshTattoo()

    ; 🌟 外部ファイルも初期値で上書きします（オートインポートでリセットが巻き戻らないようにします）
    SaveSettingsToJson(true)

    ShowMessage("$ASTR2_Msg_ConfigSaved", false, "$OK")
    ForcePageReset()
EndFunction

State NothingState
    Event OnSelectST()
        ; 何もしない
    EndEvent
EndState
