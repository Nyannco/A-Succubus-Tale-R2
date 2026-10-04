#pragma once

#include <algorithm>   // 呼び出し側の std::max / std::clamp 用です

// サキュバスLv（GlobalVariable 0x000D64 / "A Succubus Tale R2.esp"）を読む共有ヘルパーです。
//   以前は各C++モジュール(12箇所)に同じ読み取りボイラープレートがコピペされていました。ここに一本化します。
//   ★clamp/fallbackは呼び出し側が持ちます（モジュールごとに意味が違うため・挙動は従来を完全保存）：
//     ・ドレイン/コスト核   → std::max(1, SuccLevel::Raw(1))         （最低1・未取得=1）
//     ・表示/DESC(式cap)    → std::clamp(SuccLevel::Raw(1), 1, 100)  （最低1・上限100・未取得=1）
//     ・減衰/維持費/数値表示 → SuccLevel::Raw(0)                      （生値・未取得=0＝「サキュバスでない」）
//   ※RE型を使うので PCH.h（RE/Skyrim.h の後）から include しています。
namespace SuccLevel {
    // サキュバスLvの生値を返します。グローバル/データが取れない時は a_ifMissing を返します。
    inline int Raw(int a_ifMissing) {
        if (auto* dh = RE::TESDataHandler::GetSingleton()) {
            if (auto* g = dh->LookupForm<RE::TESGlobal>(0x000D64, "A Succubus Tale R2.esp")) {
                return static_cast<int>(g->value);
            }
        }
        return a_ifMissing;
    }
}
