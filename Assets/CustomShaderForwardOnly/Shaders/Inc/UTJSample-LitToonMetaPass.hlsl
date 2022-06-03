#ifndef UTJSAMPLE_LIT_TOON_META_PASS_INCLUDED
#define UTJSAMPLE_LIT_TOON_META_PASS_INCLUDED

// Custom meta pass which also handles emission

// URP includes (base meta pass functions)
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/MetaPass.hlsl"

// Texture samplers
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_EmissionMap);
SAMPLER(sampler_EmissionMap);

struct Attributes
{
    float4 positionOS   : POSITION;   // Object-space position
    float3 normalOS     : NORMAL;     // Object-space normal
    float2 uv0          : TEXCOORD0;
    float2 uv1          : TEXCOORD1;
    float2 uv2          : TEXCOORD2;
};

struct Varyings
{
    float4 positionCS       : SV_POSITION;  // Clip-space position
    float2 uv               : TEXCOORD0;
    // For editor visualization
#ifdef EDITOR_VISUALIZATION
    float2 visualizationUV  : TEXCOORD1;
    float4 lightCoord       : TEXCOORD2;
#endif
};

// Vertex function
Varyings LitToonMetaVert(Attributes input)
{
    Varyings output;

    // Set output using built-in meta pass functions
    output.positionCS = UnityMetaVertexPosition(input.positionOS.xyz, input.uv1, input.uv2);
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
#ifdef EDITOR_VISUALIZATION
    UnityEditorVizData(input.positionOS.xyz, input.uv0, input.uv1, input.uv2, output.visualizationUV, output.lightCoord);
#endif
    return output;
}

// Fragment function
half4 LitToonMetaFrag(Varyings input) : SV_Target
{
    half4 color;

    float2 uv = input.uv;

    // Construct MetaInput data
    UnityMetaInput metaInput;
    // Albedo (base color)
    metaInput.Albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb * _BaseColor.rgb;
    // Emission
    metaInput.Emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor;

#ifdef EDITOR_VISUALIZATION
    // For editor visualization
    metaInput.VizUV = input.visualizationUV;
    metaInput.LightCoord = input.lightCoord;
#endif

    // Final color (built-in meta pass)
    color = UnityMetaFragment(metaInput);

    return color;
}

#endif