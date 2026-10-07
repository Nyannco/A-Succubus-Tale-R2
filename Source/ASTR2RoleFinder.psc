Scriptname ASTR2RoleFinder Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; ============================================================
; ASTR2RoleFinder: OStimシーンカタログから成立する組を選び、OThreadBuilderで直接起動します。
; ログは ASTR2_OStimLog.txt の [ROLE] へ出します。
; ============================================================

; ============================================================
; グループ起動の核です。グループで成立するシーンを見つけ、OThreadBuilderで直接起動します。
; 開始ノードを先に指定すると、OStimは役メニュー・自動ソート・無アニメチェックを丸ごと飛ばします
; (handleStartingNodeが短絡)＝無アニメ失敗ゼロです。
; Create()に渡すlineupはGetRandomSceneが一致させたのと同じSorted配列なので、
; startThreadのfulfilledBy再チェックを通過します(ノードがclearされません)。
; OStimのスレッドidを返します(>=0; 0=プレイヤーシーン・非同期)。成立するシーンが無い、または
; アクターが不適格なら-1です(クリーンに中断・無音死なし)。
; ============================================================
; furnRef指定(例 対象が寝てるベッド) -> その種別を割り出してそこでシーンを試します。
; その家具に成立するシーンが無ければ立ちにフォールバックします(失敗ゼロ)。None -> 立ちです。
Int Function LaunchGroup(Actor[] group, ObjectReference furnRef = None) Global
    Int n = group.Length
    String furnType = "none"
    If furnRef != None
        String bt = OFurniture.GetFurnitureType(furnRef)
        If bt != "" && bt != "none"
            furnType = bt
        EndIf
    EndIf

    ; 成立するlineupを探します。まず自動ソート、次に各プレイヤー位置で、最初に当たったのが勝ちです。
    Actor[] lineup = OActorUtil.Sort(group, RealMales(group))
    String sceneId = GetRandomRealScene(lineup, furnType)
    If sceneId == ""
        Int pos = 0
        While pos < n && sceneId == ""
            lineup = OActorUtil.Sort(group, RealMales(group), pos)
            sceneId = GetRandomRealScene(lineup, furnType)
            pos += 1
        EndWhile
    EndIf

    If sceneId == ""
        If furnRef != None
            Return LaunchGroup(group, None)   ; 失敗ゼロ＝床/立ちにフォールバックします
        EndIf
        Return -1
    EndIf

    Int builderID = OThreadBuilder.Create(lineup)
    If builderID < 0
        Return -1
    EndIf
    ; furnRef指定 -> その家具でシーンを行います。None -> startingNodeを空のままにして、OStimの
    ; handleStartingNodeにidle/intro立ちノードを選ばせます(自然な開始・自動&手動モード両対応)。
    If furnRef != None
        OThreadBuilder.SetFurniture(builderID, furnRef)
    Else
        OThreadBuilder.NoFurniture(builderID)
    EndIf
    Int threadID = OThreadBuilder.Start(builderID)
    If threadID >= 0
        ASTR2Native.ScenePreparingArm()   ; 起動成立＝watchdogをarmします（ここから戦闘/セル移動/TOで自動キャンセル・ThreadStartedで消灯）
    EndIf
    Return threadID
EndFunction

; ============================================================
; ナイトメア・エンブレイスのコア起動です。bedRef = 対象が寝ていた家具です。
; その(このグループでの)ベッドに本物のシーンが在る時だけ None/ベッド の2択を出します。
; ベッドシーンが無ければメニューを飛ばし自動で立ち起動します。あとはLaunchGroupで直接起動します
; (idle始まり・無アニメ死ゼロ)。threadIDを返します(>=0; 0=プレイヤー非同期)・無ければ-1です。
; ============================================================
Int Function LaunchNightmare(Actor[] group, ObjectReference bedRef) Global
    ObjectReference furnRef = None   ; 既定＝立ち/地面
    If bedRef != None
        String bt = OFurniture.GetFurnitureType(bedRef)
        If bt != "" && bt != "none" && GroupPlayable(group, RealMales(group), bt)
            ; 本物のベッドシーンが在る -> プレイヤーに None かベッドを選ばせます
            UIListMenu menu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
            menu.AddEntryItem("$ASTR2_Pick_WhichFurn")   ; 0 = 見出し(選択時は無視)
            menu.AddEntryItem("$ASTR2_Furn_None")        ; 1 = なし(立ち/地面)
            menu.AddEntryItem(FurnLabel(bt))             ; 2 = ベッド
            menu.OpenMenu()
            Int sel = menu.GetResultInt()
            If sel == 2
                furnRef = bedRef
            EndIf
            ; sel 0 (見出し) / 1 (なし) / -1 (キャンセル) -> 立ち
        EndIf
    EndIf
    Return LaunchGroup(group, furnRef)
EndFunction

; ============================================================
; グループ編成の中核です。グループを1人ずつ組み、成立しない組を絶対に作らせず、
; 選んだ位置にプレイヤーを置いて起動します。
;   - 性別判定はOStim Condition.cpp準拠です(futaUseMaleRoleはON前提):
;       base女 + 竿 -> フタ(AGENDER・どの枠も埋める) / 女 -> F / 男 -> M
;   - 「足せる?」= 足した後の人数で ASTR2Catalog.ComboPlayable(カタログ＝唯一の正＝
;       導入済みのシーンパック次第で適応・例 MMMMが無い)で判定します。
;   - プレイヤー位置の候補 = GetRandomSceneがシーンを見つけるplayerPos値です。
; ============================================================

; 0=男, 1=女, 2=フタ(両方)。1人のOStim上のマッチ性別を返します。
Int Function ClassifySex(Actor a) Global
    If a == None
        Return 0
    EndIf
    ; OStimのAppearsFemale(OStimがシーン選定に使う性別)を使います・base性別ではありません。
    ; SoS/TNGの性別判定がONだと、竿無しのbase男は女として読まれます。
    If !OUtils.AppearsFemale(a)
        Return 0   ; OStimは男と見ます
    EndIf
    If OActorUtil.HasSchlong(a)
        Return 2   ; 女に見える + 竿 = フタ(AGENDER・両役)
    EndIf
    Return 1       ; 女
EndFunction

; ============================================================
; 速度改善です: 性別判定/strict設定をパス単位でキャッシュします。
;   ClassifySex(AppearsFemale+HasSchlong native)を絞り込みループで連打していたのを潰します。
;   世代(gen)方式＝起動パス先頭でBumpSexGen()→genが変わるだけでキャッシュを一斉無効にします(明示クリア不要)。
;   genはプレイヤーに、各actorのsex+genは各actorにStorageUtilで保持します。
; ============================================================
; カウンタは専用キー"astr2_sexgen_ctr"(プレイヤー保持)＝per-actorマーカー"astr2_sexgen"と別物にします。
;   プレイヤーもグループ(CountSexes等)でCachedClassifySexされる＝同キーだとカウンタを踏む衝突が起きるためです。
Int Function CurrentSexGen() Global
    Return StorageUtil.GetIntValue(Game.GetPlayer(), "astr2_sexgen_ctr", 0)
EndFunction

Function BumpSexGen() Global   ; 起動パスの先頭で1回＝以降のsex/strictキャッシュを新世代にします
    StorageUtil.SetIntValue(Game.GetPlayer(), "astr2_sexgen_ctr", CurrentSexGen() + 1)
EndFunction

; ClassifySexのキャッシュ版です。同じactorの再判定はStorageUtil引きで済ませます(native連打を回避)。
Int Function CachedClassifySex(Actor a) Global
    If a == None
        Return 0
    EndIf
    Int gen = CurrentSexGen()
    If StorageUtil.GetIntValue(a, "astr2_sexgen", -1) == gen
        Return StorageUtil.GetIntValue(a, "astr2_sex", 0)
    EndIf
    Int s = ClassifySex(a)
    StorageUtil.SetIntValue(a, "astr2_sex", s)
    StorageUtil.SetIntValue(a, "astr2_sexgen", gen)
    Return s
EndFunction

; OStimの実設定(intendedSexOnly)をパス単位でキャッシュします＝ComboPlayableのstrictSexに正しい値を渡します。
; dll native ASTR2Catalog.OStimStrictSex() をパス先頭の1回だけ叩きます(以降はgenキャッシュ)。
Bool Function CachedStrictSex() Global
    Actor pc = Game.GetPlayer()
    Int gen = CurrentSexGen()
    If StorageUtil.GetIntValue(pc, "astr2_strictgen", -1) == gen
        Return StorageUtil.GetIntValue(pc, "astr2_strict", 1) == 1
    EndIf
    Bool st = ASTR2Catalog.OStimStrictSex()
    StorageUtil.SetIntValue(pc, "astr2_strict", st as Int)
    StorageUtil.SetIntValue(pc, "astr2_strictgen", gen)
    Return st
EndFunction

; グループ内の本物の男(非フタ・OStimが男と見る)を返します。DominantActorsとしてSortに渡し、
; 男枠(先頭)に置かせます -- 複数竿持ち(実M + フタ)で安定ソートが実Mを女枠に残してMFFFF等の
; 有効な組を取りこぼす問題を直すためです。
Actor[] Function RealMales(Actor[] group) Global
    Actor[] tmp = PapyrusUtil.ActorArray(group.Length)
    Int cnt = 0
    Int i = 0
    While i < group.Length
        If group[i] != None && CachedClassifySex(group[i]) == 0
            tmp[cnt] = group[i]
            cnt += 1
        EndIf
        i += 1
    EndWhile
    Return TrimActors(tmp, cnt)
EndFunction

; 男枠に固定するアクター = 実男 + NPCフタ(プレイヤー以外の竿持ち全員)です。
; NPCフタはM固定が必須です＝OStimのSortは竿持ちを女枠に固定できない(「F固定」が無い) -> M固定すれば
; 構成が揺れません(意図しないランダムさが消えます)。
; プレイヤー自身の枠はplayerIndexで設定するので、ここでは除外します。
Actor[] Function DomMales(Actor[] group) Global
    Actor pc = Game.GetPlayer()
    Actor[] tmp = PapyrusUtil.ActorArray(group.Length)
    Int cnt = 0
    Int i = 0
    While i < group.Length
        Actor a = group[i]
        If a != None && a != pc && (CachedClassifySex(a) == 0 || CachedClassifySex(a) == 2)
            tmp[cnt] = a
            cnt += 1
        EndIf
        i += 1
    EndWhile
    Return TrimActors(tmp, cnt)
EndFunction

; グループの人数を [男, 女, フタ] で返します。
Int[] Function CountSexes(Actor[] group) Global
    Int[] c = new Int[3]
    Int i = 0
    While i < group.Length
        If group[i] != None
            Int s = CachedClassifySex(group[i])
            c[s] = c[s] + 1
        EndIf
        i += 1
    EndWhile
    Return c
EndFunction

; 最終的なシーン成立判定 = OStimに訊きます。このグループちょうどで、プレイヤーに有効な枠が1つでもあれば true
; (GetRandomSceneがプレイヤーをどこかの位置に置いたシーンを見つける)です。
; この判定はOStimのSoS/TNG性別判定とフタを正しく扱います。
; 自前のClassifySex/CountSexes(base性別)はSoS/TNG性別がONだとOStimと食い違うことがある
;   ので、カタログのComboPlayableはヒントに過ぎず、〔門番〕はこの判定に委ねます。
; OLibrary.GetRandomSceneと同じですが「idle」プレースホルダ(静止ポーズ・本物のアニメでない)を飛ばし
; -> 本物のアニメのscene idを返します・idle/noneしか無ければ""です。GetRandomSceneはランダムなのでリトライします。
; これがidleだけの組(例 MM/MMM)を「成立しない」扱いにする仕掛けです。
; OStim自身の家具検索半径・OStimのグローバルからLIVEで読みます(OStim完全一致・プレイヤーのMCM設定込み)。
; OStim: radius = (OStimFurnitureSearchDistance + 1) * 100 (OSexIntegrationMain.psc:1872)。
; OStim.espのGlobal 0xDA8(GlobalFloat・メートル・既定15)。
; sameFloorはOStimの定数96.0を使います(PlayerThreadStarter/NPCThreadStarter/EventListener)。
Float Function FurnitureRadius() Global
    GlobalVariable g = Game.GetFormFromFile(0xDA8, "OStim.esp") as GlobalVariable
    Float meters = 15.0   ; グローバルが見つからない時のOStim既定です
    If g != None
        meters = g.GetValue()
    EndIf
    Return (meters + 1.0) * 100.0
EndFunction

; furnType "none"/"" -> 家具なし(GetRandomScene・立ち/地面のバケット)、
; それ以外の種別(bed/chair/…) -> その種別のGetRandomFurnitureSceneです。idle飛ばしは共通です。
String Function GetRandomRealScene(Actor[] lineup, String furnType = "none") Global
    Int tries = 0
    While tries < 10
        String s
        If furnType == "" || furnType == "none"
            s = OLibrary.GetRandomScene(lineup)
        Else
            s = OLibrary.GetRandomFurnitureScene(lineup, furnType)
        EndIf
        If s == ""
            Return ""
        EndIf
        If !ASTR2Catalog.IsIdleScene(s)
            Return s
        EndIf
        tries += 1
    EndWhile
    Return ""
EndFunction

; dom = 男枠に固定するアクター(DominantActors)です。既定の自動挙動ならRealMales(group)を渡し、
; 特定構成に固定したいなら組専用のセット(実男 + 一部フタ)を渡します。
Bool Function GroupPlayable(Actor[] group, Actor[] dom, String furnType = "none") Global
    ; 人数〔ゲート〕です: この人数のシーンがカタログに1つも無ければ GetRandomScene を呼ぶまでもなく成立しません。
    ;   人数はカタログの確実な情報(性別と違いOStimとズレない)なので安全に弾けます。カタログ無効なら弾きません。
    If !CountGateAllows(furnType, group.Length)
        Return false
    EndIf
    Int n = group.Length
    Int pos = 0
    While pos < n
        If GetRandomRealScene(OActorUtil.Sort(group, dom, pos), furnType) != ""
            Return true
        EndIf
        pos += 1
    EndWhile
    Return false
EndFunction

; 'candidate'を'currentGroup'に足しても成立するシーンが残るか? を返します＝選択メニューの1人ずつの〔門番〕です。
; OStim GetRandomScene(自前の性別カウントでなく)で〔ゲート〕します = 食い違い無しです。
; (currentGroupはNoneパディング無しのきれいな配列であること。)
Bool Function CanAddNpc(Actor[] currentGroup, Actor candidate, String furnType) Global
    If candidate == None
        Return false
    EndIf
    Int n = currentGroup.Length
    Actor[] tentative = PapyrusUtil.ActorArray(n + 1)
    Int i = 0
    While i < n
        tentative[i] = currentGroup[i]
        i += 1
    EndWhile
    tentative[n] = candidate
    ; 速度改善です：絞り込みはカタログ(C++ ComboPlayable・往復1回)で判定します＝GetRandomScene連打を廃止します。
    ;   strictSexはOStim実設定(intendedSexOnly)をCachedStrictSexで反映／性別はCachedClassifySex経由で連打を潰します。
    ;   最終的な判定(requirements込み)はPlayerPositions/LaunchSceneのGetRandomSceneが1回だけ担います＝無アニメには戻りません。
    Int[] cs = CountSexes(tentative)
    Return ASTR2Catalog.ComboPlayable(furnType, cs[0], cs[1], cs[2], CachedStrictSex())
EndFunction

; この完成グループでの有効なプレイヤー枠のindexを返します(プレイヤーはグループ内に居ること)。
; = プレイヤーが役を取れてシーンが成立する位置です。
Int[] Function PlayerPositions(Actor[] group, Actor[] dom, String furnType = "none") Global
    Int n = group.Length
    Bool[] ok = PapyrusUtil.BoolArray(n)
    Int count = 0
    Int pos = 0
    While pos < n
        Actor[] lineup = OActorUtil.Sort(group, dom, pos)
        ok[pos] = (GetRandomRealScene(lineup, furnType) != "")
        If ok[pos]
            count += 1
        EndIf
        pos += 1
    EndWhile
    Int[] result = PapyrusUtil.IntArray(count)
    Int j = 0
    pos = 0
    While pos < n
        If ok[pos]
            result[j] = pos
            j += 1
        EndIf
        pos += 1
    EndWhile
    Return result
EndFunction

; プレイヤーを'playerPos'に置いて起動します。threadIDを返します(>=0; 0=プレイヤー非同期)・無ければ-1です。
; プレイヤーをplayerPosに置いて特定のシーンを起動します(ラベルと起動が一致 = メニューが見せた役が
; そのまま再生されます)。threadIDを返します(>=0; 0=プレイヤー非同期)・無ければ-1です。
Int Function LaunchScene(Actor[] group, Int playerPos, String sceneId, Actor[] dom, ObjectReference furnRef = None) Global
    If sceneId == ""
        Return -1
    EndIf
    Actor[] lineup = OActorUtil.Sort(group, dom, playerPos)
    Int builderID = OThreadBuilder.Create(lineup)
    If builderID < 0
        Return -1
    EndIf
    ; startingNodeを空のままにします(SetStartingAnimation/Sequenceを呼ばない)＝OStimのhandleStartingNodeに
    ; idle/intro立ちノードを選ばせます = 最初から自然に開始します(QuickStart/ナイトメア・エンブレイスと同じ)、自動&手動モード
    ; 両対応です。lineupはpos順ソート済みなのでプレイヤーの役は固定です。
    ; furnRef指定 -> その家具でシーンを行います; None -> 家具なし(立ち/地面・従来の挙動)です。
    If furnRef != None
        OThreadBuilder.SetFurniture(builderID, furnRef)
    Else
        OThreadBuilder.NoFurniture(builderID)
    EndIf
    Int threadID = OThreadBuilder.Start(builderID)
    If threadID >= 0
        ASTR2Native.ScenePreparingArm()   ; 起動成立＝watchdogをarmします（ここから戦闘/セル移動/TOで自動キャンセル・ThreadStartedで消灯）
    EndIf
    Return threadID
EndFunction

Int Function LaunchAtPosition(Actor[] group, Int playerPos, Actor[] dom, String furnType = "none", ObjectReference furnRef = None) Global
    Actor[] lineup = OActorUtil.Sort(group, dom, playerPos)
    String sceneId = GetRandomRealScene(lineup, furnType)
    If sceneId == ""
        Return -1
    EndIf
    Return LaunchScene(group, playerPos, sceneId, dom, furnRef)
EndFunction

; srcの先頭n人をきれいな配列(Noneパディング無し)で返します＝Sort/GetRandomScene用です。
Actor[] Function TrimActors(Actor[] src, Int n) Global
    Actor[] out = PapyrusUtil.ActorArray(n)
    Int i = 0
    While i < n
        out[i] = src[i]
        i += 1
    EndWhile
    Return out
EndFunction

; 自動モードです: 候補プールから、成立する最大の有効グループを貪欲に組み
; (プレイヤー + 足せるNPC・フタ柔軟・CanAddNpcで成立しない組は絶対作らない)、
; 最初の有効なプレイヤー位置で起動します。編成ロジックを一通り通す経路で、自動フォールバックも兼ねます。
; プレイヤーが手動で選ぶメニューもこの同じ部品を再利用します。
Int Function LaunchBestFromCandidates(Actor pc, Actor[] candidates, String furnType) Global
    BumpSexGen()   ; 起動パス先頭：性別/strictキャッシュを新世代にします(この後の絞り込みで使い回す)
    Actor[] work = PapyrusUtil.ActorArray(5)
    work[0] = pc
    Int cnt = 1
    Int i = 0
    While i < candidates.Length && cnt < 5
        Actor cand = candidates[i]
        If cand != None && cand != pc && !cand.IsDead() && !OActor.IsInOStim(cand)
            work[cnt] = cand
            Actor[] tentative = TrimActors(work, cnt + 1)
            Int[] cs = CountSexes(tentative)
            ; 速度改善です：カタログ(C++)で絞り込みます＝GetRandomScene連打を廃止します。最終的な判定は下のPlayerPositionsが1回で担います。
            ;   furnTypeは従来この絞り込みが"none"(GroupPlayable既定)だったのを踏襲します＝挙動不変です。
            If ASTR2Catalog.ComboPlayable("none", cs[0], cs[1], cs[2], CachedStrictSex())
                cnt += 1
            Else
                work[cnt] = None   ; 取り消し＝今のグループでは成立しません
            EndIf
        EndIf
        i += 1
    EndWhile

    Actor[] group = TrimActors(work, cnt)
    If cnt < 2
        Return -1
    EndIf

    Int[] positions = PlayerPositions(group, RealMales(group))
    If positions.Length == 0
        Return -1
    EndIf
    Return LaunchAtPosition(group, positions[0], RealMales(group))
EndFunction

; ============================================================
; プレイヤー操作の選択メニュー(UIExtensions)です。NPCを1人ずつ選びます -- 足せる人だけ表示します
; (CanAddNpcの〔門番〕 = 成立しない組を絶対作らない・フタ柔軟)、
; 「開始」で確定→プレイヤーの位置を選びます。threadIDを返します(>=0)・無ければ-1です。
; ============================================================
Int Function SelectAndLaunch(Actor pc, Actor speaker, Actor[] candidates, String furnType) Global
    BumpSexGen()   ; 起動パス先頭：性別/strictキャッシュを新世代にします(候補メニューの絞り込みで使い回す)
    ; speaker = 固定の会話相手です(常にシーンに入る)。None = 固定相手なし(Hキーテスト)です。
    Actor[] group
    If speaker != None && speaker != pc
        group = PapyrusUtil.ActorArray(2)
        group[0] = pc
        group[1] = speaker
    Else
        group = PapyrusUtil.ActorArray(1)
        group[0] = pc
    EndIf

    ; --- 家具ファーストです。家具は最大のフィルタなので、候補/位置より先に選びます＝残りを
    ;   それで成立するものに絞ります。ベースグループ(pc+speaker)で近くの家具を検出します; 家具の収容力が
    ;   足せる候補数の上限になります(CanAddNpcがfurnTypeで〔ゲート〕)。OStim自身の半径(FurnitureRadius)
    ;   + sameFloor 96.0です。「None」= 立ち/地面です。 ---
    furnType = "none"   ; 引数を再利用します(呼び手は"none"を渡す)。下のメニューが上書きします
    ObjectReference furnRef = None
    ObjectReference[] furns = OFurniture.FindFurniture(group.Length, pc, FurnitureRadius(), 96.0)
    If furns.Length > 0
        UIListMenu fmenu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
        fmenu.AddEntryItem("$ASTR2_Pick_WhichFurn")   ; index 0 = 見出し(選択時は無視)
        fmenu.AddEntryItem("$ASTR2_Furn_None")        ; index 1 = なし(立ち/地面)
        String[] fType = PapyrusUtil.StringArray(furns.Length)
        Int[] fIdx = PapyrusUtil.IntArray(furns.Length)   ; 選んだ項目から'furns'へ戻すindexです
        Int fCount = 0
        Int fi = 0
        While fi < furns.Length
            ObjectReference fr = furns[fi]
            If fr != None
                String ft = OFurniture.GetFurnitureType(fr)
                If ft != "" && ft != "none" && !HasFurnType(fType, fCount, ft) && CatalogHasCount(ft, group.Length)
                    fmenu.AddEntryItem(FurnLabel(ft))
                    fType[fCount] = ft
                    fIdx[fCount] = fi
                    fCount += 1
                EndIf
            EndIf
            fi += 1
        EndWhile
        If fCount > 0
            fmenu.OpenMenu()
            Int fsel = fmenu.GetResultInt()
            If fsel == -1
                Return -1
            ElseIf fsel >= 2
                furnRef = furns[fIdx[fsel - 2]]   ; -2 = 見出し(0) + なし(1)
                furnType = fType[fsel - 2]
            EndIf
            ; fsel 0 (見出し) / 1 (なし) -> furnType="none"/furnRef=Noneのまま
        EndIf
    EndIf

    Bool picking = true
    While picking && group.Length < 5
        UIListMenu menu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
        Actor[] addable = PapyrusUtil.ActorArray(candidates.Length)
        Int addCount = 0
        Int k = 0
        While k < candidates.Length
            Actor cand = candidates[k]
            If cand != None && cand != pc && !cand.IsDead() && !OActor.IsInOStim(cand) && !HasActor(group, cand) && CanAddNpc(group, cand, furnType)
                menu.AddEntryItem(cand.GetDisplayName() + SexLabel(cand))
                addable[addCount] = cand
                addCount += 1
            EndIf
            k += 1
        EndWhile

        If addCount == 0
            If group.Length < 2
                Return -1
            EndIf
            ; もう足せる相方が居ない -> 空の追加メニューを飛ばし、位置選択へ直行します
            picking = false
        Else
            Int startIdx = -1
            If group.Length >= 2
                startIdx = menu.AddEntryItem("$ASTR2_Pick_Start")
            EndIf
            Int cancelIdx = menu.AddEntryItem("$ASTR2_Pick_Cancel")

            menu.OpenMenu()
            Int sel = menu.GetResultInt()

            If sel == -1 || sel == cancelIdx
                Return -1
            ElseIf sel == startIdx
                picking = false
            ElseIf sel < addCount
                group = AppendActor(group, addable[sel])
            EndIf
        EndIf
    EndWhile

    If group.Length < 2
        Return -1
    EndIf

    ; メニューを開いてる間にアクターがbusy/deadになり得る -> 起動直前に再チェックします
    Int pickedCount = group.Length
    group = FilterEligible(group, pc)
    If group.Length < 2
        Debug.Notification("$ASTR2_Pick_MsgBusy")
        Return -1
    EndIf
    If group.Length < pickedCount
        Debug.Notification("$ASTR2_Pick_MsgDropped")
    EndIf

    ; フタ構成は起動時に固定できません(OStimのSortは竿持ちを常に男枠に置く + idle始まりはOStimが構成を選ぶ)
    ; -> 構成メニューは出しません。代わりに成立するプレイヤー位置を全部出します(プレイヤー自身の役はplayerIndex
    ; で固定できます)。dom = RealMales(既定ソート)です。
    ; 実男 + NPCフタ(プレイヤー以外の竿持ち)をM固定して構成が揺れないようにします。
    Actor[] dom = DomMales(group)
    Int[] positions = PlayerPositions(group, dom, furnType)
    If positions.Length == 0
        Debug.Notification("$ASTR2_Pick_MsgNoCombo")
        Return -1
    EndIf

    ; 成立する位置ごとに本物のシーンをロックし、各々プレイヤーの役(M/F) + 構成でラベル付けします。
    ; 成立する位置を全部出します(同じ役の選択肢からも選べるように・例 MFF/MMFFの複数の女枠)。
    ;   選択肢が1つだけの時だけ自動です。
    ; 各成立する位置を「<役><n>/<sig>」でラベルします(例 M1/MMFF, F2/MFFF) -- 役はその枠が要求する性別
    ;   (M/F/Futa)、nは役ごとの通し番号(どの構成のどの枠かが分かる)、sigは著者順の構成です。
    ;   ASCII = 全言語版/全フォントで安全です。
    String[] optScene = PapyrusUtil.StringArray(positions.Length)
    Int[] optPos = PapyrusUtil.IntArray(positions.Length)
    Int optCount = 0
    UIListMenu pmenu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
    pmenu.AddEntryItem("$ASTR2_Pick_WhichPos")   ; index 0 = 見出し「どの位置?」(選択時は無視)
    Int p = 0
    While p < positions.Length
        Int pos = positions[p]
        String sc = GetRandomRealScene(OActorUtil.Sort(group, dom, pos), furnType)
        If sc != ""
            ; ラベル = 役 + 枠の位置(pos+1)。例 MMMF -> M1/M2/M3/F4。ASCII = 全フォントで安全です。
            String role = ASTR2Catalog.GetSlotSex(sc, pos)   ; "M"/"F"/"A"
            String label
            ; ラベルは全部大文字で統一します＝M1/F2/FUTA3。sigが小文字で来ても拾えるよう m/f/a も判定します。
            If role == "F" || role == "f"
                label = "F" + (pos + 1)
            ElseIf role == "A" || role == "a"
                label = "FUTA" + (pos + 1)
            Else
                label = "M" + (pos + 1)
            EndIf
            pmenu.AddEntryItem(label)
            optScene[optCount] = sc
            optPos[optCount] = pos
            optCount += 1
        EndIf
        p += 1
    EndWhile

    If optCount == 0
        Debug.Notification("$ASTR2_Pick_MsgNoAnim")
        Return -1
    EndIf

    Int chosen = 0
    If optCount > 1
        ; 見出し行(index0「どの位置?」)は選択不可＝タップしても起動せず開き直します。
        ;   見出し選択でchosen=0のまま起動→OStimが周囲からメンバー探索へ移行する誤爆を止めます。
        ;   実選択(M1/M2…=index>=1)かキャンセル(-1)が来るまで無制限に再表示します。OpenMenuはユーザー入力待ちで
        ;   ブロックするので回数制限なしでも暴走しません(毎回プレイヤーの操作が要る＝CPU無限ループにならない)。
        chosen = -1
        While chosen < 0
            pmenu.OpenMenu()
            Int sel = pmenu.GetResultInt()
            If sel == -1
                Return -1
            ElseIf sel >= 1
                chosen = sel - 1   ; 実選択(M1/M2…)です。index 0の見出し行ぶん-1します。
            EndIf
        EndWhile
    EndIf

    Int tid = LaunchScene(group, optPos[chosen], optScene[chosen], dom, furnRef)
    If tid == -1
        Debug.Notification("$ASTR2_Pick_MsgFailStart")
    EndIf
    Return tid
EndFunction

; 家具ヘルパー -------------------------------------------------------------------------------
; 既出の家具種別か? を返します(重複排除＝各種別をメニューに1回だけ出す)。
Bool Function HasFurnType(String[] arr, Int count, String ft) Global
    Int i = 0
    While i < count
        If arr[i] == ft
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; この家具種別×この人数で、カタログにシーンが1つでもあるか? を返します。
; (今のグループ人数では実際に使えない家具は出さない)
Bool Function CatalogHasCount(String furnType, Int n) Global
    Int[] cs = ASTR2Catalog.AvailableCounts(furnType)
    Int i = 0
    While i < cs.Length
        If cs[i] == n
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

; 人数〔ゲート〕(GroupPlayable用)です: この人数のシーンがカタログに在れば true(=GetRandomSceneに進む)。
;   CatalogHasCountと違い、カタログ無効(dll不在/未構築でcs空)の時は true=弾きません(誤ブロック回避)。
;   性別は見ません(人数だけ)＝OStim性別判定とズレる罠を踏まない安全な事前フィルタです。
Bool Function CountGateAllows(String furnType, Int n) Global
    Int[] cs = ASTR2Catalog.AvailableCounts(furnType)
    If cs.Length == 0
        Return true   ; カタログ無効 -> 弾きません(GetRandomSceneに任せる)
    EndIf
    Int i = 0
    While i < cs.Length
        If cs[i] == n
            Return true
        EndIf
        i += 1
    EndWhile
    Return false   ; カタログ有効 & この人数のシーン無し -> 弾きます(GetRandomScene節約)
EndFunction

; 家具種別id -> 自前の$キーを返します(値はOStimの表記に合わせています)。
; 未マップ/modの種別は生id(ASCII)にフォールバックします＝何かしら表示されるように。
String Function FurnLabel(String ft) Global
    ; OStimのGetFurnitureTypeは具体id(例 singlebed)を返します; それを、OStimが表示するlistType表記に
    ; マッピングします(各種別のsupertype階層で解決・家具types JSONで確認済み)。
    ; bed系: bed/singlebed/doublebed/bedroll。table系: table/alchemy/enchanting/tableleanmarker(+BBLS)。
    ; wall系: wall/wardrobe(+thin/thick)。benchは独自名。chair/shelf/cookingpotは直です。
    If ft == "bed" || ft == "singlebed" || ft == "doublebed" || ft == "bedroll"
        Return "$ASTR2_Furn_Bed"
    ElseIf ft == "bench"
        Return "$ASTR2_Furn_Bench"
    ElseIf ft == "chair"
        Return "$ASTR2_Furn_Chair"
    ElseIf ft == "cookingpot"
        Return "$ASTR2_Furn_CookingPot"
    ElseIf ft == "shelf"
        Return "$ASTR2_Furn_Shelf"
    ElseIf ft == "table" || ft == "alchemytable" || ft == "enchantingtable" || ft == "tableleanmarker" || ft == "tableleanmarkerBBLS"
        Return "$ASTR2_Furn_Table"
    ElseIf ft == "wall" || ft == "wardrobe" || ft == "wardrobethin" || ft == "wardrobethick"
        Return "$ASTR2_Furn_Wall"
    EndIf
    Return ft   ; 未マップ/modの種別 -> 生id(ASCII)＝何かしら表示されるように
EndFunction

; 性別タグを素のASCII(M/F/Futa)で返します -- 全言語版/全フォントで安全(esp MiscObjectなし・$キーなし・
; 連結ラベル問題なし)です。sexClass: 0=M 1=F 2=フタ。
String Function GenderSym(Int sexClass) Global
    If sexClass == 2
        Return "Futa"
    ElseIf sexClass == 1
        Return "F"
    EndIf
    Return "M"
EndFunction

Bool Function HasActor(Actor[] group, Actor a) Global
    Int i = 0
    While i < group.Length
        If group[i] == a
            Return true
        EndIf
        i += 1
    EndWhile
    Return false
EndFunction

Actor[] Function AppendActor(Actor[] src, Actor a) Global
    Int n = src.Length
    Actor[] out = PapyrusUtil.ActorArray(n + 1)
    Int i = 0
    While i < n
        out[i] = src[i]
        i += 1
    EndWhile
    out[n] = a
    Return out
EndFunction

; メニューを開いてる間に不適格になった非プレイヤーを落とします(busy/dead/disabled)、
; OThreadBuilder.Createが古い選択で-1にならないようにします。プレイヤーはグループに残します。
Actor[] Function FilterEligible(Actor[] group, Actor pc) Global
    Actor[] work = PapyrusUtil.ActorArray(group.Length)
    Int cnt = 0
    Int i = 0
    While i < group.Length
        Actor a = group[i]
        If a == pc
            work[cnt] = a
            cnt += 1
        ElseIf a != None && !a.IsDead() && !a.IsDisabled() && !OActor.IsInOStim(a) && a.Is3DLoaded()
            work[cnt] = a
            cnt += 1
        EndIf
        i += 1
    EndWhile
    Return TrimActors(work, cnt)
EndFunction

; メニュー表示用の短い性別タグ = ClassifySex(OStim視点)経由の性別記号(M/F/フタ)です。
String Function SexLabel(Actor a) Global
    Return "  " + GenderSym(ClassifySex(a))
EndFunction
