#include "PCH.h"
#include "NailDesc.h"
#include "SkyVaultAPI.h"
#include "Localization.h"
#include "VassalUpkeep.h"   // 🧟 スイート・ヴァッサルの蘇生日数＝C++で単一の正 VassalUpkeep::VassalDaysNow を共用（定義を二重に持ちません）
#include "EssenceFlow.h"    // 💧 エッセンス・フロウ FlowHealNow/FlowCostNow（二重に持たないwrapper）
#include "Fury.h"           // 🔥 アンリーシュド・フューリー FuryBoostNow（二重に持たないwrapper）
#include "CombatDrain.h"    // 🩸 ラヴェナス・ドレイン RavenousRangeM/MaxTgts（二重に持たないwrapper）
#include "SpellInfo.h"      // 🌙 ナイトメア・エンブレイス NightmareChanceNow 等（〔アレテイア〕用getterの集約・二重に持ちません）
#include "HDrain.h"         // 💋 アラウジング・ラスト HDrain::HDrainOrgasmBaseNow（H中ドレイン素の威力）

#include <functional>
#include <string>
#include <unordered_map>
#include <vector>
#include <MinHook.h>

// ============================================================================
//  動的説明文レジストリ
//   ・TESDescription::GetDescription を MinHook で1本横取りし、g_registry に登録された
//     フォーム(呪文/アイテム)の TESDescription サブオブジェクトの時だけ、ビルダーの返す文字列へ差し替えます。
//   ・フック点＝RELOCATION_ID(14399, 14552)＝非virtualの通常メンバ関数so入口フック（MinHook・SkillXpBoostと同手）。
//   ・判別＝a_this(TESDescriptionサブオブジェクト)一致（item cardは a_parent=null で呼びます為＝親では判別できません・実機で確認）。
//     static_cast<TESDescription*>(form) はコンパイラがサブオブジェクトのオフセットを計算＝ハードコード不要で安全です。
//   ・最初の利用者＝ネイル7種(0x020886〜)。呼び出し側は NailDesc::Register(form, builder) で自分の呪文/アイテムを追加できます。
//   ★魔法メニュー・item cardとも日本語＋改行(\n→ToNewlines)が使えます＝実機のスクリーンショットで確認（以前の「魔法メニューはASCII・改行なし限定」という注記は誤りでした）。書式は呼び側ビルダーの責任です。
//   ★対象フォームのDESCが空だとゲームがGetDescriptionを呼ばない可能性＝placeholder DESC を1文字入れると確実です（手作業で設定）。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace NailDesc {
    namespace {
        constexpr const char* kEsp           = "A Succubus Tale R2.esp";
        constexpr RE::FormID  kNailBase      = 0x020886;   // idx0（0x020886〜0x02088C＝idx0-6）

        inline int SVInt(const char* key, int def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
            return def;
        }
        inline float SVFloat(const char* key, float def) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetFloat(0, key, def);
            return def;
        }

        int SuccubusLevel() { return std::clamp(SuccLevel::Raw(1), 1, 100); }

        // ★汎用レジストリ＝フォームのTESDescriptionサブオブジェクト → 説明ビルダー。load時に登録、Detourが引きます。
        //   登録は全て load(kDataLoaded・各利用側のInstall)＝Detour(ゲーム中メニュー)より前に完了so mutex不要です。
        std::unordered_map<RE::TESDescription*, std::function<std::string()>> g_registry;

        // 翻訳txtは改行を "\n"(バックスラッシュ+n の2文字) で持ちますので、実改行(0x0A)へ変換します（item cardは実改行で多段表示します）。
        std::string ToNewlines(const std::string& in) {
            std::string out;
            out.reserve(in.size());
            for (std::size_t i = 0; i < in.size(); ++i) {
                if (in[i] == '\\' && i + 1 < in.size() && in[i + 1] == 'n') {
                    out += '\n';
                    ++i;
                } else {
                    out += in[i];
                }
            }
            return out;
        }

        // 罪idx→気分カテゴリ（ASTR2NailManager.NailCategoryと同一：0/5=殺(2)・1/2=H(1)・他=吸(0)）。
        int NailCategory(int idx) {
            if (idx == 0 || idx == 5) return 2;
            if (idx == 1 || idx == 2) return 1;
            return 0;
        }
        bool IsOwned(int idx) { return SVInt(fmt::format("ASTR2_NailOwned_{}", idx).c_str(), 0) == 1; }
        bool IsComplete()     { for (int i = 0; i < 7; ++i) { if (!IsOwned(i)) return false; } return true; }

        // このネイル(nailIdx)を装備した時に有効になる大罪の並び＝7コンプなら全7／それ以外は同カテゴリの習得済み。並びは「ネイル自身の罪→残り(idx順)」。
        std::vector<int> ActiveSinsForNail(int nailIdx) {
            std::vector<int> out;
            const bool complete = IsComplete();
            if (complete || IsOwned(nailIdx)) out.push_back(nailIdx);   // ネイル自身の罪を先頭
            const int cat = NailCategory(nailIdx);
            for (int i = 0; i < 7; ++i) {
                if (i == nailIdx) continue;
                if (complete || (NailCategory(i) == cat && IsOwned(i))) out.push_back(i);
            }
            return out;
        }

        // 1大罪ぶんの効果文＝$keyへ実数差し込み（技名\n効果・0x0A）。{0}/{1}の番号式です。
        std::string BuildOneSin(int idx) {
            const int lv = SuccubusLevel();
            const char* key = nullptr;
            std::vector<std::string> args;
            switch (idx) {
                case 0:  // 憤怒 Ira＝{0}発動HP閾値(10+Lv×0.3) / {1}=Lv(魔法与ダメ+%)
                    key  = "$ASTR2_NailDesc_Ira";
                    args = { fmt::format("{:.0f}", 10.0f + lv * 0.3f), std::to_string(lv) };
                    break;
                case 1:  // 傲慢 Superbia＝{0}話術XP% / {1}HスキルXP%
                    key  = "$ASTR2_NailDesc_Superbia";
                    args = { std::to_string(SVInt("ASTR2_NailPrideSpeechMax", 100) * lv / 100),
                             std::to_string(SVInt("ASTR2_NailPrideTechMax", 50) * lv / 100) };
                    break;
                case 2:  // 色欲 Luxuria＝{0}魅了成功率% / {1}セダクション系 使用回数+/日(Lv/10)
                    key  = "$ASTR2_NailDesc_Luxuria";
                    args = { fmt::format("{:.1f}", lv * 0.1), std::to_string(lv / 10) };
                    break;
                case 3:  // 暴食 Gula＝{0}〔天敵〕から吸引%
                    key  = "$ASTR2_NailDesc_Gula";
                    args = { fmt::format("{:.1f}", SVFloat("ASTR2_NailGulaPerLv", 0.001f) * lv * 100.0f) };
                    break;
                case 4:  // 怠惰 Acedia＝{0}構え中移動速度%
                    key  = "$ASTR2_NailDesc_Acedia";
                    args = { std::to_string(SVInt("ASTR2_NailLazyMaxOffset", 50) * lv / 100) };
                    break;
                case 5:  // 嫉妬 Invidia＝{0}魔法5スキル+
                    key  = "$ASTR2_NailDesc_Invidia";
                    args = { std::to_string(SVInt("ASTR2_EnvyApplied", 0)) };
                    break;
                case 6:  // 強欲 Avaritia＝{0}吸収%
                    key  = "$ASTR2_NailDesc_Avaritia";
                    args = { std::to_string(lv) };
                    break;
                default:
                    return "";
            }
            return ToNewlines(Localization::LocFmtStrCpp(key, args));
        }

        // 「技名\n効果」→「技名 / 効果」（最初の改行を " / " に）。2〜3罪を1罪1行で縦積みする時に使います。
        std::string CompactOneLine(std::string s) {
            const auto pos = s.find('\n');
            if (pos != std::string::npos) {
                s.replace(pos, 1, " / ");
            }
            return s;
        }

        // 効果行だけ（技名を除いた"効果"部分＝$key出力の最初の改行より後ろ）。4罪以上の見出しまとめ表示で使います。
        std::string EffectOnly(int idx) {
            std::string s = BuildOneSin(idx);   // 技名\n効果
            const auto pos = s.find('\n');
            return (pos != std::string::npos) ? s.substr(pos + 1) : s;
        }

        // ネイル1枚の説明＝有効になる大罪を並べます（item cardの高さ節約）：
        //   1罪＝2行(技名\n効果)／2〜3罪＝各罪1行(技名 / 効果)／4罪以上(=実質7コンプ全開放)＝見出し「シンフル・ブレッシング」($key)＋効果だけ列挙。
        std::string BuildNailDesc(int nailIdx) {
            const std::vector<int> sins = ActiveSinsForNail(nailIdx);
            if (sins.empty()) {
                return "";   // 未習得等＝差し替えず元のDESCのまま
            }
            if (sins.size() == 1) {
                return BuildOneSin(sins[0]);   // 1罪＝技名\n効果（2行・現状維持）
            }
            if (sins.size() >= 4) {
                // 4罪以上＝実質7コンプ全開放。行数を減らします為、気分カテゴリ(吸0/H1/殺2)ごとに効果を1行に束ねます＝見出し＋最大3行。
                std::string out = ToNewlines(Localization::LocFmtStrCpp("$ASTR2_Header_SinBless", {}));   // 見出し＝既存キー流用（JP「シンフル・ブレッシング」/EN「Sinful Blessing」）
                for (int cat = 0; cat <= 2; ++cat) {
                    std::string line;
                    for (int s : sins) {
                        if (NailCategory(s) != cat) continue;
                        if (!line.empty()) line += " / ";
                        line += EffectOnly(s);
                    }
                    if (!line.empty()) {
                        out += "\n" + line;
                    }
                }
                return out;
            }
            std::string out;   // 2〜3罪＝各罪「技名 / 効果」を改行で縦積み
            for (std::size_t i = 0; i < sins.size(); ++i) {
                if (i) out += '\n';
                out += CompactOneLine(BuildOneSin(sins[i]));
            }
            return out;
        }

        // ---- MinHook: TESDescription::GetDescription(this, out, parent, fieldType) ----
        using GetDesc_t = void (*)(RE::TESDescription*, RE::BSString&, RE::TESForm*, std::uint32_t);
        GetDesc_t g_orig = nullptr;

        void Detour(RE::TESDescription* a_this, RE::BSString& a_out, RE::TESForm* a_parent, std::uint32_t a_fieldType) {
            g_orig(a_this, a_out, a_parent, a_fieldType);   // 元の説明文を先に埋めます
            if (auto it = g_registry.find(a_this); it != g_registry.end()) {
                const std::string s = it->second();
                if (!s.empty()) {
                    a_out = s.c_str();   // 登録フォームの時だけビルダー出力へ差し替えます（BSStringはUTF-8 char）
                }
            }
        }
    }

    // 登録窓口（公開）。g_registry は同TUの匿名namespacesoここから触れます。cast は template Register が済ませて渡します。
    void RegisterDesc(RE::TESDescription* a_desc, std::function<std::string()> a_builder) {
        if (a_desc && a_builder) {
            g_registry[a_desc] = std::move(a_builder);
        }
    }

    // ※マジカ消費の説明行(ManaCostLine)は廃止＝魔法メニューのコスト列に一本化しました(CalculateMagickaCostフック)。
    //   使っていた$key $ASTR2_Info_ManaCostPerSec/ManaCostBurst はこれで不要です。

    void Install() {
        REL::Relocation<std::uintptr_t> target{ RELOCATION_ID(14399, 14552) };   // TESDescription::GetDescription
        void* tgt = reinterpret_cast<void*>(target.address());

        const auto init = MH_Initialize();
        if (init != MH_OK && init != MH_ERROR_ALREADY_INITIALIZED) {
            spdlog::error("[NailDesc] MH_Initialize failed ({})", static_cast<int>(init));
            return;
        }
        if (MH_CreateHook(tgt, reinterpret_cast<void*>(&Detour), reinterpret_cast<void**>(&g_orig)) != MH_OK) {
            spdlog::error("[NailDesc] MH_CreateHook failed");
            return;
        }
        if (MH_EnableHook(tgt) != MH_OK) {
            spdlog::error("[NailDesc] MH_EnableHook failed");
            return;
        }

        // 最初の利用者＝ネイル7種を登録します（各ネイルArmoの TESDescription → BuildNailDesc(i)）。
        //   他の利用側は自分のInstallで NailDesc::Register(自分のSpell/Armo, builder) を呼べば同じ仕組みに乗れます。
        int n = 0;
        if (auto* dh = RE::TESDataHandler::GetSingleton()) {
            for (int i = 0; i < 7; ++i) {
                if (auto* armo = dh->LookupForm<RE::TESObjectARMO>(kNailBase + i, kEsp)) {
                    RegisterDesc(static_cast<RE::TESDescription*>(armo), [i]() { return BuildNailDesc(i); });
                    ++n;
                }
            }
            // 🧪 パイロット＝サキュバス・ドレイン(Succubus Drain 0x007924)＝呪文DESC横展開の1本目。
            //   ★getter ASTDrainScript.GetBaseDrainPerSec は Papyrus so式(2+(Lv-1)×8)をC++で再現＝単一の正を崩しません為、恒久化するなら共有元(〔SkyVault〕/C++getter)へ寄せます。
            //   ★呪文=魔法メニュー＝日本語/改行で empty崩れ した前例があります＝このパイロットで「日本語1行が魔法メニューに出るか」を検証します。
            if (auto* drainSpell = dh->LookupForm<RE::SpellItem>(0x007924, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(drainSpell), []() {
                    const int baseDrain = CombatDrain::DrainBaseNow();   // 計算の単一の正(CombatDrain.cpp)＝ASTDrainScript.GetBaseDrainPerSec と共用(二重無し)
                    // 3段＝1行目 呪文名／2行目 効果(実数)／3行目 フレーバー説明。全て既存$keyを流用します（他呪文と揃えます為2行→3行化）。
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Drain", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_DrainNow", { std::to_string(baseDrain) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Drain", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
                spdlog::info("[NailDesc] spell registered: Succubus Drain 0x007924 (3-line)");
            }

            // 🧟 スイート・ヴァッサル(Sweet Vassal 0x00BF77)＝呪文DESC横展開・3段(名前/効果/説明)。定義を二重に持ちません。
            //   蘇生日数＝VassalUpkeep::VassalDaysNow()(Papyrus CalcVassalDaysと同じC++の単一の正)／コスト＝〔SkyVault〕 ASTR2_ReanimCost直読み。
            if (auto* reanimSpell = dh->LookupForm<RE::SpellItem>(0x00BF77, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(reanimSpell), []() {
                    const int days = static_cast<int>(VassalUpkeep::VassalDaysNow());
                    const int cost = static_cast<int>(SVFloat("ASTR2_ReanimCost", 5000.0f));
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Reanim", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_ReanimNow",
                                                 { std::to_string(days), std::to_string(cost) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Reanim", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
                spdlog::info("[NailDesc] spell registered: Sweet Vassal 0x00BF77 (3-line)");
            }

            // 💧 エッセンス・フロウ(Essence Flow 0x02087E)＝3段。回復%/維持＝wrapper(二重に持ちません・MCM getterと同一実体)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x02087E, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Flow", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_FlowNow",
                        { fmt::format("{:.1f}", EssenceFlow::FlowHealNow()), std::to_string(EssenceFlow::FlowCostNow()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Flow", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🔥 アンリーシュド・フューリー(Fury 0x00B4AA)＝Lv解放分だけ並べる＝MCM Fury info(ASTR2MCMScript 2732)と同型を移植。
            //   名前／L2(スキル+維持)／L3(耐性+移動 or Lv4は固定のみ)／説明。値wrapperは二重に持たず・$keyはMCMと共用です。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x00B4AA, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const int lv = SuccubusLevel();
                    // スキル名キー（Lv累積：破壊Lv4→+回復6→+召喚7→+幻惑8→+変性9）
                    const char* skKey = "$ASTR2_FurySkills_1";
                    if      (lv >= 9) skKey = "$ASTR2_FurySkills_5";
                    else if (lv >= 8) skKey = "$ASTR2_FurySkills_4";
                    else if (lv >= 7) skKey = "$ASTR2_FurySkills_3";
                    else if (lv >= 6) skKey = "$ASTR2_FurySkills_2";
                    // 固定キー（マジカ再生のみLv4／+移動速度・ジャンプLv5）
                    const char* fxKey = (lv >= 5) ? "$ASTR2_FuryFixed_2" : "$ASTR2_FuryFixed_1";
                    const std::string skName = Localization::LocFmtStrCpp(skKey, {});
                    const std::string fxName = Localization::LocFmtStrCpp(fxKey, {});
                    // L2＝スキル名＋強化量＋維持コスト
                    const std::string l2 = Localization::LocFmtStrCpp("$ASTR2_FuryInfoL2",
                        { skName, std::to_string(Fury::FuryBoostNow()), std::to_string(Fury::FuryCostNow()) });
                    // 🔥 固定(マジカ再生/移動速度/ジャンプ)＝独立行に切り離し(5行化)。$ASTR2_FuryInfoL3NoRes(=「・{0}」)流用。
                    const std::string l4   = Localization::LocFmtStrCpp("$ASTR2_FuryInfoL3NoRes", { fxName });
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Power", {});
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Fury", {});
                    // Lv5+＝5行(名前/スキル維持/耐性/固定/desc)／Lv4＝耐性なしso4行(固定l4はそのまま)。
                    std::string out;
                    if (lv >= 5) {
                        const char* rsKey = "$ASTR2_FuryResist_1";
                        if      (lv >= 10) rsKey = "$ASTR2_FuryResist_3";
                        else if (lv >= 6)  rsKey = "$ASTR2_FuryResist_2";
                        const std::string rsName = Localization::LocFmtStrCpp(rsKey, {});
                        // 耐性だけ(2引数・固定はl4へ分離＝翻訳が$ASTR2_FuryInfoL3の{2}を削除)
                        const std::string l3 = Localization::LocFmtStrCpp("$ASTR2_FuryInfoL3",
                            { rsName, std::to_string(Fury::FuryResistNow()) });
                        out = name + "\n" + l2 + "\n" + l3 + "\n" + l4 + "\n" + desc;
                    } else {
                        out = name + "\n" + l2 + "\n" + l4 + "\n" + desc;
                    }
                    return ToNewlines(out);
                });
            }

            // 🩸 ラヴェナス・ドレイン(Ravenous 0x020881)＝3段。範囲/人数＝wrapper(二重に持ちません)／威力＝式再現(Drainと同じ単一の正に注意 2+(Lv-1)×8)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x020881, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const int baseDrain = CombatDrain::DrainBaseNow();   // 計算の単一の正(CombatDrain.cpp・二重無し)
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Ravenous", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_RavenousDesc",
                        { std::to_string(baseDrain), fmt::format("{:.1f}", CombatDrain::RavenousRangeM()),
                          std::to_string(CombatDrain::RavenousMaxTgts()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Ravenous", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🍬 エンバー・エッセンス(Ember 0x01D7F1)＝3段(名前/残数/説明)。火種残数＝〔SkyVault〕直読み ASTR2_PowerTokens(保存の正・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01D7F1, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Ember", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Desc_Ember",
                        { std::to_string(SVInt("ASTR2_PowerTokens", 0)) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Info_EmberFactors", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // ===== B群 =====
            // 💋 リヴァイヴィング・グレイス(Reviving Grace 0x01ED82)＝3段。消費＝最大淫魔力×10%(〔SkyVault〕 ASTR2_LF_Max直読み・成功時のみ・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01ED82, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const int cost = static_cast<int>(SVInt("ASTR2_LF_Max", 800) * 0.10f);
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Reviving", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_RevivingNow", { std::to_string(cost) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Reviving", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🔗 サキュバス・チャーム(Command/Charm 0x00DA62)＝2段(名前/説明・数値なし)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x00DA62, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Command", {});
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Command", {});
                    return ToNewlines(name + "\n" + desc);
                });
            }

            // 🔗 サーヴァント・シンク(Servant Sync 0x01C7B1)＝2段(名前/説明・数値なし)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01C7B1, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_ServantSync", {});
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_ServantSync", {});
                    return ToNewlines(name + "\n" + desc);
                });
            }

            // ===== 式C群（native化＝二重無し）=====
            // 💧 コンスーム・エッセンス(Consume 0x00BA0F)＝3段。回復%/秒＝native RegenPctNow(ASTDrainScriptと共用・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x00BA0F, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Consume", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_ConsumeNow",
                        { fmt::format("{:.1f}", CombatDrain::RegenPctNow()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Consume", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🩸 サキュバス・ウィークネス(Weakness 0x005E37)＝3段。耐性ダウン実効値＝native WeaknessResistDownNow(ASTDrainScriptと共用・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x005E37, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Weakness", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_WeaknessNow",
                        { std::to_string(CombatDrain::WeaknessResistDownNow()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Weakness", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🌙 ナイトメア・エンブレイス(Nightmare 0x01BCE9)＝3段。成功確率(base)＝native NightmareChanceNow(ASTR2NightmareEffectと共用・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01BCE9, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Nightmare", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_NightmareChance",
                        { std::to_string(SpellInfo::NightmareChanceNow()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Nightmare", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 💎 クリエイト・シャード(Shard 0x01BCE2)＝3段。★{0}=解禁済サイズのコストだけ組みます(Lv2/3/5/7/10で解禁)。
            //    ★コストは SpellInfo::ShardLifeCost(単一の正)を呼ぶ＝psc(ASTR2CreateShardEffectの支払い/GetShardCost)と共用(二重に持ちません)。表示は素コスト(ShardCostMult前)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01BCE2, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    struct Sz { int lv; int size; const char* key; };
                    static const Sz sizes[] = {
                        { 2, 0, "$ASTR2_Shard_Petty"   },
                        { 3, 1, "$ASTR2_Shard_Lesser"  },
                        { 5, 2, "$ASTR2_Shard_Common"  },
                        { 7, 3, "$ASTR2_Shard_Greater" },
                        {10, 4, "$ASTR2_Shard_Grand"   },
                    };
                    const int lv = SuccubusLevel();
                    std::string costs;
                    for (const auto& s : sizes) {
                        if (lv >= s.lv) {
                            if (!costs.empty()) costs += "／";
                            costs += Localization::LocFmtStrCpp(s.key, {}) + std::to_string(SpellInfo::ShardLifeCost(s.size));
                        }
                    }
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Shard", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_ShardDesc", { costs });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Shard", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 🍯 ディスティル・エッセンス(Distill 0x01D7EA)＝4段(名前/淫魔力コスト/マジカコスト/説明)。★Shard同型＝解禁済サイズだけ組みます(Lv2/3/5/7/10)。
            //    ★コストは SpellInfo::DistillLife/ManaCost(単一の正)を呼ぶ＝psc(ASTR2DistillEssenceEffectの支払い)と共用(二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x01D7EA, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    struct Dz { int lv; int size; const char* key; };
                    static const Dz sizes[] = {
                        { 2, 0, "$ASTR2_Shard_Petty"   },
                        { 3, 1, "$ASTR2_Shard_Lesser"  },
                        { 5, 2, "$ASTR2_Shard_Common"  },
                        { 7, 3, "$ASTR2_Shard_Greater" },
                        {10, 4, "$ASTR2_Shard_Grand"   },
                    };
                    const int lv = SuccubusLevel();
                    std::string lfCosts, manaCosts;
                    for (const auto& s : sizes) {
                        if (lv >= s.lv) {
                            const std::string szName = Localization::LocFmtStrCpp(s.key, {});
                            if (!lfCosts.empty())   lfCosts   += "／";
                            if (!manaCosts.empty()) manaCosts += "／";
                            lfCosts   += szName + std::to_string(SpellInfo::DistillLifeCost(s.size));
                            manaCosts += szName + std::to_string(SpellInfo::DistillManaCost(s.size));
                        }
                    }
                    const std::string name   = Localization::LocFmtStrCpp("$ASTR2_Spell_Distill", {});
                    const std::string lfLn   = Localization::LocFmtStrCpp("$ASTR2_Info_DistillLFDesc",   { lfCosts });
                    const std::string manaLn = Localization::LocFmtStrCpp("$ASTR2_Info_DistillManaDesc", { manaCosts });
                    const std::string desc   = Localization::LocFmtStrCpp("$ASTR2_Desc_Distill", {});
                    return ToNewlines(name + "\n" + lfLn + "\n" + manaLn + "\n" + desc);
                });
            }

            // 🩷 魅了3種(ウィスパー・セダクション0x002DB3/エリア・セダクション0x00BA13/マス・セダクション0x004E05)＝3段。1ヒットの色気注入量=native SeductionSpikeNow(二重に持ちません・3種同値)。
            {
                struct Sd { RE::FormID id; const char* nameKey; const char* descKey; };
                static const Sd seds[] = {
                    { 0x002DB3, "$ASTR2_Spell_Seduction", "$ASTR2_Desc_Seduction" },
                    { 0x00BA13, "$ASTR2_Spell_Area",      "$ASTR2_Desc_Area"      },
                    { 0x004E05, "$ASTR2_Spell_Mass",      "$ASTR2_Desc_Mass"      },
                };
                for (const auto& sd : seds) {
                    if (auto* sp = dh->LookupForm<RE::SpellItem>(sd.id, kEsp)) {
                        const char* nk = sd.nameKey;
                        const char* dk = sd.descKey;
                        RegisterDesc(static_cast<RE::TESDescription*>(sp), [nk, dk]() {
                            const std::string name = Localization::LocFmtStrCpp(nk, {});
                            const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_SedRise",
                                { fmt::format("{:.0f}", SpellInfo::SeductionSpikeNow()) });
                            const std::string desc = Localization::LocFmtStrCpp(dk, {});
                            return ToNewlines(name + "\n" + eff + "\n" + desc);
                        });
                    }
                }
            }

            // 💋 アラウジング・ラスト(Lust 0x00B4A6)＝3段。{0}興奮注入=SpellInfo::LustArousalNow／{1}H中ドレイン=HDrain::HDrainOrgasmBaseNow(実核是正・相手HPで変動・二重に持ちません)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x00B4A6, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_Lust", {});
                    const std::string eff  = Localization::LocFmtStrCpp("$ASTR2_Info_LustVals",
                        { std::to_string(SpellInfo::LustArousalNow()), std::to_string(HDrain::HDrainOrgasmBaseNow()) });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_Desc_Lust", {});
                    return ToNewlines(name + "\n" + eff + "\n" + desc);
                });
            }

            // 💅 シンフル・ネイル親(Sinful Nail 0x02089D)＝3段(名前/サマリ/説明)。{0}獲得数/7・{1}装備中名(idx→$ASTR2_NailName_<idx>／-1=未装備)。
            if (auto* sp = dh->LookupForm<RE::SpellItem>(0x02089D, kEsp)) {
                RegisterDesc(static_cast<RE::TESDescription*>(sp), []() {
                    int owned = 0;
                    for (int i = 0; i < 7; ++i) { if (IsOwned(i)) ++owned; }
                    const int worn = SVInt("ASTR2_NailWornIdx", -1);
                    std::string wornName;
                    if (worn >= 0 && worn < 7) {
                        wornName = Localization::LocFmtStrCpp(fmt::format("$ASTR2_NailName_{}", worn).c_str(), {});
                    } else {
                        wornName = Localization::LocFmtStrCpp("$ASTR2_Nail_NotEquipped", {});
                    }
                    const std::string name = Localization::LocFmtStrCpp("$ASTR2_Spell_SinfulNail", {});
                    const std::string sum  = Localization::LocFmtStrCpp("$ASTR2_NailSummary",
                        { std::to_string(owned), wornName });
                    const std::string desc = Localization::LocFmtStrCpp("$ASTR2_NailSummaryDesc", {});
                    return ToNewlines(name + "\n" + sum + "\n" + desc);
                });
            }
        }
        spdlog::info("[NailDesc] installed (registry-based, TESDescription::GetDescription @ {:X}) -- {} nails registered", target.address(), n);
    }
}
