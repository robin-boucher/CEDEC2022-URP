==== カスタムシェーダーサンプル (ForwardOnlyパス)

UniversalForwardOnlyパスを実装したカスタムシェーダーのサンプルです。

シェーダーはToonライティングをUniversalForwardOnlyパスで行っており、UniversalGBufferパスは実装していません。このため、Deferredレンダリング時でもForwardパスが実行されます。Frame Debuggerでご確認ください。

シーン
- Assets/CustomShaderSamples/CustomShaderForwardOnly/Scenes/CustomShaderForwardOnlyScene.unity: DeferredレンダリングでUniversalForwardOnlyパスを使ったシーン

シェーダー
- Assets/Shaders/UTJSample-LitToon.shader: シェーダー
--- Assets/Shaders/Inc/以下に#include対象ファイルあり

RendererData
- Assets/URP/DeferredRenderer.asset: Deferred Renderer Data