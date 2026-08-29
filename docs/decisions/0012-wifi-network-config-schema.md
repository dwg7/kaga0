# 12. network-configのWi-Fi設定を公式の実例どおりの書式に合わせる

- ステータス: 承認
- 日付: 2026-08-29

## 状況

最初の`network-config`は`wifis.wlan0.dhcp4`・`access-points`のみで構成しており、
実機で5分以上起動がハングする不具合が発生した(m329、Wi-Fi接続を試行、有線に
切り替えたところ即座に起動が進んだ)。

Raspberry Pi公式記事([Cloud-init on Raspberry Pi OS](https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/))に載っている実際のWi-Fi設定例は以下の通りで、
こちらには重要な項目が3つ抜けていたことが分かった:

```yaml
network:
  version: 2
  wifis:
    renderer: NetworkManager
    wlan0:
      dhcp4: true
      regulatory-domain: "GB"
      access-points:
        "My Net-Work":
          password: "mysupersecretpassword"
      optional: true
```

- `renderer: NetworkManager` — 明示していなかった
- `regulatory-domain` — 未設定(国コード無しではWi-Fiのスキャン/接続自体が
  制限されうる)。[0011](0011-ssh-not-enabled-by-default.md)では応急処置として
  `raspi-config nonint do_wifi_country`をruncmdで叩いていたが、こちらの
  宣言的な項目の方が公式かつ確実
- **`optional: true`** — これが無いと、起動時のネットワーク待ち処理が
  wlan0の接続確立を待ち続け、Wi-Fi接続に失敗(または時間がかかる)場合に
  起動全体がブロックされる。5分ハングの本命の原因と考えられる

## 決定

`scripts/configure-wifi.sh`の`network-config`生成を上記の公式書式に合わせる。
`regulatory-domain`は`"JP"`固定(kagaは日本国内での運用が前提)。
`scripts/flash-sdcard.sh`側の`raspi-config nonint do_wifi_country`(0011で
暫定的に追加したもの)は削除する — 同じ設定をより確実な方法で`network-config`
側にまとめたため。

## 結果

- 良い点: 公式のドキュメント実例に準拠しているため、スキーマの解釈違いによる
  不具合の可能性を大きく減らせる
- `optional: true`により、Wi-Fi接続に失敗しても有線(または起動そのもの)を
  ブロックしなくなるはず — これは次回の実機起動で確認する
