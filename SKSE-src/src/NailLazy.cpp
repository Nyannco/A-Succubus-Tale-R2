#include "PCH.h"
#include "NailLazy.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"

// ============================================================================
//  シンフル・ネイル・怠惰 Acedia（idx4）＝魔法を構えている間、移動速度を加算します（減速の打ち消しでなく素の+加算）。
//   ・Lv連動＝Lv100で最大 +50%（SpeedMult+50）／それ未満は比例します。★ネイル効果があると構えている方が通常より速くなります。
//   ・加算方式の理由＝移動速度modで通常速度は環境ごとに違います＆構えの減速%も一定ではないので「通常に合わせる」逆算は不安定です。素の加算なら環境不問で安定します。
//   ・Furyの移動速度+50もSpeedMult加算soそのまま合算で乗ります。
//   ・有効判定＝NailManagerが〔SkyVault〕へ公開する ASTR2_NailActive_4==1。
//   ・速度反映はFury実証法(SpeedMult fortify + CarryWeightナッジ)を流用します。
//   ・検知＝〔クロノス〕の実時間1秒tick（新規sink不要・Furyと同基盤）。RE操作はゲームスレッド=〔クロノス〕のtickで安全です。
//   ・調整＝最大加算量は 〔SkyVault〕 "ASTR2_NailLazyMaxOffset"（既定50＝Lv100で+50%）。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace NailLazy {
    namespace {
        inline int SVInt(const char* key, int def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
            return def;
        }

        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 状態（ゲームスレッドのみ）
        bool  g_applied      = false;
        float g_appliedSpeed = 0.0f;

        // Fury実証の移動速度即反映＝SpeedMult変更後にCarryWeightを+0.1→次フレーム-0.1（別イベント2回で派生値=移動速度を再計算誘発）。所持重量は差引ゼロです。
        void NudgeSpeed(RE::ActorValueOwner* a_avo) {
            if (!a_avo) return;
            a_avo->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kCarryWeight, 0.1f);
            SKSE::GetTaskInterface()->AddTask([]() {
                if (auto* pc = RE::PlayerCharacter::GetSingleton())
                    if (auto* avo = pc->AsActorValueOwner())
                        avo->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kCarryWeight, -0.1f);
            });
        }

        bool IsSpellForm(RE::TESForm* f) {
            return f && (f->Is(RE::FormType::Spell) || f->Is(RE::FormType::Scroll));
        }

        // 魔法を構えているか＝武器を抜いている＋左右どちらかに呪文/巻物。
        bool MagicReadied(RE::Actor* pc) {
            if (!pc) return false;
            auto* st = pc->AsActorState();
            if (!st || !st->IsWeaponDrawn()) return false;
            return IsSpellForm(pc->GetEquippedObject(true)) || IsSpellForm(pc->GetEquippedObject(false));
        }

        // 構え中の移動速度の加算量＝Lv連動（Lv100で最大＝既定+50%）。最大量は〔SkyVault〕で調整できます。
        float OffsetNow() {
            int lv = SuccubusLevel();
            if (lv > 100) lv = 100;
            const int maxOffset = SVInt("ASTR2_NailLazyMaxOffset", 50);
            return static_cast<float>(maxOffset) * (static_cast<float>(lv) / 100.0f);
        }

        void Apply(RE::ActorValueOwner* avo, float amt) {
            if (!avo || amt <= 0.0f) return;
            avo->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kSpeedMult, amt);
            g_appliedSpeed = amt;
            g_applied = true;
            NudgeSpeed(avo);
            spdlog::info("[NailLazy] speed +{:.1f} (magic readied, Lv-scaled)", amt);
        }

        void Remove(RE::ActorValueOwner* avo) {
            if (!avo || !g_applied) return;
            avo->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kSpeedMult, -g_appliedSpeed);
            spdlog::info("[NailLazy] speed -{:.1f} (removed)", g_appliedSpeed);
            g_appliedSpeed = 0.0f;
            g_applied = false;
            NudgeSpeed(avo);
        }

        // 〔クロノス〕 1秒tick＝有効(ASTR2_NailActive_4)かつ魔法構え中なら減速打消しをON、外れたらOFF。
        void Tick() {
            auto* pc = RE::PlayerCharacter::GetSingleton();
            if (!pc) return;
            auto* avo = pc->AsActorValueOwner();
            if (!avo) return;

            const bool want = (SVInt("ASTR2_NailActive_4", 0) == 1) && MagicReadied(pc);
            if (want && !g_applied) {
                Apply(avo, OffsetNow());
            } else if (!want && g_applied) {
                Remove(avo);
            }
            // want && g_applied＝維持（Lv変化の追従は次のON/OFFで反映＝簡潔優先）
        }
    }

    void Install() {
        g_applied = false;
        g_appliedSpeed = 0.0f;
        Chronos::RegisterRealtime("ASTR2NailLazy", 1.0f, Tick);
        spdlog::info("[NailLazy] installed (realtime 1s tick: cancel magic-readied slowdown, Lv-scaled)");
    }
}
