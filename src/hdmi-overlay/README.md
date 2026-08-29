# hdmi-overlay

kagaが実際に実機(m329)で動かしているアプリのソース。[docs/decisions/0014](../../docs/decisions/0014-hdmi-path-zero-copy-gl.md)の通り、
[Yuiseki氏のpi-maplibre-native-slint-touch](https://github.com/yuiseki/pi-maplibre-native-slint-touch)の
`hdmi/`実装を参照・改変したもの。

**このディレクトリはビルド可能なプロジェクトではない**。上流の
`maplibre-native-slint`チェックアウトの`cpp/`ディレクトリへ重ねて
(`hdmi/scripts/build.sh`と同じ要領で)ビルドする前提のオーバーレイ差分集。

## kagaでの変更点(上流Yuiseki氏の`hdmi/`との差分)

- `gl_map_window.slint`:
  - Dance/Calm/Syncボタンを撤去(terrain未対応のため。プロパティ自体は残置)
  - 都市ボタン(3固定)→北海道の常時観測火山9座(気象庁の表示順、
    `VolcanoEntry`構造体配列)のComboBoxに変更。9件を内部スクロール無しで
    表示するには`src/vendor-patches/`のfluent ComboBoxパッチが別途必要
  - スタイル切替ドロップダウンをkitavolca/bvmap単体の2項目に変更(URLも
    `file://`に統一)
  - Wi-Fi SSID表示を削除(接続状態アイコンのみ残置。オフライン方針との
    整合性)
  - ステータスバーに開発用fps/解像度表示を追加(`debug-text`/
    `debug-visible`、`MAPLIBRE_DEBUG_INFO`で切替)
  - 画面下部全幅にVBM/VLCM地物の属性(名称のみ)表示バーを追加
    (`feature-info-text`)。ツールチップ/吹き出しではなく一行の下部パネル
  - 上部ツールバー右にシャットダウンボタン(赤系、`request-shutdown`
    コールバック)。kagaはキーボード/ネットワーク無しで持ち込む前提のため
- `main_gl.cpp`:
  - マウスホイールでのズームを独自実装(生evdev読み取り、
    `MAPLIBRE_WHEEL_DEVS`)。Slintの`linuxkms`バックエンドは`Axis`/wheel
    イベントを処理しないため。ズーム中心はカーソル位置(後述のホバー追跡を
    転用、画面中心固定ではない)
  - VBM/VLCM地物のホバー属性表示: `on_mouse_hovered`で位置を記録、
    `saver_timer`(60ms)で`SlintMapGL::query_feature_info()`を呼び
    スロットリング。hover検知そのものはSlint本体では既に可能で、
    `src/vendor-patches/`の`m-map-view.slint`パッチで転送経路を追加している
  - `MAPLIBRE_DEBUG_INFO`環境変数でステータスバーのfps/解像度表示をON/OFF
    (開発時のみ想定)
  - シャットダウンボタンのハンドラ(`sudo systemctl poweroff`)
- `src/slint_map_gl.cpp`/`.hpp`:
  - `MAPLIBRE_ZOOM_BIAS`環境変数を追加(fps対策・見た目調整、詳細は
    [docs/plan.md](../../docs/plan.md))
  - 直近のfps値を取得する`last_fps()`を追加(上記デバッグ表示用)
  - `query_feature_info(x, y)`を追加: `mbgl::Renderer::queryRenderedFeatures`
    でvbm/vlcmソースのフィーチャーを検索し、`名称`プロパティの値のみ返す

`platform/custom_file_source.*`・`src/style_list.*`・`src/voice_activity.*`・
`src/slint_gl_backend.*`は上流のまま(未改変、ビルド対象として必要なので同梱)。

**このオーバーレイに加えて`src/vendor-patches/`(上流Slint/
maplibre-native-slint本体そのものへのパッチ、別ディレクトリ)の適用も
必要**。詳細は[src/vendor-patches/README.md](../vendor-patches/README.md)参照。

## 実機への反映手順

m329上で:

```bash
cp src/hdmi-overlay/main_gl.cpp src/hdmi-overlay/gl_map_window.slint \
   ~/poc/pi-maplibre-native-slint-touch/hdmi/
cp src/hdmi-overlay/src/*.{cpp,hpp} ~/poc/pi-maplibre-native-slint-touch/hdmi/src/
cp src/hdmi-overlay/platform/*.{cpp,hpp} ~/poc/pi-maplibre-native-slint-touch/hdmi/platform/
cd ~/poc/pi-maplibre-native-slint-touch/hdmi
env PATH="$HOME/.cargo/bin:$PATH" bash scripts/build.sh
```

火山ComboBoxのスクロール解消・ホバー属性表示を有効にするには、上記に加えて
[src/vendor-patches/](../vendor-patches/README.md)の適用も必要(初回のみ、
`~/poc/mln-slint-cpp/build`を作り直さない限り一度適用すれば保持される)。

(`~/poc/mln-slint-cpp`の`.git`はディスク節約のため削除済み。`build.sh`の
クローン判定は`$WORK/cpp`の存在で見るようm329上でパッチ済み——このリポジトリの
`scripts/build.sh`相当は未整備、次にビルド手順を固める際にここへ持ち込む
候補)
