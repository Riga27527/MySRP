#ifndef CUSTOM_LIT_PASS_INCLUEDED
#define CUSTOM_LIT_PASS_INCLUEDED

// #include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
// CBUFFER_START(UnityPerMaterial)
//     float4 _BaseColor;
// CBUFFER_END

// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);

// 4. setup UnityPerMaterial buffer property
// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)

// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
// UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
// UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
// UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
// UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)

// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// 3. add UNITY_VERTEX_INPUT_INSTANCE_ID
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    float3 normalOS : NORMAL;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float2 baseUV : VAR_BASE_UV;
    float3 normalWS : VAR_NORMAL;
    GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 5. get and transfer INSTANCE_ID in vertex shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_GI_DATA(input, output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

// 6. get INSTANCE_ID and access INSTANCE_PROP in UnityPerMaterial buffer
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    ClipLOD(input.positionCS.xy, unity_LODFade.x);
    float4 base = GetBase(input.baseUV);
    
#if defined(_CLIPPING)
    float cutoff_threshold = GetCutoff(input.baseUV);
    clip(base.a - cutoff_threshold);
#endif

    Surface surface;
    surface.position = input.positionWS;
    surface.normal = normalize(input.normalWS);
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = GetMetallic(input.baseUV);
    surface.smoothness = GetSmoothness(input.baseUV);
    surface.fresnelStrength = GetFresnel(input.baseUV);
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
    surface.depth = -TransformWorldToView(input.positionWS).z;
#if defined(_PREMULTIPLY_ALPHA)
    BRDF brdf = GetBRDF(surface, true);
#else
    BRDF brdf = GetBRDF(surface);
#endif
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
    float3 color = GetLighting(surface, brdf, gi);
    color += GetEmission(input.baseUV);
    return float4(color, surface.alpha);
}


#endif