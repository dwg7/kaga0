# Handover

kagaの現在の状態。次にこれを引き継ぐ人(人間でもAIでも)向け。

## Status as of 2026-08-30(v0達成 → 実運用調整 → VBMスタイル本格改善まで到達)

**藤村さん自身の評価(2026-08-30)**: 「一応の完成形」。v0成功条件は全て実機確認済み、
CLAUDE.md §10・[docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)・
[docs/plan.md](docs/plan.md)に詳細記録。要点:

- **地図表示**: VBM/VLCM+bvmap(GSI最適化ベクトルタイル、北海道+稚内・
  択捉島・渡島大島・龍飛岬までの拡張bbox、z16)。ドラッグ=パン、
  ダブルクリック/マウスホイール(**カーソル位置中心**)=ズーム、すべて実機確認済み
- **完全オフライン化**: PMTiles・スタイル・フォント(2書体25MB)・
  スプライトすべて`file://`ローカル読み込み。busybox httpdは廃止
  (`kaga-httpd.service`は切り戻し用に残置のみ)。**ネットワーク切断状態での
  物理確認**: 藤村さんの出勤先での実施予定——問題があれば2026-08-31(月)夕方に
  報告、との整理(2026-08-30時点で結果報告なし、無音であれば問題なしとみなす)
- **UI**: 火山ナビゲーションは気象庁常時観測火山9座のComboBox
  (スクロール無しで全件表示、fluent ComboBoxへのパッチが必要——後述)。
  VBM/VLCM分類塗り面の属性ホバー表示(画面下部全幅バー、`name`属性+
  fill-colorスワッチ、実機確認済み)。シャットダウンボタン(赤系、確認
  ダイアログ無し)——**物理電源サイクル込みで実機確認済み**(藤村さん:
  「シャットダウンは問題なし。autoexecも問題なく動いていた」)。Wi-Fi SSID
  表示は削除(接続アイコンのみ残置)。fps/解像度/CPU使用率/SoC温度の
  デバッグ表示は`MAPLIBRE_DEBUG_INFO=1`で灰色(技術情報として控えめに)
  表示中、実機確認済み(GPU使用率は`btop`でもRPiでは取得不可と判明し
  対応不可と判断)
- **解像度**: 1440p(2560x1440)で運用中。1080p/4Kも動作確認済み
  (fps: 1080p 29-33、1440p 11-12、4K 4-5)。`just set-resolution
  auto|1080p|1440p|4k [--reboot]`で切替可能(auto=EDID自動認識に戻す。
  Slintの`linuxkms`バックエンドが起動時にディスプレイのPREFERREDモードを
  自動選択する実装を持つことをソースで確認済み)
- **appliance化**: `just autoexec true/false`で`kaga-map.service`単体
  (`Conflicts=getty@tty1.service`でコンソールと自動排他)
- **ビルド**: `hdmi/`(zero-copy GL、C++)、m329上でネイティブビルド。
  アプリのソース差分は`src/hdmi-overlay/`、上流Slint/maplibre-native-slint
  本体そのものへの3件のパッチは`src/vendor-patches/`——どちらもこの
  リポジトリでバージョン管理
- **VBMスタイルのupstream貢献体制**: `hfu/stars`をゲートキーパー
  (`stars-21`セッション)、`kitavolca`(データパイプライン、現在停止中)は
  ドキュメント追従の立場、という役割分担を確立。実際に3件のPRをマージ・
  本番反映まで完了:
  - [hfu/stars#1](https://github.com/hfu/stars/pull/1): VBM注記text-size
    10→13、温泉アイコンのzoom連動icon-size
  - [hfu/stars#2](https://github.com/hfu/stars/pull/2): 道路線幅を約40%細く
  - [hfu/stars#3](https://github.com/hfu/stars/pull/3): VBM z11に団子だった
    38レイヤーをz10-14に分散(藤村さん実機確認: 「改善を実感している」)。
    等高線・道路・建物の16コードはtippecanoeのタイルサイズ制約でz13未満に
    データが無いため対象外(kitavolcaの`docs/zoom-policy.md`で確認)
  - bvmapのz16再抽出後のfps低下(z14時29-33fps→z16時12-15fps)は
    **許容する、と藤村さんが判断**(2026-08-30、精細さを優先)

## 次にやること(優先順)

[docs/plan.md](docs/plan.md)に優先度・難易度付きで整理済み。特に:

1. 火山リストの原典(GSI火山基本図・火山土地条件図サイト)側の確認——
   気象庁の座標で実用上足りているため優先度は下げてよいかもしれない
2. 道路・建物・等高線グループ(z13固定、データ制約)の線幅等の見た目調整
   (道路PR#2と同じ形で追加のPRがあり得る、着手は未定)
3. 保守・整理(`scripts/deploy.sh`の整理、ディスク管理の定常化等)

GPU使用率のステータスバー表示は対応不可と判断し取り下げ(藤村さんが実機で
`btop`を試したところMacでは取れる項目がRPiでは取れないことを確認、
2026-08-30——kaga固有の問題ではなくRPi側の技術的制約と判断)。
fps・CPU使用率・SoC温度は実装・実機確認とも完了済み。

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
