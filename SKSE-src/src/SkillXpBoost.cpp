#include "PCH.h"
#include "SkillXpBoost.h"
#include "SkyVaultAPI.h"

#include <atomic>
#include <MinHook.h>

// ============================================================================
// Skill XP Boost 実装 ― 「全バニラスキルXP +N%」(サキュバスソウル)の実装です。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   PlayerCharacter::AddSkillExperience(ActorValue, float) の"入口"を MinHook で横取りし、
//   経験値に ×(1 + g_bonusPct/100) を掛けてから元関数へ渡します。
//   g_bonusPct は Papyrus(ASTLvlManager)が ASTR2Native.SetSkillXpBonus() で随時更新します。
//   ★アドレス＝RELOCATION_ID(39413, 40488)（CommonLibSSE-NG PlayerCharacter.cpp より）。
//   ★フックは MinHook を使います：CommonLibSSEの write_branch/write_call は「既にcall/jmp命令がある
//     "呼び出し箇所"」専用（そこのrel32を読んで元ターゲットを返す設計）＝関数"入口"に撃つと
//     プロローグを誤読して即CTDします（実証済）。MinHookはプロローグを退避＋命令長解析するので
//     入口フックでも元関数を正しく呼び戻せます。
// ============================================================================

namespace {
    std::atomic<float> g_bonusPct{ 0.0f };  // 0..500（%）

    // シンフル・ネイル・傲慢(idx1)＝話術XP+。有効時のみSpeechに追加倍率を掛けます（%は〔SkyVault〕で調整・既定50）。
    inline int SVInt(const char* key, int def) {
        if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
        return def;
    }
    // サキュバスLvです（傲慢のLv連動用・1..100）。
    int NailSucLv() {
        if (auto* dh = RE::TESDataHandler::GetSingleton())
            if (auto* g = dh->LookupForm<RE::TESGlobal>(0x000D64, "A Succubus Tale R2.esp")) {
                int lv = static_cast<int>(g->value);
                return lv < 1 ? 1 : (lv > 100 ? 100 : lv);
            }
        return 1;
    }

    using AddSkillExp_t = void (*)(RE::PlayerCharacter*, RE::ActorValue, float);
    AddSkillExp_t g_original = nullptr;

    void Detour(RE::PlayerCharacter* a_this, RE::ActorValue a_skill, float a_exp) {
        const float pct = g_bonusPct.load();
        const float in = a_exp;  // ★この時点の値＝上流(perk/ご飯系ModSkillUse等)が既に効いてれば合算済みです
        if (pct > 0.0f && a_exp > 0.0f) {
            a_exp *= (1.0f + pct / 100.0f);
        }
        // 傲慢ネイル＝話術(Speech)XPだけ追加倍率を掛けます（有効時のみ・soul分と乗算で乗ります）。★Lv連動＝Max×Lv/100（Lv100で+100%＝×2・線形）。Hスキル側は別キー ASTR2_NailPrideTechMax です。
        if (a_exp > 0.0f && a_skill == RE::ActorValue::kSpeech && SVInt("ASTR2_NailActive_1", 0) == 1) {
            const int pct = SVInt("ASTR2_NailPrideSpeechMax", 100) * NailSucLv() / 100;
            a_exp *= (1.0f + static_cast<float>(pct) / 100.0f);
        }
        // ★確認用のログです（スキルXP付与ごとに出ます・多めに出ます）。in=受取値／out=ソウル倍率後／soul=本機能分%です。
        //   食事でinが跳ねれば「perk/食事系は上流＝inに合算」＝1本で全体を拾えている証拠です。
        spdlog::info("[SKILLXP] av={} in={:.3f} out={:.3f} soul={:.0f}%", static_cast<int>(a_skill), in, a_exp, pct);
        g_original(a_this, a_skill, a_exp);
    }

    // Papyrus: ASTR2Native.SetSkillXpBonus(Float pct)。0..500にクランプして保持します。
    // ★上限100→500：ソウル分(最大100%)にオーガズムバフ分(Lv×1%＝最大100%)が
    //   足して押されるので、100だと合算が頭打ちになります。500は将来の上乗せぶんの余白です。
    void Papyrus_SetSkillXpBonus(RE::StaticFunctionTag*, float a_pct) {
        if (a_pct < 0.0f) {
            a_pct = 0.0f;
        }
        if (a_pct > 500.0f) {
            a_pct = 500.0f;
        }
        g_bonusPct.store(a_pct);
    }
}

namespace SkillXpBoost {
    void Install() {
        REL::Relocation<std::uintptr_t> target{ RELOCATION_ID(39413, 40488) };  // PlayerCharacter::AddSkillExperience
        void* tgt = reinterpret_cast<void*>(target.address());

        const auto initStatus = MH_Initialize();
        if (initStatus != MH_OK && initStatus != MH_ERROR_ALREADY_INITIALIZED) {
            spdlog::error("SkillXpBoost: MH_Initialize failed ({}).", static_cast<int>(initStatus));
            return;
        }
        if (MH_CreateHook(tgt, reinterpret_cast<void*>(&Detour), reinterpret_cast<void**>(&g_original)) != MH_OK) {
            spdlog::error("SkillXpBoost: MH_CreateHook failed.");
            return;
        }
        if (MH_EnableHook(tgt) != MH_OK) {
            spdlog::error("SkillXpBoost: MH_EnableHook failed.");
            return;
        }
        spdlog::info("SkillXpBoost installed (MinHook AddSkillExperience @ {:X}).", target.address());
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("SetSkillXpBonus", "ASTR2Native", Papyrus_SetSkillXpBonus);
        return true;
    }
}
