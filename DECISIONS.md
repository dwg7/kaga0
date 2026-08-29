# Decisions

kagaがこの形になっている理由。dwg7の他リポジトリと同様、番号を振って他の文書や
コミットメッセージから指し示せるようにしている(`see D3`)。

各項目は一段落の要旨のみ。詳細な経緯・調査ログ・コード例は各リンク先の
[docs/decisions/](docs/decisions/)配下の個別ファイル(ADR形式)にある——この
`DECISIONS.md`はその索引であり、内容の複製ではない。

## D1: 意思決定はADR形式で`docs/decisions/`に記録する

kagaはハードウェア実機を伴うプロジェクトで、「なぜNative実装か」「なぜTerrainを
v0スコープ外にしたか」等の判断根拠を後から追える必要がある。番号付きファイル1つ
1決定の形式を採用。→ [docs/decisions/0001](docs/decisions/0001-record-architecture-decisions.md)

## D2: ブラウザではなくNativeスタック(MapLibre Native + Slint)を採用する

v0の成功条件「電源投入後に直接地図が起動する」専用機体験には、ブラウザ・
X11/Waylandを介さない直接DRM/KMS描画が適している。
→ [docs/decisions/0002](docs/decisions/0002-native-stack-not-browser.md)

## D3: Terrain/3D機能をv0のスコープ外とする

pitch/bearing/flyToなど高度なナビゲーションはv0の必須要件ではなく、標高タイル
対応後(v2以降)に再検討する。→ [docs/decisions/0003](docs/decisions/0003-terrain-out-of-v0-scope.md)

## D4: (置き換え済み)kitavolcaパイプラインをローカル実行してdataを取得する

→ D5に置き換え。[docs/decisions/0004](docs/decisions/0004-fetch-data-builds-from-kitavolca-not-stars.md)

## D5: PMTilesの取得元として`depot.optgeo.org`を使う

`stars.optgeo.org`はz/x/yライブタイル配信のみでファイル単位のダウンロードを
提供しないため、実体ファイルを直接HTTP GETできる`depot.optgeo.org`をオフライン
用途の取得元とする。D14のbvmap背景地図オフライン化でもこの区別が再び効いてくる。
→ [docs/decisions/0005](docs/decisions/0005-depot-optgeo-org.md)

## D6: 実機のホスト名は個体固有のコードネーム、"kaga0"はプロジェクト名

将来複数台展開(kaga1, kaga2...)する前提で、リポジトリ名と実機ホスト名を分離。
→ [docs/decisions/0006](docs/decisions/0006-hostname-naming.md)

## D7: 公開リポジトリに秘匿情報を残さない構成(.env / .env.example)

`dwg7/kaga0`はPublic。実機のホスト名・SSH鍵ファイル名等は`.env`(git管理外)に。
Justfile採用の決め手にもなった(dotenv対応)。
→ [docs/decisions/0007](docs/decisions/0007-secrets-policy.md)

## D8: (撤回済み)SDカード書き込みに"Legacy Bookworm"イメージを使う

→ D9に置き換え。[docs/decisions/0008](docs/decisions/0008-legacy-bookworm-image.md)

## D9: Trixie + cloud-init user-dataに切り替える

D8のcustom.toml方式(`init_format: systemd`)がrpi-imagerで機能しなかったため、
Trixie系のcloud-initベースの初期化に切り替えた。
→ [docs/decisions/0009](docs/decisions/0009-trixie-and-cloudinit.md)

## D10: RPiではMesaソフトウェアレンダリング(llvmpipe)が必須

RPi4のVideoCore/V3D GPUはmaplibre-nativeが要求するハードウェアGLES3パスを
持たないため、`LIBGL_ALWAYS_SOFTWARE=1`等が必要な場面がある——ただしD14の
zero-copy GL実装では、Slint側は実際にハードウェアGL(V3D)で動作している
(この決定はmaplibre-native単体のheadlessレンダリング文脈のもの)。
→ [docs/decisions/0010](docs/decisions/0010-software-gl-required.md)

## D11: cloud-initでsshを明示的に有効化する

有線LAN経由でも実機にSSH到達できない不具合があり、`runcmd`での明示的な
有効化が必要だった。→ [docs/decisions/0011](docs/decisions/0011-ssh-not-enabled-by-default.md)

## D12: network-configのWi-Fi設定を公式実例どおりの書式にする

独自の書式(`wifis.wlan0.dhcp4`等のみ)ではなく、公式ドキュメントの実例に厳密に
合わせることで解決。→ [docs/decisions/0012](docs/decisions/0012-wifi-network-config-schema.md)

## D13: Wi-Fiのrfkillブロック解除とconfigure-wifiの自動連結

`flash-sdcard.sh`に`configure-wifi.sh`を自動連結し、rfkillのソフトブロックも
解除する。→ [docs/decisions/0013](docs/decisions/0013-wifi-rfkill-and-auto-chain.md)

## D14: HDMI/GPU機体にはzero-copy GL(C++)実装を使う

`rust/`実装(`linuxkms-noseat`、ソフトウェアレンダリング)は、実際にはSPI
(GPU無し)機体向けのレシピをHDMI(V3D GPU有り)機体に誤って適用していたと
判明。[Yuiseki氏のpi-maplibre-native-slint-touch](https://github.com/yuiseki/pi-maplibre-native-slint-touch)の
`hdmi/`実装(zero-copy GL、C++)に切り替え、Stage 5-6を突破した。CPU使用率が
140%前後から25%程度に劇的改善。bvmap背景地図のオフライン化、ズームバイアスに
よるfps改善、マウスホイールの独自実装(Slintの`linuxkms`バックエンドが
wheel/scrollイベントを処理しないため)等、この決定を起点に多くの改善が続いている。
→ [docs/decisions/0014](docs/decisions/0014-hdmi-path-zero-copy-gl.md)(このADRが今夜一番よく更新されている——謝辞・技術詳細・実機ログ全て含む)
