#include "PCH.h"
#include "SceneCatalog.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <set>
#include <string>
#include <vector>

// GetAPI() は GetModuleHandleA/GetProcAddress（Windows API）を使います＝external ヘッダの前に Windows.h を置きます。
#include <Windows.h>
#include "external/OstimNG-API-Thread.h"

// ============================================================================
// OStimシーンの事前カタログ実装です。読むだけ・効果ゼロです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   構造：catalog[furniture][actorCount] = [ SceneEntry … ]（起動可能シーンのみ）
//   検証：Build() の最後に ASTR2_CatalogDump.txt へ人間可読ダンプを自動出力します。
// ============================================================================

namespace {
    namespace fs = std::filesystem;
    using json = nlohmann::json;

    // OStim本体と同じ相対パスです（GraphTableSetupNodes.cpp:11）。MO2 VFSでマージ済みの全シーンが見えます。
    constexpr const char* kScenesRoot = "Data/SKSE/Plugins/OStim/scenes";

    // OStim NG C++ API（グローバル設定 intendedSexOnly / unrestrictedNavigation を読む用）。
    //   遅延取得＝初回ネイティブ呼び出し時に1回だけ GetAPI します（OStimロード後に呼ばれます＝安全）。
    //   ※HpBarFeed/Technique 等と同じ GetAPI 経路です。複数モジュールが各自取得して問題ありません（実証済）。
    OstimNG_API::Thread::IThreadInterface* g_ostimApi = nullptr;
    bool g_ostimApiTried = false;
    OstimNG_API::Thread::IThreadInterface* OStimApi() {
        if (!g_ostimApiTried) {
            g_ostimApiTried = true;
            g_ostimApi = OstimNG_API::Thread::GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        }
        return g_ostimApi;
    }

    // 1スロット（シーンが要求するアクター枠）です。著者が書いた順番のまま保持します。
    struct SlotInfo {
        std::string sexRaw;                    // intendedSex の生文字列です（""＝JSONに無い＝OStim既定=male）
        char        sexNorm = 'M';             // 正規化：M/F/A（OStim fromString と同じ規則です）
        std::string type;                      // actor type（""＝既定）
        std::vector<std::string> requirements; // 必要タグです（toLowerで小文字化済み＝照合を小文字に揃えています）
    };

    struct SceneEntry {
        std::string sceneId;          // 起動IDそのものです（SetStartingAnimationに渡せる本物）
        std::string furniture;        // "none" 既定です
        std::vector<SlotInfo> slots;  // size = 人数
        std::string modpack;
        bool hasRequirements = false; // いずれかのスロットにrequirementsが付くかどうかです（粗フィルタで足切りできるかの判断材料です）
    };

    // furniture -> actorCount -> シーン群
    std::map<std::string, std::map<int, std::vector<SceneEntry>>> g_catalog;
    std::mutex g_mutex;

    // "idle"タグのシーンID（小文字）＝静止プレースホルダです（OStimの同性フォールバック等）。
    // 起動可能カタログからは除外するが、IsIdleScene() で照合できるよう別途記憶しておきます
    // （Papyrus側ランチャーが GetRandomScene の返りが idle なら捨てて実アニメだけ起動するためです）。
    std::set<std::string> g_idleScenes;

    // scene_id(小文字) -> 著者順スロット性別文字列（例 "MFF"）。起動可能シーンのみです。
    // GetSlotSex 用＝Papyrusが「プレイヤーがその位置で男か女か」を表示するのに使います。
    std::map<std::string, std::string> g_sceneSlotSig;

    // scene_id(小文字) -> 行為リスト。Hスキル C++化(Technique.cpp)が NodeChanged で現在ノードの行為を引きます。
    // ★全ノード対象＝起動不可(transition/noRandom/idle/zero-actor)も含めて索引します（プレイヤーは遷移ノードにも居るため）。
    std::map<std::string, std::vector<SceneCatalog::ActionInfo>> g_sceneActions;

    // 集計です（ダンプのヘッダ用）
    struct BuildStats {
        int filesSeen = 0;
        int parsedOk = 0;
        int malformed = 0;
        int startable = 0;
        int exTransition = 0;
        int exNoRandom = 0;
        int exZeroActor = 0;
        int exIdle = 0;
        int withRequirements = 0;
        int actionsIndexed = 0;  // "actions"を索引したノード数です（全ノード対象＝Hスキル C++化の土台）
    } g_stats;

    std::string toLower(std::string s) {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return s;
    }

    // OStim GameSexAPI::fromString と同じ規則です（"male"/"female"のみ厳密・他はagender）。
    char normSex(const std::string& raw) {
        const std::string s = toLower(raw);
        if (s == "male") return 'M';
        if (s == "female") return 'F';
        return 'A';
    }

    // 著者順のスロット性別シグネチャです（例 "M,F,F"）。省略スロットは 'M' です（OStim既定）。
    std::string slotSig(const SceneEntry& e) {
        std::string sig;
        for (size_t i = 0; i < e.slots.size(); ++i) {
            if (i) sig += ',';
            sig += e.slots[i].sexNorm;
        }
        return sig;
    }

    // 並び替えたマルチセット（例 "FFM"）＝「誰と」が気にする組です（lineupは並べ替えられますので順不同）。
    std::string sortedCombo(const SceneEntry& e) {
        std::string m;
        for (const auto& s : e.slots) m += s.sexNorm;
        std::sort(m.begin(), m.end());
        return m;
    }

    // 1シーンが指定の性別構成で成立するかどうかです（厳格マッチ＝OStim intendedSexOnly ON 相当）。
    //   実男→M枠/A枠、実女→F枠/A枠、フタ(AGENDER)→全枠。
    //   男枠/女枠の不足を futa で穴埋めできれば成立します（残りはA枠＋余りで埋まります＝同人数バケットですので自動成立）。
    //   A枠は性別制約を課しません＝不足計算から外して構いません（穴埋め側）。
    bool sceneFitsStrict(const SceneEntry& e, int males, int females, int futa) {
        int needM = 0, needF = 0;
        for (const auto& s : e.slots) {
            if (s.sexNorm == 'M') ++needM;
            else if (s.sexNorm == 'F') ++needF;
        }
        const int deficitM = needM > males ? needM - males : 0;
        const int deficitF = needF > females ? needF - females : 0;
        return deficitM + deficitF <= futa;
    }

    // 指定の家具・性別構成で成立するシーンがカタログに在るかどうかです。
    //   strictSex=false＝性別無視（人数が在れば成立します＝OStim unrestrictedNavigation/intendedSexOnly OFF 相当）。
    bool comboPlayableLocked(const std::string& furniture, int males, int females, int futa, bool strictSex) {
        if (males < 0) males = 0;
        if (females < 0) females = 0;
        if (futa < 0) futa = 0;
        const int n = males + females + futa;
        if (n < 1) {
            return false;
        }
        auto fb = g_catalog.find(toLower(furniture));
        if (fb == g_catalog.end()) {
            return false;
        }
        auto cb = fb->second.find(n);
        if (cb == fb->second.end()) {
            return false;
        }
        if (!strictSex) {
            return !cb->second.empty();  // 性別無視＝その人数が在れば成立します
        }
        for (const auto& e : cb->second) {
            if (sceneFitsStrict(e, males, females, futa)) {
                return true;
            }
        }
        return false;
    }

    void BuildLocked() {
        g_catalog.clear();
        g_idleScenes.clear();
        g_sceneSlotSig.clear();
        g_sceneActions.clear();
        g_stats = BuildStats{};

        std::error_code ec;
        fs::path root{ kScenesRoot };
        if (!fs::exists(root, ec)) {
            spdlog::warn("[SceneCatalog] scenes root not found: {}", kScenesRoot);
            return;
        }

        for (auto it = fs::recursive_directory_iterator(root, fs::directory_options::skip_permission_denied, ec);
             it != fs::recursive_directory_iterator(); it.increment(ec)) {
            if (ec) {
                continue;
            }
            const fs::path& p = it->path();
            if (!it->is_regular_file(ec)) {
                continue;
            }
            if (toLower(p.extension().string()) != ".json") {
                continue;
            }
            ++g_stats.filesSeen;

            std::ifstream ifs(p.string());
            // OStim と同じく例外を投げない解析です（壊れたファイルはスキップします）。
            json j = json::parse(ifs, nullptr, false);
            if (j.is_discarded() || !j.is_object()) {
                ++g_stats.malformed;
                continue;
            }
            ++g_stats.parsedOk;

            // --- Hスキル C++化の土台：全ノードの "actions" を索引します（★全除外より前＝transition/noRandom/idle/
            //     zero-actorも対象）。プレイヤーは遷移ノード(-3等)にも居るので、起動可否に関係なく行為を引けるようにします。
            {
                if (j.contains("actions") && j["actions"].is_array()) {
                    const std::string sidLower = toLower(p.filename().replace_extension("").string());
                    std::vector<SceneCatalog::ActionInfo> acts;
                    for (const auto& jx : j["actions"]) {
                        if (!jx.is_object()) {
                            continue;
                        }
                        SceneCatalog::ActionInfo a;
                        if (jx.contains("type") && jx["type"].is_string()) {
                            a.type = toLower(jx["type"].get<std::string>());
                        }
                        if (jx.contains("actor") && jx["actor"].is_number()) {
                            a.actor = jx["actor"].get<int>();
                        }
                        if (jx.contains("target") && jx["target"].is_number()) {
                            a.target = jx["target"].get<int>();
                        }
                        // performer 省略時は actor 既定（OStim準拠・実装時に1回確認）
                        if (jx.contains("performer") && jx["performer"].is_number()) {
                            a.performer = jx["performer"].get<int>();
                        } else {
                            a.performer = a.actor;
                        }
                        acts.push_back(std::move(a));
                    }
                    if (!acts.empty()) {
                        g_sceneActions[sidLower] = std::move(acts);
                        ++g_stats.actionsIndexed;
                    }
                }
            }

            // 除外①：transition（"destination"を持ちます＝遷移ノード）。
            if (j.contains("destination")) {
                ++g_stats.exTransition;
                continue;
            }
            // 除外②：noRandomSelection（ランダム選択から外れます＝起動の入口になりません）。
            if (j.contains("noRandomSelection") && j["noRandomSelection"].is_boolean() && j["noRandomSelection"].get<bool>()) {
                ++g_stats.exNoRandom;
                continue;
            }

            SceneEntry e;
            e.sceneId = p.filename().replace_extension("").string();  // OStim と同じ scene_id 生成

            // 除外③：idleタグ＝静止プレースホルダ（動きません＝アニメではありません・魅了の無駄打ち源）。
            //   カタログには入れないが、IDは g_idleScenes に記憶します（IsIdleScene用）。OStim本体のシーン/
            //   ナビは無改変＝シーン中の移動先としては従来どおり使われます（除外はあくまで候補選定の中だけ）。
            {
                bool isIdle = false;
                if (j.contains("tags") && j["tags"].is_array()) {
                    for (const auto& jt : j["tags"]) {
                        if (jt.is_string() && toLower(jt.get<std::string>()) == "idle") {
                            isIdle = true;
                            break;
                        }
                    }
                }
                if (isIdle) {
                    g_idleScenes.insert(toLower(e.sceneId));
                    ++g_stats.exIdle;
                    continue;
                }
            }

            e.furniture = "none";
            if (j.contains("furniture") && j["furniture"].is_string()) {
                e.furniture = toLower(j["furniture"].get<std::string>());
            }
            if (j.contains("modpack") && j["modpack"].is_string()) {
                e.modpack = j["modpack"].get<std::string>();
            }

            if (j.contains("actors") && j["actors"].is_array()) {
                for (const auto& ja : j["actors"]) {
                    SlotInfo slot;
                    if (ja.is_object()) {
                        if (ja.contains("intendedSex") && ja["intendedSex"].is_string()) {
                            slot.sexRaw = ja["intendedSex"].get<std::string>();
                        }
                        if (ja.contains("type") && ja["type"].is_string()) {
                            slot.type = toLower(ja["type"].get<std::string>());
                        }
                        if (ja.contains("requirements") && ja["requirements"].is_array()) {
                            for (const auto& jr : ja["requirements"]) {
                                if (jr.is_string()) {
                                    slot.requirements.push_back(toLower(jr.get<std::string>()));
                                }
                            }
                        }
                    }
                    slot.sexNorm = slot.sexRaw.empty() ? 'M' : normSex(slot.sexRaw);  // 省略＝OStim既定=male
                    if (!slot.requirements.empty()) {
                        e.hasRequirements = true;
                    }
                    e.slots.push_back(std::move(slot));
                }
            }

            const int count = static_cast<int>(e.slots.size());
            if (count < 1) {
                ++g_stats.exZeroActor;
                continue;
            }

            if (e.hasRequirements) {
                ++g_stats.withRequirements;
            }
            ++g_stats.startable;
            // 著者順スロット性別文字列を記録（GetSlotSex用）＝eをmoveする前に作ります。
            {
                std::string sig;
                for (const auto& s : e.slots) sig += s.sexNorm;
                g_sceneSlotSig[toLower(e.sceneId)] = sig;
            }
            g_catalog[e.furniture][count].push_back(std::move(e));
        }

        spdlog::info("[SceneCatalog] built: files={} parsedOk={} malformed={} startable={} (exTrans={} exNoRand={} exZero={} exIdle={}) withReqs={} actionsIndexed={}",
                     g_stats.filesSeen, g_stats.parsedOk, g_stats.malformed, g_stats.startable,
                     g_stats.exTransition, g_stats.exNoRandom, g_stats.exZeroActor, g_stats.exIdle, g_stats.withRequirements, g_stats.actionsIndexed);
    }

    // 人間可読ダンプを ASTR2_CatalogDump.txt（SKSEログフォルダ）へ書きます。
    void DumpToFileLocked() {
        auto logsFolder = SKSE::log::log_directory();
        if (!logsFolder) {
            spdlog::warn("[SceneCatalog] no log directory, skip dump");
            return;
        }
        const auto dumpPath = *logsFolder / "ASTR2_CatalogDump.txt";
        std::ofstream out(dumpPath.string(), std::ios::trunc);
        if (!out) {
            spdlog::warn("[SceneCatalog] cannot open dump file");
            return;
        }

        out << "=== ASTR2 OStim Scene Catalog ===\n";
        out << "scenes root : " << kScenesRoot << "\n";
        out << "files seen  : " << g_stats.filesSeen
            << " | parsed ok : " << g_stats.parsedOk
            << " | malformed : " << g_stats.malformed << "\n";
        out << "startable   : " << g_stats.startable
            << " | excluded(transition) : " << g_stats.exTransition
            << " | excluded(noRandomSelection) : " << g_stats.exNoRandom
            << " | excluded(idle/static) : " << g_stats.exIdle
            << " | zero-actor : " << g_stats.exZeroActor << "\n";
        out << "scenes with per-slot requirements : " << g_stats.withRequirements << "\n";
        out << "actions indexed (all nodes, incl. transition/idle) : " << g_stats.actionsIndexed << "\n";
        out << "legend: per-slot intendedSex in authored order. M=male F=female A=agender/any."
               " absent intendedSex => 'M' (OStim defaults to male).\n";
        out << "========================================================\n\n";

        for (const auto& [furniture, byCount] : g_catalog) {
            int furnitureTotal = 0;
            for (const auto& [cnt, vec] : byCount) furnitureTotal += static_cast<int>(vec.size());
            out << "[furniture = " << furniture << "]  (startable scenes: " << furnitureTotal << ")\n";

            for (const auto& [cnt, vec] : byCount) {
                out << "  -- " << cnt << "P  (" << vec.size() << " scenes)\n";

                // ① 並び替えマルチセット集計（「誰と」が在るか一目で）
                std::map<std::string, int> comboCounts;
                for (const auto& e : vec) comboCounts[sortedCombo(e)]++;
                out << "     combos: ";
                bool first = true;
                for (const auto& [combo, n] : comboCounts) {
                    if (!first) out << ", ";
                    out << combo << "x" << n;
                    first = false;
                }
                out << "\n";

                // ② 著者順シグネチャ別の内訳＋例（生データの裏取り用）
                std::map<std::string, std::vector<std::string>> bySig;
                for (const auto& e : vec) bySig[slotSig(e)].push_back(e.sceneId);
                for (auto& [sig, ids] : bySig) {
                    std::sort(ids.begin(), ids.end());
                    out << "       " << sig << " : " << ids.size() << "   e.g. ";
                    for (size_t i = 0; i < ids.size() && i < 3; ++i) {
                        if (i) out << ", ";
                        out << ids[i];
                    }
                    out << "\n";
                }
            }
            out << "\n";
        }

        // --- combo判定の自己テスト真理値表（strictSex=true）＝アルゴリズムの裏取り（実機Papyrus配線不要） ---
        //   家具noneの各人数で、全(男,女,futa)分割を総当たり＝上のcombos一覧と突き合わせて正否を目視確認できます。
        out << "=== combo feasibility self-test [furniture=none, strictSex=true] ===\n";
        out << "(format: M<males> F<females> U<futa> -> YES/no)\n";
        {
            auto fb = g_catalog.find("none");
            if (fb != g_catalog.end()) {
                for (const auto& [cnt, vec] : fb->second) {
                    out << "  -- " << cnt << "P\n";
                    for (int males = 0; males <= cnt; ++males) {
                        for (int females = 0; females <= cnt - males; ++females) {
                            const int futa = cnt - males - females;
                            const bool ok = comboPlayableLocked("none", males, females, futa, true);
                            out << "     M" << males << " F" << females << " U" << futa
                                << " -> " << (ok ? "YES" : "no") << "\n";
                        }
                    }
                }
            }
        }
        out << "\n";

        out.flush();
        spdlog::info("[SceneCatalog] dump written: {}", dumpPath.string());
    }

    // ===== Papyrus native: ASTR2Catalog.AvailableCounts(furniture) =====
    //   その家具で1件以上シーンが在る人数を昇順で返します（「何P」段）。家具が無ければ空配列です。
    std::vector<std::int32_t> Papyrus_AvailableCounts(RE::StaticFunctionTag*, RE::BSFixedString furniture) {
        std::vector<std::int32_t> out;
        std::lock_guard lk(g_mutex);
        auto fb = g_catalog.find(toLower(std::string(furniture.c_str())));
        if (fb != g_catalog.end()) {
            for (const auto& [cnt, vec] : fb->second) {  // map<int,...> は昇順イテレート
                if (!vec.empty()) {
                    out.push_back(cnt);
                }
            }
        }
        return out;
    }

    // ===== Papyrus native: ASTR2Catalog.OStimStrictSex() =====
    //   OStimのMCM実設定から「性別を厳格マッチすべきか」を返します＝ComboPlayable(strictSex)へ正しい値を渡す用です。
    //   unrestrictedNavigation ON（全条件スキップ）→ false（性別無視）／それ以外は intendedSexOnly の値です。
    //   API未取得（OStim不在）は安全側 true です（＝厳格＝おかしな異性混成を作らせません）。
    bool Papyrus_OStimStrictSex(RE::StaticFunctionTag*) {
        auto* api = OStimApi();
        if (!api) {
            return true;
        }
        if (api->IsUnrestrictedNavigation()) {
            return false;
        }
        return api->IsIntendedSexOnly();
    }

    // ===== Papyrus native: ASTR2Catalog.ComboPlayable(furniture, males, females, futa, strictSex) =====
    //   その性別構成で成立するシーンがカタログに在るかどうかです（「誰と」段）。判定は comboPlayableLocked を参照してください。
    //   ★設定(intendedSexOnly/futaUseMaleRole)はここでは読みません＝strictSexとmales/females/futaの仕分けは
    //   呼び手(Papyrus)の責任です＝当面は決め打ち(true)、将来OStim設定を読んで渡す形に差し替え可能です(dll再ビルド不要)。
    bool Papyrus_ComboPlayable(RE::StaticFunctionTag*, RE::BSFixedString furniture,
                               std::int32_t males, std::int32_t females, std::int32_t futa, bool strictSex) {
        std::lock_guard lk(g_mutex);
        if (g_catalog.empty()) {
            BuildLocked();
        }
        return comboPlayableLocked(std::string(furniture.c_str()), males, females, futa, strictSex);
    }

    // ===== Papyrus native: ASTR2Catalog.IsIdleScene(sceneId) =====
    //   そのscene_idが idleタグ（静止プレースホルダ）かどうかです。Papyrusランチャーが GetRandomScene の返りを
    //   これで弾き、実アニメだけ起動します（idle-onlyコンボは候補に出しません／起動先にもしません）。
    bool Papyrus_IsIdleScene(RE::StaticFunctionTag*, RE::BSFixedString sceneId) {
        std::lock_guard lk(g_mutex);
        if (g_catalog.empty() && g_idleScenes.empty()) {
            BuildLocked();
        }
        return g_idleScenes.find(toLower(std::string(sceneId.c_str()))) != g_idleScenes.end();
    }

    // ===== Papyrus native: ASTR2Catalog.GetSlotSex(sceneId, pos) =====
    //   そのシーンの位置(pos)のスロット性別を "M"/"F"/"A" で返します（無効なら ""）。
    //   Papyrusが「プレイヤーがその位置で男か女か」を役メニューに表示するのに使います。
    RE::BSFixedString Papyrus_GetSlotSex(RE::StaticFunctionTag*, RE::BSFixedString sceneId, std::int32_t pos) {
        std::lock_guard lk(g_mutex);
        auto it = g_sceneSlotSig.find(toLower(std::string(sceneId.c_str())));
        if (it == g_sceneSlotSig.end() || pos < 0 || pos >= static_cast<int>(it->second.size())) {
            return "";
        }
        return std::string(1, it->second[pos]);
    }
}

namespace SceneCatalog {
    void Build() {
        std::lock_guard lk(g_mutex);
        BuildLocked();
        DumpToFileLocked();  // ロードで自動ダンプ＝ゲームを起動するだけで中身を確認できます。
    }

    // Hスキル C++化の契約：任意ノード(小文字sceneId)の行為リストです。未収録は nullptr です。
    // ★返り値はカタログ内部へのポインタ＝Build()/Refresh()は起動時1回が前提（読み中の作り直しは想定しません）。
    const std::vector<ActionInfo>* GetActionsForScene(const std::string& sceneIdLower) {
        std::lock_guard lk(g_mutex);
        auto it = g_sceneActions.find(sceneIdLower);
        if (it == g_sceneActions.end()) {
            return nullptr;
        }
        return &it->second;
    }

    void ForEachSceneActions(const std::function<void(const std::string&, const std::vector<ActionInfo>&)>& fn) {
        std::lock_guard lk(g_mutex);
        for (const auto& [sid, acts] : g_sceneActions) {
            fn(sid, acts);
        }
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("AvailableCounts", "ASTR2Catalog", Papyrus_AvailableCounts);
        vm->RegisterFunction("ComboPlayable", "ASTR2Catalog", Papyrus_ComboPlayable);
        vm->RegisterFunction("OStimStrictSex", "ASTR2Catalog", Papyrus_OStimStrictSex);
        vm->RegisterFunction("IsIdleScene", "ASTR2Catalog", Papyrus_IsIdleScene);
        vm->RegisterFunction("GetSlotSex", "ASTR2Catalog", Papyrus_GetSlotSex);
        spdlog::info("[SceneCatalog] Papyrus native AvailableCounts / ComboPlayable / OStimStrictSex / IsIdleScene / GetSlotSex 登録");
        return true;
    }
}
