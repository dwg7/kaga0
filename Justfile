# kaga0 — タスクランナー
#
# Makeではなく Just を採用した理由:
#   - 姉妹プロジェクト kitavolca (https://github.com/hfu/kitavolca) も Just を使っており、
#     二つのリポジトリを行き来する開発者にとって流儀を揃えられる
#   - このリポジトリの作業はほぼ全てシェルコマンドの実行(ssh/rsync/curl等)であり、
#     ファイル依存関係に基づくビルドグラフ(Makeが得意な領域)はほぼ登場しない
#   - `set dotenv-load` により .env (git管理外、実機のホスト名など環境固有の値を置く場所。
#     docs/decisions/0007-secrets-policy.md 参照) をレシピに自動で読み込める

set dotenv-load := true
set shell := ["bash", "-c"]

# 既定タスク: 一覧表示
default:
    @just --list

# setup: 必須ツールの確認
setup:
    #!/usr/bin/env bash
    set -e
    echo "=== kaga0 セットアップ確認 ==="
    missing=0
    for cmd in ssh rsync curl; do
        command -v "$cmd" >/dev/null 2>&1 && echo "   ✓ $cmd" || { echo "   ❌ $cmd が見つかりません"; missing=1; }
    done
    for cmd in aria2c rpi-imager; do
        command -v "$cmd" >/dev/null 2>&1 && echo "   ✓ $cmd" || echo "   ⚠ $cmd が見つかりません(任意だが推奨)"
    done
    if [ ! -f .env ]; then
        echo "   ⚠ .env が見つかりません: cp .env.example .env で作成してください"
    else
        echo "   ✓ .env あり (KAGA_HOST=${KAGA_HOST:-未設定})"
    fi
    [ "$missing" -eq 0 ] || exit 1

# flash-sdcard: SDカードにOS書き込み + hostname/SSH鍵を設定(破壊的操作。事前に diskutil list で確認)
flash-sdcard device:
    ./scripts/flash-sdcard.sh {{device}}

# fetch-data: depot.optgeo.orgからPMTilesを手元のdata/に取得(プレビュー・動作確認用)
fetch-data:
    ./scripts/fetch-data.sh

# fetch-data-remote: 実機(KAGA_HOST)上で直接depot.optgeo.orgから取得(中継なし)
fetch-data-remote:
    ./scripts/fetch-data.sh --remote

# deploy: ビルド済みバイナリとsystemdユニットを実機へ転送・有効化
deploy:
    ./scripts/deploy.sh

# diagnose: 実機の状態診断(ssh経由)
diagnose:
    ./scripts/diagnose.sh --ssh

# ssh: 実機へログイン
ssh:
    ssh "${KAGA_USER}@${KAGA_HOST}"
