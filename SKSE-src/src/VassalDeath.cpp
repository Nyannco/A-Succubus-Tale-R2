#include "PCH.h"
#include "VassalDeath.h"

// ============================================================================
// 実体です（詳細は VassalDeath.h）。TESDeathEvent はメインスレッドで飛ぶので、
//   modevent 送出もそのまま同スレッドで行えます（AddTask不要）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
// ============================================================================

namespace {
    class VassalDeathSink : public RE::BSTEventSink<RE::TESDeathEvent> {
    public:
        static VassalDeathSink* GetSingleton() {
            static VassalDeathSink inst;
            return &inst;
        }

        RE::BSEventNotifyControl ProcessEvent(const RE::TESDeathEvent* a_event,
                                              RE::BSTEventSource<RE::TESDeathEvent>*) override {
            if (!a_event) {
                return RE::BSEventNotifyControl::kContinue;
            }
            auto* ref = a_event->actorDying.get();
            if (!ref) {
                return RE::BSEventNotifyControl::kContinue;
            }
            auto* actor = ref->As<RE::Actor>();
            if (!actor) {
                return RE::BSEventNotifyControl::kContinue;
            }
            // ASTR2手下ファクション(0101D278)所属だけに絞ります＝手下候補（全死亡でスパムしません）。
            static RE::TESFaction* minionFac = []() -> RE::TESFaction* {
                auto* dh = RE::TESDataHandler::GetSingleton();
                return dh ? dh->LookupForm<RE::TESFaction>(0x01D278, "A Succubus Tale R2.esp") : nullptr;
            }();
            if (!minionFac || !actor->IsInFaction(minionFac)) {
                return RE::BSEventNotifyControl::kContinue;
            }
            // ★dead フラグで弾きません＝再アニメ死霊は dead=false/isDead=false でしか飛ばしません（実機で確認）。
            //   手下ファクション(0101D278)の死亡イベントは全部 Papyrus へ渡します＝最終判定(死んでるか/生者の気絶除外)は
            //   OnVassalDied が VassalLiving/IsDead で行います。
            SKSE::ModCallbackEvent modEvent{};
            modEvent.eventName = "ASTR2_VassalDied";
            modEvent.sender = actor;
            SKSE::GetModCallbackEventSource()->SendEvent(&modEvent);
            return RE::BSEventNotifyControl::kContinue;
        }
    };
}

namespace VassalDeath {
    void Install() {
        auto* holder = RE::ScriptEventSourceHolder::GetSingleton();
        if (holder) {
            holder->AddEventSink(VassalDeathSink::GetSingleton());
            spdlog::info("[VassalDeath] TESDeathEvent シンク設置");
        } else {
            spdlog::warn("[VassalDeath] ScriptEventSourceHolder 取得失敗＝シンク未設置");
        }
    }
}
