#ifndef CUSTOM_UNLIT_PASS_INCLUEDED
#define CUSTOM_UNLIT_PASS_INCLUEDED

// #include "../ShaderLibrary/Common.hlsl"

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

// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// 3. add UNITY_VERTEX_INPUT_INSTANCE_ID
struct Attributes
{
    float3 positionOS : POSITION;
    float2 baseUV : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 baseUV : VAR_BASE_UV;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 5. get and transfer INSTANCE_ID in vertex shader
Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

// 6. get INSTANCE_ID and access INSTANCE_PROP in UnityPerMaterial buffer
float4 UnlitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 base = GetBase(input.baseUV);
    
#if defined(_CLIPPING)
    float cutoff_threshold = GetCutoff(input.baseUV);
    clip(color.a - cutoff_threshold);
#endif

    return base;
}


#endif