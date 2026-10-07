#include "PCH.h"
#include "Fury.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"

#include <atomic>
#include <cmath>
#include <cstdint>
#include <utility>
#include <vector>

// ============================================================================
//  アンリーシュド・フューリーの実体です。詳細は Fury.h。
//   ・トグル(Fury::Toggle・PowerResetのSpellCastフックが呼ぶ)＝ON/OFF切替／FuryForceOff＝覚醒OFF等の外部強制解除です。
//   ・〔クロノス〕実時間1秒tickで維持コスト(LF)を毎秒引きます＋覚醒/LF0で自動OFFします。
//   ・強化はAV fortify(kTemporary)＋ジャンプはゲーム設定＋ダメカ/落下は被ダメージvfuncフックです。
//   ・解除時に「累計消費LF×10%」を変性(Alteration)XPへまとめて付与します。
//  ★RE操作はゲームスレッドで＝native/Tick は AddTask/〔クロノス〕経由でゲームスレッドに乗せて Activate/Deactivate を呼びます。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace Fury {
    namespace {
        constexpr const char* kEsp = "A Succubus Tale R2.esp";
        constexpr int         kMagRegenPct   = 20;         // 🅲固定＝マジカ再生+20%（Lv不問・ON中常時／60秒MGEFからC++へ移管・定義は1か所です）

        // ---- 〔SkyVault〕短縮 ----
        inline int SVInt(const char* key, int def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
            return def;
        }
        inline void SVSetInt(std::uint32_t holder, const char* key, int val) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) v->SetInt(holder, key, val);
        }

        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 変性＝★基礎スキル(GetBaseActorValue)で読む＝Lv9のFury変性fortify(kTemporary)を含めない＝自己増幅/フィードバックを防ぎます。
        float FuryAlteration() {
            if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                if (auto* avo = pc->AsActorValueOwner()) return avo->GetBaseActorValue(RE::ActorValue::kAlteration);
            }
            return 0.0f;
        }

        // ★式はここ1か所に集約＝Activateもgetterもここを通します（MCM表示とC++適用がズレない）。現在値から算出＝OFF中でも「今ONなら幾つ」かのプレビューです。
        //   式B（☆スキル）＝基礎(ASTR2_FuryBase) × (1 + Lv×0.2 + tier3人数 + 変性/100)
        float SkillBonusNow() {
            const int lv    = SuccubusLevel();
            const int tier3 = SVInt("ASTR2_Tier3Count", 0);
            const int base  = SVInt("ASTR2_FuryBase", 10);
            return static_cast<float>(base) * (1.0f + lv * 0.2f + static_cast<float>(tier3) + FuryAlteration() / 100.0f);
        }
        //   式A（％項目・cap100）＝10 × (1 + Lv×0.1 + tier3人数×0.3 + 変性/100)
        float PctBonusNow() {
            const int lv    = SuccubusLevel();
            const int tier3 = SVInt("ASTR2_Tier3Count", 0);
            float x = 10.0f * (1.0f + lv * 0.1f + tier3 * 0.3f + FuryAlteration() / 100.0f);
            if (x > 100.0f) x = 100.0f;
            return x;
        }
        //   維持コスト/秒＝最大LF × (11-Lv)×0.1%（Lv10=0.1%…Lv4=0.7%・最低1）。Tickもgetterもここを通します＝Fury内で定義は1か所です。
        //   ★重複注意＝EssenceFlow.cpp CostNow と同式（別モジュールで意図的に同じ）。片方の式を変えたら必ず両方直します。
        int CostNow() {
            const int lv = SuccubusLevel();
            int lvFactor = 11 - lv;
            if (lvFactor < 1) lvFactor = 1;   // Lv>=11は0.1%/秒で下げ止め
            const int maxLF = SVInt("ASTR2_LF_Max", 800);
            int cost = static_cast<int>(std::ceil(static_cast<float>(maxLF) * lvFactor * 0.001f));
            if (cost < 1) cost = 1;
            return cost;
        }

        // ---- 状態（すべてゲームスレッドで触る。フックが読む2値だけ atomic）----
        std::atomic<bool>  g_active{ false };
        std::atomic<float> g_damageCutFrac{ 0.0f };   // ダメージカット割合 0..1（Lv10）
        std::atomic<float> g_fallResistFrac{ 0.0f };  // 落下(環境)ダメ軽減割合 0..1（Lv5）
        std::vector<std::pair<RE::ActorValue, float>> g_appliedAV;   // 適用したfortify（撤去用に正確に控えます）
        float              g_consumedLF = 0.0f;       // 累計消費LFです（解除時に×10%を変性XPへ）
        float              g_origJump   = 0.0f;       // fJumpHeightMin の元値です
        bool               g_jumpApplied = false;
        float              g_origCCJump = 0.0f;       // キャラコントローラの jumpHeight(0x23C) 元値です
        bool               g_ccJumpApplied = false;
        float              g_origFallMult = 0.0f;     // fJumpFallHeightMult の元値です（落下ダメ倍率・プレイヤー）
        bool               g_fallApplied  = false;

        // ログ用＝適用するAVの日本語名です（変更前後ログ用）。
        const char* AVName(RE::ActorValue av) {
            switch (av) {
                case RE::ActorValue::kDestruction: return "破壊";
                case RE::ActorValue::kRestoration: return "回復";
                case RE::ActorValue::kConjuration: return "召喚";
                case RE::ActorValue::kIllusion:    return "幻惑";
                case RE::ActorValue::kAlteration:  return "変性";
                case RE::ActorValue::kResistMagic: return "魔法耐性";
                case RE::ActorValue::kSpeedMult:   return "移動速度";
                case RE::ActorValue::kMagickaRateMult: return "マジカ再生";
                default:                           return "AV";
            }
        }

        // ★移動速度の即反映＝SpeedMultを変えてもエンジンは移動速度を再計算しません（既知＝Bug Fixes SSE等が対処）。
        //   CarryWeightを微増→"次フレームで"微減します＝別々のAV変更イベントを2回起こして派生値(移動速度)の再計算を誘発します。
        //   ★旧実装は同フレームで±して相殺→変更イベントが立たず効きませんでした。所持重量は差引ゼロで不変です。
        void NudgeSpeed(RE::ActorValueOwner* a_avo) {
            if (!a_avo) return;
            a_avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kCarryWeight, 0.1f);
            SKSE::GetTaskInterface()->AddTask([]() {
                if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                    if (auto* avo = pc->AsActorValueOwner())
                        avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kCarryWeight, -0.1f);
                }
            });
        }

        // ジャンプ強化＝GMST fJumpHeightMin（新規コントローラ用）と、現行キャラコントローラの jumpHeight(0x23C・キャッシュ値)の
        //   両方を掛け率で変えます／戻します。★GMSTだけでは既存コントローラがキャッシュ済 jumpHeight を使い続けて効かない
        //   （実機で確認・落下ダメGMSTは着地時読みで効くのと対照的）のでコントローラ側も直接書きます。
        //   セル移動で再生成されてもGMSTが効くので両掛けします。★変更前→後をログします。
        void SetJump(float a_mult, bool a_restore) {
            auto* pc = RE::PlayerCharacter::GetSingleton();
            auto* cc = pc ? pc->GetCharController() : nullptr;
            auto* gs = RE::GameSettingCollection::GetSingleton();
            auto* s  = gs ? gs->GetSetting("fJumpHeightMin") : nullptr;
            if (a_restore) {
                if (s) { spdlog::info("[Fury]   ジャンプ復元 GMST {:.1f} -> {:.1f}", s->data.f, g_origJump); s->data.f = g_origJump; }
                if (cc && g_ccJumpApplied) { spdlog::info("[Fury]   ジャンプ復元 CC {:.1f} -> {:.1f}", cc->jumpHeight, g_origCCJump); cc->jumpHeight = g_origCCJump; g_ccJumpApplied = false; }
            } else {
                if (s) { g_origJump = s->data.f; s->data.f = g_origJump * a_mult; spdlog::info("[Fury]   ジャンプ x{:.2f} GMST {:.1f} -> {:.1f}", a_mult, g_origJump, s->data.f); }
                if (cc) { g_origCCJump = cc->jumpHeight; cc->jumpHeight = g_origCCJump * a_mult; g_ccJumpApplied = true; spdlog::info("[Fury]   ジャンプ x{:.2f} CC {:.1f} -> {:.1f}", a_mult, g_origCCJump, cc->jumpHeight); }
                g_jumpApplied = true;
            }
        }

        // 落下ダメージ軽減＝fJumpFallHeightMult(プレイヤーの落下ダメ倍率)を落下耐性%ぶん下げます／戻します。
        //   ★落下ダメは HandleHealthDamage(vfunc104) を通らない＝被ダメフックでは消せません（実機で確認）ので
        //     ジャンプと同じGMST方式で源から消します。耐性100%→mult0＝落下ダメ0。NPCは別GMST(...MultNPC)なので無傷です。
        void SetFallDamage(float a_reduceFrac, bool a_restore) {
            auto* gs = RE::GameSettingCollection::GetSingleton();
            if (!gs) return;
            auto* s = gs->GetSetting("fJumpFallHeightMult");
            if (!s) return;
            if (a_restore) {
                spdlog::info("[Fury]   落下ダメ復元 fJumpFallHeightMult {:.3f} -> {:.3f}", s->data.f, g_origFallMult);
                s->data.f = g_origFallMult;
            } else {
                g_origFallMult = s->data.f;
                s->data.f = g_origFallMult * (1.0f - a_reduceFrac);
                g_fallApplied = true;
                spdlog::info("[Fury]   落下ダメ軽減{:.0f}% fJumpFallHeightMult {:.3f} -> {:.3f}", a_reduceFrac * 100.0f, g_origFallMult, s->data.f);
            }
        }

        // ✨ アンリーシュド・フューリー中の演出＝ピンクもやシェーダー「ASTR2Unleashed FuryES」(EffectShader 0x01F856) を
        //   プレイヤーに直接再生します。ON中ずっと(-1=永続・シェーダーは連続パーティクルでもやを出し続けます)・
        //   OFFでProcessListsを走査してfinishします（ダングリングポインタ回避）。
        //   ※VE 01F857 は現状このシェーダーを参照していない(EffectArt 075271のみ)のでVE経由でなくシェーダーを直接再生します。
        constexpr RE::FormID kFuryGlowESLocal = 0x01F856;
        RE::TESEffectShader* FuryGlowShader() {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                return dh->LookupForm<RE::TESEffectShader>(kFuryGlowESLocal, kEsp);
            }
            return nullptr;
        }
        void StartGlow(RE::Actor* a_pc) {
            if (!a_pc) return;
            auto* shader = FuryGlowShader();
            if (!shader) { spdlog::warn("[Fury] glow: EffectShader 0x{:06X} 見つからず", kFuryGlowESLocal); return; }
            a_pc->InstantiateHitShader(shader, -1.0f);
            spdlog::info("[Fury]   ✨ピンクもや開始 (ES 0x{:06X})", kFuryGlowESLocal);
        }
        void StopGlow(RE::Actor* a_pc) {
            auto* shader = FuryGlowShader();
            auto* pl = RE::ProcessLists::GetSingleton();
            if (!a_pc || !shader || !pl) return;
            pl->ForEachShaderEffect([&](RE::ShaderReferenceEffect* se) {
                if (se->effectData == shader && se->target.get().get() == a_pc) se->finished = true;
                return RE::BSContainer::ForEachResult::kContinue;
            });
            spdlog::info("[Fury]   ✨ピンクもや停止");
        }

        // ★ゲームスレッドで呼んでください。
        void Activate() {
            if (g_active.load()) return;
            auto* pc = RE::PlayerCharacter::GetSingleton();
            if (!pc) return;
            auto* avo = pc->AsActorValueOwner();
            if (!avo) return;

            const int   lv       = SuccubusLevel();
            const float skillVal = SkillBonusNow();   // 式B（☆スキル）＝getterと同じ式
            const float pctVal   = PctBonusNow();     // 式A（％・cap100）＝getterと同じ式

            spdlog::info("[Fury] === ON 適用開始 Lv={} skill+{:.0f} pct={:.0f}% ===", lv, skillVal, pctVal);
            g_appliedAV.clear();
            // ★各AVを「変更前→後(+増分)」でログ＝実機で乗ったか一目で確認できます。
            auto applyAV = [&](RE::ActorValue av, float amt) {
                if (amt == 0.0f) return;
                const float before = avo->GetActorValue(av);
                avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, av, amt);
                const float after = avo->GetActorValue(av);
                g_appliedAV.emplace_back(av, amt);
                spdlog::info("[Fury]   +{} {:.1f} -> {:.1f} (+{:.1f})", AVName(av), before, after, amt);
            };

            // ☆スキル+（式B）
            if (lv >= 4) applyAV(RE::ActorValue::kDestruction, skillVal);
            if (lv >= 6) applyAV(RE::ActorValue::kRestoration, skillVal);
            if (lv >= 7) applyAV(RE::ActorValue::kConjuration, skillVal);
            if (lv >= 8) applyAV(RE::ActorValue::kIllusion,    skillVal);
            if (lv >= 9) applyAV(RE::ActorValue::kAlteration,  skillVal);
            // 魔法耐性%（式A）
            if (lv >= 6) applyAV(RE::ActorValue::kResistMagic, pctVal);
            // 🅲固定：マジカ再生+N%（Lv制限なし＝Fury習得Lv4から常時／60秒MGEFからC++へ移管＝ON/OFFに一致）
            applyAV(RE::ActorValue::kMagickaRateMult, static_cast<float>(kMagRegenPct));
            // 移動速度＋50（＝×1.5）＝適用後にCarryWeightナッジで即反映します
            if (lv >= 5) {
                applyAV(RE::ActorValue::kSpeedMult, 50.0f);
                NudgeSpeed(avo);
            }
            // ジャンプ×2.0（GMST＋コントローラ両掛け）
            if (lv >= 5) SetJump(2.0f, false);
            // 落下耐性%（Lv5・式A）／ダメージカット%（Lv10・式A）＝被ダメージフックへ割合を渡します
            g_fallResistFrac.store(lv >= 5  ? pctVal / 100.0f : 0.0f);
            g_damageCutFrac.store(lv >= 10 ? pctVal / 100.0f : 0.0f);
            spdlog::info("[Fury]   落下耐性={:.0f}% ダメカ={:.0f}%", g_fallResistFrac.load() * 100.0f, g_damageCutFrac.load() * 100.0f);
            if (lv >= 5) SetFallDamage(g_fallResistFrac.load(), false);   // 落下ダメはフック外＝GMSTで源から軽減します
            StartGlow(pc);   // ✨ ON中ずっとピンク霧です

            g_consumedLF = 0.0f;
            g_active.store(true);
            spdlog::info("[Fury] ON Lv={} tier3={} skill+{:.0f} pct={:.0f}% (cut={} fall={})",
                         lv, SVInt("ASTR2_Tier3Count", 0), skillVal, pctVal, lv >= 10, lv >= 5);
        }

        // ★ゲームスレッドで呼んでください。a_grantXp=false は保険用です（通常は付与）。
        void Deactivate() {
            if (!g_active.load()) return;
            auto* pc  = RE::PlayerCharacter::GetSingleton();
            auto* avo = pc ? pc->AsActorValueOwner() : nullptr;
            if (avo) {
                spdlog::info("[Fury] === OFF 撤去開始 ===");
                for (auto& [av, amt] : g_appliedAV) {
                    const float before = avo->GetActorValue(av);
                    avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, av, -amt);   // 適用と逆符号で正確に撤去します
                    const float after = avo->GetActorValue(av);
                    spdlog::info("[Fury]   -{} {:.1f} -> {:.1f} (-{:.1f})", AVName(av), before, after, amt);
                }
                NudgeSpeed(avo);   // 撤去後も移動速度を即反映します
            }
            g_appliedAV.clear();
            if (g_jumpApplied) { SetJump(1.0f, true); g_jumpApplied = false; }
            if (g_fallApplied) { SetFallDamage(0.0f, true); g_fallApplied = false; }
            StopGlow(pc);   // ✨ ピンク霧を止める
            g_fallResistFrac.store(0.0f);
            g_damageCutFrac.store(0.0f);

            // 変性XP＝累計消費LF×10%（毎秒でなく解除時に1回）
            if (g_consumedLF > 0.0f && pc) {
                const float xp = g_consumedLF * 0.10f;
                pc->AddSkillExperience(RE::ActorValue::kAlteration, xp);
                spdlog::info("[Fury] OFF consumedLF={:.0f} -> AlterationXP+{:.1f}", g_consumedLF, xp);
            } else {
                spdlog::info("[Fury] OFF (consumedLF={:.0f})", g_consumedLF);
            }
            g_consumedLF = 0.0f;
            g_active.store(false);
        }

        // 〔クロノス〕実時間1秒＝維持コストを引く＋覚醒/LF0で自動OFF（ゲームスレッド）。
        void Tick() {
            if (!g_active.load()) return;
            // 覚醒OFF＝人間化＝即解除します（保険。本命はUnSuccubyのFuryForceOff）。
            if (SVInt("ASTR2_Awake", 1) == 0) { Deactivate(); return; }

            const int curLF = SVInt("ASTR2_LF_Curr", 0);
            const int cost  = CostNow();   // 維持コスト/秒＝getterと同じ式
            if (curLF < cost) { Deactivate(); return; }   // 払えない＝自動OFFします

            const int left = curLF - cost;
            SVSetInt(0, "ASTR2_LF_Curr", left);
            g_consumedLF += static_cast<float>(cost);
            // LFバー/段階バフの描き直し合図です（LF減衰/維持費と同じ）
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "astr2_lf_tick", "", static_cast<float>(left), nullptr };
                src->SendEvent(&ev);
            }
        }

        // ===== ダメカ＝ダメージ適用関数を直接フックし、被ダメを"HP減算される前"に削る =====
        //   ★HandleHealthDamageは減算の"後"の通知です（実機ログで HP前=最大−被ダメ を実証）ので引数削りは無力です。
        //     実在の被ダメ改変mod(Dynamic Damage Scaling)と同じく、HitDataを扱うダメージ関数群をREL::IDでフックし、
        //     当たった瞬間の totalDamage を ×(1-cut) する＝HPが減る前に削れます。標的がプレイヤーの時だけです。
        //   ★トランポリンは plugin.cpp で一括確保（個別AllocTrampoline禁止＝後勝ちで他フックを壊します）。落下は既存GMSTで対応済みです。
        inline float FuryCutFactor() {   // 被ダメに掛ける係数です（0=無傷）。Lv<10やOFFは1.0です（素通り）。
            if (!g_active.load()) return 1.0f;
            float cut = g_damageCutFrac.load();
            if (cut <= 0.0f) return 1.0f;
            if (cut > 1.0f) cut = 1.0f;
            return 1.0f - cut;
        }
        // 物理系＝HitData（近接/矢/爆発/衝突/abstract 共通）。標的==プレイヤーのみ totalDamage を削ります。
        void ScaleHitData(RE::HitData* a_hitData) {
            if (!a_hitData) return;
            const float factor = FuryCutFactor();
            if (factor >= 1.0f) return;   // OFF/Lv<10
            if (a_hitData->target.get().get() != RE::PlayerCharacter::GetSingleton()) return;
            const float before = a_hitData->totalDamage;
            if (before <= 0.0f) return;
            a_hitData->totalDamage = before * factor;
            spdlog::info("[Fury]   ダメカ(物理) {:.0f} -> {:.0f}", before, a_hitData->totalDamage);
        }
        // ダメージ関数群のアドレス＝Dynamic Damage Scaling(出荷済mod)由来の既知値です。RELOCATION_ID(SE,AE)+VariantOffset(SE,AE,VR)。
        struct HitMelee     { static void thunk(RE::HitData* h){ ScaleHitData(h); func(h); } static inline REL::Relocation<decltype(thunk)> func; };
        struct HitArrow     { static void thunk(RE::HitData* h){ ScaleHitData(h); func(h); } static inline REL::Relocation<decltype(thunk)> func; };
        struct HitAbstract  { static void thunk(RE::HitData* h){ ScaleHitData(h); func(h); } static inline REL::Relocation<decltype(thunk)> func; };
        struct HitExplosion { static void thunk(RE::HitData* h){ ScaleHitData(h); func(h); } static inline REL::Relocation<decltype(thunk)> func; };
        struct HitCollision { static void thunk(RE::HitData* h){ ScaleHitData(h); func(h); } static inline REL::Relocation<decltype(thunk)> func; };
        // 🔥憤怒(Ira・ネイルidx0)＝プレイヤーが撃つ魔法ダメを低HP時にUPします（追い詰められ激昂）。標的==敵・術者==プレイヤーのみです。
        //   低HP閾値=〔SkyVault〕ASTR2_NailWrathHpPct(既定30%)／威力=×(1+Lv×0.01)＝Lv100で2倍。MagicHitフックに相乗りします。
        void WrathBoostMagic(RE::ActiveEffect* a_ae) {
            if (SVInt("ASTR2_NailActive_0", 0) != 1) return;                 // 憤怒OFFです
            if (!a_ae || a_ae->magnitude <= 0.0f) return;                    // ダメージ効果のみです
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (!player) return;
            auto* tgt = (a_ae->target && a_ae->target->MagicTargetIsActor()) ? skyrim_cast<RE::Actor*>(a_ae->target) : nullptr;
            if (!tgt || tgt == player) return;                              // 標的＝敵のみです（自分被弾は除外＝Furyダメカ側の担当）
            if (a_ae->caster.get().get() != player) return;                 // 術者＝プレイヤーのみです
            auto* avo = player->AsActorValueOwner();
            const float maxHP = avo->GetPermanentActorValue(RE::ActorValue::kHealth)
                              + player->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kHealth);
            if (maxHP <= 0.0f) return;
            const float hpPct = avo->GetActorValue(RE::ActorValue::kHealth) / maxHP * 100.0f;
            const float wrathThr = 10.0f + static_cast<float>(SuccubusLevel()) * 0.3f;   // 低HP閾値＝Lv変動します(Lv1≈10.3%→Lv100=40%)
            if (hpPct >= wrathThr) return;   // 閾値以上＝低HPでない＝素通りします
            const float mult   = 1.0f + SuccubusLevel() * 0.01f;            // 威力Lv連動します（Lv100で2倍）
            const float before = a_ae->magnitude;
            a_ae->magnitude = before * mult;
            spdlog::info("[Fury]   🔥憤怒 魔法ダメUP mag {:.1f}->{:.1f} (hp{:.0f}% x{:.2f})", before, a_ae->magnitude, hpPct, mult);
        }

        // 魔法ダメージ＝ActiveEffectのmagnitudeを削ります（ダメカに内包＝物理と同じFuryCutFactor・標的==プレイヤーのみ）。
        //   ★魔法耐性AVは上限85%なので15%漏れる→ここで実カットして埋めます。write_call＝(void*,ActiveEffect*,void*,void*,void*)。
        struct MagicHit {
            static void thunk(void* a1, RE::ActiveEffect* a_ae, void* a3, void* a4, void* a5) {
                const float factor = FuryCutFactor();
                if (factor < 1.0f && a_ae && a_ae->magnitude != 0.0f &&
                    a_ae->target && a_ae->target->MagicTargetIsActor() &&
                    skyrim_cast<RE::Actor*>(a_ae->target) == RE::PlayerCharacter::GetSingleton()) {
                    const float before = a_ae->magnitude;
                    a_ae->magnitude = before * factor;
                    spdlog::info("[Fury]   ダメカ(魔法) mag {:.1f} -> {:.1f}", before, a_ae->magnitude);
                }
                WrathBoostMagic(a_ae);   // 🔥憤怒(ネイルidx0)＝プレイヤーの魔法与ダメを低HP時UP（標的敵・術者プレイヤー）
                func(a1, a_ae, a3, a4, a5);
            }
            static inline REL::Relocation<decltype(thunk)> func;
        };

        // ===== Papyrus native =====
        void FuryForceOff(RE::StaticFunctionTag*) {
            SKSE::GetTaskInterface()->AddTask([]() {
                if (g_active.load()) Deactivate();
            });
        }

        // MCM表示用getter＝現在の強化量です（トグルOFF中でも「今ONなら幾つ」かのプレビュー）。Activateと同じ式(SkillBonusNow/PctBonusNow)。
        std::int32_t GetFuryBoostNow(RE::StaticFunctionTag*)  { return static_cast<std::int32_t>(SkillBonusNow()); }   // 式B＝破壊/回復/召喚/幻惑/変性 各+N（5スキル共通）
        std::int32_t GetFuryResistNow(RE::StaticFunctionTag*) { return static_cast<std::int32_t>(PctBonusNow()); }     // 式A＝魔法耐性/落下耐性/ダメカ の%（cap100）
        std::int32_t GetFuryCostNow(RE::StaticFunctionTag*)   { return CostNow(); }                                   // 維持コスト＝淫魔力/秒（最大LF×(11-Lv)×0.1%）
    }

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝MCM getterと同じ実体を返します（重複なし・NailDescから使用）。
    std::int32_t FuryBoostNow()  { return GetFuryBoostNow(nullptr); }
    std::int32_t FuryResistNow() { return GetFuryResistNow(nullptr); }
    std::int32_t FuryCostNow()   { return GetFuryCostNow(nullptr); }

    // ON/OFFトグル本体（ゲームスレッドへ載せて Activate/Deactivate を呼びます）。native/SpellCastフック共通の入口です。
    void Toggle() {
        SKSE::GetTaskInterface()->AddTask([]() {
            if (g_active.load()) Deactivate(); else Activate();
        });
    }

    void Install() {
        g_active.store(false);
        // 毎秒の維持コストtick（実時間くり返し・非active時はno-op）。
        Chronos::RegisterRealtime("ASTR2Fury", 1.0f, Tick);
        // ダメカ＝ダメージ適用関数群を write_branch でフックします（HP減算の前に totalDamage を削ります）。
        auto& tr = SKSE::GetTrampoline();
        HitMelee::func     = tr.write_branch<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(42832, 44001), REL::VariantOffset(0x396, 0x37A, 0x3E9) }.address(), HitMelee::thunk);
        HitArrow::func     = tr.write_branch<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(42833, 44002), REL::VariantOffset(0x163, 0x163, 0x163) }.address(), HitArrow::thunk);
        HitAbstract::func  = tr.write_branch<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(42834, 44003), REL::VariantOffset(0x8D, 0x8D, 0x8D) }.address(), HitAbstract::thunk);
        HitExplosion::func = tr.write_branch<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(42835, 44004), REL::VariantOffset(0xD5, 0xDD, 0xD5) }.address(), HitExplosion::thunk);
        HitCollision::func = tr.write_branch<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(42836, 44005), REL::VariantOffset(0x17E, 0x178, 0x17E) }.address(), HitCollision::thunk);
        // 魔法ダメージ＝write_call で magnitude を削ります（15%漏れを埋めます）。
        MagicHit::func     = tr.write_call<5>(REL::Relocation<std::uintptr_t>{ RELOCATION_ID(33763, 34547), REL::VariantOffset(0x52F, 0x7B1, 0x4B1) }.address(), MagicHit::thunk);
        spdlog::info("[Fury] installed (realtime tick + HitData damage hooks x5 + magic damage hook)");
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("FuryForceOff", "ASTR2Native", FuryForceOff);
        vm->RegisterFunction("GetFuryBoostNow", "ASTR2Native", GetFuryBoostNow);
        vm->RegisterFunction("GetFuryResistNow", "ASTR2Native", GetFuryResistNow);
        vm->RegisterFunction("GetFuryCostNow", "ASTR2Native", GetFuryCostNow);
        spdlog::info("[Fury] Papyrus native FuryForceOff / GetFuryBoostNow / GetFuryResistNow / GetFuryCostNow 登録");
        return true;
    }
}
