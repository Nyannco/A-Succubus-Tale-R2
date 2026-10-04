#pragma once

// ============================================================================
// ServantRoster ― MCMサーヴァント一覧の列挙をC++化します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   名簿(〔SkyVault〕 List "ASTR2_ServantList" holder=0)を1パスで全ティアに仕分け＋
//   各人の tier(faction rank)/進捗"T.ff"(〔SkyVault〕点数)/生死/名前 を計算しキャッシュします。
//   MCMは BuildRoster() 1回＋ティア別 getter で受け取ります（旧Papyrusの最大12回フル走査を根治）。
// ============================================================================

namespace ServantRoster {
    // Papyrusネイティブ（ASTR2Servantship.BuildRoster / GetRosterRows / GetRosterActors / GetRosterCount）を登録します。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
