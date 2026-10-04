#include "PCH.h"
#include "SceneLauncher.h"
#include "external/OStimThreadsAPI.h"

#include <mutex>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace {
    std::mutex               g_acquireMutex;
    OStim::ThreadInterface*  g_threads = nullptr;
    bool                     g_tried   = false;

    // OStim の "Threads" 窓口を1回だけ取得してキャッシュします。
    //   'OST' の InterfaceExchangeMessage を "OStim" へ Dispatch → OStim が interfaceMap を埋める
    //   （OStim Main.cpp:52 で確認）→ queryInterface("Threads") → ThreadInterface*。
    //   遅延取得＝初回起動時（＝OStim完全ロード後の実プレイ中）ですので確実です。取得は Dispatch の同期呼びで軽い処理です。
    OStim::ThreadInterface* AcquireThreads() {
        std::scoped_lock lk(g_acquireMutex);
        if (g_threads || g_tried) {
            return g_threads;
        }
        g_tried = true;
        // OStim.dll 不在なら Dispatch は空振りし interfaceMap は null のまま＝下の null 判定で弾けます
        // （GetModuleHandleA での事前チェックは冗長ですので置きません＝<Windows.h>依存も避けます）。
        OStim::InterfaceExchangeMessage msg;
        SKSE::GetMessagingInterface()->Dispatch(OStim::InterfaceExchangeMessage::MESSAGE_TYPE,
                                                &msg, sizeof(msg), "OStim");
        if (!msg.interfaceMap) {
            spdlog::warn("[SceneLauncher] OStim interfaceMap is null (OStim not initialized yet?)");
            g_tried = false;   // まだOStim未初期化かも＝次回再試行できるように戻します
            return nullptr;
        }
        g_threads = static_cast<OStim::ThreadInterface*>(
            msg.interfaceMap->queryInterface(OStim::ThreadInterface::NAME));
        if (g_threads) {
            spdlog::info("[SceneLauncher] OStim 'Threads' interface acquired (createThreadBuilder ready)");
        } else {
            spdlog::warn("[SceneLauncher] queryInterface(\"Threads\") returned null");
        }
        return g_threads;
    }
}

namespace SceneLauncher {
    std::int32_t StartSequence(const std::vector<RE::Actor*>& actors, const char* sequenceId,
                               bool endAfter, bool undress) {
        if (actors.empty() || !sequenceId || sequenceId[0] == '\0') {
            return -1;
        }
        OStim::ThreadInterface* threads = AcquireThreads();
        if (!threads) {
            return -1;
        }
        std::vector<void*> ptrs;
        ptrs.reserve(actors.size());
        for (RE::Actor* a : actors) {
            if (!a) {
                return -1;
            }
            ptrs.push_back(static_cast<void*>(a));
        }
        OStim::ThreadBuilder* b = threads->createThreadBuilder(static_cast<std::uint32_t>(ptrs.size()), ptrs.data());
        if (!b) {
            spdlog::warn("[SceneLauncher] createThreadBuilder returned null (actor ineligible?)");
            return -1;
        }
        b->setStartingSequence(sequenceId);
        if (endAfter) {
            b->endAfterSequence();
        }
        if (!undress) {
            b->noUndressing();
        }
        b->noFurniture();
        const std::int32_t tid = b->start();
        spdlog::info("[SceneLauncher] StartSequence '{}' actors={} endAfter={} undress={} -> threadID={}",
                     sequenceId, ptrs.size(), endAfter, undress, tid);
        return tid;
    }

    // Papyrus: Int Function StartSequenceScene(Actor[] actors, String sequenceId, Bool endAfter, Bool undress)
    std::int32_t Papyrus_StartSequenceScene(RE::StaticFunctionTag*, std::vector<RE::Actor*> actors,
                                            RE::BSFixedString sequenceId, bool endAfter, bool undress) {
        std::vector<RE::Actor*> v;
        v.reserve(actors.size());
        for (RE::Actor* a : actors) {
            if (a) {
                v.push_back(a);
            }
        }
        return StartSequence(v, sequenceId.c_str(), endAfter, undress);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("StartSequenceScene", "ASTR2Native", Papyrus_StartSequenceScene);
        spdlog::info("[SceneLauncher] Papyrus native ASTR2Native.StartSequenceScene registered");
        return true;
    }
}
