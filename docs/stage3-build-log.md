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
