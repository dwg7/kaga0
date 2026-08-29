#!/usr/bin/env bash
# SDカードへ Raspberry Pi OS Lite (64-bit) を書き込み、hostname・SSH公開鍵authを
# 事前設定する。rpi-imager --cli はOSイメージの書き込みのみを行い、hostname/SSH/Wi-Fi
# のカスタマイズはCLIフラグとして提供されていない(2026-08-29時点で確認)ため、
# Raspberry Pi OS Bookworm系が起動時に読む custom.toml を boot パーティションへ
# 別途書き込む方式を取る。
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

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

DEVICE="${1:?使い方: flash-sdcard.sh /dev/diskN (事前に 'diskutil list' で確認)}"
HOSTNAME="${KAGA_HOST%%.local}"
OS_IMAGE="${OS_IMAGE:-Raspberry Pi OS Lite (64-bit)}"
PUBKEY_FILE="${SSH_PUBKEY_FILE:-${HOME}/.ssh/id_ed25519.pub}"
PUBKEY_FILE="${PUBKEY_FILE/#\~/${HOME}}"

: "${HOSTNAME:?KAGA_HOST が未設定。.envを用意してください(.env.example参照)}"

if ! command -v rpi-imager >/dev/null 2>&1; then
    echo "❌ rpi-imager が見つかりません: brew install --cask raspberry-pi-imager" >&2
    exit 1
fi

if [ ! -f "${PUBKEY_FILE}" ]; then
    echo "❌ SSH公開鍵が見つかりません: ${PUBKEY_FILE}" >&2
    echo "   PUBKEY_FILE=... で別のパスを指定するか、ssh-keygen で生成してください" >&2
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
rpi-imager --cli "${OS_IMAGE}" "${DEVICE}"

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
