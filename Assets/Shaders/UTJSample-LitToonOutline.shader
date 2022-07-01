Shader "UTJSample/LitToonOutline"
{
    Properties
    {
        // Main Texture, color
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        // Normal map
        _BumpScale("Normal Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        // Specular map
        [HDR] _SpecularColor("Specular Color (RGB: Color, A: Smoothness)", Color) = (1, 1, 1, 1)
        _SpecularMap("Specular Map", 2D) = "white" {}

        // Emission map
        [HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0)
        _EmissionMap("Emission Map", 2D) = "white" {}

        // Toon ramp texture
        _ToonRampTex("Toon Ramp Tex", 2D) = "white" {}

        // Shadow ramp
        _ShadowRampBlend("Shadow Ramp Blend", Range(0, 0.5)) = 0.2

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

        // Forward pass
        Pass
        {
            Name "Forward"
            // UniversalForwardOnly will allow forward pass to be used
            // even when deferred rendering is active
            Tags { "LightMode" = "UniversalForwardOnly" }

            // Opaque shader for sample purposes; no blending
            Blend Off
            ZWrite On
            Cull Back
            ZTest LEqual

            HLSLPROGRAM

            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions
            #pragma vertex LitToonForwardVert
            #pragma fragment LitToonForwardFrag

            // Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN // Main light shadows
            #pragma multi_compile _ SHADOWS_SHADOWMASK                  // Shadow mask
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS // Additional light support (includes vertex lighting option)
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS  // Additional light shadow support
            #pragma multi_compile_fragment _ _SHADOWS_SOFT              // Soft shadow support
            #pragma multi_compile_fragment _ _LIGHT_LAYERS              // Light Layer support
            // For lightmaps if enabled
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED                       
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            // For Rendering Debugger if enabled
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog

            // URP core include
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Custom LitToonForward pass
            #include "Inc/UTJSample-LitToonForwardPass.hlsl"

            ENDHLSL
        }

        // Outline pass, using SRPDefaultUnlit as extra pass
        // NOTE: Using SRPDefaultUnlit will count as a multi-pass shader,
        //       which will break SRP Batcher compatibility
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Blend Off
            Cull Front

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

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Outline pass
            #include "Inc/UTJSample-LitToonOutlinePass.hlsl"

            ENDHLSL
        }

        // Shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM

            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions used by ShadowCasterPass.hlsl
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // Keywords
            // Required by URP ShadowCasterPass.hlsl (used for normal bias differentiation)
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // GPU Instancing
            #pragma multi_compile_instancing

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Required by URP ShadowCasterPass.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Properties required by URP ShadowCasterPass.hlsl
            // NOTE: This shader does not support alpha cutout, but URP's pass
            //       requires this property, so we must define it
            //       This property should be exposed in Properties block and
            //       included in a CBUFFER if your shader supports alpha cutout functionality
            half _Cutoff;

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }

        // DepthOnly pass
        // Used to render to _CameraDepthTexture
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            Cull Back

            HLSLPROGRAM
            
            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions used in URP's DepthOnlyPass
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // GPU Instancing
            #pragma multi_compile_instancing

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Required by URP DepthOnlyPass.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Properties required by URP DepthOnlyPass.hlsl
            // NOTE: This shader does not support alpha cutout, but URP's pass
            //       requires this property, so we must define it
            //       This property should be exposed in Properties block and
            //       included in a CBUFFER if your shader supports alpha cutout functionality
            half _Cutoff;

            // Use URP's built in DepthOnly pass
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            ENDHLSL
        }

        // DepthNormalsOnly pass
        // Used to render to _CameraNormalsTexture
        // Use this instead of DepthNormals for ForwardOnly materials
        Pass
        {
            Name "DepthNormalsOnly"
            Tags{"LightMode" = "DepthNormalsOnly"}

            ZWrite On
            Cull Back

            HLSLPROGRAM

            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions used in URP's DepthNormalsPass
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // Keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT // Used in DepthNormalsOnly pass

            // GPU Instancing
            #pragma multi_compile_instancing

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Required by URP DepthNormalsPass.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Properties required by URP DepthNormalsPass.hlsl
            // NOTE: This shader does not support alpha cutout, but URP's pass
            //       requires this property, so we must define it
            //       This property should be exposed in Properties block and
            //       included in a CBUFFER if your shader supports alpha cutout functionality
            half _Cutoff;

            // Use URP's built in DepthNormals pass
            // NOTE: This pass does not sample normal maps
            //       You can write your own to include normal maps (see SimpleLitDepthNormalsPass.hlsl for reference)
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"

            ENDHLSL
        }

        // Meta pass for light maps
        Pass
        {
            Name "Meta"
            Tags{ "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM

            // Exclude unsupported platforms
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // Vertex/fragment functions
            #pragma vertex LitMetaVert
            #pragma fragment LitMetaFrag

            // Keywords
            // For editor visualization
            #pragma shader_feature EDITOR_VISUALIZATION

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/MetaPass.hlsl"

            // Common properties
            #include "Inc/UTJSample-LitToonOutlineProperties.hlsl"

            // Custom LitMeta pass (adds emission)
            #include "Inc/UTJSample-LitMetaPass.hlsl"

            ENDHLSL
        }
    }
}