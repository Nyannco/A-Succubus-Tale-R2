#include "PCH.h"
#include "PowerReset.h"
#include "Localization.h"
#include "SkyVaultAPI.h"   // ★トークンの保存先を外部 SkyVault へ（クロスMODデータ庫・別dll越しに維持）
#include "Fury.h"          // 💥 アンリーシュド・フューリー(Fury)＝火種対象外＋SpellCastでトグル駆動
#include "EssenceFlow.h"   // 💧 エッセンス・フロウ＝Fury同型＝火種対象外＋SpellCastでトグル駆動

#include <chrono>
#include <mutex>
#include <thread>
#include <unordered_map>

// ============================================================================
// PowerReset ― グレーターパワーの日次クールダウンを「使用権(トークン)」で解除します。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//
//   ★なぜフィールドを直接いじらないか
//     per-powerの日次CDの実体タイマーはセーブ(exe内部)にあり、CommonLibに公開フィールドがありません。
//     代わりに、キャストの〔門番〕 ActorMagicCaster::CheckCast が
//         *a_reason = MagicSystem::CannotCastReason::kPowerUsed (=2)
//     を返して弾いています。＝"タイマー"でなく"〔門番〕の答え"を書き換えれば通ります。
//     （実機で実証＝スイート・ヴァッサルの連続撃ち成功／ログ origResult=false → 通過）
//
//   ★この方式が要件を全部満たす理由
//     ・RemoveSpell/AddSpellを使わないので、お気に入りから外れません（過去のお蔵入り理由を回避）。
//     ・ゲーム内時間を進めないので、iNeed/スケジュール/リスポーンへの副作用がありません。
//     ・Greater Powerのままですので、Lesser Power化（かつて全廃した道）に戻りません。
//
//   ★トークン制
//     アイテムを使うと使用権が貯まり、対象パワーのどれに使っても構いません（1回=1枚消費）。
//     残数0なら何もしません＝通常どおり「今日はもう使った」で弾かれます。
//     残数はSKSEコセーブに保存＝セーブごとに正しく復元されます。
//
//   ★消費は「実発動(SpellCast)」でだけ（メニュー漏れの根治）
//     CheckCastはメニュー/お気に入り/HUDのcastability一括照会でも呼ばれます（開くだけで各パワーぶん呼ばれます）。
//     ここで消費するとメニューを開くだけで券が減りました（実機で3枚同時消費＝お気に入りのASTR2パワー3つを一括照会）。
//     →CheckCastでは「撃てる」と答えて"救済したFormID+時刻"を控えるだけです。実際に撃った瞬間に呼ばれる
//       MagicCaster::SpellCast(vfunc 0x09)で、その救済記録がある時だけ1枚消費します。
//       kPowerUsed(日次CD)を踏み越えた発動だけが救済記録を持ちます＝通常スペルも当日無料1回目も自動で除外します。
// ============================================================================

namespace {
    constexpr const char* kEspName = "A Succubus Tale R2.esp";
    constexpr RE::FormID  kSweetVassalLocalId = 0x00BF77;   // スイート・ヴァッサル SPEL（発射時のLFコスト判定の対象）
    constexpr RE::FormID  kFurySpellLocalId   = 0x00B4AA;   // 💥 アンリーシュド・フューリー(Fury) SPEL（火種対象外＝グレーアウト回避のみ・トグルはSpellCastで駆動）
    constexpr RE::FormID  kEssenceFlowLocalId = 0x02087E;   // 💧 エッセンス・フロウ SPEL（Fury同型＝火種対象外＋SpellCastでトグル）

    // ★対象の決め方＝FormIDの手書きリストをやめ、「そのパワーがどのespの物か」で判定します。
    //   理由＝リスト方式だとパワーを増やすたびに直す必要があり、必ず漏れます（実際にVassalRiseTestで漏れました）。
    //   ASTR2のespに属するパワーは常に対象／他MODのパワーは g_allowOtherMods が真なら対象にします（おまけ扱い）。
    std::atomic<std::int32_t> g_astr2Index{ -1 };     // A Succubus Tale R2.esp のロード順（未解決=-1）
    std::atomic_bool          g_allowOtherMods{ true };  // 他MODのパワーも券の対象にするか

    std::atomic<std::int32_t> g_tokens{ 0 };  // 使用権の残数（ランタイムのキャッシュ＝ホット読み用。保存の正は外部〔SkyVault〕）
    // ★保存の正＝〔SkyVault〕(グローバル名前空間・holder=0)。g_tokensは実発動フックの高速読み用キャッシュです。
    constexpr const char* kTokenKey = "ASTR2_PowerTokens";

    // 外部 〔SkyVault〕 の C++ API を1回取得してキャッシュします（未ロード/不在なら nullptr＝保存はスキップ＝機能は動きます）。
    SkyVaultAPI::IVault* GetVault() {
        static SkyVaultAPI::IVault* v = nullptr;
        if (!v) {
            v = SkyVaultAPI::GetSkyVaultAPI();
        }
        return v;
    }

    // ★救済記録＝CheckCastで「日次CDで弾かれた自分のパワー」をkOKへ差し替えた時に控えます（FormID→控えた時刻ms）。
    //   実発動(SpellCast)がこの記録付きで来た時だけ券を1枚消費します＝メニューの一括照会では消費しません。
    //   キーはお気に入りの数個ぶんですので増え続けません（同じFormIDが上書きされるだけ）。CheckCast/SpellCastは共にメインスレッドですが安全側でmutexです。
    std::mutex                                    g_rescueMutex;
    std::unordered_map<RE::FormID, std::uint32_t> g_rescued;
    std::unordered_map<RE::FormID, std::uint32_t> g_nailRescued;   // 🔮 魅了のネイル回数救済（火種トークン救済 g_rescued とは消費先が違うので分けます）。保護は同じ g_rescueMutex です。
    constexpr std::uint32_t                       kRescueWindowMs = 5000;  // 救済→実発動がこの窓内なら「その発動のための救済」とみなします

    std::uint32_t NowMs() {
        return static_cast<std::uint32_t>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now().time_since_epoch()).count());
    }

    // エンバー・エッセンス(Ember Essence)＝残数をGLOB ASTR2PowerTokenCountへ同期→アビリティ説明文<Global=…>が表示します（0101D7EF）。
    constexpr RE::FormID        kTokenGlobLocal = 0x01D7EF;
    std::atomic<RE::TESGlobal*> g_tokenGlob{ nullptr };

    // そのパワーがASTR2のespの物かどうかです（FormIDの上位1バイト＝ロード順インデックスで判定）。
    //   ★軽量プラグイン(ESL・FE xx yyy)はASTR2が通常espですので該当しません＝単純比較で足ります。
    bool IsFromAstr2(RE::MagicItem* a_spell) {
        const std::int32_t idx = g_astr2Index.load();
        if (idx < 0 || !a_spell) {
            return false;
        }
        return static_cast<std::int32_t>(a_spell->GetFormID() >> 24) == idx;
    }

    // 💥 アンリーシュド・フューリー(Fury)（プレイヤー本人が撃った時だけ）。CheckCast(火種exempt)/SpellCast(トグル駆動)の両方で使います。
    bool IsPlayerFury(RE::ActorMagicCaster* a_caster, RE::MagicItem* a_spell) {
        return a_caster && a_spell && a_caster->actor == RE::PlayerCharacter::GetSingleton() &&
               IsFromAstr2(a_spell) && (a_spell->GetFormID() & 0x00FFFFFF) == kFurySpellLocalId;
    }

    // 💧 エッセンス・フロウ（プレイヤー本人が撃った時だけ）。Fury同型＝CheckCast(火種exempt)/SpellCast(トグル駆動)両方で使います。
    bool IsPlayerEssenceFlow(RE::ActorMagicCaster* a_caster, RE::MagicItem* a_spell) {
        return a_caster && a_spell && a_caster->actor == RE::PlayerCharacter::GetSingleton() &&
               IsFromAstr2(a_spell) && (a_spell->GetFormID() & 0x00FFFFFF) == kEssenceFlowLocalId;
    }

    // ---- 🔮 魅了のネイル回数プール（シンフル・ネイル・色欲ルクスリアON時 Lv/10回/日・魅了3種で共有・日次リセット。優先＝本体無料1回>ネイル>火種トークン）----
    constexpr RE::FormID kSedSingleLocal = 0x002DB3;   // 単体魅了
    constexpr RE::FormID kSedAreaLocal   = 0x00BA13;   // エリア魅了
    constexpr RE::FormID kSedMassLocal   = 0x004E05;   // マス魅了

    int SVInt(const char* key, int def) {
        if (auto* v = GetVault()) return v->GetInt(0, key, def);
        return def;
    }
    void SVSetInt(const char* key, int val) {
        if (auto* v = GetVault()) v->SetInt(0, key, val);
    }
    int SuccubusLevel() { return std::clamp(SuccLevel::Raw(1), 1, 100); }
    // 魅了3種（Single/Area/Mass）かどうかです。ASTR2のespの物＆下位FormID一致で判定します。
    bool IsSeductionSpell(RE::MagicItem* s) {
        if (!IsFromAstr2(s)) return false;
        const RE::FormID id = s->GetFormID() & 0x00FFFFFF;
        return id == kSedSingleLocal || id == kSedAreaLocal || id == kSedMassLocal;
    }
    int CurrentDay() {
        if (auto* cal = RE::Calendar::GetSingleton()) return static_cast<int>(cal->GetDaysPassed());
        return 0;
    }
    // 今日のネイル魅了枠＝色欲ルクスリア(idx2)ON時 Lv/10（Lv10→1…Lv100→10／Lv1-9→0）。OFF/未習得=0。
    int NailSeductionBudget() {
        if (SVInt("ASTR2_NailActive_2", 0) != 1) return 0;   // 色欲ネイルOFF＝枠なし
        return SuccubusLevel() / 10;
    }
    // 日次リセットして「まだネイル枠が残ってるか」を返します。
    bool NailSeductionAvailable() {
        const int budget = NailSeductionBudget();
        if (budget <= 0) return false;
        const int today = CurrentDay();
        if (SVInt("ASTR2_SedNailDay", -1) != today) {
            SVSetInt("ASTR2_SedNailDay", today);
            SVSetInt("ASTR2_SedNailUsed", 0);
        }
        return SVInt("ASTR2_SedNailUsed", 0) < budget;
    }
    // ネイル枠を1消費します（実発動時）。
    void NailSeductionConsume() {
        SVSetInt("ASTR2_SedNailUsed", SVInt("ASTR2_SedNailUsed", 0) + 1);
    }

    // 残数を表示用GLOBへ書き込みます（初回だけFormIDで引いてキャッシュ）。値の代入だけですので軽いです＝呼び側スレッドを問わず安全です。
    void SyncTokenGlobal() {
        RE::TESGlobal* g = g_tokenGlob.load();
        if (!g) {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                g = dh->LookupForm<RE::TESGlobal>(kTokenGlobLocal, kEspName);
                g_tokenGlob.store(g);
            }
        }
        if (g) {
            g->value = static_cast<float>(g_tokens.load());
        }
    }

    // 通知debounce＝連打で「使用権が増えたよ（残りN）」が溢れないよう、加算が落ち着いてから1回だけ出します。
    //   加算のたびに世代を進める→デバウンサ(常時1本)が「350ms増えなかった＝連打終了」を見て最終残数で1回通知します。
    //   スレッドは連打1バーストにつき1本・自動終了します（VassalRaise流のstd::thread＝RE操作はAddTask経由でメインスレッドへ）。
    std::atomic<std::uint32_t> g_notifyGen{ 0 };
    std::atomic_bool           g_notifyBusy{ false };
    void ScheduleTokenNotify() {
        g_notifyGen.fetch_add(1);
        bool expected = false;
        if (!g_notifyBusy.compare_exchange_strong(expected, true)) {
            return;  // 既にデバウンサが回ってる＝世代を進めるだけでいい
        }
        std::thread([]() {
            std::uint32_t seen;
            do {
                seen = g_notifyGen.load();
                std::this_thread::sleep_for(std::chrono::milliseconds(350));
            } while (g_notifyGen.load() != seen);  // まだ増えてる間は出しません＝連打が続く限り待ちます
            const std::int32_t left = g_tokens.load();
            std::string msg = Localization::LocFmtStrCpp("$ASTR2_Msg_PowerTokenGained", { std::to_string(left) });
            SKSE::GetTaskInterface()->AddTask([msg]() { RE::DebugNotification(msg.c_str()); });
            g_notifyBusy.store(false);
        }).detach();
    }

    struct CheckCastHook {
        static bool thunk(RE::ActorMagicCaster* a_this, RE::MagicItem* a_spell, bool a_dualCast,
                          float* a_alchStrength, RE::MagicSystem::CannotCastReason* a_reason,
                          bool a_useBaseValueForCost) {
            // まず本来の判定をそのまま実行します（副作用や他の理由コードを壊さないため）
            const bool result = func(a_this, a_spell, a_dualCast, a_alchStrength, a_reason, a_useBaseValueForCost);

            // ここから先は「日次CDで弾かれた時だけ」触ります。それ以外は一切素通しします。
            if (!a_reason || *a_reason != RE::MagicSystem::CannotCastReason::kPowerUsed || !a_spell) {
                return result;
            }
            // 術者がプレイヤー本人かどうかです（NPCのパワーには関与しません）
            auto* caster = a_this ? a_this->actor : nullptr;
            if (!caster || caster != RE::PlayerCharacter::GetSingleton()) {
                return result;
            }

            // ASTR2のパワーは常に対象／他MODのパワーは設定が許す時だけ対象にします（おまけ）。
            const bool mine = IsFromAstr2(a_spell);
            if (!mine && !g_allowOtherMods.load()) {
                // 調査用＝「他MODを対象外にしている時、どのパワーが引っかかったか」を1行だけ残します。
                //   ※自前クールダウンのMODはそもそもkPowerUsedを通りません＝ここに出た物だけが対象候補です。
                spdlog::info("[PowerReset][candidate] other-mod power blocked (scope=ASTR2 only): 0x{:08X} ({})",
                             a_spell->GetFormID(), a_spell->GetName());
                return result;
            }

            // 💥 アンリーシュド・フューリーは火種対象外＝残数を問わず常にkOKへ（グレーアウト回避＝再キャストの門を開けるだけ）。
            //    救済記録(g_rescued)には入れず、SpellCastでトークンを消費しません。ON/OFFトグルはSpellCastHookが駆動します。
            if (IsPlayerFury(a_this, a_spell)) {
                *a_reason = RE::MagicSystem::CannotCastReason::kOK;
                return true;
            }

            // 💧 エッセンス・フロウも火種対象外＝Fury同型（グレーアウト回避のみ・トグルはSpellCastHookが駆動）。
            if (IsPlayerEssenceFlow(a_this, a_spell)) {
                *a_reason = RE::MagicSystem::CannotCastReason::kOK;
                return true;
            }

            // 🔮 魅了3種＝火種トークンより先に"ネイル段"（色欲ルクスリアON時 Lv/10回/日・共有プール）。枠が残ってればネイル救済でkOK＝トークンは温存します。
            //    ★ここでは枠を減らさない（メニュー照会でも呼ばれる為）＝救済記録だけ控えて、実発動(SpellCast)で1消費します（火種と同じ漏れ防止方式）。
            if (IsSeductionSpell(a_spell) && NailSeductionAvailable()) {
                {
                    std::scoped_lock lk(g_rescueMutex);
                    g_nailRescued[a_spell->GetFormID()] = NowMs();
                }
                *a_reason = RE::MagicSystem::CannotCastReason::kOK;
                return true;
            }

            // 在庫なし＝差し替えず通常どおり日次CDで弾かれます（残数0はパワーがグレーアウトのままです）。
            if (g_tokens.load() <= 0) {
                return result;
            }

            // ★ここでは券を減らしません＝この関数はメニュー/お気に入り/HUDの一括castability照会でも呼ばれるため
            //   （消費すると"メニューを開くだけで減ります"＝実機で確定した漏れ）。
            //   「撃てる」に差し替えて、"救済したFormID+時刻"を控えるだけです。実際に撃った瞬間(SpellCast)に1枚消費します。
            {
                std::scoped_lock lk(g_rescueMutex);
                g_rescued[a_spell->GetFormID()] = NowMs();
            }
            *a_reason = RE::MagicSystem::CannotCastReason::kOK;
            return true;
        }

        static inline REL::Relocation<decltype(thunk)> func;
        static inline constexpr std::size_t             idx = 0x0A;  // ActorMagicCaster::CheckCast
    };

    // ===== 💜 スイート・ヴァッサルのLFコスト（「起動→コストチェック→発射」＝マジカ不足の呪文と同じ体験）=====
    //   ★既存の技法を流用：不発は **ESPのMGEF条件** が担当します（00BF75/01D7F4 に GetGlobalValue(ASTR2SweetPaid)==1）。
    //   C++の仕事＝発射の瞬間(SpellCast 0x09・スイート・ヴァッサルが通るのは実証済)に「払ったか」をGlobalへ書くだけです：
    //     LF>=コスト → 払って ASTR2SweetPaid=1（命中時に効果が乗ります）
    //     LF< コスト → 払わず ASTR2SweetPaid=0＋「LF不足」通知（命中しても条件で不発＝何も起きません）
    //   Globalの書き方は火種の SyncTokenGlobal と同じです（初回だけFormIDで引いてキャッシュ）。
    //   ★CheckCast(0x0A)で弾くとグレーアウト＝絶対に避ける＝触りません。
    //   対象はスイート・ヴァッサル(0x..00BF77)だけ＝Reviving Grace(結果が出た時だけ払う機能起動型)/他のパワー・呪文は素通しします。
    constexpr RE::FormID        kSweetPaidGlobLocal = 0x01F2E8;   // ASTR2SweetPaid (GLOB・Long)
    constexpr float             kLFToSkillXp        = 0.1f;       // 払ったLF 1あたりの召喚スキル経験値
    std::atomic<RE::TESGlobal*> g_sweetPaidGlob{ nullptr };

    void SetSweetPaid(bool a_paid) {
        RE::TESGlobal* g = g_sweetPaidGlob.load();
        if (!g) {
            if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                g = dh->LookupForm<RE::TESGlobal>(kSweetPaidGlobLocal, kEspName);
                g_sweetPaidGlob.store(g);
            }
        }
        if (g) {
            g->value = a_paid ? 1.0f : 0.0f;
        } else {
            spdlog::warn("[SweetCost] GLOB ASTR2SweetPaid (0x{:06X}) not found -- MGEF条件が判定できない", kSweetPaidGlobLocal);
        }
    }

    bool IsPlayerSweet(RE::ActorMagicCaster* a_caster, RE::MagicItem* a_spell) {
        return a_caster && a_spell && a_caster->actor == RE::PlayerCharacter::GetSingleton() &&
               IsFromAstr2(a_spell) && (a_spell->GetFormID() & 0x00FFFFFF) == kSweetVassalLocalId;
    }

    // 実発動フック＝プレイヤーが実際にパワーを撃った瞬間だけ券を1枚消費します（メニュー照会は通りません）。
    //   CheckCastで救済した(kPowerUsed→kOKに差し替えた)FormIDが直前にある時だけ消費＝日次CDを踏み越えた発動限定です。
    struct SpellCastHook {
        static void thunk(RE::ActorMagicCaster* a_this, bool a_doCast, std::uint32_t a_arg2, RE::MagicItem* a_spell) {
            bool sweetUnpaid = false;   // スイート・ヴァッサルを払わず撃った（不発）＝後段で券を減らしません
            // 💜 スイート・ヴァッサル：発射の瞬間に「払ったか」を決めてGlobalへ（不発そのものはMGEF条件が担当します）。
            if (a_doCast && IsPlayerSweet(a_this, a_spell)) {
                if (auto* v = GetVault()) {
                    const std::int32_t lf   = v->GetInt(0, "ASTR2_LF_Curr", 400);
                    const std::int32_t cost = static_cast<std::int32_t>(v->GetFloat(0, "ASTR2_ReanimCost", 5000.0f));
                    if (lf >= cost) {
                        v->SetInt(0, "ASTR2_LF_Curr", lf - cost);
                        SetSweetPaid(true);
                        // ✨ 召喚スキル経験値＝払ったLF×0.1（固定・MCM化しません。XP量は他の項目の調整で自然に増える設計です）
                        const float xp = static_cast<float>(cost) * kLFToSkillXp;
                        if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                            pc->AddSkillExperience(RE::ActorValue::kConjuration, xp);
                        }
                        spdlog::info("[SweetCost] paid cost={} LF {}->{} flag=1 conjXP+{}", cost, lf, lf - cost, xp);
                        // バー/段階バフの描き直し＝LF減衰(C++)と同じ合図を流用します（受け口 ASTR2LifeForceBarScript.OnLifeForceTick）
                        if (auto* src = SKSE::GetModCallbackEventSource()) {
                            SKSE::ModCallbackEvent ev{ "astr2_lf_tick", "", static_cast<float>(lf - cost), nullptr };
                            src->SendEvent(&ev);
                        }
                    } else {
                        SetSweetPaid(false);
                        sweetUnpaid = true;
                        spdlog::info("[SweetCost] not paid: LF {} < cost {} flag=0 (effect will fizzle by MGEF condition)", lf, cost);
                        std::string msg = Localization::LocFmtStrCpp("$ASTR2_Msg_VassalNoLF", {});
                        SKSE::GetTaskInterface()->AddTask([msg]() { RE::DebugNotification(msg.c_str()); });
                    }
                } else {
                    SetSweetPaid(false);
                    sweetUnpaid = true;   // 金庫が読めない時も券を温存します（安全側）
                    spdlog::warn("[SweetCost] SkyVault not available -- flag=0");
                }
            }

            // 💥 アンリーシュド・フューリー：実発動の瞬間にON/OFFトグルします（OnEffectStart再発火に依存しません＝再キャストで確実に切替）。
            //    CheckCastのexemptでグレーアウトを外してあるので、ON中の再押しもここまで届く＝Toggleでdeactivate。
            if (a_doCast && IsPlayerFury(a_this, a_spell)) {
                Fury::Toggle();
            }

            // 💧 エッセンス・フロウ：実発動の瞬間にON/OFFトグルします（Fury同型＝再キャストで確実に切替）。
            if (a_doCast && IsPlayerEssenceFlow(a_this, a_spell)) {
                EssenceFlow::Toggle();
            }

            func(a_this, a_doCast, a_arg2, a_spell);  // 本来の発動を先に実行します（挙動は一切変えません）

            if (!a_doCast || !a_spell) {
                return;
            }
            auto* caster = a_this ? a_this->actor : nullptr;
            if (!caster || caster != RE::PlayerCharacter::GetSingleton()) {
                return;
            }
            const bool mine = IsFromAstr2(a_spell);
            if (!mine && !g_allowOtherMods.load()) {
                return;
            }

            // 🔮 魅了のネイル救済＝火種トークンより先に判定します。ネイル救済ならネイル枠を1消費してreturn（トークンは減らしません）。
            {
                bool nailRescued = false;
                {
                    std::scoped_lock lk(g_rescueMutex);
                    auto nit = g_nailRescued.find(a_spell->GetFormID());
                    if (nit != g_nailRescued.end()) {
                        if (NowMs() - nit->second <= kRescueWindowMs) {
                            nailRescued = true;
                        }
                        g_nailRescued.erase(nit);
                    }
                }
                if (nailRescued) {
                    NailSeductionConsume();
                    spdlog::info("[PowerReset] seduction nail-cast used (0x{:08X}) usedToday={}",
                                 a_spell->GetFormID(), SVInt("ASTR2_SedNailUsed", 0));
                    return;  // ネイル枠で撃ちました＝火種トークンは消費しません
                }
            }

            const RE::FormID id = a_spell->GetFormID();
            bool rescued = false;
            {
                std::scoped_lock lk(g_rescueMutex);
                auto it = g_rescued.find(id);
                if (it != g_rescued.end()) {
                    if (NowMs() - it->second <= kRescueWindowMs) {
                        rescued = true;
                    }
                    g_rescued.erase(it);  // 使ったら消す（古い救済が後で誤消費しないように）
                }
            }

            // 確認用＝プレイヤーが自分のパワーを実発動した事実をログ（SpellCastが発動を拾えているかの裏取り・最初の20回だけ）。
            static std::atomic<int> dbgLeft{ 20 };
            if (dbgLeft.load() > 0) {
                dbgLeft.fetch_sub(1);
                spdlog::info("[PowerReset][cast] SpellCast fired: {} (0x{:08X}) rescued={}",
                             a_spell->GetName(), id, rescued);
            }

            if (!rescued) {
                return;  // 救済記録なし＝当日の無料1回 or 通常スペル＝券は減らしません
            }
            if (sweetUnpaid) {
                spdlog::info("[PowerReset] 甘屍がLF不足で不発＝券は温存");
                return;  // 💜 払っていません＝不発（MGEF条件）＝券は減らしません
            }

            // 使用権を1枚消費します。競合で0になったら何もしません。
            std::int32_t cur = g_tokens.load();
            while (cur > 0 && !g_tokens.compare_exchange_weak(cur, cur - 1)) {
                // 他スレッドと競合したら読み直して再試行します（compare_exchangeがcurを更新します）
            }
            if (cur <= 0) {
                return;
            }

            const std::int32_t left = g_tokens.load();
            if (auto* v = GetVault()) { v->SetInt(0, kTokenKey, left); }   // ★〔SkyVault〕へ即反映します（保存の正）
            SyncTokenGlobal();   // エンバー・エッセンスの表示を更新します
            spdlog::info("[PowerReset] token spent on {} (0x{:08X}, {}) -- remaining={}",
                         a_spell->GetName(), id, mine ? "ASTR2" : "other-mod", left);
            // 画面通知します（$キー未収録なら生キーが出ます＝可視）
            std::string msg = Localization::LocFmtStrCpp("$ASTR2_Msg_PowerTokenUsed", { std::to_string(left) });
            SKSE::GetTaskInterface()->AddTask([msg]() { RE::DebugNotification(msg.c_str()); });
        }

        static inline REL::Relocation<decltype(thunk)> func;
        static inline constexpr std::size_t             idx = 0x09;  // MagicCaster::SpellCast
    };

    // ===== 永続化は〔SkyVault〕に一本化（自前のSKSEコセーブは持ちません）=====

    // ===== Papyrus native =====
    void Papyrus_AddPowerTokens(RE::StaticFunctionTag*, std::int32_t a_count) {
        if (a_count <= 0) {
            return;
        }
        const std::int32_t left = g_tokens.fetch_add(a_count) + a_count;
        if (auto* v = GetVault()) { v->SetInt(0, kTokenKey, left); }   // ★〔SkyVault〕へ即反映します（保存の正）
        SyncTokenGlobal();   // エンバー・エッセンスの表示を更新します
        ScheduleTokenNotify();   // ★通知は連打が落ち着いてから1回だけ（debounce）
        spdlog::info("[PowerReset] +{} token(s) -- now {}", a_count, left);
    }
    std::int32_t Papyrus_GetPowerTokens(RE::StaticFunctionTag*) {
        return g_tokens.load();
    }
    // 他MODのパワーも券の対象にするかの判定をします（ASTR2のパワーは常に対象＝この設定に関係なく効きます）。
    void Papyrus_SetPowerTokenOtherMods(RE::StaticFunctionTag*, bool a_on) {
        g_allowOtherMods.store(a_on);
        spdlog::info("[PowerReset] other-mod powers = {}", a_on ? "on" : "off");
    }
    bool Papyrus_GetPowerTokenOtherMods(RE::StaticFunctionTag*) {
        return g_allowOtherMods.load();
    }
}

namespace PowerReset {
    void Install() {
        // ASTR2のロード順インデックスを控えます＝以後「このパワーは本MODの物か」を1バイト比較で判定できます。
        g_astr2Index.store(-1);
        if (auto* dh = RE::TESDataHandler::GetSingleton()) {
            if (auto idx = dh->GetLoadedModIndex(kEspName); idx.has_value()) {
                g_astr2Index.store(static_cast<std::int32_t>(*idx));
                spdlog::info("[PowerReset] {} load index = 0x{:02X}", kEspName, *idx);
            } else {
                spdlog::warn("[PowerReset] {} not loaded -- ASTR2 powers will not be recognized", kEspName);
            }
        }

        // ActorMagicCaster の vtable を差し替えます。
        //   VTABLE_ActorMagicCaster は3本（多重継承ぶん）あり、CheckCast(0x0A)/SpellCast(0x09)を持つのは先頭の1本です。
        REL::Relocation<std::uintptr_t> vtbl{ RE::VTABLE_ActorMagicCaster[0] };
        CheckCastHook::func = vtbl.write_vfunc(CheckCastHook::idx, CheckCastHook::thunk);   // 「撃てる」に差し替え＋救済記録
        SpellCastHook::func = vtbl.write_vfunc(SpellCastHook::idx, SpellCastHook::thunk);   // 実発動でだけ券を消費＋スイート・ヴァッサルの支払い(ASTR2SweetPaid)
        spdlog::info("[SweetCost] pay at SpellCast 0x09 -> GLOB ASTR2SweetPaid(0x{:06X}) / fizzle = MGEF condition", kSweetPaidGlobLocal);
        spdlog::info("[PowerReset] hooks installed (CheckCast 0x{:02X} + SpellCast 0x{:02X}), scope: ASTR2 always + other mods={}",
                     CheckCastHook::idx, SpellCastHook::idx, g_allowOtherMods.load() ? "on" : "off");
    }

    // ---- 火種の復元＝保存の正は外部 〔SkyVault〕。ASTR2は自前コセーブを持ちません。----
    //   ロード後(kPostLoadGame)／新規(kNewGame)に呼び出す＝〔SkyVault〕のコセーブが読み込まれた後に g_tokens をシード。
    //   〔SkyVault〕不在(未導入)なら GetInt が呼べず 0 のまま＝機能は動きます(火種が貯まらないだけです)。
    void SyncFromVault() {
        if (auto* v = GetVault()) {
            const std::int32_t n = v->GetInt(0, kTokenKey, 0);
            g_tokens.store(n < 0 ? 0 : n);
            spdlog::info("[PowerReset] tokens synced from SkyVault: {}", g_tokens.load());
        } else {
            g_tokens.store(0);
            spdlog::warn("[PowerReset] SkyVault not available -- tokens start at 0 (not persisted)");
        }
        SyncTokenGlobal();   // 復元後の残数を表示用GLOBへ反映します
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("AddPowerTokens", "ASTR2Native", Papyrus_AddPowerTokens);
        vm->RegisterFunction("GetPowerTokens", "ASTR2Native", Papyrus_GetPowerTokens);
        vm->RegisterFunction("SetPowerTokenOtherMods", "ASTR2Native", Papyrus_SetPowerTokenOtherMods);
        vm->RegisterFunction("GetPowerTokenOtherMods", "ASTR2Native", Papyrus_GetPowerTokenOtherMods);
        spdlog::info("[PowerReset] Papyrus natives AddPowerTokens / GetPowerTokens / Set-GetPowerTokenOtherMods registered");
        return true;
    }
}
