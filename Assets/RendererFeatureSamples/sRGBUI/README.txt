==== Linearカラースペース時のsRGB UIサンプル

Renderer Featureを使い、Linearカラースペース時のsRGB UIのAlphaブレンドをGammaカラースペース時の状態に近づけるサンプルです。

Linearカラースペース時にsRGBのUIを描画すると、Alphaブレンドの結果がGammaカラースペース時と異なるため、アーティストが想定しているものと違う見た目になるケースがあります。

このサンプルではRenderer Featureを使い、独自にAlphaブレンドを行うことによってLinearカラースペース時でもUIの見た目をGammaカラースペース時に近づけるようにしてあります。
1. UIを_UITextureというRender Textureに書き出します。
2. カメラターゲットと_UITextureを独自にAlphaブレンドし、カメラターゲットに書き出します。

シーン
- Assets/RendererFeatureSamples/sRGBUI/Scenes/DefaultScene.unity: 何も施していないシーン。このシーンでカラースペースをGamma/Linear両方で確認すると、Alphaブレンドの結果が異なることがわかります。
- Assets/RendererFeatureSamples/sRGBUI/Scenes/CustomBlendedScene.unity: Alphaブレンドを施しているシーン。このシーンをLinearカラースペースで確認すると、DefaultSceneのGamma時に近くなっていることがわかります。

シェーダー
- Assets/Shaders/UTJSample-UI.shader: UIを描画するシェーダー
- Assets/Shaders/UTJSample-AlphaBlend.shader.shader: Alphaブレンドを行うシェーダー

RendererData
- Assets/URP/UIRenderer.asset: Render Featureを追加してあるRenderer Data

Renderer Feature
- Assets/RendererFeatureSamples/sRGBUI/Scripts/UITextureRendererFeature.cs: UIを描画するRenderer Feature
- Assets/RendererFeatureSamples/sRGBUI/Scripts/AlphaBlendRendererFeature.cs: Alphaブレンドを行うRenderer Feature