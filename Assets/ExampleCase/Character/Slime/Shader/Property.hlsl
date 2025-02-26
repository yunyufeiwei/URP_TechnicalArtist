#ifndef PROPERTY_INCLUDED
#define PROPERTY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D(_BaseMap)	;SAMPLER(sampler_BaseMap);
TEXTURE2D(_MatCap)	;SAMPLER(sampler_MatCap);
TEXTURE2D(_NoiseMap);SAMPLER(sampler_NoiseMap);
TEXTURE2D(_TriPlaneNormal);SAMPLER(sampler_TriPlaneNormal);
TEXTURE2D(_EmissiveMap);SAMPLER(sampler_EmissiveMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float4 _BaseMap_ST;
    float4 _RimColor;
    float  _RimBias;
    float  _RimScale;
    float  _RimPower;
    float4 _TriPlaneTile;
    float4 _TriPlaneSpeed;
    float  _TriPlaneContrast;
    float3 _NoiseSpeed;
    float  _NoiseContast;
    float  _NoiseTile;
    float4 _NoiseIntensity;
CBUFFER_END

#endif
