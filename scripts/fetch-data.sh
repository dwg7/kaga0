#!/usr/bin/env bash
# VBM/VLCM PMTilesを depot.optgeo.org から取得する。
#
# depot.optgeo.orgは、kitavolcaがstars.optgeo.orgへアップロードしたPMTilesの実体を
# 直接HTTP GETできる窓口として用意されたサーバー(Range対応の静的配信)。
# stars.optgeo.org自体はz/x/yのライブタイル配信のみでファイル単位のダウンロードは
# 提供していないため、オフライン用途ではdepot側から取得する
# (docs/decisions/0005-depot-optgeo-org.md 参照)。
#
# 使い方:
#   ./scripts/fetch-data.sh              # 手元(このホスト)の data/ に取得
#   ./scripts/fetch-data.sh --remote     # $KAGA_USER@$KAGA_HOST に直接SSHし、
#                                          # 実機上でdepotから取得(中継なし)
#
# 環境変数(.env参照。.env.exampleをコピーして使う):
#   PMTILES_BASE_URL   既定: https://depot.optgeo.org
#   KAGA_HOST, KAGA_USER  --remote 使用時のSSH先

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

PMTILES_BASE_URL="${PMTILES_BASE_URL:-https://depot.optgeo.org}"
FILES="vbm.pmtiles vlcm.pmtiles"

# dest_dir=$1 base_url=$2 files=$3(空白区切り) をfetchするシェル片。
# ローカル実行時はそのまま関数として呼び、リモート実行時はssh越しにそのまま流し込む。
fetch_script() {
    cat <<'SCRIPT'
set -euo pipefail
dest_dir="$1"; base_url="$2"; shift 2
mkdir -p "$dest_dir"
for file in "$@"; do
    echo "--- ${file} ---"
    if command -v aria2c >/dev/null 2>&1; then
        aria2c -x4 -s4 --dir="$dest_dir" --out="$file" \
            --allow-overwrite=true --continue=true "${base_url}/${file}"
    else
        curl --fail --location --continue-at - --output "${dest_dir}/${file}" "${base_url}/${file}"
    fi
done
echo "✓ 完了"
du -h "$dest_dir"/*.pmtiles
SCRIPT
}

if [ "${1:-}" = "--remote" ]; then
    : "${KAGA_HOST:?KAGA_HOST が未設定。.envを用意してください(.env.example参照)}"
    : "${KAGA_USER:?KAGA_USER が未設定。.envを用意してください(.env.example参照)}"
    echo "=== ${KAGA_USER}@${KAGA_HOST} 上で直接取得 ==="
    ssh "${KAGA_USER}@${KAGA_HOST}" 'sudo mkdir -p /opt/kaga/data && sudo chown -R "$(whoami)" /opt/kaga'
    # shellcheck disable=SC2086
    fetch_script | ssh "${KAGA_USER}@${KAGA_HOST}" bash -s -- /opt/kaga/data "${PMTILES_BASE_URL}" ${FILES}
else
    # shellcheck disable=SC2086
    fetch_script | bash -s -- "${KAGA_ROOT}/data" "${PMTILES_BASE_URL}" ${FILES}
fi
