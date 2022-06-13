==== カスタムシェーダーサンプル

URPのカスタムシェーダーのサンプルです。

シェーダーはSimpleLitに近いBlinn-Phongライティングを実装しています。

シェーダーには以下の機能が実装されています。(Shader Model 4.5以上用のSubShaderのみです)
- Diffuse + Specularライティング
- メインライト + 追加ライト
- Normal map
- Specular map
- Emission map
- Shadow cast + shadow receive (メインライト + 追加ライト)
- Light Layers対応
- UniversalForwardパス (Forwardレンダリング)
- UniversalGBUfferパス (Deferredレンダリング)
- _CameraDepthTexture, _CameraNormalsTexture対応
- ライトマップ (Metaパス)
- SRP Batcher対応
- GPU Instancing対応
- Rendering Debugger対応

シーン
- Assets/CustomShaderSamples/CustomShader/Scenes/CustomShaderForwardScene.unity: Forwardレンダリングのシーン
- Assets/CustomShaderSamples/CustomShader/Scenes/CustomShaderDeferredScene.unity: Deferredレンダリングのシーン

シェーダー
- Assets/Shaders/UTJSample-Lit.shader: シェーダー
--- Assets/Shaders/Inc/以下に#include対象ファイルあり

RendererData
- Assets/URP/ForwardRenderer.asset: Forward Renderer Data
- Assets/URP/DeferredRenderer.asset: Deferred Renderer Data