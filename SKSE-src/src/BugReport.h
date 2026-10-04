#pragma once

// ============================================================================
// BugReport ― 不具合報告用の1枚ダンプ ASTR2_BugReport.txt を生成します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   プレイヤーが「これ送って」で1枚送れば状況が読めます。MCMボタン(ASTR2BugReport.Generate)から駆動します。
//   役割分担：Papyrus が自分しか持たない値（サキュバスLv/LF/覚醒/主要MCM設定/OStim API版/ASTR2版）を
//             keys/vals にまとめて渡します。C++ は自分しか取れない
//             「生成時刻(壁時計)・ゲーム版数・ASTR2ロードindex・ASTR2_RareLog.txt末尾」を足してファイルへ書きます。
//   出力先＝SKSEログフォルダ（ASTR2SKSE.log と同じ所＝プレイヤーが一番見つけやすい／CatalogDumpと同作法）。
//   戻り値＝生成先フルパス（MCMのinfo欄に出す用・UTF-8）／失敗時は空文字。
//   Papyrus: String ASTR2Native.WriteBugReport(String astr2Ver, String[] keys, String[] vals)
//
//   ＋ OStimシーン起動失敗のローリングログ＝失敗3種(combat/cellmove/timeout)を全部
//   ASTR2_SceneLaunchFail.txt に「時刻＋reason＋セル＋戦闘中」で1行append→200行で古い順にトリムします。
//   BugReport本体にもこのログの末尾を載せます（1枚で直近の起動失敗履歴が読めます）。
//   Papyrus: ASTR2Native.LogSceneLaunchFail(String reason)
// ============================================================================

namespace BugReport
{
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm);

    // SKSE版数をLoadInterfaceから受け取り保持します（BugReportに載せる用）。SKSEPluginLoadで1回呼びます。
    //   ★skse->SKSEVersion() は packed uint32_t を返す（REL::Versionでない）＝そのまま受けてデコードします。
    void SetSkseVersion(std::uint32_t a_packed);
}
