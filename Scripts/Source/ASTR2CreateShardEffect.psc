Scriptname ASTR2CreateShardEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; チャージ詠唱では、淫魔力(Life Force)とマジカの両方を消費して、満タンの淫魔晶（Essence Shard）を作ります。
; どちらのコストも作る個数(1個あたり)に比例して増えます。
; サイズはサキュバスLvで解禁します(サイズメニューのボタンの〔門番〕も同じ条件です＝>=2/3/5/7/10)。
; 個数メニュー(x1/x5/x10/全部作る/やめる)のボタンには条件を付けません。
; レシピ/鍛冶なしです(素材からの無限生産を防ぐためです)。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    Actor player = Game.GetPlayer()
    If akTarget != player
        Return
    EndIf

    ASTR2LifeForceBarScript LFBar = Game.GetFormFromFile(0x013618, "A Succubus Tale R2.esp") as ASTR2LifeForceBarScript
    ASTLvlManager Lvl = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    Message sizeMenu = Game.GetFormFromFile(0x01BCE1, "A Succubus Tale R2.esp") as Message
    If LFBar == None || Lvl == None || sizeMenu == None
        Return
    EndIf

    Int sucLvl = Lvl.SuccubusLvl.GetValueInt()

    ; --- サイズメニュー(Lvで〔門番〕・ボタン条件と同じ閾値: >=2/3/5/7/10) ---
    ; 0=極小(Petty) 1=小(Lesser) 2=並(Common) 3=大(Greater) 4=特大(Grand)
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
        Return   ; 一番下の見えているボタン（やめる）を選んだ時です
    EndIf
    Int size = sizes[choice]

    ; 素コストは単一の正(C++ SpellInfo ShardLifeCost)を呼びます。倍率は下で掛けます。
    Int lifeCost = ASTR2Native.GetShardLifeCost(size)
    Int gemID = 0
    String sizeKey = ""     ; 作成通知に出すサイズ名の$キーです
    If size == 0
        gemID = 0x01BCDC    ; 淫魔晶（極小）
        sizeKey = "$ASTR2_Shard_Petty"
    ElseIf size == 1
        gemID = 0x01BCDD    ; 淫魔晶（小）
        sizeKey = "$ASTR2_Shard_Lesser"
    ElseIf size == 2
        gemID = 0x01BCDE    ; 淫魔晶（並）
        sizeKey = "$ASTR2_Shard_Common"
    ElseIf size == 3
        gemID = 0x01BCDF    ; 淫魔晶（大）
        sizeKey = "$ASTR2_Shard_Greater"
    Else
        gemID = 0x01BCE0    ; 淫魔晶（特大）
        sizeKey = "$ASTR2_Shard_Grand"
    EndIf

    ; コスト倍率はMCMスライダーです(既定1.0)。全サイズのlifeCostに掛けます。0割回避で最低1にします。
    lifeCost = (lifeCost * StorageUtil.GetFloatValue(player, "ASTR2_ShardCostMult", 1.0)) as Int
    If lifeCost < 1
        lifeCost = 1
    EndIf

    ; --- 個数メニュー(x1 / x5 / x10 / 全部作る / やめる ; 条件なし) ---
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
            qty = 999999    ; 「全部作る」は下で買える上限に丸めます
        Else
            Return          ; やめる（キャンセル）を選んだ時です
        EndIf
    EndIf

    ; --- 1個あたりのコスト。淫魔力とマジカ両方が許す数に個数を丸めます ---
    Int magickaPerGem = 100
    Int affordableByLife = LFBar.LFenergyCurr / lifeCost
    Int affordableByMana = (player.GetActorValue("Magicka") as Int) / magickaPerGem
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
    player.DamageActorValue("Magicka", (magickaPerGem * qty) as Float)

    Form gem = Game.GetFormFromFile(gemID, "A Succubus Tale R2.esp")
    If gem != None
        player.AddItem(gem, qty)
        Game.AdvanceSkill("Enchanting", (ShardEnchXp(size) * qty) as Float * StorageUtil.GetFloatValue(player, "ASTR2_ShardEnchXpMult", 1.0))   ; ✨ 付呪XPです（1個あたり・サイズ順）×MCM付呪XP倍率(既定1.0)
        String[] shardMsg = new String[2]   ; 通知は「○○の淫魔晶を○個封じた」と出します（{0}=サイズ名の訳文・{1}=個数）
        shardMsg[0] = ASTR2Native.LocFmtF(sizeKey, 0.0)
        shardMsg[1] = qty as String
        Debug.Notification(ASTR2Native.LocFmtStr("$ASTR2_Debug_ShardCreated", shardMsg))
        If size == 4   ; 🌟 極大(size4)の累計作成数はサキュバスソウルのスキルXPボーナスの元です（1万個で+1%・上限100万=100%・GetSkillXpBonusが読みます）
            StorageUtil.AdjustIntValue(player, "ASTR2_GrandShardCount", qty)
            ASTLvlManager lvlMgr = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
            If lvlMgr != None
                ASTR2Native.SetSkillXpBonus(lvlMgr.GetSkillXpBonus() as Float)   ; 作成でボーナスが増えた分をC++フックへ即反映します
            EndIf
        EndIf
    EndIf
EndEvent

; ===== MCMアビリティ一覧の威力getter(共通ルール) =====

; 指定サイズ(0..4)の結晶を1個作るのに要る淫魔力コストです。マジカは上乗せで一律100/個です。
Int Function GetShardCost(Int size) Global
    ; 素コストは単一の正(C++ SpellInfo ShardLifeCost)です。実支払いは別途ShardCostMultを掛けます。
    Return ASTR2Native.GetShardLifeCost(size)
EndFunction

; ===== ✨ 付呪XP（1個あたり・サイズ順）＝淫魔晶はソウルジェム系なので「付呪(Enchanting)」が入ります =====
; 淫魔晶は淫魔力コストが安いので、既定値は控えめです(3/5/10/20/40)。プロパティなので SSEEditで調整できます。
Int Property ShardEnchXpPetty   = 3 Auto
Int Property ShardEnchXpLesser  = 5 Auto
Int Property ShardEnchXpCommon  = 10 Auto
Int Property ShardEnchXpGreater = 20 Auto
Int Property ShardEnchXpGrand   = 40 Auto

Int Function ShardEnchXp(Int size)
    If size == 0
        Return ShardEnchXpPetty
    ElseIf size == 1
        Return ShardEnchXpLesser
    ElseIf size == 2
        Return ShardEnchXpCommon
    ElseIf size == 3
        Return ShardEnchXpGreater
    EndIf
    Return ShardEnchXpGrand
EndFunction
