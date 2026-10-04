#include "PCH.h"
#include "VassalUpkeep.h"
#include "Chronos.h"
#include "Localization.h"
#include "Sigil.h"
#include "SkyVaultAPI.h"
#include "TechRank.h"
#include "VLoveHud.h"   // 寵愛切れ警告の本番HUDキュー

#include <chrono>
#include <string>
#include <vector>

// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。

namespace VassalUpkeep
{
    namespace {
        constexpr const char* kJobName   = "ヴァッサル維持費";
        constexpr const char* kEsp       = "A Succubus Tale R2.esp";
        constexpr float       kIntervalH = 6.0f;         // 6ゲーム時間ごとです（旧Papyrus巡回と同じ）
        constexpr RE::FormID  kFollowQuestID = 0x01D7DC; // ASTR2VassalFollowQuest（手下のエイリアス枠）
        constexpr float       kLFToSkillXp   = 0.1f;     // 規定額(割引前)LF 1あたりの召喚スキル経験値です（固定）
        constexpr int         kMissLimit     = 3;        // 維持費の連続未払いで塵化します

        inline SkyVaultAPI::IVault* Vault() { return SkyVaultAPI::GetSkyVaultAPI(); }

        int SuccubusLevel() { return SuccLevel::Raw(0); }

        // 割引＝育つほど楽です（旧Papyrusと同式）。
        float Discount(int a_lv) {
            return 1.0f + static_cast<float>(a_lv - 1) * 0.1f + static_cast<float>(TechRank::GetDisplayTotalRank()) * 0.05f;
        }

        void Notify(const char* a_key, const std::vector<std::string>& a_args) {
            std::string msg = Localization::LocFmtStrCpp(a_key, a_args);
            SKSE::GetTaskInterface()->AddTask([msg]() { RE::DebugNotification(msg.c_str()); });
        }

        // 💀 寵愛切れの死亡処理＝専用イベント ASTR2_VassalLoveExpired で送出します（死亡掃除は VassalDied と同じ id→Actor 経路）。生者限定の死＝死体化（Kill）です。
        void AshifyLoveExpired(RE::FormID a_id) {
            auto* a = RE::TESForm::LookupByID<RE::Actor>(a_id);
            if (!a || a->IsDead()) return;
            auto* v = Vault();
            if (v && v->GetInt(a_id, "ASTR2_VassalLiving", 0) != 1) return;   // もう生者の手下ではありません＝無視
            spdlog::info("[Upkeep] love timer fired -> ashify 0x{:X}", a_id);
            // ★寵愛切れは生者の"意図的な死"（死体化・Kill）です。専用イベントで送り、OnVassalDied(TESDeathEvent経由=気絶ガード付き)には相乗りしません。
            SKSE::ModCallbackEvent ev{};
            ev.eventName = "ASTR2_VassalLoveExpired";
            ev.sender = a;
            SKSE::GetModCallbackEventSource()->SendEvent(&ev);
        }

        // 🕯️ 生者の寵愛切れ死タイマーを（再）セット＝lastLove から残り時間を出し 〔クロノス〕 Timeout に載せます（期限ピッタリで発火）。
        //   H/生者化(lastLove更新直後)＝残り満タン／ロード時(全生者に呼びます・Timeoutはセッション限りで消えるため)＝残り部分。
        void ArmLoveTimer(RE::Actor* a) {
            if (!a) return;
            auto* v = Vault();
            if (!v) return;
            const RE::FormID  id       = a->GetFormID();
            if (v->GetInt(id, "ASTR2_VassalLiving", 0) != 1) return;   // 生者だけです
            const int         loveDays = v->GetInt(0, "ASTR2_VassalLoveDays", 3);
            const std::string name     = "VassalLove_" + std::to_string(id);
            // 〔クロノス〕の期限型＝ハンドラはセッション毎に名前で登録（RegisterAt）／予約は〔SkyVault〕へ永続（ScheduleAt・ロードで生きます）。
            Chronos::RegisterAt(name.c_str(), [id]() { AshifyLoveExpired(id); });
            if (loveDays <= 0) { Chronos::CancelAt(name.c_str()); return; }   // 0=寵愛切れ死しません＝予約解除
            const double nowDay     = Chronos::NowGameHours() / 24.0;
            const float  lastLove   = v->GetFloat(id, "ASTR2_VassalLastLove", static_cast<float>(nowDay));
            const float  remainDays = static_cast<float>(loveDays) - static_cast<float>(nowDay - lastLove);
            if (remainDays <= 0.0f) { AshifyLoveExpired(id); return; }   // もう期限切れなので即・死体化します
            Chronos::ScheduleAt(name.c_str(), remainDays * 24.0f);   // 残りのゲーム内時間(時)後に死体化します（期限ピッタリで永続）
            spdlog::info("[Upkeep] love timer armed 0x{:X} remain={:.2f}d", id, remainDays);
        }

        void Papyrus_ArmVassalLoveTimer(RE::StaticFunctionTag*, RE::Actor* a) { ArmLoveTimer(a); }

        // ▶️ 維持費ジョブを稼働させます（手下作成時＝蘇生/生者化・ロード時に居れば呼びます）。
        //   停止は DoUpkeep が「発火して0体」を見たら自分で StopInterval します＝全滅を別途検知しなくて済みます。
        void Papyrus_UpkeepStart(RE::StaticFunctionTag*) { Chronos::StartInterval(kJobName); }

        // ⏹️ 生者の寵愛切れ死タイマーを取り消します（覚醒OFF＝人間化で全手下解除する時に亡霊予約を残しません）。
        void Papyrus_CancelVassalLoveTimer(RE::StaticFunctionTag*, RE::Actor* a) {
            if (!a) return;
            const std::string name = "VassalLove_" + std::to_string(a->GetFormID());
            Chronos::CancelAt(name.c_str());
        }

        // ⏱️ 放置/睡眠中〔クロノス〕は6hコマを1個ずつ約0.5秒差で連発します。1個ずつ処理すると通知が割れるので、
        //   発火は dirty を立てるだけにして、連発が止まって約1秒たったら DoUpkeep を1回だけ回します（各死霊
        //   1通知に束ねます）。徴収額は各死霊の蘇生時刻基準(ASTR2_VassalUpkeepLast)からの経過で個別に出すので、
        //   連発でも取りこぼしません＝経過をここで溜める必要はありません。
        std::chrono::steady_clock::time_point g_lastAccum;
        bool                                  g_dirty = false;

        void DoUpkeep();   // 実処理です（前方宣言）

        // 実時間0.25秒ごとに呼ばれます。最後の発火から約1秒静かなら溜めた経過を1回で処理します（連発中は先送り）。
        void FlushTick() {
            if (!g_dirty) return;
            const float quiet = std::chrono::duration<float>(std::chrono::steady_clock::now() - g_lastAccum).count();
            if (quiet < 1.0f) return;
            g_dirty = false;
            DoUpkeep();
        }

        void GiveConjXp(float a_xp) {
            if (a_xp <= 0.0f) return;
            if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
                pc->AddSkillExperience(RE::ActorValue::kConjuration, a_xp);
            }
        }

        // 手下一覧＝追従クエストのエイリアス枠に入っている生きた(=立っている)実体です。
        std::vector<RE::Actor*> Roster() {
            std::vector<RE::Actor*> out;
            auto* dh = RE::TESDataHandler::GetSingleton();
            auto* q = dh ? dh->LookupForm<RE::TESQuest>(kFollowQuestID, kEsp) : nullptr;
            if (!q) return out;
            for (auto* base : q->aliases) {
                auto* ra = skyrim_cast<RE::BGSRefAlias*>(base);
                if (!ra) continue;
                auto* a = ra->GetActorReference();
                if (a && !a->IsDead()) out.push_back(a);
            }
            return out;
        }

        void DoUpkeep() {
            auto* v = Vault();
            if (!v) return;
            const int lv = SuccubusLevel();
            if (lv <= 0) {
                spdlog::info("[Upkeep] skip: まだサキュバスでない");
                return;
            }
            if (v->GetInt(0, "ASTR2_DisadvantagesOn", 1) != 1) {
                spdlog::info("[Upkeep] skip: デメリットOFF");
                return;
            }
            const std::vector<RE::Actor*> roster = Roster();
            if (roster.empty()) {
                // 🛑 0体を見た発火が自分のジョブを止めます＝以降は空回りしません。次の作成でStartが再開します。
                Chronos::StopInterval(kJobName);
                spdlog::info("[Upkeep] no vassal -> job stopped (再開は作成時のStart)");
                return;
            }

            const int   lfMax      = v->GetInt(0, "ASTR2_LF_Max", 800);
            const float upkeepRate = v->GetFloat(0, "ASTR2_VassalUpkeepRate", 0.01f);
            const float taxRate    = v->GetFloat(0, "ASTR2_VassalTaxRate", 0.01f);
            const int   loveDays   = v->GetInt(0, "ASTR2_VassalLoveDays", 3);
            const bool  notifyPaid = v->GetInt(0, "ASTR2_VassalUpkeepNotifyPaid", 0) == 1;
            const bool  notifyMiss = v->GetInt(0, "ASTR2_VassalUpkeepNotifyMiss", 1) == 1;
            const float disc       = Discount(lv);
            const double nowDay    = Chronos::NowGameHours() / 24.0;   // Papyrus GetCurrentGameTime と同じ「日」です

            const float intervalDay = kIntervalH / 24.0f;   // 徴収間隔（6h=0.25日）＝各死霊の蘇生時刻基準の刻みです

            int   lf       = v->GetInt(0, "ASTR2_LF_Curr", 0);
            const int lfBefore = lf;
            float xp       = 0.0f;
            int   taxSteps = 0;

            for (auto* a : roster) {
                const std::uint32_t id = a->GetFormID();
                const std::string   nm = a->GetDisplayFullName() ? a->GetDisplayFullName() : "";
                // 生者か＝〔SkyVault〕 ASTR2_VassalLiving（Papyrusが蘇生時0/生者化時1を書きます）。
                //   ★召喚体フラグ(IsCommandedActor)では判定しません＝ロード後に戻る恐れ→生者を死霊扱いで塵化する危険です。
                const bool living = v->GetInt(id, "ASTR2_VassalLiving", 0) == 1;

                if (living) {
                    // 🩷 手下税＝寵愛残りで淫紋の段階を更新→下がった段数ぶん課税（徴収はループ後に1回）。
                    //   ★寵愛尽き(frac0=loveDays経過)の死は下記の〔クロノス〕 Timeout が担当します（巡回から分離＝ロスタイムなし）。
                    if (loveDays <= 0 || taxRate <= 0.0f) continue;
                    const float lastLove    = v->GetFloat(id, "ASTR2_VassalLastLove", static_cast<float>(nowDay));
                    const float elapsedLove = static_cast<float>(nowDay - lastLove);   // 最後のHからの放置日数
                    float frac = (static_cast<float>(loveDays) - elapsedLove) / static_cast<float>(loveDays);
                    if (frac < 0.0f) frac = 0.0f;
                    // ★寵愛尽きの死(生者の死体化)は 〔クロノス〕 Timeout(ArmLoveTimer)が期限ピッタリで担当します＝ここ(6h発火)では死なせません。
                    const bool schlong = v->GetInt(id, "ASTR2_VassalHasSchlong", 0) == 1;
                    const int  prevLvl = v->GetInt(id, "ASTR2_VassalSigilLvl", 6);
                    const int  curLvl  = Sigil::UpdateNpcSigil(a, frac, schlong);
                    if (curLvl < prevLvl) {
                        const int dropped = prevLvl - curLvl;
                        taxSteps += dropped;
                        // 🩷 手下税の支払い通知です（段階降下ごと・死霊の支払い通知と相乗りトグル）
                        if (notifyPaid) {
                            const float baseStep = static_cast<float>(lfMax) * taxRate;
                            const int   amt      = static_cast<int>(baseStep / disc * static_cast<float>(dropped));
                            if (amt > 0) Notify("$ASTR2_Msg_VassalTax", { nm, std::to_string(amt) });
                        }
                        // ⚠️ 最後の2段階で寵愛切れ警告＝性別×性格×段階の12種に振り分けます。
                        //   性別M/F（GetSex）×性格Y/D/H（FormIDで個体固定＝同じ子は毎回同じ性格）×段階2/1。
                        //   キー＝$ASTR2_Msg_VLoveW<2|1>_<M|F><Y|D|H>（全12本・翻訳済み・引数{0}名前/{1}残り時間）。
                        if (curLvl == 2 || curLvl == 1) {
                            const int   warnHours = static_cast<int>((static_cast<float>(loveDays) - elapsedLove) * 24.0f);
                            auto*       base = a->GetActorBase();
                            const char  sx   = (base && static_cast<int>(base->GetSex()) == 1) ? 'F' : 'M';   // 1=female
                            const char  pers[3] = { 'Y', 'D', 'H' };
                            const char  ps   = pers[id % 3u];   // FormIDで性格を個体固定
                            const char  stg  = (curLvl == 2) ? '2' : '1';
                            const std::string key = std::string("$ASTR2_Msg_VLoveW") + stg + "_" + sx + ps;
                            // 本番HUDキューへ確定文字列を積みます（Notify(DebugNotification)から差し替え）＝1体5秒ずつ順番表示・ON/OFF判定はHUD側です。
                            VLoveHud::Enqueue(Localization::LocFmtStrCpp(key.c_str(), { nm, std::to_string(warnHours) }));
                        }
                    }
                    v->SetInt(id, "ASTR2_VassalSigilLvl", curLvl);
                    spdlog::info("[Upkeep] living {} 0x{:X} loveFrac={:.2f} sigil {}->{}", nm, id, frac, prevLvl, curLvl);
                } else {
                    // 🧟💰 死霊の維持費＝各死霊の蘇生時刻を基準に個別6h徴収します（グリッド廃止・3体バラバラのタイミング）。
                    //   last(=最後に徴収した時刻・初期は蘇生時刻)からの経過を6hコマ数に→まとめて徴収し last を繰り上げます。
                    if (upkeepRate <= 0.0f) continue;
                    const float raiseTime  = v->GetFloat(id, "ASTR2_VassalRaiseTime", static_cast<float>(nowDay));
                    const float lastCharge = v->GetFloat(id, "ASTR2_VassalUpkeepLast", raiseTime);
                    int deadSteps = static_cast<int>((static_cast<float>(nowDay) - lastCharge) / intervalDay);
                    if (deadSteps < 1) continue;   // まだ次の徴収時刻に達していません
                    const float base = static_cast<float>(lfMax) * upkeepRate;   // 1回分の割引前規定額です（XP用）
                    int upkeep1 = static_cast<int>(base / disc);
                    if (upkeep1 < 1) upkeep1 = 1;
                    const int   need    = upkeep1 * deadSteps;                   // 溜まったコマ数ぶんです（24h放置なら4回分）
                    const float newLast = lastCharge + static_cast<float>(deadSteps) * intervalDay;   // 徴収したコマまで繰り上げます
                    if (lf >= need) {
                        lf -= need;
                        v->SetInt(id, "ASTR2_VassalUpkeepMiss", 0);
                        v->SetFloat(id, "ASTR2_VassalUpkeepLast", newLast);
                        xp += base * kLFToSkillXp * static_cast<float>(deadSteps);
                        spdlog::info("[Upkeep] dead {} 0x{:X} paid {} (x{} base {:.1f} / disc {:.2f}) LF->{}", nm, id, need, deadSteps, base, disc, lf);
                        if (notifyPaid) Notify("$ASTR2_Msg_VassalUpkeepPaid", { nm, std::to_string(need) });
                    } else {
                        // 払えません＝時刻は繰り上げつつ未払いコマ数を miss に積みます（3連続で塵化）。
                        v->SetFloat(id, "ASTR2_VassalUpkeepLast", newLast);
                        const int miss = v->GetInt(id, "ASTR2_VassalUpkeepMiss", 0) + deadSteps;
                        v->SetInt(id, "ASTR2_VassalUpkeepMiss", miss);
                        spdlog::info("[Upkeep] dead {} 0x{:X} MISS {}/{} (need {} have {})", nm, id, miss, kMissLimit, need, lf);
                        if (miss >= kMissLimit) {
                            // 🧟💥 3連続未払い＝塵化します。灰化は既存の死亡掃除(ASTR2_VassalDied→OnVassalDied→AshifyVassal)へ回します。
                            Notify("$ASTR2_Msg_VassalUpkeepCrumble", { nm });
                            v->SetInt(id, "ASTR2_VassalUpkeepMiss", 0);
                            SKSE::ModCallbackEvent ev{};
                            ev.eventName = "ASTR2_VassalDied";
                            ev.sender = a;
                            SKSE::GetModCallbackEventSource()->SendEvent(&ev);
                            spdlog::info("[Upkeep] dead {} 0x{:X} crumble -> ASTR2_VassalDied", nm, id);
                        } else if (notifyMiss) {
                            Notify("$ASTR2_Msg_VassalUpkeepMiss", { nm, std::to_string(kMissLimit - miss) });
                        }
                    }
                }
            }

            // 🧟 手下税の徴収＝下がった段数ぶんをまとめて1回行います（足りなければ0まで）
            if (taxSteps > 0 && taxRate > 0.0f) {
                const float baseStep = static_cast<float>(lfMax) * taxRate;   // 割引前の規定額/段です（XP用）
                const int   taxAmt   = static_cast<int>(baseStep / disc * static_cast<float>(taxSteps));
                if (taxAmt > 0) {
                    lf = (lf > taxAmt) ? (lf - taxAmt) : 0;
                    xp += baseStep * static_cast<float>(taxSteps) * kLFToSkillXp;
                    spdlog::info("[Upkeep] minion tax -{} steps={} (base/step {:.1f} / disc {:.2f}) LF->{}", taxAmt, taxSteps, baseStep, disc, lf);
                }
            }

            if (lf != lfBefore) {
                v->SetInt(0, "ASTR2_LF_Curr", lf);
                // バー/段階バフの描き直し＝LF減衰と同じ合図です（受け口 ASTR2LifeForceBarScript.OnLifeForceTick）
                if (auto* src = SKSE::GetModCallbackEventSource()) {
                    SKSE::ModCallbackEvent ev{ "astr2_lf_tick", "", static_cast<float>(lf), nullptr };
                    src->SendEvent(&ev);
                }
            }
            if (xp > 0.0f) {
                GiveConjXp(xp);
                spdlog::info("[Upkeep] conjXP+{:.1f}", xp);
            }
        }

        // 〔クロノス〕の発火口＝実処理せず dirty を立てるだけです（放置中の連発を↑FlushTickが1回に束ねます／
        //   徴収は各死霊の last からの経過で出すので、ここで経過を渡さなくて済みます）。
        void Tick(float) {
            g_lastAccum = std::chrono::steady_clock::now();
            g_dirty     = true;
        }
    }

    // 🧟 スイート・ヴァッサルの蘇生可能日数＝単一の正です（徹底して二重に持ちません）。ASTConjCost.CalcVassalDays と NailDesc(呪文DESC) が共用します。
    //   材料が全部C++で読めます＝baseDays(〔SkyVault〕)/サキュバスLv(Global)/召喚スキル(ActorValue)＝旧Papyrus式をC++へ移設します。
    float VassalDaysNow() {
        auto* v = Vault();
        const float baseDays = v ? v->GetFloat(0, "ASTR2_VassalBaseDays", 10.0f) : 10.0f;
        int lv = SuccubusLevel();
        if (lv < 1) { lv = 1; }   // サキュバスLvは1始まりです（Papyrus版 sucLvl 初期1に一致）
        float conj = 0.0f;
        if (auto* pc = RE::PlayerCharacter::GetSingleton()) {
            if (auto* avo = pc->AsActorValueOwner()) {
                conj = avo->GetActorValue(RE::ActorValue::kConjuration);
            }
        }
        const float days = baseDays * static_cast<float>(lv) * (1.0f + conj / 100.0f);
        return days > 999.0f ? 999.0f : days;
    }

    // Papyrus窓口＝ASTR2Native.GetReanimVassalDays（MCM表示・実挙動が呼びます／NailDescは VassalDaysNow を直接呼びます）。
    float Papyrus_GetReanimVassalDays(RE::StaticFunctionTag*) { return VassalDaysNow(); }

    // Papyrusネイティブ登録します（ASTR2Native.ArmVassalLoveTimer＝生者の寵愛切れ死タイマーを張り替えます）。
    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm) {
        a_vm->RegisterFunction("ArmVassalLoveTimer",    "ASTR2Native", Papyrus_ArmVassalLoveTimer);
        a_vm->RegisterFunction("UpkeepStart",           "ASTR2Native", Papyrus_UpkeepStart);
        a_vm->RegisterFunction("CancelVassalLoveTimer", "ASTR2Native", Papyrus_CancelVassalLoveTimer);
        a_vm->RegisterFunction("GetReanimVassalDays",   "ASTR2Native", Papyrus_GetReanimVassalDays);
        return true;
    }

    void Install() {
        // ★RE操作（Sigil/AddSkillExperience/LookupForm）はゲームスレッドで＝〔クロノス〕の発火をAddTaskへ渡します。
        Chronos::RegisterInterval(kJobName, kIntervalH, [](float h) {
            SKSE::GetTaskInterface()->AddTask([h]() { Tick(h); });   // ★経過hを必ず渡します（捨てると飛ばした分を取りこぼします）
        });
        Chronos::StopInterval(kJobName);   // 初期は停止します＝手下0で起動（覚醒契約のイベント系＝対象が在る間だけ稼働）。作成時のUpkeepStartで動き出します。
        // 放置中の連発を1回にまとめる番人＝実時間0.25秒ごとに見て、発火が止まって約1秒で溜めた分を処理します。
        Chronos::RegisterRealtime("ASTR2VassalUpkeepFlush", 0.25f, FlushTick);
        spdlog::info("[Upkeep] registered to Chronos ({}h interval)", kIntervalH);
    }
}
