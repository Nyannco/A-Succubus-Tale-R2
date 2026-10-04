Scriptname ASTR2Native Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; ASTR2SKSE.dll(C++ SKSEプラグイン)が提供するネイティブ関数群です。
; 実装＝src/HpBarFeed.cpp(OStim参加者をロックフリーでキャッシュしてここで返します)。
; dll未ロードまたはシーン非アクティブ時は空/Noneを安全に返します。

; プレイヤーのOStimシーン参加者です(プレイヤー除く・最大4)。
; HPバーが使うOThread.GetActors(0)のロックフリー代替です。
Actor[] Function GetSceneActors() Global Native

; キャッシュ済み参加者の数です(プレイヤー除く・解決可能なもの)。数(Int)で返すので「無し」になりません。
; ★先にこれを呼び、>0の時だけGetSceneActors()を呼びます＝空配列を返すネイティブはPapyrusでNone化します
; ＝「Actor[] x = GetSceneActors()」が代入時に「Cannot cast None to Actor[]」を連発します。
; カウントで〔門番〕すれば空代入を避けられます。
Int Function GetSceneActorCount() Global Native

; OStimシーン準備中HUDの表示開始です。起動フローの入口(会話選択後・メニュー開始前)にルートが呼びます。
; HUD「準備中」を点滅表示するだけです（この段階では自動キャンセルしません＝家具/メンバー/位置メニューの選択を邪魔しないため）。
; arm(ScenePreparingArm)後に戦闘/セル/TOの自動キャンセルが有効になります。ThreadStarted(実開始)/End(中止)で消えます。実装＝src/ScenePreparing.cpp。
Function ScenePreparingBegin() Global Native

; 準備中watchdogをarmします＝OThreadBuilder.Start成功直後にRoleFinderが呼びます。ここから戦闘/セル移動/5分TOで
; 自動キャンセルします(〔看板〕0＋ASTR2_SceneLaunchFailed送出)。Begin(表示のみ)からの移行＝メニュー中は邪魔しません。
Function ScenePreparingArm() Global Native

; 準備中HUDを消します＝起動フローが起動せず終了(ユーザーキャンセル/中止=tid<0)した時にルートが呼びます。
; 静かに消すだけです(ASTR2_SceneLaunchFailedは飛ばしません＝ユーザー自身のキャンセルなので通知不要)。
Function ScenePreparingEnd() Global Native

; ローカライズ(LocFmt)＝$翻訳キーを解決して実数を差し込み、完成した文字列を返します。MCMに「翻訳文＋数字」を
; 出せます(SkyUIは文字列まるごとが$キー1個に一致した時だけ訳す＝「$KEY」+数字の連結は$キーが生で残る)。
; 翻訳文に{0}/{1}/…のプレースホルダを置きます。valsは切り捨て整数。キー未収録は生キーを返します。現在の言語ファイル
; (+english fallback)を読みます＝全言語対応。実装＝src/Localization.cpp。
String Function LocFmt(String key, Float[] vals) Global Native
; LocFmtの単値版です（値を1個だけ渡す簡易版）。
String Function LocFmtF(String key, Float val) Global Native
; LocFmtの文字列版＝{0}/{1}/…に文字列(名前など)をそのまま差し込みます。数値も呼び側でStringにして渡せます
; ＝「○○を魅了できなかった (50/90)」のような名前+数字混在の通知文を作れる汎用版です。実装＝src/Localization.cpp。
String Function LocFmtStr(String key, String[] args) Global Native

; 実時計＝"YYYY-MM-DD HH:MM:SS"を返します。RareLog等の各行に「いつ」を刻みます＝VMon.log/クラッシュログ(壁時計)と
; 時刻照合できます。RareLogはセッション跨ぎで永続なので、起動相対のGetCurrentRealTimeでは意味を成しません＝壁時計が正です。実装＝src/Localization.cpp。
String Function Clock() Global Native
; 小数1桁の文字列("N.N")を返します＝MCM値カラムでfloatを小数表示する用です(LocFmtFはtruncateする)。+符号/単位は呼び側で付けます。ネイル現在効果の小数表示用。
String Function Fmt1(Float value) Global Native

; スキルXPボーナス＝全バニラスキルの獲得経験値に ×(1 + pct/100) を掛けます（サキュバスソウル）。
; pct(0..100)はPapyrus(ASTLvlManager.GetSkillXpBonus)が随時プッシュ＝Lv10で10%＋極大シャード数/1万・上限100%。
; dllがPlayerCharacter::AddSkillExperienceをフックして適用します＝バニラ効果欄には出ません(表示はMCM)。実装＝src/SkillXpBoost.cpp。
Function SetSkillXpBonus(Float pct) Global Native

; InfoHtml(SetInfoHtml)＝MCMのinfo欄をHTMLとして描きます＝<font color>が効きます。SkyUIのConfigPanelはinfo欄を
; TextField.text=(プレーン)で書く＝色タグが文字のまま出ます。これは同じ欄をGFx SetTextHTML(html描画)で
; 書き直します。色付けする行は SetInfoText の代わりにこれを OnOptionHighlight で呼びます(SkyUIが書き手で
; なくなる＝レース無し)。文字列は事前解決しておきます($キーはLocFmtで＝これはSkyUIの翻訳器を通しません)。
; GFxはUIスレッドで実行します(キュー投入)。実装＝src/InfoHtml.cpp。
Function SetInfoHtml(String html) Global Native

; 生者化(キス会話)＝立っている死霊を直接生者化します。ResurrectToLivingを即呼びます（起き上がり待ちなし）。
; Resurrect+commanded解除+ASTR2_VassalRisen送出→OnVassalRisenが味方化/〔サーヴァントシップ〕/淫紋/living=1を行います。実装＝src/VassalRaise.cpp。
Function ConvertVassalToLiving(Actor akVassal) Global Native
; クエストNPCガード用＝Reanimateが起こしつつある死体を見張り、起き上がり完了でKill＝死体に戻します（ASTConjCost.CancelRaiseが呼びます）
Bool Function CancelVassalRaise(Actor akCorpse) Global Native
; レア事象ログ＝C++(spdlog::warn)で ASTR2SKSE.log へ出します。旧 ASTR2_RareLog.txt 直書きを廃し出力先を一本化（実装 src/Localization.cpp）。ASTR2Log.Rare が呼びます。
Function LogRare(String tag, String msg) Global Native

; 🩹 不具合報告ファイル＝プレイヤーがこれ1枚を送れば状況が読める ASTR2_BugReport.txt を生成します（SKSEログフォルダ）。
;   astr2Ver＝ASTR2版数(呼び側の定数)／keys,vals＝呼び側が集めた「項目名／値」の対です（同じ並び・任意個）。
;   C++が生成時刻(壁時計)・ゲーム版数・ASTR2ロードindex・ASTR2_RareLog.txt末尾を足して書きます。戻り値＝生成先フルパス(失敗時"")。
;   駆動はMCMボタン→ASTR2BugReport.Generate()です。実装＝src/BugReport.cpp。
String Function WriteBugReport(String astr2Ver, String[] keys, String[] vals) Global Native

; 🩹 OStimシーン起動失敗の記録＝失敗3種(combat/cellmove/timeout)を全部ローリングログ ASTR2_SceneLaunchFail.txt へ
;   「時刻＋reason＋セル＋戦闘中」で1行appendし→200行で古い順にトリムします（肥大しない）。OnAstr2SceneLaunchFailedが毎回呼びます。
;   戦闘/移動キャンセルも拾います（「落ちる」報告の正体が戦闘ガードと切り分けられる）。実装＝src/BugReport.cpp。
Function LogSceneLaunchFail(String reason) Global Native

; 特定のOStim/OCRシーケンスをC++で直起動します（OStimの"Threads"窓口経由＝Papyrus VM遅延を挟まない）。
;   actors[0]が先頭(位置0)です。endAfter=trueでシーケンス終了時にスレッドも終了(演出向き)。undress=falseで服のまま。
;   戻り値＝threadID(>=0成功/-1失敗＝OStim不在・アクター不適格・空シーケンス)。実装＝src/SceneLauncher.cpp。
Int Function StartSequenceScene(Actor[] actors, String sequenceId, Bool endAfter, Bool undress) Global Native

; フィニッシュ判定の材料集め＝参加者ごとの「HP下限到達/特別NPC/山賊/敵対/戦闘中/召喚体/手下」を
; C++で一括収集し、akActorsと同じ並びのInt配列で返します（ビットの詰め合わせ）。
;   1=生存 / 2=下限到達 / 4=特別NPC(ユニーク・Essential・Protected・本物のフォロワー) / 8=山賊
;   16=術者に敵対 / 32=戦闘中 / 64=召喚体(Reanimate) / 128=使役中の手下(ActiveMinionFaction)
; ★H中はVMが詰まっていてネイティブ1回に25〜50msかかります＝参加者ごとに十数回問い合わせず1回にまとめます。
; ★「殺していいか」の判断はPapyrus側(ASTDrainScript)に残します＝保護ルールを追いやすい場所に置くためです。
; ★ビットは算術(% と /)で解きます＝Math.LogicalAnd(ネイティブ)を使わず、VM内で完結します。実装＝src/FinisherEval.cpp。
; afTolPct＝下限到達とみなす許容幅＝最大HPのこの割合です（固定1HPだと高HPの相手では永久に成立しません＝実機で確認）
Int[] Function GetFinisherFlags(Actor[] akActors, Actor akCaster, Float afFloorPct, Float afFloorAbs, Float afTolPct) Global Native

; パワー使用権（トークン）＝グレーターパワーの「1日1回」を1回ぶん解除する券です。
; アイテム使用でAddPowerTokens(1)＝貯まります／対象パワーを撃った瞬間にdllが1枚消費して通します。
; 対象＝ASTR2のGreater Power 5種（魅了3種/アンリーシュド・フューリー/スイート・ヴァッサル）。残数はSKSEコセーブに保存します。
; ★お気に入りから外れません＝RemoveSpell/AddSpellを使わず、キャスト判定の"答え"だけを差し替える方式です。
; 実装＝src/PowerReset.cpp。
Function AddPowerTokens(Int count) Global Native
Int Function GetPowerTokens() Global Native

; パワー使用権の対象範囲＝ASTR2のパワーは常に対象です（この設定に関係なく効きます）。
; 他MODのグレーターパワーも対象にするかをON/OFFします（既定ON・MCMから切替可）。
; ※自前クールダウンのMODはバニラのkPowerUsedを通らないのでそもそも対象外です。実装＝src/PowerReset.cpp。
Function SetPowerTokenOtherMods(Bool on) Global Native
Bool Function GetPowerTokenOtherMods() Global Native

; 汎用ファクション全リセット＝アクターに"ゲーム中に足したファクション"を、名指し(狙い撃ち)せず
; まとめて基テンプレート(ActorBase)構成へ巻き戻します＝通常状態(元の敵/中立)へ戻します。
; 本MODが足した物・他MODが足した物(例 OStim RomanceのIsOrWasFollower)を種類問わず一律に落とします＝オールリセット。
; スイート・ヴァッサルのお掃除ライブラリ ASTR2Cleanup.ResetActor から呼びます。実装＝src/FactionReset.cpp。
Function ResetRuntimeFactions(Actor akActor) Global Native

; 淫紋(ロゴ)C++化＝SKEE(NiOverride)をC++から直接叩いて淫紋を貼ります（Papyrus VMの列に並ばない）。実装＝src/Sigil.cpp。
; プレイヤー淫紋(Lv連動)を適用＝既存の淫紋を掃除→空き枠にテクスチャ/色/グロウを乗せます。
;   mode=0-3(Default/Legacy/Chest/Back)・level=1-6・glow=グロウ点灯・maleTex=竿ありor手動男テクスチャ。
;   種類/段階の中身＝見た目はPapyrus ApplyTattooと同一です（キー/値を踏襲）。
Function SigilApplyPlayer(Actor akActor, Int mode, Int level, Bool glow, Bool maleTex) Global Native
; 固定表示モードの淫紋を適用＝MCMの各fixed index(排他)から明示テクスチャを貼ります（内部で既存掃除→貼付で1枚）。
;   fLegacy=レガシー女(ASTR2Tatto)／fLegacyMale=レガシー男(MaleSucTattooMedium)＝ほころび解消。
;   全部0なら掃除のみです。
Function SigilApplyFixed(Actor akActor, Int fChest, Int fBack, Int fLegacy, Int fLegacyMale, Int fSmall, Int fMisc, Bool glow, Bool hasSchlong) Global Native
; アクターの淫紋を除去します（ASTR2Tatto/SucTattooを持つ枠のオーバーライドを撤去）。
Function SigilClear(Actor akActor) Global Native
; NPC淫紋(サキュバス・ウィークネス/手下)を適用＝股間固定・frac(残り時間0-1)→段階6→1・竿の有無で振り分けます。
;   ★貼る前に既存を掃除するので常に1枚＝サキュバス・ウィークネス→手下の順でも手下が上書きできます。
Function SigilApplyNpc(Actor akNpc, Float frac, Bool hasSchlong) Global Native

; 🧍 現在のプレイヤーのボディタイプです（MCMボディ欄の表示・手動プルダウン初期値）。0=3BA/1=UBE/2=バニラ。
Int Function SigilGetBodyType() Global Native
; 🧍 ボディ判定キャッシュ(Step B)を全消去します＝MCM「ボディ再検出」ボタン用です。環境(ボディMOD)を変えた後に押します。
Function SigilResetBodyCache() Global Native
; 🧍 個体別手動bt(Step C)＝ユニーク/カスタムフォロワーのボディ手動値です。-1=自動/0=3BA/1=UBE/2=バニラ。MCMリスト(Step D)が読み書きします。
Int Function SigilGetManualBt(Actor akActor) Global Native
Function SigilSetManualBt(Actor akActor, Int bt) Global Native
; 🧍 実効ボディ種別(Step D表示用)＝手動優先→自動検出の結果です(0=3BA/1=UBE・-1=非人型)。MCMリストの「名前(3BA)」表示に使います。
Int Function SigilGetEffectiveBt(Actor akActor) Global Native
; 🧍 カテゴリ(Step D振り分け)＝0=一般/1=ユニーク(結婚/フォロワー可能な固有NPC)/2=カスタム(非バニラesp)。
Int Function SigilGetActorCategory(Actor akActor) Global Native
; 🧍 個別排除(Step D)＝対象をリストから外します(再検出まで再登録しない)。true=除外/false=解除。
Function SigilSetExcluded(Actor akActor, Bool bExcluded) Global Native
; =====================================================================================
; ⏰ 淫魔力の時間減衰（〔クロノス〕のジョブ）
;   定期発火はC++が自動でやります。ここは「今すぐ1回」「MCM間隔の反映」「開始/停止(覚醒・デメリット)」の窓口です。
; =====================================================================================
; 今すぐ1回ぶん減衰を反映します（前回削った時刻からの経過ぶんだけ＝定期発火と二重に削らない）。
Function LFDecayTickNow() Global Native
; MCMスライダー(energyUpdateFreq)の値をC++の時計へ反映します＝次のコマから新しいグリッドになります。
Function LFDecaySyncInterval() Global Native
; 覚醒/デメリットON＝LF減衰を開始します（マーカーを"今"に置く＝OFF期間は請求しない）。
Function LFDecayStart() Global Native
; 覚醒OFF/デメリットOFF＝LF減衰を停止します（そもそも発火しない＝〔クロノス〕のジョブを止める）。
Function LFDecayStop() Global Native

; =====================================================================================
; 🩸 H中アクターHPバーの毎秒更新（〔クロノス〕が回します）
;   シーン開始時に4本のウィジェットの場所を渡します＝以後の%更新とフラッシュはC++が回します。
; =====================================================================================
Function HpBarBind(String[] widgetRoots) Global Native
Function HpBarUnbind() Global Native

; =====================================================================================
; 🔮 サキュバス・ウィークネス中のNPC淫紋（〔クロノス〕が段階を回します）
;   開始で1回 Begin（効果時間＝実時間の秒・竿の有無はPapyrusで判定して渡す）／終了で1回 End。
;   ★手下優先はロゴの表示だけです＝効果自体はエンジン管理で普通に効きます（判定はC++側）。
; =====================================================================================
Function WeaknessSigilBegin(Actor akNpc, Float afDurationSec, Bool abHasSchlong) Global Native
Function WeaknessSigilEnd(Actor akNpc) Global Native
; 覚醒OFF(人間化)＝NPCに残っている淫紋を能動的に全消しします（アンインストール前に印を残さない）
Function WeaknessSigilClearAll() Global Native
Function DrainMarkClearAll() Global Native
; 🌙 ナイトメア・エンブレイス用＝痕を打ちます(bNightmare=trueでトグル非依存・常に付く/男背中・女胸/24hで薄れる)。夢魔成功時に対象＋相方へ。
Function DrainMarkPunch(Actor akNpc, Bool bNightmare) Global Native

; =====================================================================================
; 🔢 バーの数字HUD（淫魔力/経験値バーの上に「現在値 / 最大値」を重ねます）
;   バーのウィジェットの場所を渡すだけです＝以後の表示更新はC++(〔クロノス〕)が回します。
;   表記はK/M/G・Lv100で経験値は"MAX"・ON/OFFと桁数(2/3)はMCM(〔SkyVault〕)で決めます。
; =====================================================================================
Function BarNumbersBind(String lfWidgetRoot, String expWidgetRoot) Global Native

; 🕯️ スイート・ヴァッサル：生者の手下の寵愛切れ死タイマーを（再）張ります＝lastLove更新(H/生者化)直後とロード時に呼びます。〔クロノス〕のTimeoutで期限ピッタリに死亡処理します。
Function ArmVassalLoveTimer(Actor akVassal) Global Native

; ▶️ スイート・ヴァッサル：維持費ジョブ(〔クロノス〕)を稼働させます＝手下の作成時(蘇生/生者化)とロード時に居れば呼びます。停止は0体を見た発火が自分でやります。
Function UpkeepStart() Global Native

; ⏹️ スイート・ヴァッサル：生者の寵愛切れ死タイマー(〔クロノス〕のScheduleAt)を取り消します＝覚醒OFF(人間化)で全手下解除時に亡霊予約を残さないためです。
Function CancelVassalLoveTimer(Actor akVassal) Global Native

; =====================================================================================
; 🩸 戦闘ドレイン（破壊ビーム）のC++核＝1秒tickをC++で定刻発火します（戦闘中のVM渋滞に非依存）。
;   Begin＝ビーム開始(ASTR2DrainTrigger.OnEffectStart)＝当てて+1秒で初回吸収→以後1秒ごとに吸収します。
;     canKill＝Papyrus CanKillTarget()が算出して渡します（C++でMCM/StorageUtil判定を再実装しないため）。
;   End＝ビーム終了(OnEffectFinish)。実装＝src/CombatDrain.cpp。後でまとめて記録するのはASTDrainScript.OnCombatDrainDoneです。
; =====================================================================================
Function CombatDrainBegin(Actor akCaster, Actor akTarget, Bool abCanKill) Global Native
Function CombatDrainEnd(Actor akTarget) Global Native


; 📋 ラヴェナス・ドレイン(Ravenous Drain)のステータスinfo表示用＝今Lvの現在値です（ON/OFF問わず）。
; 　GetRavenousRange＝効果範囲(メートル・半径)／GetRavenousMaxTargets＝同時に吸う最大人数です。実装＝src/CombatDrain.cpp。
Float Function GetRavenousRange() Global Native
Int Function GetRavenousMaxTargets() Global Native
; 🩸 ドレイン基礎量/秒＝2+(Lv-1)×8です（補正抜きの素の値）＝計算式は1か所にまとめています(src/CombatDrain.cpp DrainBaseNow)。
;   ASTDrainScript.GetBaseDrainPerSec(MCM表示) と NailDesc(サキュバス・ドレイン/ラヴェナス・ドレインの威力DESC) が両方これを呼びます＝式の二重持ちを解消しています。
Int Function GetDrainBaseNow() Global Native
; 💧 コンスーム・エッセンスの回復%/秒＝3.0×(1+(Lv-3)×0.05+Restoration/200)＝計算式は1か所にまとめています(src/CombatDrain.cpp)。ASTDrainScript.GetRegenPctPerSec と NailDesc(コンスーム・エッセンスDESC)が共用します。
Float Function GetRegenPctNow() Global Native
; 🩸 サキュバス・ウィークネスの耐性ダウン実効値＝(20+added)×手技×変性＝計算式は1か所にまとめています(src/CombatDrain.cpp)。ASTDrainScript.GetWeaknessResistDown と NailDesc(サキュバス・ウィークネスDESC)が共用します。
Int Function GetWeaknessDownNow() Global Native
; 🌙 ナイトメア・エンブレイスの"素のbase"(nmBase+(Lv-1)×nmPerLv・tech掛ける前)＝計算式は1か所にまとめています(src/SpellInfo.cpp)。★実挙動psc(ASTR2NightmareEffect)もMCM表示もDESCも全部これを呼びます＝式の二重持ちを解消しています。
Float Function GetNightmareBaseNow() Global Native
; 🌙 ナイトメア・エンブレイスの表示用成功確率＝base×腰使いcat0(+5%/rank)cap100(src/SpellInfo.cpp)。★実挙動はbase+興奮/tierにtechを掛けるので、表示は「対象文脈なしの代表値」です。NailDesc(ナイトメア・エンブレイスDESC)/MCM表示が使います。
Int Function GetNightmareChanceNow() Global Native
; 🩷 魅了3種の基本の色気注入量(スパイク)＝(SedBase+(Lv-1)×SedStep)×(1+攻め技cat6×0.05)＝計算式は1か所にまとめています(src/SpellInfo.cpp)。ASTSedMagEffScript.GetBaseSeductionSpike と NailDesc(魅了3種DESC)が共用します。
Float Function GetSeductionSpikeNow() Global Native
; 💋 アラウジング・ラストの興奮注入(素)＝LustBase×Lv＝計算式は1か所にまとめています(src/SpellInfo.cpp)。ASTLustEffect.GetBaseLustArousal と NailDesc(色欲DESC)が共用します。
Int Function GetLustArousalNow() Global Native
; 💋 色欲{1}のH中ドレイン素の威力＝calcDamage×totalMult(相手maxHP項抜き)＝計算式は1か所にまとめています(src/HDrain.cpp)。ASTDrainScript.GetHDrainPerOrgasm と NailDescが共用します。★実量は相手HPで変動します(表示は素)。
Int Function GetHDrainPerOrgasmNow() Global Native
; 🍯 ディスティル・エッセンス(Distill)のサイズ別コスト(aiSize 0=Petty/1=Lesser/2=Common/3=Greater/4=Grand)＝計算式は1か所にまとめています(src/SpellInfo.cpp)。ASTR2DistillEssenceEffect(支払い)/NailDesc(DESC)が共用します。
Int Function GetDistillLifeCost(Int aiSize) Global Native
Int Function GetDistillManaCost(Int aiSize) Global Native
; 💎 クリエイト・シャード(Shard)のサイズ別"素"淫魔力コスト(aiSize 0=Petty..4=Grand)＝計算式は1か所にまとめています(src/SpellInfo.cpp)。ASTR2CreateShardEffect(支払い/GetShardCost)/NailDesc(DESC)が共用します。★実支払いは別途ShardCostMultを掛けます(これは素)。
Int Function GetShardLifeCost(Int aiSize) Global Native

; =====================================================================================
; 🔥 アンリーシュド・フューリー（Fury）＝グレーターパワーのトグルです。ON/OFF切替はPowerReset(SpellCast)がC++で駆動します（この関数も呼びます）。
;   ON=Lv別バフ適用＋毎秒LF消費開始／再押しOFF=バフ撤去＋累計消費LF×10%を変性XPへ／LF0で自動OFF。
;   バフ・コスト・ダメカ・XPは全部C++が管理します。実装＝src/Fury.cpp。
; =====================================================================================
; 🔥 アンリーシュド・フューリーの強制解除＝覚醒OFF(人間化)でUnSuccubyが呼びます＝バフ全撤去＋累計消費LF×10%を変性XPへ＋停止（覚醒契約）。
Function FuryForceOff() Global Native
; 🔥 MCM表示用＝アンリーシュド・フューリーONで各スキルに乗る現在の+Nです（式B・破壊/回復/召喚/幻惑/変性で共通）。OFF中も「今ONなら幾つ」のプレビューを返します。
Int Function GetFuryBoostNow() Global Native
; 🔥 MCM表示用＝アンリーシュド・フューリーの%強化(式A・魔法耐性/落下耐性/ダメカ)の現在値です(cap100)。OFF中もプレビューします。
Int Function GetFuryResistNow() Global Native
; 🔥 MCM表示用＝アンリーシュド・フューリーの維持コスト＝淫魔力/秒です（最大LF×(11-Lv)×0.1%・Lv10=0.1%…Lv4=0.7%）。OFF中もプレビューします。
Int Function GetFuryCostNow() Global Native

; =====================================================================================
; 💧 エッセンス・フロウ（Essence Flow）＝ステータスinfo表示用の現在値getterです。
;   ON/OFF問わず「今ONにしたら」の値を返します（アンリーシュド・フューリー/コンスーム・エッセンスのgetterと同じ流儀）。実装＝src/EssenceFlow.cpp。
; =====================================================================================
; 💧 回復量＝最大HPの実効%/秒です（kRegenPctPerSec×boost＝Lv/Restoration/Hスキル自慰cat4込み・コンスーム・エッセンスのGetRegenPctPerSec と同じ%返し）。
Float Function GetFlowHealNow() Global Native
; 💧 維持コスト＝淫魔力/秒です（アンリーシュド・フューリー式＝最大LF×(11-Lv)×0.1%）。
Int Function GetFlowCostNow() Global Native

; =====================================================================================
; 🧟 スイート・ヴァッサル（Sweet Vassal）＝今の蘇生可能日数＝計算式は1か所にまとめています（実装＝src/VassalUpkeep.cpp）。
;   日数 = min(999, baseDays[〔SkyVault〕 ASTR2_VassalBaseDays] × サキュバスLv × (1+召喚/100))。
;   MCM表示(ASTConjCost.CalcVassalDays)と〔アレテイア〕の呪文DESCが両方これを呼びます＝式の二重持ちを解消しています。
; =====================================================================================
Float Function GetReanimVassalDays() Global Native
