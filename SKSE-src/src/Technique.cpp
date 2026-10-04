#include "PCH.h"
#include "Technique.h"
#include "SceneCatalog.h"   // SceneCatalog::ActionInfo / GetActionsForScene（行為索引を提供）
#include "TechRank.h"       // ★ランク層(C++)＝シーン終了時にこのシーンの秒を〔SkyVault〕へ永続＋キャッシュ再構築
#include "TechHud.h"        // ★Phase2＝H中「今なにが育ってるか」ライブHUD（シーン開始/終了で表示ON/OFF）
#include "SceneGuard.h"     // ★H中セーフティ＝近接敵を検知して当たる前にシーンを畳む（CTD回避）
#include "SkyVaultAPI.h"    // ★傲慢ネイル＝確定秒の割増率を〔SkyVault〕から読みます

#include <Windows.h>
#include "external/OstimNG-API-Thread.h"

#include <array>
#include <map>
#include <vector>
#include <mutex>
#include <chrono>
#include <string>
#include <cctype>

// ============================================================================
// Hスキルランク化(C++) ― なぜC++：OStimは元々重い→負荷を増やさない／Papyrus二重イベントで
//   held秒が2倍になるバグの根治です。設計＝NodeChanged(OStim公開API・1本)で体位変化を拾い、
//   SceneCatalog の行為索引を引いて攻め/受け＋技術カテゴリへ held秒 を累積します。全部C++です。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//
//   ★加算ルール(skill-map確定)：
//     ・技術6カテゴリ＝行為名で固定です。やる側(actor)のみです／ただし挿入系(腰使い)は受け側(挿入され)も対象です。
//       奉仕を「される側」(フェラされる等)は技術の持ち主ではないので、加算しません。
//     ・S/M＝挿入系・facial は performer で動的(自分=攻めS/相手=受けM)／奉仕(口舌[DT除く]/手技/その他)=S固定／
//       deepthroat=M固定／自慰・キス=S/Mなしです。
//
//   永続：シーン終了時に TechRank(C++) がこのシーンの秒を 〔SkyVault〕 の確定秒へ自己完結で足します
//        (Papyrus往復なし)。〔SkyVault〕はコセーブ永続なので、セーブ跨ぎ/セイレーン共有もそのまま効きます。
// ============================================================================

namespace {
    using namespace OstimNG_API::Thread;
    IThreadInterface* g_api = nullptr;

    // 8カテゴリ indexです（〔SkyVault〕キー ASTR2_TechSec_{...} と対応）
    enum Cat : int { HIPS = 0, MOUTH = 1, HAND = 2, OTHER = 3, SOLO = 4, KISS = 5, ATTACK_S = 6, RECEIVE_M = 7, CAT_COUNT = 8 };
    const char* kCatName[CAT_COUNT] = { "Hips", "Mouth", "Hand", "Other", "Solo", "Kiss", "AttackS", "ReceiveM" };

    std::mutex g_mutex;
    std::array<float, CAT_COUNT> g_sec{};              // このシーンの累積秒です（8カテゴリ集計・既存）

    // ★Ver2：行為別(孫)累積です。各行為の秒を 攻めS/受けM/中立(自慰キス) に分けて貯めます。
    //   孫ランク=S+M+中立／攻め技=選択行為のS合計／受け技=同M合計（指向フィルタはPapyrus側）。
    struct ActSec { float s = 0.0f, m = 0.0f, neu = 0.0f; };
    std::map<std::string, ActSec> g_act;               // key = 行為名(lowercase)
    uint32_t g_trackedThread = 0;                      // プレイヤー参加中の追跡スレッドです(0=なし)
    bool g_inScene = false;
    bool g_exciteOn = false;                           // ★Hスキル→興奮ブースト有効です(Papyrusが強さ>0でtrue)
    int g_curActionCat = -1;                           // ★今/直近ノードでプレイヤーがしてる技術行為のcat(0-5)です。ドレインが「イカせ行為」で参照します。不明=-1
    constexpr float kOrgasmBonusSec = 10.0f;           // ★相手をイカせた時に今の行為(孫)へ足す報酬秒です（定数・後でMCM化も可）
    std::string g_prevScene;                           // 直前ノードの scene_id です
    int g_prevPos = -1;                                // 直前ノードでのプレイヤー位置です
    std::chrono::steady_clock::time_point g_prevTime;  // 直前ノードに入った実時刻です

    inline std::string toLower(std::string s) {
        for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        return s;
    }
    inline uint32_t playerFormID() {
        auto* pc = RE::PlayerCharacter::GetSingleton();
        return pc ? pc->GetFormID() : 0x14;
    }
    inline float secSince(std::chrono::steady_clock::time_point t0) {
        return std::chrono::duration<float>(std::chrono::steady_clock::now() - t0).count();
    }

    // 行為→技術6カテゴリ index です（該当なし=facial/cumon*/holding材料/無視 は -1）。skill-map確定表です。
    int techCat(const std::string& t) {
        if (t == "vaginalsex" || t == "analsex" || t == "tribbing" || t == "buttsmothering") return HIPS;
        if (t == "blowjob" || t == "deepthroat" || t == "cunnilingus" || t == "lickingvagina" || t == "lickingpenis" || t == "lickingtesticles" || t == "lickingnipple" || t == "suckingnipple" || t == "anilingus" || t == "rimjob") return MOUTH;
        if (t == "handjob" || t == "vaginalfingering" || t == "analfingering" || t == "vaginalfisting" || t == "analfisting" || t == "rubbingclitoris" || t == "gropingbreast" || t == "gropingbutt" || t == "gropingtesticles" || t == "oralfingering" || t == "vaginaltoying" || t == "analtoying" || t == "mdildovaginal" || t == "mdildoanal" || t == "spanking" || t == "choking") return HAND;
        if (t == "boobjob" || t == "footjob" || t == "thighjob" || t == "buttjob" || t == "rubbingpenisagainstface" || t == "toy" || t == "ejaculation" || t == "vampirebite" || t == "teasing" || t == "massaging" || t == "breastsliding" || t == "breastsmothering" || t == "tailtech") return OTHER;
        if (t == "grindingpenis" || t == "grindingthigh" || t == "grindingfoot" || t == "grindingobject" || t == "femalemasturbation" || t == "malemasturbation") return SOLO;
        if (t == "kissing" || t == "frenchkissing" || t == "kissingcheek" || t == "kissingfoot" || t == "kissinghand" || t == "kissingneck") return KISS;
        return -1;
    }

    // S/M index です（6=AttackS 7=ReceiveM 該当なし=-1）。cat は techCat の結果です。
    int smCat(const std::string& t, bool isActor, bool isTarget, bool isPerf, int cat) {
        if (t == "vaginalsex" || t == "analsex" || t == "tribbing" || t == "ejaculation") {
            if (isActor || isTarget || isPerf) return isPerf ? ATTACK_S : RECEIVE_M;  // performer=自分→攻め/相手→受け（射精=旧facialのS/M挙動を継承）
            return -1;
        }
        if (t == "deepthroat") return isActor ? RECEIVE_M : -1;                       // 受け入れる技=M固定
        if (isActor && (cat == MOUTH || cat == HAND || cat == OTHER)) return ATTACK_S;  // 奉仕=S固定・やる側のみ
        return -1;
    }

    // 生のOStim行為名を「45孫」の正規名へ寄せます（パック独自の派生を本体に統合＝孫キーが孤立しません）。
    //   ①"3pp_"等の接頭辞＋末尾連番を剥がします ②"○○fellatio"→フェラ等、含む行為名で本体へ
    //   ③綴りゆれ・統合（耳舐め→乳首舐め／顔射ejaculation→facial／指咥え自慰→女オナ）。
    std::string canonAction(std::string t) {
        if (t.rfind("3pp_", 0) == 0) t = t.substr(4);                         // 接頭辞剥がし
        while (!t.empty() && std::isdigit(static_cast<unsigned char>(t.back()))) t.pop_back();  // 末尾連番(kissfellatio1/2)
        if (t.find("fellatio") != std::string::npos)    return "blowjob";     // ○○フェラ→フェラ
        if (t.find("cunnilingus") != std::string::npos) return "cunnilingus"; // クンニ○○→クンニ
        if (t == "lickingnipples")        return "lickingnipple";             // 複数形
        if (t == "suckingnipples")        return "suckingnipple";
        if (t == "kissingfeet")           return "kissingfoot";
        if (t == "lickingear")            return "lickingnipple";             // 耳舐め＝舐め技に統合
        if (t == "fingerinmouthmasturbation") return "femalemasturbation";    // 指咥え自慰＝女オナに統合
        if (t == "rimjob")                return "anilingus";                 // ★アナル舐め＝同義語を1孫に統合
        // ★孫リスト54拡張に伴う統合
        if (t == "vampirebiting")         return "vampirebite";              // 吸血（別綴り）
        if (t == "boobsmothering")        return "breastsmothering";         // 乳窒息（別綴り）
        if (t == "breastslapping")        return "spanking";                 // 乳叩き＝スパンキングへ統合
        if (t == "oraltoying")            return "blowjob";                  // 口内おもちゃ＝フェラ扱い（＋玩具は副加算）
        if (t == "facial" || t == "ejaculation_on_face" ||                   // 顔射→射精へ統合
            t == "cumonchest" || t == "cumonbutt" || t == "cumonvulva" ||    // 胸射/尻射/陰部射→射精
            t == "ejaculation_on_chest" || t == "ejaculation_on_butt" || t == "ejaculation_on_vulva") return "ejaculation";
        if (t == "cumonhands" || t == "ejaculation_on_hands") return "handjob"; // テコキ射精＝テコキ（＋射精は副加算）
        if (t == "tailjob" || t == "massagingtail" || t == "analtailsex" || t == "vaginaltailsex") return "tailtech"; // 尻尾技へ統合
        // ★7.5.1b リネーム版→旧正規名（シーンは旧名が主流so旧名へ寄せます＝採点漏れ防止）
        if (t == "deepthroating")     return "deepthroat";
        if (t == "vulvaleating")      return "cunnilingus";
        if (t == "vulvallicking")     return "lickingvagina";
        if (t == "penilelicking")     return "lickingpenis";
        if (t == "testicularlicking") return "lickingtesticles";
        if (t == "anallicking")       return "anilingus";
        if (t == "vulvalrubbing")     return "rubbingclitoris";
        return t;
    }

    // ★生type→素の名前です（"3pp_"接頭辞と末尾連番だけ剥がします＝副加算の判定用）。
    inline std::string rawBaseName(std::string t) {
        t = toLower(t);
        if (t.rfind("3pp_", 0) == 0) t = t.substr(4);
        while (!t.empty() && std::isdigit(static_cast<unsigned char>(t.back()))) t.pop_back();
        return t;
    }
    // ★横断スキルの副加算（g_mutex を握った状態で呼びます）。玩具＝おもちゃ系を使う人／射精＝テコキ射精の両者です。
    //   中立(neu)で足します＝攻め技/受け技の合計(=孫のS/M総和)を膨らませず、当該孫と種目(その他)の表示ランクだけ伸ばします。
    inline void creditCrossSkillLocked(const std::string& rawBase, bool isActor, bool isTarget, bool techCredit, float amt) {
        if (techCredit && (rawBase == "vaginaltoying" || rawBase == "analtoying" || rawBase == "oraltoying" ||
                           rawBase == "mdildovaginal" || rawBase == "mdildoanal"))
            g_act["toy"].neu += amt;                                  // 玩具（横断）＝おもちゃを使った側
        if ((isActor || isTarget) && (rawBase == "cumonhands" || rawBase == "ejaculation_on_hands"))
            g_act["ejaculation"].neu += amt;                          // テコキ射精＝手コキした側/竿持ち側の両方に射精
    }

    // 直前ノードの held秒 をカタログの行為索引から判定して累積します。
    void CommitSegment(const std::string& sceneId, int pos, float held) {
        if (held <= 0.0f || pos < 0 || sceneId.empty()) return;
        const auto* actions = SceneCatalog::GetActionsForScene(toLower(sceneId));
        if (!actions) return;  // カタログ未収録です（行為索引の未収録 or 未知シーン）
        std::string dbg;
        std::lock_guard<std::mutex> lk(g_mutex);
        for (const auto& a : *actions) {
            const bool isActor = (a.actor == pos);
            const bool isTarget = (a.target == pos);
            const bool isPerf = (a.performer == pos);
            const std::string t = canonAction(a.type);   // ★派生名を45孫の正規名へ寄せます
            const int cat = techCat(t);
            bool techCredit = false;
            if (cat == HIPS) techCredit = isActor || isTarget;  // 挿入系は受け(挿入され)も腰使いです
            else if (cat >= 0) techCredit = isActor;            // 奉仕/自慰/キスはやる側だけです
            const int sm = smCat(t, isActor, isTarget, isPerf, cat);
            if (techCredit) { g_sec[cat] += held; dbg += kCatName[cat]; dbg += ' '; }  // 技術カテゴリ秒です（既存8集計）
            // ★Ver2 行為別(孫)：S/Mは sm で記録（facial等＝技術カテゴリ無しでも攻め受けには属します）／
            //   中立(自慰キス)は techCredit時のみです。★加算がある時だけ孫キーを作ります(カラのキー(着弾/材料)は残しません)。
            if (sm == ATTACK_S)       g_act[t].s   += held;
            else if (sm == RECEIVE_M) g_act[t].m   += held;
            else if (techCredit)      g_act[t].neu += held;    // 自慰・キス＝中立
            if (sm >= 0) { g_sec[sm] += held; dbg += kCatName[sm]; dbg += ' '; }       // S/M集計です（既存8集計）
            creditCrossSkillLocked(rawBaseName(a.type), isActor, isTarget, techCredit, held);   // ★横断：玩具/テコキ射精
        }
        spdlog::info("[Technique] accrue {:.1f}s scene={} pos={} -> [{}]", held, sceneId, pos, dbg);
    }

    // ★今ノードでプレイヤーが「クレジットされる(=Hスキル秒が入る)」技術行為のcat(0-5)を1個拾って g_curActionCat へ格納します。
    //   ドレインが相手オーガズム時に GetCurrentActionCat() で参照します（イカせ行為で威力可変）。判定はCommitSegmentと同じ
    //   クレジット規則です（挿入HIPSは受けalso／他は actor のみ）。複数行為時は最初の1個です。該当無し=-1。
    void UpdateCurActionCat(const std::string& sceneId, int pos) {
        int cat = -1;
        const auto* actions = SceneCatalog::GetActionsForScene(toLower(sceneId));
        if (actions && pos >= 0) {
            for (const auto& a : *actions) {
                const bool isActor = (a.actor == pos);
                const bool isTarget = (a.target == pos);
                const int c = techCat(canonAction(a.type));
                const bool credit = (c == HIPS) ? (isActor || isTarget) : (c >= 0 && isActor);
                if (credit) { cat = c; break; }
            }
        }
        std::lock_guard<std::mutex> lk(g_mutex);
        g_curActionCat = cat;
    }

    // ★Hスキル→興奮ブースト：今のノードでプレイヤーが"相手に"してる技術行為を相手ごとにまとめ、
    //   行為名(カンマ連結)を modイベントでPapyrusへ渡します（Papyrusが孫ランク平均→倍率→OActor.SetExcitementMultiplier）。
    //   C++は重い計算をせず「相手＋行為名」を渡すだけです＝OStim中も軽いです。g_exciteOn=false(強さ0)なら何もしません。
    //   ★g_mutex は持ちません（OStim API＋SendEvent＝Papyrus再入があり得ます／g_sec/g_actには触れません）。
    void FireExciteForNode(uint32_t threadID, const std::string& sceneId, int playerPos) {
        if (!g_exciteOn || !g_api || playerPos < 0 || sceneId.empty()) return;
        const auto* actions = SceneCatalog::GetActionsForScene(toLower(sceneId));
        if (!actions) return;
        ActorData buf[8];
        uint32_t n = g_api->GetActors(threadID, buf, 8);
        if (n == 0) return;
        std::map<int, std::string> byTarget;   // 相手position -> その相手にしてる技術行為名(カンマ連結)
        for (const auto& a : *actions) {
            if (a.actor != playerPos) continue;            // プレイヤーが"する側"の行為だけ
            if (a.target < 0 || a.target == playerPos) continue;
            const std::string t = canonAction(a.type);
            if (techCat(t) < 0) continue;                  // ランクのある技術行為だけ(holding/材料/facialは除外)
            std::string& s = byTarget[a.target];
            if (!s.empty()) s += ',';
            s += t;
        }
        for (const auto& kv : byTarget) {
            int tpos = kv.first;
            if (tpos >= static_cast<int>(n)) continue;
            auto* form = RE::TESForm::LookupByID(buf[tpos].formID);
            if (!form) continue;
            SKSE::ModCallbackEvent ev{};
            ev.eventName = "ASTR2_ExciteNode";
            ev.strArg = kv.second.c_str();   // 行為名(カンマ連結)
            ev.numArg = 0.0f;
            ev.sender = form;                // 相手アクター
            if (auto* src = SKSE::GetModCallbackEventSource()) {
                src->SendEvent(&ev);
            }
            spdlog::info("[Technique] excite -> partner pos={} acts=[{}]", tpos, kv.second);
        }
    }

    // --- OStimスレッドイベント（AddTaskで次フレームへ＝シーン形成ロックとの再入デッドロック回避） ---
    void HandleStart(uint32_t threadID) {
        if (!g_api) return;
        const int pos = g_api->GetActorPosition(threadID, playerFormID());
        if (pos < 0) return;  // プレイヤー不参加シーン＝Hスキル対象外です
        const char* s = g_api->GetCurrentSceneID(threadID);
        std::string scene = s ? s : "";
        {
            std::lock_guard<std::mutex> lk(g_mutex);
            g_sec.fill(0.0f);
            g_act.clear();
            g_trackedThread = threadID;
            g_inScene = true;
            g_prevScene = scene;
            g_prevPos = pos;
            g_prevTime = std::chrono::steady_clock::now();
        }
        spdlog::info("[Technique] >>> scene start thread={} pos={} node={}", threadID, pos, scene);
        FireExciteForNode(threadID, scene, pos);   // ★開始ノードの興奮ブーストです
        UpdateCurActionCat(scene, pos);            // ★ドレイン用：今の行為catです
        TechHud::OnSceneStart();                   // ★Phase2 HUD：H中ライブ表示ONです（有効なら）
        SceneGuard::OnSceneStart(threadID);        // ★H中セーフティ監視ONです（近接敵検知→強制終了）
    }

    void HandleNodeChange(uint32_t threadID) {
        if (!g_api || !g_inScene || threadID != g_trackedThread) return;
        const char* s = g_api->GetCurrentSceneID(threadID);
        std::string cur = s ? s : "";
        const int pos = g_api->GetActorPosition(threadID, playerFormID());
        std::string prevScene; int prevPos; std::chrono::steady_clock::time_point prevTime;
        {
            std::lock_guard<std::mutex> lk(g_mutex);
            if (cur == g_prevScene && pos == g_prevPos) return;  // 同一ノード(念のため)＝計測継続です
            prevScene = g_prevScene; prevPos = g_prevPos; prevTime = g_prevTime;
            g_prevScene = cur; g_prevPos = pos; g_prevTime = std::chrono::steady_clock::now();
        }
        CommitSegment(prevScene, prevPos, secSince(prevTime));  // ノードが変わりました＝直前ノードを確定します
        FireExciteForNode(threadID, cur, pos);                  // ★新ノードの興奮ブーストです（相手＋行為名をPapyrusへ）
        UpdateCurActionCat(cur, pos);                           // ★ドレイン用：今の行為catを更新します
    }

    void HandleEnd(uint32_t threadID) {
        if (!g_inScene || threadID != g_trackedThread) return;
        std::string prevScene; int prevPos; std::chrono::steady_clock::time_point prevTime;
        {
            std::lock_guard<std::mutex> lk(g_mutex);
            prevScene = g_prevScene; prevPos = g_prevPos; prevTime = g_prevTime;
            g_inScene = false;
            g_trackedThread = 0;
            g_curActionCat = -1;   // ★シーン終了＝今の行為catをクリアします
        }
        CommitSegment(prevScene, prevPos, secSince(prevTime));  // 最後のノードを確定します

        // ★このシーンの秒をスナップショット＋ログ→即クリアします（以後ライブ秒は0です）。ここで g_mutex を解放してから
        //   TechRank(=別mutex)を呼びます＝2つのmutexを同時に握りません（デッドロック回避）。
        std::array<float, CAT_COUNT> catSnap{};
        struct ActSnap { std::string name; float s, m, neu; };
        std::vector<ActSnap> actSnap;
        {
            std::lock_guard<std::mutex> lk(g_mutex);
            std::string tot;
            for (int i = 0; i < CAT_COUNT; ++i) {
                catSnap[i] = g_sec[i];
                if (g_sec[i] > 0.0f) { tot += kCatName[i]; tot += '='; tot += std::to_string(static_cast<int>(g_sec[i])); tot += "s "; }
            }
            // ★Ver2：行為別(孫)の集計もスナップ＋ログします（実機で S/M/中立 の振り分けを目視検証）。
            std::string acts;
            for (const auto& kv : g_act) {
                const auto& a = kv.second;
                actSnap.push_back(ActSnap{ kv.first, a.s, a.m, a.neu });
                acts += kv.first; acts += "(";
                if (a.s   > 0.0f) { acts += "S="; acts += std::to_string(static_cast<int>(a.s));   acts += ' '; }
                if (a.m   > 0.0f) { acts += "M="; acts += std::to_string(static_cast<int>(a.m));   acts += ' '; }
                if (a.neu > 0.0f) { acts += "N="; acts += std::to_string(static_cast<int>(a.neu)); acts += ' '; }
                acts += ") ";
            }
            spdlog::info("[Technique] <<< scene end totals: [{}]", tot);
            spdlog::info("[Technique] <<< action totals: [{}]", acts);
            g_sec.fill(0.0f);   // ★確定は TechRank が 〔SkyVault〕 へ足します＝ここでライブをクリアします（二重計上防止）
            g_act.clear();
        }

        // 💅 傲慢のネイル(idx1)＝Hスキルの確定秒を割り増しします（実の行為秒より多く技術秒が貯まります＝早く上達）。
        //   ・有効判定＝NailManagerが公開する 〔SkyVault〕 "ASTR2_NailActive_1"==1。
        //   ・割増率＝Lv連動 線形＝Max×Lv/100（〔SkyVault〕 "ASTR2_NailPrideTechMax" 既定50）＝Lv100で+50%／Lv1で+0.5%。
        //     話術側 ASTR2_NailPrideSpeechMax(100=Lv100で×2) とは別キー・別倍率です。Lv取得は SkillXpBoost::NailSucLv と同式です(Global 0x000D64)。
        //   ・〔SkyVault〕へ足す直前(snapshot)にだけ掛けます＝ライブ秒g_sec/HUDは素の値のまま＝二重計上には触りません（コミット1点）。
        //   ・cat/action両方に同率＝子/親ランク(孫から算出)と整合を保ちます。
        if (auto* sv = SkyVaultAPI::GetSkyVaultAPI()) {
            if (sv->GetInt(0, "ASTR2_NailActive_1", 0) == 1) {
                int lv = 1;   // サキュバスLv 1..100（話術側と同式）
                if (auto* dh = RE::TESDataHandler::GetSingleton())
                    if (auto* g = dh->LookupForm<RE::TESGlobal>(0x000D64, "A Succubus Tale R2.esp")) {
                        lv = static_cast<int>(g->value);
                        lv = lv < 1 ? 1 : (lv > 100 ? 100 : lv);
                    }
                int pct = sv->GetInt(0, "ASTR2_NailPrideTechMax", 50) * lv / 100;   // Lv連動 線形（Lv100でMax%）
                float mult = 1.0f + static_cast<float>(pct) / 100.0f;
                for (int i = 0; i < CAT_COUNT; ++i) catSnap[i] *= mult;
                for (auto& a : actSnap) { a.s *= mult; a.m *= mult; a.neu *= mult; }
                spdlog::info("[Technique] 傲慢ネイル：確定秒 ×{:.2f} (Lv{})", mult, lv);
            }
        }

        // ★回収の自己完結（Papyrus往復を廃止）：このシーンの秒を 〔SkyVault〕 の確定秒へ足す→キャッシュ再構築します。
        for (int i = 0; i < CAT_COUNT; ++i) TechRank::PersistSceneCat(i, catSnap[i]);
        for (const auto& a : actSnap) {
            TechRank::PersistSceneAction(a.name.c_str(), 0, a.s);
            TechRank::PersistSceneAction(a.name.c_str(), 1, a.m);
            TechRank::PersistSceneAction(a.name.c_str(), 2, a.neu);
        }
        TechRank::RebuildCacheFromVault();

        // ★シーン集計完了の合図は残します（互換・将来フック用／Papyrus側の回収呼びは撤去済）。
        SKSE::ModCallbackEvent ev{};
        ev.eventName = "ASTR2_TechSceneReady";
        ev.numArg = 0.0f;
        if (auto* src = SKSE::GetModCallbackEventSource()) {
            src->SendEvent(&ev);
        }
        TechHud::OnSceneEnd();   // ★Phase2 HUD：H中ライブ表示OFF＋消灯します
        SceneGuard::OnSceneEnd();   // ★H中セーフティ監視OFFです
    }

    void OnThreadEvent(ThreadEvent eventType, uint32_t threadID, void* /*userData*/) {
        switch (eventType) {
        case ThreadEvent::ThreadStarted: SKSE::GetTaskInterface()->AddTask([threadID]() { HandleStart(threadID); }); break;
        case ThreadEvent::NodeChanged:   SKSE::GetTaskInterface()->AddTask([threadID]() { HandleNodeChange(threadID); }); break;
        case ThreadEvent::ThreadEnded:   SKSE::GetTaskInterface()->AddTask([threadID]() { HandleEnd(threadID); }); break;
        default: break;  // ControlInput は無視します
        }
    }

    // ===== Papyrus native（ASTR2Technique.*）=====

    // ★興奮ブーストの有効/無効です（Papyrusがシーン開始時に 強さ>0 なら true をセット＝offなら C++ は何も飛ばしません）。
    void Papyrus_SetExciteEnabled(RE::StaticFunctionTag*, bool on) {
        g_exciteOn = on;
    }

    // ★相手をイカせた報酬＝今ノードでプレイヤーがしてる技術行為(孫)へ固定秒を加算します（CommitSegmentと同じクレジット規則）。
    //   子/親ランクは孫から算出so、孫に足せば全階層へ波及します。ADD分は TechRank::PersistSceneAction が回収時に永続累積へ流します。
    //   相手イカせ毎回1回です（Papyrus側で Act!=player かつ playerInvolved をゲート）。sceneId/pos は orgasm時の今ノードです。
    void Papyrus_AddOrgasmBonus(RE::StaticFunctionTag*, RE::BSFixedString sceneId, std::int32_t pos) {
        if (pos < 0) return;
        const std::string sc = toLower(std::string(sceneId.c_str()));
        const auto* actions = SceneCatalog::GetActionsForScene(sc);
        if (!actions) return;
        const float bonus = kOrgasmBonusSec;
        std::string dbg;
        std::lock_guard<std::mutex> lk(g_mutex);
        for (const auto& a : *actions) {
            const bool isActor = (a.actor == pos);
            const bool isTarget = (a.target == pos);
            const bool isPerf = (a.performer == pos);
            const std::string t = canonAction(a.type);
            const int cat = techCat(t);
            bool techCredit = false;
            if (cat == HIPS) techCredit = isActor || isTarget;   // 挿入系は受け(挿入され)も腰使いです
            else if (cat >= 0) techCredit = isActor;             // 奉仕/自慰/キスはやる側だけです
            const int sm = smCat(t, isActor, isTarget, isPerf, cat);
            if (techCredit) g_sec[cat] += bonus;                 // 技術カテゴリ秒です（既存8集計）
            if (sm == ATTACK_S)       g_act[t].s   += bonus;     // 孫：攻めSです
            else if (sm == RECEIVE_M) g_act[t].m   += bonus;     // 孫：受けMです
            else if (techCredit)      g_act[t].neu += bonus;     // 孫：中立(自慰キス)です
            if (sm >= 0) g_sec[sm] += bonus;                     // S/M集計です（既存8集計）
            if (techCredit || sm >= 0) { dbg += t; dbg += ' '; }
            creditCrossSkillLocked(rawBaseName(a.type), isActor, isTarget, techCredit, bonus);   // ★横断：玩具/テコキ射精
        }
        spdlog::info("[Technique] orgasm bonus +{:.0f}s scene={} pos={} -> [{}]", bonus, sc, pos, dbg);
    }
}

namespace Technique {
    // ★孫スキル精査用に無名namespaceの canonAction を公開します（正規化を1か所に集約）。
    std::string CanonAction(const std::string& rawType) {
        return canonAction(toLower(rawType));
    }
    // ★孫スキル精査(玩具/テコキ射精の横断本数)用に rawBaseName を公開します。
    std::string RawBaseName(const std::string& rawType) {
        return rawBaseName(rawType);
    }

    // ★TechRank(ランク層)が読む「今のシーンのライブ秒」です。シーン外/未累積は0です。
    //   ★呼び出し側(TechRank)は g_cacheMutex を握らずにここを呼びます(2mutex同時ロックを避けるため)。
    float LiveCatSeconds(int cat) {
        if (cat < 0 || cat >= CAT_COUNT) return 0.0f;
        std::lock_guard<std::mutex> lk(g_mutex);
        return g_sec[cat];
    }
    float LiveActionSeconds(const char* action, int role) {
        if (!action) return 0.0f;
        std::lock_guard<std::mutex> lk(g_mutex);
        auto it = g_act.find(toLower(std::string(action)));
        if (it == g_act.end()) return 0.0f;
        if (role == 0) return it->second.s;
        if (role == 1) return it->second.m;
        if (role == 2) return it->second.neu;
        return 0.0f;
    }

    // ★Phase2 HUD用：今のノードでプレイヤーがクレジットされる技術行為(孫)の (正規名, 重複数)です。
    //   重複数とは同じ行為が今のノードに何個あるかです（指マン2人=2）。ライブ進行中秒を×人数して、確定(2×)と一致させます。
    std::vector<std::pair<std::string, int>> GetActiveNodeActions() {
        std::vector<std::pair<std::string, int>> out;
        std::string scene; int pos;
        {
            std::lock_guard<std::mutex> lk(g_mutex);
            if (!g_inScene) return out;
            scene = g_prevScene; pos = g_prevPos;
        }
        if (scene.empty() || pos < 0) return out;
        const auto* actions = SceneCatalog::GetActionsForScene(toLower(scene));
        if (!actions) return out;
        for (const auto& a : *actions) {
            const bool isActor = (a.actor == pos);
            const bool isTarget = (a.target == pos);
            const std::string t = canonAction(a.type);
            const int cat = techCat(t);
            const bool credit = (cat == HIPS) ? (isActor || isTarget) : (cat >= 0 && isActor);
            if (!credit) continue;
            bool found = false;
            for (auto& e : out) { if (e.first == t) { e.second += 1; found = true; break; } }   // 重複＝人数を+1
            if (!found) out.push_back({ t, 1 });
        }
        return out;
    }

    // ★今の体位に入ってからの進行中秒です（未確定）。リアルタイムHUDが確定秒に足します。
    float CurrentNodeElapsed() {
        std::lock_guard<std::mutex> lk(g_mutex);
        if (!g_inScene) return 0.0f;
        return secSince(g_prevTime);
    }

    // ★今/直近の行為cat(0-5)をC++へ公開します（H中ドレインC++用）。不明/H外=-1。Papyrus GetCurrentActionCatと同値です。
    int GetCurActionCat() {
        std::lock_guard<std::mutex> lk(g_mutex);
        return g_curActionCat;
    }

    void Install() {
        // OStim.dll の RequestPluginAPI_Thread を GetProcAddress します（ヘッダ同梱の公式経路）。
        g_api = GetAPI("ASTR2SKSE", REL::Version(0, 0, 1));
        if (!g_api) {
            spdlog::warn("[Technique] OStim API acquire FAILED (OStim.dll 不在 or RequestPluginAPI_Thread 無し)");
            return;
        }
        g_api->RegisterEventCallback(OnThreadEvent, nullptr);
        spdlog::info("[Technique] installed (NodeChanged-driven H-technique accrual).");
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("SetExciteEnabled", "ASTR2Technique", Papyrus_SetExciteEnabled);
        vm->RegisterFunction("AddOrgasmBonus", "ASTR2Technique", Papyrus_AddOrgasmBonus);
        return true;
    }
}
