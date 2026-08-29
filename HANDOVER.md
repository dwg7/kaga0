# Handover

kagaの現在の状態。次にこれを引き継ぐ人(人間でもAIでも)向け。

## Status as of 2026-08-30(深夜〜早朝、大きく進捗)

- **v0成功条件をほぼ全て達成**: VBM/VLCM表示、パン・ズーム・**マウスホイール
  ズームも独自実装で実機確認済み**(v0成功条件「ホイール=拡大縮小」達成)、
  北海道の主要火山(駒ヶ岳・十勝岳・雌阿寒岳)ボタン、すべて実機(m329)で
  確認済み。経緯は[DECISIONS.md](DECISIONS.md) D14、詳細は
  [docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)。
- **完全オフライン化を達成(2026-08-30)**: PMTiles(vbm/vlcm/bvmap)は
  `pmtiles://file://`(mbgl-core内蔵`LocalFileSource`、HTTP不使用)、
  フォント(glyphs、2フォントスタック計25MB)・スプライト(240KB)も
  GitHub Pagesから取得しローカル化。**busybox httpd(kaga-httpd.service)は
  廃止**、外部ネットワークへの依存は理論上ゼロになったはず(実機での
  ネットワーク切断状態での動作確認は物理作業のため藤村さん側でお願いしたい)
- **背景地図(bvmap、GSI最適化ベクトルタイル)を完全オフライン化・実機反映済み**。
  全国16.9GBから`pmtiles extract`で北海道+周辺(稚内・択捉島・渡島大島・
  龍飛岬を含む拡張bbox `139.2,41.1,149.5,45.7`)、z16(GSIスタイルが
  z17でのオーバーズームを前提にした設計だったため、z14打ち切りでは
  札幌の建物等が欠落する不具合があり修正済み)、2.5GB
- **appliance化(`just autoexec true/false`)が動作する**: `kaga-map.service`
  単体で完結(`Conflicts=getty@tty1.service`でコンソールと自動排他)。
  `kaga-httpd.service`はfile://切り替えにより不要化、切り戻し用に残置のみ
- **実装は`hdmi/`(zero-copy GL、C++)ベース**。ビルドは`~/poc/mln-slint-cpp`
  (m329上、ネイティブビルド)、ソース差分は`src/hdmi-overlay/`に**このリポジトリで
  バージョン管理**(反映手順は[src/hdmi-overlay/README.md](src/hdmi-overlay/README.md))
- ステータスバー: Wi-Fi SSID表示は削除(藤村さん判断、オフライン方針との
  整合性)、`MAPLIBRE_DEBUG_INFO=1`で解像度/fps表示を追加(開発時のみ想定、
  当面は表示)

## 次にやること(優先順)

[docs/plan.md](docs/plan.md)に優先度・難易度付きで整理済み。特に:

1. **実機でのオフライン動作の物理確認**(Wi-Fi/イーサネット切断状態で
   地図が問題なく動くか——ネットワーク遮断は物理作業のため藤村さん側)
2. 火山リストの整備(GSI火山基本図・火山土地条件図サイトが原典、北海道分
   抽出、気象庁常時観測火山の順で並べる——未着手)
3. 解像度の段階的引き上げ(1920x1080→2560x1440→4K、fps計測しながら)
4. 保守・整理(`scripts/deploy.sh`の整理、ディスク管理の定常化等)
5. VBMのズームレベル割り当ての見直し(bvmapほど作り込まれていない、
   `MAPLIBRE_ZOOM_BIAS`で対症療法中——着手は保留)
6. チャレンジ目標: VBM地物へのマウスオーバー属性表示

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
