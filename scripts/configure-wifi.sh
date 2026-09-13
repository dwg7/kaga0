#!/usr/bin/env bash
# 既にOSイメージ・user-dataを書き込み済みのSDカードへ、Wi-Fi設定
# (cloud-init network-config)だけを追加で書き込む。
#
# 有線接続を主、Wi-Fiは保険として使う方針(CLAUDE.md参照)だが、設定しておく。
# network-configの書式はRaspberry Pi公式記事の実例に準拠:
# https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/
# (renderer: NetworkManager / regulatory-domain / optional: true が要点。
# optional: trueが無いと、Wi-Fi接続待ちで起動がブロックされる — 実機で確認済み)
# **`ethernets: eth0:` を明示的に書いておく**こと。netplanは「書かれていない
# 設定は無効」という仕組みのため、`wifis:`だけのnetwork-configを書くと、
# 有線LANの物理リンクは確立するのにDHCPでIPを取りに行く設定自体が存在せず、
# 有線接続(方針上の主系統)が機能しなくなる——「保険のWi-Fiを足しただけの
# つもりが主系統を壊す」という本末転倒な結果になる。rpi-geoserver0
# プロジェクト(同じRPi4Bを共用、Ubuntu Server)がこのコードを流用した際に
# 実機で踏んで発覚(2026-09-13、cross-session共有)。kaga0では実機での
# 再現確認はできていないが(m329は現在rpi-geoserver0側のSDカードで稼働中)、
# 安全側に倒して先に修正済み。
# SSIDは電波として周囲に公開されている情報なので対話プロンプトでも問題ないが、
# パスワードはこのスクリプトの実行者(藤村さん)の端末で直接入力してもらうか、
# .env(git管理外)にWIFI_SSID/WIFI_PASSWORDとして書いてもらう。
# いずれの場合もClaude Codeの会話には一切含めない(.env.example参照)。
#
# 使い方:
#   diskutil list                          # SDカードのデバイス名を確認
#   ./scripts/configure-wifi.sh /dev/diskN

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

DEVICE="${1:?使い方: configure-wifi.sh /dev/diskN (事前に 'diskutil list' で確認)}"

diskutil mountDisk "${DEVICE}" >/dev/null 2>&1 || true
BOOT_MOUNT="/Volumes/bootfs"
for _ in 1 2 3 4 5; do
    [ -d "${BOOT_MOUNT}" ] && break
    sleep 1
done
if [ ! -d "${BOOT_MOUNT}" ]; then
    echo "❌ ${BOOT_MOUNT} が見つかりません。'diskutil list' でデバイス名を確認してください" >&2
    exit 1
fi

if [ -n "${WIFI_SSID:-}" ]; then
    echo "Wi-Fi SSID: ${WIFI_SSID} (.envから読み込み)"
else
    read -r -p "Wi-Fi SSID: " WIFI_SSID
fi
if [ -n "${WIFI_PASSWORD:-}" ]; then
    echo "Wi-Fi パスワード: .envから読み込み"
else
    read -r -s -p "Wi-Fi パスワード: " WIFI_PASSWORD
    echo
fi

WIFI_SSID="${WIFI_SSID}" WIFI_PASSWORD="${WIFI_PASSWORD}" \
    python3 - "${BOOT_MOUNT}/network-config" <<'PYEOF'
import json, os, sys

ssid = os.environ["WIFI_SSID"]
password = os.environ["WIFI_PASSWORD"]
out_path = sys.argv[1]

doc = f"""network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
  wifis:
    renderer: NetworkManager
    wlan0:
      dhcp4: true
      regulatory-domain: "JP"
      access-points:
        {json.dumps(ssid)}:
          password: {json.dumps(password)}
      optional: true
"""
with open(out_path, "w") as f:
    f.write(doc)
PYEOF

echo "✓ network-config を書き込みました"
sync
diskutil eject "${DEVICE}" >/dev/null 2>&1 || true
echo "✓ SDカードを取り出しました。m329へ挿してください"
