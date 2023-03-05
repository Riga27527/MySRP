#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
int _CascadeCount;
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
float4 _CascadeData[MAX_CASCADE_COUNT];
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
float4 _ShadowDistanceFade;
float4 _ShadowAtlasSize;
CBUFFER_END

#if defined(_DIRECTIONAL_PCF3)
#define DIRECTIONAL_FILTER_SAMPLES 4
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
#define DIRECTIONAL_FILTER_SAMPLES 9
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
#define DIRECTIONAL_FILTER_SAMPLES 16
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

struct DirectionalShadowData
{
    float strength;
    int tileIndex;

    float normalBias;
};

struct ShadowData
{
    int cascadeIndex;
    // whether sample the shadow
    float strength;
    // blend shadow
    float cascadeBlend;
};

float FadedShadowStrength(float distance, float scale, float fade)
{
    return saturate((1.0 - distance * scale) * fade);
}

float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

float FilterDirectionalShadow(float3 positionSTS)
{
#if defined(DIRECTIONAL_FILTER_SETUP)
    float weights[DIRECTIONAL_FILTER_SAMPLES];
    float2 positions[DIRECTIONAL_FILTER_SAMPLES];
    float4 size = _ShadowAtlasSize.yyxx;
    DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
    float shadow = 0;
    for(int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; ++i)
    {
        shadow += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy, positionSTS.z));
    }
    return shadow;
#else
    return SampleDirectionalShadowAtlas(positionSTS);
#endif
}

ShadowData GetShadowData(Surface surface)
{
    ShadowData data;
    data.cascadeIndex = 0;
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surface.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
    for(int i = 0; i < _CascadeCount; ++i)
    {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surface.position, sphere.xyz);
        if(distanceSqr < sphere.w)
        {   
            float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
            if(i == _CascadeCount - 1)
                data.strength *= FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
#if defined(_CASCADE_BLEND_DITHER)
            else if(fade < surface.dither)
                i += 1;
#endif
#if defined(_CASCADE_BLEND_SOFT)
            else
                data.cascadeBlend = fade;
#endif
            data.cascadeIndex = i;    
            return data;
        }
    }
    data.strength = 0.f;
    return data; 
}

float GetDirectionalShadowAttenuation(DirectionalShadowData data, ShadowData shadowData, Surface surfaceWS)
{
    if(data.strength <= 0.0)
        return 1.0;
    
    float3 normalBias = surfaceWS.normal * (data.normalBias * _CascadeData[shadowData.cascadeIndex].y);
    float3 positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);

    if(shadowData.cascadeBlend < 1.0)
    {
        normalBias = surfaceWS.normal * (data.normalBias * _CascadeData[shadowData.cascadeIndex + 1].y);
        positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;
        shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, shadowData.cascadeBlend);      
    }

    return lerp(1.0, shadow, data.strength);
}

#endif