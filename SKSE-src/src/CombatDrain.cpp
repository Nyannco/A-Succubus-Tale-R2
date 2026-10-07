#include "PCH.h"
#include "CombatDrain.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"
#include "ServantTier.h"
#include "TechRank.h"
#include "HDrain.h"   // 💋 アラウジング・ラスト{1}のH中ドレイン素の威力 HDrain::HDrainOrgasmBaseNow を相乗り登録します
#include "ManaCost.h" // 🔵 マジカコスト・ランク式＝Ravenous(範囲ドレイン)の毎秒消費（DrainはStage2でバニラ一本化のため不使用）
#include "external/OstimNG-API-Thread.h"

#include <chrono>
#include <cmath>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// ============================================================================
//  戦闘ドレインの核（実体）。詳細は CombatDrain.h。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//  ・Begin/End は Papyrus(ASTR2DrainTrigger)から呼ばれる native＝アクティブ集合の出し入れだけです。
//  ・〔クロノス〕実時間チェッカ(0.25s・ゲームスレッド)が、各ターゲットの「最後に吸ってから1秒」で DoCombatDrain を呼びます。
//  ・DoCombatDrain は ASTDrainScript.Drain() の戦闘枝を1:1移植します（inOStim枝は持ちません＝H中はスキップします）。
// ============================================================================

namespace CombatDrain {
    using namespace OstimNG_API::Thread;

    namespace {
        constexpr const char* kEsp = "A Succubus Tale R2.esp";
        constexpr RE::FormID  kWeaknessMgefLocal = 0x005E36;   // SuccubusWeakness MGEF (01005E36)
        constexpr RE::FormID  kLustMgefLocal     = 0x00B4A5;   // Lust MGEF (0100B4A5)

        // ---- 係数の既定値（実値は〔SkyVault〕から毎回読みます＝ASTDrainScriptと定義は1か所です。キー未設定時だけこの既定値を使います）----
        constexpr float kDestPowerDivisorDef = 100.0f;   // ASTR2_DestPowerDivisor
        constexpr float kResistDivisorDef    = 100.0f;   // ASTR2_ResistDivisor
        constexpr float kResistFloorDef      = 0.15f;    // ASTR2_ResistFloor
        constexpr float kWeaknessBaseDef     = 0.0f;     // ASTR2_WeaknessBase
        constexpr float kWeaknessPerLvDef    = 1.0f;     // ASTR2_WeaknessPerLv（★MCMスライダー＝〔SkyVault〕化）
        constexpr float kWeaknessCapDef      = 100.0f;   // ASTR2_WeaknessCap （★MCMスライダー＝同上）
        constexpr float kTechDrainRateDef    = 0.05f;    // ASTR2_TechDrainRate
        constexpr float kServantLFPerTierDef = 0.25f;    // ASTR2_ServantLFPerTier
        constexpr float kCombatFloorPct      = 0.10f;    // 非OStim 下限＝最大HP×10%（旧Drain固定値）
        constexpr float kDrainPctCoefDef     = 0.005f;   // ASTR2_DrainPctCoef  ＝%基礎威力の係数（最大HP×係数×Lv²/除数）
        constexpr float kDrainLvGateDivDef   = 100.0f;   // ASTR2_DrainLvGateDiv＝%威力のLv抑制除数（Lv100で現状維持です／新規はLv²で激減します＝高HP抜け道対策）

        IThreadInterface* g_api = nullptr;

        // ---- 〔SkyVault〕短縮（HDrainと同じ流儀）----
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

        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 🩸 ドレイン基礎量/秒の素式＝2+(Lv-1)×8。表示getter(DrainBaseNow)も戦闘核(DoCombatDrain)もこれを呼びます＝計算の定義は1か所です。
        inline int DrainBaseRaw(int lv) { return 2 + (lv - 1) * 8; }

        // MGEFをローカルID→フォームで1回だけ解決してキャッシュします。
        RE::EffectSetting* LookupMgef(RE::FormID local) {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                return dh->LookupForm<RE::EffectSetting>(local, kEsp);
            }
            return nullptr;
        }

        // 対象がその MGEF の効果を持っているかを調べます（＋lust用にdispel対象を拾えるよう分離せず、必要時に個別関数にします）。
        bool HasEffect(RE::Actor* a, RE::EffectSetting* mgef) {
            if (!a || !mgef) return false;
            auto* mt = a->AsMagicTarget();
            if (!mt) return false;
            auto* list = mt->GetActiveEffectList();
            if (!list) return false;
            for (auto* ae : *list) {
                if (ae && ae->GetBaseObject() == mgef) return true;
            }
            return false;
        }

        // アラウジング・ラスト効果を消します（消費＝倍率+1を1回だけ乗せたら剥がします）。旧 akTarget.DispelSpell(lustSpell) 相当です。
        void DispelEffect(RE::Actor* a, RE::EffectSetting* mgef) {
            if (!a || !mgef) return;
            auto* mt = a->AsMagicTarget();
            if (!mt) return;
            auto* list = mt->GetActiveEffectList();
            if (!list) return;
            for (auto* ae : *list) {
                if (ae && ae->GetBaseObject() == mgef) ae->Dispel(true);
            }
        }

        // ---- HP/AV ヘルパ ----
        inline float CurHP(RE::Actor* a) {
            return a->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth);
        }
        // 最大HP＝恒久値(base+enchant)＋一時fortify（オーガズムバフ等も入ります＝FinisherEval/旧Drainのpct由来最大と同義）。
        inline float MaxHP(RE::Actor* a) {
            const float perm = a->AsActorValueOwner()->GetPermanentActorValue(RE::ActorValue::kHealth);
            const float temp = a->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kHealth);
            return perm + temp;
        }
        inline void DamageHP(RE::Actor* a, float amt) {
            a->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth, -amt);
        }
        inline void HealHP(RE::Actor* a, float amt) {
            a->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth, amt);
        }

        // ---- アクティブ集合＝ビーム中のターゲット（key=ターゲットFormID）----
        struct Entry {
            RE::FormID caster;
            bool       canKill;   // Begin時にPapyrus CanKillTarget()が算出して渡した値です（ビーム中は固定）
            std::chrono::steady_clock::time_point lastDrain;
            std::chrono::steady_clock::time_point lastSeen{};   // 最後にBegin(=ビームが当たった合図)が来た時刻です。離脱検知用です。Ravenousは未使用です。
        };
        std::mutex                                 g_mtx;
        std::unordered_map<RE::FormID, Entry>      g_active;
        // ★013622は Concentration+Duration0 ＝毎回パッと乗って消えるインスタント再適用型です（持続しません）。
        //   なので「今乗ってるか」は見れず、「Beginの合図が来続けてるか」で当たり継続を判定します。
        //   詠唱を続けたまま狙いを移した(逸らし/薙ぎ払い)対象＝Beginがこの秒数来なければ外します。
        //   ※手下ろし(詠唱終了)は別経路＝IsChargingDrainで即全クリアします(Tick)。ここのstaleは「詠唱中の離脱」専用です。
        //   ＝再適用周期(1周期ぶん)より少し長く取る最小のガードです。実機で効き過ぎ/遅ければこの数字だけ調整します。
        constexpr float                            kDrainStaleSec = 1.5f;

        // ---- 範囲ドレイン（破壊ドレイン複数版）＝Ravenousを構えている間ON、術者中心の複数体を吸います ----
        //   単体ビーム(g_active)とは別集合で持ちます（挙動＝範囲外で外します/Lv連動人数上限があるため）。
        //   DoCombatDrain(1体1秒吸う)・威力式・LF化・後でまとめて記録する処理は単体ビームと丸ごと共用します。
        bool                                       g_aoeActive = false;
        RE::FormID                                 g_aoeCaster = 0;                 // ＝プレイヤーです（回復先）
        std::unordered_map<RE::FormID, Entry>      g_aoeTargets;                    // 今吸ってる複数体です
        // ★維持型＝Ravenousを構えている間ON（RavenousPollがcurrentSpell監視・psc非依存）。
        //   構え検知でON→kAoeWindupSec秒チャージ待ち→吸収開始→構えやめ(放出/中断)でOFF。
        std::chrono::steady_clock::time_point      g_aoeStart;                      // 詠唱開始時刻です（吸い始めまでの待ちの起点）
        bool                                       g_aoeWindupDone = false;         // チャージ経過＝吸収を始めたか
        constexpr float                            kAoeWindupSec = 3.0f;            // 詠唱開始→吸い始めまで（3秒・調整可）
        RE::BSSoundHandle                          g_aoeLoopSound{};                // 🔊 構え中のループ音ハンドルです（Concentration Cast Loop 03F205）
        // ★前方宣言：定義は下方(488/498)です。Ravenousのマジカ切れ処理(423)が定義より前で呼び出すための前方参照です。
        void StartAoeLoopSound(RE::Actor* caster);
        void StopAoeLoopSound();

        // ---- 🔵 マジカコスト（ランク式・ManaCost）＝起点で減率を1回キャッシュ→毎秒消費（毎tickは掛け算のみ）----
        float g_ravRed = 0.0f;                                    // Ravenous範囲ドレインの減率です（構え検知でキャッシュします）

        // ============================================================
        //  ドレイン核（ゲームスレッドで実行＝〔クロノス〕realtime は AddTask 経由でゲームスレッド）。
        //  返り値＝true なら集合から外します（殺害/無効）。
        // ============================================================
        bool DoCombatDrain(RE::FormID targetID, RE::FormID casterID, bool canKill) {
            auto* target = RE::TESForm::LookupByID<RE::Actor>(targetID);
            auto* caster = RE::TESForm::LookupByID<RE::Actor>(casterID);   // ＝ドレイン術者(プレイヤー)。回復先。
            if (!target || !caster || target == caster || target->IsDead()) return true;   // 無効＝外します

            // 🍖暴食(Gula・ネイルidx3)＝〔天敵〕(ドワーフ機械)の吸引制御です。esp条件(ActorTypeDwarven=0)を手作業で外した分をここで管理します：
            //   通常はドワーフを吸いません（据置＝〔天敵〕）／暴食active時だけ少量ドレイン→LF。非ドワーフはgulaMult=1.0で無影響です。
            float gulaMult = 1.0f;
            {
                static RE::BGSKeyword* dwarvenKw = nullptr;
                if (!dwarvenKw) { if (auto* dh = RE::TESDataHandler::GetSingleton()) dwarvenKw = dh->LookupForm<RE::BGSKeyword>(0x01397A, "Skyrim.esm"); }
                if (dwarvenKw && target->HasKeyword(dwarvenKw)) {
                    if (SVInt("ASTR2_NailActive_3", 0) != 1) return false;         // 暴食OFF＝ドワーフは吸えません（集合に残すが吸いません）
                    gulaMult = SVFloat("ASTR2_NailGulaPerLv", 0.001f) * static_cast<float>(SuccubusLevel());   // 🍖ドワーフダメ＝Lv×0.1%（Lv100で通常の10%・低Lvは極小）
                }
            }

            // 🛑 H中はスキップします（プレイヤーがOStimシーン中＝ビームは実質発生しません／H中ドレインはHDrainが担当ですので二重にしません）。
            //   ★API仕様＝GetPlayerThreadIDは「sceneに居ない時 0」を返します（-1ではありません）。旧コードの`!=-1`は
            //     戦闘中(tid=0)でも常にtrue→毎tickスキップ＝一度も吸わないバグになっていました。
            //     有効sceneに居る時＝tidが0でも-1(エラー)でもなく IsThreadValid の時だけスキップします。
            if (g_api) {
                const uint32_t tid = g_api->GetPlayerThreadID();
                if (tid != 0 && tid != static_cast<uint32_t>(-1) && g_api->IsThreadValid(tid)) return false;   // 有効scene中だけ集合に残してスキップします
            }

            const float curHP = CurHP(target);
            if (curHP <= 0.0f) return false;
            const float maxHP = MaxHP(target);
            const int   sucLv = SuccubusLevel();

            // ---- 威力式（ASTDrainScript.Drain() 戦闘枝の1:1移植・足し算方式）----
            const float base = static_cast<float>(DrainBaseRaw(sucLv));   // 基礎ドレイン量/秒＝DrainBaseNowと同じ素式(定義は1か所です)
            const float destFactor = 1.0f + caster->AsActorValueOwner()->GetActorValue(RE::ActorValue::kDestruction)
                                             / SVFloat("ASTR2_DestPowerDivisor", kDestPowerDivisorDef);
            float totalMult = destFactor;

            // サキュバス・ウィークネス＝耐性減算（ESP-20込みのMagicResistから更に Base+PerLv×(Lv-6)^2 を引きます・cap）
            float tgtResist = target->AsActorValueOwner()->GetActorValue(RE::ActorValue::kResistMagic);
            static RE::EffectSetting* weaknessMgef = nullptr;
            static RE::EffectSetting* lustMgef = nullptr;
            if (!weaknessMgef) weaknessMgef = LookupMgef(kWeaknessMgefLocal);
            if (!lustMgef)     lustMgef     = LookupMgef(kLustMgefLocal);
            if (HasEffect(target, weaknessMgef)) {
                int wsOver = sucLv - 6;
                if (wsOver < 0) wsOver = 0;
                float wsAdd = SVFloat("ASTR2_WeaknessBase", kWeaknessBaseDef)
                              + SVFloat("ASTR2_WeaknessPerLv", kWeaknessPerLvDef) * static_cast<float>(wsOver) * static_cast<float>(wsOver);
                const float wsCap = SVFloat("ASTR2_WeaknessCap", kWeaknessCapDef);
                if (wsAdd > wsCap) wsAdd = wsCap;
                // 🩸ドレイン追加減算を手技(自慰cat2)×変性でスケールします（①ESP-20=全魔法共通はtgtResistに反映済みですので据え置きます・②ドレイン特化分だけ伸ばします）。
                //   術者＝ドレインは常にプレイヤーですので変性はcasterのを見ます（表示getter WeaknessResistDownNowと同基準＝表示と実挙動のズレを解消します）。
                const float wsTech = 1.0f + static_cast<float>(TechRank::GetDisplayCatRank(2)) * 0.05f;
                float wsAlt = 1.0f;
                if (caster) if (auto* cavo = caster->AsActorValueOwner()) wsAlt = 1.0f + cavo->GetActorValue(RE::ActorValue::kAlteration) / 100.0f;
                wsAdd *= wsTech * wsAlt;
                tgtResist -= wsAdd;
            }
            float resistFactor = 1.0f - tgtResist / SVFloat("ASTR2_ResistDivisor", kResistDivisorDef);
            const float resistFloor = SVFloat("ASTR2_ResistFloor", kResistFloorDef);
            if (resistFactor < resistFloor) resistFactor = resistFloor;

            // アラウジング・ラスト＝倍率+1（消費＝剥がします）
            if (HasEffect(target, lustMgef)) {
                totalMult += 1.0f;
                DispelEffect(target, lustMgef);
            }

            // Hスキル＝戦闘は総合rank（H中は種目別ですが戦闘は総合です）
            totalMult += static_cast<float>(TechRank::GetDisplayTotalRank()) * SVFloat("ASTR2_TechDrainRate", kTechDrainRateDef);

            // 基礎%（高HPも割合で削ります）＝max(フラット, 最大HP×Lv×0.005)→足し算倍率→耐性(戦闘のみ)
            // 🩸%基礎威力＝最大HP×係数×Lv²/除数（Lvで威力を抑えます）。
            //   旧＝maxHP×Lv×0.005＝敵HD比例ですので新規でも高HP敵を一撃で狩れてしまいました→Lv²/100で「自分の育ち」に抑えます。
            //   Lv100=現状維持(×1.0)／Lv50≈×0.5／Lv1≈×0.01＝ほぼ無し。普通の敵(数百HP)はフラット基礎が勝つので無影響＝高HPの抜け道だけ狙い撃ちです。
            const float pctCoef = SVFloat("ASTR2_DrainPctCoef", kDrainPctCoefDef);
            const float gateDiv = SVFloat("ASTR2_DrainLvGateDiv", kDrainLvGateDivDef);
            const float lvF     = static_cast<float>(sucLv);
            const float pctBase = (gateDiv > 0.0f) ? (maxHP * pctCoef * lvF * lvF / gateDiv) : (maxHP * pctCoef * lvF);
            float amount = (pctBase > base) ? pctBase : base;
            amount *= totalMult;
            amount *= resistFactor;   // 戦闘＝耐性を乗算（サキュバス・ウィークネスで>1なら増幅）
            amount *= gulaMult;       // 🍖暴食＝ドワーフ機械は少量（gulaMult<1・非ドワーフは1.0で無影響）

            // 🔥憤怒(Ira・ネイルidx0)＝プレイヤー(術者)が低HP時、ドレイン与ダメがUPします（本MODの攻撃魔法＝ドレイン/Ravenousにも乗せます）。
            //   ★ドレイン/RavenousはDamageHP直削りでMagicHitフックを通らないので、WrathBoostMagicと同式(閾値10+Lv×0.3/倍率1+Lv×0.01)をここで乗せます。
            if (SVInt("ASTR2_NailActive_0", 0) == 1) {
                const float casterMax = MaxHP(caster);
                if (casterMax > 0.0f) {
                    const float casterHpPct = CurHP(caster) / casterMax * 100.0f;
                    const float wrathThr = 10.0f + static_cast<float>(sucLv) * 0.3f;   // 低HP閾値＝Lvで変動します(Lv1≈10.3%→Lv100=40%)
                    if (casterHpPct < wrathThr) {
                        const float wrathMult = 1.0f + static_cast<float>(sucLv) * 0.01f;   // 威力はLv連動します（Lv100で2倍）
                        amount *= wrathMult;
                        spdlog::info("[CombatDrain] 🔥憤怒 ドレイン与ダメUP x{:.2f} (術者hp{:.0f}% < 閾値{:.0f}%)", wrathMult, casterHpPct, wrathThr);
                    }
                }
            }

            // ---- 実際に削る量 ----
            float hpDrain = 0.0f;
            if (canKill) {
                hpDrain = amount;   // 敵/許可NPC＝フルダメージ（死ねます）
            } else {
                float floorHP = maxHP * kCombatFloorPct;   // 非OStim 下限＝最大HP×10%
                float drainable = curHP - floorHP;
                if (drainable > 0.0f) {
                    if (amount < drainable) { hpDrain = amount; }
                    else { hpDrain = drainable; }
                }
            }
            if (hpDrain > 0.0f) DamageHP(target, hpDrain);

            bool killed = false;
            if (canKill && (curHP - hpDrain) <= 5.0f) killed = true;

            // ---- 実吸収→術者(プレイヤー)回復優先→あふれLF×tier ----
            float absorbed = hpDrain;
            if (absorbed > curHP) absorbed = curHP;
            if (absorbed < 0.0f) absorbed = 0.0f;
            float casterHeal = 0.0f;
            if (absorbed > 0.0f) {
                const float missing = MaxHP(caster) - CurHP(caster);
                casterHeal = (absorbed < missing) ? absorbed : missing;
                if (casterHeal < 0.0f) casterHeal = 0.0f;
                if (casterHeal > 0.0f) HealHP(caster, casterHeal);
            }
            float lfGain = absorbed - casterHeal;
            const int tier = ServantTier::Get(target);
            lfGain *= (1.0f + static_cast<float>(tier) * SVFloat("ASTR2_ServantLFPerTier", kServantLFPerTierDef));
            // 🖤強欲(Avaritia・ネイルidx6)＝LF吸収+Lv%（active時のみ・Lv100で+100%＝吸収2倍）。
            if (SVInt("ASTR2_NailActive_6", 0) == 1) {
                lfGain *= 1.0f + static_cast<float>(SuccubusLevel()) * 0.01f;
            }
            if (lfGain < 0.0f) lfGain = 0.0f;

            // ---- LFプールへ加算（カンストあふれは破棄します）----
            const int curLF = SVInt("ASTR2_LF_Curr", 400);
            const int maxLF = SVInt("ASTR2_LF_Max", 800);
            int space = maxLF - curLF; if (space < 0) space = 0;
            int added = static_cast<int>(std::ceil(lfGain));
            if (added < 0) added = 0;
            if (added > space) added = space;
            if (added > 0) SVSetInt(0, "ASTR2_LF_Curr", curLF + added);
            const bool lfFull = (space <= 0);

            // ---- 後処理(Papyrus)へ引き渡し＝結果を〔SkyVault〕(target holder)へ置いて完了modeventを送出します ----
            SVSetFloat(targetID, "ASTR2_CDrain_Absorbed", absorbed);
            SVSetFloat(targetID, "ASTR2_CDrain_AcceptedLF", static_cast<float>(added));
            SVSetInt(targetID, "ASTR2_CDrain_Killed", killed ? 1 : 0);
            SVSetInt(targetID, "ASTR2_CDrain_LFFull", lfFull ? 1 : 0);
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ "astr2_combatdrain_done", "", 0.0f, target };
                src->SendEvent(&ev);
            }

            spdlog::info("[CombatDrain] {} maxHP={:.0f} hpDrain={:.0f} absorbed={:.0f} lf+={} (LF {}/{}) canKill={} killed={} rf={:.2f} mult={:.2f} tier={}",
                         target->GetDisplayFullName(), maxHP, hpDrain, absorbed, added, curLF + added, maxLF, canKill, killed, resistFactor, totalMult, tier);

            return killed;   // 殺害＝集合から外します（Papyrus KillTargetが仕上げます）／通常は残して次tick
        }

        // ============================================================
        //  範囲ドレイン（複数版）のLv連動です。
        //    範囲radius：Lv10=768u(≈11m) → Lv100=1792u(≈25m)・線形（広め）。
        //    人数上限 ：Lv10=2体 → 10Lvごと+1体（Lv100=11体）。
        // ============================================================
        float AoeRadius(int lv) {
            float r = 768.0f + (static_cast<float>(lv) - 10.0f) * 11.38f;
            return (r < 768.0f) ? 768.0f : r;   // Lv10未満は習得しませんが保険で下限です
        }
        int AoeMaxTargets(int lv) {
            int n = 2 + (lv - 10) / 10;
            return (n < 2) ? 2 : n;
        }

        // Ravenous SPEL(020881)を1回だけ解決してキャッシュします。
        RE::SpellItem* RavenousSpell() {
            static RE::SpellItem* s = nullptr;
            if (!s) { if (auto* dh = RE::TESDataHandler::GetSingleton()) s = dh->LookupForm<RE::SpellItem>(0x020881, kEsp); }
            return s;
        }
        // プレイヤーが今Ravenousを「構えている」かどうかです（currentSpellがRavenous）。
        //   発動型(FireAndForget+長チャージ)の構え中＝どの手のcasterでもcurrentSpell==Ravenousなら真です。
        bool IsChargingRavenous(RE::PlayerCharacter* pc) {
            auto* rav = RavenousSpell();
            if (!rav) return false;
            using CS = RE::MagicSystem::CastingSource;
            for (auto src : { CS::kLeftHand, CS::kRightHand, CS::kOther, CS::kInstant }) {
                if (auto* mc = pc->GetMagicCaster(src)) {
                    if (mc->currentSpell == rav) return true;
                }
            }
            return false;
        }
        // ★単体Drain呪文(007924)を「今詠唱中(手を上げてビームを出してる)」か＝どの手のcasterでもcurrentSpell==Drainなら真です。
        //   ログ実測＝ビーム保持中ずっとtrue・手を下ろすとfalse＝手上げ/下げの信頼できる信号です。
        //   用途＝手下ろし(未発動)を拾って残留ドレインを即停止します（Tick）。逸らし/薙ぎ払い(詠唱は継続)はこれでは落とさずstaleが担当です。
        bool IsChargingDrain(RE::PlayerCharacter* pc) {
            static RE::SpellItem* drn = nullptr;
            if (!drn) { if (auto* dh = RE::TESDataHandler::GetSingleton()) drn = dh->LookupForm<RE::SpellItem>(0x007924, kEsp); }
            if (!drn) return false;
            using CS = RE::MagicSystem::CastingSource;
            for (auto src : { CS::kLeftHand, CS::kRightHand, CS::kOther, CS::kInstant }) {
                if (auto* mc = pc->GetMagicCaster(src)) {
                    if (mc->currentSpell == drn) return true;
                }
            }
            return false;
        }
        // kill可否のC++判定＝単体ビーム CanKillTarget と同じルールです（保護＋AllowKill設定を反映します）。
        //   AllowKillNPC/Unique は MCM→〔SkyVault〕へミラーします（C++はそれを読みます）。既定0＝殺さない側です。
        //   ・手下/召喚体/フォロワー＝常に保護します（殺しません）
        //   ・ユニーク/Essential/Protected/正規フォロワー＝AllowKillUnique の時だけ殺せます
        //   ・一般＝AllowKillNPC が有効、または相手が敵(hostile/戦闘中/山賊)の時に殺せます（＝現行単体と同式）
        bool CanKillCpp(RE::Actor* a) {
            if (!a) return false;
            if (a->IsCommandedActor()) return false;                       // 召喚体/蘇生した手下
            if (a->IsPlayerTeammate()) return false;                       // フォロワー
            auto* dh = RE::TESDataHandler::GetSingleton();
            static RE::TESFaction* followerFac = dh ? dh->LookupForm<RE::TESFaction>(0x0005C84E, "Skyrim.esm") : nullptr;
            static RE::TESFaction* banditFac   = dh ? dh->LookupForm<RE::TESFaction>(0x0001BCC0, "Skyrim.esm") : nullptr;
            bool special = false;
            if (auto* base = a->GetActorBase()) {
                if (base->IsUnique() || base->IsEssential() || base->IsProtected()) special = true;
            }
            if (followerFac && a->IsInFaction(followerFac)) special = true;   // 正規フォロワー
            if (special) return SVInt("ASTR2_AllowKillUnique", 0) != 0;
            auto* player = RE::PlayerCharacter::GetSingleton();
            const bool isEnemy = (player && a->IsHostileToActor(player)) || a->IsInCombat() || (banditFac && a->IsInFaction(banditFac));
            return (SVInt("ASTR2_AllowKillNPC", 0) != 0) || isEnemy;
        }

        // 📋 ステータスinfo表示用の現在値getter＝今Lvの効果範囲(m・半径)と同時吸引の最大人数です。ON/OFF問わず現在値です。
        float GetRavenousRange(RE::StaticFunctionTag*) {
            return AoeRadius(SuccubusLevel()) / 70.0f;   // game units → メートル(半径)。1m≈70units（Skyrim 1unit≈1.43cm）。
        }
        int GetRavenousMaxTargets(RE::StaticFunctionTag*) {
            return AoeMaxTargets(SuccubusLevel());
        }

        // 範囲ドレインの実時間tickです（Tickの末尾から呼び出します＝同じ0.25s粒度・ゲームスレッド）。
        //   ①今吸ってる体＝範囲外/死亡を外します＋1秒ごとにDoCombatDrain（単体と共用します）。
        //   ②空き枠ぶん、範囲内の"新規の敵"をCanKillCppで判定して集合へ（C++完結・ポーリング駆動）。
        void AoeTick() {
            if (!g_aoeActive) return;
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (!player) return;

            // ★詠唱開始から kAoeWindupSec 秒経つまで吸いません（詠唱開始3秒後に吸い始めます）。
            if (!g_aoeWindupDone) {
                const float since = std::chrono::duration<float>(std::chrono::steady_clock::now() - g_aoeStart).count();
                if (since < kAoeWindupSec) return;
                g_aoeWindupDone = true;
                spdlog::info("[CombatDrain][AoE] 詠唱{:.1f}s経過→吸収開始", kAoeWindupSec);
            }

            const int   lv     = SuccubusLevel();
            const float radius = AoeRadius(lv);
            const float r2     = radius * radius;
            const int   maxN   = AoeMaxTargets(lv);
            const auto  pp     = player->GetPosition();

            // (1) 既存の吸ってる体＝範囲外/死亡を外します＋1秒経過ならDoCombatDrain対象へ
            std::vector<std::pair<RE::FormID, Entry>> due;
            {
                std::scoped_lock lk(g_mtx);
                const auto now = std::chrono::steady_clock::now();
                for (auto it = g_aoeTargets.begin(); it != g_aoeTargets.end(); ) {
                    auto* a = RE::TESForm::LookupByID<RE::Actor>(it->first);
                    bool drop = (!a || a->IsDead());
                    if (!drop) {
                        const auto ap = a->GetPosition();
                        const float dx = pp.x - ap.x, dy = pp.y - ap.y, dz = pp.z - ap.z;
                        if (dx * dx + dy * dy + dz * dz > r2) drop = true;   // 範囲外に出たので外します
                    }
                    if (drop) { it = g_aoeTargets.erase(it); continue; }
                    if (std::chrono::duration<float>(now - it->second.lastDrain).count() >= 1.0f) {
                        due.emplace_back(it->first, it->second);
                        it->second.lastDrain = now;
                    }
                    ++it;
                }
            }
            // 🔵 マジカ消費＝今秒吸う体数分（Ravenousは範囲＝人数分）。払えなければRavenous中断します（吸う前に判定します）。
            if (!due.empty()) {
                if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                    bool broke = false;
                    const int ravTier = ManaCost::CostTierFor(pc, ManaCost::SpellKind::kRavenous);   // ★毎秒消費＝表示コストと同じcostTier(定義は1か所です)
                    for (size_t i = 0; i < due.size(); ++i) {
                        if (!ManaCost::TrySpendPerSec(pc, ravTier, g_ravRed)) { broke = true; break; }   // ×人数分
                    }
                    if (broke) {
                        pc->InterruptCast(false);
                        { std::scoped_lock lk(g_mtx); g_aoeActive = false; g_aoeCaster = 0; g_aoeTargets.clear(); }
                        StopAoeLoopSound();
                        spdlog::info("[CombatDrain][AoE] マジカ切れ→Ravenous中断（体数={}）", due.size());
                        return;
                    }
                }
            }
            for (auto& [id, e] : due) {
                if (DoCombatDrain(id, e.caster, e.canKill)) {
                    std::scoped_lock lk(g_mtx);
                    g_aoeTargets.erase(id);
                }
            }

            // (2) 空き枠ぶん、範囲内の新規の敵を集めます（kill可否はPapyrusへ委譲します）
            int slots;
            {
                std::scoped_lock lk(g_mtx);
                slots = maxN - static_cast<int>(g_aoeTargets.size());
            }
            if (slots <= 0) return;

            // ★内装(worldspace無し)で ForEachReferenceInRange が SkyCell を掴んでCTDします→
            //   worldspace/SkyCellに触らない ProcessLists::ForEachHighActor＋距離フィルタへ差し替えます（アクターだけ走査・内外両対応・軽い）。
            auto* procLists = RE::ProcessLists::GetSingleton();
            if (!procLists) return;
            // アビリティコンフィグのトグル：フォロワーも吸うか／一般NPCも吸うかどうかです（既定0＝敵だけ）。
            const bool followerToo = SVInt("ASTR2_RavenousFollowerToo", 0) != 0;
            const bool generalToo  = SVInt("ASTR2_RavenousNpcToo", 0) != 0;   // 正キー（フォロワー版と対）＝一般・ユニークNPC(中立)も吸います
            std::vector<RE::Actor*> found;
            procLists->ForEachHighActor([&](RE::Actor* a) {
                if (a != player && !a->IsDead()) {
                    const auto ap = a->GetPosition();
                    const float dx = pp.x - ap.x, dy = pp.y - ap.y, dz = pp.z - ap.z;
                    if (dx * dx + dy * dy + dz * dz <= r2) {   // 範囲内（距離は問わず枠が埋まるまで拾います）
                        // 敵は常に対象です。フォロワー/一般NPCはトグルONの時だけです。殺す/殺さないはCanKillCpp(AllowKill設定)が決めます。
                        const bool isEnemy    = a->IsHostileToActor(player) || a->IsInCombat();
                        const bool isFollower = a->IsPlayerTeammate();
                        const bool isGeneral  = !isEnemy && !isFollower;   // 敵でもフォロワーでもない中立です（★ユニークNPCも含みます＝一般NPCトグルで一括吸引します・殺す可否だけAllowKillUniqueで別判定します）
                        if (isEnemy || (followerToo && isFollower) || (generalToo && isGeneral)) {
                            found.push_back(a);
                        }
                    }
                }
                return RE::BSContainer::ForEachResult::kContinue;
            });
            spdlog::info("[CombatDrain][AoE] scan r={:.0f} 敵候補={} 空き枠={}（吸い中={}）", radius, found.size(), slots, g_aoeTargets.size());

            // kill可否はC++で判定して即集合へ（ポーリング駆動＝Papyrus受け口がないのでmodeventは使いません）。
            for (auto* a : found) {
                if (slots <= 0) break;
                const RE::FormID id = a->GetFormID();
                std::scoped_lock lk(g_mtx);
                if (g_aoeTargets.count(id)) continue;
                g_aoeTargets[id] = Entry{ g_aoeCaster, CanKillCpp(a), std::chrono::steady_clock::now() };
                --slots;
            }
        }

        // 🔊 範囲ドレインの「吸ってる間」ループ音＝単体ドレインと同じ Concentration Cast Loop(03F205/Skyrim.esm)。
        //   Ravenousは発動型(FaF)で呪文/MGEFからは持続音が鳴らないので、構え検知〜構えやめの間だけC++で再生します。
        RE::BGSSoundDescriptorForm* AoeLoopDescriptor() {
            static RE::BGSSoundDescriptorForm* s = nullptr;
            if (!s) { if (auto* dh = RE::TESDataHandler::GetSingleton()) s = dh->LookupForm<RE::BGSSoundDescriptorForm>(0x03F205, "Skyrim.esm"); }
            return s;
        }
        void StartAoeLoopSound(RE::Actor* caster) {
            if (g_aoeLoopSound.IsValid()) return;   // 既にハンドル保持中＝二重再生しません（Stop時に無効化します）
            auto* desc = AoeLoopDescriptor();
            auto* am = RE::BSAudioManager::GetSingleton();
            if (!desc || !am || !caster) return;
            if (am->GetSoundHandle(g_aoeLoopSound, desc)) {
                if (auto* n = caster->Get3D()) g_aoeLoopSound.SetObjectToFollow(n);
                g_aoeLoopSound.Play();
            }
        }
        void StopAoeLoopSound() {
            if (g_aoeLoopSound.IsValid()) {
                g_aoeLoopSound.Stop();
                g_aoeLoopSound = RE::BSSoundHandle{};
            }
        }
        // 一発音（構え=Draw 03F208 / 構えやめ=Release 03F206）＝ハンドル保持は不要です（鳴り切りで自動解放します）。
        void PlayOneShotAt(RE::FormID descId, RE::Actor* at) {
            auto* dh = RE::TESDataHandler::GetSingleton();
            auto* am = RE::BSAudioManager::GetSingleton();
            if (!dh || !am || !at) return;
            auto* desc = dh->LookupForm<RE::BGSSoundDescriptorForm>(descId, "Skyrim.esm");
            if (!desc) return;
            RE::BSSoundHandle h{};
            if (am->GetSoundHandle(h, desc)) {
                if (auto* n = at->Get3D()) h.SetObjectToFollow(n);
                h.Play();
            }
        }

        // 発動型(FireAndForget+長チャージ)の「構えてる間」をC++が監視して強制介入します。
        //   currentSpell==Ravenousの間ONにし、構えをやめたら（放出/中断/離し）OFFにします。psc(呪文効果)に依存しません。
        void RavenousPoll() {
            auto* pc = RE::PlayerCharacter::GetSingleton();
            if (!pc) return;
            const bool charging = IsChargingRavenous(pc);
            bool turnedOn = false;
            bool turnedOff = false;
            if (charging && !g_aoeActive) {
                std::scoped_lock lk(g_mtx);
                g_aoeActive = true;
                g_aoeCaster = pc->GetFormID();
                g_aoeTargets.clear();
                g_aoeStart = std::chrono::steady_clock::now();
                g_aoeWindupDone = false;
                turnedOn = true;
                spdlog::info("[CombatDrain][AoE] === ON (構え検知) 詠唱{:.1f}s後に吸収開始", kAoeWindupSec);
            } else if (!charging && g_aoeActive) {
                std::scoped_lock lk(g_mtx);
                g_aoeActive = false;
                g_aoeCaster = 0;
                g_aoeTargets.clear();
                turnedOff = true;
                spdlog::info("[CombatDrain][AoE] === OFF (構えやめ)");
            }
            // 🔵 マジカ減率＝構え検知の瞬間に1回だけ測ってキャッシュします（毎tickは掛け算のみ）
            if (turnedOn) {
                g_ravRed = ManaCost::ComputeReduction(pc, ManaCost::SpellKind::kRavenous);
                spdlog::info("[CombatDrain][AoE] マジカ減率キャッシュ red={:.3f}", g_ravRed);
            }
            // 🔊 3点セット：構え=Draw(03F208) / 吸ってる間=Loop(03F205) / 構えやめ=Release(03F206)（ロック外で再生します）
            if (turnedOn)  { PlayOneShotAt(0x03F208, pc); StartAoeLoopSound(pc); }
            if (turnedOff) { StopAoeLoopSound(); PlayOneShotAt(0x03F206, pc); }
        }

        // 〔クロノス〕実時間チェッカ＝各ターゲットが「最後に吸ってから1秒」で1回吸います（初回はBegin+1秒）。
        void Tick() {
            // ★範囲ドレインの構え監視は早期returnより前です（これがg_aoeActiveを立てます＝単体ビーム0でも走らせます）。
            RavenousPoll();

            // 🩸 単体Drainビームの対象除去＝2段構え：
            //   ①手下ろし(未発動)＝IsChargingDrain false＝ビームを出していません→即・全クリアします（残留ドレインを消します＝後に残しません）。
            //   ②詠唱継続中の逸らし/薙ぎ払い＝IsChargingDrain true のまま→013622はインスタント型で「今乗ってるか」を見れないので
            //     Begin(当たった合図)がkDrainStaleSec秒来ない対象だけstaleで外します（当て続けはBeginが来続けて残ります）。
            //   ※g_activeのみ・Ravenous(g_aoeTargets)は別管理なので無影響です。
            {
                auto* pcDr = RE::PlayerCharacter::GetSingleton();
                const bool charging = pcDr && IsChargingDrain(pcDr);
                const auto nowChk = std::chrono::steady_clock::now();
                std::scoped_lock lk(g_mtx);
                if (!charging) {
                    // ①手下ろし＝ビーム出ていません→全部即止めます（後に残しません）。
                    if (!g_active.empty()) {
                        g_active.clear();
                        spdlog::info("[CombatDrain] 手下ろし(詠唱終了)→単体ドレイン即停止");
                    }
                } else {
                    // ②詠唱中は離れた対象(Begin途絶stale)/死亡/無効だけ外します。当て続けている対象は残ります。
                    for (auto it = g_active.begin(); it != g_active.end(); ) {
                        auto* a = RE::TESForm::LookupByID<RE::Actor>(it->first);
                        if (!a || a->IsDead() ||
                            std::chrono::duration<float>(nowChk - it->second.lastSeen).count() > kDrainStaleSec) {
                            it = g_active.erase(it);
                        } else {
                            ++it;
                        }
                    }
                }
            }

            // 🔵 Drain単体ビームのマジカ消費＝バニラに一本化します（Drain=Concentration＝CalculateMagickaCostフックで
            //   バニラが毎秒消費し＋マジカ切れでビーム停止します・ManaCost.cpp）。ここでは払いません。

            std::vector<std::pair<RE::FormID, Entry>> due;
            {
                std::scoped_lock lk(g_mtx);
                // ★単体ビーム(g_active)が空でも、範囲ドレイン(g_aoeActive)中はAoeTickを回すので抜けません。
                if (g_active.empty() && !g_aoeActive) return;
                const auto now = std::chrono::steady_clock::now();
                for (auto& [id, e] : g_active) {
                    if (std::chrono::duration<float>(now - e.lastDrain).count() >= 1.0f) {
                        due.emplace_back(id, e);
                        e.lastDrain = now;   // 1秒に1回（飛んでも溜め込みません）
                    }
                }
            }
            for (auto& [id, e] : due) {
                if (DoCombatDrain(id, e.caster, e.canKill)) {
                    std::scoped_lock lk(g_mtx);
                    g_active.erase(id);
                }
            }
            // 範囲ドレイン（複数版）の吸収tickです（構え監視RavenousPollはTick冒頭で実施済みです）。
            AoeTick();
        }

        // ===== Papyrus native =====
        //  ビーム開始＝当てて+1秒で初回吸収（lastDrain=今）。canKillはPapyrus CanKillTarget()が算出済です。
        void CombatDrainBegin(RE::StaticFunctionTag*, RE::Actor* akCaster, RE::Actor* akTarget, bool abCanKill) {
            if (!akCaster || !akTarget) return;
            std::scoped_lock lk(g_mtx);
            const RE::FormID tid = akTarget->GetFormID();
            const auto now = std::chrono::steady_clock::now();
            auto it = g_active.find(tid);
            if (it != g_active.end()) {
                // 既存＝同じ対象への再適用です。lastDrainは保持して経過を積み上げます（1秒到達で吸います）。caster/canKillだけ更新します。
                //   lastSeen=今＝「まだこの対象にビームが当たってる」印＝Tickの離脱猶予がリセットされます。
                it->second.caster  = akCaster->GetFormID();
                it->second.canKill = abCanKill;
                it->second.lastSeen = now;
            } else {
                // 新規＝ビームがこの対象に乗りました。追加します（当てて+1秒で初回吸収・lastSeenも今）。
                //   対象の除去はTick側＝詠唱中の離脱(逸らし/薙ぎ払い)はBegin途絶stale／手下ろしはIsChargingDrainで即停止です。
                g_active[tid] = Entry{ akCaster->GetFormID(), abCanKill, now, now };
            }
        }
        void CombatDrainEnd(RE::StaticFunctionTag*, RE::Actor* akTarget) {
            // ★ここでは消しません。013622はインスタント再適用型でOnEffectFinishが毎サイクル鳴るので、ここで消すと1秒吸う前に
            //   消えて0ダメになります。対象の除去はTick側の2段に任せます。①手下ろし(IsChargingDrain false)で即全クリアします／
            //   ②詠唱中の離脱(逸らし/薙ぎ払い)はBeginの合図がkDrainStaleSec秒途絶えたらstaleで外します。引数は未使用です。
            (void)akTarget;
        }

    }

    // 📋 呪文DESC(〔アレテイア〕)用の公開wrapper＝Ravenous getter本体を呼びます（重複なし・NailDescから使用します）。
    float RavenousRangeM()  { return GetRavenousRange(nullptr); }
    int   RavenousMaxTgts() { return GetRavenousMaxTargets(nullptr); }

    // 🩸 ドレイン基礎量/秒＝2+(Lv-1)×8＝計算の定義は1か所です（重複なし）。
    //   ASTDrainScript.GetBaseDrainPerSec(MCM) と NailDesc(サキュバス・ドレイン/ラヴェナス・ドレインの威力DESC) が共用します。
    int DrainBaseNow() { return DrainBaseRaw(SuccubusLevel()); }
    // Papyrus窓口＝ASTR2Native.GetDrainBaseNow（ASTDrainScript.GetBaseDrainPerSec が呼び出します）。
    int Papyrus_GetDrainBaseNow(RE::StaticFunctionTag*) { return DrainBaseNow(); }

    // 💧 コンスーム・エッセンスの回復%/秒＝RegenPct×(1+(Lv-3)×0.05+Restoration/200+Hスキルcat1×0.05)＝計算の定義は1か所です。
    //   ASTDrainScript.GetRegenPctPerSec(MCM) と NailDesc(コンスーム・エッセンスDESC) が共用します。実挙動=ASTLifeForceDrainConc:44-45。
    //   ★ズレ解消：(b)Hスキルcat1項を表示に追加済です。(a)威力RegenPctは今3.0固定ですが実側はMCMスライダー
    //     ASTR2_ConsumeRegenPct(StorageUtil・既定3.0)＝〔SkyVault〕へ移設したら下の 3.0f を SVFloat に差し替えます(バッチ)。
    float RegenPctNow() {
        const int lv = SuccubusLevel();
        float resto = 0.0f;
        if (auto* pc = RE::PlayerCharacter::GetSingleton())
            if (auto* avo = pc->AsActorValueOwner())
                resto = avo->GetActorValue(RE::ActorValue::kRestoration);
        return 3.0f * (1.0f + (static_cast<float>(lv) - 3.0f) * 0.05f + resto / 200.0f
                       + static_cast<float>(TechRank::GetDisplayCatRank(1)) * 0.05f);
    }
    float Papyrus_GetRegenPctNow(RE::StaticFunctionTag*) { return RegenPctNow(); }

    // 🩸 サキュバス・ウィークネスの耐性ダウン実効値＝20(①ESP-20=全魔法共通フラット) ＋ added×手技(cat2)×変性(②ドレイン特化分だけスケールします)＝計算の定義は1か所です。
    //   added = min(cap, WeaknessBase + PerLv×(Lv-6)²)。DoCombatDrain(実挙動) と NailDesc(サキュバス・ウィークネスDESC) が共用します（表示と実挙動のズレ解消済みです）。
    int WeaknessResistDownNow() {
        const int lv = SuccubusLevel();
        int wsOver = lv - 6; if (wsOver < 0) wsOver = 0;
        float added = SVFloat("ASTR2_WeaknessBase", kWeaknessBaseDef)
                    + SVFloat("ASTR2_WeaknessPerLv", kWeaknessPerLvDef) * static_cast<float>(wsOver) * static_cast<float>(wsOver);
        const float cap = SVFloat("ASTR2_WeaknessCap", kWeaknessCapDef);
        if (added > cap) added = cap;
        const float techF = 1.0f + static_cast<float>(TechRank::GetDisplayCatRank(2)) * 0.05f;
        float altF = 1.0f;
        if (auto* pc = RE::PlayerCharacter::GetSingleton())
            if (auto* avo = pc->AsActorValueOwner())
                altF = 1.0f + avo->GetActorValue(RE::ActorValue::kAlteration) / 100.0f;
        // 🩸①ESP-20は全魔法共通のフラット（手技/変性なし）＋②added(ドレイン特化)だけ手技×変性でスケールします＝実挙動(DoCombatDrain)と一致です。
        return static_cast<int>(20.0f + added * techF * altF);
    }
    int Papyrus_GetWeaknessDownNow(RE::StaticFunctionTag*) { return WeaknessResistDownNow(); }

    // 💋 アラウジング・ラスト{1}のH中ドレイン素の威力＝実体はHDrain.cpp(HDrainOrgasmBaseNow)＝重複なしです。ここは登録窓口だけ相乗りします(#include HDrain.h)。
    int Papyrus_GetHDrainPerOrgasmNow(RE::StaticFunctionTag*) { return HDrain::HDrainOrgasmBaseNow(); }

    void Install() {
        g_api = OstimNG_API::Thread::GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        // 実時間チェッカ＝0.25s粒度で見て、各ターゲット1秒ごとに吸います（ゲームスレッド＝RE操作OK）。
        Chronos::RegisterRealtime("ASTR2CombatDrain", 0.25f, Tick);
        spdlog::info("[CombatDrain] realtime checker registered (g_api={})", (void*)g_api);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("CombatDrainBegin", "ASTR2Native", CombatDrainBegin);
        vm->RegisterFunction("CombatDrainEnd", "ASTR2Native", CombatDrainEnd);
        vm->RegisterFunction("GetRavenousRange", "ASTR2Native", GetRavenousRange);
        vm->RegisterFunction("GetRavenousMaxTargets", "ASTR2Native", GetRavenousMaxTargets);
        vm->RegisterFunction("GetDrainBaseNow", "ASTR2Native", Papyrus_GetDrainBaseNow);
        vm->RegisterFunction("GetRegenPctNow", "ASTR2Native", Papyrus_GetRegenPctNow);
        vm->RegisterFunction("GetWeaknessDownNow", "ASTR2Native", Papyrus_GetWeaknessDownNow);
        vm->RegisterFunction("GetHDrainPerOrgasmNow", "ASTR2Native", Papyrus_GetHDrainPerOrgasmNow);
        spdlog::info("[CombatDrain] Papyrus native CombatDrainBegin/End + Ravenous/DrainBase/Regen/WeaknessDown/HDrainOrgasm getter 登録");
        return true;
    }
}
