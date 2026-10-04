Scriptname ASTR2DistillEssenceEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; ディスティル・エッセンス（Distill Essence）は、淫魔力(Life Force)とマジカを注いで甘露丹（Elixir）を練ります。
; Lesser Powerなので何度でも使えます。習得はクリエイト・シャードと同じLv2です（サイズ解禁の閾値も >=2/3/5/7/10 で同じです）。
; 作りは ASTR2CreateShardEffect(クリエイト・シャード作成) と同じ流儀で、サイズメニュー→個数メニュー→支払い→生成の順に進みます。
; レシピや錬金台は設けず、素材からの無限生産にはしません（クリエイト・シャードと同じ方針です）。
; 1個練るごとに錬金術スキルへ経験値が入ります。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    Actor player = Game.GetPlayer()
    If akTarget != player
        Return
    EndIf

    ASTR2LifeForceBarScript LFBar = Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
    ASTLvlManager Lvl = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    ; サイズメニューは、MGEFのVMADに設定されたObjectプロパティを優先します。未設定ならFormID直引きへ退避します。
    Message sizeMenu = ElixirSizeMenuID
    If sizeMenu == None
        sizeMenu = Game.GetFormFromFile(0x01D7E8, "A Succubus Tale R2.esp") as Message
    EndIf
    If LFBar == None || Lvl == None || sizeMenu == None
        Return
    EndIf

    Int sucLvl = Lvl.SuccubusLvl.GetValueInt()

    ; --- サイズメニュー(Lvで〔門番〕・ボタン条件と同じ閾値: >=2/3/5/7/10) ---
    ; 0=極小 1=小 2=中 3=大 4=極大（バニラ魂石のサイズ表記に準拠しています）
    ; クリエイト・シャード（Create Shard）と完全に同じ解禁ペースで、序盤から「淫魔力を何に使うか」の選択肢になります。
    ;   メニューのMessageもクリエイト・シャードのをコピーして作ってあるのでボタン条件も同じで、表示と中身がズレません。
    Int[] sizes = new Int[5]
    Int count = 0
    If sucLvl >= 2
        sizes[count] = 0
        count += 1
    EndIf
    If sucLvl >= 3
        sizes[count] = 1
        count += 1
    EndIf
    If sucLvl >= 5
        sizes[count] = 2
        count += 1
    EndIf
    If sucLvl >= 7
        sizes[count] = 3
        count += 1
    EndIf
    If sucLvl >= 10
        sizes[count] = 4
        count += 1
    EndIf
    If count == 0
        Return
    EndIf

    Int choice = sizeMenu.Show()
    If choice >= count
        Return   ; 一番下に見えているボタンが「やめる」です
    EndIf
    Int size = sizes[choice]

    ; コストは単一の正(C++ SpellInfo DistillLife/ManaCost)を呼びます。
    Int lifeCost = ASTR2Native.GetDistillLifeCost(size)
    Int magickaPerUnit = ASTR2Native.GetDistillManaCost(size)
    Potion elixir = None
    String sizeKey = ""     ; 作成通知に出すサイズ名の$キーです
    If size == 0
        elixir = PickElixir(ElixirIDPetty, 0x01D7E2)
        sizeKey = "$ASTR2_Elixir_Petty"
    ElseIf size == 1
        elixir = PickElixir(ElixirIDLesser, 0x01D7E3)
        sizeKey = "$ASTR2_Elixir_Lesser"
    ElseIf size == 2
        elixir = PickElixir(ElixirIDCommon, 0x01D7E4)
        sizeKey = "$ASTR2_Elixir_Common"
    ElseIf size == 3
        elixir = PickElixir(ElixirIDGreater, 0x01D7E5)
        sizeKey = "$ASTR2_Elixir_Greater"
    Else
        elixir = PickElixir(ElixirIDGrand, 0x01D7E6)
        sizeKey = "$ASTR2_Elixir_Grand"
    EndIf

    ; --- 個数メニュー(x1 / x5 / x10 / 全部作る / やめる ; 条件なし) ＝クリエイト・シャードと同じMessageを使い回します ---
    Int qty = 1
    Message qtyMenu = Game.GetFormFromFile(0x01BCE4, "A Succubus Tale R2.esp") as Message
    If qtyMenu != None
        Int qChoice = qtyMenu.Show()
        If qChoice == 0
            qty = 1
        ElseIf qChoice == 1
            qty = 5
        ElseIf qChoice == 2
            qty = 10
        ElseIf qChoice == 3
            qty = 999999    ; 「全部作る」の指定なので、下で買える上限に丸めます
        Else
            Return          ; 「やめる」でキャンセルします
        EndIf
    EndIf

    ; --- 1個あたりのコスト。淫魔力とマジカ両方が許す数に個数を丸めます ---
    Int affordableByLife = LFBar.LFenergyCurr / lifeCost
    Int affordableByMana = (player.GetActorValue("Magicka") as Int) / magickaPerUnit
    Int maxQty = affordableByLife
    If affordableByMana < maxQty
        maxQty = affordableByMana
    EndIf
    If qty > maxQty
        qty = maxQty
    EndIf
    If qty < 1
        Debug.Notification("$ASTR2_Debug_NotEnoughLF")
        Return
    EndIf

    ; --- 支払い(両方とも個数に比例) & 生成 ---
    LFBar.LFenergyCurr -= (lifeCost * qty)
    LFBar.CheckLifeForce()
    player.DamageActorValue("Magicka", (magickaPerUnit * qty) as Float)

    If elixir == None
        Return
    EndIf
    player.AddItem(elixir, qty)

    ; 🧪 錬金術スキルへ経験値を入れます。量は甘露丹1個が生む火種（Ember）の枚数×0.1です。作った合計を1回でまとめて渡します。
    Game.AdvanceSkill("Alchemy", AlchXp(size) * qty)

    ; 通知は「○○の甘露丹を○個練り上げた」と出します（{0}=サイズ名の訳文・{1}=個数）
    String[] msg = new String[2]
    msg[0] = ASTR2Native.LocFmtF(sizeKey, 0.0)
    msg[1] = qty as String
    Debug.Notification(ASTR2Native.LocFmtStr("$ASTR2_Msg_ElixirCreated", msg))
EndEvent

; =====================================================================================
; 🔗 参照プロパティ（SSEEditでMGEFのVMADに設定済みのObject参照です）
;   Object参照を優先し、未設定ならFormID直引きへ退避する二段構えです。
;     参照の方が堅い（espの版を重ねてもFormIDのズレに強い）ので、設定されていればそちらを使います。
; =====================================================================================

Message Property ElixirSizeMenuID Auto   ; 甘露丹のサイズ選択Messageです（0101D7E8）
Potion Property ElixirIDPetty    Auto    ; 甘露丹・極小です (0101D7E2)
Potion Property ElixirIDLesser   Auto    ; 甘露丹・小です   (0101D7E3)
Potion Property ElixirIDCommon   Auto    ; 甘露丹・中です   (0101D7E4)
Potion Property ElixirIDGreater  Auto    ; 甘露丹・大です   (0101D7E5)
Potion Property ElixirIDGrand    Auto    ; 甘露丹・極大です (0101D7E6)

; プロパティが入っていればそれを、無ければFormIDから引いて返します。
Potion Function PickElixir(Potion aProp, Int aFallbackID)
    If aProp != None
        Return aProp
    EndIf
    Return Game.GetFormFromFile(aFallbackID, "A Succubus Tale R2.esp") as Potion
EndFunction

; =====================================================================================
; ⚙️ バランス調整用プロパティ（既定値のままでも動きます。SSEEditでMGEFのVMADに入れれば上書きできます）
; =====================================================================================


; 淫魔力/マジカコストは単一の正＝C++(SpellInfo DistillLife/ManaCost)です。
;   実コスト控除はASTR2Native.GetDistillLife/ManaCost(size)で行い、表示DESCも同じC++を呼びます。調整はsrc/SpellInfo.cppのテーブルを編集します(dllビルドが必要です)。

; 錬金術に入る経験値です。1個あたりの値をサイズ順に並べており、甘露丹1個が生む火種の枚数(1/10/100/1000/10000)×0.1です。
; レート(0.1)を変えたい時はこの5値を直接いじります（例えば0.2にすると全部2倍になります）。
Float Property ElixirAlchXpPetty   = 0.1 Auto
Float Property ElixirAlchXpLesser  = 1.0 Auto
Float Property ElixirAlchXpCommon  = 10.0 Auto
Float Property ElixirAlchXpGreater = 100.0 Auto
Float Property ElixirAlchXpGrand   = 1000.0 Auto

Float Function AlchXp(Int size)
    If size == 0
        Return ElixirAlchXpPetty
    ElseIf size == 1
        Return ElixirAlchXpLesser
    ElseIf size == 2
        Return ElixirAlchXpCommon
    ElseIf size == 3
        Return ElixirAlchXpGreater
    EndIf
    Return ElixirAlchXpGrand
EndFunction
