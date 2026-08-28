# 2. ブラウザではなくNativeスタック(MapLibre Native + Slint)を採用する

- ステータス: 承認
- 日付: 2026-08-29(issue #987時点での判断を記録)

## 状況

kaga v0の成功条件は「電源投入後に直接地図が起動する」専用機体験である。
ブラウザ(Chromium kiosk mode等)を使えば実装は早いが、ブラウザ設定・アップデート・
拡張機能・レンダラプロセスなど、専用機として不要な複雑さを持ち込む。

## 決定

MapLibre Native + Slint(LinuxKMSバックエンド)によるBrowser-less / X11-less /
Wayland-less構成を採用する。参照実装として
[`maplibre/maplibre-native-slint`](https://github.com/maplibre/maplibre-native-slint)
をフォーク・参照し、ゼロから統合しない。

## 結果

- 良い点: 起動が速い、アタックサーフェスが小さい、ブラウザのUIが利用者の目に触れない
- トレードオフ: Web技術資産(既存のkitavolca `style.json`のプレビュー用JS等)がそのまま使えず、
  Native側での再実装・検証が必要になる
- 検証段階は [CLAUDE.md セクション7](../../CLAUDE.md#7-ハードウェアプロジェクトにおける作業分担重要) の
  Stage 1-7で段階的に確認する
