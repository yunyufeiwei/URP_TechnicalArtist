Shader "Miami/VFX/LocalFog"
{
	Properties
	{
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HDR]_Color("Color", Color) = (1,1,1,1)
		
		_SimpleNoiseScale("Simple Noise Scale", Float) = 20
		_SimpleNoiseAmount("Simple Noise Amount", Range( 0 , 1)) = 0.25
		_SimpleNoiseRemap("Simple Noise Remap", Range( 0 , 1)) = 0
		_SimpleNoiseAnimation("Simple Noise Animation", Vector) = (0,0,0,0)
		
		_SimplexNoiseScale("Simplex Noise Scale", Float) = 4
		_SimplexNoiseAmount("Simplex Noise Amount", Range( 0 , 1)) = 0.25
		_SimplexNoiseRemap("Simplex Noise Remap", Range( 0 , 1)) = 0
		_SimplexNoiseAnimation("Simplex Noise Animation", Vector) = (0,0,0.02,0)
		
		_VoronoiScale("Voronoi Scale", Float) = 5
		_VoronoiNoiseAmount("Voronoi Noise Amount", Range( 0 , 1)) = 0.5
		_VoronoiNoiseRemap("Voronoi Noise Remap", Range( 0 , 1)) = 0
		_VoronoiNoiseAnimation("Voronoi Noise Animation", Vector) = (0,0,0,0)

		_CombinedNoiseRemap("Combined Noise Remap", Range( 0 , 1)) = 0
		
		_SurfaceDepthFade("Surface Depth Fade", Float) = 0
		_CameraDepthFadeRange("Camera Depth Fade Range", Float) = 0
		
		_CameraDepthFadeOffset("Camera Depth Fade Offset", Float) = 0
	}

	SubShader
	{
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
		LOD 0
		ZWrite Off
		ZTest LEqual
		AlphaToMask Off
		Offset 0 , 0
		Cull Back
		ColorMask RGBA
		
		Pass
		{
			Tags { "LightMode"="UniversalForward" }
			
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			// #pragma multi_compile_instancing
			// #define ASE_SRP_VERSION 100700
			#define REQUIRE_DEPTH_TEXTURE 1

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

			#include  "CustomNoiseFunction.hlsl"
			#include "Property.hlsl"

			struct Attributes
			{
				float4 positionOS	: POSITION;
				float3 worldNormal  : NORMAL;
				float4 color		: COLOR;
				float4 texcoord		: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
				float4 color		: COLOR;
				float4 positionHCS	: SV_POSITION;
				float3 positionWS	: TEXCOORD0;
				float4 uv			: TEXCOORD3;
				float4 texcoord4	: TEXCOORD4;
				float4 eyeDepthUV	: TEXCOORD5;
				float4 screePos		: TEXCOORD6;    //用于软接触的位置
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			TEXTURE2D (_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);
			
			Varyings vert(Attributes v)
			{
				Varyings o = (Varyings)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.positionHCS = TransformObjectToHClip((v.positionOS).xyz);
				o.positionWS = TransformObjectToWorld( v.positionOS.xyz );
				o.screePos = ComputeScreenPos(o.positionHCS);

				float3 objectToViewPos = TransformWorldToView(TransformObjectToWorld(v.positionOS.xyz));
				float eyeDepth = -objectToViewPos.z;

				o.uv = v.texcoord;
				o.eyeDepthUV.x = eyeDepth;
				
				o.color = v.color;
				
				return o;
			}

			half4 frag ( Varyings i  ) : SV_Target
			{
				half4 FinalColor;
				
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				float3 worldPosition = i.positionWS;
				float4 ShadowCoords = float4( 0, 0, 0, 0 );

				float ParticleStableRandom43 = i.uv.z;

				//第一层噪声计算
				float2 simpleNoiseUV = i.uv.xy * float2( 1,1 ) + ( ( _SimpleNoiseAnimation * _TimeParameters.x ) + ( ParticleStableRandom43 * 10.0 ) );
				//通过SimpleNoise函数计算，得到噪声图
				float simpleNoise = SimpleNoise( simpleNoiseUV * _SimpleNoiseScale );
				//通过simpleNoise1减去一个值，得到另一个噪声图
				float SimpleNoiseOffset = saturate( (0.0 + (simpleNoise - _SimpleNoiseRemap) * (1.0 - 0.0) / (1.0 - _SimpleNoiseRemap)) );
				float firstSimpleNoise = lerp( 1.0 , SimpleNoiseOffset , _SimpleNoiseAmount);

				//第二层噪声的计算
				float2 simplePerlinUV = i.uv.xy * float2( 1,1 ) + float2( 0,0 );
				float simplePerlin = snoise( ( float3( simplePerlinUV ,  0.0 ) + ( _SimplexNoiseAnimation * _TimeParameters.x ) + ( ParticleStableRandom43 * 20.0 ) )*_SimplexNoiseScale );
				simplePerlin = simplePerlin * 0.5 + 0.5;
				float SimplexPerlinOffset = saturate( (0.0 + (simplePerlin - _SimplexNoiseRemap) * (1.0 - 0.0) / (1.0 - _SimplexNoiseRemap)) );
				float SecondSimpleNoise = lerp( 1.0 , SimplexPerlinOffset , _SimplexNoiseAmount);

				//第三层噪声的计算
				float time = _TimeParameters.x * _VoronoiNoiseAnimation.z;
				float2 id2 = 0;
				float2 uv2 = 0;
				float2 voronoiSmoothId2 = 0;
				float2 voronoiNoiseUV = (i.uv.xy * float2( 1,1 ) + ( (_VoronoiNoiseAnimation).xy * _TimeParameters.x )) * _VoronoiScale ;
				float  voronoiNoise = voronoi2( voronoiNoiseUV, time, id2, uv2, 0, voronoiSmoothId2 );
				float  VoronoiNoiseOffset = saturate( (0.0 + (voronoiNoise - _VoronoiNoiseRemap) * (1.0 - 0.0) / (1.0 - _VoronoiNoiseRemap)) );
				float ThirdSimpleNoise = lerp( 1.0 , VoronoiNoiseOffset , _VoronoiNoiseAmount);

				//噪声混合
				float TotleNoiseBlend = ( firstSimpleNoise * SecondSimpleNoise * ThirdSimpleNoise );
				float TotleNoiseOffset = saturate( (0.0 + (TotleNoiseBlend - _CombinedNoiseRemap) * (1.0 - 0.0) / (1.0 - _CombinedNoiseRemap)) );

				//控制接触点的融合衰减
				float4 screenUV = i.screePos / i.screePos.w;
				screenUV.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? screenUV.z : screenUV.z * 0.5 + 0.5;
				float4 depthMap = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,screenUV.xy);
				float  screenDepth = LinearEyeDepth(depthMap.r , _ZBufferParams);
				float  distanceDepth = saturate(abs(screenDepth - LinearEyeDepth(screenUV.z , _ZBufferParams)) / _SurfaceDepthFade);

				//计算一个相机距离的偏移，当相机里目标物体太近时，让物体衰减直到完全透明
				float eyeDepth = i.eyeDepthUV.x;
				float cameraDepthFade = saturate(( eyeDepth -_ProjectionParams.y - _CameraDepthFadeOffset ) / _CameraDepthFadeRange);

				//计算一个球形的遮罩，这样就不需要再材质面板上制定一个遮罩图
				float2 sphereUV = i.uv.xy * float2( 2,2 ) + float2( -1,-1 );
				float sphereMask = saturate( ( 1.0 - length( sphereUV ) ) );

				//最终输出颜色
				float4 Color = _Color * i.color;
				float  Alpha = saturate( ( TotleNoiseOffset * distanceDepth * cameraDepthFade * sphereMask * Color.a ) );

				FinalColor = half4(Color.rgb , Alpha);
				
				return FinalColor;
			}
			ENDHLSL
		}
	}
	Fallback "Hidden/InternalErrorShader"
}
