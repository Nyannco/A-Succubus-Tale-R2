# ASTR2-SKSE （ASuccubusTaleR2 自前SKSEプラグイン）

Papyrus では不可能、または重すぎる処理を、自前の C++ SKSE dll で根治するためのプロジェクトです。
現在はフル機能のプラグインで、時刻管理（〔クロノス〕）・戦闘ドレイン・Hスキルランク・淫紋オーバーレイ・
MCM/ツールチップの動的表示・ヴァッサル/サーヴァント管理など、多数のモジュールを C++ 側で担います。
ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

スタックは Visual Studio 2022 + CMake + Ninja + vcpkg + **CommonLibSSE-NG**（SE/AE/VR 一本）です。

---

## 初回セットアップ（1回だけ）

### 1. Visual Studio 2022 Community
インストーラで **「C++ によるデスクトップ開発」** ワークロードを入れます。
（MSVC・CMake・Ninja が一緒に入ります）

### 2. vcpkg を用意して VCPKG_ROOT を通す
PowerShell で実行します。
```powershell
git clone https://github.com/microsoft/vcpkg C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
# 環境変数 VCPKG_ROOT を永続化します（管理者不要・ユーザー環境変数）
setx VCPKG_ROOT "C:\vcpkg"
```
※ `setx` の後は **VS / ターミナルを開き直す**と反映されます。

### 3. （任意）出力先を MO2 の mods へ
ビルドした .dll を自動で MO2 に置きたい場合は設定します。
```powershell
setx SKYRIM_MODS_FOLDER "<MO2のmodsフォルダのパス>"
```
→ ビルド後に `<mods>\ASTR2SKSE\SKSE\Plugins\ASTR2SKSE.dll` が出来ます。
（設定しなくてもビルド自体は成功します）

---

## ビルド（VS2022 でフォルダを開くだけ）

1. VS2022 の **ファイル > 開く > フォルダー** で、この `ASTR2-SKSE` フォルダを開きます。
2. VS が `CMakePresets.json` を検知して、自動で CMake 構成を実行します。
   - ★**初回は vcpkg が CommonLibSSE-NG をソースからビルド**します＝数分〜十数分かかります（CPU 負荷・ネットダウンロードあり）。2回目以降はキャッシュで速くなります。
3. 上部の構成で `release` または `debug` を選び、**ビルド > すべてビルド**を実行します。
4. 成功すると `build\<preset>\ASTR2SKSE.dll` が出来ます。

### 動作確認
- MO2 で `ASTR2SKSE` mod を有効化し、Skyrim を起動します。
- ログに起動メッセージ `ASTR2 SKSE plugin loaded.` が出れば読み込み成功です。
- ログの場所は `Documents\My Games\Skyrim Special Edition\SKSE\ASTR2SKSE.log` です。

---

## ファイル構成
| ファイル | 役割 |
|---|---|
| `vcpkg.json` | 依存（commonlibsse-ng） |
| `vcpkg-configuration.json` | vcpkg レジストリと baseline の固定 |
| `CMakeLists.txt` | dll 名・出力先・プラグイン構成 |
| `CMakePresets.json` | コンパイラ/ツールチェーン設定 |
| `PCH.h` | プリコンパイルヘッダ（必須） |
| `src/plugin.cpp` | エントリポイント（各モジュールの初期化と Papyrus ネイティブ登録） |
| `src/*.cpp` ・ `src/*.h` | 機能別モジュール（〔クロノス〕・CombatDrain・Technique・Sigil・Localization ほか多数） |

CommonLibSSE-NG は版によって API 名が変わるため、ビルドエラーが出たら該当箇所を微修正します。

## ライセンス
本プロジェクトは **GPL-3.0** で公開します（OStim 由来）。使用ライブラリは CommonLibSSE-NG（MIT）・OStim（GPL-3.0）です。
原作クレジットや配布条件などの詳細は、MOD 本体の README を参照してください。
