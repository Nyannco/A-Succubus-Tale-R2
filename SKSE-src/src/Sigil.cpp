#include "PCH.h"
#include "Sigil.h"
#include "SkeeInterface.h"
#include "SkyVaultAPI.h"

#include "RE/B/BSVisit.h"
#include "RE/B/BSTriShape.h"
#include "RE/N/NiSkinInstance.h"
#include "RE/N/NiSkinPartition.h"
#include "RE/T/TESFaction.h"
#include "RE/T/TESFile.h"

#include <algorithm>
#include <cctype>
#include <string>

#include <string>
#include <vector>

// ============================================================================
// Sigil ― 淫紋(ロゴ)の適用を C++(SKEE/NiOverride) で行います。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   ・プレイヤー淫紋(Lv連動)の適用・除去を C++ で持ちます。
//     種類 Default/Legacy/Chest/Back・段階 1-6・竿の有無でテクスチャを振り分けます。
//   ・NiOverride のキー/インデックス/値は Papyrus ApplyTattoo と同一です（＝見た目を変えません）。
//   ・固定表示モードとNPC淫紋は Papyrus 側に置きますso、ここはプレイヤーのLv連動経路だけです。
// ============================================================================

namespace {
    SKEE::IOverrideInterface*   g_override  = nullptr;  // ノードオーバーライド（テクスチャ/色/グロウ）＝本命です
    SKEE::IOverlayInterface*    g_overlay   = nullptr;  // オーバーレイ枠です（枚数/有無）
    SKEE::IBodyMorphInterface*  g_bodyMorph = nullptr;  // UpdateModelWeight（再描画）に使います
    bool g_acquired = false;

    // NiOverride のキーです（Papyrus ApplyTattoo と同値）。
    constexpr std::uint16_t kKeyTexture   = 9;  // ShaderTexture（index=スロット0=diffuse）
    constexpr std::uint16_t kKeyColor     = 0;  // ShaderEmissiveColor
    constexpr std::uint16_t kKeyEmissive  = 1;  // ShaderEmissiveMultiple（グロウ）
    constexpr std::uint16_t kKeyGloss     = 2;  // ShaderGlossiness
    constexpr std::uint16_t kKeySpecular  = 3;  // ShaderSpecularStrength
    constexpr std::uint16_t kKeyAlpha     = 8;  // ShaderAlpha
    constexpr std::uint8_t  kIdxTexture   = 0;     // テクスチャはスロット0です
    constexpr std::uint8_t  kIdxAll       = 0xFF;  // 非テクスチャは -1（=0xFF）＝Papyrus と同じです
    constexpr std::int32_t  kPinkColor    = static_cast<std::int32_t>(0xFFFF00FF);  // ピンク紫です（ApplyTattoo と同値）

    // ---- 🧍 ボディ自動検出機能〔プロテウス〕＝ボディタイプ検出＆テクスチャ名サフィックス ----
    //   0=3BA(既存パス・無印)/1=UBE(_UBE)/2=バニラ(_Vanilla)。UBEは独自UVso、専用テクスチャが要ります(同名＋サフィックス)。
    //   プレイヤー＝MCM(自動ON=環境検出/OFF=手動プルダウン)／NPC＝環境検出(UBE_AllRace.espロード有無)。
    //   ★カスタムフォロワーの専用ボディ個別判定は将来対応です。手動保険(MCM)がある前提のざっくり自動です。
    inline int SigilSVInt(const char* key, int def) {
        if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(0, key, def);
        return def;
    }
    // holder指定の read/write です（キャッシュ用。上のSigilSVIntはholder=0固定=グローバル設定用）。
    inline int  SigilSVIntH(std::uint32_t h, const char* key, int def) {
        if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) return v->GetInt(h, key, def);
        return def;
    }
    inline void SigilSVSetIntH(std::uint32_t h, const char* key, int val) {
        if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) v->SetInt(h, key, val);
    }
    // 検出用＝ボディの頂点数を数える3Dルート＝プレイヤーは三人称の体です（Get3D()は視点依存＝一人称だと手ツリー）。NPCは通常です。
    RE::NiAVObject* GetBodyRoot(RE::Actor* act) {
        if (!act) return nullptr;
        return (act == RE::PlayerCharacter::GetSingleton()) ? act->Get3D(false) : act->Get3D();
    }

    bool IsFemaleActor(RE::Actor* act);  // 前方宣言です（定義は下・ApplyAllViewsの男性分岐で使用）

    // オーバーライドの反映＝一括Apply。★プレイヤーの視点ツリーの扱いが男性淫紋の要です。
    //   ・女性/フタ＝三人称ツリー(Get3D(false))へApply＋手枠個別一人称＝本流(モーフ有りボディで視点切替も安定)。
    //   ・男性＝現在ビュー1ツリー(Get3D())へApply。★本流(三人称のみ)にすると視点切替(一人称→三人称)の瞬間に
    //     三人称ツリーが再構築されオーバーレイが真っ黒になります(モーフ無し=UpdateModelWeightが効きません・実機で確認)。
    //     現在ビュー1ツリー方式なら視点切替しても黒くなりません(実機で確認＝旧「〔プロテウス〕を通さない版」はOKでした)。
    //     ＝男性の描画即反映はApplyOverlayのAddOverlays、視点切替耐性はこの現在ビュー方式、の二段構えが正解です。
    //   ★ApplyNodeOverridesはノードを選べず、登録済みの全オーバーライドをツリーに焼きます。
    //   手の甲柄(Hands枠)は手枠を触る所(ApplyOverlay/ClearSlot/ClearSigil)がSetNodeProperty(firstPerson=true)で個別反映します。
    //   NPCは三人称のみです（一人称ボディはありません）。
    void ApplyAllViews(RE::Actor* act) {
        if (!g_override || !act) return;
        // ★男性は現在ビュー1ツリー(Get3D())へ＝視点切替の黒を回避します(上記コメント)。女性/フタ(isFemale)は下の本流です。
        if (act == RE::PlayerCharacter::GetSingleton() && !IsFemaleActor(act)) {
            if (auto* o = act->Get3D()) g_override->ApplyNodeOverrides(act, o, true);
            return;
        }
        if (act == RE::PlayerCharacter::GetSingleton()) {
            if (auto* tp = act->Get3D(false)) g_override->ApplyNodeOverrides(act, tp, true);  // 三人称のみです
        } else if (auto* o = act->Get3D()) {
            g_override->ApplyNodeOverrides(act, o, true);
        }
    }

    // 素体のshape名かを返します（装備/合算パーティションを除外＝素体だけ数えます）。
    //   ★Demonatrix等の高poly衣装は複数shapeが1 skinPartitionを共有し合算頂点(実測32068)を全shapeが報告
    //     →素体3BA(18436)超えでUBE範囲(24000-40000)を誤ヒット→bt=1→UBEtex無し→ピンク。so素体の正準名geomだけ数えます。
    static bool IsBodyShapeName(const char* a_name) {
        if (!a_name) return false;
        std::string s(a_name);
        std::transform(s.begin(), s.end(), s.begin(),
                       [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
        return s.find("3ba")       != std::string::npos
            || s.find("cbbe")      != std::string::npos
            || s.find("ube")       != std::string::npos
            || s.find("baseshape") != std::string::npos;
    }
    // 体shapeの最大頂点数＝ボディの"絶対指紋"としています（実測＝BodySlideのスライダーで不変）。
    //   バニラ≒1353／3BA≒18436／UBE≒29298。体メッシュ＝素体shape名のBSGeometry(装備/合算は除外・IsBodyShapeName)。
    int GetBodyVertexCount(RE::Actor* act) {
        if (!act) return 0;
        const bool isPlayer = (act == RE::PlayerCharacter::GetSingleton());
        // ★プレイヤーは三人称ボディ固定（Get3D()は視点依存＝一人称だと手だけ拾います）＝GetBodyRootで統一。
        auto* root = GetBodyRoot(act);
        if (!root) {
            spdlog::warn("[Sigil]   Get3D null (player={})", isPlayer);
            return 0;
        }
        spdlog::info("[Sigil]   root='{}' player={}", root->name.c_str(), isPlayer);
        int maxVerts = 0;
        std::string maxName;
        RE::BSVisit::TraverseScenegraphGeometries(root, [&](RE::BSGeometry* a_geom) -> RE::BSVisit::BSVisitControl {
            int v = 0;
            // 体＝スキンメッシュ（物理体BSDynamicTriShapeでもスキン経由で頂点数が取れます）。
            if (auto* skin = a_geom->GetGeometryRuntimeData().skinInstance.get()) {
                if (auto* part = skin->skinPartition.get()) {
                    v = static_cast<int>(part->vertexCount);
                }
            }
            // 髪/武器など非スキンは静的な頂点数へフォールバックします。
            if (v == 0) {
                if (auto* tri = a_geom->AsTriShape()) {
                    v = static_cast<int>(tri->GetTrishapeRuntimeData().vertexCount);
                }
            }
            const bool isBody = IsBodyShapeName(a_geom->name.c_str());  // 素体名だけ採ります＝衣装の合算頂点を除外します
            spdlog::info("[Sigil]     geom '{}' verts={}{}", a_geom->name.c_str(), v, isBody ? " [素体]" : "");
            if (isBody && v > maxVerts) { maxVerts = v; maxName = a_geom->name.c_str(); }
            return RE::BSVisit::BSVisitControl::kContinue;
        });
        spdlog::info("[Sigil]   -> max '{}' verts={}", maxName, maxVerts);
        return maxVerts;
    }
    // 非人型（動物/クリーチャー/巨人/ドレモラ/機械）＝ロゴ対象外＝解析前に弾きます（耐性ダウン等の効果はMGEFso別途付きます）。
    //   ★ActorTypeUndeadは除外しません（吸血鬼＝人型ボディ）。
    bool IsNonHumanoid(RE::Actor* act) {
        if (!act) return true;
        if (act->IsChild()) return true;   // ★子供＝淫紋対象外です(絶対・淫紋を出しません/リストにも載せません)
        static constexpr const char* kNonHuman[] = {
            "ActorTypeAnimal", "ActorTypeCreature", "ActorTypeGiant", "ActorTypeDaedra", "ActorTypeDwarven"
        };
        for (auto* kw : kNonHuman) {
            if (act->HasKeywordString(kw)) return true;
        }
        return false;
    }
    bool IsFemaleActor(RE::Actor* act) {
        auto* base = act ? act->GetActorBase() : nullptr;
        return base && static_cast<int>(base->GetSex()) == 1;  // 1=female（RE::SEX::kFemale）
    }
    // 個体別に扱う子か＝ユニーク or フォロワー（＝カスタムフォロワー/バニラユニーク）。個体別手動＆キャッシュ粒度分けで共用します。
    //   ★一般NPC(無数)はfalse＝ActorBaseまとめ/手動なし。プレイヤーはここでは扱いません(専用キー)。
    bool IsIndividualActor(RE::Actor* act) {
        if (!act || act == RE::PlayerCharacter::GetSingleton()) return false;
        auto* base = act->GetActorBase();
        if (base && base->IsUnique()) return true;
        if (auto* fac = RE::TESForm::LookupByID<RE::TESFaction>(0x0005C84E))  // CurrentFollowerFaction
            return act->IsInFaction(fac);
        return false;
    }
    // 非バニラesp由来か（カテゴリ判定用）＝バニラ/DLC/CC以外＝カスタムMOD追加NPCです。
    bool IsVanillaActor(RE::Actor* act) {
        auto* base = act ? act->GetActorBase() : nullptr;
        auto* file = base ? base->GetFile(0) : nullptr;   // 元定義のesp(master index0)
        if (!file) return false;
        std::string fn = std::string(file->GetFilename());
        if (fn == "Skyrim.esm" || fn == "Update.esm" || fn == "Dawnguard.esm" ||
            fn == "HearthFires.esm" || fn == "Dragonborn.esm") return true;
        return fn.rfind("cc", 0) == 0;   // Creation Club (cc*) もバニラ扱いです
    }
    // ボディ判定キャッシュ＝holderで粒度分け：プレイヤー0x14／フォロワー・ユニーク=ref個別／一般NPC=ActorBaseまとめ。
    //   キーは世代付き"SigilBT_v{epoch}"＝MCM再検出ボタンがepoch+1で旧世代を一括無効化します(〔SkyVault〕に全消しAPIがありませんため)。
    std::uint32_t SigilCacheHolder(RE::Actor* act) {
        if (!act) return 0;
        if (act == RE::PlayerCharacter::GetSingleton()) return 0x14;
        if (IsIndividualActor(act)) return act->GetFormID();    // 個体別です（ユニーク/フォロワー）
        auto* base = act->GetActorBase();
        return base ? base->GetFormID() : act->GetFormID();     // 一般NPC=ActorBaseまとめ
    }
    std::string SigilCacheKey() {
        return "SigilBT_v" + std::to_string(SigilSVInt("ASTR2_SigilCacheEpoch", 0));
    }
    // ボディタイプ判定＝0=3BA/1=UBE(女性のみ)／★-1=ロゴ対象外(非人型)。呼び側は-1でロゴをスキップします。
    //   ★UBE対象は「女性UBE」だけ＝男性・バニラ・その他は全部3BA無印を貼ります
    //     （男性用/バニラ用テクスチャは作りません・男体はTNGのみです）。
    int DetectBodyType(RE::Actor* act) {
        const char* who = act ? act->GetDisplayFullName() : "null";
        // プレイヤー手動＝キャッシュ迂回＝MCM変更を即反映します（自動OFF時のみ）。
        const bool isPlayer = (act && act == RE::PlayerCharacter::GetSingleton());
        if (isPlayer && SigilSVInt("ASTR2_BodyAutoDetect", 1) == 0) {
            int m = SigilSVInt("ASTR2_BodyManual", 0);   // 手動: 0=3BA/1=UBE/2=バニラ
            if (m == 2) m = 0;                           // ★バニラは3BAに倒します（バニラ用テクスチャ無し）
            spdlog::info("[Sigil] DetectBodyType: {} 手動選択 -> bt={}", who, m);
            return m;
        }
        // ★個体別手動＝ユニーク/カスタムフォロワーに手動bt(≠-1)があればキャッシュ迂回で優先します。
        //   -1=自動／0=3BA／1=UBE／2=バニラ(→3BAに倒します)。MCMリストが SigilSetManualBt で書きます。
        if (!isPlayer && IsIndividualActor(act)) {
            const int mb = SigilSVIntH(act->GetFormID(), "SigilManualBt", -1);
            if (mb >= 0) {
                const int bt = (mb == 2) ? 0 : mb;   // バニラは3BAに倒します（バニラ用tex無し）
                spdlog::info("[Sigil] DetectBodyType: {} 個体手動 -> bt={}", who, bt);
                return bt;
            }
        }
        // ★キャッシュ参照＝初回だけ解析、2回目以降ゼロです。非人型(-1)も含めキャッシュします。
        const std::uint32_t holder = SigilCacheHolder(act);
        const std::string   key    = SigilCacheKey();
        constexpr int kSent = -999;                       // 未キャッシュ番兵です
        const int cached = SigilSVIntH(holder, key.c_str(), kSent);
        if (cached != kSent) {
            spdlog::info("[Sigil] DetectBodyType: {} cache(holder={:08X}) -> bt={}", who, holder, cached);
            return cached;
        }
        // 未キャッシュ→判定して保存します。
        int bt;
        if (IsNonHumanoid(act)) {                          // 非人型（動物/クリーチャー等）＝淫紋対象外です
            bt = -1;
            spdlog::info("[Sigil] DetectBodyType: {} 非人型 -> bt=-1 (新規)", who);
        } else {
            // ★性別で分けません＝男女とも同じ検出パスです（女性で正常so男性も同じ）。
            //   男性ボディ(バニラ~1385/TNG~8073)はUBE範囲(24000〜)外so自動でbt=0(3BA無印)。
            const int verts = GetBodyVertexCount(act);
            bt = (verts >= 24000 && verts <= 40000) ? 1 : 0;  // UBE範囲(~29298)だけ1・他は全部3BA
            spdlog::info("[Sigil] DetectBodyType: {} verts={} -> bt={} (新規)", who, verts, bt);
        }
        SigilSVSetIntH(holder, key.c_str(), bt);          // ★キャッシュに保存します
        // ★淫紋を使った個体(ユニーク/カスタム)をListに記録します＝MCMリストの表示源(初回遭遇時だけ・unique重複防止)。
        if (IsIndividualActor(act) && bt >= 0 && SigilSVIntH(act->GetFormID(), "SigilExcluded", 0) == 0) {  // ★除外フラグが立ってたら載せません(個別排除)
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) {
                v->ListAdd(0, "ASTR2_SigilUsedActors", act->GetFormID(), true);
                spdlog::info("[Sigil] UsedActors登録: {} (個体別＝MCMリスト表示対象)", who);  // ★誰が載ったかを可視化します(衛兵=一般NPCはここ通りません/子供は上のIsNonHumanoidで弾かれます)
            }
        }
        return bt;
    }
    // テクスチャ名の ".dds" 直前にボディ別サフィックスを挟みます（3BA=無印＝既存据え置き）。
    std::string WithBodySuffix(const std::string& tex, int bodyType) {
        if (bodyType == 0 || tex.empty()) return tex;
        const char* sfx = (bodyType == 1) ? "_UBE" : "_Vanilla";
        const auto dot = tex.rfind(".dds");
        if (dot == std::string::npos) return tex;
        return tex.substr(0, dot) + sfx + tex.substr(dot);
    }

    // ---- SetVariant サブクラス（値の受け渡し）----
    struct SetStr : SKEE::IOverrideInterface::SetVariant {
        const char* v;
        explicit SetStr(const char* s) : v(s) {}
        Type        GetType() override { return Type::String; }
        const char* String()  override { return v; }
    };
    struct SetInt : SKEE::IOverrideInterface::SetVariant {
        std::int32_t v;
        explicit SetInt(std::int32_t i) : v(i) {}
        Type         GetType() override { return Type::Int; }
        std::int32_t Int()     override { return v; }
    };
    struct SetFlt : SKEE::IOverrideInterface::SetVariant {
        float v;
        explicit SetFlt(float f) : v(f) {}
        Type  GetType() override { return Type::Float; }
        float Float()   override { return v; }
    };

    // ---- GetVariant サブクラス（現在のテクスチャ文字列を読む＝スロット占有判定/掃除用）----
    struct GetStr : SKEE::IOverrideInterface::GetVariant {
        std::string val;
        bool        got = false;
        void Int(const std::int32_t) override {}
        void Float(const float) override {}
        void String(const char* s) override { if (s) { val = s; got = true; } }
        void Bool(const bool) override {}
        void TextureSet(const RE::BGSTextureSet*) override {}
    };

    // オーバーレイ位置＝Body(既定) or Hands。★手の甲柄(ASTR2Tatto Hand)は手UVso、Hands 枠に貼る必要があります
    //   （Body枠に貼ると体UVに乗って位置が合いません＝実機で確認）。それ以外(股間/胸/背中/肩)はBodyです。
    int OverlayCount(bool hands) {
        if (!g_overlay) return 0;
        auto loc = hands ? SKEE::IOverlayInterface::OverlayLocation::Hand
                         : SKEE::IOverlayInterface::OverlayLocation::Body;
        return static_cast<int>(g_overlay->GetOverlayCount(SKEE::IOverlayInterface::OverlayType::Normal, loc));
    }
    std::string OverlayNode(bool hands, int slot) {
        return std::string(hands ? "Hands" : "Body") + " [ovl" + std::to_string(slot) + "]";
    }
    // 手枠に貼るべきテクスチャか＝"ASTR2Tatto Hand.dds" だけです（肩ShoulderL/R等は体枠）。
    bool IsHandTexture(const std::string& tex) {
        return tex.find("Hand.dds") != std::string::npos;
    }

    // そのスロットのテクスチャです（空なら got=false or 空/既定）。
    bool SlotIsEmpty(RE::Actor* act, bool isFemale, bool hands, int slot) {
        std::string node = OverlayNode(hands, slot);
        GetStr g;
        bool has = g_override->GetNodeOverride(act, isFemale, node.c_str(), kKeyTexture, kIdxTexture, g);
        if (!has || !g.got) return true;
        return g.val.empty() || g.val == "actors\\character\\overlays\\default.dds";
    }

    // 空きスロットを探します（無ければ -1）。hands=手枠/体枠。
    int FindEmptySlot(RE::Actor* act, bool isFemale, bool hands) {
        int n = OverlayCount(hands);
        for (int i = 0; i < n; ++i) {
            if (SlotIsEmpty(act, isFemale, hands, i)) return i;
        }
        return -1;
    }

    // テクスチャを選択します（Lv連動・モード0-3）。level は 1-6 です。
    std::string LeveledTexture(int mode, int level, bool isFemale, bool maleTex) {
        std::string lv = std::to_string(level);
        if (mode == 1) {          // Legacy＝股間・竿の有無で振り分け
            return maleTex ? ("Tattoos\\MaleSucTattooMediumlvl" + lv + ".dds")
                           : ("Tattoos\\ASTR2Tatto" + lv + ".dds");
        } else if (mode == 2) {   // Chest＝強制胸
            return "Tattoos\\ASTR2Tatto chest" + lv + ".dds";
        } else if (mode == 3) {   // Back＝強制背中
            return "Tattoos\\ASTR2Tatto back" + lv + ".dds";
        }
        // mode 0 Default＝性別で胸/背中（女フタ=胸・男=背中）
        return isFemale ? ("Tattoos\\ASTR2Tatto chest" + lv + ".dds")
                        : ("Tattoos\\ASTR2Tatto back" + lv + ".dds");
    }

    // NPC淫紋のテクスチャ＝股間・竿の有無で振り分けます（女=ASTR2Tatto無印／男フタ=MaleSucTattooMedium）。level 1-6。
    std::string NpcSigilTexture(bool hasSchlong, int level) {
        std::string lv = std::to_string(level);
        return hasSchlong ? ("Tattoos\\MaleSucTattooMediumlvl" + lv + ".dds")
                          : ("Tattoos\\ASTR2Tatto" + lv + ".dds");
    }
    // 💋 1回制限の痕のテクスチャ＝**男=背中／女・フタ=胸**です。
    //   ウィークネス/手下の股間紋と**別の場所**にします＝同じ相手に両方付いても被りません。
    //   胸/背中のアートは性別共用so竿の有無は不要です（＝Lv連動淫紋のDefaultモードと同じ選び方）。
    std::string DrainMarkTexture(bool isFemale, int level) {
        return LeveledTexture(0, level, isFemale, false);
    }

    // 痕が貼ってある体枠を探します（胸/背中のテクスチャが目印）。無ければ -1。
    //   ★股間紋(ASTR2Tatto<数字> / MaleSucTattooMediumlvl)は拾いません＝互いに上書き/掃除し合いません。
    int FindDrainMarkSlot(RE::Actor* act, bool isFemale) {
        int n = OverlayCount(false);
        for (int i = 0; i < n; ++i) {
            std::string node = OverlayNode(false, i);
            GetStr g;
            if (!g_override->GetNodeOverride(act, isFemale, node.c_str(), kKeyTexture, kIdxTexture, g) || !g.got) continue;
            if (g.val.find("ASTR2Tatto chest") != std::string::npos ||
                g.val.find("ASTR2Tatto back")  != std::string::npos) {
                return i;
            }
        }
        return -1;
    }

    // 手枠(Hands)ノードの全プロパティを一人称ツリーへ個別に反映します（プレイヤーのみ・値は三人称と同一）。
    //   ★手の甲柄は一人称でも見える→一人称ツリーに要ります。SetNodeProperty(firstPerson=true)＝指定ノードだけを
    //     一人称ツリーへ直接反映so体枠(Body)を巻き込みません（＝男性の体柄が一人称へ漏れません）。NPCは一人称ボディ無しso対象外です。
    void HandsToFirstPerson(RE::Actor* act, const char* node, const std::string& tex, bool glow) {
        if (!g_override || act != RE::PlayerCharacter::GetSingleton()) return;
        SetStr sTex(tex.c_str());           g_override->SetNodeProperty(act, true, node, kKeyTexture,  kIdxTexture, sTex,   true);
        SetInt sCol(kPinkColor);            g_override->SetNodeProperty(act, true, node, kKeyColor,    kIdxAll,     sCol,   true);
        SetFlt sAlpha(0.8f);                g_override->SetNodeProperty(act, true, node, kKeyAlpha,    kIdxAll,     sAlpha, true);
        SetFlt sGloss(0.0f);                g_override->SetNodeProperty(act, true, node, kKeyGloss,    kIdxAll,     sGloss, true);
        SetFlt sSpec(1.0f);                 g_override->SetNodeProperty(act, true, node, kKeySpecular, kIdxAll,     sSpec,  true);
        SetFlt sEmis(glow ? 0.5f : 0.0f);   g_override->SetNodeProperty(act, true, node, kKeyEmissive, kIdxAll,     sEmis,  true);
    }
    // 手枠ノードを一人称ツリーで既定(透明)へ戻します（プレイヤーのみ）。手枠クリアの一人称ぶんです。
    void ClearHandsFirstPerson(RE::Actor* act, const char* node) {
        if (!g_override || act != RE::PlayerCharacter::GetSingleton()) return;
        SetStr sDefault("actors\\character\\overlays\\default.dds");
        SetFlt sGlowOff(0.0f);
        g_override->SetNodeProperty(act, true, node, kKeyTexture,  kIdxTexture, sDefault, true);
        g_override->SetNodeProperty(act, true, node, kKeyEmissive, kIdxAll,     sGlowOff, true);
    }

    // 枠1つぶんだけ淫紋を消します（ClearSigilの単枠版＝他の紋は残します）。手順はClearSigilと同じです
    //   ＝①テクスチャを既定(透明)へ上書きして反映します（live geometryはRemoveだけでは消えません）②ストレージから撤去します。
    void ClearSlot(RE::Actor* act, bool isFemale, bool hands, int slot) {
        std::string node = OverlayNode(hands, slot);
        const char* nd = node.c_str();
        SetStr sDefault("actors\\character\\overlays\\default.dds");
        SetFlt sGlowOff(0.0f);
        g_override->AddNodeOverride(act, isFemale, nd, kKeyTexture,  kIdxTexture, sDefault);
        g_override->AddNodeOverride(act, isFemale, nd, kKeyEmissive, kIdxAll,     sGlowOff);
        ApplyAllViews(act);
        if (hands) ClearHandsFirstPerson(act, nd);   // ★手枠は一人称ツリーも既定へ戻します
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeyTexture,  kIdxTexture);
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeyColor,    kIdxAll);
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeyAlpha,    kIdxAll);
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeyGloss,    kIdxAll);
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeySpecular, kIdxAll);
        g_override->RemoveNodeOverride(act, isFemale, nd, kKeyEmissive, kIdxAll);
        ApplyAllViews(act);
    }

    // 残り時間割合 frac(0-1) → 段階(1-6)。満タン=6・残りわずか=1。
    //   ★6刻み＝各段階 loveDays/6（3日→12h・6日→24h）で1つ下がります。段階1(=残り1/6区間)が「最後のロゴ」で、
    //     その先 frac=0（loveDays経過）で寵愛切れ＝生者の死です（死体化／死判定はVassalUpkeep側）。
    int NpcLevelForFrac(float frac) {
        int lvl = static_cast<int>(6.0f * frac) + 1;
        if (lvl < 1) lvl = 1;
        if (lvl > 6) lvl = 6;
        return lvl;
    }

    // 固定表示モードのテクスチャを選択します（MCMの各fixed index。0=未選択・排他so最初の>0を採用）。
    //   ★固定モードは「明示選択・性別不問・崩れてもOK」＝レガシーは女art/男artを別枠で選べます（LegacyMaleほころび解消）。
    std::string FixedTexture(int fChest, int fBack, int fLegacy, int fLegacyMale, int fSmall, int fMisc, bool hasSchlong) {
        if (fChest > 0) return "Tattoos\\ASTR2Tatto chest" + std::to_string(fChest) + ".dds";
        if (fBack  > 0) return "Tattoos\\ASTR2Tatto back"  + std::to_string(fBack)  + ".dds";
        if (fMisc  > 0) {
            if (fMisc == 1) return "Tattoos\\ASTR2Tatto Hand.dds";
            if (fMisc == 2) return "Tattoos\\ASTR2Tatto Shoulder.dds";
            if (fMisc == 3) return "Tattoos\\ASTR2Tatto ShoulderL.dds";
            if (fMisc == 4) return "Tattoos\\ASTR2Tatto ShoulderR.dds";
        }
        if (fLegacy     > 0) return "Tattoos\\ASTR2Tatto" + std::to_string(fLegacy) + ".dds";                  // レガシー女です
        if (fLegacyMale > 0) return "Tattoos\\MaleSucTattooMediumlvl" + std::to_string(fLegacyMale) + ".dds";  // レガシー男です(ほころび解消)
        if (fSmall > 0) {   // 小＝男/女版（男専用MCM枠がないので竿の有無で振り分け）
            return hasSchlong ? ("Tattoos\\MaleSucTattooSmalllvl" + std::to_string(fSmall) + ".dds")
                              : ("Tattoos\\SucTattooSmalllvl" + std::to_string(fSmall) + ".dds");
        }
        return "";   // 何も選ばれていません
    }

    // 1スロットへ淫紋を全適用します（テクスチャ+色+グロウ）。Papyrus ApplyTattoo と同じキー/値です。hands=手枠/体枠。
    void ApplyOverlay(RE::Actor* act, bool isFemale, bool hands, int slot, const std::string& tex, bool glow) {
        std::string node = OverlayNode(hands, slot);
        const char* n = node.c_str();

        SetStr sTex(tex.c_str());
        g_override->AddNodeOverride(act, isFemale, n, kKeyTexture, kIdxTexture, sTex);
        SetInt sCol(kPinkColor);
        g_override->AddNodeOverride(act, isFemale, n, kKeyColor, kIdxAll, sCol);
        SetFlt sAlpha(0.8f);
        g_override->AddNodeOverride(act, isFemale, n, kKeyAlpha, kIdxAll, sAlpha);
        SetFlt sGloss(0.0f);
        g_override->AddNodeOverride(act, isFemale, n, kKeyGloss, kIdxAll, sGloss);
        SetFlt sSpec(1.0f);
        g_override->AddNodeOverride(act, isFemale, n, kKeySpecular, kIdxAll, sSpec);
        SetFlt sEmis(glow ? 0.5f : 0.0f);
        g_override->AddNodeOverride(act, isFemale, n, kKeyEmissive, kIdxAll, sEmis);

        ApplyAllViews(act);
        if (hands) HandsToFirstPerson(act, n, tex, glow);   // ★手の甲柄は一人称ツリーにも個別に反映します（体枠は流しません）
        if (g_bodyMorph) {
            g_bodyMorph->UpdateModelWeight(act, false);  // SKEEに再構築させ確実に反映します(モーフ有りボディ=女性3BA/UBE)
        }
        // ★男性はボディモーフ(.tri)が無くUpdateModelWeightが実質no-op＝貼ったテクスチャがliveに再ロードされず黒くなります
        //   (TNG/バニラ男体はモーフ焼き無し＝es全ドライブ実測＝male body .tri ゼロ件／女性は3BA/CBBEでtri有り)。
        //   →オーバーレイ枠を直接(再)構築させてテクスチャを即ロード反映します(モーフ非依存)。女性/フタ(isFemale)は従来のまま無影響です。
        if (!isFemale && g_overlay) {
            g_overlay->AddOverlays(act, false);   // defer=false=即座に枠を再構築します
        }
    }

    // このアクターの淫紋を掃除します（ASTR2Tatto/SucTattoo を持つ枠のオーバーライドを撤去します）。★Body と Hands 両方を走査します
    //   （手の甲柄は手枠に貼るのでBodyだけ見ると剥がし残ります）。
    void ClearSigil(RE::Actor* act, bool isFemale) {
        std::vector<std::string> hits;   // 淫紋があったノード（Body/Hands両方）

        // ①見た目を消します＝テクスチャを既定(透明 default.dds)へ差し替え＋グロウ0にして適用します。
        //   ★「除去(RemoveNodeOverride)」だけでは既に貼られた live geometry のテクスチャが残ります
        //     （UpdateModelWeight はボディモーフ再構築で、貼付済オーバーレイのdiffuseは消えません＝
        //      リロードで初めて消えます）。旧Papyrus RemoveTattoo と同じく"既定へ上書き"で直接消します。
        SetStr sDefault("actors\\character\\overlays\\default.dds");
        SetFlt sGlowOff(0.0f);
        for (int pass = 0; pass < 2; ++pass) {   // 0=Body, 1=Hands
            bool hands = (pass == 1);
            int n = OverlayCount(hands);
            for (int i = 0; i < n; ++i) {
                std::string node = OverlayNode(hands, i);
                const char* nd = node.c_str();
                GetStr g;
                if (!g_override->GetNodeOverride(act, isFemale, nd, kKeyTexture, kIdxTexture, g) || !g.got) continue;
                if (g.val.find("ASTR2Tatto") == std::string::npos && g.val.find("SucTattoo") == std::string::npos) continue;
                hits.push_back(node);
                g_override->AddNodeOverride(act, isFemale, nd, kKeyTexture,  kIdxTexture, sDefault);
                g_override->AddNodeOverride(act, isFemale, nd, kKeyEmissive, kIdxAll,     sGlowOff);
                if (hands) ClearHandsFirstPerson(act, nd);   // ★手枠は一人称ツリーも既定へ戻します
            }
        }
        if (hits.empty()) return;

        ApplyAllViews(act);   // 既定への差し替えを反映＝淫紋が消えます

        // ②ストレージから完全に撤去します（default.dds も含め残しません＝蓄積防止・次回は空き枠として再利用できます）。
        for (const std::string& node : hits) {
            const char* nd = node.c_str();
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeyTexture,  kIdxTexture);
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeyColor,    kIdxAll);
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeyAlpha,    kIdxAll);
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeyGloss,    kIdxAll);
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeySpecular, kIdxAll);
            g_override->RemoveNodeOverride(act, isFemale, nd, kKeyEmissive, kIdxAll);
        }
        ApplyAllViews(act);
    }
}

namespace Sigil {

    void AcquireSkee() {
        auto* messaging = SKSE::GetMessagingInterface();
        if (!messaging) {
            spdlog::error("[Sigil] messaging interface が取れない");
            return;
        }
        SKEE::InterfaceExchangeMessage msg;
        messaging->Dispatch(SKEE::InterfaceExchangeMessage::kMessage_ExchangeInterface,
                            reinterpret_cast<void*>(&msg), sizeof(msg), "skee");
        if (!msg.interfaceMap) {
            spdlog::warn("[Sigil] SKEE interfaceMap = null ＝ skee64.dll(RaceMenu) が無い/古い/未ロードの可能性");
            g_acquired = false;
            return;
        }
        g_override  = static_cast<SKEE::IOverrideInterface*>(msg.interfaceMap->QueryInterface("Override"));
        g_overlay   = static_cast<SKEE::IOverlayInterface*>(msg.interfaceMap->QueryInterface("Overlay"));
        g_bodyMorph = static_cast<SKEE::IBodyMorphInterface*>(msg.interfaceMap->QueryInterface("BodyMorph"));

        spdlog::info("[Sigil] SKEE 取得: Override={} (v{}) / Overlay={} (v{}) / BodyMorph={} (v{})",
                     reinterpret_cast<void*>(g_override),  g_override  ? g_override->GetVersion()  : 0u,
                     reinterpret_cast<void*>(g_overlay),   g_overlay   ? g_overlay->GetVersion()   : 0u,
                     reinterpret_cast<void*>(g_bodyMorph), g_bodyMorph ? g_bodyMorph->GetVersion() : 0u);

        g_acquired = (g_override != nullptr) && (g_overlay != nullptr) && (g_bodyMorph != nullptr);
        spdlog::info("[Sigil] SkeeReady = {}", g_acquired);
    }

    // ---- Papyrus native ----
    // 🧍 現在のプレイヤーのボディタイプです（MCMボディ欄の表示＆手動プルダウン初期値用）。0=3BA/1=UBE/2=バニラ。
    std::int32_t Papyrus_SigilGetBodyType(RE::StaticFunctionTag*) { return DetectBodyType(RE::PlayerCharacter::GetSingleton()); }

    // 🧍 ボディ判定キャッシュを全消去(=世代+1)＝MCM「ボディ再検出」ボタン用です。環境(ボディMOD)を変えた後に押します。
    void Papyrus_SigilResetBodyCache(RE::StaticFunctionTag*) {
        const int e = SigilSVInt("ASTR2_SigilCacheEpoch", 0);
        SigilSVSetIntH(0, "ASTR2_SigilCacheEpoch", e + 1);
        // ★個体別リストも連動クリア＝再検出で手動リストも空になります。〔SkyVault〕にList一括Clear APIがないのでindex0を件数分RemoveAtします。
        int cleared = 0;
        if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) {
            const int n = v->ListCount(0, "ASTR2_SigilUsedActors");
            for (int i = 0; i < n; ++i) v->ListRemoveAt(0, "ASTR2_SigilUsedActors", 0);
            cleared = n;
        }
        spdlog::info("[Sigil] ResetBodyCache: epoch {} -> {} (全キャッシュ無効化) + UsedActors {}件クリア", e, e + 1, cleared);
    }

    // 🧍 個体別手動bt＝ユニーク/カスタムフォロワーのボディ手動値。-1=自動/0=3BA/1=UBE/2=バニラ。MCMリストが読み書きします。
    std::int32_t Papyrus_SigilGetManualBt(RE::StaticFunctionTag*, RE::Actor* akActor) {
        if (!akActor) return -1;
        return SigilSVIntH(akActor->GetFormID(), "SigilManualBt", -1);
    }
    void Papyrus_SigilSetManualBt(RE::StaticFunctionTag*, RE::Actor* akActor, std::int32_t a_bt) {
        if (!akActor) return;
        SigilSVSetIntH(akActor->GetFormID(), "SigilManualBt", a_bt);  // -1で自動へ戻します
        spdlog::info("[Sigil] SetManualBt: {} -> {}", akActor->GetDisplayFullName(), a_bt);
    }
    // 🧍 実効ボディ種別(表示用)＝手動優先→キャッシュ→検出の結果(0=3BA/1=UBE・-1=非人型)。MCMリストの「名前(3BA)」表示に使います。
    std::int32_t Papyrus_SigilGetEffectiveBt(RE::StaticFunctionTag*, RE::Actor* akActor) {
        return DetectBodyType(akActor);
    }
    // 🧍 カテゴリ(振り分け表示)＝0=一般／1=ユニーク(結婚/フォロワー可能な固有NPC)／2=カスタム(非バニラesp由来)。
    std::int32_t Papyrus_SigilGetActorCategory(RE::StaticFunctionTag*, RE::Actor* akActor) {
        auto* base = akActor ? akActor->GetActorBase() : nullptr;
        if (!base) return 0;
        if (!IsVanillaActor(akActor)) return 2;   // カスタム＝非バニラesp
        if (base->IsUnique()) {
            auto* fMar = RE::TESForm::LookupByID<RE::TESFaction>(0x019809);  // PotentialMarriageFaction
            auto* fFol = RE::TESForm::LookupByID<RE::TESFaction>(0x05C84D);  // PotentialFollowerFaction
            if ((fMar && akActor->IsInFaction(fMar)) || (fFol && akActor->IsInFaction(fFol))) return 1;  // ユニークです
        }
        return 0;   // 一般です(固有名でもマリッジ/フォロワー不可＝その他大勢)
    }
    // 🧍 個別排除＝この子をリストから外します(再検出まで再登録しません)。true=除外(List除去＋フラグ)／false=解除。
    void Papyrus_SigilSetExcluded(RE::StaticFunctionTag*, RE::Actor* akActor, bool a_excluded) {
        if (!akActor) return;
        SigilSVSetIntH(akActor->GetFormID(), "SigilExcluded", a_excluded ? 1 : 0);
        if (a_excluded) {
            if (auto* v = SkyVaultAPI::GetSkyVaultAPI()) {
                const std::uint32_t fid = akActor->GetFormID();   // 該当FormIDをListから抜きます(後ろから走査)
                for (int i = v->ListCount(0, "ASTR2_SigilUsedActors") - 1; i >= 0; --i)
                    if (v->ListGet(0, "ASTR2_SigilUsedActors", i) == fid)
                        v->ListRemoveAt(0, "ASTR2_SigilUsedActors", i);
            }
        }
        spdlog::info("[Sigil] SetExcluded: {} -> {}", akActor->GetDisplayFullName(), a_excluded);
    }

    // プレイヤー淫紋(Lv連動)を適用します。mode=0-3(Default/Legacy/Chest/Back)・level=1-6・maleTex=竿ありor手動男。
    void Papyrus_SigilApplyPlayer(RE::StaticFunctionTag*, RE::Actor* akActor, std::int32_t mode,
                                  std::int32_t level, bool glow, bool maleTex) {
        if (!g_acquired || !akActor) {
            spdlog::warn("[Sigil] ApplyPlayer 中断: ready={} actor={}", g_acquired, reinterpret_cast<void*>(akActor));
            return;
        }
        bool isFemale = IsFemaleActor(akActor);
        if (!g_overlay->HasOverlays(akActor)) {
            g_overlay->AddOverlays(akActor, false);  // 枠が無ければ確保します
        }
        ClearSigil(akActor, isFemale);  // 旧淫紋を掃除します（二重貼り防止）
        int slot = FindEmptySlot(akActor, isFemale, false);   // プレイヤーLv連動は体枠です
        if (slot < 0) {
            spdlog::warn("[Sigil] ApplyPlayer: 空きBodyオーバーレイ枠なし（count={}）", OverlayCount(false));
            return;
        }
        if (level < 1) level = 1;
        if (level > 6) level = 6;
        const int bt = DetectBodyType(akActor);
        if (bt < 0) return;   // 非人型/専用skin＝ロゴ対象外です
        std::string tex = WithBodySuffix(LeveledTexture(mode, level, isFemale, maleTex), bt);
        ApplyOverlay(akActor, isFemale, false, slot, tex, glow);
        spdlog::info("[Sigil] ApplyPlayer: mode={} lv={} slot={} female={} maleTex={} glow={} tex={}",
                     mode, level, slot, isFemale, maleTex, glow, tex);
    }

    // プレイヤー淫紋を除去します。
    void Papyrus_SigilClear(RE::StaticFunctionTag*, RE::Actor* akActor) {
        if (!g_acquired || !akActor) return;
        ClearSigil(akActor, IsFemaleActor(akActor));
        spdlog::info("[Sigil] Clear: {}", reinterpret_cast<void*>(akActor));
    }

    // NPC淫紋(ウィークネス/手下)を適用します＝股間固定・frac→段階・竿振り分け。
    //   ★貼る前に既存を掃除so常に1枚＝ウィークネス→手下の順でも手下が上書きできます。
    void Papyrus_SigilApplyNpc(RE::StaticFunctionTag*, RE::Actor* akNpc, float frac, bool hasSchlong) {
        if (!g_acquired || !akNpc) return;
        bool isFemale = IsFemaleActor(akNpc);
        if (!g_overlay->HasOverlays(akNpc)) {
            g_overlay->AddOverlays(akNpc, false);   // 立ちNPCは枠未設置のことがあります
        }
        ClearSigil(akNpc, isFemale);   // 既存淫紋を掃除＝1枚に保ちます（上書き）
        int slot = FindEmptySlot(akNpc, isFemale, false);   // NPC淫紋は股間＝体枠です
        if (slot < 0) {
            spdlog::warn("[Sigil] ApplyNpc: 空きBodyオーバーレイ枠なし {}", reinterpret_cast<void*>(akNpc));
            return;
        }
        const int bt = DetectBodyType(akNpc);
        if (bt < 0) return;   // 非人型/専用skin＝ロゴ対象外です（耐性ダウン等の効果はMGEFで別途付きます）
        int level = NpcLevelForFrac(frac);
        std::string tex = WithBodySuffix(NpcSigilTexture(hasSchlong, level), bt);
        ApplyOverlay(akNpc, isFemale, false, slot, tex, true);   // NPC淫紋はグロウON固定です
        spdlog::info("[Sigil] ApplyNpc: lv={} slot={} female={} schlong={} tex={}", level, slot, isFemale, hasSchlong, tex);
    }

    // NPC淫紋の段階だけ更新＝既存枠を探して段階が変わってたら貼り替えます。★段階(1-6)を返します＝巡回が更新と段階取得を1回で済ませられます。
    std::int32_t Papyrus_SigilUpdateNpc(RE::StaticFunctionTag*, RE::Actor* akNpc, float frac, bool hasSchlong) {
        int level = NpcLevelForFrac(frac);   // 淫紋の有無に関係なく段階は必ず返します（手下税がこれを使います）
        if (!g_acquired || !akNpc) return level;
        bool isFemale = IsFemaleActor(akNpc);
        const int bt = DetectBodyType(akNpc);
        if (bt < 0) return level;   // 非人型＝ロゴ更新せず段階だけ返します（手下税用）
        std::string wantTex = WithBodySuffix(NpcSigilTexture(hasSchlong, level), bt);
        int n = OverlayCount(false);   // NPC淫紋は股間＝体枠です
        for (int i = 0; i < n; ++i) {
            std::string node = OverlayNode(false, i);
            const char* nd = node.c_str();
            GetStr g;
            if (!g_override->GetNodeOverride(akNpc, isFemale, nd, kKeyTexture, kIdxTexture, g) || !g.got) continue;
            if (g.val.find("ASTR2Tatto") == std::string::npos && g.val.find("SucTattoo") == std::string::npos) continue;
            if (g.val != wantTex) {
                SetStr sTex(wantTex.c_str());
                g_override->AddNodeOverride(akNpc, isFemale, nd, kKeyTexture, kIdxTexture, sTex);
                ApplyAllViews(akNpc);
                if (g_bodyMorph) g_bodyMorph->UpdateModelWeight(akNpc, false);
            }
            return level;   // 淫紋は1枠so最初の1つで完了です
        }
        return level;
    }

    // 固定表示モードの淫紋を適用＝MCMの各fixed indexから明示テクスチャを貼ります（内部で既存掃除→貼付so1枚）。
    void Papyrus_SigilApplyFixed(RE::StaticFunctionTag*, RE::Actor* akActor, std::int32_t fChest, std::int32_t fBack,
                                 std::int32_t fLegacy, std::int32_t fLegacyMale,
                                 std::int32_t fSmall, std::int32_t fMisc, bool glow, bool hasSchlong) {
        if (!g_acquired || !akActor) return;
        bool isFemale = IsFemaleActor(akActor);
        if (!g_overlay->HasOverlays(akActor)) {
            g_overlay->AddOverlays(akActor, false);
        }
        ClearSigil(akActor, isFemale);   // 旧淫紋を掃除します
        const int bt = DetectBodyType(akActor);
        if (bt < 0) return;   // 非人型/専用skin＝ロゴ対象外です
        std::string tex = WithBodySuffix(FixedTexture(fChest, fBack, fLegacy, fLegacyMale, fSmall, fMisc, hasSchlong), bt);
        if (tex.empty()) {
            spdlog::info("[Sigil] ApplyFixed: 選択なし＝掃除のみ");
            return;   // 何も選ばれていません（全部None）＝掃除だけです
        }
        bool hands = IsHandTexture(tex);   // ★手の甲柄は手枠(Hands)へ・それ以外は体枠(Body)です
        int slot = FindEmptySlot(akActor, isFemale, hands);
        if (slot < 0) {
            spdlog::warn("[Sigil] ApplyFixed: 空きオーバーレイ枠なし（hands={}）", hands);
            return;
        }
        ApplyOverlay(akActor, isFemale, hands, slot, tex, glow);
        spdlog::info("[Sigil] ApplyFixed: slot={} hands={} female={} tex={}", slot, hands, isFemale, tex);
    }

    // ---- 💋 1回制限の痕（DrainMark）専用の窓口 ----
    //   股間紋(ウィークネス/手下)と**枠を分ける**のがミソ＝ClearSigilを呼びません／自分の枠だけ触ります。
    //   位置＝男=背中／女・フタ=胸。グロウはNPC淫紋と揃えてON固定です。
    void ApplyDrainMark(RE::Actor* a_npc, float a_frac) {
        if (!g_acquired || !a_npc) return;
        const bool isFemale = IsFemaleActor(a_npc);
        if (!g_overlay->HasOverlays(a_npc)) {
            g_overlay->AddOverlays(a_npc, false);   // 立ちNPCは枠未設置のことがあります
        }
        int slot = FindDrainMarkSlot(a_npc, isFemale);      // 既に痕があるなら同じ枠を貼り替えます
        if (slot < 0) slot = FindEmptySlot(a_npc, isFemale, false);
        if (slot < 0) {
            spdlog::warn("[Sigil] DrainMark: 空きBodyオーバーレイ枠なし {}", reinterpret_cast<void*>(a_npc));
            return;
        }
        const int bt = DetectBodyType(a_npc);
        if (bt < 0) return;   // 非人型＝痕ロゴ対象外です
        const int level = NpcLevelForFrac(a_frac);
        const std::string tex = WithBodySuffix(DrainMarkTexture(isFemale, level), bt);
        ApplyOverlay(a_npc, isFemale, false, slot, tex, true);
        spdlog::info("[Sigil] DrainMark apply: lv={} slot={} female={} tex={}", level, slot, isFemale, tex);
    }

    // 痕の段階だけ更新します（変わった時だけ貼り替え）。戻り=段階(1-6)。痕が見つからなければ貼り直します。
    int UpdateDrainMark(RE::Actor* a_npc, float a_frac) {
        const int level = NpcLevelForFrac(a_frac);
        if (!g_acquired || !a_npc) return level;
        const bool isFemale = IsFemaleActor(a_npc);
        const int slot = FindDrainMarkSlot(a_npc, isFemale);
        if (slot < 0) {
            ApplyDrainMark(a_npc, a_frac);   // 3D再構築等で飛んでいたら貼り直します
            return level;
        }
        const int bt = DetectBodyType(a_npc);
        if (bt < 0) return level;   // 非人型＝更新せず段階だけ返します
        const std::string wantTex = WithBodySuffix(DrainMarkTexture(isFemale, level), bt);
        std::string node = OverlayNode(false, slot);
        GetStr g;
        if (g_override->GetNodeOverride(a_npc, isFemale, node.c_str(), kKeyTexture, kIdxTexture, g) && g.got &&
            g.val != wantTex) {
            SetStr sTex(wantTex.c_str());
            g_override->AddNodeOverride(a_npc, isFemale, node.c_str(), kKeyTexture, kIdxTexture, sTex);
            ApplyAllViews(a_npc);
            if (g_bodyMorph) g_bodyMorph->UpdateModelWeight(a_npc, false);
            spdlog::info("[Sigil] DrainMark step: lv={} slot={} tex={}", level, slot, wantTex);
        }
        return level;
    }

    // 痕だけ消します（股間紋は残します）。
    void ClearDrainMark(RE::Actor* a_npc) {
        if (!g_acquired || !a_npc) return;
        const bool isFemale = IsFemaleActor(a_npc);
        const int slot = FindDrainMarkSlot(a_npc, isFemale);
        if (slot < 0) return;
        ClearSlot(a_npc, isFemale, false, slot);
        spdlog::info("[Sigil] DrainMark clear: slot={} {}", slot, a_npc->GetDisplayFullName());
    }

    // ---- C++からのNPC淫紋 窓口（Papyrusネイティブと同じ実装を呼ぶだけ＝挙動は完全に同一）----
    void ApplyNpcSigil(RE::Actor* a_npc, float a_frac, bool a_hasSchlong) {
        Papyrus_SigilApplyNpc(nullptr, a_npc, a_frac, a_hasSchlong);
    }
    int UpdateNpcSigil(RE::Actor* a_npc, float a_frac, bool a_hasSchlong) {
        return static_cast<int>(Papyrus_SigilUpdateNpc(nullptr, a_npc, a_frac, a_hasSchlong));
    }
    void ClearNpcSigil(RE::Actor* a_npc) {
        Papyrus_SigilClear(nullptr, a_npc);
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("SigilApplyPlayer","ASTR2Native", Papyrus_SigilApplyPlayer);
        vm->RegisterFunction("SigilApplyFixed", "ASTR2Native", Papyrus_SigilApplyFixed);
        vm->RegisterFunction("SigilClear",      "ASTR2Native", Papyrus_SigilClear);
        vm->RegisterFunction("SigilApplyNpc",       "ASTR2Native", Papyrus_SigilApplyNpc);
        vm->RegisterFunction("SigilGetBodyType",    "ASTR2Native", Papyrus_SigilGetBodyType);
        vm->RegisterFunction("SigilResetBodyCache", "ASTR2Native", Papyrus_SigilResetBodyCache);
        vm->RegisterFunction("SigilGetManualBt",    "ASTR2Native", Papyrus_SigilGetManualBt);
        vm->RegisterFunction("SigilSetManualBt",    "ASTR2Native", Papyrus_SigilSetManualBt);
        vm->RegisterFunction("SigilGetEffectiveBt", "ASTR2Native", Papyrus_SigilGetEffectiveBt);
        vm->RegisterFunction("SigilGetActorCategory","ASTR2Native", Papyrus_SigilGetActorCategory);
        vm->RegisterFunction("SigilSetExcluded",    "ASTR2Native", Papyrus_SigilSetExcluded);
        spdlog::info("[Sigil] Papyrus natives (ApplyPlayer/ApplyFixed/Clear/ApplyNpc/GetBodyType/ResetBodyCache/GetManualBt/SetManualBt/GetEffectiveBt/GetActorCategory/SetExcluded) 登録");
        return true;
    }
}
