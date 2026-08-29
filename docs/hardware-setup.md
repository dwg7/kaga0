# Raspberry Pi 物理セットアップ手順

対象: Raspberry Pi 4B(初期ターゲット)。詳細な設計背景は [CLAUDE.md](../CLAUDE.md) を参照。

## 0. 事前準備

`.env` に実機のホスト名等を設定する(まだの場合):

```bash
cp .env.example .env
$EDITOR .env   # KAGA_HOST, KAGA_USER, SSH_PUBKEY_FILE を実値に
just setup     # 必須ツールと.envの有無を確認
```

ホスト名の決め方は [docs/decisions/0006-hostname-naming.md](decisions/0006-hostname-naming.md)、
`.env`をgit管理外にする理由は [docs/decisions/0007-secrets-policy.md](decisions/0007-secrets-policy.md) 参照。

## 1. SDカード書き込み

```bash
diskutil list              # SDカードのデバイス名(/dev/diskN)を確認
just flash-sdcard /dev/diskN
```

`scripts/flash-sdcard.sh`(`just flash-sdcard`)が、OS書き込み・hostname設定・SSH公開鍵の
登録・パスワード認証の無効化を一括で行う。SSH公開鍵は`.env`の`SSH_PUBKEY_FILE`を使う
(公開鍵認証のみでログインする方針の背景は [CLAUDE.md セクション8](../CLAUDE.md) 参照)。

⚠ 指定したデバイスを完全に消去する破壊的操作。`diskutil list`の出力を必ず自分の目で確認してから実行する。

## 2. 起動・疎通確認

1. SDカードを挿入
2. 電源投入(RPi 4Bは **5V/3A USB-C** — 電流不足だと不安定になるので注意)
3. 疎通確認:

```bash
just ssh
# または: ssh $KAGA_USER@$KAGA_HOST
```

`.local`が引けない場合は [network-troubleshooting.md](network-troubleshooting.md) を参照。

## 3. HDMI/マウス/キーボード接続

- HDMI → プロジェクタ/大型ディスプレイ
- USBマウス(操作用)
- USBキーボード(保守用。通常運用では不要)

## 4. 動作確認と診断

実機上、またはSSH経由で診断情報を収集できる:

```bash
just diagnose
# または: ./scripts/diagnose.sh --ssh $KAGA_USER@$KAGA_HOST
# 実機上で直接実行する場合: ./scripts/diagnose.sh
```

出力をそのままClaude Codeとのセッションに貼り付けると、原因特定を試みられる。
実機の目視確認(画面に何が映っているか等)は人間側の役割 — [CLAUDE.md セクション7](../CLAUDE.md#7-ハードウェアプロジェクトにおける作業分担重要) 参照。
