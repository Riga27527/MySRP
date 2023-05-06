#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface
{
    float3 position;
    float3 normal;
    float3 color;
    float depth;
    float alpha;
    float metallic;
    float smoothness;
    float fresnelStrength;

    float3 viewDirection;
    float dither;
};

#endif