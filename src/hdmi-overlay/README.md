# hdmi-overlay

kagaが実際に実機(m329)で動かしているアプリのソース。[docs/decisions/0014](../../docs/decisions/0014-hdmi-path-zero-copy-gl.md)の通り、
[Yuiseki氏のpi-maplibre-native-slint-touch](https://github.com/yuiseki/pi-maplibre-native-slint-touch)の
`hdmi/`実装を参照・改変したもの。

**このディレクトリはビルド可能なプロジェクトではない**。上流の
`maplibre-native-slint`チェックアウトの`cpp/`ディレクトリへ重ねて
(`hdmi/scripts/build.sh`と同じ要領で)ビルドする前提のオーバーレイ差分集。

## kagaでの変更点(上流Yuiseki氏の`hdmi/`との差分)

- `gl_map_window.slint`: Dance/Calm/Syncボタンを撤去、都市ボタン→北海道の
  火山3座(駒ヶ岳・十勝岳・雌阿寒岳)、スタイル切替ドロップダウンを
  kitavolca/bvmap単体の2項目に変更、Wi-Fi SSID表示を削除(アイコンのみ残置)、
  ステータスバーに開発用fps/解像度表示を追加(`debug-text`/`debug-visible`)
- `main_gl.cpp`: マウスホイールでのズームを独自実装(生evdev読み取り、
  `MAPLIBRE_WHEEL_DEVS`)。Slintの`linuxkms`バックエンドは`Axis`/wheel
  イベントを処理しないため。`MAPLIBRE_DEBUG_INFO`環境変数でステータスバーの
  fps/解像度表示をON/OFF(開発時のみ想定)
- `src/slint_map_gl.cpp`/`.hpp`: `MAPLIBRE_ZOOM_BIAS`環境変数を追加
  (fps対策・見た目調整、詳細は[docs/plan.md](../../docs/plan.md))、
  直近のfps値を取得する`last_fps()`を追加(上記デバッグ表示用)

`platform/custom_file_source.*`・`src/style_list.*`・`src/voice_activity.*`・
`src/slint_gl_backend.*`は上流のまま(未改変、ビルド対象として必要なので同梱)。

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

(`~/poc/mln-slint-cpp`の`.git`はディスク節約のため削除済み。`build.sh`の
クローン判定は`$WORK/cpp`の存在で見るようm329上でパッチ済み——このリポジトリの
`scripts/build.sh`相当は未整備、次にビルド手順を固める際にここへ持ち込む
候補)
