Scriptname ASTR2Log Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。

; =====================================================================================
; 📝 デバッグ共通ロガーです。
;   ・iniは一切いじりません。PapyrusUtilのMiscUtil.WriteToFileでテキストに追記するだけです。
;   ・どのスクリプトからでも  ASTR2Log.Write("タグ", "本文")  の1行で書き出せます。
;   ・タグで経路を区別します（例: "DRAIN" / "MASS" など）。
;   ・append=true で追記し、timestamp=true で各行の頭に時刻が自動で付きます。
;   出力先(MO2環境): C:\FREE\MO2\overwrite\ASTR2_OStimLog.txt の見込みです
;                  （Data\ への書き込みはMO2がoverwriteへ転送するためです）。
;   複数の機能（ドレイン／魅了／夢魔など）がこの1関数を通して同じファイルへ書き出しますので、
;   時系列で混ざって追えます（タグで区別します）。
; =====================================================================================
Function Write(String tag, String msg) Global
    ; 🔄 自動キャップは、開発ログが無限に肥大しないよう行数で頭打ちします。上限に達したら古いぶんをリセットして続行します（手で消す必要はありません）。
    ;   ★開発ログ専用です（リリースでは出力自体を撤去します）。目的は読める量を保つことだけで、直近ぶんが残れば十分です。上限は kMaxLines で調整できます。
    Int kMaxLines = 30000
    If StorageUtil.AdjustIntValue(None, "ASTR2_OStimLogLines", 1) > kMaxLines
        MiscUtil.WriteToFile("Data/ASTR2_OStimLog.txt", "===== LOG AUTO-ROTATED (" + kMaxLines + "行到達＝古いぶんをリセット) =====\n", false, false)
        StorageUtil.SetIntValue(None, "ASTR2_OStimLogLines", 1)
    EndIf
    ; 末尾に \n を足して1行1エントリにします（WriteToFileは自動で改行しませんし、timestamp引数も効きませんので手動です）。
    MiscUtil.WriteToFile("Data/ASTR2_OStimLog.txt", "[" + tag + "] " + msg + "\n", true, false)
EndFunction

; 🧹 ログ全消去です（append=false＝丸ごと上書きします）。新ゲーム開始時に呼んで、テストごとにまっさらにします。
;   普段のログ2本（OStimLog は全機能共有で、SeductionLog はシーン・ゲート・Lv 用です）をスクラッチ扱いで揃えて消します。
;   ★ ASTR2_RareLog.txt は意図的に消しません（下の Rare を参照してください）。
Function Clear() Global
    MiscUtil.WriteToFile("Data/ASTR2_OStimLog.txt", "===== LOG CLEARED (new game) =====\n", false, false)
    StorageUtil.SetIntValue(None, "ASTR2_OStimLogLines", 0)   ; 自動キャップの行カウンタも新ゲームでリセットします。
    MiscUtil.WriteToFile("Data/ASTR2_SeductionLog.txt", "===== LOG CLEARED (new game) =====\n", false, false)
    MiscUtil.WriteToFile("Data/ASTR2_FreezeLog.txt", "===== LOG CLEARED (new game) =====\n", false, false)
EndFunction

; 📌 レア事象の長期記録です（新ゲームでも Clear しませんので、セーブ／再起動／新ゲームを跨いで溜まります）。
;   普段のログは新ゲームで消えますので、レアな CTD 前兆やレース検知などはここへ書けば証拠が消えません。
;   使い方は Write と同じです：ASTR2Log.Rare("タグ", "本文")。
;   溜まってきたらリセットして構いません（このファイルを空にするだけです）。
Function Rare(String tag, String msg) Global
    ; レア事象は C++(ASTR2Native.LogRare)経由で spdlog::warn として ASTR2SKSE.log に出します＝出力先をC++ログに一本化します（旧：ASTR2_RareLog.txt へ直書き）。
    ; 配布版はログレベル warn なので〔レア〕はそのまま残り、不具合報告(BugReport)にも丸ごと取り込まれます。時刻は spdlog が各行頭に付けます。
    ; ★ASTR2Native.LogRare は dll 実装ですので ASTR2 の dll ビルドが必要です（未ビルドの dll で呼ぶと未登録エラー＝pex は dll と一緒にロード）。
    ASTR2Native.LogRare(tag, msg)
EndFunction

; 🧊 フリーズ診断専用のログです（新ゲームで Clear し、全行の頭に実時刻ms t= を自動で前置します）。
;   デッドロックの現行犯用です。ブロックしうるネイティブ呼びを enter/exit で挟みます。enter だけ残って exit が無ければ、
;   その呼びで固まったと分かり、原因が1行で確定します。普段のログを汚さないよう専用ファイルへ分けています。どの機能も同じ形で書き出せます。
;   タグ例は LOCK（呼びの前後）／SCENEDBG（シーン状態）です。確認後は撤去前提の一時計装です。
Function Freeze(String tag, String msg) Global
    MiscUtil.WriteToFile("Data/ASTR2_FreezeLog.txt", "t=" + Utility.GetCurrentRealTime() + " [" + tag + "] " + msg + "\n", true, false)
EndFunction
