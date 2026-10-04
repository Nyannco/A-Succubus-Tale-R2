#pragma once

// H中ドレインfloor（殺さない下限）のSkyVaultキー ASTR2_FloorPctH / ASTR2_FloorAbs の
//   フォールバック既定値の単一の正です。HDrain と HpBarHud が共用し、数値の二重持ち(片方だけ直してズレる事故)を防ぎます。
//   キー未設定の間だけこの既定を使います（原本は ASTDrainScript.FloorPctH / FloorAbs のプロパティ）。
namespace DrainFloor {
    inline constexpr float kFloorPctHDef = 0.10f;   // ASTR2_FloorPctH ＝H中floor＝最大HP×これです
    inline constexpr float kFloorAbsDef  = 15.0f;   // ASTR2_FloorAbs  ＝絶対下限です
}
