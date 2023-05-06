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

// directional light shadow data
struct DirectionalShadowData
{
    float strength;
    int tileIndex;

    float normalBias;
    int shadowMaskChannel;
};

struct ShadowMask
{
    bool always;
    bool distance;
    float4 shadows;
};

// global shadow data
struct ShadowData
{
    int cascadeIndex;
    // whether sample the shadow
    float strength;
    // blend shadow
    float cascadeBlend;
    ShadowMask shadowMask;
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
    data.shadowMask.always = false;
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0;
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

float GetCascadedShadow(DirectionalShadowData dirData, ShadowData shadowData, Surface surfaceWS)
{
    float3 normalBias = surfaceWS.normal * (dirData.normalBias * _CascadeData[shadowData.cascadeIndex].y);
    float3 positionSTS = mul(_DirectionalShadowMatrices[dirData.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);

    if (shadowData.cascadeBlend < 1.0)
    {
        normalBias = surfaceWS.normal * (dirData.normalBias * _CascadeData[shadowData.cascadeIndex + 1].y);
        positionSTS = mul(_DirectionalShadowMatrices[dirData.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;
        shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, shadowData.cascadeBlend);
    }
    return shadow;
}
float GetBakedShadow(ShadowMask mask, int channel)
{
    float shadow = 1.0;
    if (mask.always || mask.distance)
    {
        if(channel >= 0)
            shadow = mask.shadows[channel];
    }
    return shadow;
}

float GetBakedShadow(ShadowMask mask, int channel, float dirStrength)
{
    if (mask.always || mask.distance)
    {
        return lerp(1.0, GetBakedShadow(mask, channel), dirStrength);
    }
    return 1.0;
}

float MixBakedAndRealtimeShadows(ShadowData shadowData, float shadow, int shadowMaskChannel, float dirStrength)
{
    float baked = GetBakedShadow(shadowData.shadowMask, shadowMaskChannel);
    if (shadowData.shadowMask.always)
    {
        shadow = lerp(1.0, shadow, shadowData.strength);
        shadow = min(shadow, baked);
        return lerp(1.0, shadow, dirStrength);
    }
    if (shadowData.shadowMask.distance)
    {
        shadow = lerp(baked, shadow, shadowData.strength);
        return lerp(1.0, shadow, dirStrength);
    }
    return lerp(1.0, shadow, dirStrength * shadowData.strength);
}

float GetDirectionalShadowAttenuation(DirectionalShadowData dirData, ShadowData shadowData, Surface surfaceWS)
{
#if !defined(_RECEIVE_SHADOWS)
    return 1.0;
#endif

    if(dirData.strength * shadowData.strength <= 0.0)
        return GetBakedShadow(shadowData.shadowMask, dirData.shadowMaskChannel, abs(dirData.strength));
    
    // Mix the realtime shadow and baked shadow
    float shadow = GetCascadedShadow(dirData, shadowData, surfaceWS);
    shadow = MixBakedAndRealtimeShadows(shadowData, shadow, dirData.shadowMaskChannel, dirData.strength);

    return shadow;
}

#endif