# 4. data取得は本番タイルサーバーではなくkitavolcaパイプラインをローカル実行して行う

- ステータス: 承認
- 日付: 2026-08-29

## 状況

kagaはオフラインで動作する必要があるため、`.pmtiles`の実体ファイルが手元に必要。
kitavolcaの本番配信先である `stars.optgeo.org` は `/vbm`, `/vlcm` をTileJSON+
`{z}/{x}/{y}`のライブタイルサーバーとして公開しているが(2026-08-29時点で
`curl -sI https://stars.optgeo.org/vbm.pmtiles` は404)、生の`.pmtiles`ファイルを
直接ダウンロードできるエンドポイントは提供していない。kitavolca自体もREADMEで
「生成物をGitにコミットしない」方針を明記しており、リポジトリからの直接取得もできない。

## 決定

`scripts/fetch-data.sh` は、ローカルにkitavolcaをclone(または既存チェックアウトを利用)し、
`just fetch-vbm` / `just fetch-vlcm` で対象火山(道内でVBM/VLCM双方がShapefile提供済みの
`meakan`, `tokachi`, `tarumae`, `usu`, `hokaikoma`)を取得したうえで `just build-vbm` /
`just build-vlcm` を実行し、その出力 `dst/{vbm,vlcm}.pmtiles` を `data/` にコピーする方式とする。

## 結果

- 良い点: kitavolca本体のパイプライン変更(schema変更、対象火山追加等)にそのまま追従できる
- トレードオフ: 初回実行にGDAL/tippecanoe等のネイティブツールのインストールが必要
  (kitavolca側の前提条件がそのままkaga側にも波及する)
- stars.optgeo.orgに生pmtilesの静的配信エンドポイントが将来追加された場合は、
  本ADRを見直しシンプルなHTTP GETに置き換える
