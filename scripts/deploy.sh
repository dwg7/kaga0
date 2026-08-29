#!/usr/bin/env bash
# ビルド済みkagaバイナリを実機へ転送し、systemdサービスを有効化する。
#
# データ(PMTiles)は本スクリプトでは転送しない。実機自身がdepot.optgeo.orgから
# 直接取得する(`just fetch-data-remote` / `scripts/fetch-data.sh --remote`)。
# 理由は docs/decisions/0005-depot-optgeo-org.md 参照。
#
# 前提: src/ 以下にビルド成果物が存在すること(現時点ではまだクロスコンパイル
# パイプライン未整備 — TODO: aarch64向けビルド手順が固まり次第ここから呼び出す)。
# 現段階では `target/aarch64-unknown-linux-gnu/release/kaga` のような
# 単一バイナリを想定したプレースホルダー。
#
# 使い方:
#   ./scripts/deploy.sh <user>@<host>
# (KAGA_USER/KAGA_HOSTが.envにあれば引数省略可。Justfile経由の`just deploy`推奨)

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "${KAGA_ROOT}/.env" ] && source "${KAGA_ROOT}/.env"

TARGET="${1:-}"
if [ -z "${TARGET}" ] && [ -n "${KAGA_USER:-}" ] && [ -n "${KAGA_HOST:-}" ]; then
    TARGET="${KAGA_USER}@${KAGA_HOST}"
fi
: "${TARGET:?使い方: deploy.sh <user>@<host> (または.envにKAGA_USER/KAGA_HOSTを設定)}"

BIN="${KAGA_ROOT}/target/aarch64-unknown-linux-gnu/release/kaga"

if [ ! -f "${BIN}" ]; then
    echo "❌ ビルド成果物が見つかりません: ${BIN}" >&2
    echo "   (ビルド手順はまだ整備中。docs/decisions/ 参照)" >&2
    exit 1
fi

echo "=== バイナリを ${TARGET} へ転送 ==="
ssh "${TARGET}" "sudo mkdir -p /opt/kaga && sudo chown \$(whoami) /opt/kaga"
rsync --progress "${BIN}" "${TARGET}:/opt/kaga/kaga"

echo "=== systemdユニットを転送・有効化 ==="
scp "${KAGA_ROOT}/systemd/kaga.service" "${TARGET}:/tmp/kaga.service"
ssh "${TARGET}" "sudo mv /tmp/kaga.service /etc/systemd/system/kaga.service && \
    sudo systemctl daemon-reload && \
    sudo systemctl enable --now kaga.service"

echo "✓ デプロイ完了。状態確認: ssh ${TARGET} systemctl status kaga.service"
