Scriptname ASTR2OrgasmXpEffect extends ActiveMagicEffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; オーガズムバフ中だけスキル経験値ボーナスを上乗せする役割です。ASTOrgasmHMSBuff(010130B4・
; Script archetype)に取り付けます。バフの寿命をエンジンが管理してくれるので、Papyrus側で
; タイマーを回す必要がありません(ロード/セーブ跨ぎでも取り残しが出ません)。
; 量はStorageUtil(ASTR2_OrgXpPct)に置き、ASTLvlManager.GetSkillXpBonusがソウル分と足して
; C++フック(ASTR2Native.SetSkillXpBonus)へ押します。合算の窓口は1つに保ちます。
; 自律設計です。配線するプロパティはありません(このスクリプト名をMGEFに足すだけ)。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If akTarget != Game.GetPlayer()
        Return
    EndIf
    ASTLvlManager lvl = ASTLvlManager.Get()
    If lvl == None
        Return
    EndIf
    StorageUtil.SetIntValue(akTarget, "ASTR2_OrgXpPct", lvl.OrgasmLvPct())
    lvl.SetOrgasmBuffEffect(Self)   ; 残り時間をMCMから読めるように自身を預けます
    ASTR2Native.SetSkillXpBonus(lvl.GetSkillXpBonus() as Float)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    If akTarget != Game.GetPlayer()
        Return
    EndIf
    StorageUtil.UnsetIntValue(akTarget, "ASTR2_OrgXpPct")
    ASTLvlManager lvl = ASTLvlManager.Get()
    If lvl == None
        ASTR2Native.SetSkillXpBonus(0.0)
        Return
    EndIf
    lvl.SetOrgasmBuffEffect(None)                                 ; 預けた自身を返します。MCMは「なし」表示へ
    ASTR2Native.SetSkillXpBonus(lvl.GetSkillXpBonus() as Float)   ; ソウル分だけに戻します
EndEvent
