using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

using System.Collections.Generic;

public class StencilOverrideRendererFeature : ScriptableRendererFeature
{
    // Stencil override pass
    // For deferred renderer, if a stencil operation is defined in a forward pass (UniversalForwardOnly),
    // deferred renderer will overwrite it, so we need to manually set the stencil state in a custom RendererFeature
    // (NOTE: This can also be done with RenderObjects)

    [System.Serializable]
    public class StencilOverrideSettings
    {
        public string profilerTag = "StencilOverrideRendererFeature";

        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public LayerMask layerMask = -1;
    }

    public class StencilOverrideRenderPass : ScriptableRenderPass
    {
        private string profilerTag;

        private FilteringSettings filteringSettings;

        private List<ShaderTagId> shaderTagIds;

        private RenderStateBlock renderStateBlock;

        public StencilOverrideRenderPass(string profilerTag, RenderPassEvent renderPassEvent, LayerMask layerMask)
        {
            this.profilerTag = profilerTag;
            this.profilingSampler = new ProfilingSampler(profilerTag);

            // RenderPassEvent
            this.renderPassEvent = renderPassEvent;

            // Filtering settings
            // Set to opaque
            this.filteringSettings = new FilteringSettings(RenderQueueRange.opaque, layerMask);

            // Target material shader pass names
            this.shaderTagIds = new List<ShaderTagId>();
            this.shaderTagIds.Add(new ShaderTagId("UniversalForward"));
            this.shaderTagIds.Add(new ShaderTagId("UniversalForwardOnly"));
            this.shaderTagIds.Add(new ShaderTagId("SRPDefaultUnlit"));

            // Render state block (to override stencil state)
            this.renderStateBlock = new RenderStateBlock(RenderStateMask.Stencil);
            this.renderStateBlock.stencilReference = 1; // Stencil Ref for outline mask is 1 (see UTJSample-LitToonStencil.shader)
            this.renderStateBlock.stencilState = new StencilState(true, 255, 1, CompareFunction.Always, StencilOp.Replace, StencilOp.Keep);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Camera data
            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;

            // Sorting criteria (default for now)
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;

            // DrawingSettings
            DrawingSettings drawingSettings = CreateDrawingSettings(this.shaderTagIds, ref renderingData, sortingCriteria);

            // Run (draw renderers with render state block overriding stencil state)
            CommandBuffer cmd = CommandBufferPool.Get(this.profilerTag);
            using (new ProfilingScope(cmd, this.profilingSampler)) {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref this.filteringSettings, ref this.renderStateBlock);
            }

            context.ExecuteCommandBuffer(cmd);

            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }

    public StencilOverrideSettings settings = new StencilOverrideSettings();

    private StencilOverrideRenderPass renderPass;

    public override void Create()
    {
        this.renderPass = new StencilOverrideRenderPass(
            settings.profilerTag,
            settings.renderPassEvent,
            settings.layerMask
        );
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(this.renderPass);
    }
}