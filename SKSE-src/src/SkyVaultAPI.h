#pragma once

#include <cstdint>

// GetSkyVaultAPI() は GetModuleHandleA/GetProcAddress(Windows API)を使います＝ヘッダ自己完結でWindows.hを取り込みます
// （消費側はインクルード順を気にしなくて構いません）。NOMINMAX/LEAN_AND_MEANはガードで安全にします。
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

// ============================================================================
// 〔SkyVault〕 C++ API ― 消費側(他SKSEプラグイン=ASTR2/セイレーン…)がインクルードするヘッダです。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   SkyVault.dll の RequestSkyVaultAPI を GetProcAddress で取得→IVault* を得て直接呼びます
//   （OStim/SKEE と同型の枯れた"C++窓口"の手です）。
//   ★RE型を跨がせません＝ABI安全です（holderはFormID uint32で渡します）。
//   ★holder = フォームのFormIDです。0 = グローバル名前空間(設定用=StorageUtilの「フォーム無し」相当です)。
// ============================================================================

namespace SkyVaultAPI {
    constexpr std::uint32_t kAPIVersion = 1;

    class IVault {
    public:
        virtual ~IVault() = default;

        virtual float         GetFloat(std::uint32_t a_holder, const char* a_key, float a_default) = 0;
        virtual void          SetFloat(std::uint32_t a_holder, const char* a_key, float a_value) = 0;
        virtual std::int32_t  GetInt(std::uint32_t a_holder, const char* a_key, std::int32_t a_default) = 0;
        virtual void          SetInt(std::uint32_t a_holder, const char* a_key, std::int32_t a_value) = 0;
        // GetStr: 返り値はスレッドローカル内部バッファ＝「次の GetStr 呼び出しまで」有効です。長く持つならコピーを取ってください。
        virtual const char*   GetStr(std::uint32_t a_holder, const char* a_key, const char* a_default) = 0;
        virtual void          SetStr(std::uint32_t a_holder, const char* a_key, const char* a_value) = 0;
        virtual void          Unset(std::uint32_t a_holder, const char* a_key) = 0;

        virtual void          ListAdd(std::uint32_t a_holder, const char* a_key, std::uint32_t a_itemFormID, bool a_unique) = 0;
        virtual std::uint32_t ListGet(std::uint32_t a_holder, const char* a_key, std::int32_t a_index) = 0;  // FormID（0=無し/範囲外です）
        virtual std::int32_t  ListCount(std::uint32_t a_holder, const char* a_key) = 0;
        virtual void          ListRemoveAt(std::uint32_t a_holder, const char* a_key, std::int32_t a_index) = 0;
        virtual bool          ListHas(std::uint32_t a_holder, const char* a_key, std::uint32_t a_itemFormID) = 0;
    };

    using RequestAPIFn = IVault* (*)(std::uint32_t a_apiVersion);

    // SkyVault.dll から C++ API を取得します（1回取ってキャッシュ推奨です）。dll不在/版不一致なら nullptr です。
    inline IVault* GetSkyVaultAPI() {
        const auto handle = GetModuleHandleA("SkyVault.dll");
        if (!handle) {
            return nullptr;
        }
        const auto request = reinterpret_cast<RequestAPIFn>(
            reinterpret_cast<void*>(GetProcAddress(handle, "RequestSkyVaultAPI")));
        return request ? request(kAPIVersion) : nullptr;
    }
}
