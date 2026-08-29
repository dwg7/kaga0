#!/usr/bin/env bash
# SDカードへ Raspberry Pi OS を書き込み、hostname・SSH公開鍵authを事前設定する。
#
# rpi-imager --cli の src引数は「OS名」ではなく実際のイメージファイル/URLである
# (2026-08-29、実機にインストール済みのrpi-imager 2.0.11.1の`--cli`ヘルプで確認)。
# そのためRaspberry Pi公式のカタログJSON(os_list_imagingutility_v3.json)を都度取得し、
# OS_IMAGE名からダウンロードURL・SHA256・init_formatを解決してから rpi-imager に渡す。
#
# OSは既定で **Raspberry Pi OS Lite (64-bit)**(Trixie, init_format=cloudinit-rpi)を使う。
# 一度はLegacy(Bookworm, custom.toml方式)を選んだが、以下の理由でTrixieに戻した:
#   - maplibre-native-slintのRaspberry Pi/LinuxKMS対応(PR #66, rust/RASPBERRY_PI.md)が
#     まさに「Raspberry Pi 4, Debian 13 (trixie)」を表示ホストとして実機検証済み
#   - cloud-initのuser-data形式は業界標準で、RPi固有のcustom.tomlより仕様を確信を
#     持って扱える(公式記事: https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/)
# 詳細は docs/decisions/0009-trixie-and-cloudinit.md 参照(0008を置き換え)。
#
# init_formatに応じてカスタマイズ方式を切り替える:
#   - cloudinit-rpi(Trixie系): boot パーティションに `user-data`(cloud-init YAML)を書く
#   - systemd(Bookworm/Legacy系): boot パーティションに `custom.toml` を書く
# (OS_IMAGE環境変数でLegacyに切り替えた場合もそのまま動くようにしてある)
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
OS_IMAGE="${OS_IMAGE:-Raspberry Pi OS Lite (64-bit)}"
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

echo "   → ${OS_URL} (init_format=${OS_INIT_FORMAT})"
case "${OS_INIT_FORMAT}" in
    cloudinit-rpi|systemd) ;;
    *)
        echo "❌ '${OS_IMAGE}' の init_format '${OS_INIT_FORMAT}' はこのスクリプトが対応していない形式です" >&2
        exit 1
        ;;
esac

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

# rpi-imagerが書き込み後にbootパーティションを自動マウントしないことがある
# (macOS 26実機で確認: diskutil mountDiskを叩かない限りマウントされなかった)。
BOOT_MOUNT="/Volumes/bootfs"
diskutil mountDisk "${DEVICE}" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do
    [ -d "${BOOT_MOUNT}" ] && break
    sleep 1
done
if [ ! -d "${BOOT_MOUNT}" ]; then
    echo "❌ ${BOOT_MOUNT} が見つかりません。" >&2
    echo "   'diskutil mountDisk ${DEVICE}' を試すか、SDカードを一度抜き差ししてから再実行してください" >&2
    exit 1
fi

PUBKEY_CONTENT="$(cat "${PUBKEY_FILE}")"

if [ "${OS_INIT_FORMAT}" = "cloudinit-rpi" ]; then
    echo "=== cloud-init user-data を boot パーティションへ書き込み ==="
    # meta-dataはRaspberry Pi OSイメージ側に既定で同梱されており、そのままで良い
    # (公式記事: 上書き不要と明記)。ここではuser-dataのみ書く。
    # 値はjson.dumps()でエスケープしてYAMLに埋め込む(パスワードに"や\が含まれても
    # 壊れないように。bashのヒアドキュメントでの単純な文字列展開はここでは使わない)。
    HOSTNAME="${HOSTNAME}" RPI_USER="${RPI_USER}" RPI_PASSWORD="${RPI_PASSWORD}" PUBKEY_CONTENT="${PUBKEY_CONTENT}" \
        python3 - "${BOOT_MOUNT}/user-data" <<'PYEOF'
import json, os, sys

hostname = os.environ["HOSTNAME"]
user = os.environ["RPI_USER"]
password = os.environ["RPI_PASSWORD"]
pubkey = os.environ["PUBKEY_CONTENT"].strip()
out_path = sys.argv[1]

doc = f"""#cloud-config
hostname: {json.dumps(hostname)}
manage_etc_hosts: true

timezone: Asia/Tokyo
keyboard:
  model: pc105
  layout: jp

package_update: false
package_upgrade: false

ssh_pwauth: false

users:
  - name: {json.dumps(user)}
    groups: [adm, dialout, sudo, audio, video, plugdev, input, netdev, gpio, i2c, spi, render]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: {json.dumps(password)}
    ssh_authorized_keys:
      - {json.dumps(pubkey)}
"""
with open(out_path, "w") as f:
    f.write(doc)
PYEOF
else
    echo "=== custom.toml を boot パーティションへ書き込み(Legacy/Bookworm) ==="
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
fi

sync
diskutil eject "${DEVICE}" >/dev/null 2>&1 || true

echo "✓ 完了。SDカードを取り出してRPiに挿入し、電源投入後:"
echo "   ssh ${RPI_USER}@${HOSTNAME}.local"
