#include "PCH.h"
// 🔬 診断native本体＝Debug専用。Release(NDEBUG)ではこのファイル全体を無効化します（PCHのみの空TUになります）。
#ifndef NDEBUG
#include "ProbeDump.h"
#include "Chronos.h"

#include <string>
#include <unordered_map>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace ProbeDump
{
    namespace {
        constexpr const char* kEsp           = "A Succubus Tale R2.esp";
        constexpr RE::FormID  kFollowQuestID = 0x01D7DC;   // ASTR2VassalFollowQuest（手下枠）

        std::string NameOf(const RE::TESForm* f) {
            if (!f) return "<none>";
            std::string n = f->GetName() ? f->GetName() : "";
            const char* ed = f->GetFormEditorID();
            if (ed && *ed) n += std::string("|") + ed;
            return n;
        }

        std::string ArchName(RE::EffectSetting::Archetype a) {
            using A = RE::EffectSetting::Archetype;
            switch (a) {
            case A::kReanimate:       return "Reanimate";
            case A::kSummonCreature:  return "SummonCreature";
            case A::kCommandSummoned: return "CommandSummoned";
            case A::kScript:          return "Script";
            case A::kValueModifier:   return "ValueModifier";
            case A::kPeakValueModifier: return "PeakValueModifier";
            case A::kCalm:            return "Calm";
            case A::kFrenzy:          return "Frenzy";
            case A::kParalysis:       return "Paralysis";
            case A::kInvisibility:    return "Invisibility";
            case A::kCloak:           return "Cloak";
            default:                  return "arch#" + std::to_string(static_cast<int>(a));
            }
        }

        // 操る系の効果（Command/Reanimate・Summon）なら「操っている相手」を文字列で返します。それ以外は空です。
        std::string CommandedOf(RE::ActiveEffect* ae) {
            RE::NiPointer<RE::Actor> t;
            if (auto* ce = skyrim_cast<RE::CommandEffect*>(ae)) {
                t = ce->commandedActor.get();
            } else if (auto* se = skyrim_cast<RE::SummonCreatureEffect*>(ae)) {
                t = se->commandedActor.get();
            } else {
                return "";
            }
            return t ? fmt::format(" commands={}(0x{:X})", NameOf(t.get()), t->GetFormID()) : " commands=<none>";
        }

        // ある相手に"かかっている"魔法効果を全部出します（誰にでも使います：対象NPC／プレイヤー）。
        int DumpEffects(RE::Actor* who, const std::string& label, const char* side) {
            int n = 0;
            if (auto* mt = who ? who->AsMagicTarget() : nullptr) {
                if (auto* list = mt->GetActiveEffectList()) {
                    for (auto* ae : *list) {
                        if (!ae) continue;
                        ++n;
                        auto* base = ae->GetBaseObject();
                        auto caster = ae->caster.get();
                        const auto fl = ae->flags.underlying();
                        spdlog::info("[Probe][{}] {}effect#{} {} 0x{:X} arch={} spell={} 0x{:X} caster={} elapsed={:.1f}/{:.1f} inactive={} dispelled={}{}",
                                     label, side, n, NameOf(base), base ? base->GetFormID() : 0,
                                     base ? ArchName(base->GetArchetype()) : "?",
                                     NameOf(ae->spell), ae->spell ? ae->spell->GetFormID() : 0,
                                     caster ? NameOf(caster.get()) : "<none>",
                                     ae->elapsedSeconds, ae->duration,
                                     (fl & static_cast<std::uint32_t>(RE::ActiveEffect::Flag::kInactive)) != 0,
                                     (fl & static_cast<std::uint32_t>(RE::ActiveEffect::Flag::kDispelled)) != 0,
                                     CommandedOf(ae));
                    }
                }
            }
            spdlog::info("[Probe][{}] {}activeEffects total={}", label, side, n);
            return n;
        }

        void DumpNow(RE::Actor* a, const std::string& label) {
            if (!a) {
                spdlog::info("[Probe][{}] <none>", label);
                return;
            }
            const auto id = a->GetFormID();
            spdlog::info("[Probe][{}] ===== {} 0x{:X} =====", label, NameOf(a), id);
            spdlog::info("[Probe][{}] commanded={} teammate={} dead={} lifeState={} inCombat={}", label,
                         a->IsCommandedActor(), a->IsPlayerTeammate(), a->IsDead(),
                         static_cast<std::uint32_t>(a->AsActorState()->GetLifeState()), a->IsInCombat());

            // 操っている人（この子のプロセスが持つ commandingActor）
            if (auto* proc = a->GetActorRuntimeData().currentProcess; proc && proc->middleHigh) {
                auto cmd = proc->middleHigh->commandingActor.get();
                spdlog::info("[Probe][{}] commandingActor={}", label, cmd ? NameOf(cmd.get()) + " 0x" + fmt::format("{:X}", cmd->GetFormID()) : "<none>");
            } else {
                spdlog::info("[Probe][{}] commandingActor=<no middleHigh process>", label);
            }

            // プレイヤーの「操っている一覧」
            if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                if (auto* pp = pc->GetActorRuntimeData().currentProcess; pp && pp->middleHigh) {
                    std::string s;
                    bool mine = false;
                    for (auto& e : pp->middleHigh->commandedActors) {
                        auto ni = e.commandedActor.get();
                        if (!ni) continue;
                        if (ni.get() == a) mine = true;
                        s += fmt::format(" {}(0x{:X})", NameOf(ni.get()), ni->GetFormID());
                    }
                    spdlog::info("[Probe][{}] player.commandedActors n={} containsThis={} :{}", label,
                                 pp->middleHigh->commandedActors.size(), mine, s);
                }
            }

            // かかっている魔法効果の全部（対象NPC側）
            DumpEffects(a, label, "target:");
            // ★プレイヤー側の魔法効果の全部（術者側に残る「操る」効果＝操り先つき。これが召喚体扱いを張り直していました）
            if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                DumpEffects(pc, label, "player:");
            }

            // 掴んでいるクエストエイリアス全部
            if (auto* xa = a->extraList.GetByType<RE::ExtraAliasInstanceArray>()) {
                for (auto* d : xa->aliases) {
                    if (!d) continue;
                    spdlog::info("[Probe][{}] alias quest={} 0x{:X} alias='{}'", label, NameOf(d->quest),
                                 d->quest ? d->quest->GetFormID() : 0, d->alias ? d->alias->aliasName.c_str() : "?");
                }
            } else {
                spdlog::info("[Probe][{}] alias <none>", label);
            }

            // 今のAIパッケージ
            auto* pkg = a->GetCurrentPackage();
            spdlog::info("[Probe][{}] package={} 0x{:X}", label, NameOf(pkg), pkg ? pkg->GetFormID() : 0);

            // 上書きファクション全部
            if (auto* fc = a->extraList.GetByType<RE::ExtraFactionChanges>()) {
                std::string s;
                for (auto& fr : fc->factionChanges) {
                    s += fmt::format(" {}(0x{:X})r{}", NameOf(fr.faction), fr.faction ? fr.faction->GetFormID() : 0, static_cast<int>(fr.rank));
                }
                spdlog::info("[Probe][{}] factionChanges n={} :{}", label, fc->factionChanges.size(), s);
            } else {
                spdlog::info("[Probe][{}] factionChanges <none>", label);
            }
        }

        // ---- Papyrus native ----
        void Papyrus_ProbeDumpCpp(RE::StaticFunctionTag*, RE::Actor* akTarget, RE::BSFixedString label) {
            std::string lb = label.c_str() ? label.c_str() : "PROBE";
            if (!akTarget) {
                spdlog::info("[Probe][{}] <none>", lb);
                return;
            }
            RE::ActorHandle h = akTarget->CreateRefHandle();
            SKSE::GetTaskInterface()->AddTask([h, lb]() {
                if (auto a = h.get()) DumpNow(a.get(), lb);
            });
        }

        // ---- 見張り：手下枠の子の召喚体フラグ/ライフステートの変化を記録 ----
        struct WatchState { bool commanded; std::uint32_t life; };
        std::unordered_map<RE::FormID, WatchState> g_watch;   // ゲームスレッドのみです

        void Watch() {
            auto* dh = RE::TESDataHandler::GetSingleton();
            auto* q = dh ? dh->LookupForm<RE::TESQuest>(kFollowQuestID, kEsp) : nullptr;
            if (!q) return;
            for (auto* base : q->aliases) {
                auto* ra = skyrim_cast<RE::BGSRefAlias*>(base);
                if (!ra) continue;
                auto* a = ra->GetActorReference();
                if (!a) continue;
                const WatchState now{ a->IsCommandedActor(), static_cast<std::uint32_t>(a->AsActorState()->GetLifeState()) };
                auto it = g_watch.find(a->GetFormID());
                if (it == g_watch.end()) {
                    g_watch[a->GetFormID()] = now;
                    spdlog::info("[Probe][watch] start {} 0x{:X} commanded={} lifeState={}", NameOf(a), a->GetFormID(), now.commanded, now.life);
                    continue;
                }
                if (it->second.commanded != now.commanded || it->second.life != now.life) {
                    spdlog::info("[Probe][watch] CHANGE {} 0x{:X} commanded {}->{} lifeState {}->{}", NameOf(a), a->GetFormID(),
                                 it->second.commanded, now.commanded, it->second.life, now.life);
                    it->second = now;
                    DumpNow(a, "watch-change");   // 変わった瞬間の全状態も一緒に出します
                }
            }
        }
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("ProbeDumpCpp", "ASTR2Native", Papyrus_ProbeDumpCpp);
        spdlog::info("[Probe] Papyrus native ProbeDumpCpp 登録");
        return true;
    }

    void Install() {
        Chronos::RegisterRealtime("診断:ヴァッサル見張り", 0.5f, []() {
            SKSE::GetTaskInterface()->AddTask([]() { Watch(); });
        });
        spdlog::info("[Probe] watch registered (realtime 0.5s)");
    }
}
#endif   // NDEBUG（診断native本体ここまで）
