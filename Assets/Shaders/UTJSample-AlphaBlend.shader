Shader "UTJSample/AlphaBlend"
{
    // Blend camera color texture and UI texture

    SubShader
    {
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            struct Attributes
            {
                float2 uv : TEXCOORD0;
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_CameraColorTexture);
            SAMPLER(sampler_CameraColorTexture);
            
            TEXTURE2D(_UITexture);
            SAMPLER(sampler_UITexture);
           
            Varyings vert (Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                half4 cameraTex = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, input.uv);
                half4 uiTex = SAMPLE_TEXTURE2D(_UITexture, sampler_UITexture, input.uv);

                // Convert camera texture to sRGB before blend
                cameraTex.rgb = FastLinearToSRGB(cameraTex.rgb);

                half4 color;

                // Blend with UI
                color.rgb = cameraTex.rgb * (1 - uiTex.a) + uiTex.rgb;
                
                // Convert result to Linear
                color.rgb = FastSRGBToLinear(color.rgb);
                color.a = 1;

                return color;
            }
            ENDHLSL
        }
    }
}
