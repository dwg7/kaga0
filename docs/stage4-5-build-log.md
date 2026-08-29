# Stage 4-5 作業ログ: MapLibre NativeとSlintの統合(m329)

Stage 3完了後、maplibre-native-slintの`rust/`実装をビルドし、実際に地図をHDMI画面に
表示するまでの記録。CLAUDE.mdセクション7のステージ定義参照。

## 結果サマリー(2026-08-29)

- **Stage 4達成**: maplibre-native本体(C++、EGL対応版0.8.7)のビルド成功
- **Stage 5達成**: MapLibre NativeとSlintが統合されたバイナリが、実際にJAPANNEXT
  ディスプレイ(1920x1080)に地図を表示。**ドラッグでのパン操作も動作確認済み**
- 動作確認スタイル: `https://stars.optgeo.org/style/openstreetmap_jp_planet`
  (自前のVBM/VLCM PMTilesへの切り替えはStage 6として次に着手)

## 依存クレートのバージョン問題と修正

初回ビルド(`maplibre_native = "0.8.2"`、Cargo.lockに古いバージョンが固定)では、
OpenGL利用時に**無条件でX11/GLXが要求される**実装だった(crates.io公開版は
EGL選択ロジックが未反映)。`cargo update`で`maplibre_native`を**0.8.7**まで
引き上げることでEGLがデフォルトで使えるようになった(`glx`はオプトイン化)。
この過程で依存関係の大規模な更新(534パッケージ、slintも1.16→1.17.1)が
発生し、再ビルドに146分26秒を要した。

## 決定的な壁: 同一プロセス内でのEGLプラットフォーム競合

**症状**: maplibre-nativeのヘッドレスEGL初期化(`platform/linux/src/headless_backend_egl.cpp`、
`eglGetDisplay(EGL_DEFAULT_DISPLAY)`という素朴な呼び出しに依存)と、
Slintの`linuxkms-femtovg`(GBM経由のハードウェアGL)を同一プロセスで
両方使おうとすると、`EGL_PLATFORM`環境変数の値によらず必ずどちらかが壊れる:

| `EGL_PLATFORM` | maplibre-native側 | Slint側 |
|---|---|---|
| 未指定 | `eglInitialize()`失敗 | (到達しない) |
| `surfaceless` | 初期化成功 | `swap_buffers`でセグフォルト(`libEGL_mesa.so`内でNULLポインタ呼び出し。gdbで確認済み) |
| `gbm` | `eglChooseConfig`失敗(GLES3+PBuffer構成が見つからない) | 初期化成功 |

**切り分けに使った手法**:
- gdbで`bt`を取り、`swap_buffers`内のクラッシュを確認
- 最小限のC単体プログラム(`eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA,...)`
  + `eglInitialize`のみ)を書いて、環境自体は正常なことを確認(root/一般ユーザー、
  Slintを別プロセスで動かした状態、いずれでも成功)
- → **問題は環境設定ではなく、同一プロセス内での共存**であると特定

## 適用した修正

1. **C++側にパッチ**: `headless_backend_egl.cpp`の`eglGetDisplay(EGL_DEFAULT_DISPLAY)`を
   `eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, nullptr)`
   に変更し、環境変数に頼らず明示的にsurfacelessプラットフォームを要求するようにした
   (`#include <EGL/eglext.h>`追加。`eglGetPlatformDisplayEXT`は拡張プロトタイプの
   マクロガードで見えなかったため、コア関数の`eglGetPlatformDisplay`を使用)。
   パッチ対象: `~/.cargo/registry/src/index.crates.io-*/maplibre_native-0.8.7/target/maplibre-native/platform/linux/src/headless_backend_egl.cpp`
   (cargoのレジストリキャッシュ配下、`.orig`にバックアップ済み)
2. **Slint側は`SLINT_BACKEND=linuxkms-software`(CPU描画のダムバッファ、EGL不使用)を選択**。
   これによりプロセス内でEGLを使うのはmaplibre-native側だけになり、競合が起きなくなった
3. `linuxkms-femtovg`(ハードウェアGL)は、クリーンな状態(他プロセスのDRM保持なし)で
   再検証しても確実にセグフォルトすることを確認済み。**このプロセス構成では
   併用不可能と結論**

**cargoのキャッシュ機構に関する注意**: C++ソースを直接編集しても、cargoはその変更を
検知する仕組みを持たない(build.rsが動的にgit cloneするディレクトリはcargoの
追跡対象外)。再ビルドを強制するには、対象の`target/release/.fingerprint/maplibre_native-<hash>`
ディレクトリを削除してからビルドし直す必要がある。これによりCMakeの増分ビルド
(変更した1ファイルのみ再コンパイル)は温存され、数分で完了する。

## 既知の制約(未解決)

- **ホイールでのズームは動作しない**: Slint 1.17.1の`linuxkms`バックエンドの
  ソース(`internal/backends/linuxkms/calloop_backend/input.rs`)を確認したところ、
  `Motion`/`MotionAbsolute`/`Button`は処理されているが、`ScrollWheel`系の
  イベントを処理するコードが一切ない。上流の未実装。CLAUDE.mdのv0成功条件
  「ホイール=拡大縮小」の実現方法は要検討(自前でイベントデバイスを読む、
  upstreamにパッチを送る、別のUXにマッピングし直す、等)
- **CPU描画によるカーソルの視覚的欠如**: `linuxkms-software`使用時、マウス
  カーソルのスプライトが画面に表示されない(ドラッグ操作自体は機能する)
- **パフォーマンス**: UI(Slint)・地図(maplibre-native)とも software rendering
  (llvmpipe/CPU)のため、CPU使用率が140%前後と重い。実用的な操作感になるかは
  今後の検証が必要
- **`linuxkms-femtovg`(ハードウェアGL)は併用不可**と結論したが、根本原因
  (Mesa側の制約なのか、maplibre-native側の実装の問題なのか)は完全には
  特定できていない。upstreamへの報告や、将来のMesa/Slintバージョンでの
  再検証の余地あり

## 次にやること

1. カーソル可視化、パフォーマンス、ホイール代替案の検討(優先度は要相談)
2. Stage 6: 自前のVBM/VLCM PMTiles(`/opt/kaga/data/{vbm,vlcm}.pmtiles`、
   取得済み)を`MAPLIBRE_STYLE_URL`に`pmtiles://`スタイルとして指定し表示確認
3. 恒久的な起動スクリプト・systemdユニットへの反映(Stage 7)
