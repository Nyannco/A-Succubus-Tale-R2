#include "PCH.h"
#include "ManaCost.h"
#include "SkyVaultAPI.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <MinHook.h>

// ============================================================================
//  魔法マジカコスト＝ランク式の実体です。詳細は ManaCost.h。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   コスト計算・〔門番〕・消費・バニラ減の測定をここに集約します（定義は1か所）。
//   各魔法のコードは「起点で ComputeReduction を1回→以降 TrySpend にキャッシュ減率」で呼び出します。
// ============================================================================

namespace ManaCost {
    namespace {
        constexpr const char* kEsp           = "A Succubus Tale R2.esp";

        // ---- 式の固定土台（MCMで動かさない基準です。可変は①②③の3スライダーのみ）----
        constexpr float kBaseSec     = 20.0f;    // 毎秒系の基準です（Lv1-10・ランク1で 20/秒）
        constexpr float kSpeechPerPt = 0.001f;   // スピーチ1ptで0.1%減ります（スキル1000で100%・最終は②capで頭打ち）

        // ---- 〔SkyVault〕短縮（既存流儀・EssenceFlow.cpp と同型）----
        inline float SVFloat(const char* k, float d) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetFloat(0, k, d);
            return d;
        }

        // サキュバスLvです（TESGlobal・既存 SuccubusLevel と同じ）
        int SuccubusLevel() { return std::max(1, SuccLevel::Raw(1)); }

        // 段階です（Lv10ごと・0〜9）。Lv100超も9で頭打ちです（式の暴走防止）。
        int Stage(int lv) {
            int s = (lv - 1) / 10;
            if (s < 0) s = 0;
            if (s > 9) s = 9;
            return s;
        }

        // ---- MCMスライダー3値（規定値） ----
        float StepMul()  { return SVFloat("ASTR2_ManaCostStepMul",  1.67f);  }  // ①段階係数 1〜3
        float CapPct()   { return SVFloat("ASTR2_ManaCostCapPct",   100.0f); }  // ②カット上限 0〜100(%)
        float BurstMul() { return SVFloat("ASTR2_ManaCostBurstMul", 2.0f);   }  // ③発動倍率 1〜10（既定2＝costTierで散らす分、旧5から下げました／MCMで調整できます）

        // 素コスト（減算前）＝基準 × ①^ステージ × costUnit（costUnit＝裏ランクで散らした係数。DetourCalc/CostTierFor参照）
        float BaseCost(int costUnit) {
            const int   lv   = SuccubusLevel();
            const float step = std::pow(StepMul(), static_cast<float>(Stage(lv)));
            return kBaseSec * step * static_cast<float>(costUnit);
        }

        // 消費実行します（〔門番〕＋DamageActorValue）。足りれば消費して true を返します。
        bool TrySpend(RE::Actor* caster, float cost) {
            if (!caster)      return false;
            if (cost <= 0.0f) return true;     // 0コストは常に通します
            auto* avo = caster->AsActorValueOwner();
            if (!avo) return false;
            const float cur = avo->GetActorValue(RE::ActorValue::kMagicka);
            if (cur < cost) {
                spdlog::info("[ManaCost] spend cost={:.1f} cur={:.1f} → 不足（不発/中断）", cost, cur);
                return false;      // 不足＝不発です（呼び元がその魔法を中断します）
            }
            avo->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kMagicka, -cost);
            return true;   // ★毎tickの「OK消費」ログは削除します(スパム対策)。不足時だけ上でログを出します。
        }
    }

    // ★減率＝スピーチだけ（半額perk/Fortify/エンチャント＝バニラ減は除外＝tierと二重になりません）。
    //   ※物差し系(VanillaReduce/ProbeSpell/kProbe)は撤去済＝物差しESP6本もESP側で削除が必要です(手作業)。
    float ComputeReduction(RE::Actor* caster, SpellKind kind, bool quiet) {
        float speechReduce = 0.0f;
        if (caster) {
            if (auto* avo = caster->AsActorValueOwner()) {
                const float sp = avo->GetActorValue(RE::ActorValue::kSpeech);
                speechReduce = (sp > 0.0f ? sp : 0.0f) * kSpeechPerPt;   // 上限はありません
            }
        }
        const float cap = CapPct() / 100.0f;
        float r = speechReduce;
        if (r > cap)  r = cap;                    // ②で頭打ちです
        if (r < 0.0f) r = 0.0f;
        if (r > 1.0f) r = 1.0f;
        if (!quiet) spdlog::info("[ManaCost] reduce kind={} speech={:.3f} cap={:.2f} → final減率{:.3f}", static_cast<int>(kind), speechReduce, cap, r);
        return r;
    }

    float ComputePerSec(int costUnit) { return BaseCost(costUnit); }
    float ComputeBurst(int costUnit)  { return BaseCost(costUnit) * BurstMul(); }

    // ★毎tick/発動＝軽い側です（キャッシュ済み reduction・掛け算とマジカチェックのみ）。costUnit＝costTier。
    bool TrySpendPerSec(RE::Actor* caster, int costUnit, float reduction) {
        const float cost = BaseCost(costUnit) * (1.0f - reduction);
        return TrySpend(caster, cost);
    }

    // ============================================================================
    //  ★コスト列フック（A案）＝詳細は ManaCost.h。
    //   MagicItem::CalculateMagickaCost(11213) を対象6呪文だけ横取り→独自の計算値を返します
    //   ＝魔法メニューのコスト列/カードに実コストが出る＋バニラが詠唱時にその値で消費します。
    //   ・対象判定＝起動時に解決した6呪文のフォームポインタと一致比較します（物差しSPELは別FormIDですので再帰しません）。
    //   ・減率は高頻度呼び出しですので時間キャッシュ(~1秒)＋quietでログ抑制します（毎回物差し測定しません＝軽量です）。
    //   ・毎秒系(Drain/Consume/Ravenous)=ComputePerSec／発動系(Lust/Nightmare/Weakness)=ComputeBurst。
    //     DrainのみランクがサキュバスLv連動します。Ravenousは毎秒消費自体はC++(CombatDrain)維持＝ここは列表示用です。
    // ============================================================================
    namespace {
        struct CostSlot { RE::MagicItem* form; RE::EffectSetting* mgef; SpellKind kind; int rank; bool perSec; RE::ActorValue school; };  // mgef=表示レベル書換用／rank=裏ランク(tierの上限)
        CostSlot g_slots[6]  = {};
        int      g_slotCount = 0;

        // 学派スキル値→バニラのマスタリ段階です（素人1=0〜24 / 見習い2=25〜49 / 一人前3=50〜74 / 熟練者4=75〜99 / 達人5=100〜）。
        int MasteryTier(float skill) {
            int t = 1 + static_cast<int>(skill / 25.0f);
            if (t < 1) t = 1;
            if (t > 5) t = 5;
            return t;
        }

        // 減率キャッシュ（kind別・~1秒更新）＝CalculateMagickaCostは高頻度ですので毎回物差しを測りません。
        float                                 g_redCache[6] = {};
        std::chrono::steady_clock::time_point g_redAt[6]    = {};

        float CachedReduction(RE::Actor* caster, SpellKind kind) {
            const int k = static_cast<int>(kind);
            if (k < 0 || k > 5) return 0.0f;
            const auto now = std::chrono::steady_clock::now();
            if (g_redAt[k].time_since_epoch().count() == 0 ||
                std::chrono::duration_cast<std::chrono::milliseconds>(now - g_redAt[k]).count() > 1000) {
                g_redCache[k] = ComputeReduction(caster, kind, /*quiet=*/true);
                g_redAt[k]    = now;
            }
            return g_redCache[k];
        }

        using CalcCost_t = float (*)(RE::MagicItem*, RE::Actor*);
        CalcCost_t g_origCalc = nullptr;

        float DetourCalc(RE::MagicItem* a_this, RE::Actor* a_caster) {
            const float base = g_origCalc(a_this, a_caster);   // 元の値です（対象外はそのまま返します）
            for (int i = 0; i < g_slotCount; ++i) {
                if (g_slots[i].form == a_this) {
                    const auto& s = g_slots[i];
                    RE::Actor* c = a_caster ? a_caster : RE::PlayerCharacter::GetSingleton();
                    // ★裏ランク＝2役：① 同じ式でコストを散らします ② 表示レベル(素人〜達人)の頭打ちです。
                    //   dispTier＝表示レベル＝min(学派mastery, rank)でキャップ（②）。
                    //   costTier＝rank+(dispTier-1)＝rankで基準を散らし＋スキルで上乗せ（①）。
                    //   ※旧実装は②しか入れていませんでした＝学派が低い呪文が全部tier1に潰れて142衝突します。これで裏ランク差がコストに出ます。
                    float skill = 0.0f;
                    if (c) { if (auto* avo = c->AsActorValueOwner()) skill = avo->GetActorValue(s.school); }
                    const int   mastery  = MasteryTier(skill);
                    const int   dispTier = std::min(mastery, s.rank);        // ② 表示レベル＝rankで頭打ち
                    const int   costTier = s.rank + (dispTier - 1);          // ① rankで散らす＋スキル上乗せ
                    // 🔵 表示レベル＝MGEFのminimumSkillをdispTierのしきい値(0/25/50/75/100)へ書きます。dispTierは実スキル以下ですので詠唱の妨げになりません。
                    if (s.mgef && c == RE::PlayerCharacter::GetSingleton()) s.mgef->data.minimumSkill = (dispTier - 1) * 25;   // 表示はプレイヤー基準の時だけ更新します（NPC詠唱で揺れません）
                    const float raw  = s.perSec ? ComputePerSec(costTier) : ComputeBurst(costTier);   // 20×①^stage×costTier（発動は×③）
                    float cost = raw * (1.0f - CachedReduction(c, s.kind));
                    if (cost < 0.0f) cost = 0.0f;
#ifndef NDEBUG
                    // 🔍[DIAG]コスト確認＝skill変化時だけログを出します（スパム防止）。Debug専用＝Releaseでは除外。
                    static float s_lastLoggedSkill[6] = { -1.0f, -1.0f, -1.0f, -1.0f, -1.0f, -1.0f };
                    if (i >= 0 && i < 6 && std::fabs(skill - s_lastLoggedSkill[i]) > 0.5f) {
                        s_lastLoggedSkill[i] = skill;
                        spdlog::info("[ManaCost-DIAG] slot{} kind={} school(AV)={} skill={:.1f} mastery={} rank={} dispTier={} costTier={} perSec={} raw={:.1f} cost={:.1f}",
                                     i, static_cast<int>(s.kind), static_cast<int>(s.school), skill, mastery, s.rank, dispTier, costTier, s.perSec, raw, cost);
                    }
#endif
                    return cost;
                }
            }
            return base;
        }

        // ★Ravenous /sメニュー連動：魔法メニューのコスト列の「/s(毎秒)」は、呪文の chargeTime==0 の時だけ付きます。
        //   Ravenousは発動の溜めアニメ用に chargeTime=60 を保持したい（ESPで0にできません）ので、
        //   魔法メニューを開いてる間だけ GetChargeTime() が 0 を返すようフックします（→UIが/sを付けます）。
        //   発動は必ずメニューを閉じた後ですので本来の60が返ります＝溜めアニメは常に正常です。
        //   ★なぜ data.chargeTime直書きでなくvtableフックか：エンジンが/s判定で読むのは GetChargeTime()
        //     (vtable 0x64・単純returnではありません)で、data.chargeTime メンバ値と一致しません＝メンバに書いても効かないためです。
        //     （CommonLibの data.* 直書きがエンジン値に当たらない時の対処＝ゲッター自体をフックします）
        RE::SpellItem* g_ravenousSpell = nullptr;   // Ravenous呪文です（InstallCostHookで解決します）
        bool           g_magicMenuOpen = false;     // 魔法メニューが開いてる間だけtrue です（GetChargeTimeフックが見ます）

        // GetChargeTime(0x64) vtableフック＝SpellItem共通vtableを差し替え、中でRavenous×メニュー開の時だけ0を返します。
        using GetChargeTime_t = float (*)(RE::SpellItem*);
        GetChargeTime_t g_origGetChargeTime = nullptr;
        float GetChargeTime_Hook(RE::SpellItem* a_this) {
            if (a_this == g_ravenousSpell && g_magicMenuOpen) return 0.0f;
            return g_origGetChargeTime(a_this);
        }

        class RavenousMenuSink : public RE::BSTEventSink<RE::MenuOpenCloseEvent> {
        public:
            static RavenousMenuSink* GetSingleton() { static RavenousMenuSink s; return &s; }
            RE::BSEventNotifyControl ProcessEvent(const RE::MenuOpenCloseEvent*               a_event,
                                                  RE::BSTEventSource<RE::MenuOpenCloseEvent>*) override {
                if (a_event && g_ravenousSpell && a_event->menuName == RE::MagicMenu::MENU_NAME) {
                    g_magicMenuOpen = a_event->opening;   // 開=true(→/s)／閉=false(→本来60で溜めアニメ)
                }
                return RE::BSEventNotifyControl::kContinue;
            }
        };
    }

    // ★指定呪文の costTier を計算します（表示DetourCalcとRavenous実消費CombatDrainで共用＝定義は1か所です）。
    //   costTier = 裏ランク + (dispTier-1)／dispTier = min(学派mastery, rank)。スロット未解決(起動前)は1です。
    int CostTierFor(RE::Actor* caster, SpellKind kind) {
        for (int i = 0; i < g_slotCount; ++i) {
            if (g_slots[i].kind == kind) {
                const auto& s = g_slots[i];
                float skill = 0.0f;
                if (caster) { if (auto* avo = caster->AsActorValueOwner()) skill = avo->GetActorValue(s.school); }
                const int dispTier = std::min(MasteryTier(skill), s.rank);
                return s.rank + (dispTier - 1);
            }
        }
        return 1;
    }

    void InstallCostHook() {
        auto* dh = RE::TESDataHandler::GetSingleton();
        if (!dh) { spdlog::error("[ManaCost] InstallCostHook: TESDataHandler無"); return; }

        struct Def { RE::FormID id; RE::FormID mgefId; SpellKind kind; int rank; bool perSec; RE::ActorValue school; };
        const Def defs[6] = {
            { 0x007924, 0x013622, SpellKind::kDrain,     5, true,  RE::ActorValue::kDestruction },  // サキュバス・ドレイン（破壊・cap5）
            { 0x00B4A6, 0x00B4A5, SpellKind::kLust,      2, false, RE::ActorValue::kIllusion    },  // アラウジング・ラスト（幻惑・cap2）
            { 0x01BCE9, 0x01BCEA, SpellKind::kNightmare, 3, false, RE::ActorValue::kIllusion    },  // ナイトメア・エンブレイス（幻惑・cap3）
            { 0x00BA0F, 0x00B4AE, SpellKind::kConsume,   4, true,  RE::ActorValue::kRestoration },  // コンスーム・エッセンス（回復・cap4）
            { 0x005E37, 0x005E36, SpellKind::kWeakness,  4, false, RE::ActorValue::kAlteration  },  // サキュバス・ウィークネス（変性・cap4）
            { 0x020881, 0x020882, SpellKind::kRavenous,  5, true,  RE::ActorValue::kDestruction },  // ラヴェナス・ドレイン（破壊・cap5／毎秒はC++管理）
        };
        g_slotCount = 0;
        for (const auto& d : defs) {
            if (auto* sp = dh->LookupForm<RE::SpellItem>(d.id, kEsp)) {
                auto* mg = dh->LookupForm<RE::EffectSetting>(d.mgefId, kEsp);   // 表示レベル書換用の主効果MGEFです
                g_slots[g_slotCount++] = { static_cast<RE::MagicItem*>(sp), mg, d.kind, d.rank, d.perSec, d.school };
                if (d.kind == SpellKind::kRavenous) g_ravenousSpell = sp;   // ★GetChargeTimeフック対象です（/sメニュー連動）
#ifndef NDEBUG
                // 🔍[DIAG]/s逆転追跡＝実機の各呪文castType/chargeTimeを起動時に1回だけ吐きます（YAMLとの差を確定します）。Debug専用＝Releaseでは除外。
                spdlog::info("[ManaCost-DIAG] load {:08X} kind={} castType={} chargeTime={:.2f} perSecFlag={}",
                             d.id, static_cast<int>(d.kind), static_cast<int>(sp->GetCastingType()), sp->GetChargeTime(), d.perSec);
#endif
            }
        }

        REL::Relocation<std::uintptr_t> target{ RELOCATION_ID(11213, 11321) };   // MagicItem::CalculateMagickaCost
        void* tgt = reinterpret_cast<void*>(target.address());
        const auto init = MH_Initialize();
        if (init != MH_OK && init != MH_ERROR_ALREADY_INITIALIZED) {
            spdlog::error("[ManaCost] MH_Initialize failed ({})", static_cast<int>(init));
            return;
        }
        if (MH_CreateHook(tgt, reinterpret_cast<void*>(&DetourCalc), reinterpret_cast<void**>(&g_origCalc)) != MH_OK) {
            spdlog::error("[ManaCost] CalculateMagickaCost CreateHook failed");
            return;
        }
        if (MH_EnableHook(tgt) != MH_OK) {
            spdlog::error("[ManaCost] CalculateMagickaCost EnableHook failed");
            return;
        }
        spdlog::info("[ManaCost] CalculateMagickaCost フック設置（対象{}呪文＝コスト列に実コスト表示）", g_slotCount);

        // ★Ravenous /sメニュー連動＝GetChargeTime(0x64)をRavだけフック＋メニュー開閉で旗ON/OFF。
        if (g_ravenousSpell) {
            // GetChargeTime vtableフック設置します（SpellItem共通vtable・中でRavenousだけ判定して0を返します）
            REL::Relocation<std::uintptr_t> vtbl{ RE::SpellItem::VTABLE[0] };
            g_origGetChargeTime = reinterpret_cast<GetChargeTime_t>(vtbl.write_vfunc(0x64, &GetChargeTime_Hook));
            spdlog::info("[ManaCost] Ravenous GetChargeTimeフック設置（本来値{:.2f}・メニュー開の間だけ0返す）",
                         g_origGetChargeTime(g_ravenousSpell));
            if (auto* ui = RE::UI::GetSingleton()) {
                ui->AddEventSink<RE::MenuOpenCloseEvent>(RavenousMenuSink::GetSingleton());
                spdlog::info("[ManaCost] Ravenous /sメニュー連動Sink登録");
            } else {
                spdlog::error("[ManaCost] Ravenous Sink登録失敗：UI無");
            }
        }
    }

}
