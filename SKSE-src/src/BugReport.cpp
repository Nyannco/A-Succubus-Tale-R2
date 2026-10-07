#include "PCH.h"
#include "BugReport.h"

#include <algorithm>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace BugReport
{
    namespace {
        namespace fs = std::filesystem;

        constexpr const char* kEsp          = "A Succubus Tale R2.esp";
        // ログ本体＝SKSEログフォルダの ASTR2SKSE.log（spdlog）。レア事象(spdlog::warn [RARE])もここに出ます＝不具合報告に丸ごと取り込みます。
        constexpr int         kLogTail      = 300;   // 配布(Release)はwarnレベルso小さい＝現セッションぶんがほぼ全部入ります（検証Debugはinfoで多く末尾のみ）
        // 起動失敗ローリングログ＝SKSEログフォルダ（BugReport本体と同じ所）。全reasonを記録し、N行で古い順にトリムします。
        constexpr const char* kFailFileName = "ASTR2_SceneLaunchFail.txt";
        constexpr int         kFailTail     = 20;
        constexpr std::size_t kFailMaxLines = 200;   // ローリング上限（失敗は稀ですので数百件で十分です・ファイルは数KBです）

        // SKSE版数＝LoadInterfaceでしか取れないのでSKSEPluginLoadで一度受け取って保持します（SetSkseVersion）。
        std::string g_skseVer = "(unknown)";

        // 壁時計（"YYYY-MM-DD HH:MM:SS"）。ASTR2Native.Clock() と揃えます＝クラッシュログ/VMonと時刻照合できます。
        std::string WallClock() {
            std::time_t t = std::time(nullptr);
            std::tm     tm{};
            localtime_s(&tm, &t);
            char buf[32];
            std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm);
            return buf;
        }

        // std::filesystem::path を UTF-8 の std::string へ変換します。★path.string() はWindowsのANSI(CP1252/932)＝
        //   日本語パス(OneDrive\ドキュメント等)を壊します＝Papyrus/GFx(UTF-8前提)へ返すと化けます。u8stringでUTF-8バイトにします。
        std::string ToUtf8(const fs::path& p) {
            const auto u8 = p.u8string();
            return std::string(reinterpret_cast<const char*>(u8.data()), u8.size());
        }

        // ゲーム(SkyrimSE.exe)の版数＝"1.6.1170.0" 等。互換性切り分けの一次情報です。
        std::string GameVer() {
            auto v = REL::Module::get().version();
            return fmt::format("{}.{}.{}.{}", v[0], v[1], v[2], v[3]);
        }

        // ASTR2.esp のロード順index（未ロード＝致命的＝ここで分かります）。GetLoadedModIndex＝PowerResetで実証済みのAPIです。
        std::string Astr2Index() {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                if (auto idx = dh->GetLoadedModIndex(kEsp); idx.has_value()) {
                    return fmt::format("0x{:02X}", *idx);
                }
            }
            return "(NOT LOADED / 未ロード)";
        }

        // 任意ファイルの末尾n行です。fs::path を直接 ifstream に渡します＝Windowsではワイドで開きます＝日本語パスも安全です。
        std::string Tail(const fs::path& path, int n, const std::string& emptyMsg) {
            if (path.empty()) return emptyMsg + "\n";
            std::ifstream in(path);
            if (!in) return emptyMsg + "\n";
            std::vector<std::string> lines;
            std::string               l;
            while (std::getline(in, l)) lines.push_back(l);
            if (lines.empty()) return "(空)\n";
            const std::size_t tail  = static_cast<std::size_t>(n);
            const std::size_t start = lines.size() > tail ? lines.size() - tail : 0;
            std::string out;
            for (std::size_t i = start; i < lines.size(); ++i) out += lines[i] + "\n";
            return out;
        }

        // 起動失敗ローリングログのフルパスです（SKSEログフォルダ）。取れなければ空です。
        fs::path FailLogPath() {
            auto logs = SKSE::log::log_directory();
            return logs ? (*logs / kFailFileName) : fs::path();
        }

        // 実書き込み＝SKSEログフォルダへ丸ごと上書きします（毎回1枚に作り直します）。戻り値は生成先フルパス(UTF-8)です。
        std::string WriteReport(const std::string& astr2Ver,
                                const std::vector<std::string>& keys,
                                const std::vector<std::string>& vals) {
            auto logsFolder = SKSE::log::log_directory();
            if (!logsFolder) {
                spdlog::warn("[BugReport] log_directory 取得失敗");
                return "";
            }
            const auto    path = *logsFolder / "ASTR2_BugReport.txt";
            std::ofstream out(path, std::ios::trunc);
            if (!out) {
                spdlog::warn("[BugReport] 出力失敗: {}", ToUtf8(path));
                return "";
            }
            out << "===== ASuccubusTaleR2 Bug Report / 不具合報告 =====\n";
            out << "GeneratedAt (生成時刻) : " << WallClock()  << "\n";
            out << "ASTR2 version          : " << astr2Ver     << "\n";
            out << "Skyrim version         : " << GameVer()    << "\n";
            out << "SKSE version           : " << g_skseVer    << "\n";
            out << "ASTR2 dll built        : " << __DATE__ " " __TIME__ << "\n";
            out << "ASTR2 load index       : " << Astr2Index() << "\n";
            out << "\n----- State / 状態 -----\n";
            const std::size_t n = std::min(keys.size(), vals.size());
            for (std::size_t i = 0; i < n; ++i) {
                out << keys[i] << ": " << vals[i] << "\n";
            }
            spdlog::default_logger()->flush();   // 直近のwarn/[RARE]をディスクへ確実に出してから読みます（自プロセスが開いているログを読むため）
            out << "\n----- ASTR2SKSE.log (last " << kLogTail << " lines / セッションログ) -----\n";
            out << Tail(*logsFolder / "ASTR2SKSE.log", kLogTail, "(ASTR2SKSE.log なし)");
            out << "\n----- " << kFailFileName << " (last " << kFailTail << " lines / 直近のOStim起動失敗) -----\n";
            out << Tail(FailLogPath(), kFailTail, "(起動失敗の記録なし)");
            out << "===== end =====\n";
            spdlog::info("[BugReport] 生成完了: {} (state {} items)", ToUtf8(path), n);
            return ToUtf8(path);
        }

        // プレイヤーの現在セル（editorID→無ければformID）＋内外です。起動失敗の文脈用です（軽い読み）。
        std::string CellName(RE::Actor* p) {
            auto* cell = p ? p->GetParentCell() : nullptr;
            if (!cell) return "<no cell>";
            std::string s;
            if (const char* ed = cell->GetFormEditorID(); ed && *ed) {
                s = ed;
            }
            if (s.empty()) {
                s = fmt::format("0x{:X}", cell->GetFormID());
            }
            s += cell->IsInteriorCell() ? "(int)" : "(ext)";
            return s;
        }

        // ローリングログへ1行append＋末尾kFailMaxLines行に切り詰めます（古い順に落とします）。失敗は稀ですので毎回読み直し書き直しで十分です。
        void AppendTrim(const fs::path& path, const std::string& line) {
            if (path.empty()) return;
            std::vector<std::string> lines;
            {
                std::ifstream in(path);
                std::string    l;
                while (std::getline(in, l)) lines.push_back(l);
            }
            lines.push_back(line);
            if (lines.size() > kFailMaxLines) {
                lines.erase(lines.begin(), lines.begin() + (lines.size() - kFailMaxLines));
            }
            std::ofstream out(path, std::ios::trunc);
            if (!out) {
                return;
            }
            for (auto& s : lines) {
                out << s << "\n";
            }
        }

        // ---- Papyrus native: 不具合報告ファイル生成 ----
        //   astr2Ver＝ASTR2版数(Papyrusの定数)／keys,vals＝Papyrusが集めた項目名・値の対（任意個・同じ並び）。戻り値は生成先フルパス(UTF-8)です。
        std::string Papyrus_WriteBugReport(RE::StaticFunctionTag*, RE::BSFixedString astr2Ver,
                                           std::vector<RE::BSFixedString> keys,
                                           std::vector<RE::BSFixedString> vals) {
            const std::string ver = astr2Ver.c_str() ? astr2Ver.c_str() : "?";
            std::vector<std::string> ks, vs;
            ks.reserve(keys.size());
            vs.reserve(vals.size());
            for (auto& k : keys) ks.emplace_back(k.c_str() ? k.c_str() : "");
            for (auto& v : vals) vs.emplace_back(v.c_str() ? v.c_str() : "");
            return WriteReport(ver, ks, vs);
        }

        // ---- Papyrus native: OStimシーン起動失敗を1行記録（全reason・ローリング）----
        //   reason＝"combat"/"cellmove"/"timeout"（空も可）。時刻＋reason＋セル＋戦闘中フラグを1行appendし→200行にトリムします。
        void Papyrus_LogSceneLaunchFail(RE::StaticFunctionTag*, RE::BSFixedString reason) {
            const std::string r  = reason.c_str() ? reason.c_str() : "";
            auto*             pc = RE::PlayerCharacter::GetSingleton();
            const std::string line = fmt::format("{} reason={} cell={} combat={}",
                                                 WallClock(), r.empty() ? "(none)" : r,
                                                 CellName(pc), (pc && pc->IsInCombat()) ? 1 : 0);
            AppendTrim(FailLogPath(), line);
            spdlog::info("[BugReport] launch-fail logged: {}", line);
        }
    }

    // SKSE版数を保持します（SKSEPluginLoadから1回）。packed uint32_t を major.minor.beta へデコードします（skse64の詰め方＝上位バイトから）。
    void SetSkseVersion(std::uint32_t a_packed) {
        const unsigned major = (a_packed >> 24) & 0xFF;
        const unsigned minor = (a_packed >> 16) & 0xFF;
        const unsigned beta  = (a_packed >> 8)  & 0xFF;
        g_skseVer = fmt::format("{}.{}.{}", major, minor, beta);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("WriteBugReport", "ASTR2Native", Papyrus_WriteBugReport);
        vm->RegisterFunction("LogSceneLaunchFail", "ASTR2Native", Papyrus_LogSceneLaunchFail);
        spdlog::info("[BugReport] Papyrus native WriteBugReport / LogSceneLaunchFail 登録");
        return true;
    }
}
