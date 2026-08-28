#!/usr/bin/env bash
# kitavolca から VBM/VLCM PMTiles を取得し、data/ に配置する。
#
# 前提: kitavolca (https://github.com/hfu/kitavolca) はパイプラインであり、
# 生成済みPMTilesを配布するリポジトリではない(README参照)。本番配信先の
# stars.optgeo.org も z/x/y ライブタイルサーバーであり、生の .pmtiles を
# 直接ダウンロードできるエンドポイントは提供していない(2026-08-29時点で確認)。
# そのため kaga はローカルの kitavolca チェックアウトで `just build-vbm` /
# `just build-vlcm` を実行し、その出力 (dst/vbm.pmtiles, dst/vlcm.pmtiles) を
# コピーする方式を取る。
#
# 対象火山(北海道、VBM/VLCM 双方がShapefile提供済み — kitavolca README 2026-07-04時点):
#   meakan(雌阿寒岳) tokachi(十勝岳) tarumae(樽前山) usu(有珠山) hokaikoma(北海道駒ヶ岳)
#
# 使い方:
#   ./scripts/fetch-data.sh [kitavolca のパス]
# 環境変数:
#   KITAVOLCA_DIR   kitavolca チェックアウトのパス(省略時は ../kitavolca を使い、
#                    存在しなければ隣にclone する)

set -euo pipefail

KAGA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KITAVOLCA_DIR="${1:-${KITAVOLCA_DIR:-"${KAGA_ROOT}/../kitavolca"}}"
VOLCANOES=(meakan tokachi tarumae usu hokaikoma)

if ! command -v just >/dev/null 2>&1; then
    echo "❌ 'just' が見つかりません。'brew install just' 等でインストールしてください" >&2
    exit 1
fi

if [ ! -d "${KITAVOLCA_DIR}" ]; then
    echo "→ kitavolca が見つかりません。clone します: ${KITAVOLCA_DIR}"
    git clone https://github.com/hfu/kitavolca.git "${KITAVOLCA_DIR}"
fi

echo "=== kitavolca: ${KITAVOLCA_DIR} ==="
cd "${KITAVOLCA_DIR}"

just setup

for volcano in "${VOLCANOES[@]}"; do
    echo "--- ${volcano}: VBM取得 ---"
    just fetch-vbm "${volcano}" || echo "⚠ ${volcano} の VBM 取得に失敗(スキップ)"
    echo "--- ${volcano}: VLCM取得 ---"
    just fetch-vlcm "${volcano}" || echo "⚠ ${volcano} の VLCM 取得に失敗(スキップ)"
done

just build-vbm
just build-vlcm
just validate

mkdir -p "${KAGA_ROOT}/data"
cp "${KITAVOLCA_DIR}/dst/vbm.pmtiles" "${KAGA_ROOT}/data/vbm.pmtiles"
cp "${KITAVOLCA_DIR}/dst/vlcm.pmtiles" "${KAGA_ROOT}/data/vlcm.pmtiles"

echo "✓ 完了: ${KAGA_ROOT}/data/{vbm,vlcm}.pmtiles"
du -h "${KAGA_ROOT}"/data/*.pmtiles
