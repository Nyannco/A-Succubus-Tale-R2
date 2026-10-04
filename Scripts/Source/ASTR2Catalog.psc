Scriptname ASTR2Catalog Hidden
; ASTR2専門用語（〔 〕で囲った語）の説明は GLOSSARY.psc を参照してください。
; ASTR2SKSE.dll(C++ SKSEプラグイン)が提供するネイティブ関数群です。
; 実装は src/SceneCatalog.cpp で、導入済みの全OStimシーンを事前にカタログ化します
; (Data/SKSE/Plugins/OStim/scenes・MO2 VFSでマージ済み)。家具×人数でバケット分けし、
; 各シーンのスロット毎にintendedSexシグネチャを持たせます。アニメが無くても起動を失敗させない仕組みの中核です。
; カタログはデータロード時に1回構築し、その時にASTR2_CatalogDump.txtへ自動ダンプします。

; 「何人で」の段です。この家具で起動できるシーンが1つ以上ある人数を昇順で返します。
; 例: AvailableCounts("none") -> [1,2,3,4,5]。その家具にシーンが無い/dll不在なら空です。
Int[] Function AvailableCounts(String furniture) Global Native

; 「誰と」の段です。この性別構成で起動できるシーンがカタログに在るかを返します。
; strictSex=true  -> intendedSexで厳格マッチします(フタはどの枠も埋める・OStimのintendedSexOnly ONと同じ)。
; strictSex=false -> 性別を無視して人数だけで見ます(unrestrictedNavigation / intendedSexOnly OFFと同じ)。
; 呼び手がmales/females/futaを仕分けしてstrictSexを決めます(今は決め打ちで、将来はOStim設定への追従を検討中です)。
Bool Function ComboPlayable(String furniture, Int males, Int females, Int futa, Bool strictSex) Global Native

; OStimのMCM実設定から「性別を厳格マッチすべきか」を返します。ComboPlayableのstrictSexへ正しい値を渡すためのものです。
; unrestrictedNavigation ON→false(性別無視)／intendedSexOnly ON→true。dll不在/API未取得は安全側のtrue(厳格)とします。
; 起動1回につき先頭で1回だけ読んで使い回します(候補ごとには呼びません)。
Bool Function OStimStrictSex() Global Native

; このscene idが「idle」プレースホルダ(動かない静止ポーズ・本物のアニメでない)かを返します。
; 起動側はこれを飛ばします。メニューにidleだけの組が出ず、静止ポーズを起動しないためです。
; dll不在ならfalseを返します(その時は何もidle扱いしません)。
Bool Function IsIdleScene(String sceneId) Global Native

; このシーンの位置'pos'のスロットの想定性別を返します: "M"/"F"/"A"(不明/dll不在なら"")。
; 役メニューのラベルに使います。プレイヤー(特にフタ)がその位置の男役/女役を見分けられるようにするためです。
String Function GetSlotSex(String sceneId, Int pos) Global Native
