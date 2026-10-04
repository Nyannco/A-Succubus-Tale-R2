#include "PCH.h"
#include "HpBarFeed.h"

// GetAPI() は GetModuleHandleA/GetProcAddress（Windows API）を使います＝external ヘッダの前に Windows.h を置きます。
#include <Windows.h>
#include "external/OstimNG-API-Thread.h"

#include "ScenePreparing.h"   // ThreadStarted で準備中インジケータを OFF にします

#include <mutex>
#include <vector>

// ============================================================================
// OStim参加者(プレイヤー除く)をロックフリーにキャッシュし、Papyrus へ返すプロバイダです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・OThread.GetActors の毎回取得（OStimロック競合＝フタナリ破綻シーンのデッドロックの元）を廃止する土台です。
//   ・読むだけで副作用はありません。HPバーの ApplyBar/表示ロジックは Papyrus 側に残します。
// ============================================================================

namespace {
    using namespace OstimNG_API::Thread;

    constexpr RE::FormID kPlayerFormID = 0x14;
    constexpr RE::FormID kOstimActiveGlobalID = 0x018C69;   // A Succubus Tale R2.esp の IsOstimActive（〔看板〕）です

    IThreadInterface* g_api = nullptr;

    // OStim実イベントで〔看板〕 IsOstimActive を駆動します＝desync を根治します。
    //   ThreadStarted(プレイヤーのシーン)→=1 を再assert＝Papyrusが遅延起動を誤判定して0にしたのを上書きで直します
    //   (1発で2回Hになるバグの真因)／ThreadEnded→=0。ESPの器(Global)は温存＝ForceGreet条件(==0)はPapyrus据置です。
    //   同値の二重書きは無害です(安全な切替順)。失敗ロールバック(=0)はPapyrusに残します(ThreadStarted
    //   が飛ばない起動失敗はC++が下ろせない＝逆向きのdesyncを防ぎます)。
    void SetOstimFlag(float v) {
        auto* dh = RE::TESDataHandler::GetSingleton();
        if (!dh) {
            return;
        }
        if (auto* g = dh->LookupForm<RE::TESGlobal>(kOstimActiveGlobalID, "A Succubus Tale R2.esp")) {
            g->value = v;
        }
    }

    std::mutex g_mutex;
    std::vector<RE::FormID> g_npcs;     // プレイヤー除く参加者です(最大4)
    uint32_t g_cachedThreadID = 0;
    bool g_hasCache = false;

    // 指定スレッドの参加者をキャッシュします（プレイヤーが居るシーン＝プレイヤーのHシーンのみ対象）。
    // 必ず AddTask 経由（メインスレッド・ロック解放後）で呼びます＝コールバック内の同期はデッドロックになります。
    void RefreshCache(uint32_t threadID) {
        if (!g_api) {
            return;
        }
        ActorData buffer[8]{};
        const uint32_t filled = g_api->GetActors(threadID, buffer, 8);

        bool hasPlayer = false;
        for (uint32_t i = 0; i < filled; ++i) {
            if (buffer[i].formID == kPlayerFormID) {
                hasPlayer = true;
                break;
            }
        }
        if (!hasPlayer) {
            return;  // プレイヤー不在＝NPC同士のシーン＝HPバー対象外です（既存キャッシュは触りません）
        }

        std::vector<RE::FormID> ids;
        for (uint32_t i = 0; i < filled && ids.size() < 4; ++i) {
            if (buffer[i].formID != kPlayerFormID) {
                ids.push_back(buffer[i].formID);
            }
        }
        {
            std::lock_guard lk(g_mutex);
            g_npcs = std::move(ids);
            g_cachedThreadID = threadID;
            g_hasCache = true;
        }
        spdlog::info("[HpBarFeed] cached npc(s) for thread={}", threadID);
        SetOstimFlag(1.0f);   // 〔看板〕=1 を再assert（プレイヤーのシーン実起動の瞬間＝desync を上書きで根治します）
        ScenePreparing::OnSceneStarted();   // シーン実開始＝準備中インジケータOFF＋watchdog停止です
    }

    void ClearCache(uint32_t threadID) {
        bool wasOurs = false;
        {
            std::lock_guard lk(g_mutex);
            if (g_hasCache && threadID == g_cachedThreadID) {
                g_npcs.clear();
                g_hasCache = false;
                wasOurs = true;
            }
        }
        if (wasOurs) {
            spdlog::info("[HpBarFeed] cache cleared for thread={}", threadID);
            SetOstimFlag(0.0f);   // 〔看板〕=0（プレイヤーのシーン正常終了＝OnOstimEnd 636 の移管先です）
            // 〔看板〕を0にした直後にモッドイベントを送出します＝これを購読して近接待機中の
            //   魅了NPCのForceGreet再評価(会話の引き継ぎ)を即実行します＝OnOstimEndの固定Wait(3)による推測待ちを廃止しイベント駆動にします。
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "ASTR2_SceneFlagCleared", "", 0.0f, nullptr };
                src->SendEvent(&ev);
                spdlog::info("[HpBarFeed] sent ModEvent ASTR2_SceneFlagCleared");
            }
        }
    }

    void OnThreadEvent(ThreadEvent eventType, uint32_t threadID, void* /*userData*/) {
        switch (eventType) {
        case ThreadEvent::ThreadStarted:
            // 再入回避：コールバック内で直接 GetActors せず次フレームへ回します（実機で確認したパターンです）。
            SKSE::GetTaskInterface()->AddTask([threadID]() { RefreshCache(threadID); });
            break;
        case ThreadEvent::ThreadEnded:
            // 〔看板〕=0 のGlobal書き込みもメインスレッドで行います（AddTask遅延）。
            SKSE::GetTaskInterface()->AddTask([threadID]() { ClearCache(threadID); });
            break;
        default:
            break;
        }
    }

    // ===== Papyrus native: ASTR2Native.GetSceneActors() =====
    //   キャッシュ済みの参加者(プレイヤー除く)を Actor[] で返します。シーン外/未取得なら空配列です。
    //   LookupByID は安全に呼べます＝OStim を叩かない＝ここで再入は起きません。
    std::vector<RE::Actor*> GetSceneActors(RE::StaticFunctionTag*) {
        std::vector<RE::Actor*> out;
        std::lock_guard lk(g_mutex);
        for (RE::FormID id : g_npcs) {
            if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(id)) {
                out.push_back(actor);
            }
        }
        return out;
    }

    // ===== Papyrus native: ASTR2Native.GetSceneActorCount() =====
    //   キャッシュ済み参加者数(プレイヤー除く・実体解決できる数)を Int で返します＝配列ではないので
    //   Papyrusで None 化しません。呼び手はこれを先に見て >0 の時だけ GetSceneActors() を呼びます＝
    //   空配列→None代入の「Cannot cast None to Actor[]」ログ連発を全呼び出し元(HPバー/Hold/RecordScene)で根絶します。
    //   GetSceneActors と同じ LookupByID で数えます＝count>0 ⟺ 非空返り を保証します(レースで空になりません)。
    std::int32_t GetSceneActorCount(RE::StaticFunctionTag*) {
        std::int32_t n = 0;
        std::lock_guard lk(g_mutex);
        for (RE::FormID id : g_npcs) {
            if (RE::TESForm::LookupByID<RE::Actor>(id)) {
                ++n;
            }
        }
        return n;
    }

}

namespace HpBarFeed {
    void Install() {
        g_api = GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        if (!g_api) {
            spdlog::warn("[HpBarFeed] OStim API取得失敗＝GetSceneActorsは空配列を返す（フリーズはしない）");
            return;
        }
        g_api->RegisterEventCallback(OnThreadEvent, nullptr);
        spdlog::info("[HpBarFeed] OStim API取得OK／参加者キャッシュ用コールバック登録");
    }

    std::vector<RE::FormID> SceneNpcs() {
        std::lock_guard<std::mutex> lock(g_mutex);
        return g_npcs;
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetSceneActors", "ASTR2Native", GetSceneActors);
        vm->RegisterFunction("GetSceneActorCount", "ASTR2Native", GetSceneActorCount);
        spdlog::info("[HpBarFeed] Papyrus native ASTR2Native.GetSceneActors / GetSceneActorCount 登録");
        return true;
    }
}
