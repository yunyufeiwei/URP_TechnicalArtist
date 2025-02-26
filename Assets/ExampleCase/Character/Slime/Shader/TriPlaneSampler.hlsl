#ifndef TRIPLANESAMPLER_INCLUDED
#define TRIPLANESAMPLER_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float3 TriplanarSampler( Texture2D NoiseMap , SamplerState samplerNoise , float3 worldPos, float3 worldNormal, float falloff, float2 tiling)
{
	float3 projNormal = pow( abs( worldNormal ), falloff );
	projNormal /= ( projNormal.x + projNormal.y + projNormal.z ) + 0.00001;
	float3 nsign = sign( worldNormal );
				
	half4 xNorm , yNorm , zNorm;
	xNorm = SAMPLE_TEXTURE2D_LOD( NoiseMap , samplerNoise , float2(tiling * worldPos.zy * float2(  nsign.x, 1.0 )) ,0);
	yNorm = SAMPLE_TEXTURE2D_LOD( NoiseMap , samplerNoise , float2(tiling * worldPos.xz * float2(  nsign.y, 1.0 )) ,0);
	zNorm = SAMPLE_TEXTURE2D_LOD( NoiseMap , samplerNoise , float2(tiling * worldPos.xy * float2( -nsign.z, 1.0 )) ,0);
	half aniNoiseValue = half4(xNorm * projNormal.x + yNorm * projNormal.y + zNorm * projNormal.z).r;
				
	return aniNoiseValue;
}

#endif
