#include "PCH.h"
#include "EssenceFlow.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"
#include "TechRank.h"

#include <atomic>
#include <cmath>

// ============================================================================
//  エッセンス・フロウ（Essence Flow）の実体です。詳細は EssenceFlow.h。
//   ・トグル(Toggle)＝PowerResetのSpellCastが実発動の瞬間に呼びます（再使用で確実にON/OFF）。
//   ・〔クロノス〕実時間1秒tickで「最大HP×回復%」を回復します＝回復%ぶんLF消費し＋Restoration育成します。
//   ・起動時マジカ消費＋ソウルのマジカ再生を回復へ転用します(MagickaRateMultカット→終了で復元)。
//   ・OFF＝再使用／LF切れ／覚醒OFFのどれかで解除します（効果時間は無し＝純トグル）。
//  ★RE操作はゲームスレッドで＝Toggle は AddTask、Tick は 〔クロノス〕経由でゲームスレッドに乗ります。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace EssenceFlow {
    namespace {
        constexpr const char* kEsp           = "A Succubus Tale R2.esp";
        constexpr RE::FormID  kGlowESLocal   = 0x020880;   // ASTR2EssenceFlowES（水色シェーダー）

        // ---- 調整値（Fury式に統一・効果時間廃止＝"効果を纏う=常時消費"の純トグル）----
        constexpr float kRegenPctPerSec  = 1.0f;    // 毎秒 最大HP×この%（boost前）
        constexpr float kRefLevel        = 9.0f;    // 基準サキュバスLv（習得Lv・boostの基準）
        constexpr float kCastMagickaCost = 80.0f;   // 起動の一律マジカ（"甘露をまとう"）
        constexpr float kRestoXpFrac     = 0.10f;   // Restoration XP＝累計回復量×これ（Fury式＝OFF時にまとめて付与します）
        // ★LFコスト＝Fury式（最大LF×(11-Lv)×0.1%/秒・下限1）＝回復有無に関わらず毎秒消費します＝CostNow()。効果時間はありません（純トグル）。

        // ---- 〔SkyVault〕短縮 ----
        inline int   SVInt(const char* k, int d)   { if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, k, d);   return d; }
        inline void  SVSetInt(std::uint32_t h, const char* k, int val) { if (auto* sv = SkyVaultAPI::GetSkyVaultAPI()) sv->SetInt(h, k, val); }
        inline float SVFloat(const char* k, float d) { if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetFloat(0, k, d); return d; }

        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 維持コスト/秒＝Fury式＝最大LF×(11-Lv)×0.1%（Lv10=0.1%…Lv4=0.7%・下限1）。回復有無に関わらず毎秒消費します。
        // ★重複注意＝Fury.cpp CostNow と同式（別モジュールで意図的に同じです）。片方の式を変えたら必ず両方直します。
        int CostNow() {
            const int lv = SuccubusLevel();
            int lvFactor = 11 - lv;
            if (lvFactor < 1) lvFactor = 1;   // Lv>=11は0.1%/秒で下げ止まります
            const int maxLF = SVInt("ASTR2_LF_Max", 800);
            int cost = static_cast<int>(std::ceil(static_cast<float>(maxLF) * lvFactor * 0.001f));
            if (cost < 1) cost = 1;
            return cost;
        }

        // 回復boost＝Lv＋Restoration＋Hスキル(自慰cat4)。★Tick(実回復)とGetFlowHealNow(MCM表示)で定義は1か所です＝両方これを呼びます。
        float HealBoostNow() {
            auto* pc  = RE::PlayerCharacter::GetSingleton();
            auto* avo = pc ? pc->AsActorValueOwner() : nullptr;
            const float resto = avo ? avo->GetActorValue(RE::ActorValue::kRestoration) : 0.0f;
            return 1.0f
                + (SuccubusLevel() - kRefLevel) * 0.05f
                + resto / 200.0f
                + TechRank::GetDisplayCatRank(4) * 0.05f;
        }

        // ---- 状態（すべてゲームスレッドで触る）----
        std::atomic<bool> g_active{ false };
        float             g_rateCut     = 0.0f;   // 転用でMagickaRateMultからカットした量です（復元用）
        float             g_healedTotal = 0.0f;   // 累計回復量です（解除時に×10%をRestoration XPへ・Fury式）

        // 最大HP（fortify込み・CombatDrain同型）／現在HP。
        inline float CurHP(RE::Actor* a) { return a->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth); }
        inline float MaxHP(RE::Actor* a) {
            const float perm = a->AsActorValueOwner()->GetPermanentActorValue(RE::ActorValue::kHealth);
            const float temp = a->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kHealth);
            return perm + temp;
        }

        // 水色モヤ＝EFSHをプレイヤーへ再生／停止します（Fury StartGlow/StopGlow同型）。
        RE::TESEffectShader* GlowShader() {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) return dh->LookupForm<RE::TESEffectShader>(kGlowESLocal, kEsp);
            return nullptr;
        }
        void StartGlow(RE::Actor* a_pc) {
            if (!a_pc) return;
            auto* shader = GlowShader();
            if (!shader) { spdlog::warn("[EFlow] glow: EffectShader 0x{:06X} 見つからず", kGlowESLocal); return; }
            a_pc->InstantiateHitShader(shader, -1.0f);
            spdlog::info("[EFlow]   ✨水色もや開始 (ES 0x{:06X})", kGlowESLocal);
        }
        void StopGlow(RE::Actor* a_pc) {
            auto* shader = GlowShader();
            auto* pl = RE::ProcessLists::GetSingleton();
            if (!a_pc || !shader || !pl) return;
            pl->ForEachShaderEffect([&](RE::ShaderReferenceEffect* se) {
                if (se->effectData == shader && se->target.get().get() == a_pc) se->finished = true;
                return RE::BSContainer::ForEachResult::kContinue;
            });
            spdlog::info("[EFlow]   ✨水色もや停止");
        }

        // ★ゲームスレッドで呼んでください。
        void Deactivate() {
            if (!g_active.load()) return;
            auto* pc  = RE::PlayerCharacter::GetSingleton();
            auto* avo = pc ? pc->AsActorValueOwner() : nullptr;
            // 転用したマジカ再生を戻します
            if (avo && g_rateCut > 0.0f) {
                avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kMagickaRateMult, g_rateCut);
                spdlog::info("[EFlow]   マジカ再生を復元 (+{:.1f})", g_rateCut);
            }
            g_rateCut = 0.0f;
            StopGlow(pc);
            // Restoration XP＝累計回復量×10%（毎tickでなく解除時に1回＝Fury式）。
            if (g_healedTotal > 0.0f && pc) {
                const float xp = g_healedTotal * kRestoXpFrac;
                pc->AddSkillExperience(RE::ActorValue::kRestoration, xp);
                spdlog::info("[EFlow] OFF 累計回復={:.0f} -> RestorationXP+{:.1f}", g_healedTotal, xp);
            } else {
                spdlog::info("[EFlow] === OFF (累計回復={:.0f}) ===", g_healedTotal);
            }
            g_healedTotal = 0.0f;
            g_active.store(false);
        }

        // ★ゲームスレッドで呼んでください。
        void Activate() {
            if (g_active.load()) return;
            auto* pc = RE::PlayerCharacter::GetSingleton();
            if (!pc) return;
            auto* avo = pc->AsActorValueOwner();
            if (!avo) return;

            // 起動時マジカ〔門番〕＋消費します（"甘露をまとう"）。不足なら発動しません＝通知はありません（水色モヤの有無が合図）。
            if (avo->GetActorValue(RE::ActorValue::kMagicka) < kCastMagickaCost) {
                spdlog::info("[EFlow] マジカ不足で発動せず（need={:.0f}）", kCastMagickaCost);
                return;
            }
            avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kMagicka, -kCastMagickaCost);

            // マジカ再生の転用＝ソウルのMagRate(〔SkyVault〕・別モジュールがミラーします)をスナップしてカットします＝毎秒ループとは戦いません。
            g_rateCut = SVFloat("ASTR2_SoulMagRate", 0.0f);
            if (g_rateCut > 0.0f) {
                avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kMagickaRateMult, -g_rateCut);
            }

            g_healedTotal = 0.0f;
            StartGlow(pc);
            g_active.store(true);
            spdlog::info("[EFlow] === ON Lv={} 転用cut={:.1f} 維持LF/秒={} ===（効果時間なし＝切る/LF0/覚醒OFFまで）", SuccubusLevel(), g_rateCut, CostNow());
        }

        // 〔クロノス〕実時間1秒＝維持コスト消費(常時)＋回復(HP<満タン時のみ・追加コスト無し)＋終了条件（ゲームスレッド）。
        void Tick() {
            if (!g_active.load()) return;
            // 覚醒OFF＝人間化＝即解除します。
            if (SVInt("ASTR2_Awake", 1) == 0) { Deactivate(); return; }

            // 維持コスト＝Fury式・回復有無に関わらず毎秒消費します（"効果を纏う"コスト）。LF切れで即OFFします。
            const int cost  = CostNow();
            const int curLF = SVInt("ASTR2_LF_Curr", 0);
            if (curLF < cost) { Deactivate(); return; }   // LF切れ＝即OFFします（水色モヤが消えるのが合図）
            const int leftLF = curLF - cost;
            SVSetInt(0, "ASTR2_LF_Curr", leftLF);
            // LFバー/段階バフの描き直し合図です（Fury/減衰/維持費と同じ）。
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "astr2_lf_tick", "", static_cast<float>(leftLF), nullptr };
                src->SendEvent(&ev);
            }

            // 回復します（HP<満タンの時だけ・追加LFコスト無し＝上の維持費がコスト）。
            auto* pc  = RE::PlayerCharacter::GetSingleton();
            auto* avo = pc ? pc->AsActorValueOwner() : nullptr;
            float healHP = 0.0f, pctThisSec = 0.0f, boost = 0.0f;
            if (avo) {
                const float maxHP = MaxHP(pc);
                const float curHP = CurHP(pc);
                if (maxHP > 0.0f && curHP > 0.0f) {
                    const float hpPct = curHP / maxHP;
                    if (hpPct < 1.0f) {   // 満タンは回復しません（維持費だけ払います）
                        boost = HealBoostNow();   // ★回復boostの定義は1か所(GetFlowHealNowと共有)
                        pctThisSec = kRegenPctPerSec * boost;
                        const float missingPct = (1.0f - hpPct) * 100.0f;   // 回復しすぎない丸め
                        if (pctThisSec > missingPct) pctThisSec = missingPct;
                        if (pctThisSec > 0.0f) {
                            healHP = maxHP * (pctThisSec / 100.0f);
                            avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth, healHP);
                            g_healedTotal += healHP;   // 累計＝解除時に×10%をRestoration XPへ（Fury式）
                        }
                    }
                }
            }
            spdlog::info("[EFlow]   維持LF-{}  回復={:.0f}HP  (boost={:.2f} heal%={:.2f})  LF={}/{}",
                         cost, healHP, boost, pctThisSec, leftLF, SVInt("ASTR2_LF_Max", 0));
        }

        // ---- ステータスinfo表示用の現在値（ON/OFF問わず"今ONにしたら"の値）----
        // 回復量＝最大HPの実効%/秒（kRegenPctPerSec×boost・Consumeの GetRegenPctPerSec と同じ%返し）。
        //   ※実HPでなく%を返します（表示側が%で表示します）。boostは HealBoostNow＝Tick(実回復)と定義は1か所です。
        float GetFlowHealNow(RE::StaticFunctionTag*) {
            return kRegenPctPerSec * HealBoostNow();   // ％/秒（maxHPは掛けない）
        }
        // 維持LF/秒（Fury式・CostNowそのまま）。
        int GetFlowCostNow(RE::StaticFunctionTag*) {
            return CostNow();
        }
    }

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝匿名nsのgetter本体を呼びます（重複なし・NailDescから使用します）。
    float FlowHealNow() { return GetFlowHealNow(nullptr); }
    int   FlowCostNow() { return GetFlowCostNow(nullptr); }

    // ON/OFFトグル本体（ゲームスレッドへ載せて Activate/Deactivate）。PowerResetのSpellCastから呼び出す入口です。
    void Toggle() {
        SKSE::GetTaskInterface()->AddTask([]() {
            if (g_active.load()) Deactivate(); else Activate();
        });
    }

    void Install() {
        g_active.store(false);
        // 毎秒tick（実時間くり返し・非active時はno-op）。
        Chronos::RegisterRealtime("ASTR2EssenceFlow", 1.0f, Tick);
        spdlog::info("[EFlow] installed (realtime tick)");
    }

    // ステータスinfo表示用の現在値getter（ASTR2Native）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetFlowHealNow", "ASTR2Native", GetFlowHealNow);
        vm->RegisterFunction("GetFlowCostNow", "ASTR2Native", GetFlowCostNow);
        spdlog::info("[EFlow] Papyrus getter GetFlowHealNow/CostNow 登録");
        return true;
    }
}
