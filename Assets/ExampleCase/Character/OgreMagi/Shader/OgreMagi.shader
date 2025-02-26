Shader "TechnicalArt/Dota2" 
{
    Properties 
    {
        [Header(Texture)]
        _MainTex        ("RGB:颜色 A:透贴", 2d) = "white"{}
        _MaskTex        ("R:高光强度 G:边缘光强度 B:高光染色 A:高光次幂", 2d) = "black"{}
        _NormTex        ("RGB:法线贴图", 2d) = "bump"{}
        _MatelnessMask  ("金属度遮罩", 2d) = "black"{}
        _EmissionMask   ("自发光遮罩", 2d) = "black"{}
        _DiffWarpTex    ("颜色Warp图", 2d) = "gray"{}
        _FresWarpTex    ("菲涅尔Warp图", 2d) = "gray"{}
        _Cubemap        ("环境球", cube) = "_Skybox"{}
        [Header(DirDiff)]
        _LightCol       ("光颜色", color) = (1.0, 1.0, 1.0, 1.0)
        [Header(DirSpec)]
        _SpecPow        ("高光次幂", range(0.0, 99.0)) = 5
        _SpecInt        ("高光强度", range(0.0, 10.0)) = 5
        [Header(EnvDiff)]
        _EnvCol         ("环境光颜色", color) = (1.0, 1.0, 1.0, 1.0)
        [Header(EnvSpec)]
        _EnvSpecInt     ("环境镜面反射强度", range(0.0, 30.0)) = 0.5
        [Header(RimLight)]
        [HDR]_RimCol    ("轮廓光颜色", color) = (1.0, 1.0, 1.0, 1.0)
        [Header(Emission)]
        _EmitInt        ("自发光强度", range(0.0, 10.0)) = 1.0
        [HideInInspector]
        _Cutoff         ("Alpha cutoff", Range(0,1)) = 0.5
        [HideInInspector]
        _Color          ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader 
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry"}
        
        Pass 
        {
            Tags{"LightMode" = "UniversalForward"}
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //阴影相关的宏定义
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT         

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes 
            {
                float4 positionOS   : POSITION;
                float2 uv0      : TEXCOORD0;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
            };

            struct Varyings 
            {
                float4 positionHCS    : SV_POSITION; 
                float2 uv0      : TEXCOORD0;  
                float3 positionWS    : TEXCOORD1; 
                float3 nDirWS   : TEXCOORD2; 
                float3 tDirWS   : TEXCOORD3;
                float3 bDirWS   : TEXCOORD4;
            };

            Varyings vert (Attributes v) 
            {
                Varyings o = (Varyings)0;                   
                o.positionHCS = TransformObjectToHClip( v.positionOS.xyz);    
                o.uv0 = v.uv0;                                  
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);   
                o.nDirWS = TransformObjectToWorldNormal(v.normalOS);  
                o.tDirWS = normalize(TransformObjectToWorldDir(v.tangentOS.xyz));
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangentOS.w); 
                return o;                                         
            }

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            TEXTURE2D(_MaskTex);SAMPLER(sampler_MaskTex);
            TEXTURE2D(_NormTex);SAMPLER(sampler_NormTex);
            TEXTURE2D(_MatelnessMask);SAMPLER(sampler_MatelnessMask);
            TEXTURE2D(_EmissionMask);SAMPLER(sampler_EmissionMask);
            TEXTURE2D(_DiffWarpTex);SAMPLER(sampler_DiffWarpTex);
            TEXTURE2D(_FresWarpTex);SAMPLER(sampler_FresWarpTex);
            TEXTURECUBE(_Cubemap);SAMPLER(sampler_Cubemap);

            CBUFFER_START(UnityPerMaterial)
                half3 _LightCol;
                half _SpecPow;
                half _SpecInt;
                half3 _EnvCol;
                half _EnvSpecInt;
                half3 _RimCol;
                half _EmitInt;
                half _Cutoff;
            CBUFFER_END

            float4 frag(Varyings i) : SV_TARGET 
            {
                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 lightDir = light.direction;

                // 向量准备
                half3 normalDirTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormTex,sampler_NormTex, i.uv0));
                half3x3 TBN = half3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                half3 normalDirWS = normalize(mul(normalDirTS, TBN));
                half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);
                half3 vrDirWS = reflect(-viewDirWS, normalDirWS);
                half3 lrDirWS = reflect(-lightDir, normalDirWS);
                // 中间量准备
                half ndotl = dot(normalDirWS, lightDir);
                half ndotv = dot(normalDirWS, viewDirWS);
                half vdotr = dot(viewDirWS, lrDirWS);
                // 采样纹理
                half4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv0);
                half4 var_MaskTex = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex,i.uv0);
                half  var_MatelnessMask = SAMPLE_TEXTURE2D(_MatelnessMask,sampler_MatelnessMask, i.uv0).r;
                half  var_EmissionMask = SAMPLE_TEXTURE2D(_EmissionMask,sampler_EmissionMask, i.uv0).r;
                half3 var_FresWarpTex = SAMPLE_TEXTURE2D(_FresWarpTex,sampler_FresWarpTex, ndotv).rgb;
                half3 var_Cubemap = SAMPLE_TEXTURECUBE_LOD(_Cubemap , sampler_Cubemap ,float4(vrDirWS, lerp(8.0, 0.0, var_MaskTex.a)).rgb,3).rgb;
                // 提取信息
                half3 baseCol = var_MainTex.rgb;
                half opacity = var_MainTex.a;
                half specInt = var_MaskTex.r;
                half rimInt = var_MaskTex.g;
                half specTint = var_MaskTex.b;
                half specPow = var_MaskTex.a;
                half matellic = var_MatelnessMask;
                half emitInt = var_EmissionMask;
                half3 envCube = var_Cubemap;
                // 光照模型
                    // 漫反射颜色 镜面反射颜色
                    half3 diffCol = lerp(baseCol, half3(0.0, 0.0, 0.0), matellic);
                    half3 specCol = lerp(baseCol, half3(0.3, 0.3, 0.3), specTint) * specInt;
                    // 菲涅尔
                    half3 fresnel = lerp(var_FresWarpTex, 0.0, matellic);
                    half fresnelCol = fresnel.r;    // 无实际用途
                    half fresnelRim = fresnel.g;
                    half fresnelSpec = fresnel.b;
                    // 光源漫反射
                    half halfLambert = ndotl * 0.5 + 0.5;
                    half3 var_DiffWarpTex = SAMPLE_TEXTURE2D(_DiffWarpTex,sampler_DiffWarpTex, half2(halfLambert, 0.2)).rgb;
                    half3 dirDiff = diffCol * var_DiffWarpTex * lightColor;
                    // 光源镜面反射
                    half phong = pow(max(0.0, vdotr), specPow * _SpecPow);
                    half spec = phong * max(0.0, ndotl);
                    spec = max(spec, fresnelSpec);
                    spec = spec * _SpecInt;
                    half3 dirSpec = specCol * spec * lightColor;
                    // 环境漫反射
                    half3 envDiff = diffCol * _EnvCol;
                    // 环境镜面反射
                    half reflectInt = max(fresnelSpec, matellic) * specInt;
                    half3 envSpec = specCol * reflectInt * envCube * _EnvSpecInt;
                    // 轮廓光
                    half3 rimLight = _RimCol * fresnelRim * rimInt * max(0.0, normalDirWS.g);
                    // 自发光
                    half3 emission = diffCol * emitInt * _EmitInt;
                    // 混合
                    half3 finalRGB = (dirDiff + dirSpec) + envDiff + envSpec + rimLight + emission;
                // 透明剪切
                clip(opacity - _Cutoff);
                // 返回值
                return float4(finalRGB, 1.0);
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"     //产生阴影
    }
}