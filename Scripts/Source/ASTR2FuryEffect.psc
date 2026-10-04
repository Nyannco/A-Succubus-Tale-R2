Scriptname ASTR2FuryEffect extends activemagiceffect
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; 🔥 アンリーシュド・フューリー（Fury）はグレーターパワーのトグルです。ON/OFF切替は PowerReset(SpellCast 0x09) がC++で駆動します。
;   ・ON  ：Lv別バフを適用し、毎秒 淫魔力（LF）を消費開始（最大LF×(11-Lv)×0.1%）
;   ・再押しでOFF ：バフ撤去＋「累計消費LF×10%」を変性XPへまとめて付与
;   ・淫魔力（LF）0/覚醒OFFで自動OFF。実処理はすべてC++側で、チャネル/バフ/コスト/XP/ダメージカットを一元管理します。
; ★MGEF 00B4A7(MSRTSuccubusMagickaPower)に「相乗り」で付きます。マジカ再生+20%の PeakValueMod archetypeは
;   従来どおり効きます（固定・触らない）。
; ★トグルは OnEffectStart 依存をやめ SpellCast駆動へ一本化しました。再キャストで OnEffectStart が
;   再発火せず「再使用でOFFできない」問題への対策です。SPEL 00B4AA を Type=グレーターパワーにし、PowerReset の
;   CheckCast exempt でグレーアウトを外します。再押しが SpellCast まで届き確実にトグルします。このOnEffectStartは二重
;   トグル防止のため何もしません（残すのは MGEF に付けるスクリプト枠として）。

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; ★何もしません。ON/OFFトグルは PowerReset の SpellCastフックが駆動します（上のバナー参照）。
EndEvent
