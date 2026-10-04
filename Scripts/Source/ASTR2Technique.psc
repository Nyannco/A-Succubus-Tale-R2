Scriptname ASTR2Technique Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; =====================================================================================
; 👅 Hスキルシステム ― プレイヤー＝サキュバスの行為別スキルです（NPCごとの〔サーヴァントシップ〕とは別物です）。
;   ★計測＝C++(ASTR2-SKSE/Technique.cpp)：OStim NodeChangedで体位変化を拾い、SceneCatalogの行為索引から
;     攻め/受け＋技術カテゴリへ held秒を累積します（OStim中はカタログ参照だけ＝軽いです）。
;   ★ランク層＝C++(ASTR2-SKSE/TechRank.cpp)へ全面移管しています：
;     ① 保存＝StorageUtil→〔SkyVault〕（クロスMODデータ庫です）
;     ② floor-0＝未経験(0秒)=ランク0＝「未経験は威力補正なし」を全魔法で成立させます
;     ③ ライブ成長＝ランク = 〔SkyVault〕確定秒 ＋ 今のシーンのライブ秒です。H中に伸び／イカせ+10秒も即反映します（威力にも即効きます）。
;        確定はシーン終了時にC++が〔SkyVault〕へ足します（回収の自己完結・Papyrus往復なし・二重計上なし）。
;   ★このpscの役目＝native宣言＋設定読み(CurMode/Orient/Body)＋一度きり移行(StorageUtil→〔SkyVault〕)＋旧フック互換stubです。
; =====================================================================================

; --- C++ native：シーン計測（Technique.cpp）---
Function SetExciteEnabled(Bool on) Global Native                   ; 興奮ブースト有効/無効（強さ0でoff）
Function AddOrgasmBonus(String sceneId, Int pos) Global Native     ; 相手イカせ時に今の行為(孫)へ+報酬秒

; --- C++ native：ランク層（TechRank.cpp・〔SkyVault〕確定秒+ライブ秒・floor-0・0〜10）---
Int Function GetActionRank(String actName) Global Native           ; 孫(行為)の現ランク
Int Function GetDisplayCatRank(Int cat) Global Native              ; 表示/威力ランク（cat 0-7・マスク×指向×mode集計・ライブ反映）
Int Function GetDisplayTotalRank() Global Native                   ; 表示/威力の総合ランク
Int Function GetActionAnimCount(Int idx) Global Native            ; 孫スキル精査＝孫idxの実在アニメ本数（0ならMCMでグレーアウト）
Int Function GetActionRankAt(Int idx) Global Native               ; 孫idx(0-53)の個別ランク
String Function GetActionRankDecimalAt(Int idx) Global Native      ; 孫の小数ランク "R.ff"
Int Function GetSecondsToNextRankAt(Int idx) Global Native         ; 孫の「次ランクまであと何秒」
Bool Function IsActionApplicableAt(Int idx) Global Native          ; 孫idxが今の体/指向/modeで加算対象か（グレーアウト判定）
Function SetTechContext(Int mode, Int orient, Int body) Global Native   ; 集計コンテキストをC++へ通知
Function TechHudSetEnabled(Bool on) Global Native                  ; HUD（H中ライブ表示）on/off（TechHud.cpp登録）
Function TechHudSetLayout(Int y, Int x, Int step) Global Native    ; HUD「まとめて」（一番下の行基準：y=下からの上げ幅/x=左マージン/step=行間）
Function TechHudPreview() Global Native                              ; HUD プレビュー（白ダミー5行・5秒カウントダウン後に消える・H中は実際の値優先で空き枠だけダミー／MCM位置スライダー用）

; --- C++ native：一度きり移行（StorageUtilの旧データをPapyrusが読んで〔SkyVault〕へ絶対値セット）---
Function SetCatSecondsRaw(Int cat, Float v) Global Native
Function SetActionSecondsRaw(String name, Int role, Float v) Global Native
Bool Function TechVaultMigrated() Global Native
Function MarkTechVaultMigrated() Global Native

; =====================================================================================
; 🔑 キー定義（移行/外部イテレーション用に残します）
; =====================================================================================
; 8カテゴリのキー名です（C++ TechRank.cpp kCatKey と一致します）。StorageUtil旧キー = "ASTR2_TechSec_<name>"。
String[] Function CatKeys() Global
    String[] k = new String[8]
    k[0] = "Hips"
    k[1] = "Mouth"
    k[2] = "Hand"
    k[3] = "Other"
    k[4] = "Solo"
    k[5] = "Kiss"
    k[6] = "AttackS"
    k[7] = "ReceiveM"
    Return k
EndFunction

; 孫の正規名です（C++ TechRank.cpp kAct と一致・54要素）。移行(StorageUtil→〔SkyVault〕)用です。
String[] Function ActionList() Global
    String[] a = new String[54]
    a[0]  = "vaginalsex"
    a[1]  = "analsex"
    a[2]  = "tribbing"
    a[3]  = "blowjob"
    a[4]  = "deepthroat"
    a[5]  = "cunnilingus"
    a[6]  = "lickingvagina"
    a[7]  = "lickingpenis"
    a[8]  = "lickingtesticles"
    a[9]  = "lickingnipple"
    a[10] = "suckingnipple"
    a[11] = "anilingus"
    a[12] = "handjob"
    a[13] = "vaginalfingering"
    a[14] = "analfingering"
    a[15] = "vaginalfisting"
    a[16] = "analfisting"
    a[17] = "rubbingclitoris"
    a[18] = "gropingbreast"
    a[19] = "gropingbutt"
    a[20] = "gropingtesticles"
    a[21] = "oralfingering"
    a[22] = "vaginaltoying"
    a[23] = "analtoying"
    a[24] = "boobjob"
    a[25] = "footjob"
    a[26] = "thighjob"
    a[27] = "buttjob"
    a[28] = "rubbingpenisagainstface"
    a[29] = "grindingpenis"
    a[30] = "grindingthigh"
    a[31] = "grindingfoot"
    a[32] = "grindingobject"
    a[33] = "femalemasturbation"
    a[34] = "malemasturbation"
    a[35] = "kissing"
    a[36] = "frenchkissing"
    a[37] = "kissingcheek"
    a[38] = "kissingfoot"
    a[39] = "kissinghand"
    a[40] = "kissingneck"
    ; ★41-53の種目はC++ kActCatで指定します（顔面騎乗=腰使い／ディルド膣尻・スパンキング・首絞め=手技／玩具・射精・吸血・焦らし・マッサージ・乳こすり・乳窒息・尻尾技=その他）。
    a[41] = "buttsmothering"
    a[42] = "mdildovaginal"
    a[43] = "mdildoanal"
    a[44] = "spanking"
    a[45] = "choking"
    a[46] = "toy"
    a[47] = "ejaculation"
    a[48] = "vampirebite"
    a[49] = "teasing"
    a[50] = "massaging"
    a[51] = "breastsliding"
    a[52] = "breastsmothering"
    a[53] = "tailtech"
    Return a
EndFunction

; =====================================================================================
; 🎀 設定読み（Papyrus据置）― mode/指向はStorageUtilキー・体(性別)は自動判定します。C++へは SetTechContext で渡します。
; =====================================================================================
Int Function CurMode() Global
    Return StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechAggMode", 0)
EndFunction
Int Function CurOrient() Global
    ; 未設定時のデフォルトは体依存：フタ=両刀(2)／男女=異性愛(0)。プレイヤーが選んだらその値を使います。
    Int def = 0
    If CurBody() == 2
        def = 2
    EndIf
    Return StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechOrient", def)
EndFunction
Int Function CurBody() Global
    Return ASTR2RoleFinder.ClassifySex(Game.GetPlayer())
EndFunction

; 🔁 キャッシュ再構築＝今の mode/指向/体 をC++へ通知します（表示ランクはC++がキャッシュ+ライブで即算出します）。
;   ★MCMが開く時／プルダウン変更時に呼びます。
;   ★ロード後の初回表示に備えて移行(StorageUtil→〔SkyVault〕)も保証します。
Function RebuildTechCache() Global
    MigrateToVaultOnce()
    SetTechContext(CurMode(), CurOrient(), CurBody())
EndFunction

; =====================================================================================
; 🚚 一度きり移行：旧StorageUtilの技術秒 → 〔SkyVault〕（既存プレイヤーの進捗を失わないためです）。
;   ★StorageUtilはPapyrusUtil領なのでC++から読めません→Papyrusで読んで native setter で〔SkyVault〕へ絶対値コピーします。
;   TechVaultMigrated()が真なら即return＝2回目以降は何もしません。
; =====================================================================================
Function MigrateToVaultOnce() Global
    If TechVaultMigrated()
        Return
    EndIf
    Actor pc = Game.GetPlayer()
    String[] keys = CatKeys()
    Int i = 0
    While i < 8
        Float v = StorageUtil.GetFloatValue(pc, "ASTR2_TechSec_" + keys[i], 0.0)
        If v > 0.0
            SetCatSecondsRaw(i, v)
        EndIf
        i += 1
    EndWhile
    String[] acts = ActionList()
    Int j = 0
    While j < acts.Length
        Float s = StorageUtil.GetFloatValue(pc, "ASTR2_TechAct_" + acts[j] + "_S", 0.0)
        Float m = StorageUtil.GetFloatValue(pc, "ASTR2_TechAct_" + acts[j] + "_M", 0.0)
        Float n = StorageUtil.GetFloatValue(pc, "ASTR2_TechAct_" + acts[j] + "_N", 0.0)
        If s > 0.0
            SetActionSecondsRaw(acts[j], 0, s)
        EndIf
        If m > 0.0
            SetActionSecondsRaw(acts[j], 1, m)
        EndIf
        If n > 0.0
            SetActionSecondsRaw(acts[j], 2, n)
        EndIf
        j += 1
    EndWhile
    MarkTechVaultMigrated()   ; ★フラグを立てる＋C++キャッシュ再構築（native内で実施します）
EndFunction

; =====================================================================================
; 🧰 旧フックの互換stubです（ASTR2MainScriptが従来どおり呼びます）。計測/永続はC++が持つので、ここは最小限です。
; =====================================================================================
; シーン開始：①ロード後初回の移行を保証します ②Hスキル→興奮ブーストの有効/無効をC++へ通知します（強さ>0で以後C++がノード毎に飛ばします）。
Function OnSceneStart() Global
    MigrateToVaultOnce()
    Float strength = StorageUtil.GetFloatValue(Game.GetPlayer(), "ASTR2_TechExciteStrength", 0.02)
    SetExciteEnabled(strength > 0.0)
    ; HUD＝MCMトグル(ASTR2_TechHudEnabled・既定ON)をC++へ通知します（シーン開始ごとに同期します）。
    TechHudSetEnabled(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudEnabled", 1) == 1)
    ; HUD レイアウト（MCMスライダー・既定380/30/40）もシーン開始でC++へ同期します。
    TechHudSetLayout(StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudY", 380), StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudX", 30), StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_TechHudStep", 40))
EndFunction
