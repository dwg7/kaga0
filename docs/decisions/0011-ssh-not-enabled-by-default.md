# 11. cloud-initのuser-dataにsshサービスの明示的な有効化(runcmd)を入れる

- ステータス: 承認(実機で踏んだ不具合の記録)
- 日付: 2026-08-29

## 状況

`scripts/flash-sdcard.sh`でm329に実際に書き込み・起動したところ、有線LAN経由で
IPアドレス取得・pingは通るのに、SSH接続は`Connection refused`だった。

原因は、`user-data`の`users[].ssh_authorized_keys`はauthorized_keysファイルを
配置するだけで、**sshサービス自体の有効化・起動は別**だったこと。Raspberry Pi OSは
セキュリティ上の理由でsshdを既定で無効化しており、cloud-initの`users`/`ssh`関連の
標準モジュールだけではこれを覆さなかった(RPi固有のcloud-init拡張に専用のトグルが
あるのかもしれないが、確実な標準機構である`runcmd`を使う方を選んだ)。

## 決定

`user-data`に以下を追加する:

```yaml
runcmd:
  - systemctl enable --now ssh
```

## 結果

- 良い点: cloud-initのバージョンやRPi拡張の細かい仕様に依存せず、確実にsshdが
  起動する
- 教訓: 「pingは通るがSSHは拒否される」は「まだ起動中」ではなく「サービスが
  無効」のサインである可能性が高い。次回似た症状が出たら、まず`runcmd`の
  設定漏れを疑う
