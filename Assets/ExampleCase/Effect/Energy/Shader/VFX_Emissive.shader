Shader "TechnicalArt/VFX/VFX_Emissive"
{
    Properties
    {
        [HDR]_EmissiveColor("EmissiveColor",Color) = (1,1,1,1)
        _EmissiveIntensity("EmissiveIntensity" , float) = 5
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque"  "Queue" = "Geometry"}
        LOD 100

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
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _EmissiveColor;
                float  _EmissiveIntensity;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                
                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                FinalColor = _EmissiveColor * _EmissiveIntensity;

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
