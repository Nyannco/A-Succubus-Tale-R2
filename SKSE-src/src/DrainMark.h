#pragma once

// ============================================================================
// DrainMark ― H中ドレインの「1回制限」＝吸った相手にゲーム内24時間の痕を残します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   MCMトグルで ON/OFF（既定OFF＝制限なし）。ONの時だけ：
//     ・吸った瞬間に痕を打ちます＝ゲーム内時刻(GameDaysPassed)を〔SkyVault〕へ記録し＋淫紋(ロゴ)を貼ります
//       ★ロゴの位置＝**男=背中／女・フタ=胸**。ウィークネス/手下の股間紋とは
//         別枠so同じ相手に両方付いても被りません・互いに消しません（Sigil::ApplyDrainMark）。
//     ・痕がある相手はH中ドレインの〔門番〕で弾きます＝ゲーム内24時間は二度吸えません
//     ・残り時間で淫紋が6段階に薄れます＝見れば「あとどれくらいで吸えるか」が分かります
//
//   ★C++で持つ理由＝痕の対象は数十人規模になり得ます＝巡回(段階更新)をPapyrusで回すと
//     VMに列ができます。C++なら実時間30秒の軽い走査で済み、段階変化も細かく出せます。
//   ★"24時間"はゲーム内の1日です。魔法効果のDurationは実時間秒使いません（実プレイ24時間＝実質永久）。
//
//   〔SkyVault〕キー（holder=0=グローバル／holder=NPCのFormID）
//     ASTR2_DrainMarkOn    Int   holder0  1=1回制限ON（既定0=OFF）※MCMが書く
//     ASTR2_DrainMarkList  List  holder0  痕が残ってるNPCのFormID一覧（巡回の対象）
//     ASTR2_DrainMark_Day  Float holderNPC 痕を打った時のゲーム内日数
//   ※胸/背中のアートは性別共用so竿の有無は不要です（旧 ASTR2_DrainMark_Sch は廃止しました）。
// ============================================================================

namespace DrainMark
{
    // MCMトグル＝1回制限が有効かどうかです（〔SkyVault〕 ASTR2_DrainMarkOn・既定OFF）。
    bool Enabled();

    // この相手は痕が残っている（＝まだ吸えません）かどうかです。OFFの時は常に false＝〔門番〕ごと素通りです。
    bool IsMarked(RE::Actor* a_npc);

    // 痕を打ちます＝時刻記録＋淫紋を満タン段階で貼り＋巡回へ載せます。OFFの時は何もしません。
    //   ドレイン核(HDrain)が「吸った直後」に1回呼びます。
    void Mark(RE::Actor* a_npc);                             // ドレイン痕(HDrain・トグルON時)＝既存互換(旧シンボル維持=リンク安定)
    void Mark(RE::Actor* a_npc, bool a_nightmare);           // a_nightmare=true＝夢魔痕(トグル非依存で常に付きます/巡回でOFFでも消しません)

    // kDataLoaded＝起動ログ（稼働してることの刻印）。
    void Install();

    // kPostLoadGame/kNewGame＝セーブに残ってる痕があれば巡回を再開します。
    void OnLoadGame();

    // 覚醒OFF(人間化)＝痕を全部畳みます。各NPCの淫紋を消し、〔SkyVault〕キー/リストを掃除します。
    //   ★覚醒OFFはアンインストール前の必須作業ですので、残った淫紋を能動的に消しきります
    //     （放置すると巡回が大元ポーズ ASTR2_Awake=0 で止まり淫紋が凍結します。MODを外すと印が残ってしまいます）。
    void ClearAll();

    // Papyrus ネイティブ登録します（ASTR2Native.DrainMarkClearAll）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm);
}
