#ifndef UTJSAMPLE_LIT_GBUFFER_PASS_INCLUDED
#define UTJSAMPLE_LIT_GBUFFER_PASS_INCLUDED

// Custom GBuffer pass for deferred renderer

// URP includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

// Texture samplers
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);
SAMPLER(sampler_BumpMap);
TEXTURE2D(_EmissionMap);
SAMPLER(sampler_EmissionMap);
TEXTURE2D(_SpecularMap);
SAMPLER(sampler_SpecularMap);

// Attributes
struct Attributes
{
    float2 uv                   : TEXCOORD0;
    float4 positionOS           : POSITION;  // Object-space position
    float3 normalOS             : NORMAL;    // Object-space normal
    float4 tangentOS            : TANGENT;   // Object-space tangent
    float2 staticLightmapUV     : TEXCOORD1; // Lightmap UV (static)
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV    : TEXCOORD2; // Lightmap UV (dynamic)
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Varyings
struct Varyings
{
    float2 uv                   : TEXCOORD0;

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 1);  // GI (lightmap or ambient light)

    float3 positionWS           : TEXCOORD2;   // World-space position
    half3 normalWS              : TEXCOORD3;   // World-space normal
    half3 tangentWS             : TEXCOORD4;   // World-space tangent
    half3 bitangentWS           : TEXCOORD5;   // World-space bitangent

#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    float4 shadowCoord          : TEXCOORD6;   // Vertex shadow coords if required
#endif
                
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV    : TEXCOORD7;   // Dynamic lightmap UVs
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLight           : TEXCOORD8;   // Vertex light
#endif

    float4 positionCS           : SV_POSITION; // Clip-space position

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// ====== Vertex functions

// Vert
Varyings LitGBufferVert(Attributes input)
{
    Varyings output;

    // GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    // Stereo
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // Transformations
    // See Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl for helper functions
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    float4 positionCS = positionInputs.positionCS;
    float3 positionWS = positionInputs.positionWS;
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
    float3 normalWS = normalInputs.normalWS;
    float3 tangentWS = normalInputs.tangentWS;
    float3 bitangentWS = normalInputs.bitangentWS;

    // Set output
    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    OUTPUT_SH(normalWS, output.vertexSH);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.positionCS = positionCS;
    output.positionWS = positionWS;
    output.normalWS = normalWS;
    output.tangentWS = tangentWS;
    output.bitangentWS = bitangentWS;
#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    // Vertex shadow coords if required
    output.shadowCoord = TransformWorldToShadowCoord(positionWS);
#endif
#ifdef DYNAMICLIGHTMAP_ON
    // Dynamic lightmap
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

    // Vertex lighting
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLight = 0;
    // Loop through additional lights to get vertex lighting
    int additionalLightCount = GetAdditionalLightsCount();
    for (int lightIndex = 0; lightIndex < additionalLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, positionWS);
        vertexLight += LightingDiffuse(light, normalWS);
    }
    output.vertexLight = vertexLight;
#endif

    return output;
}

// ====== Fragment functions

/*  Generate GBuffer output
GBuffer output (FragmentOutput) is defined as follows in UnityGBuffer.hlsl

Required
- GBuffer0 : SV_Target0
  RGB: Albedo
  A: MaterialFlags bitmask
    1: kMaterialFlagReceiveShadowsOff           : No receive shadows
    2: kMaterialFlagSpecularHighlightsOff       : No specular highlights
    4: kMaterialFlagSubtractiveMixedLighting    : Set if using subtractive mixed lighting (in Lighting settings)
    8: kMaterialFlagSpecularSetup               : Use specular workflow　(if UniversalMaterialType = Lit)

- GBuffer1 : SV_Target1
  RGB: Specular color
  A: Occlusion

- GBuffer2 : SV_Target2
  RGB: World space normals
  A: Smoothness

- GBuffer3 : SV_Target3
  RGB: GI + Emission
  A: 1

Optional (Order depends on flags; see UnityGBuffer.hlsl for details)
- GBUFFER_SHADOWMASK
  RGBA: Shadow mask if enabled

- GBUFFER_LIGHT_LAYERS
  RGBA: Light layer if enabled

- GBUFFER_OPTIONAL_SLOT_1
  RGBA: Store depth as color if Native Render Pass is enabled

See https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@12.1/manual/rendering/deferred-rendering-path.html#g-buffer-layout
for the GBuffer output data layout */
FragmentOutput GBuffer(InputData inputData, SurfaceData surfaceData)
{
    FragmentOutput output;

    // Material flags
    uint materialFlags = 0;
    #if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    materialFlags |= kMaterialFlagSubtractiveMixedLighting;  // For subtractive mixed lighting
    #endif
    // We do not set kMaterialFlagReceiveShadowsOff, kMaterialFlagSpecularHighlightsOff
    // as this sample always has shadows and specular highlights enabled
    float materialFlagsPacked = PackMaterialFlags(materialFlags);

    // Normals
    float3 normalWS = PackNormal(inputData.normalWS);

    // GI + Emission
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
    half3 giEmission = (inputData.bakedGI * surfaceData.albedo) + surfaceData.emission;

    // GBuffer0
    output.GBuffer0.rgb = surfaceData.albedo;  // Albedo
    output.GBuffer0.a = materialFlagsPacked;   // Material flags

    // GBuffer1
    output.GBuffer1.rgb = surfaceData.specular;  // Specular color
    output.GBuffer1.a = 0;                       // Occlusion (occlusion not included in this sample)

    // GBuffer2
    output.GBuffer2.rgb = normalWS;              // World space normals
    output.GBuffer2.a = surfaceData.smoothness;  // Smoothness

    // GBuffer3
    output.GBuffer3.rgb = giEmission;  // GI + Emission
    output.GBuffer3.a = 1;

    // GBUFFER_SHADOWMASK (shadow mask)
    #if OUTPUT_SHADOWMASK
    output.GBUFFER_SHADOWMASK = inputData.shadowMask;
    #endif

    // GBUFFER_LIGHT_LAYERS (light layer)
    #ifdef _LIGHT_LAYERS
    uint lightLayer = GetMeshRenderingLightLayer();
    output.GBUFFER_LIGHT_LAYERS = float4((lightLayer & 0x000000FF) / 255.0, 0.0, 0.0, 0.0);
    #endif

    // GBUFFER_OPTIONAL_SLOT_1 (depth as color if Native Render Pass is enabled)
    #if _RENDER_PASS_ENABLED
    output.GBUFFER_OPTIONAL_SLOT_1 = inputData.positionCS.z;
    #endif

    return output;
}

// Frag
FragmentOutput LitGBufferFrag(Varyings input)
{
    // Instancing
    UNITY_SETUP_INSTANCE_ID(input);
    // Stereo
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 color;

    float2 uv = input.uv;

    // Helper functions to sample base map, normal map, emission, specular can also be found in
    // Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl

    // Sample base map + color
    half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    color = baseMap * _BaseColor;
               
    // Sample normal map
#if BUMP_SCALE_NOT_SUPPORTED
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv));
#else
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv), _BumpScale);
#endif
    half3 normalWS = normalize(mul(normalTS, float3x3(input.tangentWS, input.bitangentWS, input.normalWS)));

    // Sample emission map
    half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor;

    // Sample specular map
    half4 specular = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, uv) * _SpecularColor;

    // Shadow coord
#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    // Use vertex shadow coords if required
    float4 shadowCoord = input.shadowCoord;
#elif defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN)
    // Otherwise, get per-pixel shadow coords
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    float4 shadowCoord = 0;
#endif

    // Basic lighting
    // Built-in lighting functions can be found in Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    // Construct InputData struct
    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = normalize(GetWorldSpaceViewDir(input.positionWS));
    inputData.shadowCoord = shadowCoord;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    // Vertex lighting
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.vertexLighting = input.vertexLight;
#else
    inputData.vertexLighting = 0;
#endif
    // Lightmaps
#ifdef DYNAMICLIGHTMAP_ON
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, normalWS);
#endif
                
    // Construct SurfaceData struct
    SurfaceData surfaceData = (SurfaceData)0;
    surfaceData.albedo = color.rgb;
    surfaceData.alpha = color.a;
    surfaceData.emission = emission;
    surfaceData.metallic = 0;
    surfaceData.occlusion = 1;
    surfaceData.smoothness = specular.a;
    surfaceData.specular = specular.rgb;
    surfaceData.normalTS = normalTS;

    FragmentOutput output = GBuffer(inputData, surfaceData);

    return output;
}

#endif
