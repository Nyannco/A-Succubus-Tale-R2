Scriptname ASTR2WeaknessEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; サキュバス・ウィークネス（MGEF 005E36）に乗せる効果です。効果中、対象NPCへ淫紋を付与し、残り時間で段階を変えます。
; 段階更新は〔クロノス〕に任せ、ここは開始と終了を1回ずつ伝えるだけです（WeaknessSigilBegin/End）。
;   段階更新を相手1人ごとのPapyrusループで回すと、相手が増えるほど重くなるため、C++に持たせています。
; スイート・ヴァッサルで淫紋が付与されている手下には、ウィークネスは淫紋の付与を行わず、耐性ダウンだけを付与します（同じ部位への二重付与を避けるためです）。
; 手下かどうかの判定もC++側が持ちます（ASTR2ActiveMinionFaction所属＝VassalDeathと同じ見方）。

Float Property DurationSec = 60.0 Auto      ; ウィークネスの効果時間です（EFIT準拠・段階計算用の総時間）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; 💰 マジカ消費はバニラに一本化しています（CalculateMagickaCostフック＝ManaCost.cpp）＝ここでは払いません。
    If akTarget == None
        Return
    EndIf
    ; 🔮 変性(Alteration)育成＝ウィークネス命中で、耐性ダウン量に比例したXPを入れます（率1.5・ドレインと同じやり方）。
    Game.AdvanceSkill("Alteration", ASTDrainScript.GetWeaknessResistDown() * 1.5)
    ; 淫紋の貼付＋段階更新はC++へ任せます（竿の有無だけPapyrusで判定して渡す＝OActorUtilがPapyrus専用のためです）。
    ASTR2Native.WeaknessSigilBegin(akTarget, DurationSec, OActorUtil.HasSchlong(akTarget))
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    If akTarget == None
        Return
    EndIf
    ASTR2Native.WeaknessSigilEnd(akTarget)
EndEvent
