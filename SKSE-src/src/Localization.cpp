#include "PCH.h"
#include "Localization.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

// ============================================================================
// LocFmt 実装 ― 翻訳txtを直接解析する経路です（CPP_SKSE_REFERENCE 山E）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   Data/Interface/Translations/A Succubus Tale R2_<sLanguage>.txt（UTF-16LE・タブ区切り）を解析して
//   key->訳文 のキャッシュにします（english は常にフォールバックとして読み込みます）。LocFmt(key, vals) は訳文を引いて
//   {0}/{1}/... を値（int に切り捨て）で埋め、完成した UTF-8 文字列を返します。
//   GFx 内部には触りません（SceneCatalog のファイル読み方式を流用します）。
// ============================================================================

namespace {
    // key（小文字化）-> 訳文（UTF-8）。active = 現在の sLanguage／english = フォールバック。
    std::map<std::string, std::string> g_active;
    std::map<std::string, std::string> g_english;
    std::mutex g_mutex;

    std::string toLower(std::string s) {
        std::transform(s.begin(), s.end(), s.begin(),
                       [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return s;
    }

    // ini の sLanguage:General から現在のゲーム言語を取ります（既定 "english"）。
    std::string GetLanguage() {
        std::string lang = "english";
        if (auto* setting = RE::GetINISetting("sLanguage:General")) {
            if (setting->GetType() == RE::Setting::Type::kString && setting->GetString() && setting->GetString()[0]) {
                lang = setting->GetString();
            }
        }
        return toLower(lang);
    }

    // UTF-16LE（BOM）・タブ区切りの翻訳ファイルを key(小文字)->値(UTF-8) に読み込みます。
    void LoadFile(const std::string& path, std::map<std::string, std::string>& out) {
        std::ifstream ifs(path, std::ios::binary);
        if (!ifs) {
            return;
        }
        std::vector<char> bytes((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
        if (bytes.size() < 2) {
            return;
        }
        size_t off = 0;
        if (static_cast<unsigned char>(bytes[0]) == 0xFF && static_cast<unsigned char>(bytes[1]) == 0xFE) {
            off = 2;  // UTF-16LE BOM を飛ばす
        }
        // UTF-16LE のコードユニットを集めます
        std::u16string u16;
        u16.reserve((bytes.size() - off) / 2);
        for (size_t i = off; i + 1 < bytes.size(); i += 2) {
            u16.push_back(static_cast<char16_t>(static_cast<unsigned char>(bytes[i]) |
                                                (static_cast<unsigned char>(bytes[i + 1]) << 8)));
        }
        // UTF-16 -> UTF-8 を手動で変換します（Windows API 不使用・サロゲートペア対応）
        std::string u8;
        u8.reserve(u16.size() * 2);
        for (size_t i = 0; i < u16.size(); ++i) {
            std::uint32_t cp = u16[i];
            if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < u16.size()) {
                const std::uint32_t lo = u16[i + 1];
                if (lo >= 0xDC00 && lo <= 0xDFFF) {
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                    ++i;
                }
            }
            if (cp < 0x80) {
                u8.push_back(static_cast<char>(cp));
            } else if (cp < 0x800) {
                u8.push_back(static_cast<char>(0xC0 | (cp >> 6)));
                u8.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            } else if (cp < 0x10000) {
                u8.push_back(static_cast<char>(0xE0 | (cp >> 12)));
                u8.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
                u8.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            } else {
                u8.push_back(static_cast<char>(0xF0 | (cp >> 18)));
                u8.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
                u8.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
                u8.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            }
        }

        size_t start = 0;
        while (start < u8.size()) {
            const size_t nl = u8.find('\n', start);
            std::string line = (nl == std::string::npos) ? u8.substr(start) : u8.substr(start, nl - start);
            start = (nl == std::string::npos) ? u8.size() : nl + 1;
            while (!line.empty() && (line.back() == '\r' || line.back() == '\n')) {
                line.pop_back();
            }
            if (line.empty() || line[0] != '$') {
                continue;
            }
            const size_t tab = line.find('\t');
            if (tab == std::string::npos) {
                continue;
            }
            const std::string key = toLower(line.substr(0, tab));
            if (!key.empty()) {
                out[key] = line.substr(tab + 1);
            }
        }
    }

    std::string Lookup(const std::string& keyLower) {
        auto it = g_active.find(keyLower);
        if (it != g_active.end()) {
            return it->second;
        }
        it = g_english.find(keyLower);
        if (it != g_english.end()) {
            return it->second;
        }
        return "";
    }

    // {0},{1},... を int に切り捨てた値で置換します。
    std::string Substitute(std::string tmpl, const std::vector<float>& vals) {
        for (size_t i = 0; i < vals.size(); ++i) {
            const std::string token = "{" + std::to_string(i) + "}";
            const std::string rep = std::to_string(static_cast<long long>(vals[i]));  // ゼロ方向へ切り捨て
            size_t pos = 0;
            while ((pos = tmpl.find(token, pos)) != std::string::npos) {
                tmpl.replace(pos, token.size(), rep);
                pos += rep.size();
            }
        }
        return tmpl;
    }

    // ===== Papyrus ネイティブ: ASTR2Native.LocFmt(key, vals[]) =====
    //   key の訳文の {0}/{1}/... を vals（int に切り捨て）で埋めて返します。
    //   key が見つからない -> 生キーを返します（＝翻訳漏れが見えます）。
    RE::BSFixedString Papyrus_LocFmt(RE::StaticFunctionTag*, RE::BSFixedString key, std::vector<float> vals) {
        std::lock_guard lk(g_mutex);
        const std::string k = toLower(std::string(key.c_str()));
        const std::string txt = Lookup(k);
        if (txt.empty()) {
            return key;
        }
        return RE::BSFixedString(Substitute(txt, vals).c_str());
    }

    // ===== Papyrus ネイティブ: ASTR2Native.LocFmtF(key, val) ===== 単一値の簡易版です。
    RE::BSFixedString Papyrus_LocFmtF(RE::StaticFunctionTag* tag, RE::BSFixedString key, float val) {
        std::vector<float> v{ val };
        return Papyrus_LocFmt(tag, key, v);
    }

    // ===== Papyrus ネイティブ: ASTR2Native.LocFmtStr(key, args[]) =====
    //   {0}/{1}/... を文字列 args でそのまま置換します（名前など）。数値は呼び側で String 化して渡します＝
    //   名前+数字混在の通知文(「○○を魅了できなかった (50/90)」)を作れる汎用版です。key未収録→生キーを返します。
    RE::BSFixedString Papyrus_LocFmtStr(RE::StaticFunctionTag*, RE::BSFixedString key, std::vector<RE::BSFixedString> args) {
        std::lock_guard lk(g_mutex);
        const std::string k = toLower(std::string(key.c_str()));
        const std::string txt = Lookup(k);
        if (txt.empty()) {
            return key;
        }
        std::string out = txt;
        for (size_t i = 0; i < args.size(); ++i) {
            const std::string token = "{" + std::to_string(i) + "}";
            const std::string rep = args[i].c_str() ? std::string(args[i].c_str()) : std::string();
            size_t pos = 0;
            while ((pos = out.find(token, pos)) != std::string::npos) {
                out.replace(pos, token.size(), rep);
                pos += rep.size();
            }
        }
        return RE::BSFixedString(out.c_str());
    }
    // ===== Papyrus ネイティブ: ASTR2Native.Clock() =====
    //   実時計(YYYY-MM-DD HH:MM:SS)を返します。RareLog等の各行に「いつ」を刻みます＝VMon.log/クラッシュログ(壁時計)と
    //   時刻照合できます。RareLogはセッション跨ぎで永続ですので、起動相対のGetCurrentRealTimeでは意味を成しません＝壁時計が正です。
    RE::BSFixedString Papyrus_Clock(RE::StaticFunctionTag*) {
        std::time_t tt = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::tm tmv{};
        localtime_s(&tmv, &tt);
        std::ostringstream s;
        s << std::put_time(&tmv, "%Y-%m-%d %H:%M:%S");
        return RE::BSFixedString(s.str().c_str());
    }
    // ===== Papyrus ネイティブ: ASTR2Native.Fmt1(float) =====
    //   float を小数1桁の文字列("N.N")で返します。LocFmtF経由(Substitute)は float を整数truncateしますので
    //   MCM値カラムで小数を出すのに使います（+符号や単位は呼び側で付けます）＝ネイル現在効果の小数化に使います。
    RE::BSFixedString Papyrus_Fmt1(RE::StaticFunctionTag*, float v) {
        return RE::BSFixedString(fmt::format("{:.1f}", v).c_str());
    }
    // ===== Papyrus ネイティブ: ASTR2Native.LogRare(tag, msg) =====
    //   レア事象を spdlog::warn で ASTR2SKSE.log に出します（配布版の warn フィルタを通過＝不具合報告にも乗ります）。
    //   旧 ASTR2_RareLog.txt への直書きを廃し、C++ログへ出力先を一本化します（ファイル数削減・overwriteを汚さない）。時刻は spdlog が各行に付けます。
    void Papyrus_LogRare(RE::StaticFunctionTag*, RE::BSFixedString tag, RE::BSFixedString msg) {
        spdlog::warn("[RARE/{}] {}", tag.c_str() ? tag.c_str() : "", msg.c_str() ? msg.c_str() : "");
    }
}

namespace Localization {
    // C++用の入口です＝Papyrus_LocFmtStr と同じ引き方/差し込み方（実装を1か所に寄せずに済むよう最小で複製します）。
    std::string LocFmtStrCpp(const std::string& key, const std::vector<std::string>& args) {
        std::lock_guard lk(g_mutex);
        const std::string txt = Lookup(toLower(key));
        if (txt.empty()) {
            return key;  // 未収録＝生キーを返します（画面に出て翻訳漏れが分かります）
        }
        std::string out = txt;
        for (size_t i = 0; i < args.size(); ++i) {
            const std::string token = "{" + std::to_string(i) + "}";
            size_t pos = 0;
            while ((pos = out.find(token, pos)) != std::string::npos) {
                out.replace(pos, token.size(), args[i]);
                pos += args[i].size();
            }
        }
        return out;
    }

    void Build() {
        std::lock_guard lk(g_mutex);
        g_active.clear();
        g_english.clear();
        const std::string base = "Data/Interface/Translations/A Succubus Tale R2_";
        const std::string lang = GetLanguage();
        LoadFile(base + "english.txt", g_english);  // english は常にフォールバック
        if (lang != "english") {
            LoadFile(base + lang + ".txt", g_active);
        }
        spdlog::info("[Localization] lang={} active={} english={}", lang, g_active.size(), g_english.size());
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("LocFmt", "ASTR2Native", Papyrus_LocFmt);
        vm->RegisterFunction("LocFmtF", "ASTR2Native", Papyrus_LocFmtF);
        vm->RegisterFunction("LocFmtStr", "ASTR2Native", Papyrus_LocFmtStr);
        vm->RegisterFunction("Clock", "ASTR2Native", Papyrus_Clock);
        vm->RegisterFunction("Fmt1", "ASTR2Native", Papyrus_Fmt1);
        vm->RegisterFunction("LogRare", "ASTR2Native", Papyrus_LogRare);
        spdlog::info("[Localization] Papyrus native ASTR2Native.LocFmt / LocFmtF / LocFmtStr / Clock / Fmt1 / LogRare registered");
        return true;
    }
}
