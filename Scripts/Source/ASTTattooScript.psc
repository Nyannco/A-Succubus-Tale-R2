Scriptname ASTTattooScript extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; =================================================================
; 💡 デッドロック解除用の共通getterです
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

; Variables
;---------------------------------------------
bool property enableGlow = true Auto
bool property fixedTattoo = false Auto
int Property currTattooLvl = 1 Auto

; プレイヤー淫紋の適用は C++(SigilApplyPlayer / SigilApplyFixed)が持ちます。
;   種類/固定モードのテクスチャ選択ロジックは Sigil.cpp にあります。RefreshTattoo が native を呼びます。

; =================================================================
; 淫紋を消す
; =================================================================
Function RemoveTattoo(Actor act)
    If act == None
        Return
    EndIf
    ; 淫紋の撤去はC++(SKEE)へ委譲します＝既定(透明)へ上書きして撤去するので、見た目も即消えます（Papyrus VMに並びません）。
    ; プレイヤー/NPC問わずASTR2Tatto/SucTattooの枠を掃除します（SigilClearが一括処理）。
    ASTR2Native.SigilClear(act)
EndFunction

; =================================================================
; 🩸 NPC淫紋（サキュバスの印）＝効果中にNPCへ付ける印です（サキュバス・ウィークネス/スイート・ヴァッサル等）。
;   位置=股間（レガシー）。★竿の有無で自動：竿あり(男/フタ)=MaleSucTattooMedium／竿なし(女)=ASTR2Tatto。両方6段階です。
;   残り時間の割合 frac(0〜1) でテクスチャの段階(level 6→1)を変えます。ピンク紋様が
;   満タン(lvl6)→残りわずか(lvl1)へ縮むので、見た目で残り時間が分かります。グロウは点灯固定でピンクを光らせます。
;   撤去は既存RemoveTattoo(act)で行います。配線は各スペルから呼びます。MCMトグル ASTR2_NpcSigilEnabled(既定1=ON)を尊重します。
; =================================================================

; NPC淫紋の段階計算/テクスチャ選択は C++ Sigil.cpp が持ちます（NpcLevelForFrac/NpcSigilTexture）。

; NPCに淫紋を付与します（サキュバス・ウィークネス/スイート・ヴァッサル等）＝効果開始時に1回。frac=残り/総(0〜1・既定1=満タン)。
;   ★段階計算・テクスチャ選択・実際の貼付はC++(SigilApplyNpc)が持ちます＝股間固定・竿振り分け・貼る前に既存を掃除するので1枚になります。
;   MCMトグル ASTR2_NpcSigilEnabled(既定1=ON)を尊重します。撤去は RemoveTattoo(=SigilClear)で行います。
Function ApplyNpcSigil(Actor act, Float frac = 1.0)
    If act == None
        Return
    EndIf
    If StorageUtil.GetIntValue(Game.GetPlayer(), "ASTR2_NpcSigilEnabled", 1) == 0
        Return   ; MCMロゴページでOFFのとき
    EndIf
    ASTR2Native.SigilApplyNpc(act, frac, OActorUtil.HasSchlong(act))
EndFunction


; 状況に合わせて淫紋を更新・貼り直します
Function RefreshTattoo()
    ASTR2MainScript Main = GetMain()
    ASTLvlManager Lvl = GetLvlManager()   ; 独立したLvlManagerに直接IsSuccubus()を確認
    Actor player = Game.GetPlayer()

    If Main.usesTatoo && Lvl.IsSuccubus()
        Bool maleTex = OActorUtil.HasSchlong(player)
        ASTR2MCMScript MCM = ASTR2MCMScript.Get()
        If fixedTattoo
            ; 🔒 固定表示＝C++(SigilApplyFixed)へ委譲＝各fixed index(排他)から明示テクスチャを貼ります（内部で掃除→貼付するので1枚）。
            If MCM != None
                ASTR2Native.SigilApplyFixed(player, MCM.fixedChestIndex, MCM.fixedBackIndex, MCM.fixedLegacyIndex, MCM.fixedLegacyMaleIndex, MCM.fixedLegacySmallIndex, MCM.fixedMiscIndex, enableGlow, maleTex)
            EndIf
        Else
            ; 🟢 Lv連動＝C++(SigilApplyPlayer)へ委譲＝Papyrus VMの列に並びません（native側で掃除→貼付するので二重貼りなし）。
            Int mode = 0
            If MCM != None
                mode = MCM.currLeveledTattosIndex
            EndIf
            ASTR2Native.SigilApplyPlayer(player, mode, currTattooLvl, enableGlow, maleTex)
        EndIf
    Else
        ; サキュバスでない/OFF＝除去します
        ASTR2Native.SigilClear(player)
    EndIf
EndFunction



; 段階は ASTLvlManager が currTattooLvl へ直接1-6を設定します。
