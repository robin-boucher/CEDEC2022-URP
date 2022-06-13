==== Outlineパスサンプル

Renderer Featureを使い、Normal方向にMeshを拡張するOutlineパスを実行するサンプルです。

SRPDefaultUnlitでの追加パスを使ったOutlineだと「マルチパスシェーダーに該当する」を理由にSRP Batcherの対象外になってしまいます。Renderer Featureを使った実装だと元のシェーダーをSRP Batcher対象のままOutlineを描画することが可能になります。Frame Debuggerでご確認ください。

また、このOutlineはStencilバッファを使い、Meshが描画されていない領域にのみOutlineが表示されるようにしています。Forwardレンダリングだと特殊なことをする必要はありませんが、DeferredレンダリングだとURPがStencil Stateを上書きしてしまうため、別のRenderer FeatureでStencil Stateをオーバーライドしています。

シーン
- Assets/RendererFeatureSamples/StencilOutlinePass/Scenes/StencilOutlineForwardScene.unity: Forwardレンダリングのシーン
- Assets/RendererFeatureSamples/StencilOutlinePass/Scenes/StencilOutlineDeferredScene.unity: Deferredレンダリングのシーン (追加Renderer Featureあり)

シェーダー
- Assets/Shaders/UTJSample-LitToonStencil.shader: Meshを描画するシェーダー (Stencil書き込みあり)
--- Assets/Shaders/Inc/以下に#include対象ファイルあり
- Assets/Shaders/UTJSample-OutlineStencil.shader: Outline描画パス

RendererData
- Assets/URP/StencilOutlineRendererForward.asset: Forward Renderer Data
- Assets/URP/StencilOutlineRendererDeferred.asset: Deferred Renderer Data (追加Renderer Featureあり)

Renderer Feature
- Assets/RendererFeatureSamples/StencilOutlinePass/Scripts/OutlineRendererFeature.cs: Outlineを描画するRenderer Feature
- Assets/RendererFeatureSamples/StencilOutlinePass/Scripts/StencilOverrideRendererFeature.cs: Stencilをオーバーライドし、書き込むRenderer Feature (Deferredレンダリングのみ)