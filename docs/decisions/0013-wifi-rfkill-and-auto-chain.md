# 13. Wi-Fiのrfkillブロックを解除し、configure-wifiをflash-sdcardに自動連結する

- ステータス: 承認(実機で確認済み)
- 日付: 2026-08-29

## 状況

[0012](0012-wifi-network-config-schema.md)でnetwork-configの書式を公式実例に
合わせたが、実機(m329)でも依然Wi-Fiに繋がらなかった。原因を実機に直接SSHして
調査したところ、2つの問題が重なっていた:

1. **`configure-wifi.sh`の実行漏れ**: `/boot/firmware/network-config`が、
   Raspberry Piの初期テンプレート(全項目コメントアウト)のまま残っていた。
   `just flash-sdcard`と`just configure-wifi`が別々の手動コマンドだったため、
   片方だけ実行してしまう事故が実際に起きた
2. **Wi-Fi無線自体がrfkillでソフトブロックされていた**:
   `/var/lib/systemd/rfkill/platform-fe300000.mmcnr:wlan: 1`(1=ブロック中)。
   Raspberry Pi OSは国コード未設定の間、規制準拠のためWi-Fi無線を電波的に
   ブロックする仕様と見られる。`sudo raspi-config nonint do_wifi_country JP`を
   実行したところ即座に解除され、周辺APが`nmcli device wifi list`に表示されるように
   なった。network-config側の`regulatory-domain`指定だけでこのブロックが解除される
   かどうかは未検証(今回は1の問題で`network-config`自体が適用されなかったため)

## 決定

1. `scripts/flash-sdcard.sh`の`user-data`生成に`raspi-config nonint do_wifi_country JP`を
   `runcmd`として追加する(実機で確実に動作することを確認済み)。`network-config`側の
   `regulatory-domain`はそのまま残す(併用に害はない)。
2. `scripts/flash-sdcard.sh`は、`.env`に`WIFI_SSID`/`WIFI_PASSWORD`が設定されていれば、
   OS書き込み・`user-data`書き込みに続けて自動的に`scripts/configure-wifi.sh`を
   呼び出す(SDカードをマウントしたまま同一セッション内で行う)。設定が無ければ
   スキップし、その旨を表示する。`configure-wifi.sh`は単体でも
   (既に書き込み済みのカードにWi-Fiだけ後から足したい場合のために)引き続き使える。

## 結果

- 良い点: 「flash-sdcardは実行したがconfigure-wifiを忘れる」という、実際に発生した
  ヒューマンエラーの経路が塞がる
- 良い点: eject→再挿入の往復が一度減り、今回のセッションで何度か踏んだ
  「rpi-imagerの書き込み後にデバイスが消える」系の不安定要素に触れる機会が減る
- 教訓: 「pingは通るがWi-Fiのスキャン結果が空」は、regulatory-domain設定の
  有無だけでなく、**rfkillのソフトブロック自体**を疑うべきである
  (`cat /var/lib/systemd/rfkill/*`で直接確認できる)
