using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

using System.Collections.Generic;

public class UITextureRendererFeature : ScriptableRendererFeature
{
    // Render UI into separate render target

    public const string UI_TEXTURE_NAME = "_UITexture";

    [System.Serializable]
    public class UITextureSettings
    {
        public string profilerTag = "UITextureRendererFeature";

        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        public LayerMask layerMask = -1;

        public Material material;
    }

    public class UITextureRenderPass : ScriptableRenderPass
    {
        private string profilerTag;

        private Material material;

        private RenderTargetHandle uiRenderTexture;

        private FilteringSettings filteringSettings;

        private List<ShaderTagId> shaderTagIds;

        public UITextureRenderPass(string profilerTag, RenderPassEvent renderPassEvent, LayerMask layerMask, Material material)
        {
            this.profilerTag = profilerTag;
            this.profilingSampler = new ProfilingSampler(profilerTag);

            // RenderPassEvent
            this.renderPassEvent = renderPassEvent;

            // Filtering settings
            // Set to transparent for UI
            this.filteringSettings = new FilteringSettings(RenderQueueRange.transparent, layerMask);

            // Pass names
            this.shaderTagIds = new List<ShaderTagId>();
            this.shaderTagIds.Add(new ShaderTagId("SRPDefaultUnlit"));

            this.material = material;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // Called before Execute

            // Render texture for UI
            this.uiRenderTexture = new RenderTargetHandle();
            this.uiRenderTexture.Init(UITextureRendererFeature.UI_TEXTURE_NAME);

            // Render texture with camera texture's descriptor
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            desc.colorFormat = RenderTextureFormat.ARGB32;
            cmd.GetTemporaryRT(this.uiRenderTexture.id, desc);

            // Set uiTextureRenderTexture as render target to draw UI into
            ConfigureTarget(this.uiRenderTexture.id);

            // Clear
            ConfigureClear(ClearFlag.All, new Color(0f, 0f, 0f, 0f));
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Camera data
            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;

            // Sorting criteria (default for now)
            SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;

            // DrawingSettings for ui
            DrawingSettings drawingSettings = CreateDrawingSettings(this.shaderTagIds, ref renderingData, sortingCriteria);
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

        public override void FrameCleanup(CommandBuffer cmd)
        {
            // Release render texture

            cmd.ReleaseTemporaryRT(this.uiRenderTexture.id);
        }
    }

    public UITextureSettings settings = new UITextureSettings();

    private UITextureRenderPass renderPass;

    public override void Create()
    {
        this.renderPass = new UITextureRenderPass(
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