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
    // current Count
    int shadowedDirectionalLightCount;
    
    static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");

    static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");

    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
    }

    ShadowedDirectionalLight[] shadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount];
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

    public Vector2 ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        if(shadowedDirectionalLightCount < maxShadowedDirectionalLightCount 
            && light.shadows != LightShadows.None 
            && light.shadowStrength > 0f
            && cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
            {
                shadowedDirectionalLights[shadowedDirectionalLightCount] = new ShadowedDirectionalLight{ visibleLightIndex = visibleLightIndex};
                return new Vector2(light.shadowStrength, shadowedDirectionalLightCount++);
            }
        return Vector2.zero;
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

        int split = shadowedDirectionalLightCount <= 1 ? 1 : 2;
        int tileSize = atlasSize / split;

        for(int i = 0; i < shadowedDirectionalLightCount; ++i)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }
        
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        ShadowedDirectionalLight light = shadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex, BatchCullingProjectionType.Unknown);
        cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(light.visibleLightIndex, 0, 1, Vector3.zero, tileSize, 0f, 
        out Matrix4x4 viewMatrix, out Matrix4x4 projMatrix, out ShadowSplitData splitData);

        shadowSettings.splitData = splitData;
        // Set rendering viewport
        Vector2 offest = SetTileViewport(index, split, tileSize);

        dirShadowMatrices[index] = ConvertToAtlasMatrix(projMatrix * viewMatrix, offest, split);
        // Set project matrix
        buffer.SetViewProjectionMatrices(viewMatrix, projMatrix);
        
        ExecuteBuffer();
        context.DrawShadows(ref shadowSettings);
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