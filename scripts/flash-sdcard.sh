#!/usr/bin/env bash
# SDカードへ Raspberry Pi OS を書き込み、hostname・SSH公開鍵authを事前設定する。
#
# rpi-imager --cli の src引数は「OS名」ではなく実際のイメージファイル/URLである
# (2026-08-29、実機にインストール済みのrpi-imager 2.0.11.1の`--cli`ヘルプで確認)。
# そのためRaspberry Pi公式のカタログJSON(os_list_imagingutility_v3.json)を都度取得し、
# OS_IMAGE名からダウンロードURLとSHA256を解決してから rpi-imager に渡す。
#
# OSは既定で **Raspberry Pi OS (Legacy, 64-bit) Lite**(Bookworm, init_format=systemd)
# を使う。最新の「Raspberry Pi OS Lite (64-bit)」はTrixieベースでinit_format=
# cloudinit-rpiに切り替わっており、custom.tomlではなくcloud-init user-data形式の
# カスタマイズが必要になった可能性がある(2026-08-29時点、公式カタログJSONで確認。
# この新形式の正確なスキーマは未検証)。実績のあるcustom.toml方式(下記)を確実に
# 使うため、あえてLegacy(Bookworm)を選んでいる。詳細は
# docs/decisions/0008-legacy-bookworm-image.md 参照。
#
# custom.toml は Raspberry Pi OS Bookworm系(init_format=systemd)が起動時に読む
# 標準のカスタマイズ機構で、hostname/user/ssh/localeをboot パーティションへ
# 直接書き込むだけで適用される。
#
# ホスト名の付け方は docs/decisions/0006-hostname-naming.md 参照
# (実機固有の識別名は .env に書く。.gitに残したくない情報のため — 0007参照)。
#
# ⚠ 本スクリプトは指定したデバイスを破壊的に上書きする。実行前に対象デバイスを
#   必ず自分の目で確認すること(誤ってメインディスクを指定すると全データを失う)。
#
# 使い方:
#   cp .env.example .env && $EDITOR .env   # KAGA_HOST / SSH_PUBKEY_FILE を実値に
#   diskutil list                          # 対象SDカードのデバイス名を確認
#   ./scripts/flash-sdcard.sh /dev/diskN   # 確認プロンプトへ手動でyesと入力
#
# 前提: rpi-imager がインストール済み(brew install --cask raspberry-pi-imager)。
#       CLIバイナリは.appバンドル内にあるだけでPATHに無いことがある。その場合:
#       ln -sf "/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager" /opt/homebrew/bin/rpi-imager

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

DEVICE="${1:?使い方: flash-sdcard.sh /dev/diskN (事前に 'diskutil list' で確認)}"
HOSTNAME="${KAGA_HOST%%.local}"
OS_IMAGE="${OS_IMAGE:-Raspberry Pi OS (Legacy, 64-bit) Lite}"
PUBKEY_FILE="${SSH_PUBKEY_FILE:-${HOME}/.ssh/id_ed25519.pub}"
PUBKEY_FILE="${PUBKEY_FILE/#\~/${HOME}}"

: "${HOSTNAME:?KAGA_HOST が未設定。.envを用意してください(.env.example参照)}"

if ! command -v rpi-imager >/dev/null 2>&1; then
    echo "❌ rpi-imager が見つかりません: brew install --cask raspberry-pi-imager" >&2
    echo "   (CLIが見つからない場合は上記コメントのln -sfコマンド参照)" >&2
    exit 1
fi

if [ ! -f "${PUBKEY_FILE}" ]; then
    echo "❌ SSH公開鍵が見つかりません: ${PUBKEY_FILE}" >&2
    echo "   PUBKEY_FILE=... で別のパスを指定するか、ssh-keygen で生成してください" >&2
    exit 1
fi

echo "=== OSカタログから '${OS_IMAGE}' を解決中 ==="
OS_CATALOG_URL="https://downloads.raspberrypi.org/os_list_imagingutility_v3.json"
read -r OS_URL OS_SHA256 OS_INIT_FORMAT <<<"$(
    curl -fsSL "${OS_CATALOG_URL}" | python3 -c '
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
def walk(items):
    for it in items:
        if it.get("name") == name:
            print(it["url"], it["extract_sha256"], it.get("init_format", "?"))
            return True
        if "subitems" in it and walk(it["subitems"]):
            return True
    return False
if not walk(data["os_list"]):
    sys.exit(1)
' "${OS_IMAGE}"
)" || { echo "❌ OSカタログに '${OS_IMAGE}' が見つかりません" >&2; exit 1; }

echo "   → ${OS_URL}"
if [ "${OS_INIT_FORMAT}" != "systemd" ]; then
    echo "❌ '${OS_IMAGE}' の init_format は '${OS_INIT_FORMAT}' で、想定するcustom.toml方式(systemd)と異なります。" >&2
    echo "   docs/decisions/0008-legacy-bookworm-image.md を参照し、OS_IMAGEを見直してください" >&2
    exit 1
fi

echo "=== 対象デバイス確認 ==="
diskutil list "${DEVICE}"
echo
read -r -p "⚠ ${DEVICE} の内容は完全に消去されます。本当に書き込みますか? (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
    echo "中止しました"
    exit 1
fi

read -r -p "RPi用ユーザー名 [${KAGA_USER:-}]: " RPI_USER
RPI_USER="${RPI_USER:-${KAGA_USER:?ユーザー名が未入力かつKAGA_USER未設定です}}"
read -r -s -p "RPi用パスワード(公開鍵authが有効なため通常使わないが、コンソールログイン用に必要): " RPI_PASSWORD
echo

echo "=== OSイメージ書き込み: ${OS_IMAGE} → ${DEVICE} ==="
rpi-imager --cli "${OS_URL}" "${DEVICE}" --sha256 "${OS_SHA256}"

echo "=== custom.toml を boot パーティションへ書き込み ==="
BOOT_MOUNT="/Volumes/bootfs"
if [ ! -d "${BOOT_MOUNT}" ]; then
    echo "❌ ${BOOT_MOUNT} が見つかりません。書き込み直後に自動マウントされるまで少し待ってから再実行してください" >&2
    exit 1
fi

PUBKEY_CONTENT="$(cat "${PUBKEY_FILE}")"

cat > "${BOOT_MOUNT}/custom.toml" <<EOF
config_version = 1

[system]
hostname = "${HOSTNAME}"

[user]
name = "${RPI_USER}"
password = "${RPI_PASSWORD}"
password_encrypted = false

[ssh]
enabled = true
password_authentication = false
authorized_keys = [ "${PUBKEY_CONTENT}" ]

[locale]
keymap = "jp"
timezone = "Asia/Tokyo"
EOF

sync
diskutil eject "${DEVICE}" >/dev/null 2>&1 || true

echo "✓ 完了。SDカードを取り出してRPiに挿入し、電源投入後:"
echo "   ssh ${RPI_USER}@${HOSTNAME}.local"
