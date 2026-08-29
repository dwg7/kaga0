# m329 実機スペック(2026-08-29確認)

`ssh hfu@m329.local`で実機から直接取得した値。再現コマンドも併記。

## 本体

| 項目 | 値 |
|---|---|
| モデル | Raspberry Pi 4 Model B Rev 1.2 |
| Revisionコード | `c03112`(= Pi4B **4GB** Rev1.2。藤村さんの認識通りRAMは4GB) |
| CPU | Cortex-A72 × 4コア、aarch64、600–1500MHz |
| RAM実効値 | 3886900 kB(≈3.7GiB。GPU等への予約分を除いた実効値。物理搭載量は4GB) |
| Swap | zram(圧縮RAM上のswap、2GiB)。ディスクswapファイルではない点に注意 —
  ビルド時のメモリ逼迫でzram圧縮のCPUオーバーヘッドが乗る可能性がある |
| シリアル | `100000000d93aef3` |
| 温度(確認時) | 73.5℃(`vcgencmd measure_temp`。アイドル〜軽負荷時) |
| スロットリング | `throttled=0x0`(未発生。電源・温度とも問題なし) |

確認コマンド:
```bash
cat /proc/device-tree/model
grep -E "Revision|Serial" /proc/cpuinfo
grep MemTotal /proc/meminfo
vcgencmd get_throttled
vcgencmd measure_temp
```

**注意点(Rev1.2について)**: Raspberry Pi 4のRev1.1/1.2ボードはUSB-C電源周りの
既知の設計ミス(e-marked/PDネゴシエーション対応の高機能USB-Cケーブルだと
給電されないことがある)が報告されている世代。単純な(chipなしの)USB-C
ケーブル・電源であれば問題ない。電源が不安定に見える場合はまずケーブルを疑う。

## OS

| 項目 | 値 |
|---|---|
| ディストリビューション | Debian GNU/Linux 13 (trixie) |
| カーネル(2026-08-29時点、apt upgrade直後) | インストール済み `6.18.39+rpt-rpi-v8`、**稼働中はまだ`6.18.34`**(再起動待ち) |

## microSDカード(mmcblk0)

| 項目 | 値 |
|---|---|
| 製品名(CIDのname) | `SA32G`(SanDisk系32GB品と推測されるコード。断定はできない) |
| manfid / oemid | `0x000002` / `0x544d` |
| 製造年月(CID date) | 2019年6月 |
| バス速度モード | UHS-I speed **DDR50** |
| 生容量 | 30,979,129,344 bytes(≈28.85 GiB、"32GB"表記品としては一般的な実効値) |
| パーティション構成 | `mmcblk0p1` 512MiB vfat(`/boot/firmware`) / `mmcblk0p2` 28.3GiB ext4(`/`) |
| ディスク空き(2026-08-29時点) | 約20GB |

確認コマンド:
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
for f in manfid oemid name serial date hwrev fwrev; do
  echo -n "$f: "; cat /sys/block/mmcblk0/device/$f
done
dmesg | grep -i mmc0
sudo blockdev --getsize64 /dev/mmcblk0
```

**留意点**: DDR50は決して最速のUHSモード(UHS-Iの上にはSDR104やUHS-II等がある)
ではない。サブモジュールcloneやビルドの遅さの一因がディスクI/O律速なのか
ネットワーク律速なのかを切り分ける際、この点を思い出すこと(2026-08-29時点の
初回cloneは実測ではWi-Fi帯域が支配的だった)。

## 関連ドキュメント

- ハードウェア一般のセットアップ手順: [docs/hardware-setup.md](hardware-setup.md)
- ホスト名・ユーザー名の命名規約: [docs/decisions/0006-hostname-naming.md](decisions/0006-hostname-naming.md)
- Stage 3ビルド作業ログ(このスペックを踏まえたOOM対策等): [docs/stage3-build-log.md](stage3-build-log.md)
