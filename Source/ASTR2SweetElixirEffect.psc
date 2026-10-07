Scriptname ASTR2SweetElixirEffect extends ActiveMagicEffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 甘露丹(カンロタン / Sweet Elixir)は、使うと「グレーターパワーを1回ぶん余分に撃てる券」が貯まります。

; =====================================================================================
; 🎫 パワー使用権（トークン）
;   グレーターパワーの「1日1回」は、バニラのキャスト判定が kPowerUsed を返して弾いています。
;   dll(src/PowerReset.cpp)がその"判定の答え"だけを kOK に差し替えることで、
;   タイマーにもお気に入りにも一切触らずに1回ぶん通します。
;   ★RemoveSpell/AddSpell方式は「お気に入りから外れる」ため見送り、それを回避した形です。
;
;   このスクリプトはアイテム側で、「券を1枚(TokensPerUse枚)発行する」だけです。
;   消費はdllが自動で行います（対象パワーを撃った瞬間に1枚）。
;
;   対象パワーは ASTR2 の Greater Power 5種です（魅了 単体/範囲/大量・淫魔解放・スイート・ヴァッサル招来）。
;   ※シャード作成/隷属同期は Lesser Power で、元から無制限なので対象外です。
; =====================================================================================

; ★何枚ぶん貯まるかは アイテム(ALCH)のMagnitude で決めます。バニラのポーション(回復量等)と同じ流儀です。
;   MGEFは1個で、ALCH側でMagnitudeを 1/10/100/1000/10000 と指定します。極小=1/小=10/中=100/大=1000/極大=10000。
;   ★重要：MGEFのArchetypeは「Value Modifier」等の"エンジンが処理する型"にすること（実効果は無害な
;     AV=Aggression（プレイヤーには効かない）へ乗せて値の運搬役に使います）。「Script」archetypeだと
;     エンジンがMagnitudeを積まず GetMagnitude() が0を返します（実測確定 raw=0.0）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; プレイヤー以外が飲んでも意味がないので何もしません（NPCに配っても無害にしておきます）
    If akTarget != Game.GetPlayer()
        Return
    EndIf

    Int add = GetMagnitude() as Int
    If add >= 1
        GrantTokens(add)                ; 通常（1個ずつ飲む）で、即時付与します（待ち無し）
    Else
        ; ★連打で速く飲むと OnEffectStart 時点でまだ Magnitude が積まれておらず 0 を返すことがあります
        ;   （エンジンの1フレ遅れ・同フレームで大量に始まると一部が0読み。実機ログで実証）。
        ;   誤って最低1枚に落とさないよう、1フレ待って読み直します。MGEFの0.5s持続で OnUpdate を鳴らします。
        RegisterForSingleUpdate(0.1)
    EndIf
EndEvent

Event OnUpdate()
    Int add = GetMagnitude() as Int
    If add < 1
        add = 1   ; それでも0なら最終保険です（ほぼ発生しません）
    EndIf
    GrantTokens(add)
EndEvent

; 券を add 枚発行します（消費はdllが自動）。通知は連打で溢れないよう dll(PowerReset) 側で
;   debounce して「増え終わってから1回だけ」出します。ここでは Debug.Notification しません。
Function GrantTokens(Int add)
    ASTR2Native.AddPowerTokens(add)
EndFunction
