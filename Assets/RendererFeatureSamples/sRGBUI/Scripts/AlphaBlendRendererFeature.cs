using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

using System.Collections.Generic;

public class AlphaBlendRendererFeature : ScriptableRendererFeature
{
    // Blend UI texture with camera color target

    [System.Serializable]
    public class AlphaBlendSettings
    {
        public string profilerTag = "AlphaBlendRendererFeature";
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        public Material blendMaterial = null;
    }

    public class AlphaBlendRenderPass : ScriptableRenderPass
    {
        private string profilerTag;

        private Material material;

        private RenderTargetIdentifier cameraColorRenderTargetIdentifier;
        private RenderTargetHandle tempRTHandle;

        public AlphaBlendRenderPass(string profilerTag, RenderPassEvent renderPassEvent, Material material)
        {
            this.profilerTag = profilerTag;
            this.profilingSampler = new ProfilingSampler(profilerTag);

            this.material = material;

            this.renderPassEvent = renderPassEvent;
        }

        public void Setup(RenderTargetIdentifier cameraColorRenderTargetIdentifier)
        {
            this.cameraColorRenderTargetIdentifier = cameraColorRenderTargetIdentifier;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // Called before Execute

            // Setup temporary RenderTexture handle
            cmd.GetTemporaryRT(this.tempRTHandle.id, cameraTextureDescriptor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Camera data
            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;

            // Create command buffer
            CommandBuffer commandBuffer = CommandBufferPool.Get(this.profilerTag);

            // Blit with blend material to temporary render texture
            Blit(commandBuffer, this.cameraColorRenderTargetIdentifier, this.tempRTHandle.Identifier(), this.material);

            // Blit back into camera target
            Blit(commandBuffer, this.tempRTHandle.Identifier(), this.cameraColorRenderTargetIdentifier);

            // Execute
            context.ExecuteCommandBuffer(commandBuffer);

            // Cleanup
            commandBuffer.Clear();
            CommandBufferPool.Release(commandBuffer);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            // Called after Execute

            // Relase temporary RenderTexture
            cmd.ReleaseTemporaryRT(this.tempRTHandle.id);
        }
    }

    public AlphaBlendSettings settings = new AlphaBlendSettings();

    private AlphaBlendRenderPass renderPass;

    public override void Create()
    {
        this.renderPass = new AlphaBlendRenderPass(
            settings.profilerTag,
            settings.renderPassEvent,
            settings.blendMaterial
        );
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Pass camera color target RenderTextureHandle to render pass
        this.renderPass.Setup(renderer.cameraColorTarget);

        renderer.EnqueuePass(this.renderPass);
    }
}


