Shader "Art_URP/Character/Longicorn"
{
    Properties
    {
        [Header(Base)]
        _Color("Color",Color) = (1,1,1,1)
        _BaseMap("BaseMap" , 2D) = "white"{}
        _NormalMap("NormalMap",2D) = "bump"{}
        _NormalScale("NormalScale",float) = 1
        [Toggle(_NORMALDIR_ON)]_NormalDir("NormalDir" , int) = 1

        [Header(Matcap)]
        _Matcap("BaseCatmap" , 2D) = "white"{}
        _MatcapAdd("MatcapAdd",2D) = "white"{}
        _MatcapIntensity("MatcapIntensity" , Range(1,20)) = 1
        _MatcapAddIntensity("MatcapAddIntensity",Range(0,1)) = 1

        [Header(Fresnel)]
        _FresnelPow("FresnelPow" , Range(0,20)) = 1

        [Header(RampTexture)]
        _RampTexture("RampTexture",2D) = "white"{}

    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry"}

        LOD 100

        pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _NORMALDIR_ON

            //阴影相关的宏定义
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT         

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
                float3 positionWS   : TEXCOORD;
                float2 uv           : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 tangentWS    : TEXCOORD3;
                float3 bitangentWS  : TEXCOORD4;
                float3 normalVS     : TEXCOORD5;
                float3 viewWS       : TEXCOORD6;
            };
            
            //属性定义部分
            //定义纹理采样贴图和采样状态
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_Matcap);SAMPLER(sampler_Matcap);
            TEXTURE2D(_MatcapAdd);SAMPLER(sampler_MatcapAdd);
            TEXTURE2D(_RampTexture);SAMPLER(sampler_RampTexture);

            //CBuffer部分，数据参数定义在该结构内，可以使用srp的batch功能
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _BaseMap_ST;
                float4 _Normal_ST;
                float  _NormalScale;
                float  _NormalDir;
                float  _MatcapIntensity;
                float  _MatcapAddIntensity;
                float  _FresnelPow;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);

                //世界空间下的法线相关数据，用于后面构建TBN矩阵
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

                //光照部分
                // Light light = GetMainLight();
                //计算阴影坐标使用该函数的重载方式
                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));

                half4 lightColor = half4(light.color.rgb * light.distanceAttenuation , 1); 
                half3 lightDir = light.direction;

                //Input.hlsl中定义的该变量默认是half4，因此在代码里面声明变量最好保持一致，减少隐式警告
                half4 ambientColor = _GlossyEnvironmentColor;

                half4 selfShadow = light.shadowAttenuation;

                //向量
                half3 worldNormalDir = normalize(i.normalWS);
                half3 worldViewDir = normalize(i.viewWS);

                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap , i.uv);
                //提取法线贴图，通过TBN矩阵将贴图的法线从切线空间转换到世界空间
                half4 bumpMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap , i.uv);
                half3 normalTS = UnpackNormalScale(bumpMap , _NormalScale);
                half3 worldNormalWS = normalize(TransformTangentToWorld(normalTS , float3x3(i.tangentWS.xyz , i.bitangentWS.xyz , i.normalWS.xyz)));

                half4 diffuse  = saturate(dot(worldNormalWS , lightDir) * 0.5 + 0.5) *  lightColor * baseMap * selfShadow;

                //----------------------------法线方案选择--------------------------------
                //方案一：手动切换是使用模型的顶点法线作为matcapUV来采样，还是使用切线空间变换后的法线来作为matcapUV来采样
                // half3 normalVS = TransformWorldToViewDir(worldNormalWS) * 0.5 + 0.5;
                // half3 normalVS = TransformWorldToViewDir(i.normalWS) * 0.5 + 0.5;

                //方案二：
                //计算matcap贴图，因为matcap贴图是在视角空间下的反射，因此需要使用视空间下的法线作为uv来进行采样
                half3 normalVS = TransformWorldToViewDir(i.normalWS) * 0.5 + 0.5;
                #if(_NORMALDIR_ON)
                    normalVS = TransformWorldToViewDir(worldNormalWS) * 0.5 + 0.5;
                #endif

                half2 matcapUV = normalVS.xy;
                half4 matcapMap = SAMPLE_TEXTURE2D(_Matcap,sampler_Matcap,matcapUV) * _MatcapIntensity;
                half4 matcapMapAdd = SAMPLE_TEXTURE2D(_MatcapAdd , sampler_MatcapAdd , matcapUV) * _MatcapAddIntensity;

                //通过菲涅尔来控制薄膜干涉的显示效果
                half  fresnelMask = (1 - saturate(dot(worldNormalWS , worldViewDir))) * _FresnelPow;
                half2 rampTexUV = float2(fresnelMask ,0.5);
                half4 rampTex = SAMPLE_TEXTURE2D(_RampTexture , sampler_RampTexture , rampTexUV);

                //这里直接加上环境光，画面会变灰，是正常效果（相当于在效果上追加了一层整体的环境色），环境光反射的区域应该只影响高光部分，那么可以将环境光计算在高光反射 部分
                // FinalColor = diffuse * matcapMap * rampTex + matcapMapAdd + ambientColor;
                // FinalColor = diffuse * matcapMap * rampTex + matcapMapAdd;
                //这里的ambientColor * baseMap相当于在EnvironmentLighting中，将环境光的颜色调的比较黑，操作结果是一样的
                FinalColor = diffuse * matcapMap * rampTex + matcapMapAdd + ambientColor * baseMap;

                return FinalColor;
            }
            ENDHLSL  
        }

        //处理物体生成阴影..
        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };
            struct Varyings
            {
                float4 positionCS  : SV_POSITION;       //裁剪空间的维度是四维的
            };

            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings) 0;

                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

                //\Library\PackageCache\com.unity.render-pipelines.universal@14.0.8\Editor\ShaderGraph\Includes\Varyings.hlsl
                //获取阴影专用裁剪空间下的坐标
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, float3(0,0,0)));
                //判断是否在DirectX平台翻转过坐标
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                o.positionCS = positionCS;

                return o;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
