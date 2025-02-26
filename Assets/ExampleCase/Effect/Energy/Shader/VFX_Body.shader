Shader "TechnicalArt/VFX/VFX_Body"
{
    Properties
    {
        _NormalMap("NormalMap" , 2D) = "bump"{}
        
        _RimColor("RimColor" , Color) = (1,1,1,1)
        _RimPower("RimPower" , Range(1 , 20)) = 1
        _RimScale("RimScale" , float) = 1
        _RimBais("RimBais" , float) = 0

        _FlowMap("FlowMap" , 2D) = "white"{}
        _FlowTillingOffset("FlowTillingOffset" , vector) = (1,0.5,0,0.3)
        _FlowLightColor("FlowLightColor" , Color) = (1,1,1,1)
        _FlowLightScale("FlowLightScale" , float) = 2
        _FlowLightBais("FlowLightBais" , float) = 0

        _NebulatMap("NebulatMap",2D) = "white"{}
        _NebulaDistort("NebulaDistort" , float) = 0.05
        _NebulatTillingX("NebulaTillingX" , float) = 1
        _NebulatTillingY("NebulaTillingY" , float) = 1
        _NebulatIntensity("NebulatIntensity",float) = 10
        _StarPower("StarPower" , Range(1,20)) = 5
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
                float2 texcoord     : TEXCOORD;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 tangentWS    : TEXCOORD3;
                float3 bitangentWS  : TEXCOORD4;
                float3 viewWS       : TEXCOORD5;
                float2 uv1          : TEXCOORD6;
                float2 uv_VS        : TEXCOORD7;
            };
            
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_FlowMap);SAMPLER(sampler_FlowMap);
            TEXTURE2D(_NebulatMap);SAMPLER(sampler_NebulatMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _NormalMap_ST;
                float4 _RimColor;
                float  _RimPower;
                float  _RimScale;
                float  _RimBais;
                float4 _FlowMap_ST;
                float4 _FlowTillingOffset;
                float4 _FlowLightColor;
                float  _FlowLightScale;
                float  _FlowLightBais;
                float4 _NebulatMap_ST;
                float  _NebulaDistort;
                float  _NebulatTillingX;
                float  _NebulatTillingY;
                float  _NebulatIntensity;
                float  _StarPower;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.tangentWS = TransformObjectToWorldDir(v.tangentOS.xyz);
                half signDir = real(v.tangentOS.w) * GetOddNegativeScale();
                o.bitangentWS =cross(o.normalWS , o.tangentWS) * signDir; 

                o.viewWS = GetWorldSpaceViewDir(o.positionWS);

                o.uv = v.texcoord;
                
                //flowMap uv
                half2 flowMapUVPosition = (o.positionWS - TransformObjectToWorld(half3(0,0,0))).xy ;
                //_FlowTillingOffset.xy表示了纹理的缩放系数，_FlowTillingOffset.zw表示了纹理的移动速度，这里乘以时间让其自动平移
                o.uv1 = (v.texcoord * _FlowMap_ST.xy * _FlowTillingOffset.xy) + (_FlowTillingOffset.zw * _Time.y + _FlowMap_ST.zw);

                //计算相机空间的uv
                o.uv_VS = (TransformWorldToView(o.positionWS) - TransformWorldToView(half3(0,0,0))).xy * _NebulatMap_ST.xy + _NebulatMap_ST.zw;

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                half3 ambientColor =  _GlossyEnvironmentColor.rgb;

                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 lightDir = light.direction;

                //向量计算
                half3 worldViewDir = SafeNormalize(i.viewWS);

                half4 bumpMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap , i.uv);
                half3 normalTS = UnpackNormal(bumpMap);
                half3 worldNormalDir = normalize(TransformTangentToWorld(normalTS , float3x3(i.tangentWS.xyz , i.bitangentWS.xyz , i.normalWS.xyz) , true));

                half  NdotV = dot(worldNormalDir , worldViewDir);

                //计算边缘光效果
                half3 rimColor = (pow(1 - saturate(NdotV) , _RimPower) * _RimScale + _RimBais) * _RimColor.rgb;

                half  distortFlow = NdotV * 0.5 + 0.5;
                half  flowMap = SAMPLE_TEXTURE2D(_FlowMap , sampler_FlowMap , i.uv1).r;
                //计算身体流光效果
                half3 flowLightColor = flowMap * ((1 - NdotV) * _FlowLightScale + _FlowLightBais) * _FlowLightColor.rgb;    

                //将世界空间法线变换到视图空间
                half2 viewUV = (TransformWorldToViewDir(worldNormalDir.xyz)).xy * _NebulaDistort;
                viewUV = (viewUV + i.uv_VS) * half2(_NebulatTillingX , _NebulatTillingY);
                //使用视图空间的uv计算星云效果
                half3 nebulatMap = SAMPLE_TEXTURE2D(_NebulatMap , sampler_NebulatMap , viewUV).rgb;
                //计算星云体效果
                half3 nebulatColor = flowMap * nebulatMap.rgb;

                //强化星云的星星闪烁部分
                half3 starInt = pow(saturate(flowMap) , _StarPower) * pow(saturate(nebulatMap) , _StarPower).rgb * _NebulatIntensity;

                FinalColor = half4(rimColor + flowLightColor + nebulatColor + starInt, 1.0);

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
