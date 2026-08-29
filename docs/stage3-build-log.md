# Stage 3 作業ログ: maplibre-native-slintをm329上でビルド

Stage 3(DRM/KMS経由でSlintのHello Worldアプリを表示)の作業記録。
compact前の状態保存も兼ねる。CLAUDE.mdセクション7のステージ定義参照。

## 方針

- まず[stars.optgeo.org/style/openstreetmap_jp_planet](https://stars.optgeo.org/style/openstreetmap_jp_planet)
  (既存の公開スタイル)を表示できることを確認してから、自前のVBM/VLCM PMTilesに進む
  (藤村さんの判断: 自前データの前に、動くパイプライン自体を確保する)
- **RustのRust実装(`rust/`)を使う**。理由: upstream READMEは"C++パスが正式な参照実装、
  Rustは実験的な連携用"と位置づけているが、Raspberry Pi/LinuxKMS向けの実機検証済み
  手順があるのはRust版のみ(PR #66, `rust/RASPBERRY_PI.md`)。C++版にはRPi固有の
  ビルドガイドが無い(Ubuntu 24.04/Windows/macOSのみ)。またRust版には
  `MAPLIBRE_STYLE_URL`等の環境変数でスタイルを差し替えられる仕組みがあり、
  「まず既存スタイルで確認」という進め方に合っている
- リポジトリは`/opt/maplibre-native-slint`にclone(まだ`git`管理下、`vendor/`化は
  動くことを確認してから検討)

## m329のハードウェア(2026-08-29確認)

- RAM: 4GB(空き約3.5GB)、Swap 2GB
- CPU: 4コア(Cortex-A72系、RPi4B標準)
- ディスク空き: 25GB(`/`, mmcblk0p2)
- **並列ビルド時のメモリ不足に注意**: 4コアフル活用(`-j4`)だとC++の重いコンパイル単位で
  OOMの可能性がある。詰まったら`-j2`等に落とすか、cargo/cmakeのデフォルト挙動に任せる

## 実施済みのセットアップ手順(m329上、再現用)

```bash
# システム依存関係(Debian Trixie。Ubuntu 24.04ガイドを参考にパッケージ名を合わせた)
sudo apt-get update
sudo apt-get install -y git cmake ninja-build pkg-config \
    libcurl4-openssl-dev libglfw3-dev libuv1-dev libpng-dev libwebp-dev \
    libicu-dev libssl-dev mesa-common-dev libgl1-mesa-dev libgles2-mesa-dev \
    libegl1-mesa-dev

# Rust(rustup)。既に~/.rustup/settings.tomlが存在していた(過去の準備の跡と思われる)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# → rustc 1.98.0 (aarch64-unknown-linux-gnu)。rust/README.mdの要求(1.90+)を満たす

# リポジトリ
sudo mkdir -p /opt/maplibre-native-slint
sudo chown -R hfu:hfu /opt/maplibre-native-slint
cd /opt/maplibre-native-slint
git clone https://github.com/maplibre/maplibre-native-slint.git .
git submodule update --init --recursive   # ← compact時点でまだ実行中(サブモジュールが大きく時間がかかる)
```

## 次にやること(compact後、ここから再開)

1. `git submodule update --init --recursive` の完了を確認
   (`ssh hfu@m329.local 'cd /opt/maplibre-native-slint && git submodule status'`)
2. `cd rust && cargo build --release --features linuxkms-noseat` を実行
   (時間がかかる見込み。バックグラウンド実行+定期確認を推奨)
3. ビルド成功したら、以下の環境変数で実行(`rust/RASPBERRY_PI.md`参照。
   コンソールのアクティブVT上で実行する必要がある — SSH越しでも、他に
   DRM masterを握っているプロセスが無ければ動くはず):

   ```bash
   SLINT_BACKEND=linuxkms-noseat \
   EGL_PLATFORM=surfaceless \
   LIBGL_ALWAYS_SOFTWARE=1 \
   GALLIUM_DRIVER=llvmpipe \
   MAPLIBRE_STYLE_URL=https://stars.optgeo.org/style/openstreetmap_jp_planet \
   ./target/release/maplibre_native_slint
   ```
4. JAPANNEXTディスプレイに地図が表示されるか、藤村さんに目視確認してもらう
5. 動いたら、Stage 4-5(自前のVBM/VLCM PMTilesへの切り替え)へ。
   `MAPLIBRE_STYLE_URL`に`pmtiles://`スタイルを指定する形になる見込み
6. 恒久的なビルド手順が固まったら、この場当たり的な手順を
   `scripts/setup-build-env.sh`のようなスクリプトに落とし込む

## クロスコンパイル要否の調査(2026-08-29)

PR #66(`rust/RASPBERRY_PI.md`追加、著者: yuiseki, 2026-06-19マージ)を確認した結果:

- **ビルドホスト**: Raspberry Pi 5 (Debian 12/bookworm)、**表示ホスト**: Raspberry Pi 4
  (Debian 13/trixie)という2台構成で検証されている。SPI/HDMI液晶(480×320)で
  PMTiles(`osm-fiord`スタイル、planet.pmtiles)の表示まで確認済み
- これは異アーキテクチャ間の「クロスコンパイル」ではなく、**同じaarch64・異なるDebian
  バージョン間でのバイナリ移動**。ICU/libpng16/libuvなどのバージョン差異が出るため、
  ビルドホスト側の該当ライブラリを`LD_LIBRARY_PATH`でバンドルする回避策が必要
  (ただしGPU/表示スタック — libEGL/libGL/Mesa/libdrm/libgbm — は禁止、必ず
  ターゲット側のものを使う)
- **m329は自身がTrixieなので、この問題は発生しない**。ビルド・実行とも同一機体・
  同一OSで完結でき、Yuisekiさんの検証環境より単純。クロスコンパイルは不要と判断し、
  m329上でのネイティブビルドを継続する
- 代替案(将来ビルドが遅すぎる場合): もう1台aarch64/Trixie機をビルド専用に用意する
  (異バージョン間バンドル問題は起きないが、ビルド時間短縮が目的になる)。現時点では
  不要と判断

## ETA見積もり(2026-08-29 13:52時点)

- サブモジュールclone開始13:28、24分経過時点で`vendor/maplibre-native`
  (GitHub上サイズ約4.7GB)が2.6GB取得済み(約56%、Wi-Fi経由 約1.8MB/s)
- clone完了まで残り30〜60分と推定(本体の残り+ネストした39個のサブモジュール)
- その後の`cargo build --release --features linuxkms-noseat`が本命。
  maplibre-nativeは大規模C++コードベースで、m329(4コアCortex-A72、RAM 3.7GB)では
  2〜5時間程度を見込む。`-j4`でのOOMリスクは既知([上記](#m329のハードウェア2026-08-29確認)参照)、
  発生時は`-j2`/`-j1`への切り替えでさらに延びる可能性
- **合計ETA: 現時点から初回起動確認まで体感3〜6時間**

## swap設定(2026-08-29): ディスクswap追加

デフォルトのswapは**zramのみ**(2GiB、zstd圧縮、`/dev/zram0`)。これはRAM内で
完結する圧縮swapなので物理RAM(3.7GiB)の枠を超える余裕を作らず、さらに
圧縮・展開でCPUを消費するため、ビルドでCPUを使い切っている状況とは相性が
悪い。「ビルド中はswapを切った方がいい」という発想は**逆効果**(物理RAM
使い切った瞬間に即OOM killerが起動しやすくなる)と判断し、代わりに
**ディスク上に4GBの一時swapfileを追加**した(zramは残したまま併用):

```bash
sudo fallocate -l 4G /var/swap-build.img
sudo chmod 600 /var/swap-build.img
sudo mkswap /var/swap-build.img
sudo swapon /var/swap-build.img
```

優先順位はzram(prio 100)が先、`/var/swap-build.img`(prio -2)は溢れた分の
受け皿。合計swap 6GiB。ディスク空きは18GB→14GBに減少(SDカード残容量的には
問題なし)。

**後片付け予定**: Stage 3完走(初回起動確認)後、`sudo swapoff /var/swap-build.img
&& sudo rm /var/swap-build.img`で外す。本番運用(kiosk用途、長時間稼働)で
SDカードへの書き込み摩耗を避けるため、常設はしない方針。

## Slint単体Hello Worldでの並行検証(2026-08-29)

本命のmaplibre-native-slint(巨大なC++ vendorツリーを含む)のビルドを待つ間、
**Slint単体のHello World**を別ディレクトリ(`~/slint-hello`)で並行して試すことで、
DRM/KMS(`linuxkms-noseat`)+ EGL software GL(llvmpipe)の経路そのものを
先に検証する。本命のmaplibre-native-slintの`rust/Cargo.toml`もdefault-featuresを
絞っていないため、Slint側の全バックエンド(winit経由のWayland/X11も含む)向け依存が
まとめて降ってくる。同じ構成でつまずくシステム依存(pkg-config経由)を先に洗い出せる
副次効果がある。

**追加で必要だったaptパッケージ**(pkg-configエラーで判明、上記「実施済みのセットアップ手順」に追加):
```bash
sudo apt-get install -y libfontconfig1-dev libudev-dev libinput-dev \
    libdrm-dev libgbm-dev libxkbcommon-dev libwayland-dev
```

## Stage 3達成 + 解像度・swap方針の修正(2026-08-29)

**Slint単体のHello Worldが、DRM/KMS経由でJAPANNEXTディスプレイに表示できることを確認した
(Stage 3の成功条件を達成)。** しかも当初想定していたsoftware rendering(llvmpipe)は不要で、
**ハードウェアGL(VideoCoreのv3dドライバ、GLES2)でそのまま動いた**。トラックボールの
カーソルも画面全域で正しく追従することを確認済み。

**わかったこと・修正した前提**:
- `EGL_PLATFORM=surfaceless`はSlint自身のオンスクリーンサーフェス作成には**不適切**
  だった(off-screen専用プラットフォームのため)。これを外したら動いた。llvmpipe/
  software renderingが必須なのはmaplibre-native側がGLES3を要求する場合の話であり、
  Slint単体(femtovg、GLES2で足りる)には無関係
- `SLINT_BACKEND=linuxkms-noseat`は**実行時の値としては無効**(Slint 1.17時点)。
  `noseat`はコンパイル時のCargo feature名であり、実行時は`linuxkms-femtovg`等の
  renderer名を指定する必要がある。upstream(maplibre-native-slint)のガイドは
  やや古いSlintバージョン向けの表記のまま
- **JAPANNEXTディスプレイのネイティブ解像度は3840x2160(4K)**。maplibre-native側の
  software rendering(llvmpipe)はピクセル数に比例してコストが増えるため、upstream
  検証環境(480×320)と比べて54倍のピクセル数になる4Kのままでは実用速度が出ない
  懸念がある。**`/boot/firmware/cmdline.txt`に`video=HDMI-A-1:1920x1080@60`を追加し、
  出力解像度を1920x1080に強制した**(ディスプレイ側は複数解像度対応、パネル側で
  スケーリングされる想定)
- **swap方針を修正**: Trixieには`rpi-swap`という新しいzram+file階層型swap管理が
  標準搭載されており、zram(2GB)が溢れた分を`/var/swap`(最大2GB、`/etc/rpi/swap.conf`
  でディスク使用率50%上限も設定済み)に自動でwritebackする。これは今回手動追加した
  `/var/swap-build.img`(4GB)と役割が重複しており、しかも再起動で無効化されていた
  (fstab未登録のため)。**`/var/swap-build.img`は削除し、OS標準のrpi-swapに一任する
  方針に変更**。ディスク空きが6.1GB→11GBに回復した。念のため再起動して検証したところ、
  `/var/swap`(2GB)は起動のたびに自動再生成される仕様だが(rpi-swap標準の常設コストとして
  許容)、手動追加した`/var/swap-build.img`は再生成されず、削除は恒久的に有効と確認できた

## ディスク逼迫時の対応方針(2026-08-29)

サブモジュールcloneが完了した時点で空き9.1GB(全39ネストサブモジュール込みで`.git`は6.0GBに拡大)。
本命のcargo/cmakeビルドがまだ控えており、USB SSD等の即効性のある救済手段が今すぐ
用意できるわけではないため、**残り3GBを危険水域**と定め、事前に対応順序を決めておく。

**在庫(2026-08-29 15時台時点)**:
- `~/slint-hello/target`(使い捨てテスト成果物): 1.5GB → Hello World確認後に即削除可
- `.git`(全サブモジュール履歴込み): 6.0GB → 迂闊に触らない(CMakeがgit describeで
  バージョン文字列を埋め込む可能性があり、破壊するとビルド自体が失敗しうる)
- `~/.cargo/registry`: 488MB → 効果は小さいが比較的安全
- `~/.rustup`: 1.4GB → 触らない(ツールチェーン本体)
- swapfile `/var/swap-build.img`: 4GB → 最終手段のみ([上記](#swap設定2026-08-29-ディスクswap追加)参照。
  縮小はOOMリスクとの再トレードオフ)

**対応順序**:
1. `cargo build`のプロセスグループに`SIGSTOP`を送って凍結(killせず進捗を保持したまま
   時間を稼ぐ)。凍結中に`du -sh target/*`で肥大化箇所を特定
2. 無傷で削れるもの(使い捨てテスト成果物、不要キャッシュ)から削除
3. `target/`配下で残りのビルドに不要な中間物があれば選択的に削除(全消し`cargo clean`は
   最終手段、手戻り最小化を優先)
4. 本当の最終手段: `cargo clean`で作り直し、またはswapfile縮小
5. 繰り返す/足りない場合はUSB SSD接続を前倒し。その際も**SIGSTOPで凍結→
   `/opt`をSSDへ退避→シンボリックリンクで差し替え→SIGCONTで再開**という順にすれば、
   ビルドをゼロからやり直さずに移設できる

**監視**: 30秒間隔でディスク空きを監視するウォッチドッグを常駐させ、5GB未満で警告、
3GB未満で検知(バックグラウンドタスクとして起動、Claude Codeが自動的に気づく仕組み)。

## 未解決・保留中の論点

- **ログインユーザー名 `hfu` vs `niroku`**: `~/.ssh/config`に元々
  `Host m329` (旧)と`Host m321`の両方が`User niroku`だった。"m3xx"系ハードウェア
  では`niroku`を使う古い(または別の)慣習があった可能性がある。今回は
  SDカードに既に`hfu`で作成済みのため`hfu`で進めているが、藤村さんに
  最終確認は取れていない。[0006](decisions/0006-hostname-naming.md)参照
- **cloud-initのavahi/mDNS**: `m329.local`のmDNS解決が時々失敗する(SSH自体は
  最終的に通るが、`ping`が"Unknown host"を返すことが複数回あった)。原因未調査。
  実害は無い(IPまたは再試行で解決する)が、気になる場合は
  `systemctl status avahi-daemon`を確認する価値がある
- **`network-config`のregulatory-domain単体でrfkillブロックが解除されるか未検証**
  ([0013](decisions/0013-wifi-rfkill-and-auto-chain.md)参照)。今はraspi-config経由の
  runcmdで確実に解除しているので実害は無いが、次にOSイメージが更新された際は
  再確認する価値がある
