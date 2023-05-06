#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

float3 GetLighting(Surface surface, BRDF brdf, Light light)
{
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

float3 GetLighting(Surface surface, BRDF brdf, GI gi)
{
    ShadowData shadowData = GetShadowData(surface);
    shadowData.shadowMask = gi.shadowMask;
    //return gi.shadowMask.shadows.rgb;
    float3 color = 0.0;
    for(int i = 0; i < GetDirectionalLightCount(); ++i)
    {
        Light light = GetDirectionalLight(i, surface, shadowData);
        color += GetLighting(surface, brdf, light);
    }
    // indirect lighting
    float3 indirectColor = IndirectBRDF(surface, brdf, gi.diffuse, gi.specular);
    return color + indirectColor;
    //return color + gi.diffuse * brdf.diffuse;
    // return color;
}


#endif