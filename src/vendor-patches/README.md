# vendor-patches

kagaが依存する上流プロジェクト(Slint、`maplibre-native-slint`)自体に加えた
パッチ。これらは`src/hdmi-overlay/`(kaga独自のアプリソース)とは違い、
**上流の共有コードそのものの改変**であり、ビルドホスト(m329)上の
FetchContent/vendorディレクトリに直接手で当てている——`hdmi/scripts/build.sh`
のoverlay機構(`cpp/`配下のみ対象)の対象外なので、このリポジトリで
バージョン管理しないと再ビルド環境構築のたびに失われる。

## 適用先と内容

| ファイル(このディレクトリ内) | 実機での適用先 | 内容・理由 |
|---|---|---|
| `slint-fluent-combobox/combobox.slint` | `~/poc/mln-slint-cpp/build/_deps/slint-src/internal/compiler/widgets/fluent/combobox.slint` | `visible-items: min(6, model.length)` → `model.length`。fluentスタイルのComboBoxは6件を超えると内部スクロールになる仕様で、火山9座のドロップダウンでスクロールが必要になり操作しづらかった(藤村さん指摘、2026-08-30)。上限を撤廃し全件を一度に表示 |
| `maplibre-native-slint-base/m-map-view.slint` | `~/poc/mln-slint-cpp/src/m-map-view.slint` | `TouchArea.pointer-event`のmoveハンドラに`!self.pressed`分岐を追加し、`MMapAdapter.mouse-hovered(x, y)`を新規発火。押下無しのホバー移動はSlintコア側では元々配送されている(`PointerEventKind.move`)が、この上流ファイルが`&& self.pressed`で握りつぶしていたため、ドラッグ用の`mouse-moved`とは別に転送する分岐を追加 |
| `maplibre-native-slint-base/m-map-adapter.slint` | `~/poc/mln-slint-cpp/src/m-map-adapter.slint` | 上記`mouse-hovered`コールバックの宣言を追加(globalの一部) |

**このディレクトリはビルドの一部として自動適用されない**。実機再構築時は
手動で上記の対応先へコピーする(下記コマンド参照)。`hdmi/scripts/build.sh`
自体にこれらの適用ステップを組み込むことは今のところしていない
(頻繁に手を入れる場所ではないため。次にビルド手順全体を整理する際の
候補——[docs/plan.md](../../docs/plan.md)の保守・整理の節参照)。

## 実機への反映手順

```bash
scp src/vendor-patches/slint-fluent-combobox/combobox.slint \
    "$KAGA_USER@$KAGA_HOST:/tmp/combobox.slint"
scp src/vendor-patches/maplibre-native-slint-base/m-map-view.slint \
    src/vendor-patches/maplibre-native-slint-base/m-map-adapter.slint \
    "$KAGA_USER@$KAGA_HOST:/tmp/"
ssh "$KAGA_USER@$KAGA_HOST" '
  cp /tmp/combobox.slint ~/poc/mln-slint-cpp/build/_deps/slint-src/internal/compiler/widgets/fluent/combobox.slint
  cp /tmp/m-map-view.slint ~/poc/mln-slint-cpp/src/m-map-view.slint
  cp /tmp/m-map-adapter.slint ~/poc/mln-slint-cpp/src/m-map-adapter.slint
'
```

その後は通常通り`hdmi/scripts/build.sh`(または`cmake --build`)でビルドする。
`combobox.slint`の変更はSlintコンパイラ自体(`i-slint-compiler`/`slint-cpp`
crate)の再ビルドを要するため、他の変更より時間がかかる(実測4〜9分/クレート)。

## 注意: `~/poc/mln-slint-cpp/build`が存在しない/作り直す場合

`build/_deps/slint-src`はCMakeのFetchContentが初回configure時に取得する
ディレクトリ。**configureをやり直す(`RECONFIGURE=1`や`build/`削除)と
このパッチは失われる**——[docs/decisions/0014](../../docs/decisions/0014-hdmi-path-zero-copy-gl.md)
に記載の通り、このpinされたref(`1f32a5a`)ではSlintが動くrelease/1
ブランチから取得されるため、再configureはmerge conflictを引き起こす
リスクもあり基本的に避けている。`~/poc/mln-slint-cpp/src/`(上流
`maplibre-native-slint`本体のソース)側は逆にconfigure非依存(リポジトリ
チェックアウトの一部)なので、`build/`を作り直してもこちらは保持される。
