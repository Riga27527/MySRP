#ifndef CUSTOM_UNITY_INPUT_INCLUEDED
#define CUSTOM_UNITY_INPUT_INCLUEDED

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
float4 unity_WorldTransformParams;
CBUFFER_END

float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;

float4x4 unity_MatrixVP;
float4x4 glstate_matrix_projection;

float4x4 unity_PreObjectToWorld;
float4x4 unity_PreWorldToObject;

float3 _WorldSpaceCameraPos;

#endif