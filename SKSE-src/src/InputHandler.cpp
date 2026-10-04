#include "PCH.h"
#include "InputHandler.h"

#include <fstream>

// ============================================================================
//  Shift+T → tfc トグル＋ T の待機メニュー暴発を抑制します
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//  フック位置・方式は OAR と同一です（入力ディスパッチ呼び出しを write_call で差し替えます）。
// ============================================================================

namespace {
    // --- DirectInput スキャンコード（キーボード） ---
    constexpr std::uint32_t kScan_T = 0x14;  // T（バニラ＝待機）
    constexpr std::uint32_t kScan_LShift = 0x2A;
    constexpr std::uint32_t kScan_RShift = 0x36;

    // Shift の押下状態です（入力イベントから随時更新）。フレームを跨いで保持されます。
    bool g_shiftHeld = false;

    // ASTR2SKSE.ini の [FreeCamHotkey] bEnabled が 1 のときだけ true（既定=false）。
    // WinAPI(GetPrivateProfileInt)はCommonLibSSE環境で宣言が見えないので、標準C++で素朴に読みます。
    bool IsFreeCamHotkeyEnabled() {
        std::ifstream ini("Data\\SKSE\\Plugins\\ASTR2SKSE.ini");
        if (!ini) {
            return false;  // INI が無ければ OFF です
        }
        std::string line;
        while (std::getline(ini, line)) {
            const auto key = line.find("bEnabled");
            if (key == std::string::npos) {
                continue;
            }
            const auto eq = line.find('=', key);
            if (eq == std::string::npos) {
                continue;
            }
            for (std::size_t i = eq + 1; i < line.size(); ++i) {
                const char c = line[i];
                if (c == ' ' || c == '\t' || c == '\r') {
                    continue;  // 空白は読み飛ばします
                }
                return c == '1';  // bEnabled=1 のときだけ有効です
            }
        }
        return false;
    }

    // フリーカメラ(tfc相当)をトグルします。
    //   ・コンソール発行(Script::CompileAndRun)は入力フック内から呼ぶとCTDするので使いません。
    //   ・カメラAPIを直叩きし、さらに SKSEタスクで"次フレームの安全な時点"へ回します（再入防止）。
    void ToggleFreeCamera() {
        SKSE::GetTaskInterface()->AddTask([]() {
            if (auto* camera = RE::PlayerCamera::GetSingleton()) {
                camera->ToggleFreeCameraMode(false);  // false = 時間は止めません（素の tfc 相当）
            }
        });
    }

    // ゲーム本体へ渡る手前で入力イベント列を覗き、Shift+T を処理します。
    void HandleInput(RE::InputEvent* const* a_events) {
        if (!a_events) {
            return;
        }

        for (auto* event = *a_events; event; event = event->next) {
            auto* button = event->AsButtonEvent();
            if (!button) {
                continue;
            }
            if (button->GetDevice() != RE::INPUT_DEVICE::kKeyboard) {
                continue;
            }

            const auto key = button->GetIDCode();

            // Shift 状態を更新します（押下中＝value!=0）
            if (key == kScan_LShift || key == kScan_RShift) {
                g_shiftHeld = button->IsPressed();
                continue;
            }

            // Shift 押下中の T を握り潰します
            if (key == kScan_T && g_shiftHeld) {
                // 押した瞬間だけ tfc を1回トグルします（押しっぱなしで連打しません）
                if (button->IsDown()) {
                    ToggleFreeCamera();
                    spdlog::info("Shift+T: toggled free camera (tfc)");
                }
                // value=0 にして「押されていない」状態に見せる＝待機メニューを暴発させません
                button->value = 0.0f;
                button->heldDownSecs = 0.0f;
            }
        }
    }

    // --- 入力ディスパッチ関数のフック（OAR と同一ターゲット） ---
    struct InputDispatchHook {
        static void thunk(RE::BSTEventSource<RE::InputEvent*>* a_dispatcher, RE::InputEvent* const* a_events) {
            HandleInput(a_events);          // 先に自前処理します（T を無力化済み）
            func(a_dispatcher, a_events);   // 改変後の列を本家へ渡します
        }
        static inline REL::Relocation<decltype(thunk)> func;
    };
}

namespace InputHandler {
    void Install() {
        // 既定はOFFです。Data\SKSE\Plugins\ASTR2SKSE.ini の [FreeCamHotkey] bEnabled=1 のときだけ有効化します。
        //   ・公開ASTR2＝INI無し/0 → フック設置せず＝Shift+Tは化けません（押し付けません）
        //   ・この機能は個人QoLです。個人用dll側で使う想定で、ASTR2側は0のままにします。
        if (!IsFreeCamHotkeyEnabled()) {
            spdlog::info("FreeCam hotkey disabled (ini bEnabled!=1). Input hook not installed.");
            return;
        }

        // ★トランポリンは plugin.cpp で一括確保済みです（個別AllocTrampolineは後勝ちで他フックを壊すので廃止します）
        auto& trampoline = SKSE::GetTrampoline();

        // 入力ディスパッチ呼び出し（SE 67315 / AE 68617 / VR 0xC519E0）の +0x7B にある call を差し替えます
        const REL::Relocation<std::uintptr_t> hookPoint{ REL::VariantID(67315, 68617, 0xC519E0) };
        InputDispatchHook::func = trampoline.write_call<5>(
            hookPoint.address() + REL::VariantOffset(0x7B, 0x7B, 0x81).offset(),
            InputDispatchHook::thunk);

        spdlog::info("InputHandler installed (Shift+T -> tfc).");
    }
}
