#pragma once

#include <functional>

// ============================================================================
// 〔クロノス〕 ― ASTR2の「時計の核」です。時間で動く物をC++に一元管理します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   狙いは速度でなく Papyrus を噛ませないこと＝共有VMを詰まらせないことです。
//
// 【〔クロノス〕の要点＝旧実装との違い】
//   ・マーカー（各ジョブが「最後にいつ処理したか／いつ発火するか」）は〔SkyVault〕に永続します
//     ＝セーブごと（.skseコセーブ）に残る → ロードしたらそのまま再開します（リセットも張り直しもありません）。
//   ・ジョブは時間管理をしません＝渡された経過(elapsed)ぶんの効果を書くだけです。マーカーは〔クロノス〕が持ちます
//     （自前マーカー禁止＝LF減衰が二重に持って不具合になった教訓です）。
//   ・〔門番〕：セーブがロードされ、プレイヤーがセルに居る時だけ時刻ジョブを動かします
//     ＝メインメニュー(バニラ既定=1日目8時)でマーカーが焼き付く事故を根絶します（実機で確認＝584日一括の真因です）。
//   ・期限型も永続＝セーブ跨ぎで生き残ります（旧実装はロードで消えて張り直しが要りました）。
//
// 【時間の測り方】
//   ・ゲーム内時刻＝`日(GetDaysPassed の整数部) × 24 + GetHour()`（長期プレイでも刻みが粗くなりません）。
//   ・マーカーもこの「ゲーム内時間（時）」で持ちます＝待機/睡眠/ファストトラベルで飛んでも歩調が合います。
//
// 【登録は3種類】
//   ① 定期型 RegisterInterval("名前", 4.0f, fn)
//      → ゲーム内4時間ごとに1回です。寝て何コマ飛んでも**1回だけ**発火し、**実際の経過(elapsedゲーム内時間)を渡します**。
//        ★受け側の義務＝渡されたelapsedで処理します（自前で時刻を測りません）。
//      → 用途は淫魔力の減衰・維持費・痕の段階更新などです。
//   ② 期限型（永続の一発）＝2段構え：
//        RegisterAt("名前", fn)              …起動時(kDataLoaded)にハンドラを名前で登録します（毎セッション）。
//        ScheduleAt("名前", 12.0f)           …プレイ中に「今から12ゲーム内時間後」に予約します（〔SkyVault〕へ永続）。
//        CancelAt("名前")                    …予約を取り消します。
//      → 予約時刻はセーブに残ります＝ロードしても生きていて、時刻が来たら1回発火します。効果側は張り直しは不要です。
//      → 用途は将来の手下死タイマーなどです。
//   ③ 実時間くり返し型 RegisterRealtime("名前", 1.0f, fn)   ※HUD専用・時計とは別物です
//      → 実時間で○秒ごとです（ゲーム内時刻と無関係）。HUDの描き替え用です。★〔門番〕の外＝メニュー中も回ります。
//        ＝将来は〔クロノス〕から切り出すことを検討しています（今は互換のため同居しています）。
//
//   ※永続は〔SkyVault〕（holder=0・キー`ASTR2_Chrono_*`）＝コセーブでセーブごとです。〔門番〕があるので
//     メインメニューで書かれる事はなく、584日焼き付きは起きません。
// ============================================================================

namespace Chronos
{
    // 定期型のコールバックです。引数は前回発火からの実際の経過（ゲーム内時間）です。
    using IntervalJob = std::function<void(float a_elapsedGameHours)>;
    // 期限型／実時間くり返し型のコールバックです。
    using OneShotJob  = std::function<void()>;
    using RealtimeJob = std::function<void()>;

    // ---- ① 定期型 ----
    // 登録します（同じ名前で呼び直すと間隔変更）。マーカーは〔SkyVault〕に永続するので、ロードで自動再開します。
    void RegisterInterval(const char* a_name, float a_intervalGameHours, IntervalJob a_fn);
    // 間隔だけ変えます（MCMスライダー等から）。未登録なら何もしません。
    void SetInterval(const char* a_name, float a_intervalGameHours);
    // 「今すぐ、溜まってる経過ぶんだけ処理して」＝定期型と同じマーカーを使うので二重に処理しません。
    //   （旧LFの TickNow の受け皿＝表示を今の値にしたい瞬間に呼びます）。
    void RunDueNow(const char* a_name);
    // 個別の開始/停止（覚醒・デメリット等の状態変化で呼びます＝マーカーの設置/撤去です）。
    //   Start＝有効化＋マーカーを"今"に置きます（OFF期間は請求しません）。Stop＝停止（発火しません）＋マーカーを消去します。
    void StartInterval(const char* a_name);
    void StopInterval(const char* a_name);

    // ---- ② 期限型（永続の一発）----
    void RegisterAt(const char* a_name, OneShotJob a_fn);       // 起動時にハンドラを名前で登録します
    void ScheduleAt(const char* a_name, float a_delayGameHours);// プレイ中に予約します（永続）
    void CancelAt(const char* a_name);                         // 予約を取り消します

    // ---- ③ 実時間くり返し型（HUD専用・時計とは別）----
    void RegisterRealtime(const char* a_name, float a_everyRealSeconds, RealtimeJob a_fn);

    // 今のゲーム内時刻です（日×24＋時）。
    double NowGameHours();
    // 今のタイムスケールです（他MODの変更に毎回追従・0以下なら既定20）。
    float Timescale();

    // kDataLoaded＝核の起動です（鼓動を1本持ちます）。★当面はC++スレッド＝Papyrusは使いません。
    //   将来はエンジン更新ループへのフックへの置換を検討しています（REL id確認後）＝スレッドすら無くせます。
    void Install();

    // kPostLoadGame＝ロード直後の後始末（永続マーカーは触らない＝そのまま再開します）。
    void OnLoadGame();
}
