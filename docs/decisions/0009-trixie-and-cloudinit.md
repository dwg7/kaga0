# 9. Trixieベースの "Raspberry Pi OS Lite (64-bit)" + cloud-init user-data に切り替える

- ステータス: 承認 — [0008](0008-legacy-bookworm-image.md) を撤回
- 日付: 2026-08-29

## 状況

[0008](0008-legacy-bookworm-image.md)では、custom.toml方式(`init_format: systemd`)が
確実に動くことを理由にLegacy(Bookworm)を選んだ。一方、以下の懸念が残っていた:

- kaga0以外の自分たちのプロジェクトは既にTrixieを使っている(藤村さん指摘)
- 「いずれ廃止される方式」に今から乗ることが技術的負債にならないか
- MapLibre Nativeという若い技術が、そもそもTrixieで動くのか
- cloudinit-rpi(Trixieの新方式)は本当に制御できるのか

この2点(MapLibre Nativeの動作実績、cloudinit-rpiの制御可能性)を実際に調査した。

### 調査結果1: MapLibre NativeはTrixie上のRPi4で実機検証済み

`maplibre/maplibre-native-slint`のPR
[#66](https://github.com/maplibre/maplibre-native-slint/pull/66)(2026-06-19マージ、
著者: [yuiseki](https://github.com/yuiseki) — 本プロジェクトのCLAUDE.mdが参照実装として
挙げているまさにそのリポジトリの最多コントリビューターの一人)が、
LinuxKMSバックエンド対応(`linuxkms-noseat`機能)を追加し、その検証環境([rust/RASPBERRY_PI.md](https://github.com/maplibre/maplibre-native-slint/blob/main/rust/RASPBERRY_PI.md))は:

> Build host: Raspberry Pi 5, Debian 12 (bookworm)
> **Display host: Raspberry Pi 4, Debian 13 (trixie)**, 480x320 SPI/HDMI LCD

まさにkagaが使う実機(RPi4)・OS(Trixie)の組み合わせで、PMTiles(planetソース)を
含むスタイルの描画まで確認されている。

同ガイドにより、**RPiのVideoCore GPUはmaplibre-nativeが必要とするハードウェア
GLES3パスを持たず、Mesaのソフトウェアラスタライザ(llvmpipe)へのフォールバックが
必須**という、OS選択とは独立した重要な技術的制約も判明した。これは
[0010](0010-software-gl-required.md)に別途記録する。

### 調査結果2: cloudinit-rpiは業界標準のcloud-initそのもの

Raspberry Pi公式記事([Cloud-init on Raspberry Pi OS](https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/))によれば、Trixie系イメージのbootパーティションには
`meta-data`(既定で同梱、変更不要)・`user-data`(YAML、`#cloud-config`ヘッダ必須)・
`network-config`(任意)が置かれ、`user-data`でhostname・ユーザー作成・SSH公開鍵・
sudo・locale/timezoneを設定できる。cloud-init自体はRPi固有の発明ではなく、
クラウド/仮想化業界で長年使われてきた標準機構であるため、RPi固有のcustom.toml
(0008時点でgistや掲示板から仕様を組み立てるしかなかった)より、スキーマを
確信を持って扱える。

## 決定

`scripts/flash-sdcard.sh`の既定OSを再び **"Raspberry Pi OS Lite (64-bit)"**
(Trixie, `init_format: cloudinit-rpi`)に戻す。カスタマイズは`custom.toml`ではなく
`user-data`(cloud-init)で行う。スクリプトは解決した`init_format`が
`cloudinit-rpi`か`systemd`かで生成するファイルを分岐し、想定外の形式であれば
エラーで停止する(0008から継続する安全策)。

`user-data`生成はbashのヒアドキュメント文字列展開ではなく、Python の
`json.dumps()`で各値(パスワード等)をエスケープしてから埋め込む。パスワードに
`"`や`\`が含まれるとYAMLが壊れ、カスタマイズがサイレントに失敗しうるため。

## 結果

- 良い点: 他プロジェクトとOSの流儀が揃う。MapLibre Native側の実績とも一致する。
  cloud-init自体の仕様変更・廃止リスクはRPi固有機構より低いと考えられる
- 良い点: `custom.toml`方式もLegacyへの上書き(`OS_IMAGE`環境変数)で引き続き使える
  ため、フォールバックを失わない
- トレードオフ: Trixieでの長期運用実績はBookwormほど蓄積されていない
  (2026-06-18リリース、まだ日が浅い)。実機でのStage 1(SSH到達性)確認を
  丁寧に行う
