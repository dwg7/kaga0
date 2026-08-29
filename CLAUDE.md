# kaga0 — Claude Code 引き継ぎドキュメント

このファイルは `dwg7/kaga0` リポジトリのルートに置く、Claude Code向けのプロジェクト文脈です。
新しいセッションを開始する際は、まずこのファイルを読んでください。

参照元: [UNopenGIS/7 issue #987](https://github.com/UNopenGIS/7/issues/987)

---

## 1. プロジェクト概要

**kaga (kitavolca air-gapped appliance)** は、[kitavolca](https://github.com/hfu/kitavolca) の成果である
VBM(火山基本図)・VLCM(火山土地条件図)ベクトルタイルを、ネットワークに依存せず表示するための
可搬型地理空間アプライアンスである。

```
kitavolca = PMTiles を生成するパイプライン
kaga      = PMTiles を閲覧するアプライアンス
```

両者は競合ではなく補完関係。kitavolca は「データを作る」、kaga は「データを見せる」。

### 背景・動機

kitavolca の現行デプロイはGitHub Pagesを利用しているが、省庁・自治体・防災機関・企業ネットワーク等では
GitHub Pages・外部CDN・公開ウェブサービスへのアクセスが制限される場合がある(実際に確認済み)。

> 「地図を公開する」のではなく、「地図を持ち込む」というアプローチ。

---

## 2. 設計思想

kaga は汎用コンピュータではない。**「火山地図を確実に表示する」ことに限定した専用機**として設計する。

理想的な体験:

```
電源投入 → 地図起動 → マウス操作 → 説明・議論
```

利用者が意識するべきものは地図だけ。ブラウザ設定・ネットワーク設定・サーバ起動手順は表面に出さない。

---

## 3. プラットフォームとソフトウェアスタック

- **初期ターゲット**: Raspberry Pi 4B(将来的にPi 5、CyberDeck形態も検討)
- **接続構成**: HDMI→プロジェクタ/大型ディスプレイ、USBマウス、USBキーボード(保守用)

**目標スタック**(Browser-less / X11-less / Wayland-less):

```
Raspberry Pi OS (Lite, 64bit)
    ↓
MapLibre Native
    ↓
Slint (LinuxKMS backend)
    ↓
DRM/KMS
```

systemdによる直接起動を目指す。

**既存の参照実装**: [`maplibre/maplibre-native-slint`](https://github.com/maplibre/maplibre-native-slint) が
Slintコンポーネント群・C++バックエンド(`mbgl-slint`)・Linux/Windows/macOS対応の
カノニカルなリファレンス実装として既に存在する。ゼロから統合するのではなく、これをフォーク・参照して始める。

SlintのLinuxKMSバックエンドは、DRM dumb buffer方式(フォールバックとしてレガシーfbdev)、
libinput/libudevでの入力処理、libseatによるroot不要アクセス(または `backend-linuxkms-noseat` で
root権限アクセス)をサポートしている。

**既知の技術的制約**: RPiのVideoCore GPUはmaplibre-nativeが要求するハードウェアGLES3パスを
持たず、Mesaのソフトウェアラスタライザ(llvmpipe)へのフォールバックが必須
(`LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe`)。上記の参照実装がRPi4/Trixieで
実機検証済み。詳細・実行時の環境変数は[docs/decisions/0010](docs/decisions/0010-software-gl-required.md)参照。

---

## 4. v0のスコープ

### 実装対象

- VBM PMTiles / VLCM PMTiles のオフライン表示
- HDMIプレゼンテーション利用
- マウス操作(ドラッグ=移動、ホイール=拡大縮小)

### 実装できれば望ましい

- hillshade(Terrainとは切り離して検討。Nice to have)

### v0のスコープ外

- terrain、3D地形表現、pitch、bearing rotation、flyTo、高度な3Dナビゲーション
- (Terrainが利用可能になればv2以降で再検討)

### 成功条件

1. 電源投入後に直接地図が起動する
2. インターネット接続なしで動作する
3. 北海道の主要火山を表示できる
4. パン・ズームが快適である
5. 会議や打合せで実利用できる

---

## 5. ロードマップ

| バージョン | 内容 |
|---|---|
| v0 | Raspberry Pi 4B、MapLibre Native、VBM/VLCM PMTiles、基本パン・ズーム |
| v1 | hillshade対応(可能な場合)、背景地図強化、航空写真対応 |
| v2 | Terrain再評価、3D機能検討 |
| v3 | CyberDeck化、バッテリー搭載、現地説明・防災訓練利用 |

---

## 6. リポジトリ構成方針

```
dwg7/kaga0/
├── README.md                 # kaga v0の成功条件、issue #987へのリンク
├── CLAUDE.md                  # このファイル
├── Justfile                    # タスクランナー(採用理由はdocs/decisions参照)
├── .env.example                # 環境固有の値のテンプレート(.envはgit管理外)
├── docs/
│   ├── hardware-setup.md      # RPi物理セットアップ手順
│   ├── network-troubleshooting.md
│   └── decisions/              # ADR的な意思決定記録
├── src/                        # maplibre-native-slint を vendor/submodule で参照
├── data/
│   └── .gitignore              # PMTiles本体はリポジトリに含めない(容量大)
├── scripts/
│   ├── fetch-data.sh           # depot.optgeo.orgからVBM/VLCM PMTilesを取得
│   ├── flash-sdcard.sh         # SDカードイメージ焼き込み自動化(rpi-imager --cli)
│   ├── deploy.sh                # RPiへのデプロイ
│   └── diagnose.sh              # 実機の状態診断コマンド一式
└── systemd/
    └── kaga.service              # 起動時自動起動の定義
```

**方針メモ:**

- PMTilesデータ本体はGitに含めない。`data/`は取得スクリプトのみ配置。
- `docs/decisions/`はADR(Architecture Decision Record)形式で、後から本人も含めて
  経緯を追えるようにする。issue本文に既にある判断(なぜNative実装か、なぜTerrainをv0スコープ外にしたか)
  に加え、実装が進むにつれ増える判断をここに残す。
- タスクランナーには`Justfile`(Makeではなく)を採用。理由は
  [docs/decisions/0007-secrets-policy.md](docs/decisions/0007-secrets-policy.md)参照(dotenv対応が決め手)。
- 実機のホスト名・ユーザー名・SSH鍵ファイル名など環境固有の値は`.env`(git管理外)に置き、
  リポジトリには`.env.example`のプレースホルダーのみを残す。理由・詳細は
  [docs/decisions/0006](docs/decisions/0006-hostname-naming.md)・[0007](docs/decisions/0007-secrets-policy.md)参照。
  新しいセッションはまず`.env`の有無を確認し(`just setup`)、なければ`.env.example`から作る。

---

## 7. ハードウェアプロジェクトにおける作業分担(重要)

Claude Codeは実機に物理的に触れない。以下を明確に分担する。

**Claude Codeが担当する範囲:**

- ビルドスクリプト・デプロイスクリプトの作成
- クロスコンパイル/QEMUでの事前検証(実機に持っていく前にビルドが通ることを確認)
- ログ・診断出力の解析(`scripts/diagnose.sh`の出力を貼り付けてもらえば原因特定を試みる)
- systemdユニットファイル、設定ファイルの作成・修正
- ドキュメント・ADRの整備

**人間(藤村さん)が担当する範囲:**

- SDカードの物理的な書き込み・挿入
- 電源投入、HDMI/マウス/キーボードの物理接続
- 実機での動作確認、画面の目視確認
- ネットワーク環境依存の切り分け(現地ネットワークでのmDNS到達性など)

**観測可能性を最初から作り込む:**

実機の状態はClaude Codeから直接見えないため、`journalctl`のログ、systemdサービスの状態、
SSH経由で取得できる診断コマンド一式を早期に用意する。「動きません」ではなく、
ログを貼り付けるだけで原因を特定できる状態を目指す。

**小さく確認可能な単位で進める:**

以下の段階ごとに動作確認・コミット・issueコメントを刻む。

```
1. RPi OS Lite が起動し、SSHで入れる
2. コンソール(TTY)にHDMI経由で何か表示できる(単色画面等で可)
3. DRM/KMS経由でSlintのHello Worldアプリが表示できる
4. MapLibre Native単体が何らかの形でレンダリングできる(ヘッドレス出力でも可)
5. MapLibre NativeとSlintが繋がり、地図がHDMI画面に出る
6. VBM/VLCM PMTilesを実際に表示する(← v0の成功条件到達点)
7. systemdで自動起動、電源投入だけで地図が立ち上がる
```

---

## 8. Raspberry Pi 初期セットアップ手順

`scripts/flash-sdcard.sh`(`just flash-sdcard <device>`)で自動化済み。手順の詳細・背景は
[docs/hardware-setup.md](docs/hardware-setup.md)参照。要点:

1. `cp .env.example .env` して `KAGA_HOST`・`SSH_PUBKEY_FILE` 等の実値を設定
   (ホスト名の決め方は[0006](docs/decisions/0006-hostname-naming.md)、実値を`.env`に置く理由は
   [0007](docs/decisions/0007-secrets-policy.md)参照)
2. OS: **Raspberry Pi OS Lite (64-bit)**(Trixie。GUIデスクトップ不要、軽量、
   Browserless構成に合う。一度はLegacy(Bookworm)を選んだが撤回した経緯は
   [0008](docs/decisions/0008-legacy-bookworm-image.md)→[0009](docs/decisions/0009-trixie-and-cloudinit.md)参照)
3. ホスト名・ユーザー・SSH公開鍵は `user-data`(cloud-init。Trixie系の起動時カスタマイズ機構)経由で設定。
   **公開鍵認証のみ有効化し、パスワード認証は無効化する**(デフォルトの`pi`ユーザーは存在しないため
   ユーザー作成が必須)
4. SDカードを挿し、電源投入(RPi 4Bは5V/3A USB-C)
5. 疎通確認: `ssh $KAGA_USER@$KAGA_HOST`(`just ssh`)

### ネットワーク疎通トラブルシューティング

`.local`名前解決はmDNS(Avahi)依存。詳細な切り分け手順は
[docs/network-troubleshooting.md](docs/network-troubleshooting.md)参照。

**留意点**: 省庁・自治体・防災機関ネットワークでは、mDNS(UDP 5353)がブロックされている可能性が高い
(GitHub Pagesアクセス制限と同根の問題)。開発時の疎通確認と、実配備先での接続性検証は別問題として扱う。

将来的にkaga1、kaga2と複数台展開する際は、それぞれの実機ごとに個体コードネームと
`.env`を用意する([0006](docs/decisions/0006-hostname-naming.md)参照)。

---

## 9. データ配布

VBM/VLCM PMTilesは `depot.optgeo.org` から直接取得する(`just fetch-data` で開発機へ、
`just fetch-data-remote` で実機へ直接)。背景は[0005](docs/decisions/0005-depot-optgeo-org.md)参照。

---

## 10. 現時点でのステータス

**最新の生きた状態は[HANDOVER.md](HANDOVER.md)を参照**(このセクションは
Stage単位のマイルストーン記録として残す。日々更新されるのはHANDOVER.md側)。
意思決定の経緯は[DECISIONS.md](DECISIONS.md)(索引)→[docs/decisions/](docs/decisions/)
(個別ADR)、今後の作業は[docs/plan.md](docs/plan.md)。

- [x] `dwg7/kaga0` リポジトリ作成
- [x] 実機準備(Raspberry Pi 4、コードネーム決定済み — 詳細は`.env`、[0006](docs/decisions/0006-hostname-naming.md))
- [x] SDカード書き込み・実機への疎通確認(`scripts/flash-sdcard.sh`、Trixie+cloud-init。
      有線・Wi-Fi(Buffalo系AP)両方でSSH到達性を確認済み)
- [x] Stage 1: RPi OS Liteが起動し、SSHで入れる
- [x] Stage 2: コンソール(TTY)にHDMI経由で表示できる(JAPANNEXTディスプレイ、
      HDMI0、`m329 login:`プロンプトを目視確認済み)
- [x] Stage 3: DRM/KMS経由でSlintのHello Worldアプリが表示できる(ハードウェアGL
      〈v3d〉で動作、トラックボールのカーソル追従も確認済み。詳細・経緯は
      [docs/stage3-build-log.md](docs/stage3-build-log.md)参照)
- [x] Stage 4: MapLibre Native単体のビルド成功(初回は`rust/`実装〈EGL対応版0.8.7、
      C++にパッチ適用〉で到達。詳細は[docs/stage4-5-build-log.md](docs/stage4-5-build-log.md)参照。
      その後2026-08-30に**Yuisekiさんの`hdmi/`実装〈C++、zero-copy GL〉が
      正しいレシピと判明し切り替え**——`rust/`実装はSPI〈GPU無し〉機体向けの
      レシピをHDMI〈GPU有り〉機体に誤って適用していたと判明。詳細・謝辞は
      [docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)参照)
- [x] Stage 5: MapLibre NativeとSlintが繋がり、地図がHDMI画面に出た。
      `hdmi/`(zero-copy GL、ハードウェアGL/V3D)でドラッグ=パン・ダブル
      クリック=ズームイン・マウスカーソル表示、すべて動作確認済み
      (CPU使用率25%、29-38fps。旧`rust/`+ソフトウェアレンダリング版の
      140%前後から劇的に改善。詳細は[docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)参照)。
      **マウスホイールでの拡大縮小も独自実装で達成**(Slint上流の`linuxkms`
      バックエンドは`Axis`/wheelイベントを処理しないため、生evdev読み取り
      スレッドを追加。v0成功条件「ホイール=拡大縮小」を当初の「上流の制約で
      未対応」という結論から覆した。詳細は[docs/plan.md](docs/plan.md)参照)
- [x] Stage 6: VBM/VLCM PMTilesを実際に表示(← v0の成功条件到達点、
      藤村さん実機確認済み「いけてるね」)。背景地図として国土地理院
      (GSI)の`bvmap`を`pmtiles extract`でオフライン化して追加
      (北海道+稚内・択捉島・渡島大島・龍飛岬までの拡張bbox、z16、2.5GB、
      詳細は[docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)参照)。
      **フォント・スプライトも含め完全ローカル化済み**(2026-08-30。
      GitHub Pages依存は解消。ネットワーク切断状態での最終確認は物理作業の
      ため未実施、藤村さんが後日出勤先で実施予定)
- [x] Stage 7: systemdで自動起動、電源投入だけで地図が立ち上がる
      (`just autoexec true/false`、`kaga-map.service`が
      `Conflicts=getty@tty1.service`を持つためコンソールとの排他は
      systemdが自動処理。手動での`systemctl stop getty@tty1`は不要になった)
