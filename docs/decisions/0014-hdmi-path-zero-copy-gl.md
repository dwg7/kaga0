# 0014: HDMI/GPU機体にはzero-copy GL(C++)実装を使う

## ステータス

採用・実機で動作確認済み(2026-08-30未明、詳細は末尾の「実機ビルド・実行ログ」参照)

## 一晩の要約(2026-08-30、圧縮直前に追記)

このADRは非常に長い一晩の記録なので、通読しない読者向けにTL;DRを置く。
時系列は本文・[docs/plan.md](../plan.md)により忠実。

1. `rust/`実装(前夜までのStage 3-5)がEGL競合で行き詰まり、原因は
   「SPI機体向けレシピをHDMI機体に誤って適用していた」ことだったと判明
   → Yuisekiさんの`hdmi/`(zero-copy GL、C++)に切り替え(本ADRの主題)
2. 切り替え自体は成功、CPU 140%→25%、Stage 5-6を達成
3. その後、実機での目視確認から次々に改善点が見つかり、その都度その場で
   直した: bvmapのz14打ち切りバグ(z16へ、南西端も渡島大島・龍飛岬まで拡張)、
   マウスホイールの独自実装(Slintの制約を評価しなおして実現)、
   `pmtiles://file://`化(busybox廃止)、フォント/スプライトの完全ローカル化、
   火山ComboBox化(気象庁常時観測火山9座)とそのスクロール問題(Slint本体への
   パッチ)、VBM/VLCM地物のホバー属性表示(これもSlint本体への軽微なパッチで
   実現)、シャットダウンボタン、ホイールズームのカーソル中心化、解像度の
   段階的検証(1080p/1440p/4K、1440pに着地)
4. 副産物として、`~/poc/mln-slint-cpp`の`.git`削除(ディスク6GB節約)、
   アプリのソース差分(`src/hdmi-overlay/`)と上流本体へのパッチ
   (`src/vendor-patches/`)を初めてこのリポジトリでバージョン管理下に置いた
   (それまで実機にしか存在せず、途中で気づいて慌てて取り込んだ)
5. **v0成功条件(CLAUDE.md §4)は全て実機確認済み**。残る大きな未確認事項は
   「ネットワーク切断状態での完全オフライン動作」の物理確認のみ
   (藤村さんが約25時間後に出勤先で実施予定)

## 謝辞・参照

kagaがStage 5-6を「正しい実装」で突破できたのは、[Yuiseki](https://github.com/yuiseki)さんの
[`pi-maplibre-native-slint-touch`](https://github.com/yuiseki/pi-maplibre-native-slint-touch)
リポジトリ、特に`hdmi/`(zero-copy GL、C++、[maplibre/maplibre-native-slint#68](https://github.com/maplibre/maplibre-native-slint/pull/68)として
upstream化)があったからに他ならない。同じdwg7組織の先行知見であり、
「Raspberry Pi 4(Debian 13/trixie、V3D 4.2.14.0)で実機検証済み」という記述が
m329と寸分違わず一致していたことが、今夜の突破口になった。ここに感謝を記録する。

kagaはこの実装を**参照・移植**しており、そのままフォークして使い続けるものではない
(upstreamはPR #73以降でバックエンドを`mbgl-slint`ライブラリへ切り出す等、既に
先へ進んでいる。「バージョンを上げる」のではなく「必要に応じて移植し直す」対象として
扱う、と`hdmi/README.md`にも明記されている)。kaga側での改変(スタイル切り替え
ドロップダウンの簡素化、Dance/Calm・Syncボタンの削除、都市ボタン→北海道の火山への
差し替め等)は、すべてkaga固有の要件によるものであり、Yuisekiさんの設計判断への
異議ではない。

## kagaの目的の再確認(Yuisekiさんの構想との違い)

`hdmi/`実装を読み込む過程で、GPS・Meshtastic無線ノード表示・PiSugarバッテリー・
音声起動(`pi-hear`)・多段階スクリーンセーバー・tty切り替え(`supervisor.py`)など、
Yuisekiさん自身の可搬アプライアンス([pi-z2-display-hat-mini](https://github.com/yuiseki/pi-z2-display-hat-mini)系譜)向けの
豊富な機能に触れた。これらは**Yuisekiさんの構想(汎用の可搬地図・通信デッキ)には
自然だが、kagaの目的には無関係**であり、意図的に持ち込まない。

CLAUDE.md冒頭に立ち返ると、kagaの目的は明確に一点に絞られている:

> 「地図を公開する」のではなく、「地図を持ち込む」というアプローチ。

具体的には:
- **単機能専用機**であること(汎用コンピュータでも汎用マップビューアでもない)
- VBM(火山基本図)・VLCM(火山土地条件図)という**特定のデータ**を、
  **完全にネットワークから独立して**(GPS/無線/クラウド同期なしに)表示すること
- 利用シーンは**会議・打合せ・防災訓練**での提示——タッチパネルでの日常携行操作
  ではなく、HDMI大画面へのプロジェクタ投影とマウス/トラックボール操作
- 成功条件は5つだけ(CLAUDE.md §4): 電源投入から直接起動、オフライン動作、
  北海道の主要火山表示、快適なパン・ズーム、実務での使用に耐えること

したがって今後の機能追加(スタイル切り替えUI、都市ジャンプボタン、将来のホバー属性表示等)は
すべて「この一点をより確実に・より分かりやすく達成するため」という基準で取捨選択する。
GPS連携やメッシュ通信のような、Yuisekiさんの構想にあってkagaの成功条件に無い機能は、
たとえ`hdmi/`のコードに既にあっても、明示的に持ち込まない。

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
4. PMTilesの読み込み方式は下記の追記で判明済み(HTTP経由のまま、`busybox httpd`継続でよい)
5. うまくいけば、今回の`rust/`実装での知見(swap、ディスク管理、解像度設定等)は
   そのまま活きるはずなので、Stage 3-6を実質的に「正しい実装で」やり直す形になる

## 実装詳細の把握(ソースコード熟読、2026-08-29夜追記)

`hdmi/`配下の全ソース(`README.md`、`main_gl.cpp`〈1555行〉、`src/slint_gl_backend.*`、
`src/slint_map_gl.*`〈690行〉、`platform/custom_file_source.*`、`gl_map_window.slint`、
`scripts/build.sh`、`CMakeLists.txt`、systemdユニット)を読了。以下、要点。

### 1. EGL競合問題の根本的な解決方法(今晩ずっと格闘した壁の正体)

`SlintGLBackend`(`mbgl::gl::RendererBackend`のカスタム実装)は**EGLコンテキストを
自分で作らない**。`ContextMode::Shared`を指定し、`activate()`/`deactivate()`を
完全な no-op にしている――コメントに明記:「Slint's context is already current
inside the rendering-notifier callback」。つまりプロセス全体を通じてEGLコンテキストは
**Slintが持つ1つだけ**であり、maplibre-nativeはSlintの`rendering_notifier`
コールバック(`RenderingSetup`/`BeforeRendering`/`RenderingTeardown`)の中で、
その同じコンテキスト上のFBOに描画するだけ。GL関数ポインタも`eglGetProcAddress`を
素通しして使う(`getExtensionFunctionPointer`)。

→ 今晩の`rust/`実装での問題(maplibre-nativeのheadless EGL initとSlintの
GBM/EGLが同一プロセスで衝突)は、**そもそもmaplibre-nativeに独自のEGL
コンテキストを持たせようとしたこと自体が原因**だったと判明。`hdmi/`実装は
設計時点でこれを回避している。C++側へのパッチ(`headless_backend_egl.cpp`の
`eglGetPlatformDisplay`化)は不要になる見込み――headlessバックエンドを
そもそも使わないため。

### 2. 描画ループの実体(`main_gl.cpp`)

`win->window().set_rendering_notifier(...)`のコールバック内:

- `RenderingSetup`: `glGenTextures`/`glGenRenderbuffers`/`glGenFramebuffers`で
  カラーテクスチャ+深度ステンシルRBOを持つFBOを1つ作り、`smap->setup(fbo, w, h, styleUrl)`
  でmaplibre-native側に橋渡し。サイズは`MAPLIBRE_WIDTH`/`HEIGHT`未指定なら
  ディスプレイの実解像度をそのまま使う。
- `BeforeRendering`: 現在のGL状態(FBOバインディング、viewport、program、
  各種バッファ/テクスチャバインド、blend/depth/scissor/cullの有効状態)を
  退避 → `smap->render()`でmaplibre-nativeにFBOへ描画させる → 退避した状態を
  全て復元 → `slint::Image::create_from_borrowed_gl_2d_rgba_texture(tex, size,
  BottomLeft)`でそのテクスチャをSlint側にゼロコピーで渡す →
  `window().request_redraw()`で次フレームを予約。
- `RenderingTeardown`: FBO/RBO/テクスチャの解放。

GL状態の保存・復元がある理由: SlintのFemtoVGレンダラとmaplibre-nativeの
レンダラが同じGLコンテキストを時分割で使うため、互いのGL状態を汚さないよう
明示的にサンドイッチしている。これは`rust/`版では存在しなかった配慮で、
今晩の実装でホイール/カーソル以外にも潜在バグがあった可能性を示唆する。

### 3. 入力: 物理ホイールは今回もこの実装でも処理されていない

`slint_map_gl.cpp`の`handle_wheel_zoom(x, y, dy)`は`map->scaleBy(...)`を呼ぶ
だけの薄いAPIで、**呼び出し元は`gl_map_window.slint`のオンスクリーンズーム
ボタン/スライダーとキーボードショートカットのみ**(`grep`で確認済み:
`MMapAdapter.wheel-zoomed(...)`の呼び出し箇所は全てボタンの`clicked`/
キー入力に紐づいており、実際のマウス/トラックボールのスクロールイベントを
libinput経由で受け取っている箇所はゼロ)。ドラッグ=パン、ダブルタップ
(`handle_mouse_press`内で350ms以内・30px以内の連続pressを自前検出)=
ズームイン、という設計。

→ Slint 1.17.1の`linuxkms`バックエンドが`ScrollWheel`イベントを一切
処理しない、という[docs/stage4-5-build-log.md](../stage4-5-build-log.md)での
発見は、より成熟したこの参照実装でも回避策(オンスクリーンボタン・
ダブルタップ)止まりで、根本解決されていないことが確認できた。
**CLAUDE.md v0成功条件の「ホイール=拡大縮小」は、この実装をそのまま
使う場合はオンスクリーンズームボタンかダブルタップへの置き換えが
必要になる**――トラックボールの物理ホイールでのズームは、Slintに
パッチを当てるか、libinputの生イベントを別経路で読む自前実装をしない限り
実現しない。次回、藤村さんと擦り合わせたい論点。

### 4a. 続報(同夜さらに追記): mbgl-core本体には`file://`直読みの経路が実在した

上記4節は`platform/custom_file_source.*`(Yuisekiさんのcprベース独自HTTPクライアント、
`http`/`https`のみ受理)だけを見た時点の結論。その後mbgl-core本体
(`platform/default/src/mln/storage/`)を読み進めたところ、**`custom_file_source.*`は
`main_gl.cpp`/`slint_map_gl.cpp`のどこからも`registerFileSourceFactory`されておらず、
実際には未使用(ビルド対象に含まれているだけの生きていないコード)**と判明した。

実際に使われるのはmbgl-coreデフォルトの`MainResourceLoader`
(`main_resource_loader.cpp`)で、リクエストを次の優先順で振り分ける:

```
Asset → Mbtiles → PMTiles → LocalFileSource(file://) → Database → Network(http/https)
```

`pmtiles://`URLはまず`PMTilesFileSource`(`pmtiles_file_source.cpp`)が受け、
prefixを剥がした中身のURL(例: `file:///opt/kaga/data/vbm.pmtiles`)を
**同じResourceLoaderに再帰的に投げ直す**(`getFileSource()`が
`FileSourceType::ResourceLoader`を取得し直すだけ)。中身が`file://`なら
`LocalFileSource`(`local_file_source.cpp`→`local_file_request.cpp`)が拾い、
`stat()`後`util::readFile(path, dataRange)`で**バイト範囲(ヘッダ127バイト、
ディレクトリ、各タイル)を直接ファイルから読む**。TCP/HTTPは一切経由しない。
`style.json`自体も`Resource::Kind::Style`として同じResourceLoaderを通るため、
`file:///opt/kaga/data/style.json`で直接読める可能性が高い。

→ **`busybox httpd`はkaga独自の追加レイヤーであり、この経路が実機でも
機能すれば完全に不要にできる**。ループバック経由とはいえ、リクエストごとの
TCP/HTTPオーバーヘッドとbusyboxのプロセスモデルの負荷が消える。

**未検証・要確認**: 今夜Stage 6で`rust/`実装(`maplibre_native`クレート0.8.7)
で`file:///opt/kaga/data/style.json`を試した際はRustパニックで失敗した実績が
ある。これはRustバインディング層固有の制約だった可能性が高く、`hdmi/`は
C++から`map->getStyle().loadURL(...)`を直接呼ぶため素のmbgl-coreの挙動に
従うはずだが、**ビルド完了後に実機で最初に試すべき最優先事項**。うまくいけば
スタイルURLを`file:///opt/kaga/data/style.json`、ソースURLを
`pmtiles://file:///opt/kaga/data/{vbm,vlcm}.pmtiles`に書き換えるだけで、
`busybox httpd`のプロセス起動・待受・Stage 6の`style.json`書き換え手順が
まるごと不要になる。だめだった場合のフォールバックとして`busybox httpd`は
そのまま温存する(手順は既に確立済み)。

### 4b. 元の疑問への回答(4節、`custom_file_source.*`単体で見た場合)

`platform/custom_file_source.cpp`(`CustomFileSource`、`cpr`ライブラリで
プレーンな`cpr::Get(url)`を発行するだけの薄いHTTPクライアント)の
`canRequest()`は**`http://`/`https://`prefixのURLしか受け付けない**
(`url.rfind("http://", 0) != 0 && ...`のガードで弾く)。ローカルファイル
直読みの経路はこの実装にも存在しない。`map->getStyle().loadURL(styleUrl)`も
プレーンなURL文字列を渡すだけ。

→ Stage 6で半分投げかけていた疑問(mbgl-coreのPMTiles file sourceが
ローカルファイル直読みに対応しているか)は、**この参照実装のレベルでは
「対応していない、常にHTTP経由」と判明**。今回`busybox httpd`で
Range対応HTTPサーバを立てた構成は、`hdmi/`実装に移行してもそのまま
再利用できる。この点はStage 6の知見がロスなく引き継げる。

### 5. m329に不要な機能は「存在しない前提で安全にフォールバックする」設計

`main_gl.cpp`にはGPS(`pi-gps`)・Meshtastic位置情報・PiSugarバッテリー・
音声起動(`voice_activity`)・スクリーンセーバー(DVDロゴ/タイルバウンド)・
`supervisor.py`によるTTY切り替え、といったYuisekiさん自身のアプライアンス
向け機能が大量に埋め込まれている。ただし:

- `voice_activity.*`: 文字列判定のみの純粋関数。マイクデバイス不在でも
  何も壊れない
- `style_list.*`: 設定ファイル(`~/.config/maplibre-slint-gl/styles.csv`等)
  が無ければ空リストを返し、呼び出し側は組み込みデフォルトにフォールバック
- GPS/mesh/自己位置ファイルは`/dev/shm/pi-*`の存在チェック付きで、
  無ければ単に表示しない(READMEの「hides itself when its source is
  absent」という記述をソースで確認)

→ **`main_gl.cpp`をほぼ手を加えずビルド・実行しても、m329上で
クラッシュする理由は見当たらない**。無理に該当箇所を削って移植する
より、まずはそのままビルドして動かし、動作確認できてから段階的に
不要部分(supervisor.py、スクリーンセーバー、GPS/mesh関連)を
省く方が「小さく確認可能な単位で進める」というCLAUDE.md §7の方針に合う。

## 実機ビルド・実行ログ(2026-08-30未明)

### ビルド: 成功(`maplibre-slint-gl`)

`hdmi/scripts/build.sh`相当をm329上で実行。総所要時間は約2時間(うち大半は
`vendor/maplibre-native`のgit submodule再帰clone〈履歴込み約4.7GB、Wi-Fi律速〉
と初回コンパイル)。**成果物**: `~/poc/mln-slint-cpp/build/cpp/maplibre-slint-gl`
(14MB、aarch64 PIE実行ファイル)。

**追加でインストールした依存**: `libseat-dev seatd`(他は既存の`rust/`実装作業で
入っていたものを流用でき、意外にも大半揃っていた)。

**ハマった点(pkg-configではなくrustcが真因)**: ビルド中に`libudev-sys v0.1.4`の
build.rsが`called Result::unwrap() on an Err value: Os { code: 2, kind:
NotFound }`で2回失敗。ログに`PKG_CONFIG`関連の`cargo:rerun-if-env-changed`行が
大量に出ていたため最初`pkg-config`未検出だと誤診断し、`PKG_CONFIG=/usr/bin/
pkg-config`を明示指定して再ビルドしたが再現(strace で確認すると`pkg-config`の
呼び出し自体はexit 0で成功していた)。**真因**は`libudev-sys`のbuild.rs
32行目`Command::new("rustc").arg(...).output().unwrap()`——`cpr`ではなく
**素の`rustc`をPATH解決で直接呼んでいた**こと。CMake/Corrosionは`cargo`/`rustc`を
`CMakeCache.txt`に記録した**絶対パス**で起動するため、build.sh自体のシェル
(`PATH=/usr/local/bin:/usr/bin:/bin:/usr/games`、`~/.cargo/bin`を含まない)
経由でも通常のcargoビルドは問題なく動くが、この一つの依存クレートの
build.rsだけが例外的に`rustc`をPATH経由で裸呼びしていたため失敗していた。
**修正**: `PATH="$HOME/.cargo/bin:$PATH"`を明示的に付与して`build.sh`を再実行。
これで解決し、既にキャッシュ済みの`mbgl-core`(97%まで到達済みだった)を含む
全ビルド成果物を無駄にせず、最終リンクまで到達した。

**教訓**: 「PATHに関連しそうな環境変数がエラーログに大量に出ている」ことと
「そのエラーの真因がPATH関連である」ことは別で、`strace -f -e trace=execve`で
実際に何を呼ぼうとして失敗しているかを見るまでは真因を決め打ちしないこと。
今回は`PKG_CONFIG_*`という文字列のノイズに引きずられて30分ほど遠回りした。

### 実行: 成功(ハードウェアGL、V3D 4.2.14.0)

初回実行は`Error presenting framebuffer on screen: Permission denied (os
error 13)`で失敗。`journalctl -u seatd`で`Could not make device fd drm
master: Device or resource busy`と判明——**`getty@tty1`のfbconコンソール
(HDMI画面に表示されていた`m329 login:`)が既にDRM masterを握っていて競合**
していた。これはYuisekiさんの`supervisor.py`が「map起動時はコンソールを、
コンソール表示時はmapを、排他的に」制御している理由そのものだった
(README「Input: touch, mouse, keyboard + the map/terminal switch」節で
説明されていたが、読んだ時点では抽象的にしか理解していなかった)。

`sudo systemctl stop getty@tty1`でDRM masterを解放してから再実行したところ
**成功**:

```
[main_gl] RenderingSetup: NativeOpenGL acquired, render size 1920x1080
[SlintMapGL] setup fbo=1 size=1920x1080 style=http://127.0.0.1:8080/style.json
[INFO] {maplibre-slint-}[General]: GPU Identifier: V3D 4.2.14.0
[MapObserver] Did finish loading style
[perf] 29.9~37.9 fps
```

- **フレームレート**: 29.9〜37.9fps(busybox httpd経由、`/opt/kaga/data/style.json`
  〈VBM/VLCM限定の74レイヤー版〉)
- **CPU使用率**: プロセス単体25%、システム全体で80%アイドル
  (`rust/`+`linuxkms-software`版の140%前後から劇的に改善)
- スタイルは今夜Stage 6で作った`busybox httpd`版をそのまま流用、変更不要だった

**未検証(次回)**: 実際の画面での見た目・ドラッグ操作・ダブルタップズームの
確認(藤村さんによる目視・操作確認待ち)、`getty@tty1`停止に代わる恒久的な
運用方法(supervisor.py導入、または簡略版の自作)、`pmtiles://file://`方式への
切り替え実験。

### 更新した次のアクション

1. m329で`hdmi/scripts/build.sh`相当を実行(未経験の`libseat`/`seatd`系
   パッケージ追加が必要、上記の依存リスト参照)
2. ビルドできた`maplibre-slint-gl`を、まずはsupervisor.py抜きで
   `scripts/run.sh`相当(tmux + 直接実行)で動かし、`MAPLIBRE_STYLE_URL`に
   既存の`http://127.0.0.1:8080/style.json`(busybox httpd継続)を渡して
   VBM/VLCM表示を確認。**方針(2026-08-29夜決定)**: まず実績のある
   `busybox httpd`方式でYuisekiさんの到達点(ドラッグ=パン、ダブルタップ=
   ズームイン、実際のPMTiles表示)に追いつくことを優先し、動作が安定して
   から4a節の`pmtiles://file://`方式を別途・慎重に実験する。両方式を
   同時に切り替えて問題を混同しない
3. ドラッグ=パン、ダブルタップ=ズームインが動くか確認。カーソル可視性も
   (ハードウェアGL経由になるため、`linuxkms-software`時代の「カーソル
   非表示」問題が解消している可能性が高い――要検証)
4. 物理ホイールでのズームをどう扱うか、藤村さんと方針を決める
   (a) オンスクリーンズームボタン/ダブルタップに正式に切り替え
       (CLAUDE.md v0成功条件の記述更新が要る)
   (b) 自前でlibinputの生スクロールイベントを読み、`map->scaleBy`を
       直接呼ぶ薄い層を足す(工数増、上流不在の自作パッチ)
5. うまく動いたら、supervisor.py抜きの最小systemdユニットを自作し
   Stage 7へ

## 実機での初回動作確認と修正(2026-08-30、続き)

### バグ: 起動直後にYuisekiさんのホスト先スタイルへ上書きされる

初回の目視確認で「地図は見えるがVBM/VLCMが見えない、OSMベースの地図に見える」と
判明。原因は`gl_map_window.slint`の`MMapView`コンポーネントの`style-url`
プロパティが`"https://yuiseki.dev/static/styles/osm-bright.json"`に直書き
されていたこと。`main_gl.cpp`側の`SlintMapGL::setup()`は`MAPLIBRE_STYLE_URL`
環境変数を正しく解決してmaplibre-native側に直接ロードするが(ログにも
反映されていた)、**それとは独立に**`.slint`側の`style-url`プロパティ変更が
`MMapAdapter.request-style-change`経由で`setStyleUrl()`を呼び、Yuisekiさん
自身がホストする公開デモスタイルで上書きしていた。README側にも
「C++がlabel,urlファイルから両方(ドロップダウンの候補リスト)を差し替えられる」
という説明はあったが、**`map.style-url`自体の初期値**はそれとは別物で、
.slintソースの直接編集が必要だった。

**修正**: `gl_map_window.slint`の`style-names`/`style-urls`配列と
`map.style-url`の初期値を、kagaのローカルスタイル
(`http://127.0.0.1:8080/style.json`)一本に置き換え。あわせて座標
`0,0,zoom1`だった`MMapView`の初期center/zoomは触れていない(実際の初期視点は
`SlintMapGL::setup()`内の`MAPLIBRE_CENTER`環境変数/ハードコード〈東京〉が
使われており、`.slint`側の値は実質未使用と判断)。

さらに`MAPLIBRE_CENTER="42.626,141.537,11"`(vbm.pmtilesのヘッダに記録された
中心座標=有珠山付近、PMTiles v3ヘッダをPythonで直接パースして取得)を指定し、
北海道の火山データが実際に存在する範囲を初期表示にした。これで**VBM/VLCMの
実表示を確認**(藤村さん確認: 「いけてるね」)。

### bvmap(背景地図)のオフライン化

藤村さんの提案で、背景地図として`https://stars.optgeo.org/style/bvmap-dark.json`
を追加検討。ただしこのスタイルの`bvmap`ソースは`https://stars.optgeo.org/bvmap`
という**z/x/yライブタイル配信のみ**(ADR 0005で既出の通り、depot.optgeo.orgに
ダウンロード可能なPMTilesは無い)で、そのまま使うとkagaの核心要件(オフライン
動作)に反する。

藤村さんから「stars.optgeo.orgの`.config/martin/config.yaml`を見ると、実体は
`https://cyberjapandata.gsi.go.jp/xyz/optimal_bvmap-v1/optimal_bvmap-v1.pmtiles`
(国土地理院、GSI)だ」という情報提供があり、これを直接確認: **本物のPMTiles
ファイルとして存在**(HTTPヘッダで`accept-ranges: bytes`確認)。ただし全国版で
**16.9GB**——m329のSDカード(28GB、空き5-6GB)には到底収まらない。

**解決**: PMTilesはバイト範囲アクセスに対応した設計であることを利用し、
`pmtiles extract`(protomaps製CLI、Homebrewで導入済み)でVBM/VLCMと同じ
北海道bbox(`140.4,41.7,144.6,43.8`、zoom 0-14)だけを**HTTPバイト範囲読み
経由でリモートから直接抽出**。全国16.9GBの中から実際に転送されたのは
314MB(ドライラン時点の見積もり通り)、出力ファイルは**300MB**。ローカル
(Mac)で抽出してから`scp`でm329の`/opt/kaga/data/bvmap.pmtiles`へ転送
(m329上に`pmtiles` CLIを入れる手間を避けるため)。これで**bvmap自体も
オフライン資産にできた**(GSIのサーバーは初回抽出時のみ必要)。

スタイル合成: `bvmap-dark.json`の123レイヤーから`background`レイヤー
(1枚、ダーク配色)を残し、残り122レイヤーの`source`をローカル
`pmtiles://http://127.0.0.1:8080/bvmap.pmtiles`に差し替えた上で、
既存のVBM/VLCM層(74レイヤー、`background`は重複するので除去)の**下**に
配置。あわせて`sprite`フィールドをbvmap-dark由来のもの
(`https://gsi-cyberjapan.github.io/optimal_bvmap/sprite/std`)に設定
(`glyphs`は元々同じGSI GitHub Pagesを指しており変更不要)。
合計196レイヤーの新しい`/opt/kaga/data/style.json`をPythonスクリプトで
生成しm329へデプロイ。

**残る非オフライン依存(既知、未解決)**: `glyphs`(フォント)と`sprite`
(アイコン画像)は今も`gsi-cyberjapan.github.io`(GitHub Pages)を指したまま
——これは今回新たに持ち込んだものではなく、**kitavolca由来の元style.jsonが
最初からそうだった**。VBM/VLCMのsymbolレイヤーのラベル表示は、元々この
外部依存に乗っていたことになる。完全オフライン化にはフォント/スプライトの
ローカル同梱が必要で、bvmap同様に「一度取得してPMTiles的資産として持ち込む」
対応が今後の課題(v0成功条件そのものには影響しない——ラベルが出なくても
地物の色・形は表示される――が、v1以降の「背景地図強化」で本格対応したい)。

**196レイヤー版での実測(2026-08-30)**: 1920x1080、bvmap-dark背景込みで
安定後**約15.8fps**、プロセスCPU使用率82%(1コア相当)、システム全体は
約80%アイドル。74レイヤー版(bvmap無し)の29-38fpsからほぼ半減——GPU
(V3D)側がボトルネックと見られ、システム全体のCPUには余裕がある。
**解像度を上げる前のベースライン**として記録(藤村さんの次の検討課題:
段階的な解像度向上と、その都度のfps計測)。

### UI調整(藤村さんの指示、2026-08-30)

- **Dance/Calmボタン・Syncチェックボックスを画面から削除**。理由:
  kagaがpitch/bearingの3D演出を使うのは標高タイル(terrain)対応後
  (CLAUDE.md v0スコープ外、[docs/decisions/0014]自体の対象ではなくCLAUDE.md
  §4のロードマップ判断)であり、今は使わない。`.slint`側の
  `dancing`/`sensor-available`/`sync-toggled`プロパティ・コールバック自体は
  未削除(`main_gl.cpp`側のバインディングに影響を与えないための最小差分。
  UIのボタン/チェックボックスのみ非表示ではなく削除)
- **都市ジャンプボタン(Paris/New York/Tokyo)を北海道の火山3座に変更**:
  「駒ヶ岳」(42.0631, 140.6772)・「十勝岳」(43.4183, 142.6863)・
  「雌阿寒岳」(43.3844, 144.0128)、いずれもzoom12でfly-to

### 次のチャレンジ目標(藤村さんより)

火山基本図(VBM)の地物に対する**マウスオーバー時の属性表示**。UI上の配置は
Dance/Calmボタンがあった場所(画面左下)を想定。実現には以下の技術的検討が
必要(未着手、次回以降):
- maplibre-nativeの`queryRenderedFeatures`相当のAPIをC++から呼び出し、
  ポインタ位置直下のフィーチャとその属性(GeoJSON properties)を取得する経路
- Slint側でのホバー検出(`TouchArea`の`moved`はドラッグ用に既存利用中のため、
  クリックなしの純粋なマウス移動〈hover〉をどう拾うか要調査)
- 取得した属性をどう表示するか(画面左下の固定パネル、ツールチップ風の
  追従パネル等、UI設計はこれから)
