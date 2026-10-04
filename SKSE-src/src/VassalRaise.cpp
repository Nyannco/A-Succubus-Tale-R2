#include "PCH.h"
#include "VassalRaise.h"

#include <chrono>
#include <mutex>
#include <string_view>
#include <thread>
#include <unordered_set>

// ============================================================================
// スイート・ヴァッサル(Sweet Vassal)の「生者化」native群です。★起こす(ふわー)のは ESP の Reanimate
//   archetype 効果(MGEF 0100BF75)がエンジンで直接やります＝これらのnativeは死体を起こしません。
//   ・ConvertVassalToLiving(キス会話)＝立ってる死霊を直接 ResurrectToLiving で生者化します。
//   ・CancelVassalRaise(クエストNPCガード)＝起こしかけをアニメグラフで見張り、起き上がり完了(GetUpEnd)でKill＝死体へ戻します。
//   フック確実化＝reanimateはアニメグラフを組み直すので1回購読は無音化します→
//     std::thread の"実時間"100ms間隔で再購読し続け、組み直し後グラフに必ず乗せます
//     （SKSE::AddTask再帰は同フレーム内で連続実行されburnして不発so使いません）。
//     5秒で GetUpEnd を拾えなくても強制生者化＝固着への最後の砦です。
//   生者化の順番＝Resurrect→生者状態(kAlive)→Reanimate効果をDispel→召喚体の紐付け解除。
//     ★Dispelは生者化の"後"なら崩れません（実機で確認）／"前"だと死体がcrumble→即灰化します（旧版で実機確認）。
//     ★Dispelしないで残すと、効果が「プレイヤーの死霊」として紐付けを付け直します＝「- 所有者名」表示＋会話不可になります。
//   ★実際のRE::オブジェクト操作は全てゲームスレッド(AddTask)で行います。std::threadは"待つ"だけで、
//     グラフ再購読/生者化のような状態変更はAddTaskへ投げます（別スレッドから直に触るとクラッシュ）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
// ============================================================================

namespace {
    constexpr std::string_view kGetUpDoneTag = "GetUpEnd"sv;   // 起き上がり完了タグです（実測確定）

    // 起こした実体を生者化します（Resurrect→生者状態→Reanimate効果を外す→召喚体の紐付けを外す、の順）。
    void ResurrectToLiving(RE::FormID a_id) {
        SKSE::GetTaskInterface()->AddTask([a_id]() {
            auto* a = RE::TESForm::LookupByID<RE::Actor>(a_id);
            if (!a) {
                return;
            }
            a->Resurrect(false, false);   // inventory/3D保持＝起こした実体をそのまま生者にします
            spdlog::info("[VassalRaise] -> Resurrect to living 0x{:X}", a_id);

            // ★Reanimate効果の Dispel は「生者化の後」に行います（下の★）。生者化の"前"に外すと死体がcrumble→灰化します。

            // commanded(召喚体)の旗を下ろします＝undead声(うー)/「解放して」/「- Prisoner」の元です。
            a->GetActorRuntimeData().boolFlags.reset(RE::Actor::BOOL_FLAGS::kIsCommandedActor);
            a->EvaluatePackage();
            // reanimateのライフステート(kReanimate=4)を生者(kAlive=0)へ強制＝青白い肌の着色を抜きます。
            a->SetLifeState(RE::ACTOR_LIFE_STATE::kAlive);
            spdlog::info("[VassalRaise] SetLifeState(kAlive) 0x{:X}", a_id);

            // ★Reanimate効果を外します＝生者化(Resurrect＋kAlive)の"後"・紐付け解除の"前"。
            //   残すと効果が毎フレーム「プレイヤーの死霊」として付け直す→下で外した commanded/commandingActor/
            //   プレイヤーの commandedActors が数フレームで元通り＝「- 所有者名」表示＋会話不可（ログで確認）。
            //   生者化の後に外せば崩れません（実機で確認・dead=False）。崩れたのは生者化の"前"に外していた旧版です。
            if (auto* mt = a->AsMagicTarget()) {
                mt->DispelEffectsWithArchetype(RE::EffectSetting::Archetype::kReanimate, false);
            }
            a->GetActorRuntimeData().boolFlags.reset(RE::Actor::BOOL_FLAGS::kIsCommandedActor);   // 外した後にもう一度下ろします（念押し）
            spdlog::info("[VassalRaise] dispelled Reanimate effects 0x{:X} dead={} commanded={}", a_id, a->IsDead(), a->IsCommandedActor());

            // commandingActor 実体リンクを空にします＝所有者名(Prisoner)＋ミニオンボイスを断ちます。
            {
                if (auto* proc = a->GetActorRuntimeData().currentProcess; proc && proc->middleHigh) {
                    proc->middleHigh->commandingActor = RE::ActorHandle{};
                    spdlog::info("[VassalRaise] cleared middleHigh->commandingActor 0x{:X}", a_id);
                }
                // プレイヤー側 commandedActors[] から自分を消します＝召喚枠を解放します。
                if (auto* player = RE::PlayerCharacter::GetSingleton()) {
                    if (auto* pproc = player->GetActorRuntimeData().currentProcess; pproc && pproc->middleHigh) {
                        auto& cmds = pproc->middleHigh->commandedActors;
                        for (auto it = cmds.begin(); it != cmds.end(); ++it) {
                            auto ni = it->commandedActor.get();
                            if (ni && ni.get() == a) {
                                cmds.erase(it);
                                spdlog::info("[VassalRaise] erased player commandedActors entry 0x{:X}", a_id);
                                break;
                            }
                        }
                    }
                }
            }

            // ★プレイヤー側の「この子を操る」効果(CommandEffect/ReanimateEffect)を外します。
            //   これが残ると毎フレームの処理で commanded/commandingActor/プレイヤーの一覧を張り直します＝「- 所有者名」＋会話不可になります
            //   （ログ：外した直後false→直後にTRUE）。操り先を先に空にしてからDispel＝終了処理がこの子に何もしません。
            //   同じ呪文の他の子の効果には触りません（まとめて外すと死霊のまま連れている子まで切れます）。
            int released = 0;
            if (auto* player = RE::PlayerCharacter::GetSingleton()) {
                if (auto* pmt = player->AsMagicTarget()) {
                    if (auto* list = pmt->GetActiveEffectList()) {
                        for (auto* ae : *list) {
                            auto* ce = skyrim_cast<RE::CommandEffect*>(ae);
                            if (!ce) continue;
                            auto tgt = ce->commandedActor.get();
                            if (tgt && tgt.get() == a) {
                                ce->commandedActor = RE::ActorHandle{};
                                ce->Dispel(true);
                                ++released;
                            }
                        }
                    }
                }
            }
            a->GetActorRuntimeData().boolFlags.reset(RE::Actor::BOOL_FLAGS::kIsCommandedActor);
            spdlog::info("[VassalRaise] player-side command effect released={} for 0x{:X}", released, a_id);

            spdlog::info("[VassalRaise] after unlink 0x{:X} dead={} commanded={}", a_id, a->IsDead(), a->IsCommandedActor());

            // ※HP回復は Resurrect(false,false) がエンジン側で戻すので明示処理は不要です。

            // 生者化を Papyrus へ通知します＝残FX除去/味方化の起点（OnVassalRisen が受けます）。
            SKSE::ModCallbackEvent modEvent{};
            modEvent.eventName = "ASTR2_VassalRisen";
            modEvent.sender = a;
            SKSE::GetModCallbackEventSource()->SendEvent(&modEvent);
            spdlog::info("[VassalRaise] mod event ASTR2_VassalRisen 送出 0x{:X}", a_id);
        });
    }

    // 起こしかけを"死体に戻す"＝クエストNPCガード(ASTConjCost.CancelRaise)用です。
    //   ★Dispelは同フレーム競合で空振り＆灰化/塵化は放棄済＝起き上がり完了後にKillして死体を転がすだけです。
    void CancelToCorpse(RE::FormID a_id) {
        SKSE::GetTaskInterface()->AddTask([a_id]() {
            auto* a = RE::TESForm::LookupByID<RE::Actor>(a_id);
            if (!a) {
                return;
            }
            a->KillImmediate();
            spdlog::info("[VassalRaise] cancel raise -> KillImmediate 0x{:X} dead={}", a_id, a->IsDead());
        });
    }

    // 見張り完了時の仕上げ＝cancel(クエストNPCガード)なら死体へ／通常は生者化します。
    void FinishGetUp(RE::FormID a_id, bool a_cancel) {
        if (a_cancel) {
            CancelToCorpse(a_id);
        } else {
            ResurrectToLiving(a_id);
        }
    }

    // ===== 起き上がり完了フック＝死体のアニメグラフを購読し、完了タグで生者化 =====
    class VassalGetUpSink : public RE::BSTEventSink<RE::BSAnimationGraphEvent> {
    public:
        static VassalGetUpSink* GetSingleton() {
            static VassalGetUpSink inst;
            return &inst;
        }

        // 追跡開始＝ゲームスレッドで呼ばれる前提です（CancelVassalRaise の AddTask 内から）。
        void Track(RE::Actor* a_corpse, bool a_cancel = false) {
            if (!a_corpse) {
                return;
            }
            RE::FormID id = a_corpse->GetFormID();
            {
                std::scoped_lock lk(_mutex);
                _pending.insert(id);
                if (a_cancel) {
                    _cancel.insert(id);
                } else {
                    _cancel.erase(id);
                }
            }
            Subscribe(a_corpse);   // まず即購読します（呼び出しはゲームスレッド）
            spdlog::info("[VassalRaise] getup-hook 購読開始 0x{:X}", id);

            // ★実時間の再購読ループ＝グラフ組み直し後にも必ず乗せます（別スレッドは"待つ"だけ）。
            std::thread([id]() {
                using namespace std::chrono_literals;
                constexpr int kMaxMs = 5000;
                constexpr int kStepMs = 100;
                for (int elapsed = 0; elapsed < kMaxMs; elapsed += kStepMs) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(kStepMs));
                    if (!GetSingleton()->IsPending(id)) {
                        return;   // GetUpEnd を拾って生者化済＝ループ終了です
                    }
                    // グラフ操作はゲームスレッドへ委譲します（別スレッドから直接触りません）。
                    SKSE::GetTaskInterface()->AddTask([id]() {
                        if (auto* a = RE::TESForm::LookupByID<RE::Actor>(id)) {
                            GetSingleton()->Subscribe(a);
                        }
                    });
                }
                // 5秒たってもGetUpEndを拾えませんでした＝強制生者化します（thrall固着の最後の砦）。
                if (GetSingleton()->TakePending(id)) {
                    const bool cancel = GetSingleton()->TakeCancel(id);
                    spdlog::warn("[VassalRaise] GetUpEnd 未検出→5秒タイムアウトで強制{} 0x{:X}", cancel ? "Kill(cancel)" : "生者化", id);
                    FinishGetUp(id, cancel);
                    SKSE::GetTaskInterface()->AddTask([id]() {
                        if (auto* a = RE::TESForm::LookupByID<RE::Actor>(id)) {
                            GetSingleton()->Unsubscribe(a);
                        }
                    });
                }
            }).detach();
        }

        RE::BSEventNotifyControl ProcessEvent(const RE::BSAnimationGraphEvent* a_event,
                                              RE::BSTEventSource<RE::BSAnimationGraphEvent>*) override {
            if (!a_event || !a_event->holder) {
                return RE::BSEventNotifyControl::kContinue;
            }
            RE::FormID id = a_event->holder->GetFormID();
            if (!IsPending(id)) {
                return RE::BSEventNotifyControl::kContinue;   // 対象外です（生者化済 or 別アクター）
            }
            spdlog::info("[VassalRaise][anim] 0x{:X} tag='{}' payload='{}'", id, a_event->tag.c_str(), a_event->payload.c_str());

            if (std::string_view(a_event->tag.c_str()) == kGetUpDoneTag) {
                if (TakePending(id)) {   // 二重発火を止めます＝最初の1回だけ通します
                    FinishGetUp(id, TakeCancel(id));
                    RE::FormID doneId = id;
                    SKSE::GetTaskInterface()->AddTask([doneId]() {
                        if (auto* a = RE::TESForm::LookupByID<RE::Actor>(doneId)) {
                            GetSingleton()->Unsubscribe(a);
                        }
                    });
                }
            }
            return RE::BSEventNotifyControl::kContinue;
        }

        bool IsPending(RE::FormID a_id) {
            std::scoped_lock lk(_mutex);
            return _pending.contains(a_id);
        }
        // pending なら true を返しつつ消します（アトミックに「自分が担当」を確定＝二重処理防止）。
        bool TakePending(RE::FormID a_id) {
            std::scoped_lock lk(_mutex);
            return _pending.erase(a_id) > 0;
        }
        // cancel(死体へ戻す)指定だったか＝取り出して消します。
        bool TakeCancel(RE::FormID a_id) {
            std::scoped_lock lk(_mutex);
            return _cancel.erase(a_id) > 0;
        }

        // グラフ全部へ自分をシンク登録します（重複はCommonLib側で弾かれるので繰り返しOK）。
        void Subscribe(RE::Actor* a) {
            RE::BSAnimationGraphManagerPtr mgr;
            if (a && a->GetAnimationGraphManager(mgr) && mgr) {
                for (const auto& graph : mgr->graphs) {
                    if (graph) {
                        graph->GetEventSource<RE::BSAnimationGraphEvent>()->AddEventSink(this);
                    }
                }
            }
        }
        void Unsubscribe(RE::Actor* a) {
            RE::BSAnimationGraphManagerPtr mgr;
            if (a && a->GetAnimationGraphManager(mgr) && mgr) {
                for (const auto& graph : mgr->graphs) {
                    if (graph) {
                        graph->GetEventSource<RE::BSAnimationGraphEvent>()->RemoveEventSink(this);
                    }
                }
            }
        }

    private:
        std::mutex _mutex;
        std::unordered_set<RE::FormID> _pending;
        std::unordered_set<RE::FormID> _cancel;   // 起き上がり後に生者化でなくKillする対象（クエストNPCガード）
    };

    // ===== Papyrus native: ASTR2Native.CancelVassalRaise(Actor akCorpse) -> Bool =====
    //   クエストNPCガード用＝Reanimateが起こしつつある死体を見張り、起き上がり完了(GetUpEnd)でKill＝死体に戻します。
    //   呼び元＝ASTConjCost.CancelRaise。
    bool CancelVassalRaise(RE::StaticFunctionTag*, RE::Actor* akCorpse) {
        if (!akCorpse) {
            return false;
        }
        RE::ActorHandle corpseH = akCorpse->CreateRefHandle();
        SKSE::GetTaskInterface()->AddTask([corpseH]() {
            if (auto a = corpseH.get()) {
                VassalGetUpSink::GetSingleton()->Track(a.get(), true);
            }
        });
        return true;
    }

    // ===== Papyrus native: ASTR2Native.ConvertVassalToLiving(Actor akVassal) =====
    //   立ってる死霊(Lv9+999日)をキス会話で"直接"生者化します＝CancelVassalRaiseの起き上がり待ちを介さず
    //   ResurrectToLiving を即呼びます（同じ生者化＝Resurrect+commanded解除+ASTR2_VassalRisen送出→OnVassalRisen）。
    void ConvertVassalToLiving(RE::StaticFunctionTag*, RE::Actor* akVassal) {
        if (!akVassal) {
            return;
        }
        ResurrectToLiving(akVassal->GetFormID());   // 中で AddTask＝ゲームスレッドで安全に実行します
    }
}

namespace VassalRaise {
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("ConvertVassalToLiving", "ASTR2Native", ConvertVassalToLiving);
        vm->RegisterFunction("CancelVassalRaise", "ASTR2Native", CancelVassalRaise);
        spdlog::info("[VassalRaise] Papyrus native ConvertVassalToLiving / CancelVassalRaise 登録");
        return true;
    }
}
