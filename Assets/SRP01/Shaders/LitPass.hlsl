#ifndef CUSTOM_LIT_PASS_INCLUEDED
#define CUSTOM_LIT_PASS_INCLUEDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
// CBUFFER_START(UnityPerMaterial)
//     float4 _BaseColor;
// CBUFFER_END

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

// 4. setup UnityPerMaterial buffer property
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)

UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)

UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// 3. add UNITY_VERTEX_INPUT_INSTANCE_ID
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 baseUV : VAR_BASE_UV;
    float3 normalWS : VAR_NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 5. get and transfer INSTANCE_ID in vertex shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);

    output.normalWS = TransformObjectToWorldNormal(input.normalOS);

    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    return output;
}

// 6. get INSTANCE_ID and access INSTANCE_PROP in UnityPerMaterial buffer
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    float4 base = baseMap * baseColor;
    
#if defined(_CLIPPING)
    float cutoff_threshold = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
    clip(base.a - cutoff_threshold);
#endif

    Surface surface;
    surface.normal = normalize(input.normalWS);
    surface.color = base.rgb;
    surface.alpha = base.a;
    
    float3 color = GetLighting(surface);

    return float4(color, surface.alpha);
}


#endif