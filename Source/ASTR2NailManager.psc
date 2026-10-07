Scriptname ASTR2NailManager extends Quest
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
;/ =========================================================================
   シンフル・ネイル「7つの大罪」機能の中枢です。
   ・ネイル7種＝素のArmor(付呪なし)です。効果はここからコードで乗せます(装備検知方式)。
   ・習得フラグは〔SkyVault〕に永続保存します(捨てても残り、コンプ状態も記憶します)。
   ・気分3カテゴリ(吸/H/殺)に大罪7を3・2・2で配分します。
   ・1〜6本=カテゴリ内で相乗／7コンプ=全解放(どのネイルでも7大罪フル発動します)。
   ========================================================================= /;

ASTR2NailManager Function Get() Global
    return Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTR2NailManager
EndFunction

; ===== ネイル定数 =====
; ネイルArmorはFormID連番 0x020886〜0x02088C（idx 0-6）です。
; idx: 0=イラ(憤怒) 1=スペルビア(傲慢) 2=ルクスリア(色欲) 3=グラ(暴食) 4=アケディア(怠惰) 5=インヴィディア(嫉妬) 6=アヴァリティア(強欲)
; 気分カテゴリ: 0=吸(暴食/怠惰/強欲) 1=H(傲慢/色欲) 2=殺(憤怒/嫉妬)

Armor Function NailArmor(Int idx) Global   ; idx 0-6 からネイルArmorを返します
    return Game.GetFormFromFile(0x020886 + idx, "A Succubus Tale R2.esp") as Armor
EndFunction

Int Function NailCategory(Int idx) Global  ; 0=吸 1=H 2=殺
    If idx == 0 || idx == 5        ; イラ(憤怒) / インヴィディア(嫉妬)
        return 2
    ElseIf idx == 1 || idx == 2    ; スペルビア(傲慢) / ルクスリア(色欲)
        return 1
    Else                           ; グラ(暴食) / アケディア(怠惰) / アヴァリティア(強欲)
        return 0
    EndIf
EndFunction

; 装備中のフォームからネイルidxを引きます（-1=ネイルではありません）。
Int Function IdxFromArmor(Form akArmor) Global
    Int i = 0
    While i < 7
        If akArmor == Game.GetFormFromFile(0x020886 + i, "A Succubus Tale R2.esp")
            return i
        EndIf
        i += 1
    EndWhile
    return -1
EndFunction

; ===== 習得フラグ（〔SkyVault〕に永続・捨てても残る）=====
Bool Function IsOwned(Int idx) Global
    return SkyVault.GetInt(None, "ASTR2_NailOwned_" + idx, 0) == 1
EndFunction

Function SetOwned(Int idx) Global
    SkyVault.SetInt(None, "ASTR2_NailOwned_" + idx, 1)
EndFunction

Bool Function IsComplete() Global
    Int i = 0
    While i < 7
        If SkyVault.GetInt(None, "ASTR2_NailOwned_" + i, 0) != 1
            return false
        EndIf
        i += 1
    EndWhile
    return true
EndFunction

; 習得済みの本数です（進捗表示・配布判定用）。
Int Function OwnedCount() Global
    Int c = 0
    Int i = 0
    While i < 7
        If SkyVault.GetInt(None, "ASTR2_NailOwned_" + i, 0) == 1
            c += 1
        EndIf
        i += 1
    EndWhile
    return c
EndFunction

; ===== 配布 =====
; 指定ネイルをプレイヤーへ付与し、習得フラグをONにします。
Function GrantNail(Int idx)
    Armor nl = NailArmor(idx)
    If nl != None
        Game.GetPlayer().AddItem(nl, 1, true)
        SetOwned(idx)
    EndIf
EndFunction

; カテゴリ内の未習得からランダムに配布します（全習得済みなら重複配布＝フォロワー用）。
; cat: 0=吸 1=H 2=殺 ／ 戻り＝配布したidx（-1=失敗）
Int Function GrantRandomFromCategory(Int cat)
    Int[] pool = new Int[7]
    Int n = 0
    Int i = 0
    ; ① 未習得を優先して集めます
    While i < 7
        If NailCategory(i) == cat && !IsOwned(i)
            pool[n] = i
            n += 1
        EndIf
        i += 1
    EndWhile
    ; ② 未習得が無ければカテゴリ全部から選びます（重複配布＝フォロワー用）
    If n == 0
        i = 0
        While i < 7
            If NailCategory(i) == cat
                pool[n] = i
                n += 1
            EndIf
            i += 1
        EndWhile
    EndIf
    If n == 0
        return -1
    EndIf
    Int pick = pool[Utility.RandomInt(0, n - 1)]
    GrantNail(pick)
    return pick
EndFunction

; ===== 効果合算（有効な大罪セットを作る部分・効果の中身は大罪ごとに各機能側で実装）=====
; 装備中ネイルidx(-1=非装備)から「有効な大罪セット」を出して効果を張り直します。
Function RefreshEffects(Int equippedIdx)
    ; ★装備中idxを常に公開します（着脱イベント経由でも更新＝ネイル親DESCの{1}装備中名用／-1=未装備）。RefreshFromEquippedと同じ書き先です。
    SkyVault.SetInt(None, "ASTR2_NailWornIdx", equippedIdx)
    Bool[] active = new Bool[7]   ; 既定=全false（＝全効果OFF）
    ; ★覚醒OFF（人間化）中は装備していても全効果OFF＝習得フラグ/アイテムは保持して休眠します。覚醒ONで張り直します。
    If equippedIdx >= 0 && SkyVault.GetInt(None, "ASTR2_Awake", 1) == 1
        If IsComplete()
            ; 7コンプ＝カテゴリ縛り解除＝全大罪フルです
            Int i = 0
            While i < 7
                active[i] = true
                i += 1
            EndWhile
        Else
            ; コンプ前＝装備ネイルのカテゴリで習得済みの大罪だけ相乗します
            Int cat = NailCategory(equippedIdx)
            Int i = 0
            While i < 7
                If NailCategory(i) == cat && IsOwned(i)
                    active[i] = true
                EndIf
                i += 1
            EndWhile
        EndIf
    EndIf
    ApplyEffectSet(active)
EndFunction

; 現在装備しているネイルを検出して効果を張り直します（覚醒ON復帰・ロード後など、装備イベントが飛ばないケース用）。1本も無ければ全OFFです。
Function RefreshFromEquipped()
    Actor pc = Game.GetPlayer()
    ; ★装備中ネイルidxを常に公開します（ネイル親DESC {1}装備中名用・トグル問わず）。-1=未装備。
    Int worn = -1
    Int w = 0
    While w < 7
        Armor nlw = NailArmor(w)
        If nlw != None && pc.IsEquipped(nlw)
            worn = w
            w = 7
        Else
            w += 1
        EndIf
    EndWhile
    SkyVault.SetInt(None, "ASTR2_NailWornIdx", worn)
    ; ★装備必須トグルOFF＝装備しなくても習得済み大罪を有効化します（ネイル強制を避ける保険）。既定ON＝従来の装備検知。
    If SkyVault.GetInt(None, "ASTR2_NailRequireEquip", 1) == 0
        RefreshEffectsNoEquip()
        return
    EndIf
    RefreshEffects(worn)
EndFunction

; 装備必須トグルOFF用＝装備検知せず習得済みの大罪を全部有効化します（覚醒ON中のみ）。カテゴリ/コンプ縛りは装備時だけの演出なので、非装備時は習得したぶんをすべて有効化します。
Function RefreshEffectsNoEquip()
    Bool[] active = new Bool[7]
    If SkyVault.GetInt(None, "ASTR2_Awake", 1) == 1
        Int i = 0
        While i < 7
            If IsOwned(i)
                active[i] = true
            EndIf
            i += 1
        EndWhile
    EndIf
    ApplyEffectSet(active)
EndFunction

; MCMトグル等から即時張り直しを呼ぶGlobal窓口です（装備必須トグルの切替時に呼びます＝ASTR2NailManager.RefreshNow()）。
Function RefreshNow() Global
    Get().RefreshFromEquipped()
EndFunction

; 有効大罪セットを実際の効果に反映＝各罪の有効状態を〔SkyVault〕へ公開します（疎結合の契約）。
;   各機能は自分のidxのフラグ ASTR2_NailActive_<idx>（1=有効/0=無効）を読んで効果をON/OFFします。
;   idx→罪と効果：
;     0 憤怒Ira     =低HPで魔法ダメUP(Lv連動・追い詰められて激昂)
;     1 傲慢Superbia=話術/HスキルXP+
;     2 色欲Luxuria =魅了成功率/arousal補正+
;     3 暴食Gula    =〔天敵〕(ActorTypeDwarven機械)へ少量ダメ→LF変換
;     4 怠惰Acedia  =魔法構え中の移動減速を打消し(Lv連動)+アンリーシュド・フューリーの速度丸乗り
;     5 嫉妬Invidia =全サーヴァントのtier合計を魔法5スキルに加算
;     6 強欲Avaritia=LF吸収量+%
Function ApplyEffectSet(Bool[] active)
    Int i = 0
    While i < 7
        SkyVault.SetInt(None, "ASTR2_NailActive_" + i, active[i] as Int)
        i += 1
    EndWhile
    ; 嫉妬(idx5)＝受動statバフ(サーヴァントtier合計→魔法5スキル)なので、フラグ更新だけでは焼き直りません＝張り直しトリガーを1回呼びます（ON合計/OFF全戻しを差分管理するので順不同で安全）
    ASTR2Servantship.RefreshEnvyBuff()
EndFunction

; =====================================================================================
; 🎴 気分プロンプト＆配布フロー（覚醒初回／Lv1パワー「シンフル・ネイル（Sinful Nail）」1日1回=Power）
;   気分メニュー(コンプ前3択/コンプ後4択)→選んだカテゴリから1本配布して装備します。手本＝ディスティル・エッセンス(Distill)。
;   Message: 3択=0x020899(Feed吸/Seduce H/Slay殺/Cancel)／4択=0x02089A(＋Choose freely自由)。
;   choice: 0=吸(cat0) 1=H(cat1) 2=殺(cat2) ／ 3=自由(4択のみ)or やめる(3択) ／ 4=やめる(4択)
; =====================================================================================
Function MoodGrantFlow(Bool isInitial = false)
    Bool complete = IsComplete()
    Message menu
    If complete && !isInitial
        menu = Game.GetFormFromFile(0x02089A, "A Succubus Tale R2.esp") as Message   ; コンプ後4択
    Else
        menu = Game.GetFormFromFile(0x020899, "A Succubus Tale R2.esp") as Message   ; コンプ前3択
    EndIf
    If menu == None
        return
    EndIf
    Int choice = menu.Show()
    If choice >= 0 && choice <= 2
        Int idx = GrantRandomFromCategory(choice)   ; 0=吸 1=H 2=殺
        If idx >= 0
            EquipNail(idx)
        EndIf
    ElseIf choice == 3 && complete && !isInitial
        OpenFreeSelect()   ; コンプ後の「自由に選ぶ」＝コンテナ窓(④)です
    EndIf
    ; それ以外(やめる)＝何もしません
EndFunction

; 覚醒時の初回配布です（コンプ前3択固定＝ASTR2MainScript.ShowInitialAwakeningPromptから）
Function InitialMoodGrant()
    MoodGrantFlow(true)
EndFunction

; Lv1パワー「シンフル・ネイル（Sinful Nail）」(1日1回=Power)から＝コンプ状態で3択/4択を自動切替します
Function DailyMoodGrant()
    MoodGrantFlow(false)
EndFunction

; 配布したネイルを装備します＝OnObjectEquipped→RefreshEffectsで効果を即適用します
Function EquipNail(Int idx)
    Armor nl = NailArmor(idx)
    If nl != None
        Game.GetPlayer().EquipItem(nl, false, true)   ; silent equip
    EndIf
EndFunction

; ===== コンテナ選択窓（④・コンプ後「自由に選ぶ」）=====
; プレイヤー足元に一時コンテナをPlaceAtMeで出し→7種を入れ→バニラのコンテナメニューで好きに取得→
;   閉じたら一時コンテナごと撤去します（残りネイルも一緒に破棄）。swf/UIExt不要・依存ゼロです（設計通り）。
; コンテナbase＝ASTR2NailHolder(0x02089E)をFormID直引きします。Autoプロパティは既存セーブにNone焼き込み＝配布でも落とし穴なので、FormID直引きに一本化します（GetFormFromFile優先・気分Messageと同じ流儀）。
Function OpenFreeSelect()
    Container holderBase = Game.GetFormFromFile(0x02089E, "A Succubus Tale R2.esp") as Container
    If holderBase == None
        return
    EndIf
    Actor pc = Game.GetPlayer()
    ObjectReference box = pc.PlaceAtMe(holderBase, 1, false, false)
    If box == None
        return
    EndIf
    ; 7種を器へ入れます
    Int i = 0
    While i < 7
        Armor nl = NailArmor(i)
        If nl != None
            box.AddItem(nl, 1, true)
        EndIf
        i += 1
    EndWhile
    ; コンテナメニューを開き、閉じ切るまで待ちます
    box.Activate(pc)
    Utility.Wait(0.4)
    While UI.IsMenuOpen("ContainerMenu")
        Utility.Wait(0.3)
    EndWhile
    ; 一時コンテナを撤去します（プレイヤーが取らなかったネイルも器ごと破棄＝次回まっさら）
    box.Disable()
    box.Delete()
EndFunction

; =====================================================================================
; 📊 実数getter（MCMの実数表示用・MCMが読みます）
;   ・〔SkyVault〕のキーで持つ値は各機能の実装と同一キーなので値は完全一致します（強欲/暴食/傲慢/嫉妬の記録値）。
;   ・Lv連動式(怠惰/憤怒/色欲)は表示用の写しで、式の正は各機能の実装側です（式が変わると表示とずれるため同じ式を保ちます）。
;   ・全部Papyrusで完結します（〔SkyVault〕/Lv/記録値を読むだけ）＝dllビルド不要。
; =====================================================================================
Int Function NailSucLv() Global
    ASTLvlManager Lvl = Game.GetFormFromFile(0x013617, "A Succubus Tale R2.esp") as ASTLvlManager
    If Lvl && Lvl.SuccubusLvl
        Int lv = Lvl.SuccubusLvl.GetValueInt()
        If lv > 100
            return 100
        EndIf
        If lv < 1
            return 1
        EndIf
        return lv
    EndIf
    return 1
EndFunction

; 怠惰＝構え中の移動速度加算%です（現在Lv）＝NailLazy.cpp の OffsetNow と同式(maxOffset×Lv/100)。
Float Function GetLazySpeedPctNow() Global
    return (SkyVault.GetInt(None, "ASTR2_NailLazyMaxOffset", 50) * NailSucLv()) as Float / 100.0
EndFunction

; 傲慢＝話術XP倍率%です（Lv連動 Max×Lv/100・Lv100で+100%＝SkillXpBoostと同式）。★小数1桁表示用にFloatで返します(呼び側で+符号/桁整形)。
Float Function GetPrideSpeechPct() Global
    return SkyVault.GetInt(None, "ASTR2_NailPrideSpeechMax", 100) as Float * NailSucLv() / 100.0
EndFunction

; 傲慢＝HスキルXP倍率%です（Lv連動 Max×Lv/100・Lv100で+50%＝Technique.cppと同式）。★Floatで返します。
Float Function GetPrideTechPct() Global
    return SkyVault.GetInt(None, "ASTR2_NailPrideTechMax", 50) as Float * NailSucLv() / 100.0
EndFunction

; 強欲＝LF吸収 +Lv%です（CombatDrain/HDrain実式 ×(1+Lv×0.01)＝Lv100で+100%＝吸収2倍）。★Floatで返します。
Float Function GetGreedPct() Global
    return NailSucLv() as Float
EndFunction

; 暴食＝〔天敵〕(ドワーフ機械)のドレイン率 Lv×0.1%です（CombatDrain実式 NailGulaPerLv(0.001)×Lv×100＝Lv100で10%）。★Floatで返します(小数1桁で3.1%等)。
Float Function GetGulaPct() Global
    return NailSucLv() as Float * SkyVault.GetFloat(None, "ASTR2_NailGulaPerLv", 0.001) * 100.0
EndFunction

; 憤怒＝低HP時の魔法与ダメ加算%です（＝Lv×1%＝Fury.cppの×(1+Lv×0.01)と同じ／Lv100で+100%=×2）。★Floatで返します。
Float Function GetWrathDmgPctNow() Global
    return NailSucLv() as Float
EndFunction

; 憤怒＝発動する低HP閾値%＝10+Lv×0.3です（Fury.cpp実式・Lv1≈10%→Lv100=40%）。この値は〔SkyVault〕キーでなくLv式から算出します（Fury.cppと同式）。
Int Function GetWrathHpPct() Global
    return (10.0 + NailSucLv() as Float * 0.3) as Int
EndFunction

; 色欲＝魅了で入る興奮量(スパイク)の加算%です（＝Lv×0.1%＝ASTSedMagEffScriptの×(1+Lv×0.001)と同じ／Lv100で+10%）。
Float Function GetLustPctNow() Global
    return NailSucLv() as Float * 0.1
EndFunction

; 色欲＝セダクション系の1日の使用回数枠です（＝Lv/10＝PowerReset.cpp の NailSeductionBudget と同式／Lv10で1回…Lv100で10回・Lv1-9は0）。
Int Function GetLustSedBudget() Global
    return NailSucLv() / 10
EndFunction

; 嫉妬＝魔法5スキルへの現在加算量です（嫉妬の実装がASTR2_EnvyAppliedへ記録した実適用値）。
Int Function GetEnvyBonusNow() Global
    return SkyVault.GetInt(None, "ASTR2_EnvyApplied", 0)
EndFunction
