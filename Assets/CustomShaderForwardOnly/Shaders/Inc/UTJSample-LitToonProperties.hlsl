#ifndef UTJSAMPLE_LIT_TOON_PROPERTIES_INCLUDED
#define UTJSAMPLE_LIT_TOON_PROPERTIES_INCLUDED

// Uniform properties, put in UnityPerMaterial cbuffer for SRP compatibility
CBUFFER_START(UnityPerMaterial)
    half4 _BaseColor;
    float4 _BaseMap_ST;
    float _BumpScale;
    half3 _EmissionColor;
    half4 _SpecularColor;
    float _ShadowRampBlend;
    half3 _OutlineColor;
    float _OutlineThickness;

    // Properties required by URP ShadowCasterPass.hlsl
    half _Cutoff;
CBUFFER_END

#endif
