# SPレコード音声復元プロジェクト

SPレコードの盤面写真から音溝（溝底）の形状を読み取り、音声を復元するためのMATLABプロジェクトです。

盤面画像の各列（x）について、輝度から求めた「暗さ」の分布をもとに溝底のy座標を検出し、その並びを1周分つなげて音声波形とします。溝底の検出には**重心法（centroid method）**と**局所的最大値法（local maximum method）**の2種類があり、解像度を上げる手法として**リサンプル**と**内挿（interp2）**を比較しています。

## 処理の流れ

1. 盤面画像（8分割撮影の8枚）を読み込み、各画像をさらに横方向に10分割して細長い画像（`img_small`）にする（計80セグメント）。
2. `omitMask` で左右の無効領域（マスク）を除去する。
3. `ImageData` → `DarknessValue` を作り、暗さ行列 `dMat = 1 - img/255` を得る。必要に応じて `dResample`（リサンプル）や `dInterp`（interp2内挿）で高解像度化する。
4. `ddiff` でしきい値 `D_THRESH` を超える領域の立ち上がり／立ち下がりを求め、各xで溝底候補の区間（`getStartEndIdx`）と幅の狭い溝底区間（`getGrooveBtmIdx`）を特定する。
5. `extractGrv_cnt`（重心法）／`extractGrv_max`（局所的最大値法）で溝底のy座標を求め、`GrooveCandidates` に格納する。
6. `fitGroove` で手動指定した平行四辺形内の点群を直線近似し、溝の傾きを補正する。
7. ヒストグラムのピークから追跡対象の溝1本を選び、その中心付近（`TOL_DISTANCE`／`tol`）の点だけを抽出、欠損を `fillmissing` で補間し、多項式でデトレンドする。
8. 全セグメントの座標を連結し、回転数78rpmから標本化周波数を計算して `AudioData` を生成、波形・FFT・スペクトログラムを描画・保存し、wavに書き出す。

## ディレクトリ構成

- **`Research.prj`**: MATLABプロジェクトファイル
- **`src/`**: クラス定義と共通関数
- **`scripts/`**: 溝底抽出・音声生成の実行スクリプト群（旧版は `archive/`、針再生の評価は `evaluation/`）
- **`data/`**: 入力データ（`pictures/` は盤面写真、`stylus playback/` は針再生の音源）
- **`results/`**: 実行結果（日付ごとのフォルダに図・音声を保存）
- **`test/`**: テストコード

## `src/` の主なクラス・関数

### クラス

- **`ImageData`**: 盤面画像（グレースケール行列）と幅・高さ・IDを保持。`showImg` で画像を表示。
- **`DarknessValue`**: 暗さ行列 `dMat` と溝底抽出処理を担う中心的クラス。
  - `dResample(p,q)` / `dInterp(step,method)`: 解像度変換（リサンプル／内挿）
  - `ddiff(D_th)`: しきい値超えの立ち上がり・立ち下がりを計算
  - `getStartEndIdx(x)` / `getGrooveBtmIdx(...)`: 溝底候補区間の特定
  - `extractGrv_cnt(x)` / `extractGrv_max(x)`: 重心法／局所的最大値法で溝底のy座標を算出
- **`GrooveCandidates`**: 検出した溝底候補点（`pksCell`）を保持し、`showCandidates` で散布図表示。
- **`AudioData`**: 復元音声を保持し、波形（`audioPlot`）・FFT（`FFTPlot`）・スペクトログラム（`spectrogramPlot`）の描画、wav保存（`saveAudio`）、再生（`playAudio`）を行う。
- **`MediaData`**: メディアデータ用の抽象基底クラス（現状 `AudioData` は継承していない）。

### 共通関数

- **`omitMask`**: 画像左右の無効領域を除去
- **`fitGroove` / `fitGroove_multiPeaks`**: 平行四辺形内の点群を直線／多項式近似し溝の傾きを補正（`_multiPeaks` は1溝で複数検出された点を平均してから処理）
- **`createFigure`**: サイズ指定でfigureを作成
- **`soundCheck`**: 波形・FFT・スペクトログラムをまとめて描画・保存
- **`mkdirFromDate`**: `results/<日付>/` フォルダを作成しパスを返す
- **`setDefaultIntrpr`**: 描画のインタプリタをLaTeXに設定
- **`togglevisibility`**: 凡例クリックでプロットの表示/非表示を切り替えるコールバック

## `scripts/` の主なスクリプト

- **`pkCentroid_resample_1cycle.m`**: リサンプルしたデータに重心法を適用し、1周分の音声を生成する基本スクリプト。
- **`pkCentroid_interp2_1cycle.m`**: 上記を内挿（`dInterp`）ベースに置き換えた版。1周分の音声を生成。
- **`pkCentroidAndLocalMax_resample_1cycle.m`**: 重心法と局所的最大値法、リサンプルの有無（計4パターン）で1周分の音声を作り比較。移動平均・移動中央値による平滑化や針再生との比較も含む。
- **`pkCentroid_resample.m`**: 画像1枚（1セグメント）について、リサンプルの有無×2手法の溝底検出結果を比較する検討用スクリプト。
- **`pkCentroid_interp2.m`**: 画像1枚について、元データ・リサンプル・内挿の溝底検出結果を比較する検討用スクリプト。
- **`darknessInterp2.m`**: 小領域画像を `interp2` で疑似高解像度化する動作確認用スクリプト。
- **`evaluation/stylus/sound_from_stylus.m`**: 針で再生した音源を切り出し・フィルタ処理し、復元音声と比較・評価する。

## 基本的な使用方法

1. MATLABで **`Research.prj`** を開いてプロジェクトを起動します。
2. スクリプト先頭で以下を実行し、ルートフォルダを取得します。パス指定はこの `rootFolder` を基点に行ってください。
   ```matlab
   proj = currentProject;
   rootFolder = proj.RootFolder;
   ```
3. `scripts/` 内の目的に合ったスクリプト（例: `pkCentroid_interp2_1cycle.m`）を実行します。処理途中で `fitGroove` により溝中心をマウス（`ginput`）で指定する操作が必要です。
4. 生成された図・音声は `results/<日付>/` に保存されます。
