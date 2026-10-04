#pragma once

#include <functional>
#include <string>

// ============================================================================
//  動的説明文レジストリ
//   TESDescription::GetDescription を1本フックし、登録されたフォーム(呪文/アイテム)の
//   ツールチップ本文を「ビルダーが返す文字列」へ差し替えます。ネイル7種が最初の利用者です。
//   呼び出し側は自分のフォームの説明ビルダーを Register(form, builder) で load時(Install)に登録します。
//   ★魔法メニュー・item cardとも日本語/改行が使えます（実機で確認・書式は呼び側ビルダーの責任）。詳細は NailDesc.cpp。
// ============================================================================
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
namespace NailDesc {
    void Install();

    // 動的DESC登録の内部窓口（cast は下の template Register が行います）。load時に呼びます。
    void RegisterDesc(RE::TESDescription* a_desc, std::function<std::string()> a_builder);

    // 任意のフォーム(TESObjectARMO/SpellItem 等・TESDescription継承)に説明ビルダーを紐付けます。
    //   例: NailDesc::Register(mySpell, []() { return BuildMyDesc(); });
    //   T の TESDescription サブオブジェクトのオフセットはコンパイラが計算します（ハードコード不要）。
    template <class T>
    inline void Register(T* a_form, std::function<std::string()> a_builder) {
        if (a_form) {
            RegisterDesc(static_cast<RE::TESDescription*>(a_form), std::move(a_builder));
        }
    }
}
