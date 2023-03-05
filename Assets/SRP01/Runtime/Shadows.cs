using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;

public class Shadows
{
    const string bufferName = "Shadows";    
    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };
    
    ScriptableRenderContext context;
    CullingResults cullingResults;
    ShadowSettings settings;

    // Max Count
    const int maxShadowedDirectionalLightCount = 4;
    const int maxCascades = 4;

    // current Count
    int shadowedDirectionalLightCount;
    
    static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    static int cascadeCountId = Shader.PropertyToID("_CascadeCount");
    static int cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    static int shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");
    static int cascadeDataId = Shader.PropertyToID("_CascadeData");

    static Vector4 [] cascadeCullingSpheres = new Vector4[maxCascades];
    static Vector4 [] cascadeData = new Vector4[maxCascades];

    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float nearPlaneOffset;
    }

    ShadowedDirectionalLight[] shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];
    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];
    // RenderTexture shadowMap;

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings settings)
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        this.shadowedDirectionalLightCount = 0;
    }

    void ExecuteBuffer()
    {
        // Debug.Log(context);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    public Vector3 ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        if(shadowedDirectionalLightCount < maxShadowedDirectionalLightCount 
            && light.shadows != LightShadows.None 
            && light.shadowStrength > 0f
            && cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
            {
                shadowedDirectionalLights[shadowedDirectionalLightCount] = new ShadowedDirectionalLight{ 
                    visibleLightIndex = visibleLightIndex, 
                    slopeScaleBias = light.shadowBias,
                    nearPlaneOffset = light.shadowNearPlane};
                return new Vector3(light.shadowStrength, settings.directional.cascadeCount * shadowedDirectionalLightCount++, light.shadowNormalBias);
            }
        return Vector3.zero;
    }

    public void Render()
    {
        if(shadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();    
        }
    }

    void RenderDirectionalShadows()
    {
        int atlasSize = (int) settings.directional.atlasSize;

        // shadowMap = RenderTexture.GetTemporary(atlasSize, atlasSize, 32, RenderTextureFormat.Shadowmap);
        // shadowMap.filterMode = FilterMode.Bilinear;
        // shadowMap.wrapMode = TextureWrapMode.Clamp;

        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        // CoreUtils.SetRenderTarget(buffer, shadowMap, 
        // RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, ClearFlag.Depth);
        
        buffer.ClearRenderTarget(true, false, Color.clear);
        
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        int tiles = shadowedDirectionalLightCount * settings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : (tiles <= 4 ? 2 : 4);
        int tileSize = atlasSize / split;

        for(int i = 0; i < shadowedDirectionalLightCount; ++i)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }
        
        buffer.SetGlobalInt(cascadeCountId, maxCascades);
        buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(shadowDistanceFadeId, new Vector4(1f / settings.maxDistance, 1f / settings.distanceFade, 1f / (1f - f * f)));
        
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        ShadowedDirectionalLight light = shadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex, BatchCullingProjectionType.Unknown);
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;
        for(int i = 0; i < cascadeCount; ++i)
        {
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(light.visibleLightIndex, i, cascadeCount, ratios, tileSize, light.nearPlaneOffset, 
            out Matrix4x4 viewMatrix, out Matrix4x4 projMatrix, out ShadowSplitData splitData);   

            if(index == 0)
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }

            shadowSettings.splitData = splitData;
    
            int tileIndex = tileOffset + i;
            // Set rendering viewport
            Vector2 offest = SetTileViewport(tileIndex, split, tileSize);

            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projMatrix * viewMatrix, offest, split);
            // Set project matrix
            buffer.SetViewProjectionMatrices(viewMatrix, projMatrix);

            buffer.SetGlobalDepthBias(0f, light.slopeScaleBias); 
            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
            buffer.SetGlobalDepthBias(0f, 0f);            
        }
    }
    
    void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        // Sphere's diameter divides tileSize to get texelSize
        float texelSize = 2f * cullingSphere.w / tileSize;
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;
        cascadeData[index] = new Vector4(1f / cullingSphere.w, texelSize * 1.4142136f);
    }

    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);

        buffer.SetViewport(new Rect(offset.x * tileSize, offset.y * tileSize, tileSize, tileSize));
        
        return offset;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        if(SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }

        float scale = 1f / split;
        Matrix4x4 scaleOffset = Matrix4x4.identity;
        scaleOffset.m00 = scaleOffset.m11 = scale * 0.5f;
        scaleOffset.m03 = (0.5f + offset.x) * scale;
        scaleOffset.m13 = (0.5f + offset.y) * scale;
        scaleOffset.m22 = scaleOffset.m23 = 0.5f;

        return scaleOffset * m;
    }

    public void Cleanup()
    {
        // if(shadowMap){
        //     Debug.Log("111");
        //     RenderTexture.ReleaseTemporary(shadowMap);
        //     shadowMap = null;
        // }
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }
}