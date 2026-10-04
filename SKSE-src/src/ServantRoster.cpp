#include "PCH.h"
#include "ServantRoster.h"
#include "ServantTier.h"     // tier = faction rank（C++直読み・Papyrus GetTier相当）
#include "SkyVaultAPI.h"     // 名簿(List)＋点数(Float)の外部データ庫（C++が直読み）

#include <array>
#include <vector>
#include <string>
#include <mutex>
#include <algorithm>

// ============================================================================
// MCMサーヴァント一覧の列挙をC++化します。旧MCMはティアごとに Count/Names/Actors を
//   毎回呼び名簿を最大12回フル走査＋1人ずつ GetFormFromFile/配列成長でO(N²)＝人数の二乗で激重でした。
//   →ここで〔SkyVault〕名簿を1パス走査してtier別にキャッシュ＝MCMは BuildRoster()1回＋getterで即取得します。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace {
    constexpr std::uint32_t kHolder = 0;                 // 名簿＝global名前空間（Papyrus SkyVault.List*(None,...) と一致）
    constexpr const char*   kListKey   = "ASTR2_ServantList";
    constexpr const char*   kPointsKey = "ASTR2_SvPoints";

    // 〔SkyVault〕を取得します（TechRankと同じ手・1回取ってキャッシュ／不在ならnullptr＝空扱い）。
    SkyVaultAPI::IVault* GetVault() {
        static SkyVaultAPI::IVault* v = nullptr;
        if (!v) v = SkyVaultAPI::GetSkyVaultAPI();
        return v;
    }

    // 各ティアの下限しきい値です（Papyrus ASTR2Servantship.TierThreshold と1:1）。
    float tierThreshold(int tier) {
        if (tier >= 4) return 180.0f;
        if (tier == 3) return 90.0f;
        if (tier == 2) return 40.0f;
        if (tier == 1) return 12.0f;
        return 0.0f;
    }
    // 進捗文字列 "T.ff" です（Papyrus ProgressString と1:1・ff=次ティアへの進捗%00〜99／愛玩4は"4.00"）。
    std::string progressString(int tier, float points) {
        if (tier >= 4) return "4.00";
        const float lo = tierThreshold(tier);
        const float hi = tierThreshold(tier + 1);
        int ff = 0;
        if (hi > lo) ff = static_cast<int>(((points - lo) / (hi - lo)) * 100.0f);
        if (ff < 0) ff = 0; else if (ff > 99) ff = 99;   // 次しきい値到達分は99で止めます（昇格は別処理）
        std::string s = std::to_string(tier) + ".";
        if (ff < 10) s += "0";
        s += std::to_string(ff);
        return s;
    }

    // ---- キャッシュ（BuildRosterで作りgetterが読む・全部Papyrus VMスレッド上so軽いが念のためmutex）----
    std::mutex g_mutex;
    struct TierCache {
        std::vector<RE::BSFixedString> rows;    // "名前   T.ff"
        std::vector<RE::Actor*>        actors;  // 同順です（個別リセットの行↔Actor対応）
    };
    std::array<TierCache, 5> g_cache;           // index = tier 0..4（0=獲物は一覧に出しませんが枠だけ確保します）

    // ===================== Papyrus native（ASTR2Servantship.*）=====================
    // ★1パス列挙：〔SkyVault〕名簿を全走査→生存&tier1-4をtier別に仕分け＋進捗/名前を計算してキャッシュします。
    void Papyrus_BuildRoster(RE::StaticFunctionTag*) {
        std::lock_guard<std::mutex> lk(g_mutex);
        for (auto& c : g_cache) { c.rows.clear(); c.actors.clear(); }
        auto* v = GetVault();
        if (!v) return;
        const int n = v->ListCount(kHolder, kListKey);
        for (int i = 0; i < n; ++i) {
            const std::uint32_t fid = v->ListGet(kHolder, kListKey, i);
            if (fid == 0) continue;
            auto* form = RE::TESForm::LookupByID(fid);
            if (!form) continue;
            auto* actor = form->As<RE::Actor>();
            if (!actor || actor->IsDead()) continue;
            const int tier = ServantTier::Get(actor);
            if (tier < 1 || tier > 4) continue;                       // tier0(獲物)は一覧に表示しません
            const float pts = v->GetFloat(fid, kPointsKey, 0.0f);
            std::string row = std::string(actor->GetDisplayFullName()) + "   " + progressString(tier, pts);
            g_cache[tier].rows.push_back(RE::BSFixedString(row.c_str()));
            g_cache[tier].actors.push_back(actor);
        }
    }

    // ティアの表示行 "名前   T.ff" です（capN件・maxCount<=0で全部）。★BuildRoster後に読みます。
    std::vector<RE::BSFixedString> Papyrus_GetRosterRows(RE::StaticFunctionTag*, std::int32_t tier, std::int32_t maxCount) {
        std::lock_guard<std::mutex> lk(g_mutex);
        std::vector<RE::BSFixedString> out;
        if (tier < 0 || tier > 4) return out;
        const auto& rows = g_cache[tier].rows;
        const int lim = (maxCount <= 0) ? static_cast<int>(rows.size())
                                        : std::min<int>(static_cast<int>(rows.size()), maxCount);
        for (int i = 0; i < lim; ++i) out.push_back(rows[i]);
        return out;
    }
    // ティアのActorです（rowsと同順・cap一致＝個別リセットの行↔Actor紐付け）。
    std::vector<RE::Actor*> Papyrus_GetRosterActors(RE::StaticFunctionTag*, std::int32_t tier, std::int32_t maxCount) {
        std::lock_guard<std::mutex> lk(g_mutex);
        std::vector<RE::Actor*> out;
        if (tier < 0 || tier > 4) return out;
        const auto& acts = g_cache[tier].actors;
        const int lim = (maxCount <= 0) ? static_cast<int>(acts.size())
                                        : std::min<int>(static_cast<int>(acts.size()), maxCount);
        for (int i = 0; i < lim; ++i) out.push_back(acts[i]);
        return out;
    }
    // ティアの生存サーヴァント総数です（cap無視＝「N人中M表示」の真の総数）。
    std::int32_t Papyrus_GetRosterCount(RE::StaticFunctionTag*, std::int32_t tier) {
        std::lock_guard<std::mutex> lk(g_mutex);
        if (tier < 0 || tier > 4) return 0;
        return static_cast<std::int32_t>(g_cache[tier].rows.size());
    }
}

namespace ServantRoster {
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("BuildRoster", "ASTR2Servantship", Papyrus_BuildRoster);
        vm->RegisterFunction("GetRosterRows", "ASTR2Servantship", Papyrus_GetRosterRows);
        vm->RegisterFunction("GetRosterActors", "ASTR2Servantship", Papyrus_GetRosterActors);
        vm->RegisterFunction("GetRosterCount", "ASTR2Servantship", Papyrus_GetRosterCount);
        spdlog::info("[ServantRoster] Papyrus roster natives registered.");
        return true;
    }
}
