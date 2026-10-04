#pragma once

// グレーターパワーの「1日1回」を、お気に入りを壊さずに解除する仕掛けです（使用権=トークン制）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ★仕組み＝CDタイマー(exe内部・CommonLib非公開)には触らず、キャスト判定 ActorMagicCaster::CheckCast の
//     "結果"だけを差し替えます（kPowerUsed → kOK）。RemoveSpell/AddSpellを使わないのでお気に入りは無傷です。
//   実機で実証した方式に基づきます。
namespace PowerReset {
    // vtableフックを仕掛けます（kDataLoadedで1回）。対象パワーの解決もここで行います。
    void Install();

    // ---- 火種の復元＝保存の正は外部 〔SkyVault〕（自前コセーブ）。ASTR2はコセーブを持ちません。----
    //   ロード後(kPostLoadGame)／新規(kNewGame)に呼び出す＝〔SkyVault〕のコセーブ読込後に g_tokens をシード。
    void SyncFromVault();

    // Papyrusネイティブ(ASTR2Native.AddPowerTokens / GetPowerTokens)を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
