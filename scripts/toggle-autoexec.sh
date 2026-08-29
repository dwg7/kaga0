#!/usr/bin/env bash
# 実機の起動時自動起動(appliance化)をON/OFFする。
#
# ON(true):  ビルド済みバイナリを /opt/kaga/bin/ へコピーし、
#            kaga-httpd.service + kaga-map.service を有効化・起動する。
#            kaga-map.service は Conflicts=getty@tty1.service を持つため、
#            起動と同時にgetty@tty1(コンソールログイン)は自動停止する
#            (systemdのConflicts=は双方向。詳細はsystemd/kaga-map.service参照)。
# OFF(false): 上記2ユニットを停止・無効化し、getty@tty1を復帰させる
#            (通常のSSH開発作業に戻る)。
#
# ビルド成果物の場所は現状 ~/poc/mln-slint-cpp/build/cpp/maplibre-slint-gl
# 固定(docs/decisions/0014参照。ビルド手順が整理されたら変数化する)。
#
# 使い方:
#   ./scripts/toggle-autoexec.sh true
#   ./scripts/toggle-autoexec.sh false
# (KAGA_USER/KAGA_HOSTは.envから。Justfile経由の`just autoexec true/false`推奨)

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

: "${KAGA_HOST:?KAGA_HOST が未設定。.envを用意してください(.env.example参照)}"
: "${KAGA_USER:?KAGA_USER が未設定。.envを用意してください(.env.example参照)}"

MODE="${1:-}"
case "${MODE}" in
    true|false) ;;
    *) echo "使い方: $0 true|false" >&2; exit 1 ;;
esac

TARGET="${KAGA_USER}@${KAGA_HOST}"
BUILD_BIN="/home/${KAGA_USER}/poc/mln-slint-cpp/build/cpp/maplibre-slint-gl"

if [ "${MODE}" = "true" ]; then
    echo "=== ${TARGET}: autoexec ON にする ==="
    echo "--- ビルド成果物を /opt/kaga/bin/ へ配置 ---"
    ssh "${TARGET}" "
        set -e
        if [ ! -f '${BUILD_BIN}' ]; then
            echo 'ビルド成果物が見つかりません: ${BUILD_BIN}' >&2
            echo 'hdmi/scripts/build.sh 相当を先に実行してください' >&2
            exit 1
        fi
        sudo mkdir -p /opt/kaga/bin
        sudo cp '${BUILD_BIN}' /opt/kaga/bin/maplibre-slint-gl
        sudo chmod 755 /opt/kaga/bin/maplibre-slint-gl
    "

    echo "--- systemdユニットを配置(User=${KAGA_USER}を埋め込み) ---"
    sed "s/__KAGA_USER__/${KAGA_USER}/" "${KAGA_ROOT}/systemd/kaga-map.service" \
        | ssh "${TARGET}" "cat | sudo tee /etc/systemd/system/kaga-map.service > /dev/null"
    scp "${KAGA_ROOT}/systemd/kaga-httpd.service" "${TARGET}:/tmp/kaga-httpd.service"
    ssh "${TARGET}" "sudo mv /tmp/kaga-httpd.service /etc/systemd/system/kaga-httpd.service"

    echo "--- 有効化・起動(getty@tty1はConflicts=により自動停止) ---"
    ssh "${TARGET}" "
        sudo systemctl daemon-reload
        sudo systemctl enable --now kaga-httpd.service
        sudo systemctl enable --now kaga-map.service
    "
    echo "✓ autoexec ON。次回電源投入時から地図が自動起動する。"
    echo "  状態確認: ssh ${TARGET} systemctl status kaga-map.service"
else
    echo "=== ${TARGET}: autoexec OFF にする ==="
    ssh "${TARGET}" "
        sudo systemctl disable --now kaga-map.service 2>/dev/null || true
        sudo systemctl disable --now kaga-httpd.service 2>/dev/null || true
        sudo systemctl enable --now getty@tty1.service
    "
    echo "✓ autoexec OFF。コンソール(getty@tty1)が復帰、通常のSSH開発作業に戻れる。"
fi
