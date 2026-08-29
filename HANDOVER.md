# Handover

kagaの現在の状態。次にこれを引き継ぐ人(人間でもAIでも)向け。

## Status as of 2026-08-30(未明〜早朝、非常に大きく進捗した一晩)

v0成功条件をすべて実機確認済み。CLAUDE.md §10・[docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)・
[docs/plan.md](docs/plan.md)に詳細記録。要点:

- **地図表示**: VBM/VLCM+bvmap(GSI最適化ベクトルタイル、北海道+稚内・
  択捉島・渡島大島・龍飛岬までの拡張bbox、z16)。ドラッグ=パン、
  ダブルクリック/マウスホイール(**カーソル位置中心**)=ズーム、すべて実機確認済み
- **完全オフライン化**: PMTiles・スタイル・フォント(2書体25MB)・
  スプライトすべて`file://`ローカル読み込み。busybox httpdは廃止
  (`kaga-httpd.service`は切り戻し用に残置のみ)。**ネットワーク切断状態での
  最終確認は藤村さんが約25時間後に出勤先で実施予定**(2026-08-30時点で未実施)
- **UI**: 火山ナビゲーションは気象庁常時観測火山9座のComboBox
  (スクロール無しで全件表示、fluent ComboBoxへのパッチが必要——後述)。
  VBM/VLCM地物のホバー属性表示(画面下部全幅バー、`名称`のみ)。
  シャットダウンボタン(赤系、確認ダイアログ無し)。Wi-Fi SSID表示は削除
  (接続アイコンのみ残置)。fps/解像度デバッグ表示は`MAPLIBRE_DEBUG_INFO=1`
  で当面表示中
- **解像度**: 1440p(2560x1440)で運用中。1080p/4Kも動作確認済み
  (fps: 1080p 29-33、1440p 11-12、4K 4-5——1440pが実用上のバランス点、
  藤村さん判断)
- **appliance化**: `just autoexec true/false`で`kaga-map.service`単体
  (`Conflicts=getty@tty1.service`でコンソールと自動排他)
- **ビルド**: `hdmi/`(zero-copy GL、C++)、m329上でネイティブビルド。
  アプリのソース差分は`src/hdmi-overlay/`、**上流Slint/maplibre-native-slint
  本体そのものへの3件のパッチ**(ComboBoxのスクロール制限撤廃、hover
  イベント転送の追加)は`src/vendor-patches/`——どちらもこのリポジトリで
  バージョン管理(以前は実機にしか存在せず、今夜途中で気づいて追加した)

## 次にやること(優先順)

[docs/plan.md](docs/plan.md)に優先度・難易度付きで整理済み。特に:

1. **実機でのオフライン動作の物理確認**(藤村さんが約25時間後に出勤先で。
   Wi-Fi/イーサネット切断状態で地図が問題なく動くか)
2. 火山リストの原典(GSI火山基本図・火山土地条件図サイト)側の確認——
   気象庁の座標で実用上足りているため優先度は下げてよいかもしれない
3. VBM style.json(text-size/icon-size等)の恒久対応をどこで管理するか
   ——`stars-21`という既存の対話セッションをゲートキーパーとする案を
   藤村さんに提案済み、連絡はまだ実施していない
4. VBMのズームレベル割り当ての見直し(bvmapほど作り込まれていない、
   `MAPLIBRE_ZOOM_BIAS`で対症療法中——着手は保留)
5. 保守・整理(`scripts/deploy.sh`の整理、ディスク管理の定常化等)
6. GPU使用率のステータスバー表示(RPiでの一般的な取得手段が無く要調査)

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
