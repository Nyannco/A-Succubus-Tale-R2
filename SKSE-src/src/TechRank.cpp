#include "PCH.h"
#include "TechRank.h"
#include "Technique.h"      // Technique::LiveCatSeconds / LiveActionSeconds（今のシーンのライブ秒）
#include "SkyVaultAPI.h"    // 確定秒の保存先＝外部〔SkyVault〕（クロスMODデータ庫）
#include "SceneCatalog.h"   // 孫スキル精査＝各行為の実在アニメ本数を全シーンから集計

#include <array>
#include <string>
#include <mutex>
#include <cstdint>

// ============================================================================
// Hスキルランク層(C++)です。Papyrus ASTR2Technique のランク系ロジックを寸分違わず移植し、
//   ①保存＝StorageUtil→〔SkyVault〕 ②floor-0(未経験=0) ③ライブ成長(確定秒+ライブ秒) を足したものです。
//   デッドロック回避：g_cacheMutex と Technique::g_mutex を同時に握りません
//   （キャッシュをコピーして解放→そのあとで Technique のライブ秒を足します）。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace {
    constexpr std::uint32_t kHolder = 0;   // 〔SkyVault〕 holder=0（プレイヤー単一データ・PowerResetと同じ流儀・キーで名前空間分離）

    // 8カテゴリのキー名です（Papyrus CatKeys / Technique.cpp kCatName と一致）。
    const char* kCatKey[8] = { "Hips", "Mouth", "Hand", "Other", "Solo", "Kiss", "AttackS", "ReceiveM" };

    // ★孫の総数です（54＝旧42からfacialを射精へ統合(-1)＋新規13追加）。全ての孫ループ/配列はこれを使います。
    constexpr int kActN = 54;

    // 孫の正規名です（canonActionの出力＝g_act/〔SkyVault〕キーと一致）。★idx0-40は旧来のまま(MCM行の互換維持)／
    //   旧facial(41)は"ejaculation"へ統合し削除／新規13はidx41-53に追加します。種目は下の kActCat で明示します。
    const char* kAct[kActN] = {
        "vaginalsex", "analsex", "tribbing",
        "blowjob", "deepthroat", "cunnilingus", "lickingvagina", "lickingpenis", "lickingtesticles",
        "lickingnipple", "suckingnipple", "anilingus",
        "handjob", "vaginalfingering", "analfingering", "vaginalfisting", "analfisting", "rubbingclitoris",
        "gropingbreast", "gropingbutt", "gropingtesticles", "oralfingering", "vaginaltoying", "analtoying",
        "boobjob", "footjob", "thighjob", "buttjob", "rubbingpenisagainstface",
        "grindingpenis", "grindingthigh", "grindingfoot", "grindingobject", "femalemasturbation", "malemasturbation",
        "kissing", "frenchkissing", "kissingcheek", "kissingfoot", "kissinghand", "kissingneck",
        // ★新規13（41-53）：顔面騎乗／ディルド膣・尻／スパンキング／首絞め／玩具(横断)／射精(顔射統合)／吸血／焦らし／マッサージ／乳こすり／乳窒息／尻尾技
        "buttsmothering", "mdildovaginal", "mdildoanal", "spanking", "choking",
        "toy", "ejaculation", "vampirebite", "teasing", "massaging", "breastsliding", "breastsmothering", "tailtech"
    };

    // 各行為の加算対象マスクです（applyMask用）。bit: 男異1 男同2 女異4 女同8 フタ専用16。
    const int kMask[kActN] = {
        13, 15, 8,
        6, 6, 9, 9, 6, 6,
        15, 15, 15,
        7, 13, 15, 13, 15, 13,
        15, 15, 7, 15, 13, 15,
        4, 6, 6, 6, 15,
        19, 12, 15, 15, 12, 19,
        15, 15, 15, 15, 15, 15,
        // 新規13（顔面騎乗15／ディルド膣13(玩具膣同)・尻15(玩具尻同)／スパンキング15／首絞め15／玩具15／射精15(旧facial同)／吸血15／焦らし15／マッサージ15／乳こすり15／乳窒息15／尻尾技15）
        15, 13, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15
    };

    // 各孫のHUD表示名$keyです（★HUD専用 $ASTR2_ActHud_*＝ツリー記号なしの純粋な行為名／MCMは記号付き$ASTR2_Act_*を別途使用）。TechHudがLocalizationで解決します。
    const char* kActKey[kActN] = {
        "$ASTR2_ActHud_Vaginal", "$ASTR2_ActHud_Anal", "$ASTR2_ActHud_Tribbing",
        "$ASTR2_ActHud_Blowjob", "$ASTR2_ActHud_Deepthroat", "$ASTR2_ActHud_Cunnilingus", "$ASTR2_ActHud_LickVagina", "$ASTR2_ActHud_LickPenis", "$ASTR2_ActHud_LickBalls",
        "$ASTR2_ActHud_LickNipple", "$ASTR2_ActHud_SuckNipple", "$ASTR2_ActHud_AnalLick",
        "$ASTR2_ActHud_Handjob", "$ASTR2_ActHud_Fingering", "$ASTR2_ActHud_AnalFinger", "$ASTR2_ActHud_Fisting", "$ASTR2_ActHud_AnalFist", "$ASTR2_ActHud_RubClit",
        "$ASTR2_ActHud_GropeBreast", "$ASTR2_ActHud_GropeButt", "$ASTR2_ActHud_GropeBalls", "$ASTR2_ActHud_OralFinger", "$ASTR2_ActHud_VaginalToy", "$ASTR2_ActHud_AnalToy",
        "$ASTR2_ActHud_Boobjob", "$ASTR2_ActHud_Footjob", "$ASTR2_ActHud_Thighjob", "$ASTR2_ActHud_Buttjob", "$ASTR2_ActHud_RubFace",
        "$ASTR2_ActHud_GrindPenis", "$ASTR2_ActHud_GrindThigh", "$ASTR2_ActHud_GrindFoot", "$ASTR2_ActHud_GrindObject", "$ASTR2_ActHud_MasturbF", "$ASTR2_ActHud_MasturbM",
        "$ASTR2_ActHud_Kiss", "$ASTR2_ActHud_KissFrench", "$ASTR2_ActHud_KissCheek", "$ASTR2_ActHud_KissFoot", "$ASTR2_ActHud_KissHand", "$ASTR2_ActHud_KissNeck",
        // 新規13（41-53）
        "$ASTR2_ActHud_FaceSit", "$ASTR2_ActHud_DildoVaginal", "$ASTR2_ActHud_DildoAnal", "$ASTR2_ActHud_Spanking", "$ASTR2_ActHud_Choking",
        "$ASTR2_ActHud_Toy", "$ASTR2_ActHud_Ejaculation", "$ASTR2_ActHud_VampBite", "$ASTR2_ActHud_Teasing", "$ASTR2_ActHud_Massage", "$ASTR2_ActHud_BreastSlide", "$ASTR2_ActHud_BreastSmother", "$ASTR2_ActHud_Tail"
    };

    // 行為index→技術6カテゴリ（0=腰使い 1=口舌 2=手技 3=その他 4=自慰 5=キス）。★範囲依存を廃止＝明示配列です(孫追加で並びが崩れません)。
    const int kActCat[kActN] = {
        0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        3, 3, 3, 3, 3,
        4, 4, 4, 4, 4, 4,
        5, 5, 5, 5, 5, 5,
        // 新規13：顔面騎乗=腰使い(0)／ディルド膣尻・スパンキング・首絞め=手技(2)／玩具・射精・吸血・焦らし・マッサージ・乳こすり・乳窒息・尻尾技=その他(3)
        0, 2, 2, 2, 2,
        3, 3, 3, 3, 3, 3, 3, 3
    };

    // 行為index→技術6カテゴリです。範囲外は-1です。
    inline int techCatByIndex(int i) {
        if (i < 0 || i >= kActN) return -1;
        return kActCat[i];
    }

    // マスク判定です（Papyrus ApplyMask を完全移植）。body:0男/1女/2フタ orient:0異/1同/2両刀 mode:0やりこみ/1らしさ/2得意。
    bool applyMask(int mask, int body, int orient, int mode) {
        if (body == 0) {                                   // 男
            if (mode == 0 || orient == 2) return (mask & 3) != 0;   // 男異|男同
            if (orient == 0)              return (mask & 1) != 0;   // 男異
            return (mask & 2) != 0;                                 // 男同
        } else if (body == 1) {                            // 女
            if (mode == 0 || orient == 2) return (mask & 12) != 0;  // 女異|女同
            if (orient == 0)              return (mask & 4) != 0;   // 女異
            return (mask & 8) != 0;                                 // 女同
        }
        // フタ＝女として絞ります＋フタ専用bit(16)は常時適用します
        int f;
        if (mode == 0 || orient == 2) f = mask & 12;
        else if (orient == 0)         f = mask & 4;
        else                          f = mask & 8;
        if (f != 0) return true;
        return (mask & 16) != 0;
    }

    // ランク化です（Papyrus SecondsToRank ＋ ★floor-0）。0秒=ランク0（未経験＝威力補正はありません）。
    int secondsToRank(float sec) {
        if (sec <= 0.0f)    return 0;    // ★floor-0：未経験です
        if (sec >= 3450.0f) return 10;
        if (sec >= 2610.0f) return 9;
        if (sec >= 1890.0f) return 8;
        if (sec >= 1290.0f) return 7;
        if (sec >= 810.0f)  return 6;
        if (sec >= 450.0f)  return 5;
        if (sec >= 210.0f)  return 4;
        if (sec >= 90.0f)   return 3;
        if (sec >= 30.0f)   return 2;
        return 1;                        // 0 < sec < 30
    }

    // ランクの下限しきい値秒です（Papyrus RankThreshold）。rank<=1=0（floor-0のrank0も0）。
    float rankThreshold(int rank) {
        if (rank <= 1) return 0.0f;
        if (rank == 2) return 30.0f;
        if (rank == 3) return 90.0f;
        if (rank == 4) return 210.0f;
        if (rank == 5) return 450.0f;
        if (rank == 6) return 810.0f;
        if (rank == 7) return 1290.0f;
        if (rank == 8) return 1890.0f;
        if (rank == 9) return 2610.0f;
        return 3450.0f;
    }

    // ---- 〔SkyVault〕 取得（PowerReset と同じ手・1回取ってキャッシュ／不在なら nullptr＝秒0扱い）----
    SkyVaultAPI::IVault* GetVault() {
        static SkyVaultAPI::IVault* v = nullptr;
        if (!v) v = SkyVaultAPI::GetSkyVaultAPI();
        return v;
    }
    inline std::string catKey(int c) { return std::string("ASTR2_TechSec_") + kCatKey[c]; }
    inline const char* roleSuffix(int role) { return role == 0 ? "_S" : (role == 1 ? "_M" : "_N"); }
    inline std::string actKey(const char* name, int role) { return std::string("ASTR2_TechAct_") + name + roleSuffix(role); }

    // ---- C++キャッシュ＝〔SkyVault〕の「確定秒」のスナップショット（ロード/シーン終了で再構築）----
    std::mutex g_cacheMutex;
    float g_catSec[8] = {};
    struct AS { float s = 0.0f, m = 0.0f, neu = 0.0f; };
    AS   g_actSec[kActN];
    int  g_mode = 0, g_orient = 0, g_body = 1;   // 集計コンテキストです（Papyrus SetTechContext で更新）

    // 単純カテゴリ秒です（確定 + ライブ）。★g_cacheMutex を握ったまま Technique を呼びません（デッドロック回避）。
    float catEffSeconds(int cat) {
        float base;
        { std::lock_guard<std::mutex> lk(g_cacheMutex); base = g_catSec[cat]; }
        return base + Technique::LiveCatSeconds(cat);
    }
    // 孫idxの実効秒です（確定 + ライブ・S/M/中立別）。
    AS actEffAt(int idx) {
        AS a;
        { std::lock_guard<std::mutex> lk(g_cacheMutex); a = g_actSec[idx]; }
        a.s   += Technique::LiveActionSeconds(kAct[idx], 0);
        a.m   += Technique::LiveActionSeconds(kAct[idx], 1);
        a.neu += Technique::LiveActionSeconds(kAct[idx], 2);
        return a;
    }
    // 全孫の実効秒を1回で作ります（表示ランク計算用・キャッシュは1回コピーしてから解放）。
    void buildEff(AS eff[kActN], int& mode, int& orient, int& body) {
        {
            std::lock_guard<std::mutex> lk(g_cacheMutex);
            for (int i = 0; i < kActN; ++i) eff[i] = g_actSec[i];
            mode = g_mode; orient = g_orient; body = g_body;
        }
        for (int i = 0; i < kActN; ++i) {
            eff[i].s   += Technique::LiveActionSeconds(kAct[i], 0);
            eff[i].m   += Technique::LiveActionSeconds(kAct[i], 1);
            eff[i].neu += Technique::LiveActionSeconds(kAct[i], 2);
        }
    }

    // 子＝種目の表示ランクです（Papyrus CalcCatRank 移植）。cat 0-5=孫ランク集計 / 6-7=選択セットのS(M)秒合計。
    int catRankFromEff(int cat, const AS eff[kActN], int mode, int orient, int body) {
        if (cat == 6 || cat == 7) {
            float sum = 0.0f;
            for (int i = 0; i < kActN; ++i) {
                if (applyMask(kMask[i], body, orient, mode)) sum += (cat == 6 ? eff[i].s : eff[i].m);
            }
            return secondsToRank(sum);
        }
        int total = 0, count = 0, best = 0;
        for (int i = 0; i < kActN; ++i) {
            if (techCatByIndex(i) == cat && applyMask(kMask[i], body, orient, mode)) {
                int r = secondsToRank(eff[i].s + eff[i].m + eff[i].neu);
                total += r; count += 1;
                if (r > best) best = r;
            }
        }
        if (count == 0) return 0;                 // ★floor-0：対象行為ゼロ＝0（Papyrusは1でした＝0-10化で0へ）
        if (mode == 2)  return best;              // 得意特化＝最高です
        return (total + count / 2) / count;       // やりこみ/らしさ＝四捨五入平均です
    }
    int totalRankFromEff(const AS eff[kActN], int mode, int orient, int body) {
        int sum = 0;
        for (int c = 0; c < 8; ++c) sum += catRankFromEff(c, eff, mode, orient, body);
        return (sum + 4) / 8;
    }

    inline int findActIdx(const char* name) {
        for (int i = 0; i < kActN; ++i) { if (std::string(kAct[i]) == name) return i; }
        return -1;
    }

    // ===== 孫スキル精査：各孫(0-53)に対応アニメが何本あるか（0ならMCMでグレーアウト）=====
    //   SceneCatalog索引の全シーンを走査し、各シーンで出た孫を1回だけ数えます（シーン=アニメ単位のユニーク本数）。
    //   ★行為名は Technique::CanonAction で正規化してから引きます(派生名/綴りゆれも本体に寄ります・計測と同じ規則)。
    //   ★transition/idle等の起動不可ノードも索引に含みます(「0か非0か」判定には十分・存在しない孫を弾く目的)。
    std::array<int, kActN> g_animCount{};
    std::once_flag g_animCountedOnce;
    void computeAnimCounts() {
        std::array<int, kActN> cnt{};
        // ★横断スキル(玩具/射精)＝直接その名前のアニメはありません(副加算専用)so、寄与する生行為を副次的に数えます
        //   （CommitSegmentのcreditCrossSkillLockedと対応）。これが無いと玩具が常時0本＝誤グレーアウトになります。
        const int idxToy  = findActIdx("toy");
        const int idxEjac = findActIdx("ejaculation");
        SceneCatalog::ForEachSceneActions([&](const std::string&, const std::vector<SceneCatalog::ActionInfo>& acts) {
            std::array<bool, kActN> seen{};
            for (const auto& a : acts) {
                const int idx = findActIdx(Technique::CanonAction(a.type).c_str());
                if (idx >= 0 && !seen[idx]) { seen[idx] = true; ++cnt[idx]; }
                const std::string rb = Technique::RawBaseName(a.type);
                if (idxToy >= 0 && !seen[idxToy] &&
                    (rb == "vaginaltoying" || rb == "analtoying" || rb == "oraltoying" || rb == "mdildovaginal" || rb == "mdildoanal")) {
                    seen[idxToy] = true; ++cnt[idxToy];        // 玩具＝おもちゃ系のアニメを1本と数えます
                }
                if (idxEjac >= 0 && !seen[idxEjac] && (rb == "cumonhands" || rb == "ejaculation_on_hands")) {
                    seen[idxEjac] = true; ++cnt[idxEjac];      // 射精＝テコキ射精のアニメも数えます（cumon*は上のcanonで既に加算）
                }
            }
        });
        g_animCount = cnt;
    }

    // ===================== Papyrus native（ASTR2Technique.*）=====================
    // 孫idxの実在アニメ本数です（初回に遅延集計）。0ならMCMでグレーアウトします。
    std::int32_t Papyrus_GetActionAnimCount(RE::StaticFunctionTag*, std::int32_t idx) {
        std::call_once(g_animCountedOnce, computeAnimCounts);
        if (idx < 0 || idx >= kActN) return 0;
        return g_animCount[idx];
    }

    // 単純ランクです（カテゴリ秒直＝攻め技(6)等・セダクションが使います）。
    std::int32_t Papyrus_GetTechRank(RE::StaticFunctionTag*, std::int32_t cat) {
        if (cat < 0 || cat >= 8) return 0;
        return secondsToRank(catEffSeconds(cat));
    }

    float Papyrus_GetActionSeconds(RE::StaticFunctionTag*, RE::BSFixedString name) {
        const int idx = findActIdx(name.c_str());
        if (idx < 0) {   // 孫リスト外＝ライブのみです（確定はありません）
            return Technique::LiveActionSeconds(name.c_str(), 0) + Technique::LiveActionSeconds(name.c_str(), 1) + Technique::LiveActionSeconds(name.c_str(), 2);
        }
        AS a = actEffAt(idx);
        return a.s + a.m + a.neu;
    }
    std::int32_t Papyrus_GetActionRank(RE::StaticFunctionTag* tag, RE::BSFixedString name) {
        return secondsToRank(Papyrus_GetActionSeconds(tag, name));
    }

    // 表示/威力ランクです（マスク×指向×mode 集計・ライブ反映）。
    std::int32_t Papyrus_GetDisplayCatRank(RE::StaticFunctionTag*, std::int32_t cat) {
        if (cat < 0 || cat >= 8) return 0;
        AS eff[kActN]; int mode, orient, body; buildEff(eff, mode, orient, body);
        return catRankFromEff(cat, eff, mode, orient, body);
    }
    std::int32_t Papyrus_GetDisplayTotalRank(RE::StaticFunctionTag*) {
        AS eff[kActN]; int mode, orient, body; buildEff(eff, mode, orient, body);
        return totalRankFromEff(eff, mode, orient, body);
    }

    // 孫idx（0-53）系です。
    std::int32_t Papyrus_GetActionRankAt(RE::StaticFunctionTag*, std::int32_t idx) {
        if (idx < 0 || idx >= kActN) return 0;
        AS a = actEffAt(idx);
        return secondsToRank(a.s + a.m + a.neu);
    }
    // 孫の「次のランクまであと何秒」です（Papyrus GetSecondsToNextRankAt）。rank10=0。
    std::int32_t Papyrus_GetSecondsToNextRankAt(RE::StaticFunctionTag*, std::int32_t idx) {
        if (idx < 0 || idx >= kActN) return 0;
        AS a = actEffAt(idx);
        const float sec = a.s + a.m + a.neu;
        const int rank = secondsToRank(sec);
        if (rank >= 10) return 0;
        float need = rankThreshold(rank + 1) - sec;
        if (need < 0.0f) need = 0.0f;
        return static_cast<std::int32_t>(need);
    }
    // 孫の小数ランク "R.ff"です（Papyrus GetActionRankDecimalAt）。rank10="10.00"。
    RE::BSFixedString Papyrus_GetActionRankDecimalAt(RE::StaticFunctionTag*, std::int32_t idx) {
        if (idx < 0 || idx >= kActN) return RE::BSFixedString("0.00");
        AS a = actEffAt(idx);
        const float sec = a.s + a.m + a.neu;
        const int rank = secondsToRank(sec);
        if (rank >= 10) return RE::BSFixedString("10.00");
        const float lo = rankThreshold(rank);
        const float hi = rankThreshold(rank + 1);
        int ff = 0;
        if (hi > lo) ff = static_cast<int>(((sec - lo) / (hi - lo)) * 100.0f);
        if (ff < 0) ff = 0; else if (ff > 99) ff = 99;
        std::string s = std::to_string(rank) + "." + (ff < 10 ? "0" : "") + std::to_string(ff);
        return RE::BSFixedString(s.c_str());
    }
    // 孫idxが今の体/指向/modeで加算対象かどうかです（グレーアウト判定）。
    bool Papyrus_IsActionApplicableAt(RE::StaticFunctionTag*, std::int32_t idx) {
        if (idx < 0 || idx >= kActN) return false;
        int mode, orient, body;
        { std::lock_guard<std::mutex> lk(g_cacheMutex); mode = g_mode; orient = g_orient; body = g_body; }
        return applyMask(kMask[idx], body, orient, mode);
    }

    // 集計コンテキスト（mode/orient/body）をPapyrusから受け取ります（RebuildTechCacheラッパ／MCM変更時）。
    void Papyrus_SetTechContext(RE::StaticFunctionTag*, std::int32_t mode, std::int32_t orient, std::int32_t body) {
        std::lock_guard<std::mutex> lk(g_cacheMutex);
        g_mode = mode; g_orient = orient; g_body = body;
    }

    // ---- 移行用（StorageUtilの旧データをPapyrusが読んで 〔SkyVault〕 へ絶対値セット）----
    void Papyrus_SetCatSecondsRaw(RE::StaticFunctionTag*, std::int32_t cat, float v) {
        if (cat < 0 || cat >= 8) return;
        if (auto* vault = GetVault()) vault->SetFloat(kHolder, catKey(cat).c_str(), v);
    }
    void Papyrus_SetActionSecondsRaw(RE::StaticFunctionTag*, RE::BSFixedString name, std::int32_t role, float v) {
        if (role < 0 || role > 2) return;
        if (auto* vault = GetVault()) vault->SetFloat(kHolder, actKey(name.c_str(), role).c_str(), v);
    }
    bool Papyrus_TechVaultMigrated(RE::StaticFunctionTag*) {
        if (auto* vault = GetVault()) return vault->GetInt(kHolder, "ASTR2_TechMigrated", 0) == 1;
        return true;   // 〔SkyVault〕不在＝移行の必要なし扱いです（機能はライブのみで動きます）
    }
    void Papyrus_MarkTechVaultMigrated(RE::StaticFunctionTag*) {
        if (auto* vault = GetVault()) vault->SetInt(kHolder, "ASTR2_TechMigrated", 1);
        TechRank::RebuildCacheFromVault();
        spdlog::info("[TechRank] migration marked done -> cache rebuilt from SkyVault");
    }
}

namespace TechRank {
    void RebuildCacheFromVault() {
        auto* v = GetVault();
        std::lock_guard<std::mutex> lk(g_cacheMutex);
        for (int c = 0; c < 8; ++c) {
            g_catSec[c] = v ? v->GetFloat(kHolder, catKey(c).c_str(), 0.0f) : 0.0f;
        }
        for (int i = 0; i < kActN; ++i) {
            g_actSec[i].s   = v ? v->GetFloat(kHolder, actKey(kAct[i], 0).c_str(), 0.0f) : 0.0f;
            g_actSec[i].m   = v ? v->GetFloat(kHolder, actKey(kAct[i], 1).c_str(), 0.0f) : 0.0f;
            g_actSec[i].neu = v ? v->GetFloat(kHolder, actKey(kAct[i], 2).c_str(), 0.0f) : 0.0f;
        }
    }

    void OnLoadGame() {
        RebuildCacheFromVault();   // 確定秒→キャッシュ。移行(StorageUtil→〔SkyVault〕)はPapyrusが初回に実行します。
        spdlog::info("[TechRank] OnLoadGame -> cache rebuilt from SkyVault");
    }

    // ★Phase2 HUD用：今のノードで育ってる孫の行データです（名前$key＋現ランク＋次まで秒。max=-1）。
    std::vector<HudLine> BuildHudLines() {
        std::vector<HudLine> out;
        auto acts = Technique::GetActiveNodeActions();   // (正規名, このノードでの重複数=人数)
        // ★リアルタイム化：今の体位の進行中秒を確定秒に足します＝残り秒/ランクが毎秒ヌルヌル更新されます。
        //   ★進行中秒は「その行為を同時にしてる人数」ぶん掛けます＝確定(CommitSegmentが人数ぶん加算=2×)と一致
        //     ＝指マン2人なら残り秒が2/秒で減ります（体位変更時のガクッも消えます）。
        const float inProg = Technique::CurrentNodeElapsed();
        for (const auto& [nm, count] : acts) {
            const int idx = findActIdx(nm.c_str());
            if (idx < 0 || idx >= kActN) continue;   // 範囲外は除外します（facialは射精へ統合済＝全孫に名前があります）
            AS a = actEffAt(idx);
            const float sec = a.s + a.m + a.neu + inProg * static_cast<float>(count);
            const int rank = secondsToRank(sec);
            int toNext;
            if (rank >= 10) {
                toNext = -1;   // 最大です
            } else {
                float need = rankThreshold(rank + 1) - sec;
                toNext = need < 0.0f ? 0 : static_cast<int>(need);
            }
            out.push_back(HudLine{ kActKey[idx], rank, toNext });
        }
        return out;
    }

    // 総合ランクをC++へ公開します（Papyrus版をそのまま呼びます＝計算の二重持ちはありません）。
    int GetDisplayTotalRank() {
        return Papyrus_GetDisplayTotalRank(nullptr);
    }

    // カテゴリ別ランクをC++へ公開します（Papyrus版をそのまま呼びます）。
    int GetDisplayCatRank(int cat) {
        return Papyrus_GetDisplayCatRank(nullptr, cat);
    }

    // 単純カテゴリランク(攻め技等・セダクションが使います)をC++へ公開します（Papyrus GetTechRank をそのまま呼びます）。
    int GetTechRankCpp(int cat) {
        return Papyrus_GetTechRank(nullptr, cat);
    }

    // Technique.cpp がシーン終了時に「このシーンの秒」を確定秒へ足します（読んで加算＝Adjust）。
    void PersistSceneCat(int cat, float delta) {
        if (cat < 0 || cat >= 8 || delta <= 0.0f) return;
        auto* v = GetVault();
        if (!v) return;
        const std::string k = catKey(cat);
        v->SetFloat(kHolder, k.c_str(), v->GetFloat(kHolder, k.c_str(), 0.0f) + delta);
    }
    void PersistSceneAction(const char* action, int role, float delta) {
        if (!action || role < 0 || role > 2 || delta <= 0.0f) return;
        auto* v = GetVault();
        if (!v) return;
        const std::string k = actKey(action, role);
        v->SetFloat(kHolder, k.c_str(), v->GetFloat(kHolder, k.c_str(), 0.0f) + delta);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetActionRank", "ASTR2Technique", Papyrus_GetActionRank);
        vm->RegisterFunction("GetDisplayCatRank", "ASTR2Technique", Papyrus_GetDisplayCatRank);
        vm->RegisterFunction("GetDisplayTotalRank", "ASTR2Technique", Papyrus_GetDisplayTotalRank);
        vm->RegisterFunction("GetActionAnimCount", "ASTR2Technique", Papyrus_GetActionAnimCount);
        vm->RegisterFunction("GetActionRankAt", "ASTR2Technique", Papyrus_GetActionRankAt);
        vm->RegisterFunction("GetSecondsToNextRankAt", "ASTR2Technique", Papyrus_GetSecondsToNextRankAt);
        vm->RegisterFunction("GetActionRankDecimalAt", "ASTR2Technique", Papyrus_GetActionRankDecimalAt);
        vm->RegisterFunction("IsActionApplicableAt", "ASTR2Technique", Papyrus_IsActionApplicableAt);
        vm->RegisterFunction("SetTechContext", "ASTR2Technique", Papyrus_SetTechContext);
        vm->RegisterFunction("SetCatSecondsRaw", "ASTR2Technique", Papyrus_SetCatSecondsRaw);
        vm->RegisterFunction("SetActionSecondsRaw", "ASTR2Technique", Papyrus_SetActionSecondsRaw);
        vm->RegisterFunction("TechVaultMigrated", "ASTR2Technique", Papyrus_TechVaultMigrated);
        vm->RegisterFunction("MarkTechVaultMigrated", "ASTR2Technique", Papyrus_MarkTechVaultMigrated);
        spdlog::info("[TechRank] Papyrus rank natives registered.");
        return true;
    }
}
