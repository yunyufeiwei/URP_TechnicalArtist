Shader "TechnicalArt/Goblet"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]_DstFactor("DstFactor",int) = 0
        
        [Header(Matcap)]
        _MatCap("MatCap" , 2D) = "blcak"{}
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent"  "Queue" = "Transparent"}
        LOD 100
        Blend [_SrcFactor][_DstFactor]
        ZWrite Off
        ZTest On
        Cull Back

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD;
                float3 normalOS     : NORMAL;
                float4 color        : COLOR;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 viewWS       : TEXCOORD3;
                float4 color        : TEXCOORD4;
            };

            TEXTURE2D(_MatCap);SAMPLER(sampler_MatCap);

            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o=(Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.viewWS = GetWorldSpaceViewDir(o.positionWS);
                
                o.uv = v.texcoord;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;

                //世界空间下的向量
                half3 worldViewDir = SafeNormalize(i.viewWS);
                half3 worldNormalDir = normalize(i.normalWS);

                //视图空间下的向量
                half3 ViewSpaceNormalDir = TransformWorldToViewDir(worldNormalDir.xyz) * 0.5 + 0.5;
                half3 ViewSpaceViewDir = normalize(TransformWorldToView(worldViewDir));

                half3 matCapDir = cross(ViewSpaceNormalDir,ViewSpaceViewDir);
                half2 matCapUV = matCapDir.xy * 0.5 + 0.5; 
                half3 matcapMap = SAMPLE_TEXTURE2D(_MatCap , sampler_MatCap , matCapUV).rgb;
                half3 matcapMapColor = matcapMap;

                FinalColor = half4(matcapMapColor,1.0);
                
                return FinalColor;
            }
            ENDHLSL
        }
    }
}
