Shader "UTJSample/OutlineStencil"
{
    Properties
    {
        // Outline
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineThickness("Outline Thickness", Float) = 1
    }

    // SM 4.5 subshader
    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
            "ShaderModel"="4.5"
        }
        LOD 200

        // Outline pass
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Cull Front

            // Stencil operation (masked by model)
            Stencil 
            {
                Ref 1
                Comp Greater
            }

            HLSLPROGRAM

            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions
            #pragma vertex LitToonOutlineVert
            #pragma fragment LitToonOutlineFrag

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog

            // URP core include
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Uniform properties, put in UnityPerMaterial cbuffer for SRP compatibility
            CBUFFER_START(UnityPerMaterial)
                half3 _OutlineColor;
                float _OutlineThickness;
            CBUFFER_END

            // Outline pass
            #include "Inc/UTJSample-LitToonOutlinePass.hlsl"

            ENDHLSL
        }
    }
}