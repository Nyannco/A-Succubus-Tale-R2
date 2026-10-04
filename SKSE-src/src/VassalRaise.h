#pragma once

// ============================================================================
// VassalRaise ― スイート・ヴァッサル(Sweet Vassal)の「生者化」コア（Papyrus不可をC++で）
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・起こす(ふわー)のは ESP の Reanimate archetype 効果(MGEF 0100BF75)がエンジンで直接やります＝このnativeは死体を起こしません。
//   ・reanimateはアニメグラフを組み直すので1回購読は無音化する→std::thread の実時間100ms間隔で
//     再購読し続け、組み直し後グラフに必ず乗せる＋5秒タイムアウトで強制実行します(固着の最後の砦)。
//   ・生者化＝Resurrect→生者状態→Reanimate効果をDispel→召喚体の紐付け解除。Dispelは生者化の"後"なら
//     崩れません／残すと効果が紐付けを付け直して「- 所有者名」＋会話不可になります。
//   ・Papyrus: ASTR2Native.ConvertVassalToLiving(キス会話で直接生者化) / CancelVassalRaise(クエストNPCガード＝起き上がり後Kill)。
//     Vassal管理(VassalList/Duration/税/寵愛)は同一refにPapyrusが乗せます。
// ============================================================================

namespace VassalRaise {
    // Papyrus ネイティブ関数を登録します（SKSEPluginLoad で1回）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);
}
