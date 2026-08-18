# 進捗まとめ（2026-08-03 〜 2026-08-17）

## 今回やったこと

### 学会原稿（ASJ 2026-09）向けの図・音声作成
- photoshopで高解像度化した画像に対し、重心法で溝形状を抽出し音声・図を作成
- fig6（従来法データ）の差し替え
- 関連スクリプト名の変更・整理

### コードのリファクタリング
- `DarknessValue` を `DarknessMap`（darkness行列の保持）と `GrooveExtractor`（溝底抽出）に分割
- rename-proposal の実施（P2: GrooveCandidates→GroovePointCloud、P3-A: MediaData廃止・archive化、P4-1: imgWidth/imgHeight→width/height）
- checkcode静的解析によるテストゲートを追加
- fitGrooveを複数pks対応・p1p2自動選択対応に書き換え
- 不要ファイル（uploadTest.m）を削除

## 得られた結果
- `results/0731/`, `results/0802/`, `results/0807/`: 8x補間/8xリサンプル×重心法/局所最大法の音声・波形・FFT・STFT
- `results/figures/paper/202609asj/`: 学会原稿用figure
- `experiments/0731,0802,0807/`: 対応するcycleResult

## 次の2週間の予定
- （TODO: 記入）

## 相談・議論したいこと
- （TODO: 記入）
