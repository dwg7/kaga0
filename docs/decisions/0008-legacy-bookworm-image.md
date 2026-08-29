# 8. SDカード書き込みには "Raspberry Pi OS (Legacy, 64-bit) Lite" (Bookworm) を使う

- ステータス: 承認
- 日付: 2026-08-29

## 状況

`scripts/flash-sdcard.sh`の実装中、実機にインストール済みの`rpi-imager`(2.0.11.1)の
`--cli`は「OS名」ではなく実際のイメージファイル/URLを`src`引数に取ることが判明した。
そのため、Raspberry Pi公式のOSカタログ`os_list_imagingutility_v3.json`を取得して
名前からURL/SHA256を解決する必要があった。

このカタログを調べたところ、現在の既定「Raspberry Pi OS Lite (64-bit)」は
Debian **Trixie**ベースに切り替わっており、`init_format`が`cloudinit-rpi`になっていた
(2026-08-29時点)。一方、`docs/hardware-setup.md`等で前提としてきたホスト名/SSH鍵の
事前設定機構(`custom.toml`をbootパーティションに置くだけで適用される方式)は、
`init_format: systemd`(Debian **Bookworm**ベースの"Legacy"版)で動作することを
複数の一次情報(gistの実例、コミュニティのフォーラム投稿)で確認済みのものであり、
Trixie版の`cloudinit-rpi`が同じcustom.tomlスキーマで動くのか、別のcloud-init
user-data形式が必要になるのかは未検証だった。

## 決定

`flash-sdcard.sh`の既定OSを **"Raspberry Pi OS (Legacy, 64-bit) Lite"**
(`init_format: systemd`)に固定する。スクリプトは解決したOSの`init_format`を確認し、
`systemd`以外であればエラーで停止する(未検証のcloud-init形式に対してcustom.tomlを
書き込んでしまい、サイレントに設定が無視される事態を避けるため)。

## 結果

- 良い点: 検証済みの経路のみを通るため、実機に持っていってから「ホスト名が
  反映されていない」「SSH鍵が効かない」といった不具合に気づくリスクを減らせる
- トレードオフ: 最新のTrixieベースイメージ(セキュリティ更新等)ではなく、
  Legacy(Bookworm)を使い続けることになる。Bookwormも「security updates」付きで
  配布されているため、実用上の懸念は小さいと判断
- 将来、cloudinit-rpi形式のuser-dataスキーマを検証できたら、本ADRを見直し
  最新イメージへ移行する
