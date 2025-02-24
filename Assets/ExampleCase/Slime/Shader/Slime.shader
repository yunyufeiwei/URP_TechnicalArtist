Shader "TechnicalArt/Slime"
{
    Properties
    {
        [HDR]_Color("Color" , Color) = (1,1,1,1)
        [NoScaleOffset]_BaseMap("BaseMap" , 2D) = "white"{}
        [NoScaleOffset]_MatCap("MatCap" , 2D) = "white"{}
        [NoScaleOffset]_NormalMap("NormalMap" , 2D) = "bump"{}
        
        [Header(Fresnel)]
        _RimColor("RimColor" , Color) = (1,1,1,1)
        _RimBias("RimBias" , float) = 0
        _RimScale("RimScale" , float) = 1
        [PowerSlider(8)]_RimPower("RimPower" , Range(0.1, 20)) = 1
        
        [NoScaleOffset]_TriPlaneNormal("TriPlaneNormal" , 2D) = "bump"{}
        _Tilling("Tilling X(rg) Y(gb) Z(rb)",float) = (2,2,2,0)
        _Speed("Speed X(rg) Y(gb) Z(rb)" , float) = (0,0,0,0)
        _Contrast("Contrast",float) = 1 
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
                float4 Color        : COLOR;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 tangentWS    : TEXCOORD3;
                float3 bitangentWS  : TEXCOORD4;
                float3 viewDirWS    : TEXCOORD5;
                float3 vertexColor  : TEXCOORD6;
            };

            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MatCap);SAMPLER(sampler_MatCap);
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
            TEXTURE2D(_TriPlaneNormal);SAMPLER(sampler_TriPlaneNormal);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _BaseMap_ST;
                float4 _RimColor;
                float  _RimBias;
                float  _RimScale;
                float  _RimPower;
                float4 _Tilling;
                float4 _Speed;
                float  _Contrast;
            CBUFFER_END

            Varyings vert (Attributes v)
            {
                Varyings o=(Varyings)0;
                o.positionHCS = TransformObjectToHClip(v.positionOS);

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.tangentWS = TransformObjectToWorldDir(v.tangentOS.xyz);
                half signDir = real(v.tangentOS.w) * GetOddNegativeScale();
                o.bitangentWS = cross(o.normalWS,o.tangentWS) * signDir;

                o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);

                o.uv = TRANSFORM_TEX(v.texcoord, _BaseMap);
                o.vertexColor = v.Color;

                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;

                //向量计算
                half3 worldViewDir = SafeNormalize(i.viewDirWS);
                half3 worldNormal_Obj = normalize(i.normalWS);
                half3x3 TBN = float3x3(i.tangentWS.xyz,i.bitangentWS.xyz,i.normalWS.xyz);

                half4 normalMap = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,i.uv);
                half3 normalTS = UnpackNormal(normalMap).xyz;
                half3 worldNormalDir = TransformTangentToWorld(normalTS , TBN , true);

                //TriPlaneMapping
                half3 worldSpaceUV = (i.positionWS - TransformObjectToWorld(half3(0,0,0))) * _Tilling.xyz + (_Time.y * _Speed.xyz);
                half2 TriPlane_RG = worldSpaceUV.xy;
                half2 TriPlane_GB = worldSpaceUV.yz;
                half2 TriPlane_RB = worldSpaceUV.xz;
                half3 TriPlaneTex_RG = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_RG)).rgb;
                half3 TriPlaneTex_GB = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_GB)).rgb;
                half3 TriPlaneTex_RB = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_RB)).rgb;
                half3 contrast = pow(abs(worldNormal_Obj) , _Contrast);
                half3 weight = contrast / (contrast.x + contrast.y + contrast.z);
                half3 TriPlaneNormal_TS = (TriPlaneTex_RG * weight.z) + (TriPlaneTex_GB * weight.x) + (TriPlaneTex_RB * weight.y);
                half3 NormalRec = normalize(half3(worldNormal_Obj.x + TriPlaneNormal_TS.x , TriPlaneNormal_TS.y + worldNormal_Obj.y , worldNormal_Obj.z));

                half3 viewNormalDir = TransformWorldToViewDir(NormalRec.xyz);

                //计算
                half  fresnel = pow(saturate(dot(worldNormal_Obj , worldViewDir)) , _RimPower) * _RimScale + _RimBias;
                half4 fresnelColor = fresnel * _RimColor;

                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap , i.uv);
                
                half2 matCapUV = viewNormalDir.xy * 0.5 + 0.5;
                half4 matCapMap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap , matCapUV) * _Color;

                FinalColor = half4(viewNormalDir,1.0);
               
                return fresnelColor;
            }
            ENDHLSL
        }
    }
}
