# Raspberry Pi 物理セットアップ手順

対象: Raspberry Pi 4B(初期ターゲット)。詳細な設計背景は [CLAUDE.md](../CLAUDE.md) を参照。

## 1. SDカード書き込み

`scripts/flash-sdcard.sh` を使うと、OS書き込みとhostname/SSH設定を一括で行える。

```bash
diskutil list                          # SDカードのデバイス名(/dev/diskN)を確認
./scripts/flash-sdcard.sh /dev/diskN
```

手動で行う場合は [Raspberry Pi Imager](https://www.raspberrypi.com/software/) で:

1. OS: **Raspberry Pi OS Lite (64-bit)**
2. 歯車アイコンから編集:
   - ホスト名: `kaga0`
   - ユーザー名・パスワードを設定(デフォルトの`pi`ユーザーは存在しない)
   - SSH有効化・公開鍵認証を推奨
   - Wi-Fiは保険として設定(有線があればそちらが優先)

## 2. 起動・疎通確認

1. SDカードを挿入
2. 電源投入(RPi 4Bは **5V/3A USB-C** — 電流不足だと不安定になるので注意)
3. 疎通確認:

```bash
ssh <ユーザー名>@kaga0.local
```

`.local`が引けない場合は [network-troubleshooting.md](network-troubleshooting.md) を参照。

## 3. HDMI/マウス/キーボード接続

- HDMI → プロジェクタ/大型ディスプレイ
- USBマウス(操作用)
- USBキーボード(保守用。通常運用では不要)

## 4. 動作確認と診断

実機上、またはSSH経由で診断情報を収集できる:

```bash
./scripts/diagnose.sh                          # 実機上で直接実行
./scripts/diagnose.sh --ssh user@kaga0.local   # 手元のMacからSSH経由で実行
```

出力をそのままClaude Codeとのセッションに貼り付けると、原因特定を試みられる。
実機の目視確認(画面に何が映っているか等)は人間側の役割 — [CLAUDE.md セクション7](../CLAUDE.md#7-ハードウェアプロジェクトにおける作業分担重要) 参照。
