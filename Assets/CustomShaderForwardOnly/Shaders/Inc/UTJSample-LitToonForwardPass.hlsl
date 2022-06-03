#ifndef UTJSAMPLE_LIT_TOON_FORWARD_PASS_INCLUDED
#define UTJSAMPLE_LIT_TOON_FORWARD_PASS_INCLUDED

// Custom forward pass for forward renderer

// URP includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl" // Required for debug display

// Texture samplers
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);
SAMPLER(sampler_BumpMap);
TEXTURE2D(_EmissionMap);
SAMPLER(sampler_EmissionMap);
TEXTURE2D(_SpecularMap);
SAMPLER(sampler_SpecularMap);
TEXTURE2D(_ToonRampTex);
SAMPLER(sampler_ToonRampTex);

// Properties required for debug display
float4 _BaseMap_TexelSize;
float4 _BaseMap_MipInfo;

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

    // Store fog factor + vertex light (if enabled) in same TEXCOORD8
#if _ADDITIONAL_LIGHTS_VERTEX    
    half4 fogFactorVertexLight  : TEXCOORD8;   // Fog factor (x) + vertex light (yzw)
#else
    half fogFactor              : TEXCOORD8;   // Fog Factor 
#endif

    float4 positionCS           : SV_POSITION; // Clip-space position

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// ====== Lighting functions

// Diffuse
half3 LightingDiffuse(Light light, float3 normalWS, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend)
{
    // Toon ramp
    float NDL = saturate(dot(normalWS, light.direction));
    float2 toonRampUV = float2(NDL, 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;

    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, light.shadowAttenuation);

    half3 diffuseColor = (light.color * light.distanceAttenuation * toonRamp);

    return diffuseColor;
}

// Specular
half3 LightingSpecular(Light light, float3 normalWS, float3 viewDirectionWS, half3 specular, float smoothness, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend)
{
    // Toon ramp
    float3 halfVector = normalize(light.direction + viewDirectionWS);
    float NDH = saturate(dot(normalWS, halfVector));
    float specularFactor = pow(NDH, smoothness);
    float2 toonRampUV = float2(specularFactor, 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;
    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, light.shadowAttenuation);
    half3 specularColor =  light.color * light.distanceAttenuation * specular * toonRamp;

    return specularColor;
}

// ====== Vertex functions

// Vert
Varyings LitToonForwardVert(Attributes input)
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

    // Fog + vertex lighting
    half fogFactor = ComputeFogFactor(positionCS.z);
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLight = 0;
    // Loop through additional lights to get vertex lighting
    int additionalLightCount = GetAdditionalLightsCount();
    for (int lightIndex = 0; lightIndex < additionalLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, positionWS);
        vertexLight += LightingDiffuse(light, normalWS);
    }
    output.fogFactorVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif

    return output;
}

// ====== Fragment functions

// Get lit color
half4 Lighting(InputData inputData, SurfaceData surfaceData, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend)
{
    // Basic BlinnPhong lighting

    float smoothness = exp2(11 * surfaceData.smoothness);

    // NOTE: Light cookies are not implemented in this sample

    // Get light layer if feature is enabled
#if _LIGHT_LAYERS
    uint lightLayer = GetMeshRenderingLightLayer();
#endif

    // Main light
    half3 mainLightDiffuseColor = 0;
    half3 mainLightSpecularColor = 0;
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

#if _LIGHT_LAYERS
    // If light layers are enabled, only process light if renderer's layer is included
    if (IsMatchingLightLayer(mainLight.layerMask, lightLayer)) {
#endif
        // Diffuse
        mainLightDiffuseColor += LightingDiffuse(mainLight, inputData.normalWS, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend) + inputData.vertexLighting;
        // Specular
        mainLightSpecularColor += LightingSpecular(mainLight, inputData.normalWS, inputData.viewDirectionWS, surfaceData.specular, smoothness, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend);

#if _LIGHT_LAYERS
    }
#endif

    // Additional lights (only for per-pixel lights)
    half3 additionalLightsDiffuseColor = 0;
    half3 additionalLightsSpecularColor = 0;
#ifdef _ADDITIONAL_LIGHTS
    // In URP, additional lights are handled in same pass with loop
    int additionalLightCount = GetAdditionalLightsCount();
    for (int lightIndex = 0; lightIndex < additionalLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);

#if _LIGHT_LAYERS
        // If light layers are enabled, only process light if renderer's layer is included
        if (IsMatchingLightLayer(light.layerMask, lightLayer)) {
#endif
        // Diffuse
        additionalLightsDiffuseColor += LightingDiffuse(light, inputData.normalWS, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend) + inputData.vertexLighting;
        // Specular
        additionalLightsSpecularColor += LightingSpecular(light, inputData.normalWS, inputData.viewDirectionWS, surfaceData.specular, smoothness, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend);

#if _LIGHT_LAYERS
        }
#endif
    }
#endif

    // Final color
#ifdef DEBUG_DISPLAY
    // For Rendering Debugger, add colors for features that are enabled
    half3 finalColor = 0;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
    {
        finalColor += mainLightDiffuseColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
    {
        finalColor += additionalLightsDiffuseColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING))
    {
        finalColor += inputData.vertexLighting;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION))
    {
        finalColor += inputData.bakedGI;
    }

    finalColor *= surfaceData.albedo;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_EMISSION))
    {
        finalColor += surfaceData.emission;
    }

    half3 debugSpecularColor = 0;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
    {
        debugSpecularColor += mainLightSpecularColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
    {
        debugSpecularColor += additionalLightsSpecularColor;
    }

    finalColor += debugSpecularColor;
#else
    half3 finalColor = (mainLightDiffuseColor + additionalLightsDiffuseColor + inputData.bakedGI) * surfaceData.albedo + surfaceData.emission;
    finalColor += (mainLightSpecularColor + additionalLightsSpecularColor);
#endif

    return half4(finalColor, surfaceData.alpha);
}

// Frag
half4 LitToonForwardFrag(Varyings input) : SV_Target
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
    inputData.vertexLighting = input.fogFactorVertexLight.yzw; // From fogFactorVertexLight combined variable
#else
    inputData.vertexLighting = 0;
#endif
    // Lightmaps
#ifdef DYNAMICLIGHTMAP_ON
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, normalWS);
#endif
    // For Rendering Debugger
#ifdef DEBUG_DISPLAY
#ifdef DYNAMICLIGHTMAP_ON
    inputData.dynamicLightmapUV = input.dynamicLightmapUV.xy;
#endif
#ifdef LIGHTMAP_ON
    inputData.staticLightmapUV = input.staticLightmapUV;
#else
    inputData.vertexSH = input.vertexSH;
#endif
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
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

#ifdef DEBUG_DISPLAY
    // Stop here and return debug display color Rendering Debugger is enabled with modes that can override

    // Manually handle DEBUGLIGHTINGMODE_LIGHTING_WITHOUT_NORMAL_MAPS and DEBUGLIGHTINGMODE_REFLECTIONS

    // These two modes internally depend upon a local _NORMALMAP keyword being defined
    // Default URP shaders enable/disable _NORMALMAP in the ShaderGUI (BaseShaderGUI.cs)
    // Since this sample does not include a ShaderGUI, we must handle these modes manually

    // Ignore normal map values for normals when DEBUGLIGHTINGMODE_LIGHTING_WITHOUT_NORMAL_MAPS or DEBUGLIGHTINGMODE_REFLECTIONS is enabled
    if (_DebugLightingMode == DEBUGLIGHTINGMODE_LIGHTING_WITHOUT_NORMAL_MAPS || _DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTIONS) {
        inputData.normalWS = normalize(input.normalWS);
    }

    half4 debugColor;
    if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    {
        return debugColor;
    }
#endif

    // Lighting
    color = Lighting(inputData, surfaceData, TEXTURE2D_ARGS(_ToonRampTex, sampler_ToonRampTex), _ShadowRampBlend);

    // Mix fog
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color.rgb = MixFog(color.rgb, input.fogFactorVertexLight.x); // From fogFactorVertexLight combined variable
#else
    color.rgb = MixFog(color.rgb, input.fogFactor);
#endif

    return color;
}

#endif
