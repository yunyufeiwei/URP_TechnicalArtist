Shader "Art_URP/Character/VFX_Flowing"
{
    Properties
    {
        _Color("Color",Color) = (1,1,1,1)
        _Emissive("Emissive" , 2D) = "white"{}
        _EmissiveIntensity("EmissiveIntensity" , float) = 1
        _FadePower("FadePower" , float) = 2
        _FlowSpeed("FlowSpeed X(uSpeed) Y(vSpeed)" , vector) = (1,1,1,1)
        _DistortMap("DistortMap" , 2D) = "white"{}
        _DistortIntensity("DistortIntensity" , float) = 0
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent"  "Queue" = "Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull off
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
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 viewWS       : TEXCOORD3;
                float2 uv1          : TEXCOORD5;
            };
            
            TEXTURE2D(_Emissive);SAMPLER(sampler_Emissive);
            TEXTURE2D(_DistortMap);SAMPLER(sampler_DistortMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _Emissive_ST;
                float  _EmissiveIntensity;
                float  _FadePower;
                float4 _FlowSpeed;
                float4 _DistortMap_ST;
                float  _DistortIntensity;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.viewWS = GetWorldSpaceViewDir(o.positionWS);

                o.uv = v.texcoord;
                // o.uv = (v.texcoord * _Emissive_ST.xy + _FlowSpeed.xy * _Time.y) + _Emissive_ST.zw;
                o.uv1 = v.texcoord * _DistortMap_ST.xy + _DistortMap_ST.zw;

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 lightDir = light.direction;

                half  distortMap = SAMPLE_TEXTURE2D(_DistortMap , sampler_DistortMap , i.uv1).r * _DistortIntensity * i.uv.y;
                half2 emissiveUV = (i.uv * _Emissive_ST.xy + _FlowSpeed.xy * _Time.y) + _Emissive_ST.zw;
                emissiveUV = emissiveUV + distortMap;
                half  emissiveMap = SAMPLE_TEXTURE2D(_Emissive,sampler_Emissive , emissiveUV).r;
                half3 emissiveColor = emissiveMap * _Color.rgb * _EmissiveIntensity;

                //透明度
                half uvMask = pow(saturate(1 - i.uv.y) , _FadePower ) * smoothstep(0,0.3,1 - abs(i.uv.x * 2 -1));
                half Alpha = saturate(emissiveMap.r * _EmissiveIntensity * uvMask);

                FinalColor = half4(emissiveColor , Alpha);

                return FinalColor;
            }
            ENDHLSL  
        }
    }
}
