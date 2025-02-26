Shader "TechnicalArt/ASlime"
{
	Properties
	{
		[Header(Matcap)]
		[HDR]_BaseColor("BaseColor" , Color) = (1,1,1,1)
        [NoScaleOffset]_BaseMap("BaseMap" , 2D) = "white"{}
        [NoScaleOffset]_MatCap("MatCap" , 2D) = "white"{}
		[NoScaleOffset]_EmissiveMap("EmissiveMap" , 2D) = "white"{}
		
		[Space(20)]
		[Header(Fresnel)]
        _RimColor("RimColor" , Color) = (1,1,1,1)
        _RimBias("RimBias" , float) = 0
        _RimScale("RimScale" , float) = 1
        [PowerSlider(8)]_RimPower("RimPower" , Range(0.1, 20)) = 1
        
		[Space(20)]
		[Header(FlowMapProperty)]
        [NoScaleOffset]_TriPlaneNormal("TriPlaneNormal" , 2D) = "bump"{}
        _TriPlaneTile("TriPlaneTile X(rg) Y(gb) Z(rb)",float) = (2,2,2,0)
        _TriPlaneSpeed("TriPlaneSpeed X(rg) Y(gb) Z(rb)" , float) = (0,0,0,0)
        _TriPlaneContrast("TriPlaneContrast",float) = 1
		
		[Space(20)]
		[Header(NoiseProperty)]
		[NoScaleOffset]_NoiseMap("NoiseMap", 2D) = "white" {}
		_NoiseTile("NoiseTile", Float) = 1
		_NoiseContast("NoiseContast",Float) = 5
		_NoiseIntensity("NoiseIntensity", Vector) = (0.1,0.1,0.1,0)
		_NoiseSpeed("NoiseSpeed", Vector) = (0,0.3,-0.2,0)
	}
	SubShader
	{
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "UniversalMaterialType"="Lit" }
		LOD 100
		
		Pass
		{
			Tags { "LightMode"="UniversalForward" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "TriPlaneSampler.hlsl"
			#include "Property.hlsl"

			struct VertexInput
			{
				float4 positionOS	: POSITION;
				float3 normalOS		: NORMAL;
				float4 tangentOS	: TANGENT;
				float2 texcoord     : TEXCOORD0;
				float4 Color        : COLOR;
			};

			struct VertexOutput
			{
				float4 positionHCS	: SV_POSITION;
				float2 uv			: TEXCOORD0;
				float3 positionWS	: TEXCOORD1;
				float3 normalWS		: TEXCOORD2;
				float3 tangentWS    : TEXCOORD3;
                float3 bitangentWS  : TEXCOORD4;
                float3 viewDirWS    : TEXCOORD5;
                float4 vertexColor  : TEXCOORD6;
				float3 worldPosUV	: TEXCOORD7;
			};

			VertexOutput vert( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				o.positionWS = TransformObjectToWorld( (v.positionOS).xyz );
				o.normalWS = TransformObjectToWorldNormal(v.normalOS);

				//世界空间的投射采样Noise贴图，计算出灰度图遮罩
				float3 objToWorld31 = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
				o.worldPosUV =  ( o.positionWS - objToWorld31 ) * _NoiseTile  + ( _Time.y * _NoiseSpeed );
				float3 VertexNoise = TriplanarSampler( _NoiseMap , sampler_NoiseMap , o.worldPosUV , o.normalWS, _NoiseContast, float2( 1,1 ));
				float3 VertexOffset = VertexNoise.xyz * v.Color.xyz * o.normalWS * _NoiseIntensity.xyz ;
				v.positionOS.xyz += VertexOffset.xyz;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( v.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( v.normalOS, v.tangentOS );

				o.tangentWS = normalInput.tangentWS;
				o.bitangentWS = normalInput.bitangentWS;
				o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);

				o.positionHCS = vertexInput.positionCS;

				o.uv = v.texcoord;
				o.vertexColor = v.Color;

				return o;
			}

			half4 frag ( VertexOutput i) : SV_Target
			{
				half4 FinalColor;
				
				half3 worldViewDir = SafeNormalize(i.viewDirWS);
                half3 worldNormal_Obj = normalize(i.normalWS);	//模型的法线

				//计算菲涅尔遮罩（边缘黑-中间白）
                half  fresnel = pow(saturate(dot(worldNormal_Obj , worldViewDir)) , _RimPower) * _RimScale + _RimBias;
                half4 fresnelColor = fresnel * _RimColor;

                //TriPlaneMapping
                half3 worldSpaceUV = (i.positionWS - TransformObjectToWorld(half3(0,0,0))) * _TriPlaneTile.xyz + (_Time.y * _TriPlaneSpeed.xyz);
                half2 TriPlane_RG = worldSpaceUV.xy;
                half2 TriPlane_GB = worldSpaceUV.yz;
                half2 TriPlane_RB = worldSpaceUV.xz;
                half3 TriPlaneTex_RG = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_RG)).rgb;
                half3 TriPlaneTex_GB = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_GB)).rgb;
                half3 TriPlaneTex_RB = UnpackNormal(SAMPLE_TEXTURE2D(_TriPlaneNormal , sampler_TriPlaneNormal , TriPlane_RB)).rgb;
                half3 contrast = pow(abs(worldNormal_Obj) , _TriPlaneContrast);
                half3 weight = contrast / (contrast.x + contrast.y + contrast.z);
                half3 TriPlaneNormal_TS = (TriPlaneTex_RG * weight.z) + (TriPlaneTex_GB * weight.x) + (TriPlaneTex_RB * weight.y);
                
                half3 NormalRec = normalize(half3(worldNormal_Obj.x + TriPlaneNormal_TS.x , TriPlaneNormal_TS.y + worldNormal_Obj.y , worldNormal_Obj.z));
                half3 viewNormalDir = TransformWorldToViewDir(NormalRec.xyz);	//视图空间法线

				//颜色混合--漫反射颜色
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap , i.uv);
                
                half2 matCapUV = viewNormalDir.xy * 0.5 + 0.5;
                half4 matCapMap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap , matCapUV) * _BaseColor;

                half4 emissiveMap = SAMPLE_TEXTURE2D(_EmissiveMap,sampler_EmissiveMap , i.uv);
                half4 emissiveColor = emissiveMap * fresnelColor;

                FinalColor = half4(baseMap.rgb * matCapMap.rgb + emissiveColor.rgb ,1.0);

				return FinalColor;
			}
			ENDHLSL
		}
	}
	Fallback Off
}
