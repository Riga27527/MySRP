using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;
    Camera camera;
    CullingResults cullingResults;
    const string bufferName = "Render Camera";

    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");

    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    public void Render(ScriptableRenderContext context, Camera camera)
    {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();

        PrepareForSceneWindow();

        if(!Cull())
        {
            return;
        }

        Setup();
        DrawVisibleGeometry();
        DrawUnsupportedShaders();
        DrawGizmos();
        Submit();
    }

    void Setup()
    {
        context.SetupCameraProperties(camera);

        CameraClearFlags flags = camera.clearFlags;

        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth, 
            flags == CameraClearFlags.Color, 
            flags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear);

        buffer.BeginSample(bufferName);
        ExecuteBuffer();
    }
    
    void DrawVisibleGeometry()
    {
        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque
        };

        // Set shaderPass and sorting mode
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
        // Set renderQueue
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        
        // 1. Draw opaque objects
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        // 2. Draw Skybox
        context.DrawSkybox(camera);
        
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;

        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        // 3. Draw transparent objects
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

    }

    void Submit()
    {
        buffer.EndSample(bufferName);
        ExecuteBuffer();
        context.Submit();
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    bool Cull()
    {
        ScriptableCullingParameters p;

        if(camera.TryGetCullingParameters(out p))
        {
            cullingResults = context.Cull(ref p);
            return true;
        }

        return false;
    }
}
