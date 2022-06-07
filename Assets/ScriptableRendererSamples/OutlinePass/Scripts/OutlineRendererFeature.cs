using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

using System.Collections.Generic;

public class OutlineRendererFeature : ScriptableRendererFeature
{
    // Render outline pass (NOTE: This can also be done with RenderObjects)

    [System.Serializable]
    public class OutlineSettings
    {
        public string profilerTag = "OutlineRendererFeature";

        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public LayerMask layerMask = -1;

        public Material material;
    }

    public class OutlineRenderPass : ScriptableRenderPass
    {
        private string profilerTag;

        private Material material;

        private FilteringSettings filteringSettings;

        private List<ShaderTagId> shaderTagIds;

        public OutlineRenderPass(string profilerTag, RenderPassEvent renderPassEvent, LayerMask layerMask, Material material)
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

            this.material = material;
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

            // Always use pass 0 of shader
            drawingSettings.overrideMaterial = this.material;
            drawingSettings.overrideMaterialPassIndex = 0;

            // Run (draw renderers)
            CommandBuffer cmd = CommandBufferPool.Get(this.profilerTag);
            using (new ProfilingScope(cmd, this.profilingSampler)) {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref this.filteringSettings);
            }

            context.ExecuteCommandBuffer(cmd);

            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
    }

    public OutlineSettings settings = new OutlineSettings();

    private OutlineRenderPass renderPass;

    public override void Create()
    {
        this.renderPass = new OutlineRenderPass(
            settings.profilerTag,
            settings.renderPassEvent,
            settings.layerMask,
            settings.material
        );
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(this.renderPass);
    }
}