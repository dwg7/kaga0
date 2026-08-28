#!/usr/bin/env bash
# SDカードへ Raspberry Pi OS Lite (64-bit) を書き込み、hostname=kaga0・SSH公開鍵authを
# 事前設定する。rpi-imager --cli はOSイメージの書き込みのみを行い、hostname/SSH/Wi-Fi
# のカスタマイズはCLIフラグとして提供されていない(2026-08-29時点で確認)ため、
# Raspberry Pi OS Bookworm系が起動時に読む custom.toml を boot パーティションへ
# 別途書き込む方式を取る。
#
# ⚠ 本スクリプトは指定したデバイスを破壊的に上書きする。実行前に対象デバイスを
#   必ず自分の目で確認すること(誤ってメインディスクを指定すると全データを失う)。
#
# 使い方:
#   diskutil list                          # まず対象SDカードのデバイス名を確認
#   ./scripts/flash-sdcard.sh /dev/diskN   # 確認プロンプトへ手動でyesと入力
#
# 前提: rpi-imager がインストール済み(brew install --cask raspberry-pi-imager)。
#       ~/.ssh/id_ed25519.pub (または id_rsa.pub) が存在すること。

set -euo pipefail

DEVICE="${1:?使い方: flash-sdcard.sh /dev/diskN (事前に 'diskutil list' で確認)}"
HOSTNAME="kaga0"
OS_IMAGE="${OS_IMAGE:-Raspberry Pi OS Lite (64-bit)}"
PUBKEY_FILE="${PUBKEY_FILE:-${HOME}/.ssh/id_ed25519.pub}"

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

read -r -p "RPi用ユーザー名: " RPI_USER
read -r -s -p "RPi用パスワード: " RPI_PASSWORD
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
