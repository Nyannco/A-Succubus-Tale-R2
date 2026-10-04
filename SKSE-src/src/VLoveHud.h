#pragma once

#include <string>

// ============================================================================
// VLoveHud ― 寵愛切れ警告のHUD描画です（本番キュー版）。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   本番＝VassalUpkeep.cpp が確定文字列（名前・残り時間・<font>差込済）を
//         Enqueue → 1体ずつ 5秒ずつ 順番にHUD表示します（Notifyで3体同時に表示が重なり判読不能になる問題を解消します）。
//   ON/OFF＝〔SkyVault〕 Int `ASTR2_VLoveHudOn`（1=表示/0=非表示・既定1）。OFFはキューを捨てて何も出しません。
//   位置＝〔SkyVault〕 Int を毎描画read（MCMスライダー即反映）：
//         ASTR2_VLoveHudX(30) / ASTR2_VLoveHudY(380・画面下からの上げ幅) / ASTR2_VLoveHudStep(行間40)
//   プレビュー＝位置スライダーを動かして「MCMを閉じた瞬間」に、一番長いダミー文言を 5秒間・秒カウントダウン(5→1)で表示します
//              （位置合わせ用・旧「テスト常時表示」の置き換え／メニュー中はHUDが裏なので閉じてからカウントします）。
//   土台＝TechHud（createTextField＋$別名フォント）に相乗りします。
// ============================================================================

namespace VLoveHud
{
    // kDataLoaded＝〔クロノス〕へ実時間くり返しで登録します（表示ON/OFF・プレビューは毎描画で判定します）。
    void Install();

    // 本番キュー：確定HTML文字列を1本積みます。1体ずつ5秒ずつHUD表示します（上限6本・超で古いのを捨てます）。
    //   呼び出し側は #include "VLoveHud.h" → VLoveHud::Enqueue(str)。
    void Enqueue(const std::string& a_text);
}
