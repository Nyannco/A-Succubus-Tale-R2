#include "PCH.h"
#include "TechHud.h"
#include "TechRank.h"        // BuildHudLines（今のノードで育ってる孫の行データ）
#include "Localization.h"    // $key→現在言語の文字列（LocFmtStrCpp）
#include "RE/H/HUDMenu.h"    // HUDライブ表示の親メニュー(uiMovie=Scaleform)

#include <thread>
#include <atomic>
#include <string>
#include <vector>
#include <chrono>

// ============================================================================
// H中ライブHUD＝「<孫名>：残りN秒」を OStim準備中(ScenePreparing)の上に積みます。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   位置基準（ScenePreparing/VMon 実測）：
//     VMon      top = rect.bottom - 86   (高さ56・下余白30)
//     OStim準備中 top = rect.bottom - 158  (高さ32・VMonの72px上)
//     間隔72px(top-to-top)＝VMon↔準備中と同じです。左端 x = rect.left + 30（準備中/VMonと揃います）。
//   位置(実機調整)：line i(0=最下) top = rect.bottom - kFirstLineTop(380) - kStep(40)*i。
//     380=一番下の行(アイコン列より上・画面内)／40=行間(72は広すぎました)。さらに微調整はこの2定数 or MCM位置スライダー化で行います。
// ============================================================================

namespace {
    // 同時表示の上限です。全アニメ走査(有効3396シーン×全ポジション)で最大4行(Billyy輪姦系5件のみ)＝予備1で5にしています。
    constexpr int    kMaxLines   = 5;
    constexpr double kWidth       = 900.0;
    constexpr double kHeight      = 32.0;    // 1行ぶんです
    // MCMスライダーで動かせるレイアウトです（既定＝実機調整値・Papyrus TechHudSetLayout で更新）。
    //   一番下の行を基準にX/Y/行間（TechHudSetLayout）＝上の行は行間ぶん自動追従します。
    std::atomic<int> g_hudTop{ 380 };        // 一番下の行(index0)の上げ幅です（bottomから）
    std::atomic<int> g_hudLeft{ 30 };        // 左マージンです（leftから）
    std::atomic<int> g_hudStep{ 40 };        // 行間です
    std::atomic<uint32_t> g_previewGen{ 0 }; // プレビュー(MCM位置調整用ダミー)の世代＝呼び直しで前のカウントを無効化します
    std::atomic<int>      g_previewRemain{ -1 };  // プレビューの残り秒（-1=プレビューなし）。H中は本番行の上の空き枠をダミーで埋めます

    std::atomic<bool>     g_enabled{ true };  // MCMトグルです（既定ON）
    std::atomic<bool>     g_active{ false };  // H(シーン)中かどうかです
    std::atomic<uint32_t> g_gen{ 0 };         // リフレッシュスレッドの世代です（開始/終了で無効化）

    // 全行を隠します（フィールドが在れば _visible=false）。ゲームスレッド(AddTask)から呼びます。
    void HideAll() {
        auto* ui = RE::UI::GetSingleton();
        if (!ui) return;
        auto hud = ui->GetMenu<RE::HUDMenu>();
        if (!hud || !hud->uiMovie) return;
        auto& mv = hud->uiMovie;
        for (int i = 0; i < kMaxLines; ++i) {
            const std::string var = "_root.ASTR2TechHud" + std::to_string(i);
            RE::GFxValue tf;
            if (mv->GetVariable(&tf, var.c_str()) && tf.IsObject()) {
                tf.SetMember("_visible", RE::GFxValue(false));
            }
        }
    }

    // html行を描画します（i番目＝準備中の上へ i+1 段）。無い行は隠します。ゲームスレッド(AddTask)から呼びます。
    void RenderHtmls(const std::vector<std::string>& htmls) {
        auto* ui = RE::UI::GetSingleton();
        if (!ui) return;
        auto hud = ui->GetMenu<RE::HUDMenu>();
        if (!hud || !hud->uiMovie) return;
        auto& mv = hud->uiMovie;
        const RE::GRectF rect = mv->GetVisibleFrameRect();
        const double top  = static_cast<double>(g_hudTop.load());
        const double left = static_cast<double>(g_hudLeft.load());
        const double step = static_cast<double>(g_hudStep.load());
        for (int i = 0; i < kMaxLines; ++i) {
            const bool show = (i < static_cast<int>(htmls.size()));
            const std::string name = "ASTR2TechHud" + std::to_string(i);
            const std::string var = "_root." + name;
            const double x = static_cast<double>(rect.left) + left;
            const double y = static_cast<double>(rect.bottom) - top - step * i;   // line0=一番下・上へ積みます
            RE::GFxValue tf;
            if (!mv->GetVariable(&tf, var.c_str()) || !tf.IsObject()) {
                if (!show) continue;   // 消すだけなら作りません
                // 深度は固定値でなく getNextHighestDepth() で動的取得＝他MOD/VMon/準備中との深度衝突を根絶します
                //   （HUDMenu _root は全MOD共通1枚なので固定キリ番は被ります）。
                RE::GFxValue depth;
                mv->Invoke("_root.getNextHighestDepth", &depth, nullptr, 0);
                // AS2: createTextField(name, depth, x, y, width, height)
                RE::GFxValue args[6];
                args[0] = name.c_str();
                args[1] = depth;
                args[2] = x;
                args[3] = y;
                args[4] = kWidth;
                args[5] = kHeight;
                RE::GFxValue made;
                if (!mv->Invoke("_root.createTextField", &made, args, 6)) continue;
                if (!mv->GetVariable(&tf, var.c_str()) || !tf.IsObject()) continue;
                tf.SetMember("html", RE::GFxValue(true));
                tf.SetMember("selectable", RE::GFxValue(false));
                tf.SetMember("multiline", RE::GFxValue(false));
                tf.SetMember("wordWrap", RE::GFxValue(false));
            }
            tf.SetMember("_x", RE::GFxValue(x));   // 毎回位置更新＝MCMスライダーの変更が(シーン中でも)次refreshで反映されます
            tf.SetMember("_y", RE::GFxValue(y));
            tf.SetMember("_visible", RE::GFxValue(show));
            if (show) {
                tf.SetMember("_alpha", RE::GFxValue(100.0));
                tf.SetMember("htmlText", RE::GFxValue(htmls[i].c_str()));
            }
        }
    }

    // 1行の表示文字列（html）を作ります。左端に「ランク〇：」＋名前＋残り秒。
    //   色＝下(index0)から ピンク→水色→ピンク… の交互です（MCMの技術色 pink=#ffc5e1 / 水色=#73bbf7）。
    //   引数＝{0}=ランク {1}=名前 {2}=残り秒（maxは{0}=ランク {1}=名前）。
    std::string BuildLineHtml(const TechRank::HudLine& L, int index) {
        const std::string label = Localization::LocFmtStrCpp(L.nameKey, {});
        const std::string rankStr = std::to_string(L.rank);
        std::string line;
        if (L.rank >= 10) {
            line = Localization::LocFmtStrCpp("$ASTR2_TechHud_Max", { rankStr, label });
        } else {
            line = Localization::LocFmtStrCpp("$ASTR2_TechHud_Line", { rankStr, label, std::to_string(L.secToNext) });
        }
        const char* color = (index % 2 == 0) ? "#ffc5e1" : "#73bbf7";   // 下=ピンク→水色→ピンク（MCM色）
        return std::string("<font color='") + color + "' size='20'>" + line + "</font>";
    }

    // プレビュー中なら空き枠(kMaxLinesまで)を白ダミーで埋めます＝実際の値が優先・下から本物→上にダミーです。
    void AppendDummies(std::vector<std::string>& htmls) {
        const int remain = g_previewRemain.load();
        if (remain < 0) return;
        const std::string line = Localization::LocFmtStrCpp("$ASTR2_TechHud_Dummy", { std::to_string(remain) });
        while (static_cast<int>(htmls.size()) < kMaxLines) {
            htmls.push_back("<font color='#ffffff' size='20'>" + line + "</font>");
        }
    }

    // リフレッシュスレッド＝H中は1秒ごとに「今育ってる孫」を作り直して描画します（残り秒がライブで減ります）。
    //   std::threadは"待つ"だけです／RE::操作は全部 AddTask でゲームスレッドへ回します（ScenePreparing/VassalRaise式）。
    void StartThread(uint32_t gen) {
        std::thread([gen]() {
            using namespace std::chrono;
            while (true) {
                if (g_gen.load() != gen || !g_active.load()) break;
                if (g_enabled.load()) {
                    auto lines = TechRank::BuildHudLines();
                    std::vector<std::string> htmls;
                    htmls.reserve(lines.size());
                    for (const auto& L : lines) {
                        htmls.push_back(BuildLineHtml(L, static_cast<int>(htmls.size())));
                        if (static_cast<int>(htmls.size()) >= kMaxLines) break;
                    }
                    AppendDummies(htmls);   // H中プレビュー＝本物の上の空き枠だけダミーです
                    SKSE::GetTaskInterface()->AddTask([htmls, gen]() {
                        if (g_gen.load() == gen && g_active.load()) RenderHtmls(htmls);
                    });
                } else {
                    SKSE::GetTaskInterface()->AddTask([gen]() {
                        if (g_gen.load() == gen) HideAll();
                    });
                }
                std::this_thread::sleep_for(milliseconds(1000));
            }
            SKSE::GetTaskInterface()->AddTask([]() { HideAll(); });   // 終了＝必ず消します
        }).detach();
    }

    // ===== Papyrus native: ASTR2Technique.TechHudSetEnabled(Bool) =====
    void Papyrus_SetEnabled(RE::StaticFunctionTag*, bool on) {
        TechHud::SetEnabled(on);
    }

    // ===== Papyrus native: ASTR2Technique.TechHudSetLayout(Int y, Int x, Int step) =====
    //   「まとめて」スライダー＝一番下の行を基準に全行を動かします（y=下からの上げ幅／x=左マージン／step=行間）。0以下は無視＝既定維持です。
    void Papyrus_SetLayout(RE::StaticFunctionTag*, std::int32_t a_y, std::int32_t a_x, std::int32_t a_step) {
        if (a_y > 0)    g_hudTop.store(a_y);
        if (a_x >= 0)   g_hudLeft.store(a_x);
        if (a_step > 0) g_hudStep.store(a_step);
    }

    // プレビュー＝MCMの位置スライダー調整用ダミー5行です（白＝本番のピンク/水色と区別）。
    //   「残り5秒」→…→「残り0秒」と1秒ずつ減り、0の1秒後に消えます。
    //   ポーズ中(MCMを開いてる間)は5秒のまま据え置き＝HUDが見える状態(メニューを閉じた後)で数え始めます。
    //   呼び直し＝世代更新で前のカウントを捨てて5秒から始めます。
    //   H外＝このスレッドがダミー5行を描きます／H中＝描画は本番リフレッシュに任せ、本物の行の上の空き枠をダミーで埋めます
    //   （AppendDummies・実際の値優先＝本物2行ならダミー3行）。ここは残り秒(g_previewRemain)を進めるだけです。
    void StartPreview(uint32_t pgen) {
        std::thread([pgen]() {
            using namespace std::chrono;
            int remain = 5;
            while (true) {
                if (g_previewGen.load() != pgen) return;   // 新しいプレビューに譲ります（消しません）
                g_previewRemain.store(remain);
                if (!g_active.load()) {
                    std::vector<std::string> htmls;
                    AppendDummies(htmls);   // 空＝5行ともダミーです
                    SKSE::GetTaskInterface()->AddTask([htmls, pgen]() {
                        if (g_previewGen.load() == pgen && !g_active.load()) RenderHtmls(htmls);
                    });
                }
                std::this_thread::sleep_for(milliseconds(1000));
                auto* ui = RE::UI::GetSingleton();
                if (ui && ui->GameIsPaused()) continue;   // メニュー中は据え置きます
                if (remain <= 0) break;                    // 0を1秒見せたら終了します
                --remain;
            }
            if (g_previewGen.load() != pgen) return;
            g_previewRemain.store(-1);   // H中は次の本番リフレッシュでダミーが消えます
            SKSE::GetTaskInterface()->AddTask([pgen]() {
                if (g_previewGen.load() == pgen && !g_active.load()) HideAll();
            });
        }).detach();
    }

    // ===== Papyrus native: ASTR2Technique.TechHudPreview() =====
    //   MCMの位置スライダー確定/既定戻しの直後に呼びます（H中も可＝実際の値優先で空き枠だけダミー）。
    void Papyrus_Preview(RE::StaticFunctionTag*) {
        StartPreview(++g_previewGen);
    }
}

namespace TechHud {
    void OnSceneStart() {
        g_active.store(true);
        const uint32_t gen = ++g_gen;   // 前スレッドを無効化して新スレッドを開始します
        StartThread(gen);
    }

    void OnSceneEnd() {
        g_active.store(false);
        ++g_gen;   // スレッドを停止します
        SKSE::GetTaskInterface()->AddTask([]() { HideAll(); });
    }

    void SetEnabled(bool on) {
        g_enabled.store(on);
        if (!on) {
            SKSE::GetTaskInterface()->AddTask([]() { HideAll(); });
        }
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("TechHudSetEnabled", "ASTR2Technique", Papyrus_SetEnabled);
        vm->RegisterFunction("TechHudSetLayout", "ASTR2Technique", Papyrus_SetLayout);
        vm->RegisterFunction("TechHudPreview", "ASTR2Technique", Papyrus_Preview);
        spdlog::info("[TechHud] Papyrus native ASTR2Technique.TechHudSetEnabled / TechHudSetLayout / TechHudPreview registered.");
        return true;
    }
}
