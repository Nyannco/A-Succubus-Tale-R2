Scriptname ASTR2BugReport Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 🩹 不具合報告ファイルの値集めです。プレイヤーとサキュバスの状態、主要設定を集めて ASTR2Native.WriteBugReport へ渡します。
; MCMボタンの OnSelect から ASTR2BugReport.Generate() を呼ぶだけで、ロジックはこの1本に閉じます。
; 生成先のフルパスを返します（失敗時は""）。MCMのinfo欄に出力先を表示できます。版数・時刻・レアログ末尾はC++側で足します。

; ASTR2の版数です。配布ごとにここを更新します（README/RELEASE_CHECKLIST/FOMOD info.xmlの版と揃える・現行 v1.0.0）。
String Function Version() Global
    Return "1.0.0"
EndFunction

; MCMボタンから呼ぶ本体です。値を集めてC++へ渡し、1枚書き出して生成先フルパスを返します。
String Function Generate() Global
    String esp = "A Succubus Tale R2.esp"
    ; ★MCM・メイン・Lvマネージャは同じクエスト（0x013617）に相乗りしているため、GetLFBarと同じ流儀で各キャストで取得します。
    ASTLvlManager Lvl            = Game.GetFormFromFile(0x013617, esp) as ASTLvlManager
    ASTR2LifeForceBarScript LFBar = Game.GetFormFromFile(0x013618, esp) as ASTR2LifeForceBarScript
    ASTR2MainScript Main         = Game.GetFormFromFile(0x013617, esp) as ASTR2MainScript
    Actor pc = Game.GetPlayer()

    String[] keys = new String[16]
    String[] vals = new String[16]

    keys[0] = "Awakened (succubus mode)"
    If Lvl
        vals[0] = Lvl.IsSuccubus() as String
    Else
        vals[0] = "?(LvlManager None)"
    EndIf

    keys[1] = "Succubus Lv"
    If Lvl && Lvl.SuccubusLvl
        vals[1] = Lvl.SuccubusLvl.GetValueInt() as String
    Else
        vals[1] = "?"
    EndIf

    keys[2] = "Progress speed (0-2)"
    If Lvl
        vals[2] = Lvl.progressSpeed as String
    Else
        vals[2] = "?"
    EndIf

    keys[3] = "Max Essence (max Life Force)"
    If LFBar
        vals[3] = (LFBar.LFenergyMax as Int) as String
    Else
        vals[3] = "?(LFBar None)"
    EndIf

    keys[4] = "Current Essence (now / current Life Force)"
    If LFBar
        vals[4] = (LFBar.LFenergyCurr as Int) as String
    Else
        vals[4] = "?(LFBar None)"
    EndIf

    keys[5] = "OStim API version"
    Int oVer = -1
    If Main && Main.ostim
        oVer = Main.ostim.GetAPIVersion()
    EndIf
    vals[5] = oVer as String

    keys[6] = "Player level (vanilla)"
    If pc
        vals[6] = pc.GetLevel() as String
    Else
        vals[6] = "?"
    EndIf

    ; 主要なMCM設定です（〔SkyVault〕から直読みで、MCMと同じキー）。淫紋のボディ判定まわりは不具合の切り分けに効きます。
    keys[7] = "Body auto-detect"
    vals[7] = SkyVault.GetInt(None, "ASTR2_BodyAutoDetect", 1) as String

    keys[8] = "Body manual (0=3BA/1=UBE/2=vanilla)"
    vals[8] = SkyVault.GetInt(None, "ASTR2_BodyManual", 0) as String

    keys[9] = "Bar numbers ON"
    vals[9] = SkyVault.GetInt(None, "ASTR2_BarNumOn", 1) as String

    ; 🧩 必須MOD（esp持ち）のロード有無です。未導入（名前違いも含む）なら NOT LOADED＝不具合切り分けの一次情報です。
    ;   dll系（SkyVault/AddressLib/PO3/PapyrusUtil/SKSE/Pandora）は無いとこのファイル自体が生成されない為ここには出しません＝ファイルが在る＝dll系は揃っている証拠です。
    keys[10] = "Req: OStim.esp (core)"
    vals[10] = ReqStatus("OStim.esp")

    keys[11] = "Req: OCum.esp (cum bonus)"
    vals[11] = ReqStatus("OCum.esp")

    keys[12] = "Req: OSLAroused.esp (arousal)"
    vals[12] = ReqStatus("OSLAroused.esp")

    keys[13] = "Req: UIExtensions.esp"
    vals[13] = ReqStatus("UIExtensions.esp")

    keys[14] = "Req: SkyUI_SE.esp"
    vals[14] = ReqStatus("SkyUI_SE.esp")

    keys[15] = "Req: RaceMenu.esp"
    vals[15] = ReqStatus("RaceMenu.esp")

    Return ASTR2Native.WriteBugReport(Version(), keys, vals)
EndFunction

; 🧩 必須MOD（esp）のロード有無を返します。GetModByName が 255 なら未導入（名前違いも含む）。
;   フルespもESPFEも255以外で返る為、有無判定に足ります（load indexの区別は不要so文字列で返します）。
String Function ReqStatus(String espName) Global
    If Game.GetModByName(espName) == 255
        Return "NOT LOADED"
    EndIf
    Return "loaded"
EndFunction
