#pragma once
// ============================================================================
// SKEE (RaceMenu / NiOverride) の C++ モッダー窓口です ― CommonLibSSE-NG 向けラッパ。
// ASTR2専門用語（〔 〕で囲った語）の説明は scripts/GLOSSARY.psc を参照してください。
//   出典: 「RaceMenu Anniversary Edition\ModderResource\IPluginInterface.h」
//   ★namespace SKEE で包み、前方宣言を RE 型のエイリアスへ差し替えます。PCH.h(RE が可視) の後に include します。
//   ★各インターフェースは全メソッドを"元の順序どおり"宣言します＝vtable オフセットを SKEE 本体と一致させるため
//     （途中を省くと AddNodeOverride 等の呼び先がズレて即CTD）。使う予定が無いメソッドも消しません。
// ============================================================================
#include <cstdint>

namespace SKEE
{
    using TESObjectREFR = RE::TESObjectREFR;
    using NiAVObject    = RE::NiAVObject;
    using TESObjectARMO = RE::TESObjectARMO;
    using TESObjectARMA = RE::TESObjectARMA;
    using BGSTextureSet = RE::BGSTextureSet;

    using skee_u64 = std::uint64_t;
    using skee_u32 = std::uint32_t;
    using skee_i32 = std::int32_t;
    using skee_u16 = std::uint16_t;
    using skee_u8  = std::uint8_t;

    // 全 SKEE インターフェースの基底。QueryInterface はこの型で返ります。
    class IPluginInterface
    {
    public:
        IPluginInterface() {}
        virtual ~IPluginInterface() {}

        virtual skee_u32 GetVersion() = 0;
        virtual void     Revert()     = 0;
    };

    class IInterfaceMap
    {
    public:
        virtual IPluginInterface* QueryInterface(const char* name) = 0;
        virtual bool              AddInterface(const char* name, IPluginInterface* pluginInterface) = 0;
        virtual IPluginInterface* RemoveInterface(const char* name) = 0;
    };

    struct InterfaceExchangeMessage
    {
        enum
        {
            kMessage_ExchangeInterface = 0x9E3779B9
        };
        IInterfaceMap* interfaceMap = nullptr;
    };

    // ------------------------------------------------------------------------
    // IBodyMorphInterface ― UpdateModelWeight(3D再構築/オーバーレイ再適用) を使います。
    // ------------------------------------------------------------------------
    class IBodyMorphInterface : public IPluginInterface
    {
    public:
        enum
        {
            kCurrentPluginVersion = 4,
            kSerializationVersion = 3
        };
        class MorphKeyVisitor   { public: virtual void Visit(const char*, float) = 0; };
        class StringVisitor     { public: virtual void Visit(const char*) = 0; };
        class ActorVisitor      { public: virtual void Visit(TESObjectREFR*) = 0; };
        class MorphValueVisitor { public: virtual void Visit(TESObjectREFR*, const char*, const char*, float) = 0; };
        class MorphVisitor      { public: virtual void Visit(TESObjectREFR*, const char*) = 0; };

        virtual void  SetMorph(TESObjectREFR* actor, const char* morphName, const char* morphKey, float relative) = 0;
        virtual float GetMorph(TESObjectREFR* actor, const char* morphName, const char* morphKey) = 0;
        virtual void  ClearMorph(TESObjectREFR* actor, const char* morphName, const char* morphKey) = 0;

        virtual float GetBodyMorphs(TESObjectREFR* actor, const char* morphName) = 0;
        virtual void  ClearBodyMorphNames(TESObjectREFR* actor, const char* morphName) = 0;

        virtual void  VisitMorphs(TESObjectREFR* actor, MorphVisitor& visitor) = 0;
        virtual void  VisitKeys(TESObjectREFR* actor, const char* name, MorphKeyVisitor& visitor) = 0;
        virtual void  VisitMorphValues(TESObjectREFR* actor, MorphValueVisitor& visitor) = 0;

        virtual void  ClearMorphs(TESObjectREFR* actor) = 0;

        virtual void  ApplyVertexDiff(TESObjectREFR* refr, NiAVObject* rootNode, bool erase = false) = 0;

        virtual void  ApplyBodyMorphs(TESObjectREFR* refr, bool deferUpdate = true) = 0;
        virtual void  UpdateModelWeight(TESObjectREFR* refr, bool immediate = false) = 0;

        virtual void      SetCacheLimit(skee_u64 limit) = 0;
        virtual bool      HasMorphs(TESObjectREFR* actor) = 0;
        virtual skee_u32  EvaluateBodyMorphs(TESObjectREFR* actor) = 0;

        virtual bool      HasBodyMorph(TESObjectREFR* actor, const char* morphName, const char* morphKey) = 0;
        virtual bool      HasBodyMorphName(TESObjectREFR* actor, const char* morphName) = 0;
        virtual bool      HasBodyMorphKey(TESObjectREFR* actor, const char* morphKey) = 0;
        virtual void      ClearBodyMorphKeys(TESObjectREFR* actor, const char* morphKey) = 0;
        virtual void      VisitStrings(StringVisitor& visitor) = 0;
        virtual void      VisitActors(ActorVisitor& visitor) = 0;
        virtual skee_u64  ClearMorphCache() = 0;
    };

    // ------------------------------------------------------------------------
    // IOverlayInterface ― オーバーレイ枠の有無/追加/枚数。
    // ------------------------------------------------------------------------
    class IOverlayInterface : public IPluginInterface
    {
    public:
        enum
        {
            kCurrentPluginVersion = 2,
            kSerializationVersion = 1
        };
        virtual bool HasOverlays(TESObjectREFR* reference) = 0;
        virtual void AddOverlays(TESObjectREFR* reference, bool defer = true) = 0;
        virtual void RemoveOverlays(TESObjectREFR* reference, bool defer = true) = 0;
        virtual void RevertOverlays(TESObjectREFR* reference, bool resetDiffuse, bool defer = true) = 0;
        virtual void RevertOverlay(TESObjectREFR* reference, const char* nodeName, skee_u32 armorMask, skee_u32 addonMask, bool resetDiffuse, bool defer = true) = 0;
        virtual void EraseOverlays(TESObjectREFR* reference, bool defer = true) = 0;
        virtual void RevertHeadOverlays(TESObjectREFR* reference, bool resetDiffuse, bool defer = true) = 0;
        virtual void RevertHeadOverlay(TESObjectREFR* reference, const char* nodeName, skee_u32 partType, skee_u32 shaderType, bool resetDiffuse, bool defer = true) = 0;

        enum class OverlayType { Normal, Spell };
        enum class OverlayLocation { Body, Hand, Feet, Face };
        virtual skee_u32    GetOverlayCount(OverlayType type, OverlayLocation location) = 0;
        virtual const char* GetOverlayFormat(OverlayType type, OverlayLocation location) = 0;

        using OverlayInstallCallback = void (*)(TESObjectREFR* ref, NiAVObject* node);
        virtual bool RegisterInstallCallback(const char* key, OverlayInstallCallback cb) = 0;
        virtual bool UnregisterInstallCallback(const char* key) = 0;
    };

    // ------------------------------------------------------------------------
    // IOverrideInterface ― ノードオーバーライド(=淫紋テクスチャ/色/グロウ)の本命。
    //   AddNodeOverride / GetNodeOverride / RemoveNodeOverride / ApplyNodeOverrides を使います。
    // ------------------------------------------------------------------------
    class IOverrideInterface : public IPluginInterface
    {
    public:
        enum
        {
            kCurrentPluginVersion = 2,
            kSerializationVersion = 3
        };

        // 現在値を読む時の受け皿（GetNodeOverride が該当型の Visit を呼びます）。
        class GetVariant
        {
        public:
            virtual void Int(const skee_i32 i) = 0;
            virtual void Float(const float f) = 0;
            virtual void String(const char* str) = 0;
            virtual void Bool(const bool b) = 0;
            virtual void TextureSet(const BGSTextureSet* textureSet) = 0;
        };

        // 値を設定する時に渡します（GetType() で型を宣言し、該当ゲッターで値を返します）。
        class SetVariant
        {
        public:
            enum class Type { None, Int, Float, String, Bool, TextureSet };
            virtual Type           GetType() { return Type::None; }
            virtual skee_i32       Int()     { return 0; }
            virtual float          Float()   { return 0.0f; }
            virtual const char*    String()  { return nullptr; }
            virtual bool           Bool()    { return false; }
            virtual BGSTextureSet* TextureSet() { return nullptr; }
        };

        virtual bool HasArmorAddonNode(TESObjectREFR* refr, bool firstPerson, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, bool debug) = 0;

        virtual bool HasArmorOverride(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index) = 0;
        virtual void AddArmorOverride(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index, SetVariant& value) = 0;
        virtual bool GetArmorOverride(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index, GetVariant& visitor) = 0;
        virtual void RemoveArmorOverride(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index) = 0;
        virtual void SetArmorProperties(TESObjectREFR* refr, bool immediate) = 0;
        virtual void SetArmorProperty(TESObjectREFR* refr, bool firstPerson, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index, SetVariant& value, bool immediate) = 0;
        virtual bool GetArmorProperty(TESObjectREFR* refr, bool firstPerson, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName, skee_u16 key, skee_u8 index, GetVariant& value) = 0;
        virtual void ApplyArmorOverrides(TESObjectREFR* refr, TESObjectARMO* armor, TESObjectARMA* addon, NiAVObject* object, bool immediate) = 0;
        virtual void RemoveAllArmorOverrides() = 0;
        virtual void RemoveAllArmorOverridesByReference(TESObjectREFR* reference) = 0;
        virtual void RemoveAllArmorOverridesByArmor(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor) = 0;
        virtual void RemoveAllArmorOverridesByAddon(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon) = 0;
        virtual void RemoveAllArmorOverridesByNode(TESObjectREFR* refr, bool isFemale, TESObjectARMO* armor, TESObjectARMA* addon, const char* nodeName) = 0;

        virtual bool HasNodeOverride(TESObjectREFR* refr, bool isFemale, const char* nodeName, skee_u16 key, skee_u8 index) = 0;
        virtual void AddNodeOverride(TESObjectREFR* refr, bool isFemale, const char* nodeName, skee_u16 key, skee_u8 index, SetVariant& value) = 0;
        virtual bool GetNodeOverride(TESObjectREFR* refr, bool isFemale, const char* nodeName, skee_u16 key, skee_u8 index, GetVariant& visitor) = 0;
        virtual void RemoveNodeOverride(TESObjectREFR* refr, bool isFemale, const char* nodeName, skee_u16 key, skee_u8 index) = 0;
        virtual void SetNodeProperties(TESObjectREFR* refr, bool immediate) = 0;
        virtual void SetNodeProperty(TESObjectREFR* refr, bool firstPerson, const char* nodeName, skee_u16 key, skee_u8 index, SetVariant& value, bool immediate) = 0;
        virtual bool GetNodeProperty(TESObjectREFR* refr, bool firstPerson, const char* nodeName, skee_u16 key, skee_u8 index, GetVariant& value) = 0;
        virtual void ApplyNodeOverrides(TESObjectREFR* refr, NiAVObject* object, bool immediate) = 0;
        virtual void RemoveAllNodeOverrides() = 0;
        virtual void RemoveAllNodeOverridesByReference(TESObjectREFR* reference) = 0;
        virtual void RemoveAllNodeOverridesByNode(TESObjectREFR* refr, bool isFemale, const char* nodeName) = 0;

        virtual bool HasSkinOverride(TESObjectREFR* refr, bool isFemale, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index) = 0;
        virtual void AddSkinOverride(TESObjectREFR* refr, bool isFemale, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index, SetVariant& value) = 0;
        virtual bool GetSkinOverride(TESObjectREFR* refr, bool isFemale, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index, GetVariant& visitor) = 0;
        virtual void RemoveSkinOverride(TESObjectREFR* refr, bool isFemale, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index) = 0;
        virtual void SetSkinProperties(TESObjectREFR* refr, bool immediate) = 0;
        virtual void SetSkinProperty(TESObjectREFR* refr, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index, SetVariant& value, bool immediate) = 0;
        virtual bool GetSkinProperty(TESObjectREFR* refr, bool firstPerson, skee_u32 slotMask, skee_u16 key, skee_u8 index, GetVariant& value) = 0;
        virtual void ApplySkinOverrides(TESObjectREFR* refr, bool firstPerson, TESObjectARMO* armor, TESObjectARMA* addon, skee_u32 slotMask, NiAVObject* object, bool immediate) = 0;
        virtual void RemoveAllSkinOverrides() = 0;
        virtual void RemoveAllSkinOverridesByReference(TESObjectREFR* reference) = 0;
        virtual void RemoveAllSkinOverridesBySlot(TESObjectREFR* refr, bool isFemale, bool firstPerson, skee_u32 slotMask) = 0;
    };
}
