#!/usr/bin/env bash
# kaga実機(Raspberry Pi)の状態診断。実機上で直接実行するか、
# ./scripts/diagnose.sh --ssh <user>@kaga0.local でSSH経由実行する。
#
# 出力をそのままClaude Codeに貼り付ければ、原因特定の材料になる。

set -uo pipefail

run_local() {
    echo "=== hostname / uptime ==="
    hostname; uptime
    echo

    echo "=== kaga.service 状態 ==="
    systemctl status kaga.service --no-pager -l 2>&1 || echo "(kaga.service は未インストール)"
    echo

    echo "=== kaga.service 直近ログ(journalctl, 直近200行) ==="
    journalctl -u kaga.service -n 200 --no-pager 2>&1 || echo "(ログなし)"
    echo

    echo "=== DRM/KMS デバイス ==="
    ls -l /dev/dri/ 2>&1 || echo "(/dev/dri なし)"
    for card in /dev/dri/card*; do
        [ -e "$card" ] || continue
        echo "--- $card ---"
        cat "/sys/class/drm/$(basename "$card")/device/uevent" 2>&1 || true
    done
    echo

    echo "=== connector 状態(HDMI検出) ==="
    for status in /sys/class/drm/card*-HDMI*/status; do
        [ -e "$status" ] || continue
        echo "$status: $(cat "$status")"
    done
    echo

    echo "=== 現在のユーザーが属するグループ(video/render/input) ==="
    id
    echo

    echo "=== ネットワーク ==="
    ip -brief addr 2>&1 || ifconfig 2>&1
    echo
    systemctl status avahi-daemon --no-pager -l 2>&1 | head -10 || true
    echo

    echo "=== ディスク空き容量 ==="
    df -h / /boot/firmware 2>&1
    echo

    echo "=== メモリ / 温度 ==="
    free -h
    vcgencmd measure_temp 2>&1 || echo "(vcgencmdなし)"
    vcgencmd get_throttled 2>&1 || true
    echo

    echo "=== OSバージョン ==="
    cat /etc/os-release 2>&1 | head -5
    uname -a
}

if [ "${1:-}" = "--ssh" ]; then
    KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    [ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"
    target="${2:-}"
    if [ -z "${target}" ] && [ -n "${KAGA_USER:-}" ] && [ -n "${KAGA_HOST:-}" ]; then
        target="${KAGA_USER}@${KAGA_HOST}"
    fi
    : "${target:?使い方: diagnose.sh --ssh <user>@host (または.envにKAGA_USER/KAGA_HOSTを設定)}"
    ssh "${target}" "$(declare -f run_local); run_local"
else
    run_local
fi
