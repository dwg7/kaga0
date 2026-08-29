# 0014: HDMI/GPU機体にはzero-copy GL(C++)実装を使う

## ステータス

採用(次回セッションから着手)

## 背景

Stage 3-6は`maplibre-native-slint`の`rust/`実装(`linuxkms-noseat`、
`LIBGL_ALWAYS_SOFTWARE=1`)で進め、2026-08-29中にVBM/VLCM PMTilesの表示まで
到達した。しかしこの過程で以下の問題に直面した:

- Slintの画面用EGL(GBM経由のハードウェアGL)と、maplibre-nativeのオフスクリーン用EGL
  (surfaceless)が、同一プロセス内で共存できない([docs/stage4-5-build-log.md](../stage4-5-build-log.md)参照)。
  回避策として両方ソフトウェアレンダリング(`SLINT_BACKEND=linuxkms-software`)にしたが、
  CPU使用率140%前後と重く、カーソルも非表示になった
- Slint 1.17.1の`linuxkms`バックエンドはホイール/スクロールイベントを一切処理しない
  (上流の未実装)

[UNopenGIS/7 issue #945](https://github.com/UNopenGIS/7/issues/945)経由で、
Yuisekiさんの[`pi-maplibre-native-slint-touch`](https://github.com/yuiseki/pi-maplibre-native-slint-touch)
リポジトリを発見した。ここには**ハードウェア構成によって2つの別実装**が用意されていた:

| ルート | パネル/接続 | レンダラ | 実装言語 |
|---|---|---|---|
| SPI(`spi/`) | SPI fbtft、GPU/KMS無し | Slintソフトウェア + maplibre読み戻し | Rust |
| **HDMI**(`hdmi/`) | HDMI、vc4 KMS、**V3D GPU使用可** | **zero-copy GL**(maplibreがSlintのGLテクスチャに直接描画) | **C++** |

私たちがこれまで使っていたPR #66由来のレシピ(`linuxkms-noseat`、software rendering)は
**SPI(GPU無し)ルート向け**のものだった。m329は実際にはHDMI接続・V3D GPU使用可能な
機体なので、**「HDMI」ルートに該当し、SPI向けレシピを誤って適用していた**ことになる。
今晩ずっと格闘したEGLプラットフォーム競合は、この不一致が根本原因だったと考えられる。

## 決定

次回セッションでは、`hdmi/`のzero-copy GL実装(C++)への切り替えに着手する。

**技術的なポイント**(`hdmi/README.md`より):
- maplibre-nativeを`mbgl::gl::RendererBackend`のカスタム実装でSlintのGLコンテキスト内の
  FBO/テクスチャに直接描画させ、GPU→CPUの読み戻しを一切行わない
  (`slint::Image::create_from_borrowed_gl_2d_rgba_texture`)
- 入力は「ドラッグ=パン、ダブルタップ=ズームイン」(ホイールではない!タッチパネル向け設計だが、
  Slintのホイール未対応問題を副産物的に回避している)
- ビルドは`maplibre-native-slint`をcloneした上に、`hdmi/`配下の独自C++ソース
  (`slint_gl_backend.*`、`slint_map_gl.*`、`main_gl.cpp`、`gl_map_window.slint`)を
  `cpp/`ディレクトリへ重ねる形(`hdmi/scripts/build.sh`)
- 依存: `libegl-dev libgles-dev libgl-dev libopengl-dev libgbm-dev libdrm-dev
  libinput-dev libxkbcommon-dev libudev-dev libseat-dev seatd libssl-dev
  libcurl4-openssl-dev zlib1g-dev libpng-dev libicu-dev libx11-dev libxext-dev
  mesa-common-dev`(X11関連パッケージはリンク時の`OpenGL::GLX`ターゲット解決のためだけに必要、
  実行時にX11は使わない)
- CMakeフラグ: `-DMLN_WITH_OPENGL=ON -DMLN_WITH_WEBGPU=OFF -DMLN_WITH_GLFW=OFF
  -DSLINT_FEATURE_RENDERER_FEMTOVG=ON -DSLINT_FEATURE_BACKEND_LINUXKMS=ON`
  (**`libseat`版**を使用。今回私たちが使った`noseat`ではない点に注意)
- `MAPLIBRE_STYLE_URL`等の環境変数はそのまま使える。他にも`MAPLIBRE_WIDTH/HEIGHT`、
  `MAPLIBRE_PREFETCH_DELTA`、画面消灯・スクリーンセーバー関連の変数が豊富に用意されている
- 「Raspberry Pi 4(Debian 13/trixie、aarch64、V3D 4.2.14.0)」で動作検証済みと明記
  — **私たちのm329と一致する環境**
- 実機へのデプロイはバイナリ+一部ライブラリのscp+systemdユニット
  (`hdmi/scripts/deploy.sh`、`hdmi/systemd/maplibre-slint-gl.service`)。
  GPU/表示スタック(Mesa/libEGL/libGL/libdrm/libgbm)はバンドルせず、必ずターゲット側を使う
  (ADR 0009のcross-distro注意点と同じ考え方)
- upstream(`maplibre-native-slint`本体)はこの後PR #73でバックエンドを`mbgl-slint`という
  再利用可能ライブラリに切り出し、#70/#72/#75/#76でビルド周りを刷新している。Yuisekiさんの
  `hdmi/`はマージ済みコミット(`1f32a5a`)に固定されているため、最新のupstreamを追う場合は
  「バージョンを上げる」のではなく「移植し直す」作業になる、と明記されている

## 次のアクション(次回セッション)

1. `hdmi/scripts/build.sh`相当の手順をm329(ビルドホスト兼実行ホストとして使う)で試す
2. 依存パッケージのインストール(上記リスト。今回インストール済みのものと重複あり)
3. ビルド成功後、実際にVBM/VLCM PMTilesスタイルで動作確認
4. PMTilesの読み込み方式(HTTP経由かローカルファイル直接か)もこの実装でどうなっているか確認
   (今回rust/実装ではPython http.serverがRange未対応で失敗し、`busybox httpd`で回避した。
   C++実装でも同様の制約があるか要確認)
5. うまくいけば、今回の`rust/`実装での知見(swap、ディスク管理、解像度設定等)は
   そのまま活きるはずなので、Stage 3-6を実質的に「正しい実装で」やり直す形になる
