#pragma once

#include <cstdint>
#include <vector>

namespace RE {
    class Actor;
    namespace BSScript {
        class IVirtualMachine;
    }
}

// ============================================================================
// SceneLauncher ― 特定の OStim シーケンス/シーンを C++ から直接起動する土台です（再利用可）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   OStim の "Threads" PluginInterface(createThreadBuilder) を1回取得してキャッシュします。
//   Papyrus VM の順番待ちを挟みません＝会話ゼロと合わせてロマンスより速く起動します。
//   ★他の機能でも ASTR2Native.StartSequenceScene で特定シーンをC++から起動できます。
// ============================================================================
namespace SceneLauncher {
    // actors[0] が先頭(dom/位置0)です。sequenceId＝OStim/OCRのシーケンス名です（例 "OCR_FM_Kiss1"）。
    //   endAfter=true でシーケンス終了時にスレッドも終了します（演出向き）。undress=false で服のままです。
    //   戻り値＝threadID（>=0 成功／-1 失敗＝OStim不在・窓口取得不可・アクター不適格・空シーケンス）。
    std::int32_t StartSequence(const std::vector<RE::Actor*>& actors, const char* sequenceId,
                               bool endAfter, bool undress);

    // Papyrus native 登録します（ASTR2Native.StartSequenceScene）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
