Shader "TechnicalArt/Postprocess/SobelRimLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ThicknessX("ThicknessX" , float) = 0.01
        _ThicknessY("ThicknessY" , float) = 0.01
        _MaxThickness("MaxThickness",float) = 0.01
        _Intensity("Intensity" , Range(0,1)) = 0.01
        _LerpValue("LerpValue",Range(0,1)) = 1
        _Distance("Distance" , float) = 1
        _RimLightColor("RimLightColor" , Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags {"RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry"}

        Pass
        {
            NAME "RimLight"
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // #define REQUIRE_DEPTH_TEXTURE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 texcoord     : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 screenPos    : TEXCOORD1;
            };

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            TEXTURE2D (_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_TexelSize;          //x = 1/width  y = 1/height  z = width  w = height(xy表示宽高比)
                float  _ThicknessX;
                float  _ThicknessY;
                float  _MaxThickness;
                float  _Intensity;
                float  _LerpValue;
                float  _Distance;
                float4 _RimLightColor;
            CBUFFER_END

            static float2 sobelSamplePoints[9] = {float2(-1,1) , float2(0,1) , float2(1,1),
                                                  float2(-1,0) , float2(0,0) , float2(1,0),
                                                  float2(-1,-1), float2(0,-1), float2(1,-1),
                                                 };

            
            static float sobelXMatrix[9] = {1,0,-1,
                                            2,0,-2,
                                            1,0,-1,
                                            };

            static float sobelYMatrix[9] = {1,2,1,
                                            0,0,0,
                                            -1,-2,-1,
                                            };

            Varyings vert (Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.texcoord;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 FinalColor;
                // half2 screenUV = i.positionHCS / _ScreenParams.xy;

                float2 sobel = 0;    
                // //获得深度图
                float  depthMap = SAMPLE_TEXTURE2D(_CameraDepthTexture , sampler_CameraDepthTexture , i.uv).r; 
                // //转化为线性0-1深度，这样0.5就表示处于相机到farPlane一半的位置   
                depthMap = Linear01Depth(depthMap,_ZBufferParams);  
                // // //找到该像素离相机的真是距离，_ProjectionParams.z表示_Camera_FarPlane的距离。                         
                float  depthDistance= _ProjectionParams.z * depthMap;            
                float2 adaptiveThickness = float2(_ThicknessX , _ThicknessY);
                
                if(depthDistance <= 0)
                {
                    adaptiveThickness = float2(_MaxThickness,_MaxThickness);
                }
                else
                {
                    adaptiveThickness = adaptiveThickness / depthDistance;          //根据距离对边缘光厚度进行线性缩放
                }
                adaptiveThickness = min(adaptiveThickness , float2(_MaxThickness , _MaxThickness));

                for(int id = 0 ; id < 9 ; id++)
                {
                    float2 screenPos = i.uv + sobelSamplePoints[id] * adaptiveThickness;
                    float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture , sampler_CameraDepthTexture , screenPos).r;
                    depth = Linear01Depth(depth,_ZBufferParams);

                    sobel += depth * float2(sobelXMatrix[id] , sobelYMatrix[id]);
                }

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex , sampler_MainTex , i.uv);
                // half RimRange = step(_Distance , length(sobel) * _ProjectionParams.z);
                half4 rimLightColor = _RimLightColor * step(_Distance , length(sobel) * _ProjectionParams.z);               //计算rimLightColor的颜色

                FinalColor = mainTex + lerp(mainTex * rimLightColor , rimLightColor , _LerpValue) * _Intensity;

                // FinalColor = lerp(mainTex * _RimLightColor , _RimLightColor , _LerpValue) * _Intensity;

                return FinalColor;
            }
            ENDHLSL
        }
    }
}
