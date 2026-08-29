# Handover

kagaの現在の状態。次にこれを引き継ぐ人(人間でもAIでも)向け。

## Status as of 2026-08-30

- **v0成功条件のコア部分を達成**: VBM/VLCM PMTilesの表示、パン・ズーム、
  完全オフライン動作(一部フォント/スプライトを除く)、北海道の主要火山
  (駒ヶ岳・十勝岳・雌阿寒岳)への切り替え、すべて実機(m329)で確認済み。
  経緯は[DECISIONS.md](DECISIONS.md) D14、詳細は
  [docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)。
- **実装は`hdmi/`(zero-copy GL、C++)ベース**、`rust/`実装(旧Stage 3-5)は
  完全に非採用・削除済み(SPI機体向けレシピをHDMI機体に誤って適用していたと
  判明したため)。ビルドは`~/poc/mln-slint-cpp`(m329上、ネイティブビルド。
  クロスコンパイルではない)、ソース差分は`~/poc/pi-maplibre-native-slint-touch/hdmi/`
  に置いて`build.sh`でoverlay+ビルドする運用。
- **appliance化(`just autoexec true/false`)が動作する**: `systemd/kaga-httpd.service`
  (PMTiles配信)+`kaga-map.service`(地図本体、`Conflicts=getty@tty1.service`で
  コンソールと自動排他)。`scripts/toggle-autoexec.sh`が実体。
- **背景地図(bvmap、GSI最適化ベクトルタイル)をオフライン化済み**。全国16.9GBから
  `pmtiles extract`で北海道分(稚内・択捉島まで含む拡張bbox)のみ抽出。
  **z16まで抽出し直す作業が進行中**(最初z14で抽出してしまい、札幌の建物等
  z15-17がスタイル側でオーバーズーム前提だったため表示されなかった不具合を
  修正中——このHANDOVER.md更新時点で転送が完了しているか要確認、
  `ssh $KAGA_USER@$KAGA_HOST 'ls -la /opt/kaga/data/bvmap.pmtiles*'`で確認できる)。
- **マウスホイールでのズームを独自実装済み(ビルド成功、実機での動作確認は未実施)**。
  Slintの`linuxkms`バックエンドが`Axis`(wheel/scroll)イベントを一切処理しない
  ため、`main_gl.cpp`に生evdev読み取りスレッドを追加し、既存の`net_ssid`と
  同じ「バックグラウンドスレッドはatomicに書くだけ、UIスレッドの`flyto_timer`
  (200ms周期)が読んで`smap->handle_wheel_zoom()`を呼ぶ」パターンで実装。
  `MAPLIBRE_WHEEL_DEVS`で対象デバイスを上書き可能(既定は`REL_WHEEL`能力での
  自動検出)。

## 次にやること(優先順)

1. **bvmap z16再抽出の転送完了確認 → 実機で動作確認**(このHANDOVER更新の
   直前に開始した作業。転送先は`/opt/kaga/data/bvmap.pmtiles.new`、確認後
   `bvmap.pmtiles`にmvして`kaga-map.service`を再起動する)
2. **マウスホイールズームの実機動作確認**(ビルドは通っているが、
   `kaga-map.service`再起動後にトラックボールのホイールで実際にズームする
   か未確認)
3. その他の未着手項目は[docs/plan.md](docs/plan.md)に優先度・難易度付きで
   整理済み(火山リストの拡充、ステータスバーへのfps/解像度/CPU・GPU使用率
   表示、`pmtiles://file://`実験、解像度の段階的引き上げ、マウスオーバー
   属性表示など)

## 引き継ぐ人が最初に読むべきもの

1. [CLAUDE.md](CLAUDE.md) — プロジェクト概要・設計思想・v0スコープ
2. このファイル — 今の状態
3. [DECISIONS.md](DECISIONS.md) — なぜこうなっているか(索引。詳細は
   [docs/decisions/](docs/decisions/)配下)
4. [docs/plan.md](docs/plan.md) — 次に何をやるか(優先度・難易度付き)

## 実機(m329)への接続

`.env`(git管理外)に`KAGA_HOST`/`KAGA_USER`。`just ssh`または
`ssh $KAGA_USER@$KAGA_HOST`。ビルド成果物は実機上の
`~/poc/mln-slint-cpp/build/cpp/maplibre-slint-gl`、appliance化後は
`/opt/kaga/bin/maplibre-slint-gl`にコピーされる(`just autoexec true`が実施)。
