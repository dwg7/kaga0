#!/usr/bin/env bash
# ビルド済みkagaバイナリとデータをRPi実機へデプロイし、サービスを再起動する。
#
# 前提: src/ 以下にビルド成果物が存在すること(現時点ではまだクロスコンパイル
# パイプライン未整備 — TODO: aarch64向けビルド手順が固まり次第ここから呼び出す)。
# 現段階では `target/aarch64-unknown-linux-gnu/release/kaga` のような
# 単一バイナリを想定したプレースホルダー。
#
# 使い方:
#   ./scripts/deploy.sh <user>@kaga0.local

set -euo pipefail

TARGET="${1:?使い方: deploy.sh <user>@kaga0.local}"
KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${KAGA_ROOT}/target/aarch64-unknown-linux-gnu/release/kaga"

if [ ! -f "${BIN}" ]; then
    echo "❌ ビルド成果物が見つかりません: ${BIN}" >&2
    echo "   (ビルド手順はまだ整備中。docs/decisions/ 参照)" >&2
    exit 1
fi

echo "=== バイナリを ${TARGET} へ転送 ==="
ssh "${TARGET}" "sudo mkdir -p /opt/kaga && sudo chown \$(whoami) /opt/kaga"
rsync --progress "${BIN}" "${TARGET}:/opt/kaga/kaga"

echo "=== データ(PMTiles)を転送 ==="
rsync --progress "${KAGA_ROOT}"/data/*.pmtiles "${TARGET}:/opt/kaga/data/" 2>&1 \
    || echo "⚠ data/*.pmtiles が見つかりません。先に scripts/fetch-data.sh を実行してください"

echo "=== systemdユニットを転送・有効化 ==="
scp "${KAGA_ROOT}/systemd/kaga.service" "${TARGET}:/tmp/kaga.service"
ssh "${TARGET}" "sudo mv /tmp/kaga.service /etc/systemd/system/kaga.service && \
    sudo systemctl daemon-reload && \
    sudo systemctl enable --now kaga.service"

echo "✓ デプロイ完了。状態確認: ssh ${TARGET} systemctl status kaga.service"
