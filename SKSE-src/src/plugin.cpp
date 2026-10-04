#include "PCH.h"
#include "InputHandler.h"
#include "HpBarFeed.h"
#include "SceneCatalog.h"
#include "Technique.h"
#include "TechRank.h"
#include "TechHud.h"
#include "Localization.h"
#include "InfoHtml.h"
#include "VassalRaise.h"
#include "SkillXpBoost.h"
#include "FinisherEval.h"
#include "PowerReset.h"
#include "FactionReset.h"
#include "VassalDeath.h"
#include "Sigil.h"
#include "ScenePreparing.h"
#include "SceneLauncher.h"
#include "SceneGuard.h"
#include "HDrain.h"
#include "DrainMark.h"
#include "Chronos.h"
#include "LifeForceDecay.h"
#include "VassalUpkeep.h"
#include "BugReport.h"
#include "NailLazy.h"
#include "NailDesc.h"
#include "HpBarHud.h"
#include "WeaknessSigil.h"
#include "BarNumbers.h"
#include "VLoveHud.h"
#include "CombatDrain.h"
#include "ServantRoster.h"
#include "Fury.h"
#include "EssenceFlow.h"
#include "SpellInfo.h"
#include "ManaCost.h"

// ============================================================================
// A Succubus Tale R2 native SKSE plugin ― 本体です。各機能モジュールの初期化と
//   Papyrus native の登録、SKSEメッセージ（データロード完了等）の受け取りを行います。
//   ログは SKSE/Plugins/ASTR2SKSE.log へ出します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
// ============================================================================

namespace {
    // ログを SKSE のログフォルダ（Documents\My Games\...\SKSE\）へ出します
    void SetupLog() {
        auto logsFolder = SKSE::log::log_directory();
        if (!logsFolder) {
            return;
        }
        auto logFilePath = *logsFolder / "ASTR2SKSE.log";
        auto fileSink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(logFilePath.string(), true);
        auto logger = std::make_shared<spdlog::logger>("log", std::move(fileSink));
        logger->set_level(spdlog::level::warn);   // 配布版：info/debugを黙らせる（warn/err/クラッシュ原因は残す）。devはinfoのまま
        logger->flush_on(spdlog::level::warn);
        spdlog::set_default_logger(std::move(logger));
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse);
    BugReport::SetSkseVersion(skse->SKSEVersion());   // SKSE版数(packed uint32_t)を保持＝BugReportに載せます
    SetupLog();

    spdlog::info("ASTR2 SKSE plugin loaded.");

    // トランポリンを一括確保します（全フック共用）。★各Installで個別にAllocTrampolineすると後勝ちで
    //   先のフックのトランポリンが壊れるので、ここで1回だけ確保します。
    SKSE::AllocTrampoline(256);   // ★64→256＝Fury.cppの被ダメHitDataフック5本(write_branch<5>各≒14B)追加ぶん＋余裕です（増やすだけなので他フックに影響ありません）

    // 入力フック設置します（Shift+T → tfc トグル＋T暴発抑制）
    InputHandler::Install();

    // HPバー本番：OStim参加者プロバイダのPapyrusネイティブ(ASTR2Native.GetSceneActors)を登録します
    SKSE::GetPapyrusInterface()->Register(HpBarFeed::RegisterPapyrus);

    // OStimシーンカタログのPapyrusネイティブ(ASTR2Catalog.*)を登録します
    SKSE::GetPapyrusInterface()->Register(SceneCatalog::RegisterPapyrus);

    // Hスキル(C++)のPapyrusネイティブ(ASTR2Technique.GetSceneTechSeconds/ResetSceneTech)を登録します
    SKSE::GetPapyrusInterface()->Register(Technique::RegisterPapyrus);

    SKSE::GetPapyrusInterface()->Register(TechRank::RegisterPapyrus);

    SKSE::GetPapyrusInterface()->Register(TechHud::RegisterPapyrus);

    // LocFmt：$翻訳キー＋実数差し込みのPapyrusネイティブ(ASTR2Native.LocFmt/LocFmtF)を登録します
    SKSE::GetPapyrusInterface()->Register(Localization::RegisterPapyrus);

    // InfoHtml：MCM info欄を色付き(html)で描く Papyrusネイティブ(ASTR2Native.SetInfoHtml)を登録します
    SKSE::GetPapyrusInterface()->Register(InfoHtml::RegisterPapyrus);

    // スイート・ヴァッサル：死霊の生者化(ConvertVassalToLiving)と起こしかけガード(CancelVassalRaise)のPapyrusネイティブを登録します
    SKSE::GetPapyrusInterface()->Register(VassalRaise::RegisterPapyrus);

    // 🩹 不具合報告ファイル：1枚ダンプ ASTR2_BugReport.txt を生成するネイティブ(ASTR2Native.WriteBugReport)を登録します
    SKSE::GetPapyrusInterface()->Register(BugReport::RegisterPapyrus);

    // スキルXPボーナス：全バニラスキルXPに×(1+N/100)を掛けるPapyrusネイティブ(ASTR2Native.SetSkillXpBonus)を登録します
    SKSE::GetPapyrusInterface()->Register(SkillXpBoost::RegisterPapyrus);

    // フィニッシュ判定の材料集め：参加者のHP/下限/保護/敵判定をまとめて1回で返すネイティブ(ASTR2Native.GetFinisherFlags)を登録します
    SKSE::GetPapyrusInterface()->Register(FinisherEval::RegisterPapyrus);

    // スイート・ヴァッサル：生者の寵愛切れ死タイマーを張り替えるネイティブ(ASTR2Native.ArmVassalLoveTimer)を登録します
    SKSE::GetPapyrusInterface()->Register(VassalUpkeep::RegisterPapyrus);

    // パワー使用権：残数の取得/加算ネイティブ(ASTR2Native.AddPowerTokens/GetPowerTokens)を登録します
    SKSE::GetPapyrusInterface()->Register(PowerReset::RegisterPapyrus);

    // 汎用ファクション全リセット：ランタイム付与ファクションを基テンプレートへ巻き戻すネイティブ
    //   (ASTR2Native.ResetRuntimeFactions)を登録＝スイート・ヴァッサルのお掃除ライブラリ ASTR2Cleanup が使います。
    SKSE::GetPapyrusInterface()->Register(FactionReset::RegisterPapyrus);

    // 淫紋(ロゴ)C++化：淫紋ネイティブ(ASTR2Native.Sigil*)を登録します
    SKSE::GetPapyrusInterface()->Register(Sigil::RegisterPapyrus);

    // OStimシーン準備中インジケータ＋watchdog：ネイティブ(ASTR2Native.ScenePreparingBegin)を登録します
    SKSE::GetPapyrusInterface()->Register(ScenePreparing::RegisterPapyrus);

    // 特定シーンC++起動の土台：ネイティブ(ASTR2Native.StartSequenceScene)を登録＝OStimの"Threads"窓口経由で直起動します
    SKSE::GetPapyrusInterface()->Register(SceneLauncher::RegisterPapyrus);

    // 🔋 淫魔力の時間減衰(C++時計)：ネイティブ(ASTR2Native.LFDecayTickNow/LFDecaySyncInterval)を登録します
    SKSE::GetPapyrusInterface()->Register(LifeForceDecay::RegisterPapyrus);

    // 🩸 HPバーの毎秒更新(C++)：ネイティブ(ASTR2Native.HpBarBind/HpBarUnbind)を登録します
    SKSE::GetPapyrusInterface()->Register(HpBarHud::RegisterPapyrus);

    // 🔮 ウィークネス淫紋の段階更新(C++)：ネイティブ(ASTR2Native.WeaknessSigilBegin/End/ClearAll)を登録します
    SKSE::GetPapyrusInterface()->Register(WeaknessSigil::RegisterPapyrus);

    // 💋 痕(1回制限)の覚醒OFF掃除：ネイティブ(ASTR2Native.DrainMarkClearAll)を登録します
    SKSE::GetPapyrusInterface()->Register(DrainMark::RegisterPapyrus);

    // 🔢 バーの数字HUD(C++)：ネイティブ(ASTR2Native.BarNumbersBind)を登録します
    SKSE::GetPapyrusInterface()->Register(BarNumbers::RegisterPapyrus);

    // 🩸 戦闘ドレイン(C++)：ネイティブ(ASTR2Native.CombatDrainBegin/End)を登録します
    SKSE::GetPapyrusInterface()->Register(CombatDrain::RegisterPapyrus);

    // 🔥 アンリーシュド・フューリー(C++)：ネイティブ(ASTR2Native.FuryForceOff 等)を登録します
    SKSE::GetPapyrusInterface()->Register(Fury::RegisterPapyrus);

    // 💧 エッセンス・フロウ(C++)：ステータスinfo表示用の現在値getter(ASTR2Native.GetEssenceFlowHealNow/CostNow)を登録します
    SKSE::GetPapyrusInterface()->Register(EssenceFlow::RegisterPapyrus);

    SKSE::GetPapyrusInterface()->Register(SpellInfo::RegisterPapyrus);

    // 👑 サーヴァント一覧(C++)：ネイティブ(ASTR2Servantship.BuildRoster/GetRoster*)を登録＝MCM一覧の列挙をC++で1パス化します
    SKSE::GetPapyrusInterface()->Register(ServantRoster::RegisterPapyrus);

    // データロード完了時に ~ コンソールへ一行（メインメニューで ~ を開くと見えます）
    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message* message) {
        // ★SKEE(RaceMenu/NiOverride)のC++窓口取得＝kPostPostLoadで1回です。
        //   kPostLoadだとSKEEが自分の窓口を組む前に問い合わせて空振り(interfaceMap=null)します（実機で実証済みです）。
        //   kPostPostLoadは全プラグインのkPostLoad完了後なので、SKEEの窓口が組み上がっています（OStimも越境確定はkPostPostLoadです）。
        if (message->type == SKSE::MessagingInterface::kPostPostLoad) {
            Sigil::AcquireSkee();
        }

        // セーブロード安全弁：準備中を破棄＋「〔看板〕1だがシーン無し」の詰まりを解消します（ScenePreparing）。
        //   ＋火種(使用権トークン)を外部〔SkyVault〕から復元します（〔SkyVault〕のコセーブ読込後にシードします）。
        if (message->type == SKSE::MessagingInterface::kPostLoadGame) {
            ScenePreparing::OnLoadGame();
            PowerReset::SyncFromVault();
            TechRank::OnLoadGame();   // ★Hスキルランク：〔SkyVault〕の確定秒→C++キャッシュを作り直します
            DrainMark::OnLoadGame();  // 💋1回制限：セーブに残ってる痕の巡回(淫紋の段階更新)を再開します
            Chronos::OnLoadGame();  // ⏰ 時計の核：定期ジョブの発火コマをセーブから復元します（グリッドを保ちます）
            LifeForceDecay::SyncInterval();   // 🔋 MCMスライダーの間隔を反映します
        }
        // 新規ゲーム＝〔SkyVault〕は空なので火種0でシードします（表示GLOBもリセットします）。
        if (message->type == SKSE::MessagingInterface::kNewGame) {
            PowerReset::SyncFromVault();
            TechRank::OnLoadGame();   // ★Hスキルランク：新規は空なので全ランク0で初期化します
        }

        if (message->type == SKSE::MessagingInterface::kDataLoaded) {
            if (auto* console = RE::ConsoleLog::GetSingleton()) {
                console->Print("ASTR2 SKSE plugin loaded.");
            }
            spdlog::info("kDataLoaded: ASTR2 SKSE alive.");

            // HPバー本番：OStim参加者をキャッシュ(ThreadStarted/Ended購読)＝GetSceneActorsの供給元です
            HpBarFeed::Install();
            // OStim全シーンを事前カタログ化（1回）＝ASTR2_CatalogDump.txt へ自動ダンプ＝裏取り材料です
            SceneCatalog::Build();
            // Hスキル(C++)：OStim API取得＋NodeChanged購読＝体位ごとにカタログ行為索引から攻め/受け+技術秒を累積します
            Technique::Install();
            // H中ドレイン核(C++)：ostim_orgasm を直受け→〔門番〕3つ→威力式1:1→HP減→LF加算(〔SkyVault〕)→完了modevent（フルC++化です）
            HDrain::Install();
            // 💋1回制限：吸った相手にゲーム内24hの痕＋淫紋(6段階で薄れます)。既定OFF・MCMトグルで入/切できます。
            DrainMark::Install();
            // ⏰ 時計の核：常時動くタイマーはC++に1本だけです。各処理が自分の実行間隔（例：4時間）を
            //   申告して登録＝Papyrusから常駐タイマーを無くし、他MODのVMを占有しません。
            Chronos::Install();
            // 🔋 第1号ジョブ＝淫魔力の時間減衰です（間隔＝MCMスライダー・旧Papyrus tickの置き換えです）
            LifeForceDecay::Install();
            // 🧟 スイート・ヴァッサルの維持費2種（死霊の維持費・生者の維持費）を核へ（6ゲーム時間ごと・旧Papyrus巡回から移設します）
            VassalUpkeep::Install();
            // 🩸 H中のHPバー更新を核へ（実時間1秒ごと・Papyrusの毎秒ループを廃止します）
            HpBarHud::Install();
            // 🔮 ウィークネス中の淫紋段階を核へ（相手の数だけ立っていたPapyrusループを廃止します）
            WeaknessSigil::Install();
            // 🔢 淫魔力/経験値バーの上に「現在値 / 最大値」を重ねます（K/M/G表記・Lv100でMAX）
            BarNumbers::Install();
            // 💔 寵愛切れ警告HUD（本番＝VassalUpkeepが確定文字列をEnqueue→1体5秒ずつ表示します／ON-OFFはMCM実装=〔SkyVault〕 ASTR2_VLoveHudOn）。
            //   ★位置合わせは「MCMを閉じた瞬間プレビュー」＝旧「テスト常時表示 ASTR2_VLoveHudTest」は撤去済でこのフラグはもうありません。
            VLoveHud::Install();
            // H中セーフティ：近接敵をC++で軽くポーリング→当たる前にシーンを畳んでCTD回避します（Technique HandleStart/Endから駆動します）
            SceneGuard::Install();
            // LocFmt：現在言語の翻訳ファイル(+english fallback)を1回パースしてキャッシュします
            Localization::Build();
            // スキルXPボーナス：AddSkillExperienceフック設置します（全スキルXPに×(1+N/100)・値はPapyrusがSetSkillXpBonusで供給します）
            SkillXpBoost::Install();
            // ★グレーターパワーの日次CD解除：CheckCastの"判定結果"を差し替えます（お気に入りを壊さない方式です）
            //   火種(トークン)方式＝AddPowerTokensで貯めた券で1回解除します。ASTR2のグレーターパワーは常に対象です／他MODのパワーはMCMトグル(SetPowerTokenOtherMods)でON/OFFできます。
            PowerReset::Install();
            // スイート・ヴァッサル：手下の死亡即掃除＝TESDeathEventシンク設置します（再アニメ死霊でも確実に死亡を拾います）。
            //   手下ファクション所属の死亡→modevent ASTR2_VassalDied→Papyrus OnVassalDiedがAshifyVassal。
            VassalDeath::Install();
            // 🩸 戦闘ドレイン核(C++)：ビーム(MGEF01013622)の1秒tickをC++へ＝当てて+1秒で定刻吸収します(VM渋滞非依存です)。
            //   Papyrus(ASTR2DrainTrigger)は開始/終了の合図だけです／後回しの記録(XP/記帳/殺害)はOnCombatDrainDoneへ委譲します。
            CombatDrain::Install();
            // 🔥 アンリーシュド・フューリー(C++)：Voiceトグルのチャネル＝毎秒LF消費＋Lv別バフ＋ダメージ軽減/落下フック＋解除時変性XPです。
            Fury::Install();
            // 💧 エッセンス・フロウ(C++)：アンリーシュド・フューリー同型トグル＝毎秒HP%回復＋LF消費＋マジカ再生転用＋水色のもやです。トグルはPowerReset(SpellCast)が駆動します。
            EssenceFlow::Install();
            // 🩸 シンフル・ネイル・怠惰：魔法構え中の移動減速を打ち消します(Lv連動)＝アンリーシュド・フューリー速度も構え中に丸乗りします。〔クロノス〕実時間1秒tickです。
            NailLazy::Install();
            // 🩸 シンフル・ネイル・動的説明文：ツールチップに罪名+実数を差し込みます(TESDescription::GetDescriptionフック)。
            NailDesc::Install();
            // 🔵 魔法コスト列表示：CalculateMagickaCostを対象6呪文だけ横取り→
            //   魔法メニューのコスト列/カードに独自の実コストを出す＋バニラが詠唱時にその値で消費します。
            ManaCost::InstallCostHook();
        }
    });

    return true;
}
