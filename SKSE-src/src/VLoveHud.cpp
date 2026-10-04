#include "PCH.h"
#include "VLoveHud.h"
#include "Chronos.h"
#include "Localization.h"     // $key→現在言語（LocFmtStrCpp）
#include "SkyVaultAPI.h"
#include "RE/H/HUDMenu.h"

#include <algorithm>
#include <cmath>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace VLoveHud
{
    namespace {
        constexpr const char* kJobName    = "寵愛警告HUD";
        constexpr float       kEverySec   = 0.5f;
        constexpr int         kMaxLines   = 6;                        // 折り返し上限です（安全枠）
        constexpr const char* kDummyKey   = "$ASTR2_Msg_VLoveHudPreview";  // プレビュー専用の「あと{1}秒」版です（一番長いセリフのまま＝折り返し確認用・水色font込み）
        constexpr const char* kDummyNameKey = "$ASTR2_Msg_VLoveHudPreviewName";  // プレビューのダミー名です（多言語・{0}へ差します）
        constexpr int         kWrapCP     = 24;                       // 1行あたりの目安コードポイント数です
        constexpr float       kShowSec    = 5.0f;                     // 本番：1体あたりの表示秒です
        constexpr float       kPreviewSec = 5.0f;                     // プレビュー：スライダー移動時の表示秒です
        constexpr std::size_t kMaxQueue   = 6;                        // 同時発生Max＝3体×2段階

        // --- 本番キュー（別スレッドから積む可能性→mutex） ---
        std::mutex              g_mutex;
        std::deque<std::string> g_queue;
        std::string             g_current;
        bool                    g_showing  = false;
        float                   g_shownFor = 0.0f;

        // --- プレビュー（位置スライダー移動の検知＝X/Y/Stepの変化）。Update専用スレッドのみ触ります ---
        bool  g_posInit     = false;
        int   g_lastX = 0, g_lastY = 0, g_lastStep = 0;
        float g_previewLeft = 0.0f;   // 残り秒です（>0でプレビュー中）
        bool  g_previewDirty = false; // スライダーを動かしました＝MCMを閉じたらプレビュー開始する予約です

        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }
        inline int SVInt(const char* k, int d) { auto* v = Vault(); return v ? v->GetInt(0, k, d) : d; }

        // UTF-8文字列を「コードポイント約a_maxごと」に折ります（マルチバイトの途中で切りません）。
        // タグ対応：<...>内はCP勘定に入れず、タグの途中では折りません＝<font color>が行分割で壊れません。
        std::vector<std::string> SplitUtf8(const std::string& s, int a_max) {
            std::vector<std::string> out;
            std::string cur;
            int  cp    = 0;
            bool inTag = false;
            for (std::size_t i = 0; i < s.size();) {
                const unsigned char c = static_cast<unsigned char>(s[i]);
                std::size_t len = 1;
                if      ((c & 0x80) == 0x00) len = 1;
                else if ((c & 0xE0) == 0xC0) len = 2;
                else if ((c & 0xF0) == 0xE0) len = 3;
                else if ((c & 0xF8) == 0xF0) len = 4;
                if (i + len > s.size()) len = 1;             // 壊れ対策です
                if (len == 1 && c == '<') inTag = true;
                cur.append(s, i, len);
                i += len;
                if (len == 1 && c == '>') { inTag = false; continue; }
                if (inTag) continue;                         // タグ内は数えません/折りません
                if (++cp >= a_max) { out.push_back(cur); cur.clear(); cp = 0; }
            }
            if (!cur.empty()) out.push_back(cur);
            if (out.empty()) out.push_back("");
            return out;
        }

        void HideAll(RE::GFxMovieView* a_mv) {
            for (int i = 0; i < kMaxLines; ++i) {
                RE::GFxValue tf;
                const std::string var = "_root.ASTR2VLoveHud" + std::to_string(i);
                if (a_mv->GetVariable(&tf, var.c_str()) && tf.IsDisplayObject()) {
                    tf.SetMember("_visible", RE::GFxValue(false));
                }
            }
        }

        // 確定文字列を複数行テキストフィールドで描画します（下から上へ積みます＝上から読める並び）。
        void RenderLines(RE::GFxMovieView* a_mv, const std::string& a_text) {
            const RE::GRectF rect = a_mv->GetVisibleFrameRect();
            const double left = static_cast<double>(SVInt("ASTR2_VLoveHudX", 30));
            const double yUp  = static_cast<double>(SVInt("ASTR2_VLoveHudY", 380));   // 画面下からの上げ幅です
            const double step = static_cast<double>(SVInt("ASTR2_VLoveHudStep", 40)); // 折り返し行間です

            std::vector<std::string> lines = SplitUtf8(a_text, kWrapCP);
            const int    n = std::min(static_cast<int>(lines.size()), kMaxLines);
            const double x = static_cast<double>(rect.left) + left;

            for (int i = 0; i < kMaxLines; ++i) {
                const std::string name = "ASTR2VLoveHud" + std::to_string(i);
                const std::string var  = "_root." + name;
                const bool show = (i < n);
                RE::GFxValue tf;
                const bool exists = a_mv->GetVariable(&tf, var.c_str()) && tf.IsDisplayObject();
                // ブロックの一番下の行(i=n-1)が「下から yUp」＝上へ積みます＝上から下へ読める並びです。
                const double y = static_cast<double>(rect.bottom) - yUp - step * (n - 1 - i);
                if (!exists) {
                    if (!show) continue;
                    RE::GFxValue depth;
                    a_mv->Invoke("_root.getNextHighestDepth", &depth, nullptr, 0);   // 深度は動的取得＝他HUDと衝突しません
                    RE::GFxValue args[6];
                    args[0].SetString(name.c_str());
                    args[1] = depth;
                    args[2].SetNumber(x);
                    args[3].SetNumber(y);
                    args[4].SetNumber(880.0);
                    args[5].SetNumber(step > 0.0 ? step : 40.0);
                    RE::GFxValue made;
                    if (!a_mv->Invoke("_root.createTextField", &made, args, 6)) continue;
                    if (!a_mv->GetVariable(&tf, var.c_str()) || !tf.IsDisplayObject()) continue;
                    tf.SetMember("html", RE::GFxValue(true));
                    tf.SetMember("selectable", RE::GFxValue(false));
                    tf.SetMember("multiline", RE::GFxValue(false));
                    tf.SetMember("wordWrap", RE::GFxValue(false));
                    tf.SetMember("autoSize", RE::GFxValue("none"));
                }
                tf.SetMember("_x", RE::GFxValue(x));
                tf.SetMember("_y", RE::GFxValue(y));
                tf.SetMember("_visible", RE::GFxValue(show));
                if (show) {
                    const std::string html =
                        "<p align='left'><font face='$EverywhereMediumFont' size='20' color='#ffc5e1'>" +
                        lines[static_cast<std::size_t>(i)] + "</font></p>";
                    tf.SetMember("htmlText", RE::GFxValue(html.c_str()));
                }
            }
        }

        // 位置スライダーの変化を見てプレビューを起動します。初回は基準を取るだけです（誤発火防止）。
        void PollSlidersForPreview() {
            const int x  = SVInt("ASTR2_VLoveHudX", 30);
            const int y  = SVInt("ASTR2_VLoveHudY", 380);
            const int st = SVInt("ASTR2_VLoveHudStep", 40);
            if (!g_posInit) { g_lastX = x; g_lastY = y; g_lastStep = st; g_posInit = true; return; }
            if (x != g_lastX || y != g_lastY || st != g_lastStep) {
                g_lastX = x; g_lastY = y; g_lastStep = st;
                g_previewDirty = true;   // 動かしました＝MCMを閉じた瞬間にカウント開始します（メニュー中は動かしません）
            }
        }

        // 本番キューの現在表示文字列を返します（表示秒の経過管理＋次へ送り）。無ければfalse。
        bool CurrentQueueText(std::string& a_out) {
            std::lock_guard<std::mutex> lk(g_mutex);
            if (g_showing) {
                g_shownFor += kEverySec;
                if (g_shownFor >= kShowSec) { g_showing = false; g_current.clear(); }
            }
            if (!g_showing) {
                if (g_queue.empty()) return false;
                g_current  = g_queue.front();
                g_queue.pop_front();
                g_showing  = true;
                g_shownFor = 0.0f;
            }
            a_out = g_current;
            return true;
        }

        void ClearQueue() {
            std::lock_guard<std::mutex> lk(g_mutex);
            g_queue.clear();
            g_showing  = false;
            g_shownFor = 0.0f;
            g_current.clear();
        }

        void Update() {
            auto* ui  = RE::UI::GetSingleton();
            auto  hud = ui ? ui->GetMenu<RE::HUDMenu>() : nullptr;
            if (!hud || !hud->uiMovie) return;
            auto& mv = hud->uiMovie;

            PollSlidersForPreview();

            // メニュー(MCM等でゲームがポーズ)中はHUDが裏＝プレビューは動かさず、閉じた(ポーズ解除)瞬間にカウント開始します。
            if (ui->GameIsPaused()) return;
            if (g_previewDirty) { g_previewLeft = kPreviewSec; g_previewDirty = false; }

            // ① プレビュー中＝最優先です。ダミー文言を秒カウントダウン(5→1)で表示します（ON/OFFに依らず位置合わせ可）。
            if (g_previewLeft > 0.0f) {
                const int secs = std::max(1, static_cast<int>(std::ceil(g_previewLeft)));
                const std::string dummyName = Localization::LocFmtStrCpp(kDummyNameKey, {});
                const std::string text =
                    Localization::LocFmtStrCpp(kDummyKey, { dummyName, std::to_string(secs) });
                RenderLines(mv.get(), text);
                g_previewLeft -= kEverySec;
                return;
            }

            // ② 本番HUDがON＝キューを1体ずつ処理します。空なら隠します。
            if (SVInt("ASTR2_VLoveHudOn", 1) == 1) {
                std::string text;
                if (CurrentQueueText(text)) { RenderLines(mv.get(), text); return; }
                HideAll(mv.get());
                return;
            }

            // ③ OFF＝キューを捨てて何も出しません（ONに戻した時に古い警告が溜まって一斉に表示されないように）。
            ClearQueue();
            HideAll(mv.get());
        }
    }

    void Enqueue(const std::string& a_text) {
        std::lock_guard<std::mutex> lk(g_mutex);
        if (g_queue.size() >= kMaxQueue) g_queue.pop_front();   // 暴走防止＝古いのを捨てます
        g_queue.push_back(a_text);
    }

    void Install() {
        Chronos::RegisterRealtime(kJobName, kEverySec, []() { Update(); });
        spdlog::info("[VLoveHud] 本番HUDを登録（ASTR2_VLoveHudOn==1で表示・スライダー移動で5秒プレビュー）");
    }
}
