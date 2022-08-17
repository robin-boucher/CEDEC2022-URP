==== Linearカラースペース時のsRGB UIサンプル

Renderer Featureを使い、Linearカラースペース時のsRGB UIのAlphaブレンドをGammaカラースペース時の状態に近づけるサンプルです。

Linearカラースペース時にsRGBのUIを描画すると、Alphaブレンドの結果がGammaカラースペース時と異なるため、アーティストが想定しているものと違う見た目になるケースがあります。

このサンプルではRenderer Featureを使い、独自にAlphaブレンドを行うことによってLinearカラースペース時でもUIの見た目をGammaカラースペース時に近づけるようにしてあります。
1. UIを_UITextureというRender Textureに書き出します。この際、UIのテクスチャがsRGBであれば、色変換を行います。
2. カメラターゲットと_UITextureを独自にAlphaブレンドし、カメラターゲットに書き出します。

1.のステップに関しては3通りの手法を使用しています。それぞれメリット・デメリットがあります。

1_1. UIを_UITextureに書き出す際、UIマテリアルをオーバーライドし、一括で色変換を行います。
  メリット: 各UIコンポーネントに特別な処理・操作を施す必要がありません。Renderer Featureが一括で処理してくれます。
  デメリット: 各UIコンポーネントが同じマテリアルで描画されるため、マテリアル個別のプロパティを設定すると無視されてしまいます。
    MaskなどのIMaterialModifier使用のコンポーネントや、スクリプトからマテリアルプロパティを操作しているものが該当します。
    また、TextMeshProは専用のマテリアルを使用するため、この手法では描画することができません。

1_2. sRGBテクスチャを使用するImageコンポーネントに、色変換を行う専用のマテリアルを指定します。UIを_UITextureに書き出す際にマテリアルオーバーライドを設定しません。
  メリット: マテリアルオーバーライドを設定しないため、マテリアルプロパティの設定が維持されます。MaskやTextMeshProも使用できます。
  デメリット: sRGBテクスチャを使用するコンポーネントに専用マテリアルを指定する処理が必要です。

1_3. sRGBテクスチャをTextureImporter設定でLinearテクスチャに指定します (sRGB Color Textureのチェックを外す)。UIを_UITextureに書き出す際にマテリアルオーバーライドを設定しません。
  メリット: マテリアルオーバーライドを設定しないため、マテリアルプロパティの設定が維持されます。MaskやTextMeshProも使用できます。
    また、Imageコンポーネントなどに専用のマテリアルを指定する必要もありません。
  デメリット: 納品される各sRGBテクスチャをLinearテクスチャに変換する必要があります。また、若干色味に差が出る可能性があります。

シーン
- Assets/RendererFeatureSamples/sRGBUI/Scenes/DefaultScene.unity: 何も施していないシーン。このシーンでカラースペースをGamma/Linear両方で確認すると、Alphaブレンドの結果が異なることがわかります。
- Alphaブレンドを施しているシーンは下記になります。これらのシーンをLinearカラースペースで確認すると、DefaultSceneのGamma時に近くなっていることがわかります。
--- Assets/RendererFeatureSamples/sRGBUI/Scenes/CustomBlendedOverrideMaterialScene.unity: 手法1_1のシーンです。TextMeshProは描画指定いません。
--- Assets/RendererFeatureSamples/sRGBUI/Scenes/CustomBlendedCustomMaterialScene.unity: 手法1_2のシーンです。
--- Assets/RendererFeatureSamples/sRGBUI/Scenes/CustomBlendedLinearTextureScene.unity: 手法1_3のシーンです。

シェーダー
- Assets/Shaders/UTJSample-UI.shader: UIを描画するシェーダー
- Assets/Shaders/UTJSample-AlphaBlend.shader.shader: Alphaブレンドを行うシェーダー

RendererData
- Assets/URP/UIRenderer.asset: Render Featureを追加してあるRenderer Data

Renderer Feature
- Assets/RendererFeatureSamples/sRGBUI/Scripts/UITextureRendererFeature.cs: UIを描画するRenderer Feature
- Assets/RendererFeatureSamples/sRGBUI/Scripts/AlphaBlendRendererFeature.cs: Alphaブレンドを行うRenderer Feature