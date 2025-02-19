Shader "TechnicalArt/Crystal"
{
    Properties
    {
        [Header(FresnelProperty)]
        _RimColor("FresnelColor",Color) = (1,1,1,1)
        _NormalMap("NormalMap",2D) = "bump"{}
        _EdgeMap("FresnelEdgeMap",2D) = "black"{}
        _FresnelPower("FresnelPower",Range(1,5)) = 1
        _FresnelScale("FresnelScale",Float) = 1
        _FresnelBais("FresnelBais",Float) = 0
        
        [Header(ReflectProperty)]
        _ReflectTex("ReflectTex",cube) = "skybox"{}
        _ReflectIntensity("ReflectInstensity",Float) = 0.1
        
        [Header(RefractProperty)]
        _RefractMap("RefractMap",2D) = "black"{}
        _TillingOffset("TillingOffset",Vector) = (1,1,0,0)
        _DistortIntensity("DistortIntensity",Float) = 1
        _InsideColor("InsideColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque"  "Queue" = "Geometry"}
        LOD 100

        Pass
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
                float2 texcoord     : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 tangentWS    : TEXCOORD2;
                float3 bitangentWS  : TEXCOORD3;
                float3 viewWS       : TEXCOORD4;
                float3 positionWS   : TEXCOORD5;
                float2 uv_VS        : TEXCOORD6;
            };

            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_EdgeMap);SAMPLER(sampler_EdgeMap);
            TEXTURECUBE(_ReflectTex);SAMPLER(sampler_ReflectTex);
            TEXTURE2D(_RefractMap);SAMPLER(sampler_RefractMap);
            TEXTURE2D(_SequenceMap);SAMPLER(sampler_SequenceMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _RimColor;
                float4 _NormalMap_ST;
                float  _FresnelPower;
                float  _FresnelScale;
                float  _FresnelBais;
                float  _ReflectIntensity;
                float4 _RefractTex_ST;
                float4 _TillingOffset;
                float  _DistortIntensity;
                float4 _InsideColor;
                float4 _GameObjectPosition;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.tangentWS = TransformObjectToWorldDir(v.tangentOS.xyz);
                half signDir = real(v.tangentOS.w) * GetOddNegativeScale();
                o.bitangentWS =cross(o.normalWS , o.tangentWS) * signDir;   

                o.viewWS = GetWorldSpaceViewDir(o.positionWS);

                //计算相机空间的uv
                //如果仅仅用half3(0,0,0)来表示gameObject的位置，那么该物体只能在世界坐标的远点
                //o.uv_VS = (TransformWorldToView(o.positionWS) - TransformWorldToView(half3(0,0,0))).xy * _TillingOffset.xy + _TillingOffset.zw;
                o.uv_VS = (TransformWorldToView(o.positionWS) - TransformWorldToView(_GameObjectPosition.xyz)).xy * _TillingOffset.xy + _TillingOffset.zw;

                o.uv = TRANSFORM_TEX(v.texcoord , _NormalMap);
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;

                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));

                //采样纹理贴图
                half fresnelEdgeMap = SAMPLE_TEXTURE2D(_EdgeMap,sampler_EdgeMap,i.uv).r;

                //TBN
                half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,i.uv);
                half3 normalTS = UnpackNormal(normalMap);
                half3 worldNormal = TransformTangentToWorld(normalTS , float3x3(i.tangentWS.xyz , i.bitangentWS.xyz,i.normalWS.xyz),true);

                half3 worldNormalDir = SafeNormalize(worldNormal);
                half3 worldViewDir = SafeNormalize(i.viewWS);

                //菲涅尔制作 边缘颜色
                half fresnelFactor = saturate(1 - dot(worldNormalDir,worldViewDir));
                half3 fresnelColor = ((_FresnelBais + pow(fresnelFactor,_FresnelPower) * _FresnelScale) + fresnelEdgeMap) * _RimColor.rgb ;

                //反射颜色 ,反射值在边缘的地方存在，使用菲涅尔因子进行混合
                half3 reflectDir = normalize(reflect(-worldViewDir,worldNormalDir));
                half4 reflectMap = SAMPLE_TEXTURECUBE_LOD(_ReflectTex , sampler_ReflectTex , reflectDir  , 4) * _ReflectIntensity;
                half3 reflectColor = reflectMap.rgb * fresnelFactor * fresnelFactor;

                //内部图像与折射
                half2 distortIntensity = (TransformWorldToViewDir(worldNormalDir.xyz)).xy * _DistortIntensity;  //添加法线折射
                half2 viewSpace_UV = i.uv_VS + distortIntensity;
                half3 refractTex = lerp(SAMPLE_TEXTURE2D(_RefractMap , sampler_RefractMap , viewSpace_UV).rgb , _InsideColor.rgb , fresnelFactor);

                FinalColor = half4(fresnelColor + reflectColor + refractTex , 1.0);
                return FinalColor;
            }
            ENDHLSL
        }
    }
}
