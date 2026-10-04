#include "PCH.h"
#include "BarNumbers.h"
#include "Chronos.h"
#include "SkyVaultAPI.h"
#include "RE/H/HUDMenu.h"

#include <cmath>
#include <cstdio>
#include <mutex>
#include <string>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace BarNumbers
{
    namespace {
        constexpr const char* kJobName  = "バー数字";
        constexpr float       kEverySec = 0.5f;    // 実時間0.5秒ごとです＝変わった時だけ描き替えるので実質無コストです
        constexpr int         kMaxLevel = 100;             // ここに到達したら経験値はカンスト表示です

        // HUDへ作る文字レイヤーの名前です（2本）。
        constexpr const char* kFieldLF  = "ASTR2_BarNum_LF";
        constexpr const char* kFieldXP  = "ASTR2_BarNum_XP";

        std::mutex  g_mutex;
        std::string g_lfRoot;      // 淫魔力バーのWidgetRoot（Papyrusから受け取ります）
        std::string g_xpRoot;      // 経験値バーのWidgetRootです
        std::string g_lastLF;      // 直前に描いた文字＝同じなら描き替えません
        std::string g_lastXP;
        std::string g_boxLF;       // 直前にログした器の範囲＝変わった時だけログします
        std::string g_boxXP;

        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }
        inline int SVInt(const char* k, int d) { auto* v = Vault(); return v ? v->GetInt(0, k, d) : d; }
        inline float SVFloat(const char* k, float d) { auto* v = Vault(); return v ? v->GetFloat(0, k, d) : d; }

        int SuccubusLevel() { return SuccLevel::Raw(0); }

        // 数値 → K/M/G表記です。digits＝有効桁(2 or 3)。
        //   999→"999" ／ 12345→"12.3K"(3桁) or "12K"(2桁) ／ 2880916→"2.88M"(3桁) or "2.9M"(2桁)
        std::string Short(double a_v, int a_digits) {
            if (a_v < 0.0) a_v = 0.0;
            const char* unit = "";
            double v = a_v;
            if (v >= 1000000000.0)   { v /= 1000000000.0; unit = "G"; }
            else if (v >= 1000000.0) { v /= 1000000.0;    unit = "M"; }
            else if (v >= 1000.0)    { v /= 1000.0;       unit = "K"; }
            else {
                char raw[32]{};
                std::snprintf(raw, sizeof(raw), "%.0f", v);
                return raw;
            }
            // 有効桁に合わせて小数点以下を決めます（例 3桁＝12.3K / 2.88M、2桁＝12K / 2.9M）
            int intDigits = (v >= 100.0) ? 3 : ((v >= 10.0) ? 2 : 1);
            int dec = a_digits - intDigits;
            if (dec < 0) dec = 0;
            if (dec > 2) dec = 2;
            char buf[32]{};
            std::snprintf(buf, sizeof(buf), "%.*f%s", dec, v, unit);
            return buf;
        }

        // 器(=meter.background)の範囲を、ウィジェット自身の座標で測ります。
        //   WidgetRootの_x/_yはSkyUIのアンカー点（中身は_widgetHolderがアンカーに応じてずらして描きます）、
        //     _width/_heightは伸び縮みする残量(fill)まで含む外枠＝どちらも器の位置ではありません（実機で上寄り/残量追従を確認）。
        //   backgroundはsetSizeのたびに設定幅・高さぴったりに合わせられます＝器そのものです。
        bool FrameBox(RE::GFxMovieView* a_mv, const std::string& a_root,
                      double& a_x, double& a_y, double& a_w, double& a_h) {
            RE::GFxValue rootClip;
            if (!a_mv->GetVariable(&rootClip, a_root.c_str()) || !rootClip.IsDisplayObject()) return false;
            RE::GFxValue b;
            if (!a_mv->Invoke((a_root + ".meter.background.getBounds").c_str(), &b, &rootClip, 1) || !b.IsObject()) return false;
            RE::GFxValue xMin, xMax, yMin, yMax;
            if (!b.GetMember("xMin", &xMin) || !b.GetMember("xMax", &xMax) ||
                !b.GetMember("yMin", &yMin) || !b.GetMember("yMax", &yMax)) return false;
            if (!xMin.IsNumber() || !xMax.IsNumber() || !yMin.IsNumber() || !yMax.IsNumber()) return false;
            a_x = xMin.GetNumber();
            a_y = yMin.GetNumber();
            a_w = xMax.GetNumber() - a_x;
            a_h = yMax.GetNumber() - a_y;
            return a_w > 0.0 && a_h > 0.0;
        }

        // 文字レイヤーを1本描きます（無ければ作ります）。空文字なら隠します。
        //   文字枠はウィジェットの**中**（WidgetRootの子）に作ります＝メニュー/会話等でHUDが消える時、
        //     バーと一緒に消えます・フェードも一緒です（旧＝_root直下でHUDの表示切替の対象外＝出っぱなしでした）。
        //   位置合わせは毎周期（MCMで幅を変えても追従します）／文字の描き替えはa_textChangedの時だけです。
        void DrawOne(RE::GFxMovieView* a_mv, const char* a_field, const std::string& a_root,
                     const std::string& a_text, bool a_textChanged, std::string& a_lastBox) {
            if (a_root.empty()) return;
            const std::string path = a_root + "." + a_field;
            RE::GFxValue tf;
            const bool exists = a_mv->GetVariable(&tf, path.c_str()) && tf.IsDisplayObject();

            if (a_text.empty()) {                       // OFF/対象なし＝隠すだけです（作りません・消しません）
                if (exists) tf.SetMember("_visible", RE::GFxValue(false));
                return;
            }
            double bx = 0.0, by = 0.0, bw = 0.0, bh = 0.0;
            if (!FrameBox(a_mv, a_root, bx, by, bw, bh)) {
                if (exists) tf.SetMember("_visible", RE::GFxValue(false));
                return;                                 // バーがまだ出来ていません＝次の周期で
            }
            {   // 判定ログ＝器の範囲が変わった時だけ1行出します（ズレた時に計算ミスかを切り分ける用）
                char box[96]{};
                std::snprintf(box, sizeof(box), "x=%.1f y=%.1f w=%.1f h=%.1f", bx, by, bw, bh);
                if (a_lastBox != box) {
                    a_lastBox = box;
                    spdlog::info("[BarNumbers] box {} {}", a_field, box);
                }
            }

            if (!exists) {
                RE::GFxValue depth;
                a_mv->Invoke((a_root + ".getNextHighestDepth").c_str(), &depth, nullptr, 0);   // 深度は動的に取得します＝他と衝突しません
                RE::GFxValue args[6];
                args[0].SetString(a_field);
                args[1] = depth;
                args[2].SetNumber(bx);
                args[3].SetNumber(by);
                args[4].SetNumber(bw);
                args[5].SetNumber(bh);
                RE::GFxValue made;
                if (!a_mv->Invoke((a_root + ".createTextField").c_str(), &made, args, 6)) return;
                if (!a_mv->GetVariable(&tf, path.c_str())) return;
                tf.SetMember("html", RE::GFxValue(true));
                tf.SetMember("selectable", RE::GFxValue(false));
                tf.SetMember("multiline", RE::GFxValue(false));
                tf.SetMember("wordWrap", RE::GFxValue(false));
                tf.SetMember("autoSize", RE::GFxValue("none"));
                a_textChanged = true;                   // 作りたて＝必ず文字を入れます
                spdlog::info("[BarNumbers] field created in {}", a_root);
            }
            if (a_textChanged) {
                const std::string html =
                    "<p align='center'><font face='$EverywhereMediumFont' size='16' color='#FFFFFF'>" +
                    a_text + "</font></p>";
                tf.SetMember("htmlText", RE::GFxValue(html.c_str()));
            }
            // 配置＝左右は器の中央／**文字の下端を器の下端に合わせます**
            //   枠の高さ＝実際の文字の高さ＋上下の余白(TextFieldの内側2px×2)＝枠の下端＝文字の下端です。
            double fieldH = 20.0;
            RE::GFxValue th;
            if (tf.GetMember("textHeight", &th) && th.IsNumber() && th.GetNumber() > 0.0) {
                fieldH = th.GetNumber() + 4.0;
            }
            tf.SetMember("_x", RE::GFxValue(bx));
            tf.SetMember("_y", RE::GFxValue(by + bh - fieldH));
            tf.SetMember("_width", RE::GFxValue(bw));
            tf.SetMember("_height", RE::GFxValue(fieldH));
            tf.SetMember("_visible", RE::GFxValue(true));
        }

        void Update() {
            std::lock_guard<std::mutex> lock(g_mutex);

            auto* ui = RE::UI::GetSingleton();
            auto  hud = ui ? ui->GetMenu<RE::HUDMenu>() : nullptr;
            if (!hud || !hud->uiMovie) return;
            auto& mv = hud->uiMovie;

            const bool on = (SVInt("ASTR2_BarNumOn", 1) == 1);
            if (!on) {
                if (!g_lastLF.empty()) { DrawOne(mv.get(), kFieldLF, g_lfRoot, "", true, g_boxLF); g_lastLF.clear(); }
                if (!g_lastXP.empty()) { DrawOne(mv.get(), kFieldXP, g_xpRoot, "", true, g_boxXP); g_lastXP.clear(); }
                return;
            }
            int digits = SVInt("ASTR2_BarNumDigits", 3);
            if (digits < 2) digits = 2;
            if (digits > 3) digits = 3;

            // 淫魔力＝現在/最大
            const double lfCur = static_cast<double>(SVInt("ASTR2_LF_Curr", 0));
            const double lfMax = static_cast<double>(SVInt("ASTR2_LF_Max", 0));
            std::string lfText = Short(lfCur, digits) + " / " + Short(lfMax, digits);

            // 経験値＝現在/次のLvまで。Lv100に到達したらカンスト表示です。
            std::string xpText;
            if (SuccubusLevel() >= kMaxLevel) {
                xpText = "MAX";
            } else {
                const double xpCur = static_cast<double>(SVFloat("ASTR2_Xp_Curr", 0.0f));
                const double xpReq = static_cast<double>(SVFloat("ASTR2_Xp_Req", 0.0f));
                xpText = Short(xpCur, digits) + " / " + Short(xpReq, digits);
            }

            // 位置合わせは毎周期／文字の描き替えは変わった時だけです
            DrawOne(mv.get(), kFieldLF, g_lfRoot, lfText, lfText != g_lastLF, g_boxLF);
            g_lastLF = lfText;
            DrawOne(mv.get(), kFieldXP, g_xpRoot, xpText, xpText != g_lastXP, g_boxXP);
            g_lastXP = xpText;
        }

        // ---- Papyrus ネイティブ ----
        //   バーのWidgetRootを渡してもらいます（ロード毎に1回＝Maintenanceから）。
        void Papyrus_Bind(RE::StaticFunctionTag*, RE::BSFixedString a_lfRoot, RE::BSFixedString a_xpRoot) {
            std::lock_guard<std::mutex> lock(g_mutex);
            g_lfRoot = a_lfRoot.c_str() ? a_lfRoot.c_str() : "";
            g_xpRoot = a_xpRoot.c_str() ? a_xpRoot.c_str() : "";
            g_lastLF.clear();
            g_lastXP.clear();
            g_boxLF.clear();
            g_boxXP.clear();
            spdlog::info("[BarNumbers] bind LF='{}' XP='{}'", g_lfRoot, g_xpRoot);
        }
    }

    void Install() {
        Chronos::RegisterRealtime(kJobName, kEverySec, []() { Update(); });
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("BarNumbersBind", "ASTR2Native", Papyrus_Bind);
        spdlog::info("[BarNumbers] Papyrus native (BarNumbersBind) 登録");
        return true;
    }
}
