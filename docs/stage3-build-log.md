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
