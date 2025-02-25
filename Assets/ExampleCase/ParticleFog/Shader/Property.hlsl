#ifndef PROPERTY_INCLUDE
#define PROPERTY_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _Color;
    float3 _SimplexNoiseAnimation;
    float3 _VoronoiNoiseAnimation;
    float2 _SimpleNoiseAnimation;
    float _SurfaceDepthFade;
    float _CombinedNoiseRemap;
    float _VoronoiNoiseAmount;
    float _VoronoiNoiseRemap;
    float _VoronoiScale;
    float _SimplexNoiseAmount;
    float _SimplexNoiseRemap;
    float _SimplexNoiseScale;
    float _SimpleNoiseAmount;
    float _SimpleNoiseRemap;
    float _SimpleNoiseScale;
    float _CameraDepthFadeRange;
    float _CameraDepthFadeOffset;
CBUFFER_END

#endif
