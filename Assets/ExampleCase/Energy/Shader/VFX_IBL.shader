Shader "Art_URP/Character/VFX_IBL"
{
    Properties
    {
        _BaseMap("BaseMap" , 2D) = "white"{}
        _NormalMap("NormalMap" , 2D) = "bump"{}
        _MaskMap("MaskMap" , 2D) = "white"{}
        _RoughnessAdjust("_RoughnessAdjust",Range(-1,1)) = 0
        _IBL("CubeMap" , Cube) = "skybox"{}
        _IBLIntensity("IBLIntensity" , float) = 1
        _AO("AO" , 2D) = "white"{}
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
            };
            
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);SAMPLER(sampler_MaskMap);
            TEXTURECUBE(_IBL);SAMPLER(sampler_IBL);
            TEXTURE2D(_AO);SAMPLER(sampler_AO);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _NormalMap_ST;
                float4 _MaskMap_ST;
                float  _RoughnessAdjust;
                float  _IBLIntensity;
            CBUFFER_END

            half3 GammaToLinear(half3 color)
            {
                return pow(color , 2.2);
            }
            half3 LinearToGamma(half3 color)
            {
                return pow(color , 1 / 2.2);
            }

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

                o.uv = TRANSFORM_TEX(v.texcoord , _BaseMap);

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                half3 ambientColor =  _GlossyEnvironmentColor.rgb;

                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 lightDir = light.direction;

                //向量
                half3 worldViewDir = SafeNormalize(i.viewWS);

                half4 bumpMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap , i.uv);
                half3 normalTS = UnpackNormal(bumpMap);
                half3 worldNormalDir = normalize(TransformTangentToWorld(normalTS , float3x3(i.tangentWS.xyz , i.bitangentWS.xyz , i.normalWS.xyz) , true));

                //纹理采样
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap , sampler_BaseMap , i.uv);
                baseMap.rgb = GammaToLinear(baseMap.rgb);
                half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap , sampler_NormalMap , i.uv);
                half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap , sampler_MaskMap , i.uv);

                half roughness = clamp(0 , 1 , maskMap.g + _RoughnessAdjust);
                half IBLMipmapLevel = ((1.7 - roughness *0.7) * roughness) * 6;         //计算IBL的粗糙度级别

                half4 aoMap = SAMPLE_TEXTURE2D(_AO , sampler_AO , i.uv);

                //IBL
                half3 reflectDir = normalize(reflect(-worldViewDir , worldNormalDir));
                half4 IBLMap = SAMPLE_TEXTURECUBE_LOD(_IBL , sampler_IBL , reflectDir , IBLMipmapLevel) * _IBLIntensity * aoMap;
                IBLMap.rgb = GammaToLinear(IBLMap.rgb);

                FinalColor = half4(LinearToGamma((baseMap * IBLMap).rgb) , 1.0);

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
