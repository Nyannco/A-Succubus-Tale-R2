#include "HDrain.h"
#include "SkyVaultAPI.h"
#include "ServantTier.h"
#include "Technique.h"
#include "DrainMark.h"
#include "DrainFloorDefaults.h"   // ドレインfloor既定の単一の正（HpBarHudと共用）
#include "external/OstimNG-API-Thread.h"
#include <cmath>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace HDrain {
    using namespace OstimNG_API::Thread;

    namespace {
        // ---- 係数の既定値（★実値は〔SkyVault〕から毎回読む＝Papyrus原本(ASTDrainScript/ASTLvlManagerの裏打ちプロパティ)と定義は1か所）----
        //   重複の解消：以前はここに定数を直書きし、原本を調整すると黙ってズレる危険がありました。キー未設定時だけこの既定値を使います。
        constexpr float kHSexBoostLvRateDef  = 0.05f;   // ASTR2_HSexBoostLvRate  ＝HSexBoost の Lv係数です
        constexpr float kTechDrainRateDef    = 0.05f;   // ASTR2_TechDrainRate    ＝Hスキル rank係数です
        constexpr float kServantLFPerTierDef = 0.25f;   // ASTR2_ServantLFPerTier ＝tierごとLF倍率加算です
        using DrainFloor::kFloorPctHDef;   // ASTR2_FloorPctH 既定＝DrainFloorDefaults.h の単一の正を共用します
        using DrainFloor::kFloorAbsDef;    // ASTR2_FloorAbs 既定
        constexpr int   kBaseDamageDef       = 5;       // ASTR2_BaseDamage       ＝calcDamage = base + inc*(Lv-1)
        constexpr int   kDamageIncDef        = 5;       // ASTR2_DamageInc

        IThreadInterface* g_api = nullptr;

        // ---- 〔SkyVault〕短縮 ----
        inline float SVFloat(const char* key, float def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetFloat(0, key, def);
            return def;
        }
        inline int SVInt(const char* key, int def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
            return def;
        }
        inline void SVSetInt(std::uint32_t holder, const char* key, int val) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) v->SetInt(holder, key, val);
        }
        inline void SVSetFloat(std::uint32_t holder, const char* key, float val) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) v->SetFloat(holder, key, val);
        }

        // ---- Hスキル：秒→ランク（ASTR2Technique.SecondsToRank と同一しきい値）----
        int SecondsToRank(float sec) {
            if (sec >= 3450.0f) return 10;
            if (sec >= 2610.0f) return 9;
            if (sec >= 1890.0f) return 8;
            if (sec >= 1290.0f) return 7;
            if (sec >= 810.0f)  return 6;
            if (sec >= 450.0f)  return 5;
            if (sec >= 210.0f)  return 4;
            if (sec >= 90.0f)   return 3;
            if (sec >= 30.0f)   return 2;
            return 1;
        }
        // 種目別rankです（イカせ行為のcat）。cat<0(不明)は総合＝8catランク平均(四捨五入)にフォールバックします。
        int TechRankNow() {
            int cat = Technique::GetCurActionCat();   // 0-5 / -1
            if (cat >= 0) return SecondsToRank(Technique::LiveCatSeconds(cat));
            int sum = 0;
            for (int i = 0; i < 8; ++i) sum += SecondsToRank(Technique::LiveCatSeconds(i));
            return (sum + 4) / 8;
        }

        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 〔門番〕② プレイヤーが npc と同じOStimスレッドに居るかを判定します
        bool PlayerInSceneWith(RE::Actor* npc) {
            if (!g_api) return false;
            uint32_t tid = g_api->GetPlayerThreadID();
            if (tid == static_cast<uint32_t>(-1)) return false;
            ActorData buf[8]{};
            uint32_t n = g_api->GetActors(tid, buf, 8);
            RE::FormID npcID = npc->GetFormID();
            for (uint32_t i = 0; i < n; ++i) {
                if (buf[i].formID == npcID) return true;
            }
            return false;
        }

        // ---- HP/AV ヘルパ ----
        inline float CurHP(RE::Actor* a) {
            return a->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth);
        }
        // 最大HP＝permanent(base+fortifyエンチャ込み)です。GetActorValueModifierはこのCommonLibで
        //   ActorValueOwner非公開なのでこれで代用します（一時fortify薬ぶんの誤差は許容）。
        inline float MaxHP(RE::Actor* a) {
            return a->AsActorValueOwner()->GetPermanentActorValue(RE::ActorValue::kHealth);
        }
        inline void DamageHP(RE::Actor* a, float amt) {
            a->AsActorValueOwner()->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth, -amt);
        }
        inline void HealHP(RE::Actor* a, float amt) {
            a->AsActorValueOwner()->RestoreActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth, amt);
        }

        // 💋 H中ドレインの素の威力式＝計算の定義は1か所です。実核DoDrainも表示getter HDrainOrgasmBaseNow も共用します。
        inline float HDrainCalcDamage(int lv) {
            return static_cast<float>(SVInt("ASTR2_BaseDamage", kBaseDamageDef) + SVInt("ASTR2_DamageInc", kDamageIncDef) * (lv - 1));
        }
        inline float HDrainTotalMult(int lv) {
            const float hSexBoost = SVFloat("ASTR2_HSexBoostBase", 2.0f)
                                    * (1.0f + static_cast<float>(lv - 1) * SVFloat("ASTR2_HSexBoostLvRate", kHSexBoostLvRateDef));
            return 1.0f + (hSexBoost - 1.0f) + static_cast<float>(TechRankNow()) * SVFloat("ASTR2_TechDrainRate", kTechDrainRateDef);
        }

        // ============================================================
        //  ドレイン核（ゲームスレッドで実行＝AddTask内から呼び出す）
        // ============================================================
        void DoDrain(RE::FormID npcID) {
            auto* npc = RE::TESForm::LookupByID<RE::Actor>(npcID);
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (!npc || !player || npc == player || npc->IsDead()) return;

            // 〔門番〕（判定ログは分岐と同時に入れておく方針です）。まずプレイヤー参加判定でNPC同士Hを黙って除外します（ここはログ不要＝毎シーン鳴ってスパムになります）。
            if (!PlayerInSceneWith(npc)) return;
            // 以降はプレイヤー参加＝本来吸う相手なので、スキップした時は必ず理由をログに残します。
            if (SVInt("ASTR2_IsDrainOn", 1) == 0) {
                spdlog::info("[HDrain] skip {}: drain OFF (IsDrainOn=0)", npc->GetDisplayFullName());
                return;
            }
            if (DrainMark::IsMarked(npc)) {   // 💋1回制限＝痕があれば吸いません（OFFなら常にfalse＝従来同）
                spdlog::info("[HDrain] skip {}: 1回制限(marked)", npc->GetDisplayFullName());
                return;
            }

            const int   sucLv = SuccubusLevel();
            const float curHP = CurHP(npc);
            if (curHP <= 0.0f) {
                spdlog::info("[HDrain] skip {}: curHP<=0", npc->GetDisplayFullName());
                return;
            }
            const float maxHP = MaxHP(npc);

            // ---- 威力 amount = Max(calcDamage, maxHP*Lv*0.005) * totalMult（H中は耐性無視）----
            const float calcDamage = HDrainCalcDamage(sucLv);   // 素の威力＝定義は1か所です(HDrainCalcDamage・表示getterと共用)
            const float pctBase = maxHP * sucLv * 0.005f;
            float amount = (pctBase > calcDamage) ? pctBase : calcDamage;

            const int   techRank = TechRankNow();               // ★ログ用です（totalMultの式は HDrainTotalMult に集約＝重複を解消）
            const float totalMult = HDrainTotalMult(sucLv);
            amount *= totalMult;

            // ---- HP減（H中は殺さない＝下限で止める）----
            float floorHP = maxHP * SVFloat("ASTR2_FloorPctH", kFloorPctHDef);
            const float floorAbs = SVFloat("ASTR2_FloorAbs", kFloorAbsDef);
            if (floorHP < floorAbs) floorHP = floorAbs;
            float drainable = curHP - floorHP;
            float hpDrain = 0.0f;
            bool  floored = false;
            if (drainable > 0.0f) {
                if (amount < drainable) { hpDrain = amount; }
                else { hpDrain = drainable; floored = true; }
            }
            if (hpDrain > 0.0f) DamageHP(npc, hpDrain);

            // ---- 実吸収→caster(プレイヤー)回復優先→あふれLF ----
            float absorbed = hpDrain;
            if (absorbed > curHP) absorbed = curHP;
            if (absorbed < 0.0f) absorbed = 0.0f;
            float casterHeal = 0.0f;
            if (absorbed > 0.0f) {
                float pcMax = MaxHP(player), pcCur = CurHP(player);
                float missing = pcMax - pcCur;
                casterHeal = (absorbed < missing) ? absorbed : missing;
                if (casterHeal < 0.0f) casterHeal = 0.0f;
                if (casterHeal > 0.0f) HealHP(player, casterHeal);
            }
            float lfGain = absorbed - casterHeal;

            // ---- オーガズムボーナス淫魔力（LF）＋tier倍率 ----
            //   ボーナス式＝吸ったHP × Rate × Lv（不変です）。capはMCMトグルでON/OFF（既定ON）
            //   ＝HP2000万級の相手はボーナスが青天井になるので、要る時だけ頭打ちを効かせます。
            const float orgRate = SVFloat("ASTR2_OrgLFRate", 0.5f);
            const float orgCap  = SVFloat("ASTR2_OrgLFCap", 2000.0f);
            const bool  capOn   = (SVInt("ASTR2_OrgLFCapOn", 1) != 0);
            float bonusLF = absorbed * orgRate * sucLv;
            if (capOn && bonusLF > orgCap) bonusLF = orgCap;
            lfGain += bonusLF;
            const int tier = ServantTier::Get(npc);
            lfGain *= (1.0f + tier * SVFloat("ASTR2_ServantLFPerTier", kServantLFPerTierDef));
            // 🖤強欲(Avaritia・ネイルidx6)＝淫魔力（LF）吸収+Lv%（active時のみ・Lv100で+100%）＝CombatDrainと同じです。
            if (SVInt("ASTR2_NailActive_6", 0) == 1) {
                lfGain *= 1.0f + static_cast<float>(sucLv) * 0.01f;
            }
            if (lfGain < 0.0f) lfGain = 0.0f;

            // ---- LFプールへ加算（カンストあふれは破棄）----
            int curLF = SVInt("ASTR2_LF_Curr", 400);
            int maxLF = SVInt("ASTR2_LF_Max", 800);
            int space = maxLF - curLF; if (space < 0) space = 0;
            int added = static_cast<int>(std::ceil(lfGain));
            if (added < 0) added = 0;
            if (added > space) added = space;
            if (added > 0) SVSetInt(0, "ASTR2_LF_Curr", curLF + added);

            // ---- 後処理(Papyrus)へ引き渡し＝結果を〔SkyVault〕(npc holder)へ置いて完了modevent送出 ----
            SVSetFloat(npcID, "ASTR2_HDrain_Absorbed", absorbed);
            SVSetFloat(npcID, "ASTR2_HDrain_AcceptedLF", static_cast<float>(added));
            SVSetInt(npcID, "ASTR2_HDrain_Floored", floored ? 1 : 0);
            SVSetInt(npcID, "ASTR2_HDrain_LFFull", (space <= 0) ? 1 : 0);   // 満タン中フラグ＝後処理のおまけXP除外用です
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "astr2_hdrain_done", "", 0.0f, npc };
                src->SendEvent(&ev);
            }

            DrainMark::Mark(npc);   // 💋1回制限＝吸った直後に痕＋NPC淫紋を付けます（中でトグル判定・OFFなら何もしない）
            spdlog::info("[HDrain] {} maxHP={:.0f} hpDrain={:.0f} absorbed={:.0f} lfGain={:.0f} lf+={} (LF {}/{}) tier={} techRank={} totalMult={:.2f}",
                         npc->GetDisplayFullName(), maxHP, hpDrain, absorbed, lfGain, added, curLF + added, maxLF, tier, techRank, totalMult);

            // ---- 吸収FXのC++即出し（ImageSpaceModifier + VisualEffect＝ASTDrainFx相当）は今後の検討事項です。
            //      数値ドレイン(hot)は建って実機で速さを確認済みです＝ここにFXを足す形を検討しています（Phase 2b）。
        }
    }

    // 💋 色欲/H中ドレインの素の威力(表示用)＝実核DoDrain(134-143)の calcDamage×totalMult を相手maxHP項抜きで再計算＝定義は1か所です。
    //   材料は全てDoDrainと同じ〔SkyVault〕キーなので値が一致します。実量は max(calcDamage, maxHP×Lv×0.005)×totalMult＝相手HPで変動します(表示は素の推定)。
    int HDrainOrgasmBaseNow() {
        const int lv = SuccubusLevel();
        return static_cast<int>(HDrainCalcDamage(lv) * HDrainTotalMult(lv));   // 素の威力＝実核DoDrainと同じヘルパです(定義は1か所・相手maxHP項は表示では抜く)
    }

    void Install() {
        g_api = OstimNG_API::Thread::GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));

        class OrgasmSink : public RE::BSTEventSink<SKSE::ModCallbackEvent> {
        public:
            RE::BSEventNotifyControl ProcessEvent(const SKSE::ModCallbackEvent* e,
                                                  RE::BSTEventSource<SKSE::ModCallbackEvent>*) override {
                if (e && e->eventName == "ostim_orgasm") {
                    if (auto* actor = e->sender ? e->sender->As<RE::Actor>() : nullptr) {
                        RE::FormID id = actor->GetFormID();
                        SKSE::GetTaskInterface()->AddTask([id]() { DoDrain(id); });
                    }
                }
                return RE::BSEventNotifyControl::kContinue;
            }
        };
        static OrgasmSink sink;
        if (auto* src = SKSE::GetModCallbackEventSource()) {
            src->AddEventSink(&sink);
            spdlog::info("[HDrain] ostim_orgasm sink installed (g_api={})", (void*)g_api);
        }
    }
}
