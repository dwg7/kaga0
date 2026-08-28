# 3. Terrain/3D機能をv0のスコープ外とする

- ステータス: 承認
- 日付: 2026-08-29(issue #987時点での判断を記録)

## 状況

MapLibreはTerrain(3D地形)・pitch・bearing rotation・flyToなど高度なナビゲーション
機能を持つが、kaga v0の成功条件は「北海道の主要火山を表示できる」「パン・ズームが快適」
という2Dベースの体験である。Terrainは実装・検証コストが高く、Raspberry Pi 4Bの
GPU性能でのパフォーマンスも未検証。

## 決定

v0では以下をスコープ外とする:

- terrain、3D地形表現
- pitch、bearing rotation
- flyTo、高度な3Dナビゲーション

hillshade(2Dのまま陰影のみ)はTerrainと切り離して検討し、v0で実装できれば
nice to haveとして扱う(v1で本格対応)。

## 結果

- v0はパン・ズームのみの2D体験に絞ることで、Stage 1-7([CLAUDE.md](../../CLAUDE.md)参照)の
  各段階を早く確認できる
- Terrainの要否・実現可能性はRaspberry Pi 5等より高性能なハードウェアが視野に入る
  v2で再評価する([ロードマップ](../../CLAUDE.md#5-ロードマップ)参照)
