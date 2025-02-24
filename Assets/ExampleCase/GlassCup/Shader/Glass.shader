Shader "TechnicalArt/Glass"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcFactor("SrcFactor",int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]_DstFactor("DstFactor",int) = 0

        [Header(Matcap)]
        _MatCap("MatCap" , 2D) = "blcak"{}

        [Space(20)]
        [Header(RefractProperty)]
        _RefractMatcap("RefractMatcap" , 2D) = "black"{ }
        _RefractIntensity("refractIntensity" , float) = 1
        _RefractColor("RefractColor" , Color) = (1,1,1,1)
        _RefractMin("RefractMin",float) = 0
        _RefractMax("RefractMax",float) = 1

        [Space(20)]
        [Header(Mask)]
        _EdgeMask("EdgeMask" , 2D) = "white"{}
        _ObjectPivotOffset("_ObjectPivotOffset" , float) = 0
        _ObjectHeight("_ObjectHeight" , float) = 0.35
        _DirtMap("DirtMap" , 2D) = "black"{}
        _DirtIntensity("DirtIntensity" , float) = 1
        _Alpha("Alpha" , float) = 1
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent"  "Queue" = "Transparent"}
        // Blend [_SrcFactor][_DstFactor]
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest On
        Cull Back

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
                float3 normalOS     : NORMAL;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 viewWS       : TEXCOORD3;
            };
            
            TEXTURE2D(_MatCap);SAMPLER(sampler_MatCap);
            TEXTURE2D(_RefractMatcap);SAMPLER(sampler_RefractMatcap);
            TEXTURE2D(_EdgeMask);SAMPLER(sampler_EdgeMask);
            TEXTURE2D(_DirtMap);SAMPLER(sampler_DirtMap);

            CBUFFER_START(UnityPerMaterial)
                float  _RefractIntensity;
                float4 _RefractColor;
                float  _ObjectPivotOffset;
                float  _ObjectHeight;
                float  _RefractMin;
                float  _RefractMax;
                float  _DirtIntensity;
                float  _Alpha;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.viewWS = GetWorldSpaceViewDir(o.positionWS);

                o.uv = v.texcoord;

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                half3 ambientColor =  _GlossyEnvironmentColor.rgb;

                half3 worldViewDir = SafeNormalize(i.viewWS);
                half3 worldNormalDir = normalize(i.normalWS);
                half3 viewNormalDir = TransformWorldToViewDir(worldNormalDir.xyz);
                half3 positionViewSpace = normalize(TransformWorldToView(i.positionWS));

                //常规matCapUV的计算方式
                // half2 matCapUV =cross(viewNormalDir.xy * 0.5 + 0.5);

                //算法改进之后的matCapUV(常规的matcapUV在面法线朝向一致或者相对非常平滑时，会采样到同一个matcap上的像素点，因此会出现图像拉伸)
                half3 matCapDir = cross(viewNormalDir , positionViewSpace);
                matCapDir = half3(-matCapDir.y , matCapDir.x , matCapDir.z);
                half2 matCapUV = matCapDir.xy * 0.5 + 0.5; 
                half3 matcapMap = SAMPLE_TEXTURE2D(_MatCap , sampler_MatCap , matCapUV).rgb;
                half3 matcapMapColor = matcapMap;

                //厚度图遮罩计算
                half fresnelMask = saturate(1 - smoothstep(_RefractMin , _RefractMax , dot(worldNormalDir , worldViewDir)));
                half2 edgeMaskUV = ((i.positionWS.y - TransformObjectToWorld(half3(0,0,0)).y) - _ObjectPivotOffset) / _ObjectHeight;
                half edgeMask = SAMPLE_TEXTURE2D(_EdgeMask , sampler_EdgeMask , edgeMaskUV).r;
                half dirtMask = SAMPLE_TEXTURE2D(_DirtMap , sampler_DirtMap , i.uv).a * _DirtIntensity;

                half Thickness = saturate(fresnelMask + edgeMask + dirtMask).r;      //计算遮罩

                //计算折射
                half refractivity = Thickness * _RefractIntensity;                                      //对遮罩部分强加,计算出折射率的区域
                half2 refractUV = matCapUV + refractivity;                                              //对折射的区域计算一个偏移值
                half3 refractMap = SAMPLE_TEXTURE2D(_RefractMatcap , sampler_RefractMatcap , refractUV).rgb;
                half3 refractColor = lerp(_RefractColor.rgb * 0.5 , refractMap * _RefractColor.rgb , refractivity);

                half Alpha = saturate((max(matcapMap.r , Thickness)) * _Alpha);

                FinalColor = half4(matcapMapColor + refractColor , Alpha);

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
