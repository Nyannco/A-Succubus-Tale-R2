#include "PCH.h"

// fork版CommonLib(commonlibsse-ng-fork)が宣言のみ残し実体を削除した
//   TESObjectREFR::InstantiateHitShader を補完します（非forkには実装あり＝fork移行で欠落）。
// アドレス＝RELOCATION_ID(19446, 19872)（非fork CommonLibSSE-NG TESObjectREFR.cpp 由来）。
//   EssenceFlow/Fury の覚醒もや生成（ヒットシェーダー常時ON）が使います。
namespace RE
{
    ShaderReferenceEffect* TESObjectREFR::InstantiateHitShader(TESEffectShader* a_shader, float a_dur, TESObjectREFR* a_facingRef, bool a_faceTarget, bool a_attachToCamera, NiAVObject* a_attachNode, bool a_interfaceEffect)
    {
        using func_t = decltype(&TESObjectREFR::InstantiateHitShader);
        REL::Relocation<func_t> func{ RELOCATION_ID(19446, 19872) };
        return func(this, a_shader, a_dur, a_facingRef, a_faceTarget, a_attachToCamera, a_attachNode, a_interfaceEffect);
    }
}
