#ifndef UNITY_COMMON_INCLUEDED
#define UNITY_COMMON_INCLUEDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "UnityInput.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_I_V unity_MatrixInvV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection
// Not right !! can't find any defined
#define UNITY_PREV_MATRIX_M unity_PreObjectToWorld
#define UNITY_PREV_MATRIX_I_M unity_PreWorldToObject

// 2. import UnityInstancing.hlsl
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

float Square(float v)
{
    return v * v;
}
#endif