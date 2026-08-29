# 5. PMTilesの取得元として depot.optgeo.org を使う

- ステータス: 承認 — [0004](0004-fetch-data-builds-from-kitavolca-not-stars.md) を置き換え
- 日付: 2026-08-29

## 状況

[0004](0004-fetch-data-builds-from-kitavolca-not-stars.md)で採用した「kitavolcaをローカルで
clone・buildする」方式は正しく動くが、GDAL/tippecanoe等ネイティブツールのインストールが
必要で、実機側でデータを更新したい場合には荷が重い。

一方、`stars.optgeo.org`(本番タイルサーバー)は`/vbm`, `/vlcm`をTileJSON + `{z}/{x}/{y}`の
ライブタイルとしてのみ公開しており、ファイル単位のダウンロードはできない
(`curl -sI https://stars.optgeo.org/vbm.pmtiles` は404)。

`depot.optgeo.org` は、stars.optgeo.org上のpmtiles実体へのアクセス窓口として新たに
用意されたサーバーで、`vbm.pmtiles` / `vlcm.pmtiles` をRange対応の静的ファイルとして
直接GETできることを確認した(2026-08-29時点、`Accept-Ranges: bytes`、
vbm.pmtiles ≈64MB、vlcm.pmtiles ≈8MB)。

## 決定

`scripts/fetch-data.sh` は depot.optgeo.org から `aria2c`(優先、複数コネクション・
再開に対応)または `curl`(フォールバック)で直接ダウンロードする方式に変更する。
kitavolcaのローカルbuildは行わない。

`--remote` オプションで、実機(`$KAGA_USER@$KAGA_HOST`)へSSHし、実機自身が
depot.optgeo.orgから直接取得することもできるようにする — 開発機を経由した
二重転送(depot→開発機→実機)を避けるため。取得元URLは `.env` の
`PMTILES_BASE_URL` で切り替え可能にする。

## 結果

- 良い点: ネイティブツール不要、ダウンロードのみで完結。実機が直接取得できるため
  開発機の帯域・ディスクを経由しない
- トレードオフ: depot.optgeo.orgの可用性・データ鮮度に依存する。kitavolca側の
  ビルド結果が反映されるタイミングは `just upload`(kitavolca側)に依存する
- depot.optgeo.orgが将来提供しなくなった場合は、[0004](0004-fetch-data-builds-from-kitavolca-not-stars.md)
  の方式に戻すことを検討する
