# 10. RPiではmaplibre-nativeのGL/EGLをMesaソフトウェアレンダリング(llvmpipe)で動かす

- ステータス: 承認(既知の技術的制約として記録)
- 日付: 2026-08-29

## 状況

[0009](0009-trixie-and-cloudinit.md)の調査中、`maplibre-native-slint`の
[rust/RASPBERRY_PI.md](https://github.com/maplibre/maplibre-native-slint/blob/main/rust/RASPBERRY_PI.md)に、OS選択(Bookworm/Trixie)とは独立した重要な制約が
記載されているのを見つけた:

> The VideoCore GPU on Pi has no usable hardware OpenGL ES 3 path for
> maplibre-native, so its GL/EGL context must be created with Mesa's
> software rasterizer (llvmpipe) on the surfaceless EGL platform.
> Without this, maplibre-native aborts with `eglInitialize() failed`.

つまりRaspberry Pi(4/5)のVideoCore GPUは、maplibre-nativeが要求するハードウェア
GLES3パスを提供できず、素のままでは`eglInitialize()`で落ちる。実行時に以下の
環境変数でMesaのソフトウェアラスタライザへ強制フォールバックさせる必要がある:

```bash
SLINT_BACKEND=linuxkms-noseat \
EGL_PLATFORM=surfaceless \
LIBGL_ALWAYS_SOFTWARE=1 \
GALLIUM_DRIVER=llvmpipe \
./maplibre_native_slint
```

これは[CLAUDE.md](../../CLAUDE.md)のスタック図(MapLibre Native → Slint → DRM/KMS)が
暗黙に前提としていた「GPUで描画される」という想定と異なる。実際にはCPU側の
ソフトウェアラスタライザで描画される。

## 決定

- kaga.serviceの起動時、上記4つの環境変数を設定する(`systemd/kaga.service`の
  `Environment=`に追加する。Stage 4-5で実装)
- v0成功条件4「パン・ズームが快適である」は、ソフトウェアレンダリングの実測性能を
  Stage 4(MapLibre Native単体のレンダリング確認)で確認してから判断する。
  yuiseki氏のデモではPMTiles(planetソース)を含むスタイルが実機で描画できているため、
  実用に耐える可能性は高いが、火山図(VBM/VLCM)特有のフィーチャ密度での検証が必要

## 結果

- 良い点: 「なぜ描画されないのか」を今後デバッグする際、GPU/ドライバの問題だと
  誤って深追いすることを防げる(既知の制約として最初から認識できる)
- トレードオフ: 将来ハードウェアアクセラレーションが使えるようになった場合
  (Mesaのv3dドライバ改善、あるいはRPi5世代でのGLES3サポート改善等)、
  本ADRを見直しハードウェアパスへ切り替えることを検討する
