#pragma once

// ============================================================================
// WeaknessSigil ― サキュバス・ウィークネス中のNPC淫紋「段階更新」を C++ が持ちます。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   旧＝`ASTR2WeaknessEffect` が効果中ずっと `RegisterForSingleUpdate(SigilTickSec=10)` を自己再予約し、
//       残り割合を計算して `UpdateNpcSigil`（中身はC++）を呼ぶだけでした＝**C++の関数を呼ぶために
//       Papyrusが10秒ごとに起きている**状態です。しかも相手1人につき1ループ＝複数人に撃つと人数ぶん並びます。
//   新＝効果開始で「この相手を○秒ぶん」登録するだけです。段階更新は〔クロノス〕の実時間くり返しジョブが
//       まとめて面倒を見ます＝Papyrusのループは消えます。
//
//   ★手下優先は**ロゴ(淫紋)の表示についてだけ**です＝相手がスイート・ヴァッサルの手下なら
//     淫紋を貼りません/更新しません/消しません（手下の淫紋を尊重します）。**ウィークネスの効果自体は普通に効きます**
//     （耐性ダウンはMGEFsoエンジン管理・こちらは一切触りません）。
//   ★判定は `ASTR2ActiveMinionFaction`(0x01D278) 所属で行います＝VassalDeath.cpp と同じ見方です。
//     （旧Papyrusは StorageUtil の `ASTR2_VassalList` を見ていましたが、StorageUtilはC++から読めないため）
// ============================================================================

namespace WeaknessSigil
{
    // 〔クロノス〕へ段階更新ジョブを登録します（kDataLoaded 後に1回）。
    void Install();

    // 覚醒OFF(人間化)＝登録中の全ウィークネス淫紋を今すぐ消して登録を空にします。
    //   ★このジョブは実時間くり返し＝大元ポーズ(ASTR2_Awake)の対象外so、覚醒OFFで能動的に消さないと
    //     NPCに乗った淫紋がエンジンのDuration切れまで残ります（長時間もあり得ます）＝MOD撤去前に消しきります。
    void ClearAll();

    // Papyrus ネイティブに登録します（ASTR2Native.WeaknessSigilBegin / WeaknessSigilEnd / WeaknessSigilClearAll）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);
}
