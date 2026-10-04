#include "PCH.h"
#include "SceneGuard.h"
#include "Localization.h"    // 通知文の$key→現在言語
#include <Windows.h>
#include "external/OstimNG-API-Thread.h"   // シーン参加者の判定(GetActorPosition)

#include <thread>
#include <atomic>
#include <string>
#include <chrono>

// ============================================================================
// H中セーフティ監視です。std::threadは"待つ"だけ／RE::操作は全部 AddTask でゲームスレッドへ回します
//   （ScenePreparing/VassalRaise式）。停止は OThread.Stop(0) を VM DispatchStaticCall で1回呼びます。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace {
    using namespace OstimNG_API::Thread;
    IThreadInterface* g_api = nullptr;

    constexpr float kDangerRange = 1500.0f;   // この距離以内に敵対NPCが居たら強制終了します（安全寄り・要調整ならMCMスライダーにします）
    constexpr int   kStepMs      = 500;       // 走査間隔です

    std::atomic<bool>     g_active{ false };   // H(シーン)監視中かどうかです
    std::atomic<bool>     g_triggered{ false };// このシーンで既に強制終了を撃ったかどうかです（1回だけ）
    std::atomic<uint32_t> g_gen{ 0 };          // 監視スレッドの世代です（開始/終了で無効にします）
    std::atomic<uint32_t> g_thread{ 0 };       // 追跡中のOStimスレッドIDです

    // ★当たる前にシーンを畳みます＝OThread.Stop(0)（Papyrus実績の呼び方）をVM経由で1回＋Debug通知を出します。
    void TriggerStop() {
        if (g_triggered.exchange(true)) return;   // 二重発火しません
        g_active.store(false);

        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        if (vm) {
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchStaticCall("OThread", "Stop", RE::MakeFunctionArguments(std::int32_t{ 0 }), callback);
        }
        // ★3行通知＝①発動 ②理由(H中に攻撃されるとクラッシュ) ③ヒント(襲われ注意)＝
        //   「なぜ止まったか」を理解して敵地を避けてもらうためです。Skyrim通知は積み上がるので3連発で構いません。
        const char* kNotifyKeys[3] = { "$ASTR2_Msg_SceneDanger", "$ASTR2_Msg_SceneDangerWhy", "$ASTR2_Msg_SceneDangerHint" };
        for (int i = 0; i < 3; ++i) {
            const std::string msg = Localization::LocFmtStrCpp(kNotifyKeys[i], {});
            if (!msg.empty()) {
                RE::DebugNotification(msg.c_str());
            }
        }
        spdlog::info("[SceneGuard] hostile detected within {:.0f} -> OThread.Stop(0) + 3-line notify", kDangerRange);
    }

    // 近接の敵対NPC走査です（ゲームスレッド：AddTaskから呼びます）。シーン参加者・味方・死体は除外します。
    void Scan() {
        if (!g_active.load() || !g_api) return;
        auto* pc = RE::PlayerCharacter::GetSingleton();
        if (!pc) return;
        auto* pl = RE::ProcessLists::GetSingleton();
        if (!pl) return;
        const uint32_t thread = g_thread.load();
        const RE::NiPoint3 ppos = pc->GetPosition();
        for (auto& handle : pl->highActorHandles) {
            auto ptr = handle.get();
            RE::Actor* a = ptr.get();
            if (!a || a == pc) continue;
            if (a->IsDead() || a->IsDisabled()) continue;
            if (g_api->GetActorPosition(thread, a->GetFormID()) >= 0) continue;   // シーン参加者は除外します
            if (!a->IsHostileToActor(pc)) continue;                              // 敵対のみです（魅了済の味方/相手は非敵対ですので自然に除外されます）
            if (ppos.GetDistance(a->GetPosition()) > kDangerRange) continue;
            TriggerStop();   // 敵検知＝当たる前に畳みます
            return;
        }
    }

    void StartWatchdog(uint32_t gen) {
        std::thread([gen]() {
            using namespace std::chrono;
            while (true) {
                std::this_thread::sleep_for(milliseconds(kStepMs));
                if (g_gen.load() != gen || !g_active.load()) break;
                SKSE::GetTaskInterface()->AddTask([gen]() {
                    if (g_gen.load() == gen && g_active.load()) Scan();
                });
            }
        }).detach();
    }
}

namespace SceneGuard {
    void Install() {
        g_api = GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        if (!g_api) {
            spdlog::warn("[SceneGuard] OStim API acquire FAILED (監視は動くが参加者除外が効かない)");
        } else {
            spdlog::info("[SceneGuard] installed (H中セーフティ監視).");
        }
    }

    void OnSceneStart(std::uint32_t threadID) {
        g_thread.store(threadID);
        g_triggered.store(false);
        g_active.store(true);
        const uint32_t gen = ++g_gen;
        StartWatchdog(gen);
    }

    void OnSceneEnd() {
        g_active.store(false);
        ++g_gen;   // 監視スレッドを停止します
    }
}
