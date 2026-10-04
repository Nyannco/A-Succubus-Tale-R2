#include "PCH.h"
#include "ScenePreparing.h"

// GetAPI() は GetModuleHandleA/GetProcAddress（Windows API）を使います＝external ヘッダの前に Windows.h。
#include <Windows.h>
#include "external/OstimNG-API-Thread.h"

#include "RE/H/HUDMenu.h"   // HUDライブ表示の親メニュー(uiMovie=Scaleform)
#include "Localization.h"   // 「準備中」文言を$キーから引く(LocFmtStrCpp)

#include <atomic>
#include <chrono>
#include <string>
#include <thread>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace {
    using namespace OstimNG_API::Thread;

    constexpr RE::FormID kPlayerFormID = 0x14;
    constexpr RE::FormID kOstimActiveGlobalID = 0x018C69;   // A Succubus Tale R2.esp の IsOstimActive(〔看板〕)です
    constexpr int kStepMs = 100;
    constexpr int kTimeoutMs = 300000;   // 5分＝実開始が来ない時の最終安全弁です（戦闘/セル移動より遅い保険）

    // OStim C++ API（安全弁でプレイヤーがシーン内かを見る用）。遅延取得します（HpBarFeed 等と同じ GetAPI 経路）。
    IThreadInterface* g_api = nullptr;
    bool g_apiTried = false;
    IThreadInterface* OStimApi() {
        if (!g_apiTried) {
            g_apiTried = true;
            g_api = GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        }
        return g_api;
    }

    // 準備中の状態です。世代(gen)で古いwatchdogを弾きます（Begin毎に++）。
    std::atomic<bool> g_preparing{ false };   // フロー全体（会話選択→メニュー→起動待ち）＝HUD表示中
    std::atomic<bool> g_armed{ false };       // ★起動後(OThreadBuilder.Start成功)＝戦闘/セル/TOの自動キャンセルを有効化します
    std::atomic<std::uint32_t> g_gen{ 0 };
    std::atomic<RE::FormID> g_startCell{ 0 };

    void SetOstimFlag(float v) {
        auto* dh = RE::TESDataHandler::GetSingleton();
        if (!dh) {
            return;
        }
        if (auto* g = dh->LookupForm<RE::TESGlobal>(kOstimActiveGlobalID, "A Succubus Tale R2.esp")) {
            g->value = v;
        }
    }

    // --- HUD「OStim準備中」＝VMon実証の _root.createTextField 方式（HUDMenu uiMovie）。点滅=_alpha明滅。 ---
    //   ★毎回「在るか確認→無ければ作る」＝セル移動/メニューでHUDが作り直されてもテキストが自動復帰します。
    void HudApply(bool a_show, bool a_bright) {
        SKSE::GetTaskInterface()->AddTask([a_show, a_bright]() {
            auto* ui = RE::UI::GetSingleton();
            if (!ui) {
                return;
            }
            auto hud = ui->GetMenu<RE::HUDMenu>();
            if (!hud || !hud->uiMovie) {
                return;
            }
            auto& mv = hud->uiMovie;

            RE::GFxValue tf;
            if (!mv->GetVariable(&tf, "_root.ASTR2PrepHud") || !tf.IsObject()) {
                if (!a_show) {
                    return;  // 消すだけなら作りません
                }
                // 左下・VMon(2行=56+下余白30)の少し上に置きます＝重なりません。画面実寸から計算します（解像度非依存）。
                const RE::GRectF rect = mv->GetVisibleFrameRect();
                const double w = 900.0;
                const double hgt = 32.0;
                const double x = static_cast<double>(rect.left) + 30.0;
                const double y = static_cast<double>(rect.bottom) - hgt - 30.0 - 96.0;

                // AS2: createTextField(name, depth, x, y, width, height)
                RE::GFxValue args[6];
                args[0] = "ASTR2PrepHud";
                // ★深度は固定値でなく空き深度を取ります＝他MOD/VMonとの深度衝突を根絶します（同深度は後勝ちで前を消すため）。
                //   getNextHighestDepthは既存の最上より必ず上を返します＝作成順で自然に積まれ相対順序も保たれます。
                RE::GFxValue prepDepth;
                mv->Invoke("_root.getNextHighestDepth", &prepDepth, nullptr, 0);
                args[1] = prepDepth;
                args[2] = x;
                args[3] = y;
                args[4] = w;
                args[5] = hgt;
                RE::GFxValue made;
                if (!mv->Invoke("_root.createTextField", &made, args, 6)) {
                    return;
                }
                if (!mv->GetVariable(&tf, "_root.ASTR2PrepHud") || !tf.IsObject()) {
                    return;
                }
                tf.SetMember("html", RE::GFxValue(true));
                tf.SetMember("selectable", RE::GFxValue(false));
                tf.SetMember("multiline", RE::GFxValue(false));
                tf.SetMember("wordWrap", RE::GFxValue(false));
            }
            tf.SetMember("_visible", RE::GFxValue(a_show));
            if (a_show) {
                tf.SetMember("_alpha", RE::GFxValue(a_bright ? 100.0 : 40.0));   // 点滅（明↔淡）
                const std::string body = Localization::LocFmtStrCpp("$ASTR2_Hud_Preparing", {});
                const std::string html = "<font color='#FFD86B' size='20'>" + body + "</font>";
                tf.SetMember("htmlText", RE::GFxValue(html.c_str()));
            }
        });
    }

    // キャンセル（戦闘/セル移動/タイムアウト）＝〔看板〕0＋HUD消し＋ModEvent(理由)で既存Papyrusハンドラに後始末させます。
    //   ★ゲームスレッド前提です（watchdog の AddTask 内 or OnLoad）。
    void DoCancel(std::uint32_t a_gen, const char* a_reason) {
        if (g_gen.load() != a_gen) {
            return;   // 古い世代＝無視します
        }
        if (!g_preparing.exchange(false)) {
            return;   // 既に実開始/処理済です
        }
        g_armed.store(false);
        SetOstimFlag(0.0f);
        HudApply(false, false);
        if (auto* src = SKSE::GetModCallbackEventSource()) {
            SKSE::ModCallbackEvent ev{ "ASTR2_SceneLaunchFailed", a_reason, 0.0f, nullptr };
            src->SendEvent(&ev);
        }
        spdlog::info("[ScenePreparing] CANCEL ({}) -> flag0 + ModEvent ASTR2_SceneLaunchFailed", a_reason);
    }

    // watchdog本体＝VassalRaise式です。std::threadは"待つ"だけ・RE::操作は全部 AddTask でゲームスレッドへ回します。
    //   ★点滅はフロー全体(preparing)で常時です。自動キャンセル(戦闘/セル/TO)は arm 後(起動後)だけ＝
    //     メニュー選択中(未arm)は表示だけで邪魔しません。preparing が false になったら終了します。
    void StartWatchdog(std::uint32_t a_gen) {
        std::thread([a_gen]() {
            using namespace std::chrono;
            int elapsed = 0;   // 点滅用の総経過です（表示のみ）
            int armMs = 0;     // arm後の経過です（タイムアウト判定用）
            while (true) {
                std::this_thread::sleep_for(milliseconds(kStepMs));
                if (!g_preparing.load() || g_gen.load() != a_gen) {
                    return;   // End/実開始/上書き＝終了します
                }
                elapsed += kStepMs;
                const bool armed = g_armed.load();
                if (armed) {
                    armMs += kStepMs;
                }
                const bool bright = ((elapsed / 400) % 2) == 0;   // ~1.25Hz の明滅です
                const int armSnap = armMs;
                SKSE::GetTaskInterface()->AddTask([a_gen, bright, armed, armSnap]() {
                    if (!g_preparing.load() || g_gen.load() != a_gen) {
                        return;
                    }
                    HudApply(true, bright);   // 点滅更新（在るか確認→無ければ作り直し）＝常時
                    if (!armed) {
                        return;   // ★メニュー選択中(未arm)＝表示だけ・自動キャンセルしません
                    }
                    auto* pc = RE::PlayerCharacter::GetSingleton();
                    if (!pc) {
                        return;
                    }
                    if (pc->IsInCombat()) {
                        DoCancel(a_gen, "combat");
                        return;
                    }
                    RE::FormID cur = 0;
                    if (auto* cell = pc->GetParentCell()) {
                        cur = cell->GetFormID();
                    }
                    const RE::FormID start = g_startCell.load();
                    if (start != 0 && cur != 0 && cur != start) {
                        DoCancel(a_gen, "cellmove");   // プレイヤーがセル移動＝選んだアクターが不在になり得ます
                        return;
                    }
                    if (armSnap >= kTimeoutMs) {
                        DoCancel(a_gen, "timeout");   // 起動後、実開始が来ない最終安全弁です
                        return;
                    }
                });
            }
        }).detach();
    }

    // ===== Papyrus native: ASTR2Native.ScenePreparingBegin() =====
    //   起動フローの入口（会話選択後・メニュー開始前）にルートが呼びます＝HUD「準備中」を出します。
    //   まだ自動キャンセルはしません(armed=false)＝家具/メンバー/位置メニューの選択を邪魔しません。
    //   ThreadStarted(実開始)/End(中止)で消えます。
    void ScenePreparingBegin(RE::StaticFunctionTag*) {
        g_armed.store(false);
        const std::uint32_t myGen = g_gen.fetch_add(1) + 1;   // 新世代です（古いwatchdogを無効化）
        g_preparing.store(true);
        HudApply(true, true);
        StartWatchdog(myGen);
        spdlog::info("[ScenePreparing] BEGIN gen={} (HUD on, watchdog unarmed)", myGen);
    }

    // ===== Papyrus native: ASTR2Native.ScenePreparingArm() =====
    //   RoleFinder が OThreadBuilder.Start 成功(threadID>=0)直後に呼びます＝「シーン実開始待ち」へ移行します。
    //   ここから戦闘/セル移動/5分TO の自動キャンセルが有効になります。開始時プレイヤーセルを控えます。
    void ScenePreparingArm(RE::StaticFunctionTag*) {
        RE::FormID cell = 0;
        if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
            if (auto* c = pc->GetParentCell()) {
                cell = c->GetFormID();
            }
        }
        g_startCell.store(cell);
        g_armed.store(true);
        if (!g_preparing.load()) {
            // 念のため：Begin無しでArmが来ても表示は出します（想定外経路の保険）。
            const std::uint32_t myGen = g_gen.fetch_add(1) + 1;
            g_preparing.store(true);
            HudApply(true, true);
            StartWatchdog(myGen);
        }
        spdlog::info("[ScenePreparing] ARM startCell=0x{:X} (auto-cancel enabled)", cell);
    }

    // ===== Papyrus native: ASTR2Native.ScenePreparingEnd() =====
    //   起動フローが起動せず終了(ユーザーキャンセル/中止=tid<0)した時にルートが呼びます＝HUDを消します。
    //   ★静かに消すだけです（ASTR2_SceneLaunchFailed は飛ばしません＝ユーザー自身のキャンセルですので通知不要）。
    void ScenePreparingEnd(RE::StaticFunctionTag*) {
        if (g_preparing.exchange(false)) {
            g_armed.store(false);
            g_gen.fetch_add(1);
            HudApply(false, false);
            spdlog::info("[ScenePreparing] END (flow aborted/cancelled -> HUD off)");
        }
    }
}

namespace ScenePreparing {
    void OnSceneStarted() {
        // HpBarFeed の ThreadStarted(RefreshCache・ゲームスレッド)から呼ばれます。準備中OFF＋HUD消し＋watchdog無効化。
        if (g_preparing.exchange(false)) {
            g_armed.store(false);
            g_gen.fetch_add(1);
            HudApply(false, false);
            spdlog::info("[ScenePreparing] scene started -> preparing OFF");
        }
    }

    void OnLoadGame() {
        // セーブロード時の安全弁です。準備中を破棄＋「〔看板〕1だがシーン無し」の詰まりを解消します。
        g_preparing.store(false);
        g_armed.store(false);
        g_gen.fetch_add(1);
        SKSE::GetTaskInterface()->AddTask([]() {
            HudApply(false, false);
            auto* api = OStimApi();
            const bool inScene = api && api->IsActorInAnyThread(kPlayerFormID);
            if (!inScene) {
                auto* dh = RE::TESDataHandler::GetSingleton();
                if (dh) {
                    auto* g = dh->LookupForm<RE::TESGlobal>(kOstimActiveGlobalID, "A Succubus Tale R2.esp");
                    if (g && g->value != 0.0f) {
                        g->value = 0.0f;
                        spdlog::info("[ScenePreparing] load: stale IsOstimActive=1 with no scene -> reset 0");
                    }
                }
            }
        });
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("ScenePreparingBegin", "ASTR2Native", ScenePreparingBegin);
        vm->RegisterFunction("ScenePreparingArm", "ASTR2Native", ScenePreparingArm);
        vm->RegisterFunction("ScenePreparingEnd", "ASTR2Native", ScenePreparingEnd);
        spdlog::info("[ScenePreparing] Papyrus native ASTR2Native.ScenePreparingBegin / Arm / End 登録");
        return true;
    }
}
