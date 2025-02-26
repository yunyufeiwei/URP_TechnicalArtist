Shader "Art_URP/Character/Character_Painter" 
{
    Properties 
    {
        [Header(Texture)]
            _MainTex    ("RGB:基础颜色 A:环境遮罩", 2D)     = "white" {}
            [Normal] _NormTex	("RGB:法线贴图", 2D)       = "bump" {}
            _SpecTex    ("RGB:高光颜色 A:高光次幂", 2D)     = "gray" {}
            _EmitTex    ("RGB:环境贴图", 2d)                = "black" {}
            _Cubemap    ("RGB:环境贴图", cube)              = "_Skybox" {}
        [Header(Diffuse)]
            _MainCol    ("基本色",      Color)              = (0.5, 0.5, 0.5, 1.0)
            _EnvDiffInt ("环境漫反射强度",  Range(0, 1))    = 0.2
            _EnvUpCol   ("环境天顶颜色", Color)             = (1.0, 1.0, 1.0, 1.0)
            _EnvSideCol ("环境水平颜色", Color)             = (0.5, 0.5, 0.5, 1.0)
            _EnvDownCol ("环境地表颜色", Color)             = (0.0, 0.0, 0.0, 0.0)
        [Header(Specular)]
            [PowerSlider(2)] _SpecPow    ("高光次幂",    Range(1, 90))       = 30
            _EnvSpecInt ("环境镜面反射强度", Range(0, 5))   = 0.2
            _FresnelPow ("菲涅尔次幂", Range(0, 5))         = 1
            _CubemapMip ("环境球Mip", Range(0, 7))          = 0
        [Header(Emission)]
            [HideInInspect] _EmitInt    ("自发光强度", range(1, 10))         = 1
    }
    SubShader 
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry"}

        Pass 
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //阴影相关的宏定义
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT         

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "MyCginc.cginc"

            struct VertexInput 
            {
                float4 positionOS   : POSITION;     // 顶点信息 Get✔
                float2 uv0      : TEXCOORD0;        // UV信息 Get✔
                float3 normalOS   : NORMAL;         // 法线信息 Get✔
                float4 tangentOS  : TANGENT;        // 切线信息 Get✔
            };

            struct VertexOutput 
            {
                float4 positionHCS      : SV_POSITION;  // 屏幕顶点位置
                float2 uv0              : TEXCOORD0;    // UV0
                float3 positionWS       : TEXCOORD1;    // 世界空间顶点位置
                float3 nDirWS           : TEXCOORD2;    // 世界空间法线方向
                float3 tDirWS           : TEXCOORD3;    // 世界空间切线方向
                float3 bDirWS           : TEXCOORD4;    // 世界空间副切线方向
            };

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormTex);SAMPLER(sampler_NormTex);
            TEXTURE2D(_SpecTex);SAMPLER(sampler_SpecTex);
            TEXTURE2D(_EmitTex);SAMPLER(sampler_EmitTex);
            TEXTURECUBE(_Cubemap);SAMPLER(sampler_Cubemap);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float3 _MainCol;
                float _EnvDiffInt;
                float3 _EnvUpCol;
                float3 _EnvSideCol;
                float3 _EnvDownCol;
                // Specular
                float _SpecPow;
                float _FresnelPow;
                float _EnvSpecInt;
                float _CubemapMip;
                // Emission
                float _EmitInt;
            CBUFFER_END

            // 输入结构>>>顶点Shader>>>输出结构
            VertexOutput vert (VertexInput v) 
            {
                VertexOutput o = (VertexOutput)0;                   // 新建输出结构
                o.positionHCS = TransformObjectToHClip( v.positionOS.xyz );       // 顶点位置 OS>CS
                o.uv0 = v.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;                                  // 传递UV
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);   // 顶点位置 OS>WS
                o.nDirWS = TransformObjectToWorldNormal(v.normalOS);  // 法线方向 OS>WS
                o.tDirWS = normalize(TransformObjectToWorldDir(v.tangentOS.xyz)); // 切线方向 OS>WS
                o.bDirWS = normalize(cross(o.nDirWS, o.tDirWS) * v.tangentOS.w);  // 副切线方向
                return o;
            }

            half4 frag(VertexOutput i) : SV_TARGET 
            {
                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 lDirWS = light.direction;

                // 准备向量
                float3 nDirTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormTex,sampler_NormTex, i.uv0)).rgb;
                float3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);
                float3 nDirWS = normalize(mul(nDirTS, TBN));
                float3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 vrDirWS = reflect(-vDirWS, nDirWS);
                // float3 lDirWS = _WorldSpaceLightPos0.xyz;
                float3 lrDirWS = reflect(-lDirWS, nDirWS);
                // 准备点积结果
                float ndotl = dot(nDirWS, lDirWS);
                float vdotr = dot(vDirWS, lrDirWS);
                float vdotn = dot(vDirWS, nDirWS);
                // 采样纹理
                float4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv0);
                float4 var_SpecTex = SAMPLE_TEXTURE2D(_SpecTex,sampler_SpecTex, i.uv0);
                float3 var_EmitTex = SAMPLE_TEXTURE2D(_EmitTex, sampler_EmitTex,i.uv0).rgb;
                float3 var_Cubemap = SAMPLE_TEXTURECUBE_LOD(_Cubemap,sampler_Cubemap, float4(vrDirWS, lerp(_CubemapMip, 0.0, var_SpecTex.a)),3).rgb;
                // 光照模型(直接光照部分)
                float3 baseCol = var_MainTex.rgb * _MainCol;
                float lambert = max(0.0, ndotl);
                float3 specCol = var_SpecTex.rgb;
                float specPow = lerp(1, _SpecPow, var_SpecTex.a);
                float phong = pow(max(0.0, vdotr), specPow);
                float3 dirLighting = (baseCol * lambert + specCol * phong) * lightColor;
                // 光照模型(环境光照部分)
                float3 envCol = TriColAmbient(nDirWS, _EnvUpCol, _EnvSideCol, _EnvDownCol);
                float fresnel = pow(max(0.0, 1.0 - vdotn), _FresnelPow);    // 菲涅尔
                float occlusion = var_MainTex.a;
                float3 envLighting = (baseCol * envCol * _EnvDiffInt + var_Cubemap * fresnel * _EnvSpecInt * var_SpecTex.a) * occlusion;
                // 光照模型(自发光部分)
                float3 emission = var_EmitTex * _EmitInt * (sin(_Time.z) * 0.5 + 0.5);
                // 返回结果
                float3 finalRGB = dirLighting + envLighting + emission;
                return float4(finalRGB, 1.0);
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"     //产生阴影
    }
}