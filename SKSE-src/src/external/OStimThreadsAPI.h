#pragma once

#include <cstdint>

// ============================================================================
// OStim の PluginInterface("Threads") 窓口を、OStim内部型を引っ張らずに叩くための
// 最小ABIヘッダ（消費側の再宣言）。SKEE窓口を最小namespaceで叩くのと同じ手。
//   ★vtableの順序は OStimNG-7.4c/skse/src/PluginInterface/... と厳密一致させること（ABI依存）。
//     呼ばない仮想関数も"宣言だけ"残す＝vtableオフセットを合わせるため（消してはいけない）。
//   出典ヘッダ（OStim=GPL-3.0・ASTR2もGPL-3.0so互換）：
//     PluginInterface.h / InterfaceMap.h / InterfaceExchangeMessage.h /
//     Threading/ThreadInterface.h / Threading/ThreadBuilder.h
//   取得手順（OStim Main.cpp:52 で実装確認済）：
//     InterfaceExchangeMessage を 'OST' で "OStim" へ Dispatch → interfaceMap が埋まる →
//     interfaceMap->queryInterface("Threads") → ThreadInterface* → createThreadBuilder(...)。
// ============================================================================

namespace OStim {
    // 使わない型は前方宣言のみ（引数/戻り値の型合わせ用。中身は触らない）。
    class Node;
    class Thread;
    class ThreadEventListener;
    class ThreadActorEventListener;

    class PluginInterface {
    public:
        PluginInterface() {}
        virtual ~PluginInterface() {}
        virtual std::uint32_t getVersion() = 0;
    };

    class InterfaceMap {
    public:
        virtual PluginInterface* queryInterface(const char* name) = 0;
        virtual bool             addInterface(const char* name, PluginInterface* pluginInterface) = 0;
        virtual PluginInterface* removeInterface(const char* name) = 0;
    };

    struct InterfaceExchangeMessage {
        enum : std::uint32_t { MESSAGE_TYPE = 'OST' };
        InterfaceMap* interfaceMap = nullptr;
    };

    // ★ThreadBuilder.h と厳密一致（呼ぶのは setStartingSequence / endAfterSequence /
    //   noUndressing / noFurniture / start のみ。残りは順序合わせの宣言）。
    class ThreadBuilder {
    public:
        virtual void         setDominantActors(std::uint32_t actorCount, void** actors) = 0;
        virtual void         setFurniture(void* furniture) = 0;
        virtual void         setDuration(std::int32_t duration) = 0;
        virtual void         setStartingNode(Node* node) = 0;
        virtual void         setStartingNode(const char* node) = 0;
        virtual void         addStartingNode(Node* node, std::int32_t duration, bool navigateTo) = 0;
        virtual void         addStartingNode(const char* node, std::int32_t duration, bool navigateTo) = 0;
        virtual void         setStartingSequence(const char* sequence) = 0;
        virtual void         concatStartingSequence(const char* sequence, bool navigateTo) = 0;
        virtual void         endAfterSequence() = 0;
        virtual void         undressActors() = 0;
        virtual void         noAutoMode() = 0;
        virtual void         noPlayerControl() = 0;
        virtual void         noUndressing() = 0;
        virtual void         noFurniture() = 0;
        virtual void         setMetadataCSV(const char* metadata) = 0;
        virtual std::int32_t start() = 0;
        virtual void         cancel() = 0;
    };

    // ★PluginInterface継承なので、基底のvtable(~dtor + getVersion)の後に自分の仮想関数が並びます。順序厳守。
    class ThreadInterface : public PluginInterface {
    public:
        inline static const char* NAME = "Threads";

        virtual Thread*        getThread(std::int32_t threadID) = 0;
        virtual void           registerThreadStartListener(ThreadEventListener* listener) = 0;
        virtual void           registerSpeedChangedListener(ThreadEventListener* listener) = 0;
        virtual void           registerNodeChangedListener(ThreadEventListener* listener) = 0;
        virtual void           registerClimaxListener(ThreadActorEventListener* listener) = 0;
        virtual void           registerThreadStopListener(ThreadEventListener* listener) = 0;
        virtual ThreadBuilder* createThreadBuilder(std::uint32_t actorCount, void** actors) = 0;
    };
}
