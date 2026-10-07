Scriptname ASTR2Cleanup Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 🧹 汎用お掃除ライブラリです。スイート・ヴァッサル（Sweet Vassal）で付与した「味方の印」を全部剥がして通常状態(基テンプレート)へ戻します。
;    灰化／戦闘死／浄化ツール／将来のお掃除用途で共用します。どのアクターに呼んでも安全です（手下でなければ空振りします）。
;
; 方針として、FormID名指し(狙い撃ち)で他MODのファクションを剥がしません。
;   「入っているか不明な特定MODの物を名指しで剥がす」は禁止なので、ファクションは
;   ASTR2Native.ResetRuntimeFactions（ランタイム付与を基テンプレートへ一律巻き戻すオールリセットです）に任せます。
;   つまり、本MODが足した物(CurrentFollowerFaction/手下)もOStim Romanceの IsOrWasFollower も種類問わず一律に落ちます。
;
; 灰化すると自分では二度と蘇生できなくなりますが、それで問題ありません。他MODでの復活やセル再湧きの時に
;   通常状態(元の敵/中立)へ戻っていることが目的なので、綺麗にリセットするのがこのライブラリの仕事です。

; 通常状態へ戻します。味方の印を全部剥がします。akTarget が None／手下でなくても安全に空振りします。
Function ResetActor(Actor akTarget) Global
    If akTarget == None
        Return
    EndIf
    Actor pc = Game.GetPlayer()

    ; 🧬 ファクションはオールリセットします。ランタイムで足された物を基テンプレートへ一律巻き戻します（狙い撃ちはゼロで、他MODの物も落ちます）。
    ASTR2Native.ResetRuntimeFactions(akTarget)
    ; エンジンの「ファクション同士の戦闘反応」キャッシュを捨てます。味方から元の反応(敵/中立)へ即反映します。
    PO3_SKSEFunctions.ClearCachedFactionFightReactions()

    ; 🤝 味方の挙動を解除します（ファクションとは別軸です）。
    akTarget.SetPlayerTeammate(False)
    akTarget.IgnoreFriendlyHits(False)
    akTarget.SetRelationshipRank(pc, 0)                                          ; 蘇生時に結んだ関係(ランク)を白紙へ戻します
    ; 敵対度＝2(攻撃的)へ強制で戻します。GetBaseActorValueは味方化の SetActorValue("Aggression",0) で0に汚染済みなので使えません
    ;   （元値は破壊されて復元不能です）。0のままだと攻撃してこず「味方のまま」リポップします（実機ログで確認済みです）。
    akTarget.SetActorValue("Aggression", 2.0)   ; 山賊等の敵に戻します。攻撃的です

    ; 🩷 淫紋(眷属の証)を撤去します。味方解除と一緒に消します。RemoveTattoo(=C++ SigilClear)が再描画まで完結するので追加の再描画は不要です。
    ASTTattooScript tat = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTTattooScript
    If tat != None
        tat.RemoveTattoo(akTarget)
    EndIf

    ; 🧷 追従スロットを解放します。alias ForceRefが残ると連れ回されます（味方さの一因です）。
    ASTConjCost.ClearVassalSlot(akTarget)
    ; 👑 〔サーヴァントシップ〕(眷属tier/点数/名簿)も浄化します。残ると再接触でミラーが関係ランクを貼り直すためです。
    ASTR2Servantship.ResetServant(akTarget)

EndFunction
