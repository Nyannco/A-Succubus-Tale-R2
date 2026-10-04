#include "PCH.h"
#include "HpBarHud.h"
#include "Chronos.h"
#include "HpBarFeed.h"
#include "SkyVaultAPI.h"
#include "DrainFloorDefaults.h"   // ドレインfloor既定の単一の正（HDrainと共用）
#include "RE/H/HUDMenu.h"   // HUDの親メニュー(uiMovie=Scaleform)＝TechHud/ScenePreparingと同じ入口です

#include <mutex>
#include <string>
#include <vector>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace HpBarHud
{
    namespace {
        constexpr const char* kJobName   = "HPバー更新";
        constexpr float       kEverySec  = 1.0f;    // 実時間1秒ごとです（旧Papyrus tickと同じテンポ）
        constexpr float       kEpsilon   = 0.005f;  // これ未満の%変化は投げません＝無駄なInvokeを削ります
        constexpr int         kMaxBars   = 4;

        // ドレイン下限（H中は殺さない下限）＝**〔SkyVault〕の単一の正から毎回読みます**。
        //   原本は `ASTDrainScript.FloorPctH / FloorAbs`（プロパティ）です。ここに数値をコピーすると、
        //     原本を調整した時にC++だけ黙って古い値で動きます（実際にズレたのを確認）。
        //   キーが未設定の間は既定値＝今までと同じ挙動なので、Papyrus側の裏打ち化を待たずに入れても安全です。
        using DrainFloor::kFloorPctHDef;   // DrainFloorDefaults.h の単一の正（HDrainと共用）
        using DrainFloor::kFloorAbsDef;

        inline float FloorPctH() {
            auto* v = SkyVaultAPI::GetSkyVaultAPI();
            return v ? v->GetFloat(0, "ASTR2_FloorPctH", kFloorPctHDef) : kFloorPctHDef;
        }
        inline float FloorAbs() {
            auto* v = SkyVaultAPI::GetSkyVaultAPI();
            return v ? v->GetFloat(0, "ASTR2_FloorAbs", kFloorAbsDef) : kFloorAbsDef;
        }

        std::mutex               g_mutex;
        std::vector<std::string> g_roots;                  // 各バーのWidgetRoot（Papyrusから受け取ります）
        float                    g_lastPct[kMaxBars]  = { -1.0f, -1.0f, -1.0f, -1.0f };
        bool                     g_wasFloor[kMaxBars] = { false, false, false, false };
        bool                     g_bound = false;

        inline float CurHP(RE::Actor* a) {
            return a->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth);
        }
        // 表示用の最大HP = 現在HP - ダメージ修飾(≤0)＝**fortify込みの実効最大**です。
        //   旧Papyrusの `GetActorValuePercentage("Health")` と同じ見え方＝バーの%を変えないためこちらを使います
        //   （オーガズムバフの「Health最大+」等が乗ってる相手でもバーが100%超えに見えません）。
        //   `GetActorValueModifier` は ActorValueOwner でなく **Actor** のメンバーです（このCommonLib・FinisherEvalと同形）。
        inline float MaxHPForBar(RE::Actor* a) {
            auto* o = a->AsActorValueOwner();
            const float dmg = a->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth);
            return o->GetActorValue(RE::ActorValue::kHealth) - dmg;
        }
        // 下限フラッシュ用の最大HP＝**HDrainと同じ読み方**(GetPermanentActorValue)です。
        //   ここを揃えないと「ドレインが止まる高さ」と「バーが光る高さ」がズレます（HDrain側が
        //     ダメージ修飾からの逆算→GetPermanentActorValueへ変わったので、こちらも合わせます）。
        inline float MaxHPForFloor(RE::Actor* a) {
            return a->AsActorValueOwner()->GetPermanentActorValue(RE::ActorValue::kHealth);
        }

        // ウィジェットへ1本投げます（HUD Menu の Scaleform を直接叩きます）。
        void InvokePercent(RE::GFxMovieView* a_mv, const std::string& a_root, float a_pct) {
            RE::GFxValue args[2];
            args[0].SetNumber(a_pct);
            args[1].SetBoolean(false);   // 第2引数=即スナップしません（Papyrus SetPercent と同じ渡し方）
            a_mv->Invoke((a_root + ".setPercent").c_str(), nullptr, args, 2);
        }

        // 🔆 フラッシュは**2段**＝色をセットしてから発火します（custommeter.swfの作り・Papyrus StartFlashと同じ手順）。
        //   1回で `startFlash(色)` と呼ぶと色が渡らず、バーの基本色(赤)で光ります（実機で確認）。
        //     startFlashの引数は**Bool**＝「既に点滅中でも強制再発火」です。
        void InvokeFlash(RE::GFxMovieView* a_mv, const std::string& a_root, std::uint32_t a_color) {
            RE::GFxValue col;
            col.SetNumber(static_cast<double>(a_color));
            a_mv->Invoke((a_root + ".setFlashColor").c_str(), nullptr, &col, 1);
            RE::GFxValue force;
            force.SetBoolean(true);
            a_mv->Invoke((a_root + ".startFlash").c_str(), nullptr, &force, 1);
        }

        // 毎秒の更新本体です（ゲームスレッド＝〔クロノス〕のAddTask内）。
        void Update() {
            std::lock_guard<std::mutex> lock(g_mutex);
            if (!g_bound || g_roots.empty()) return;

            auto* ui = RE::UI::GetSingleton();
            auto  hud = ui ? ui->GetMenu<RE::HUDMenu>() : nullptr;
            if (!hud || !hud->uiMovie) return;
            auto& mv = hud->uiMovie;

            const std::vector<RE::FormID> npcs = HpBarFeed::SceneNpcs();

            for (int i = 0; i < kMaxBars && i < static_cast<int>(g_roots.size()); ++i) {
                if (g_roots[i].empty()) continue;
                if (i >= static_cast<int>(npcs.size())) {       // 参加者が減った枠は触りません
                    g_lastPct[i] = -1.0f;
                    g_wasFloor[i] = false;
                    continue;
                }
                auto* npc = RE::TESForm::LookupByID<RE::Actor>(npcs[i]);
                if (!npc) {
                    g_lastPct[i] = -1.0f;
                    continue;
                }
                const float maxHP = MaxHPForBar(npc);
                if (maxHP <= 0.0f) continue;
                const float cur = CurHP(npc);
                float pct = cur / maxHP;
                if (pct < 0.0f) pct = 0.0f;
                if (pct > 1.0f) pct = 1.0f;

                // 🔆 ドレイン下限に「到達した瞬間」だけ白フラッシュします（張り付いてる間は光らせ続けません）。
                float floorHP = MaxHPForFloor(npc) * FloorPctH();
                const float floorAbs = FloorAbs();
                if (floorHP < floorAbs) floorHP = floorAbs;
                const bool atFloor = (cur <= floorHP + 0.5f);
                const bool flashNow = atFloor && !g_wasFloor[i];
                g_wasFloor[i] = atFloor;

                if (g_lastPct[i] < 0.0f || std::abs(pct - g_lastPct[i]) >= kEpsilon) {
                    InvokePercent(mv.get(), g_roots[i], pct);
                    g_lastPct[i] = pct;
                }
                if (flashNow) {
                    InvokeFlash(mv.get(), g_roots[i], 0xFFFFFF);
                }
            }
        }

        // ---- Papyrus ネイティブ ----
        //   シーン開始時に4本のWidgetRootを渡してもらいます＝以後の毎秒更新はC++が回します。
        void Papyrus_HpBarBind(RE::StaticFunctionTag*, std::vector<RE::BSFixedString> a_roots) {
            std::lock_guard<std::mutex> lock(g_mutex);
            g_roots.clear();
            for (const auto& r : a_roots) {
                g_roots.emplace_back(r.c_str() ? r.c_str() : "");
            }
            for (int i = 0; i < kMaxBars; ++i) {
                g_lastPct[i] = -1.0f;
                g_wasFloor[i] = false;
            }
            g_bound = !g_roots.empty();
            spdlog::info("[HpBarHud] bind {}本＝以後の毎秒更新はC++", g_roots.size());
        }

        void Papyrus_HpBarUnbind(RE::StaticFunctionTag*) {
            std::lock_guard<std::mutex> lock(g_mutex);
            g_bound = false;
            spdlog::info("[HpBarHud] unbind（シーン終了）");
        }
    }

    void Install() {
        Chronos::RegisterRealtime(kJobName, kEverySec, []() { Update(); });
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("HpBarBind", "ASTR2Native", Papyrus_HpBarBind);
        a_vm->RegisterFunction("HpBarUnbind", "ASTR2Native", Papyrus_HpBarUnbind);
        spdlog::info("[HpBarHud] Papyrus natives (HpBarBind/HpBarUnbind) 登録");
        return true;
    }
}
