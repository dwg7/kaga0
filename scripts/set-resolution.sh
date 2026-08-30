#!/usr/bin/env bash
# 実機のHDMI出力解像度を切り替える。
#
# kagaのSlint linuxkmsバックエンドは、接続されたディスプレイのEDIDが
# 申告する「PREFERRED」モードを起動時に自動選択する
# (slint/internal/backends/linuxkms/drmoutput.rs)。/boot/firmware/cmdline.txt
# の`video=HDMI-A-1:<解像度>@60`は、そのPREFERRED判定を上書きする仕組み
# (Linuxカーネルのcmdlineモード機構)——このスクリプトはその一行を
# 付け外しするだけで、DRM/KMSのモード決定自体は起動時の一度きりのため、
# 反映には再起動が必要(docs/decisions/0014、docs/plan.md参照)。
#
# auto: video=行を削除し、EDID自動認識に戻す(初見の会場向け・推奨デフォルト)。
#       多くのプロジェクタ・ディスプレイは1080pネイティブで、これは実測でも
#       快適な帯域(29-33fps)に当たることが多い。4Kネイティブ機に繋がった
#       場合は自動的に激重(4-5fps)になるトレードオフあり。
# 1080p/1440p/4k: 既知のディスプレイ向けに固定(開発機JAPANNEXTでの実測:
#       1080p 29-33fps、1440p 11-12fps、4K 4-5fps。docs/plan.md参照)。
#
# 使い方:
#   ./scripts/set-resolution.sh auto|1080p|1440p|4k [--reboot]
# (KAGA_USER/KAGA_HOSTは.envから。Justfile経由の`just set-resolution <mode>`推奨)
# --reboot を付けない場合は編集のみ行い、反映には手動で `just ssh` 後
# `sudo reboot`(または次回電源投入)が必要。

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

: "${KAGA_HOST:?KAGA_HOST が未設定。.envを用意してください(.env.example参照)}"
: "${KAGA_USER:?KAGA_USER が未設定。.envを用意してください(.env.example参照)}"

MODE="${1:-}"
REBOOT="${2:-}"

case "${MODE}" in
    auto) VIDEO_TOKEN="" ;;
    1080p) VIDEO_TOKEN="video=HDMI-A-1:1920x1080@60" ;;
    1440p) VIDEO_TOKEN="video=HDMI-A-1:2560x1440@60" ;;
    4k) VIDEO_TOKEN="video=HDMI-A-1:3840x2160@60" ;;
    *)
        echo "使い方: $0 auto|1080p|1440p|4k [--reboot]" >&2
        exit 1
        ;;
esac

if [ -n "${REBOOT}" ] && [ "${REBOOT}" != "--reboot" ]; then
    echo "使い方: $0 auto|1080p|1440p|4k [--reboot]" >&2
    exit 1
fi

TARGET="${KAGA_USER}@${KAGA_HOST}"
CMDLINE=/boot/firmware/cmdline.txt

echo "=== ${TARGET}: 解像度を ${MODE} に設定 ==="
ssh "${TARGET}" "
    set -e
    sudo cp ${CMDLINE} ${CMDLINE}.bak
    # 既存のvideo=HDMI-A-1:...トークンを除去してから、必要なら付け直す
    # (トークンは空白区切りの1行なのでsedの単語置換で十分)。
    NEW=\$(sed -E 's/[[:space:]]*video=HDMI-A-1:[^ ]*//' ${CMDLINE}.bak)
    if [ -n '${VIDEO_TOKEN}' ]; then
        NEW=\"\${NEW} ${VIDEO_TOKEN}\"
    fi
    echo \"\${NEW}\" | sudo tee ${CMDLINE} > /dev/null
    echo '--- 変更後 ---'
    cat ${CMDLINE}
"
echo "✓ ${CMDLINE} を更新(バックアップ: ${CMDLINE}.bak)。DRM/KMSのモード決定は起動時のみのため反映には再起動が必要。"

if [ "${REBOOT}" = "--reboot" ]; then
    echo "--- 再起動します ---"
    ssh "${TARGET}" "sudo reboot" || true
else
    echo "反映するには: ssh ${TARGET} sudo reboot"
fi
