Shader "TechnicalArt/Goblet"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]_DstFactor("DstFactor",int) = 0
        
        [Header(Matcap)]
        _MatCap("MatCap" , 2D) = "blcak"{}
        
        _MinRefractRange("MinRefractRange",Float) = 0
        _MaxRefractRange("MaxRefractRange",Float) = 1
        
        _DirtMap("DirtMap",2D) = "black"{}
        _DirtIntensity("DirtIntensity",Float) = 1
        _Alpha("Alpha",Float) = 1
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
            TEXTURE2D(_DirtMap);SAMPLER(sampler_DirtMap);

            CBUFFER_START(UnityPerMaterial)
                float  _MinRefractRange;
                float  _MaxRefractRange;
                float4 _DirtMap_ST;
                float  _DirtIntensity;
                float  _Alpha;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o=(Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.viewWS = GetWorldSpaceViewDir(o.positionWS);
                
                o.uv = TRANSFORM_TEX(v.texcoord , _DirtMap);
                o.color = v.color;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;

                //世界空间下的向量
                half3 worldViewDir = SafeNormalize(i.viewWS);
                half3 worldNormalDir = normalize(i.normalWS);

                //视图空间下的向量
                half3 ViewSpaceNormalDir = TransformWorldToViewDir(worldNormalDir.xyz); //视图空间下法线到相机的向量
                half3 ViewSpacePosition = normalize(TransformWorldToView(i.positionWS));        //视图空间下点到相机的向量

                half3 matCapDir = cross(ViewSpaceNormalDir,ViewSpacePosition);
                matCapDir = half3(-matCapDir.y,matCapDir.x,matCapDir.z);
                half2 matCapUV = matCapDir.xy * 0.5 + 0.5;
                half3 matcapMap = SAMPLE_TEXTURE2D(_MatCap , sampler_MatCap , matCapUV).rgb;
                half3 matcapMapColor = matcapMap;

                //
                half fresnelMask = dot(worldNormalDir,worldViewDir);
                half refractMask = saturate(1 - smoothstep(_MinRefractRange , _MaxRefractRange , fresnelMask)); //折射范围过渡对比
                half3 dirtMap = SAMPLE_TEXTURE2D(_DirtMap , sampler_DirtMap , i.uv).a * _DirtIntensity;

                FinalColor = half4(dirtMap,_Alpha);
                
                return FinalColor;
            }
            ENDHLSL
        }
    }
}
