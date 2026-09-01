# Raspberry Pi 4B 活用パターン(草稿)

kaga0(dwg7/kaga0、火山基本図オフライン表示アプライアンス)での実体験に基づく、
Raspberry Pi 4Bを組み込み機器・キオスク/アプライアンスとして活用する際のパターン集。
`cafebabe`が新規パターンを募集した際に提案する目的で起草(2026-09-02、藤村さん指示)。
書式は`dwg7/cafebabe`の`patterns/*.md`に倣う。

各パターンの「実例」は、kaga0の実際のコミット・ADR・issueに基づく一次情報。

---

## GPUが使えるかは「SoCの型番」ではなく「表示出力経路」で決まる

**タグ**: RPi4B、GPU/GL、要検証

**状況(Context)**
RPi4B上で、OpenGL ES依存のグラフィックスライブラリ(地図描画エンジン等)を組み込む場面。
上流ドキュメントに「RaspberryPiのVideoCore GPUには使えるハードウェアGLES3パスが無く、
ソフトウェアラスタライザが必須」という記述がある。

**問題/対立する力(Problem / Forces)**
この種の記述は特定の構成(例: SPI接続の小型ディスプレイでKMS/DRMを経由しない機体)向けに
書かれていることが多く、HDMI接続でDRM/KMSが有効な機体には当てはまらない。文言だけを鵜呑みに
すると、実際には使えるハードウェアアクセラレーションを見送り、大幅に遅いソフトウェア
レンダリング(実測でCPU使用率140%超)を選んでしまう。

**解決(Solution)**
「GPUが使えるか」を機体・SoCの型番だけで判断せず、実際の表示出力経路(HDMI+vc4/v3d
DRM-KMSドライバか、SPI接続の小型パネルでKMSを経由しないか)で判断する。上流ドキュメントを
読む際は、それがどの構成を前提に書かれたものかを本文・リポジトリ構成(例: `rust/`と`hdmi/`が
別ディレクトリに分かれている等)から確認する。

**実例(Known uses)**
- `kaga0` — 当初SPI機体向けの「software GL必須」という上流の記述
  ([maplibre-native-slintのrust/RASPBERRY_PI.md](https://github.com/maplibre/maplibre-native-slint/blob/main/rust/RASPBERRY_PI.md))を、
  HDMI接続・V3D GPU搭載の実機に誤適用した
  ([docs/decisions/0010](https://github.com/dwg7/kaga0/blob/main/docs/decisions/0010-software-gl-required.md))。
  後日、HDMI/GPU機体向けの別実装(zero-copy GL、C++)に切り替えたところ、CPU使用率
  140%超→25%、fps大幅改善(29-38fps)を達成
  ([docs/decisions/0014](https://github.com/dwg7/kaga0/blob/main/docs/decisions/0014-hdmi-path-zero-copy-gl.md))

---

## 表示用GLコンテキストとオフスクリーン用GLコンテキストは同一プロセスで共存させない

**タグ**: RPi4B、GPU/GL、EGL

**状況(Context)**
RPi4B上で、UIフレームワーク(画面表示用のハードウェアGLコンテキストを持つ)と、地図描画等の
別ライブラリ(独自にヘッドレス/オフスクリーンのEGLコンテキストを初期化する)を同一プロセス内で
組み合わせる場面。

**問題/対立する力(Problem / Forces)**
両者が別々にEGLコンテキストを初期化しようとすると、環境変数(`EGL_PLATFORM`等)をどう
設定しても必ずどちらかが壊れる(`eglInitialize()`失敗、または`swap_buffers`時の
セグフォルト)。原因の切り分けが難しく、環境設定自体の問題だと誤診しがち。

**解決(Solution)**
同一プロセス内での複数EGLコンテキスト共存は避ける。ライブラリ側が「既存のGLコンテキストを
共有して使う」モード(zero-copy)を提供していればそれを使う。無ければ、片方をソフトウェア
レンダリングに倒してハードウェアGLとの競合を回避する。切り分けには、該当ライブラリの
初期化ロジックのみを再現した最小限の単体テストプログラムを書き、単独では動く/動かないを
先に確認するとよい(gdbでのバックトレース確認と併用)。

**実例(Known uses)**
- `kaga0` — maplibre-nativeのヘッドレスEGL初期化とSlintのGBM経由ハードウェアGLが同一
  プロセスで衝突。gdbで`swap_buffers`内のセグフォルトを確認、最小限のCテストプログラムで
  環境自体は正常と確認した上で「同一プロセス内共存」が原因と特定
  ([docs/stage4-5-build-log.md](https://github.com/dwg7/kaga0/blob/main/docs/stage4-5-build-log.md))。
  最終的にはSlintと直接GLコンテキストを共有する実装(zero-copy GL)に切り替えて解決
  ([docs/decisions/0014](https://github.com/dwg7/kaga0/blob/main/docs/decisions/0014-hdmi-path-zero-copy-gl.md))

---

## 完全オフライン運用のRPiアプライアンスでは、ローカルHTTPサーバーよりファイル直読みを優先する

**タグ**: RPi4B、オフライン運用、PMTiles

**状況(Context)**
RPi4Bベースの完全オフラインアプライアンスで、PMTiles等の大容量データファイルをアプリに
供給する場面。busybox httpd等の軽量ローカルHTTPサーバーを使う実装がよくある。

**問題/対立する力(Problem / Forces)**
ローカルとはいえHTTP/TCPスタックを経由すると、高負荷時(高頻度のタイル要求が短時間に
集中する場面等)にリクエストが取りこぼされることがある。プロセスも1つ余計に管理する
必要がある。

**解決(Solution)**
使用ライブラリがバイト範囲read(HTTP Rangeリクエスト相当)を`file://`スキームで直接
サポートしているか、ソースコードで確認する。対応していれば、ローカルHTTPサーバーを廃止し
ファイル直読みに切り替える。プロセスが1つ減り、TCP/HTTPスタックを経由しないため
リクエスト取りこぼしが構造的に起きなくなる。

**実例(Known uses)**
- `kaga0` — mbgl-core(MapLibre Native)の`LocalFileSource`が`file://`直読みに対応
  していることをソースコード調査で発見。busybox httpd経由からの切り替え後、体感で
  「パフォーマンス上昇」——ログ上の平均fpsは同等だったが、タイル欠けの減少(取りこぼし
  削減)が体感の正体と推測される
  ([docs/plan.md](https://github.com/dwg7/kaga0/blob/main/docs/plan.md)「`pmtiles://file://`方式への切り替え」節)

---

## キーボードレスRPiアプライアンスには、systemdのConflicts=による自動排他とオンスクリーンの安全な電源断手段が必須

**タグ**: RPi4B、appliance、systemd

**状況(Context)**
RPi4BをHDMI接続のキオスク/アプライアンスとして、キーボード・ネットワーク接続無しで
持ち込み運用する場面(会議・イベントでのデモ用途等)。

**問題/対立する力(Problem / Forces)**
1. DRM/KMSのマスター権限はコンソール(getty)とキオスクアプリで競合する。手動で
   `systemctl stop getty@tty1`のような追加操作が必要だと、「電源投入だけでアプリが
   起動する」という要件を満たせない。
2. キーボードが無いと、正常なシャットダウン手段が「電源を物理的に抜く」しか無くなり、
   SDカードのファイルシステムを傷めるリスクがある。

**解決(Solution)**
1. キオスクアプリのsystemdユニットに`Conflicts=getty@tty1.service`を設定する。
   systemdのConflicts=は双方向のため、アプリ起動時に自動でgettyが止まり、手動操作が
   不要になる。
2. 画面上に、確認ダイアログ無しの直接的なシャットダウンボタンを設置する。裏側では
   `sudo systemctl poweroff`をパスワード無しsudo(該当コマンドのみに絞る等)で実行する。
   確認ダイアログを挟むと「電源を抜くのと同じくらい気軽に、かつそれより安全に」という
   狙いが損なわれる。

**実例(Known uses)**
- `kaga0` — `kaga-map.service`に`Conflicts=getty@tty1.service`を設定し、手動コンソール
  停止操作を撤廃。シャットダウンボタンは実機での物理電源サイクル(シャットダウン→電源
  抜き差し→自動起動)まで含めて動作確認済み(2026-08-30)

---

## RTCバッテリー非搭載のRPiでは、電源断中に進行する情報(時刻等)を安易に表示しない

**タグ**: RPi4B、ハードウェア制約、UX

**状況(Context)**
標準構成のRaspberry Pi(RTCバッテリー拡張無し)を、ネットワーク接続無し(NTP同期不可)で
運用する場面。

**問題/対立する力(Problem / Forces)**
RTCバッテリーが無いRPiは、電源断中は時刻を保持できない。オフライン運用では再起動後に
NTP同期もできないため、システム時計は「最後にシャットダウンした時点の値から自走する」
状態になる。UIに時計を表示すると、実際の時刻と異なる値を表示し続けるリスクがある。

**解決(Solution)**
ハードウェア制約(RTCバッテリー非搭載)とネットワーク前提(オフライン運用)の組み合わせで
「表示している時刻が正しい保証が無い」場面では、時刻を表示しないことを選ぶ。「間違った
情報を見せる」より「情報を見せない」方が安全、という判断基準を明示する。

**実例(Known uses)**
- `kaga0` — [issue #2](https://github.com/dwg7/kaga0/issues/2)として提起され、
  ステータスバーの時計表示を撤去(2026-08-31)

---

## DRM/KMSアプリの解像度はEDID自動認識に任せ、UI側は解像度非依存に作る

**タグ**: RPi4B、DRM/KMS、appliance

**状況(Context)**
RPi4B+HDMIのキオスク/アプライアンスを、行き先が事前にわからない外部ディスプレイ
(会議室のプロジェクタ等)に接続して使う場面。

**問題/対立する力(Problem / Forces)**
- 接続先の解像度を事前にハードコードしておくと、実際に接続したディスプレイが
  対応していない解像度を強制することになりかねない
- 逆にUI側が解像度を意識しない作りだと、解像度が変わった時に体感が崩れる箇所が出る
  (例: マウス相対移動量を解像度に関係なく1:1でロジカルピクセルに変換していると、
  4Kディスプレイでは1080pの半分の距離しかカーソルが動かず「遅い」と感じる)

**解決(Solution)**
- カーネルのcmdlineで解像度を明示指定(`video=<connector>:<解像度>@<Hz>`)しない限り、
  DRM/KMSアプリはディスプレイのEDIDが申告するPREFERREDモードを自動選択する。行き先が
  未知の外部ディスプレイに繋ぐ用途では、これを積極的に活用する(明示指定は開発中の
  固定検証用途に限定)
- ただしUI側(特にポインタ処理)は解像度を意識した実装にする。マウスの相対移動量を
  「基準解像度(例: 1080p)に対する比率」でスケールしてから累積すると、異なる解像度間で
  体感速度が揃う

**実例(Known uses)**
- `kaga0` — `cmdline.txt`から`video=`行を外すと、接続中のディスプレイのEDIDネイティブ
  解像度(4K@60Hz)が自動選択されることを実機で確認。開発中は特定解像度に固定する
  スクリプト(`just set-resolution auto|1080p|1440p|4k`)を用意しつつ、実運用のデフォルトは
  autoを推奨とした。マウスカーソル速度についても、Slintの`linuxkms`バックエンドを
  パッチし、`screen_size.height / 1080.0`で相対移動量をスケールする実装を追加
  (`src/vendor-patches/slint-linuxkms-backend/input.rs`)

---

## 次のアクション

- `cafebabe`が新規パターンを募集した際、この草稿から適切な粒度で提案する
- 藤村さんのレビュー待ち(内容の過不足・実例の正確性確認)
