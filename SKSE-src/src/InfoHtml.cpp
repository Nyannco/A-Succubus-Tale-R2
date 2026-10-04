#include "PCH.h"
#include "InfoHtml.h"

#include <atomic>
#include <mutex>
#include <string>

// ============================================================================
// InfoHtml 実装 ― SkyUI MCM の info テキストを GFx SetTextHTML() で色付けします。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   材料（configpanel.swf 逆コンパイル）＝ConfigPanel.applyInfoText() は
//     contentHolder.infoPanel.textField.text = unescape(info)   // プレーン -> タグはそのまま文字
//   を行い、contentHolder.infoPanel.background._height = textField.textHeight + 22 でサイズを合わせます。
//   _parentMenu = _root.QuestJournalFader.Menu_mc  （journal 構造）で、パネルは ConfigPanelFader の
//   中にあります。同じ textField を SetTextHTML で書き直すので、同一の文字列が html として描画されます
//   （<font color> が効く＝同じ swf のオプション一覧で実証済みです）。GFx は UI スレッドで動かす必要があります（AddUITask）。
//   ★ 肝の競合（readback ログで発見・ConfigPanel.as で原因特定）＝
//   SkyUI の Papyrus 層はハイライトごとに info バッファをクリアし、OnOptionHighlight が返った後の UI パスで
//   フラッシュします（setInfoText -> applyInfoText -> textField.text=""）。こちらは SetInfoHtml しか呼ばない
//   （SetInfoText は呼ばない）ので、そのバッファは空 -> フラッシュがフィールドを空にします。
//   こちらの SetTextHTML は同じ UI パス（AddUITask）で動き、フラッシュより前に1まとめへ潰されます
//   （"all-same-ms" の readback）-> 負けます。旧「AddUITask で1回だけ再適用」も同じパスに居たので、同じく負けました。
//   対策＝AddUITask でなく AddTask（次のゲームフレーム）で、実フレームを跨いで撃ち直します。
//   SKI の空フラッシュはハイライトごとに1イベントなので、次の数フレームで書けば必ずその後に着地します。
//   世代カウンタで、カーソルが離れた時に古い撃ちを捨てます。
//   （=> 呼び元は今も SetInfoHtml だけを使い、SetInfoText は使いません。）
// ============================================================================

namespace {
    std::mutex g_mutex;
    std::string g_base;     // 検出した config-panel のベースパスです（見つかるまで空）
    bool g_warned = false;  // 「見つからない」ログは次に成功するまで最大1回です

    // ハイライトごとに++します。再アサートの世代ガード＝別optionへカーソルが移ると古いフレームの撃ちを捨てます。
    std::atomic<std::uint64_t> g_generation{0};
    // SKIの空flush(OnOptionHighlight返却後の次UIパス)を確実に跨ぐため、実フレームで数回撃ち直す回数です。
    constexpr int kReassertFrames = 3;

    // config-panel ベースの候補です（可能性が高い順）。info の textField は
    // <base>.contentHolder.infoPanel.textField にあります。
    const char* kCandidates[] = {
        "_root.QuestJournalFader.Menu_mc.ConfigPanelFader.configPanel",
        "_root.ConfigPanelFader.configPanel",
        "_root.QuestJournalFader.Menu_mc.configPanel",
        "_root.configPanel",
        "_root",
    };

    // <base>.contentHolder.infoPanel.textField が display object に解決できれば true を返します。
    bool LeafOk(RE::GFxMovieView* a_movie, const std::string& a_base) {
        RE::GFxValue tf;
        const std::string leaf = a_base + ".contentHolder.infoPanel.textField";
        return a_movie->GetVariable(&tf, leaf.c_str()) && tf.IsDisplayObject();
    }

    // config-panel のベースパスを解決してキャッシュします。キャッシュが古くなっていたら再スキャンします
    // （MCM 再オープンでパネルが作り直される）。UI スレッドで動きます。見つからなければ false を返します。
    bool ResolveBase(RE::GFxMovieView* a_movie) {
        if (!g_base.empty()) {
            if (LeafOk(a_movie, g_base)) {
                return true;
            }
            g_base.clear();  // stale -> re-scan
        }
        for (const char* cand : kCandidates) {
            if (LeafOk(a_movie, cand)) {
                g_base = cand;
                g_warned = false;
                spdlog::info("[InfoHtml] info textField found at {}.contentHolder.infoPanel.textField", cand);
                return true;
            }
        }
        if (!g_warned) {
            spdlog::warn("[InfoHtml] info textField not found (MCM not open, or SkyUI path differs)");
            g_warned = true;
        }
        return false;
    }

    // MCM の info textField を html で書き直し、SkyUI の背景リサイズも合わせます。
    // 純粋な「1回書くだけ」＝UI スレッドで動きます（AddUITask 経由で呼ぶ）。フレームを跨いだ
    // 再アサートは下の ScheduleReassert が担当で、ここではしません。
    void ApplyHtml(const std::string& a_html) {
        auto* ui = RE::UI::GetSingleton();
        if (!ui) {
            spdlog::warn("[InfoHtml] ApplyHtml: UI singleton null");
            return;
        }
        RE::GPtr<RE::GFxMovieView> movie = ui->GetMovieView(RE::JournalMenu::MENU_NAME);
        if (!movie) {
            spdlog::warn("[InfoHtml] ApplyHtml: 'Journal Menu' movie is null (MCM movie not reachable this way?)");
            return;
        }

        std::lock_guard lk(g_mutex);
        if (!ResolveBase(movie.get())) {
            return;
        }

        const std::string tfPath = g_base + ".contentHolder.infoPanel.textField";
        RE::GFxValue tf;
        if (!movie->GetVariable(&tf, tfPath.c_str()) || !tf.IsDisplayObject()) {
            return;
        }
        tf.SetTextHTML(a_html.c_str());

        // ConfigPanel.applyInfoText() に合わせる＝background._height = textHeight + 22（空なら32）
        double h = 32.0;
        if (!a_html.empty()) {
            RE::GFxValue th;
            if (movie->GetVariable(&th, (tfPath + ".textHeight").c_str()) && th.IsNumber()) {
                h = th.GetNumber() + 22.0;
            }
        }
        RE::GFxValue bgH;
        bgH.SetNumber(h);
        movie->SetVariable((g_base + ".contentHolder.infoPanel.background._height").c_str(), bgH);
    }

    // こちらの html を実フレームを跨いで撃ち直し、SkyUI の1発の空フラッシュより後に着地させます。
    //   AddTask   = 次のゲームフレーム（メインスレッド）で動く => 実際にフレーム境界を跨ぎます
    //               （AddUITask は同じ UI パスに留まって負ける＝これが旧バグ）。
    //   その中の AddUITask で、そのフレームの UI パスへ移って GFx を UI スレッドで触ります。
    //   a_gen: これがまだ今のハイライトの時だけ書きます（カーソルが移っていない）。
    //   a_framesLeft: 連続するフレームで繰り返すので、フラッシュがどのフレームで来ても覆えます。
    void ScheduleReassert(const std::string& a_html, std::uint64_t a_gen, int a_framesLeft) {
        if (a_framesLeft <= 0) {
            return;
        }
        auto* task = SKSE::GetTaskInterface();
        if (!task) {
            return;
        }
        task->AddTask([a_html, a_gen, a_framesLeft]() {              // 次のゲームフレーム（メインスレッド）
            if (a_gen != g_generation.load()) {
                return;                                             // 古い＝カーソルが別のオプションへ移った
            }
            if (auto* uiTask = SKSE::GetTaskInterface()) {
                uiTask->AddUITask([a_html, a_gen, a_framesLeft]() {  // そのフレームの UI パス（GFx安全）
                    if (a_gen != g_generation.load()) {
                        return;
                    }
                    ApplyHtml(a_html);
                    ScheduleReassert(a_html, a_gen, a_framesLeft - 1);
                });
            }
        });
    }

    // ===== Papyrus ネイティブ: ASTR2Native.SetInfoHtml(html) =====
    //   GFx の書き直しを UI スレッドへキューします。文字列は HTML として表示されるので
    //   <font color> が効きます。色付きの行では OnOptionHighlight で SetInfoText の代わりに呼びます。
    //   文字列は解決済みにしておく必要があります（$キー＋数値は LocFmt）。
    //   .psc の宣言に合わせて void を返します（Function SetInfoHtml(String) Global Native）。
    void Papyrus_SetInfoHtml(RE::StaticFunctionTag*, RE::BSFixedString html) {
        std::string h = (html.c_str() != nullptr) ? html.c_str() : "";
        const std::uint64_t gen = ++g_generation;   // 新しいハイライト => 新しい世代（古い再アサートを引退させる）
        auto* task = SKSE::GetTaskInterface();
        if (!task) {
            spdlog::warn("[InfoHtml] SetInfoHtml: SKSE task interface null");
            return;
        }
        // 即時描画（ハイライトの瞬間・SKI の空フラッシュより前）＝1フレームぶん正しい色を見せます
        task->AddUITask([h, gen]() {
            if (gen != g_generation.load()) {
                return;
            }
            ApplyHtml(h);
        });
        // その後、実フレームを跨いで撃ち直し、SKI の空フラッシュより後に着地して残します。
        ScheduleReassert(h, gen, kReassertFrames);
    }
}

namespace InfoHtml {
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("SetInfoHtml", "ASTR2Native", Papyrus_SetInfoHtml);
        spdlog::info("[InfoHtml] Papyrus native ASTR2Native.SetInfoHtml registered");
        return true;
    }
}
