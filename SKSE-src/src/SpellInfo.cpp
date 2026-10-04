#include "PCH.h"
#include "SpellInfo.h"
#include "SkyVaultAPI.h"
#include "TechRank.h"

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace SpellInfo {
    namespace {
        inline float SVFloat(const char* key, float def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetFloat(0, key, def);
            return def;
        }
        inline int SVInt(const char* key, int def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
            return def;
        }

        int SuccubusLevel() { return std::clamp(SuccLevel::Raw(1), 1, 100); }
    }

    // 🌙 ナイトメア・エンブレイスの成功確率の"素のbase"(対象なし＝興奮/tierボーナス抜き・tech倍率も掛ける前)＝計算の単一の正です。
    //   ＝nmBase+(Lv-1)×nmPerLv。実挙動(ASTR2NightmareEffect OnEffectStart)もMCM表示もDESCも全部これを呼びます＝psc側の式再掲を撤去しました。
    //   nmBase/nmPerLv は StorageUtil→〔SkyVault〕 へ移設済みです（MCMスライダー/Save-Load/この計算で共有）。
    float NightmareBaseNow() {
        const int   lv      = SuccubusLevel();
        const float nmBase  = SVFloat("ASTR2_NightmareBaseChance", 10.0f);
        const float nmPerLv = SVFloat("ASTR2_NightmareChancePerLv", 8.0f);
        return nmBase + static_cast<float>(lv - 1) * nmPerLv;
    }
    // 🌙 表示用の成功確率＝base×腰使いcat0(+5%/rank)・cap100です。
    //   実挙動はbase+興奮/tierボーナスにtechを掛けます(対象依存)ので表示とは差が出ます＝表示は「対象文脈なしの代表値」です(仕様)。
    int NightmareChanceNow() {
        const float c = NightmareBaseNow()
                        * (1.0f + static_cast<float>(TechRank::GetDisplayCatRank(0)) * 0.05f);
        const int chance = static_cast<int>(c);
        return chance > 100 ? 100 : chance;
    }
    float Papyrus_GetNightmareBaseNow(RE::StaticFunctionTag*) { return NightmareBaseNow(); }
    int   Papyrus_GetNightmareChanceNow(RE::StaticFunctionTag*) { return NightmareChanceNow(); }

    // 🩷 セダクション3種(ウィスパー・セダクション/エリア・セダクション/マス・セダクション)の基本スパイク量＝計算の単一の正です。
    //   ASTSedMagEffScript.GetBaseSeductionSpike(MCM/実挙動) と NailDesc(DESC) が共用します。base/stepはStorageUtil→〔SkyVault〕へ移設しました。
    //   攻め技rankは GetTechRankCpp(6)＝psc GetTechRank(6) と同値です(GetDisplayCatRankとは別物なので注意してください)。
    float SeductionSpikeNow() {
        const int   lv   = SuccubusLevel();
        const float base = SVFloat("ASTR2_SedBase", 50.0f);
        const float step = SVFloat("ASTR2_SedStep", 5.0f);
        const float raw  = base + static_cast<float>(lv - 1) * step;
        return raw * (1.0f + static_cast<float>(TechRank::GetTechRankCpp(6)) * 0.05f);
    }
    float Papyrus_GetSeductionSpikeNow(RE::StaticFunctionTag*) { return SeductionSpikeNow(); }

    // 💋 アラウジング・ラストの興奮注入(素・LF比率/Hスキル倍率抜き)＝LustBase×Lv＝計算の単一の正です。
    //   ASTLustEffect.GetBaseLustArousal(MCM) と NailDesc(DESC) が共用します。LustBaseはStorageUtil→〔SkyVault〕へ移設しました。
    int LustArousalNow() {
        const int lv   = SuccubusLevel();
        const int base = SVInt("ASTR2_LustBase", 10);
        return base * lv;
    }
    int Papyrus_GetLustArousalNow(RE::StaticFunctionTag*) { return LustArousalNow(); }

    // 🍯 ディスティル・エッセンス(Distill)のサイズ別コスト＝計算の単一の正です。size 0=Petty 1=Lesser 2=Common 3=Greater 4=Grand。
    //   psc(ASTR2DistillEssenceEffectの支払い)もC++ DESC(NailDesc)もこれを呼びます＝旧Autoプロパティ+ハードコピーを撤去しました。シャードより重めです(ストック桁違いなので)。
    int DistillLifeCost(int size) {
        static const int lf[5] = { 500, 1500, 5000, 15000, 50000 };
        return (size >= 0 && size < 5) ? lf[size] : 0;
    }
    int DistillManaCost(int size) {
        static const int mana[5] = { 100, 200, 400, 800, 1600 };
        return (size >= 0 && size < 5) ? mana[size] : 0;
    }
    int Papyrus_GetDistillLifeCost(RE::StaticFunctionTag*, int size) { return DistillLifeCost(size); }
    int Papyrus_GetDistillManaCost(RE::StaticFunctionTag*, int size) { return DistillManaCost(size); }

    // 💎 クリエイト・シャード(Shard)のサイズ別"素"淫魔力コスト＝計算の単一の正です。size 0=Petty..4=Grand。
    //   psc(支払い/GetShardCost)もC++ DESCもこれを呼びます＝旧リテラル3箇所を撤去しました。実支払いは別途 ShardCostMult を掛けます(ここは素です)。
    int ShardLifeCost(int size) {
        static const int lf[5] = { 400, 600, 1000, 1400, 2000 };
        return (size >= 0 && size < 5) ? lf[size] : 0;
    }
    int Papyrus_GetShardLifeCost(RE::StaticFunctionTag*, int size) { return ShardLifeCost(size); }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetNightmareBaseNow", "ASTR2Native", Papyrus_GetNightmareBaseNow);
        vm->RegisterFunction("GetNightmareChanceNow", "ASTR2Native", Papyrus_GetNightmareChanceNow);
        vm->RegisterFunction("GetSeductionSpikeNow", "ASTR2Native", Papyrus_GetSeductionSpikeNow);
        vm->RegisterFunction("GetLustArousalNow", "ASTR2Native", Papyrus_GetLustArousalNow);
        vm->RegisterFunction("GetDistillLifeCost", "ASTR2Native", Papyrus_GetDistillLifeCost);
        vm->RegisterFunction("GetDistillManaCost", "ASTR2Native", Papyrus_GetDistillManaCost);
        vm->RegisterFunction("GetShardLifeCost", "ASTR2Native", Papyrus_GetShardLifeCost);
        spdlog::info("[SpellInfo] Papyrus getter GetNightmareBaseNow/ChanceNow/SeductionSpikeNow/LustArousalNow/DistillLife-ManaCost/ShardLifeCost 登録");
        return true;
    }
}
