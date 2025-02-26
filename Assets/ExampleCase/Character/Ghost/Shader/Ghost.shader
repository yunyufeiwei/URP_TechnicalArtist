Shader "Art_URP/Character/Ghost"
{
    Properties
    {
        [Header(Frensel)]
        _FresnelColor("Color",Color) = (1,1,1,1)
        _FresnelFade("FresnelFade" , Range(0,8)) = 1
        _FresnelBrightness("FrenselBrightness" , Range(1,5)) = 1

        _Amplitude("Amplitude(XZ),Intensity(zw)",Vector) = (1,1,1,1)
        _Offset("Offset",float) = 0
    }
    SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "False"}
        Blend One One
        ZWrite Off

        LOD 100

        pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS     : POSITION;
                float3 normalOS     : NORMAL;
            };
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS     : TEXCOORD;
                float  fogCoord     : TEXCOORD1;
                float3 positionWS   : TEXCOORD2;
                float3 positionOS   : TEXCOORD3;
            };

            //CBuffer部分，数据参数定义在该结构内，可以使用srp的batch功能
            CBUFFER_START(UnityPerMaterial)
            float4 _FresnelColor;
            float  _FresnelFade;
            float  _FresnelBrightness;
            float4 _Amplitude;
            float  _Offset;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionOS = v.positionOS.xyz;
                v.positionOS.x += sin((v.positionOS.y + _Time.y) * _Amplitude.x) * _Amplitude.y;
                v.positionOS.z += sin((v.positionOS.y + _Time.y) * _Amplitude.z) * _Amplitude.w;

                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                //世界空间下模型的坐标
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);


                //通过ComputeFogFactor方法，使用裁剪空间的Z方向深度得到雾的坐标
                o.fogCoord = ComputeFogFactor(o.positionHCS.z);

                return o;
            }

            half4 frag(Varyings i):SV_TARGET
            {
                half4 FinalColor;

                half3 normalDir = normalize(i.normalWS);
                half3 viewDir   = normalize(_WorldSpaceCameraPos - i.positionWS);
                half  NdotV     = 1 - saturate(dot(normalDir,viewDir));
                half4 fresnel   = pow(NdotV , _FresnelFade) * _FresnelBrightness * _FresnelColor;

                //使用模型本地空间的方向，计算从上到下的遮罩，作为效果显示的混合条件
                half mask = saturate(1 - i.positionOS.x + _Offset);

                FinalColor = fresnel * mask;
                //混合雾效
                FinalColor.rgb = MixFog(FinalColor.rgb , i.fogCoord);

                return FinalColor;
            }
            ENDHLSL  
        }
        //投射阴影
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

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
                float4 positionCS   : SV_POSITION;
            };


            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, float3(0,0,0)));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                output.positionCS = positionCS;
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
