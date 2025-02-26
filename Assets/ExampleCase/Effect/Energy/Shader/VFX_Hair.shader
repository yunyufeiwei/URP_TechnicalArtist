Shader "Art_URP/Character/VFX_Emissive"
{
    Properties
    {   
        _BaseColor("BaseColor0" , 2D) = "white"{}
        _Mask("Mask" , 2D) = "white"{}
        [HDR]_EmissiveColor("EmissiveColor",Color) = (1,1,1,1)
        _EmissiveIntensity("EmissiveIntensity" , float) = 5
        _ClipValue("ClipValue" , Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "AlphaTest"  "Queue" = "Geometry"}
        Cull off

        pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
            };

            TEXTURE2D(_BaseColor);SAMPLER(sampler_BaseColor);
            TEXTURE2D(_Mask);SAMPLER(sampler_Mask);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor_ST;
                float4 _Mask_ST;
                float4 _EmissiveColor;
                float  _EmissiveIntensity;
                float  _ClipValue;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

                o.uv = TRANSFORM_TEX(v.texcoord , _BaseColor);
                
                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                half4 baseMap = SAMPLE_TEXTURE2D(_BaseColor , sampler_BaseColor , i.uv);
                half4 maskMap = SAMPLE_TEXTURE2D(_Mask , sampler_Mask , i.uv);

                clip(maskMap.r - _ClipValue);

                FinalColor = _EmissiveColor * _EmissiveIntensity;

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
