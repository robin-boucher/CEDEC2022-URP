#ifndef UTJSAMPLE_LIT_TOON_OUTLINE_PASS_INCLUDED
#define UTJSAMPLE_LIT_TOON_OUTLINE_PASS_INCLUDED

// Outline pass

// Attributes
struct Attributes
{
    float4 positionOS           : POSITION;  // Object-space position
    float3 normalOS             : NORMAL;    // Object-space normal

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Varyings
struct Varyings
{
    half fogFactor              : TEXCOORD0;   // Fog Factor 
    float4 positionCS           : SV_POSITION; // Clip-space position

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// Vertex function
Varyings LitToonOutlineVert(Attributes input)
{
    Varyings output;

    // GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    // Stereo
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // Transformations
    // See Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl for individual transformation functions
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float3 normalCS = TransformWorldToHClipDir(normalWS);
    float4 positionCS = TransformObjectToHClip(input.positionOS.xyz);

    // Apply normal-based outline (expand vertex in normal direction)
    half2 outlineNormal = normalize(normalCS.xy);
    positionCS.xy += (outlineNormal / _ScreenParams.xy) * _OutlineThickness * positionCS.w * 2;

    // Set output
    output.positionCS = positionCS;
    output.fogFactor = ComputeFogFactor(positionCS.z);;

    return output;
}

// Fragment function
half4 LitToonOutlineFrag(Varyings input) : SV_Target
{
    // Instancing
    UNITY_SETUP_INSTANCE_ID(input);
    // Stereo
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 color = half4(_OutlineColor, 1);

    // Mix fog
    color.rgb = MixFog(color.rgb, input.fogFactor);

    return color;
}

#endif
