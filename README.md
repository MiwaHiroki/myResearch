# SPレコード音声復元プロジェクト

SPレコードの盤面写真から音溝（溝底）の形状を読み取り、音声を復元するためのMATLABプロジェクトです。

盤面画像の各列（x）について、輝度から求めた「暗さ」の分布をもとに溝底のy座標を検出し、その並びを1周分つなげて音声波形とします。溝底の検出には**重心法（centroid method）**と**局所的最大値法（local maximum method）**の2種類があり、解像度を上げる手法として**リサンプル**と**内挿（interp2）**を比較しています。

## 処理の流れ

1. 盤面画像（8分割撮影の8枚）を読み込み、各画像をさらに横方向に10分割して細長い画像（`img_small`）にする（計80セグメント）。
2. `omitMask` で左右の無効領域（マスク）を除去する。
3. `ImageData` → `DarknessMap` を作り、暗さ行列 `dMat = 1 - img/255` を得る。必要に応じて `dResample`（リサンプル）や `dInterp`（interp2内挿）で高解像度化する。
4. `DarknessMap` の `setDiffTF` でしきい値 `D_THRESH` を超える領域の立ち上がり／立ち下がりを求め、`GrooveExtractor` で各xの溝底候補の区間（`findThresholdIntervals`）と幅の狭い溝底区間（`findGrooveBottomIntervals`）を特定する。
5. `GrooveExtractor` の `extractByCentroid`（重心法）／`extractByLocalMax`（局所的最大値法）で溝底のy座標を求め、`GrooveCandidates` に格納する。
6. `fitGroove` で選択した平行四辺形内の点群を直線近似し、溝の傾きを補正する（詳細は「溝の選択（fitGroove）」）。
7. ヒストグラムのピークから追跡対象の溝1本を選び、その中心付近（`TOL_DISTANCE`／`tol`）の点だけを抽出、欠損を `fillmissing` で補間し、多項式でデトレンドする。
8. 全セグメントの座標を連結し、回転数78rpmから標本化周波数を計算して `AudioData` を生成、波形・FFT・スペクトログラムを描画・保存し、wavに書き出す。
9. `saveCycleResult` で実験条件と解析結果（`ImageData`／`GrooveCandidates`／`AudioData`／`y_comb` など）を `experiments/<日付>/` の `.mat` に保存する（詳細は「1周分の実験結果の保存」）。

## ディレクトリ構成

- **`Research.prj`**: MATLABプロジェクトファイル
- **`src/`**: クラス定義と共通関数（配線されていない旧コードは `archive/`）
- **`scripts/`**: 溝底抽出・音声生成の実行スクリプト群（旧版は `archive/`、針再生の評価は `evaluation/`）
- **`data/`**: 入力データ（`pictures/` は盤面写真、`stylus playback/` は針再生の音源）
- **`experiments/`**: 1周分の解析結果の`.mat`（日付ごと。旧版・失敗した試行は `archive/`）
- **`results/`**: 図・音声の出力先（日付ごと。原稿用の図は `figures/paper/<会議名>/`）
- **`test/`**: テストコード（`unit/` が `runAllTests` の対象。廃止したクラスのテストは `archive/`）

`experiments/` と `results/` は寿命が違うので分けている。`results/` の図・音声は `experiments/` の`.mat`から何度でも作り直せるが、`.mat` 自体は `fitGroove` の手動操作を80セグメント分やり直さないと作れない。**バックアップの対象は `data/` と `experiments/` の2つ**で、`results/` は消してよい。どちらもgit管理外。

## `src/` の主なクラス・関数

### クラス

- **`ImageData`**: 盤面画像（グレースケール行列）と幅・高さ・IDを保持。`showImg` で画像を表示。
- **`DarknessMap`**: 暗さ行列 `dMat` の保持・変換・表示を担うクラス。
  - `dResample(p,q)` / `dInterp(step,method)`: 解像度変換（リサンプル／内挿）
  - `setDiffTF(D_THRESH)`: しきい値超えの立ち上がり・立ち下がりを計算
  - `plotD_x(x)`: 列xの暗さ分布をプロット
- **`GrooveExtractor`**: `DarknessMap` から溝底候補点を抽出するクラス。`dMat`（最大約2GB）を複製しないよう、各メソッドは対象の `DarknessMap` インスタンスを引数として都度受け取る。
  - `findThresholdIntervals(map,x)` / `findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH)`: 溝底候補区間の特定（区間は `startIdxCells`/`endIdxCells` に保持）
  - `extractByCentroid(map,x)` / `extractByLocalMax(map,x)`: 重心法／局所的最大値法で溝底のy座標を算出
- **`GrooveCandidates`**: 検出した溝底候補点（`pksCell`）を保持し、`showCandidates` で散布図表示。
- **`AudioData`**: 復元音声を保持し、波形（`audioPlot`）・FFT（`FFTPlot`）・スペクトログラム（`spectrogramPlot`）の描画、wav保存（`saveAudio`）、再生（`playAudio`）を行う。

上記はいずれも継承関係を持たない独立した値クラス。共通の抽象基底クラスだった`MediaData`は誰にも継承されず孤立していたため、`src/archive/MediaData.m`へ退避した（単体テストも`test/archive/`に移動済み）。

### 共通関数

- **`omitMask`**: 画像左右の無効領域を除去
- **`fitGroove`**: 手動（`ginput`）または保存済みの点（`P1`/`P2`）で選んだ平行四辺形内の点群を直線近似し、溝の傾きを補正する。複数の溝底候補点データセット（例: 重心法と局所的最大値法）を`cell`でまとめて渡すと、1回の選択で全データセットを補正できる（詳細は「溝の選択（fitGroove）」）
  - `src/archive/fitGroove_multiPeaks.m`: 旧版（1溝で複数検出された点を平均してから処理）。現行の`fitGroove`に統合されていないため参照用として残置
- **`createFigure`**: サイズ指定でfigureを作成
- **`soundCheck`**: 波形・FFT・スペクトログラムをまとめて描画・保存
- **`mkdirFromDate`**: 図・音声の出力先 `results/<日付>/` を作成しパスを返す
- **`experimentDir`**: 実験結果`.mat`の保存先 `experiments/<日付>/` を作成しパスを返す（`Create=false` でパスを組むだけ）
- **`setDefaultIntrpr`**: 描画のインタプリタをLaTeXに設定
- **`cycleConditions`**: 1周分の音声を作成したときの実験条件（定数・日付・保存先・高解像度化のパラメータ）をstructにまとめる。必須の定数が欠けていればエラーになる
- **`cycleMethodResult`**: 溝底抽出手法1つ分の1周データ（`GrooveCandidates`配列・x/y座標・`y_comb`・`AudioData`）をstructにまとめる。要素数の整合性をここで検証する
- **`saveCycleResult`**: 上記2つをまとめて `experiments/<日付>/cycleResult_<条件>_<日付>.mat` に保存する（詳細は下記「1周分の実験結果の保存」）
- **`loadCycleResult`**: `saveCycleResult` で保存した結果を読み込む
- **`cycleResultFileName`**: 結果.matのファイル名の命名規則を返す（保存側・読み込み側で共有）
- **`cycleResultPath`**: 結果.matのフルパスを返す（読み込み側用。`experiments/<日付>/` を見て、無ければ移行前の `results/<日付>/` も探す）
- **`togglevisibility`**: 凡例クリックでプロットの表示/非表示を切り替えるコールバック

## `scripts/` の主なスクリプト

- **`pkCentroid_resample_1cycle.m`**: リサンプルしたデータに重心法を適用し、1周分の音声を生成する基本スクリプト。末尾で `saveCycleResult` により `cycleResult_rsmplD_<日付>.mat` を保存。
- **`pkCentroid_interp2_1cycle.m`**: 上記を内挿（`dInterp`）ベースに置き換えた版。1周分の音声を生成し、`cycleResult_intpD_<日付>.mat` を保存。
- **`pkCentroidAndLocalMax_resample_1cycle.m`**: 重心法と局所的最大値法、リサンプルの有無（計4パターン）で1周分の音声を作り比較。移動平均・移動中央値による平滑化や針再生との比較も含む。
- **`pkCentroid_resample.m`**: 画像1枚（1セグメント）について、リサンプルの有無×2手法の溝底検出結果を比較する検討用スクリプト。
- **`pkCentroid_interp2.m`**: 画像1枚について、元データ・リサンプル・内挿の溝底検出結果を比較する検討用スクリプト。
- **`darknessInterp2.m`**: 小領域画像を `interp2` で疑似高解像度化する動作確認用スクリプト。
- **`evaluation/stylus/sound_from_stylus.m`**: 針で再生した音源を切り出し・フィルタ処理し、復元音声と比較・評価する。

## 溝の選択（fitGroove）

`fitGroove(jSegment,fig,p2,w,h,pksCell,opts)` は、平行四辺形（左端の点`p1`・右端の点`p2`、高さ`h`）内にある溝底候補点を直線近似し、その傾きで`pksCell`の各要素を補正する。

- **複数データセットを1回で補正**: `pksCell`は`{pks_max, pks_cnt}`のように複数の溝底候補点データセットをまとめて渡せる。同じ溝に対して重心法・局所的最大値法を1回の選択（`ginput`1組）で両方補正できるため、手法ごとに別々にクリックする必要がない。戻り値`pksCorCell`も同じ順序・要素数の`cell`になる。
- **保存済みの点で自動選択**: `opts.P1`/`opts.P2`に既知の点（`(1,2)`の`[x,y]`）を渡すと、その点については`ginput`を呼ばず渡された値をそのまま使う。両方渡せば`ginput`だけでなく`figure`の作成・描画も一切行わない完全自動モードになるため、`fig`には`[]`を渡してよい（80セグメント分ループで無駄なfigureの生成/破棄をしなくて済む）。`P1`を省略した場合は従来通り（`jSegment==1`なら`ginput`、それ以外は引数の`p2`を`p1`として使う）。
- **p1,p2の保存と再利用**: 音声復元の実験（`_1cycle`スクリプト）でセグメントごとの`p1`,`p2`を`allP1`,`allP2`に蓄積し、`saveCycleResult`の`GrooveSelection=struct('p1',allP1,'p2',allP2)`で保存しておくと、`loadCycleResult`で読み込んだ`result.grooveSelection.p1`/`.p2`を次回の`fitGroove`呼び出しに`P1`/`P2`として渡すだけで、同じ溝を`ginput`なしで自動選択できる（抽出手法やパラメータだけを変えて再解析したい場合に便利）。

```matlab
% 手動選択（1回のginputで重心法・局所的最大値法の両方を補正）
[p1,p2,pksCorCell] = fitGroove(jSegment,fig,p2,w_prl,h_prl,{pks_max,pks_cnt});
pks_max_cor = pksCorCell{1}; pks_cnt_cor = pksCorCell{2};

% 以前の実験結果に保存したp1,p2を使って自動選択（ginput・figureともに不要）
prev = loadCycleResult(prevMatPath);
[p1,p2,pksCorCell] = fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_max,pks_cnt}, ...
    P1=prev.grooveSelection.p1(kImgSmall,:), P2=prev.grooveSelection.p2(kImgSmall,:));
```

1溝で複数検出された点を平均してから処理する旧版（`fitGroove_multiPeaks`）は現行の`fitGroove`には統合されておらず、`src/archive/fitGroove_multiPeaks.m`に参照用として残置している。

## 1周分の実験結果の保存

`fitGroove` の手動操作を80セグメント分繰り返す必要がある（`GrooveSelection`による自動選択を使わない場合）ため、1周分の解析は図を作るたびに再実行できない。そこで解析結果を `.mat` に保存し、図の作成スクリプトはそれを読むだけにする。

- 保存先は `experiments/<日付>/`。図・音声の出力先（`results/<日付>/`）とは分ける。
- **1ファイル = 1つの高解像度化条件**（`origD` / `rsmplD` / `intpD`）。1ファイルの中に重心法・局所的最大値法の両方の結果を入れる（`allImg` を手法ごとに二重保存しないため）。
- 保存される変数は `result`（struct）1つだけ。

```matlab
% 保存（1周分の解析の最後で実行）
dir    = mkdirFromDate(rootFolder, date);    % 図・音声の出力先
expDir = experimentDir(rootFolder, date);    % 実験結果.matの保存先

cond = cycleConditions( ...
    Upsampling="intpD", Date=date, SaveDir=dir, ExperimentDir=expDir, ...
    LMask=L_MASK, ThHist=TH_HIST, DThresh=D_THRESH, WTh=W_TH, ...
    Tol=tol, BinWidth=binWidth, HPrl=h_prl, ...
    QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, ...
    Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");

res_cnt = cycleMethodResult("centroid", allPts_cnt_intpD, xcoords, ycoords, y_comb, intpAudio);

matPath = saveCycleResult(cond, allImg, res_cnt);

% 読み込み（図の作成スクリプト）
matPath = cycleResultPath(rootFolder, "intpD", "0731");
result  = loadCycleResult(matPath);
figure; result.centroid.audio.spectrogramPlot(4096);
```

`ExperimentDir` を省略すると `SaveDir` に保存される（移行前の動作）。読み込み側の `cycleResultPath` は `experiments/<日付>/` を先に見て、無ければ `results/<日付>/` も探すので、古い場所に残っている結果もそのまま読める。

`result` の構成:

| フィールド | 内容 |
| --- | --- |
| `conditions` | 実験条件（`cycleConditions` の出力。定数・日付・保存先・高解像度化のパラメータ・画像ファイル名） |
| `meta` | 実行日時・スクリプト名・MATLAB版・gitコミット・ルートフォルダ |
| `allImg` | (TOTAL_SEGMENTS x 1) `ImageData` |
| `centroid` / `localMax` | `.pts` (N x 1 `GrooveCandidates`)、`.xcoords`、`.ycoords`（各 N x 1 cell）、`.y_comb`、`.audio` (1x1 `AudioData`) |
| `dValueFile` | `DarknessMap` を保存した.matのファイル名（未保存なら `""`） |
| `grooveSelection` | `fitGroove` で選んだ点。`.p1`、`.p2` とも (TOTAL_SEGMENTS x 2)（渡さなかった場合は空の (0 x 2)） |

`DarknessMap` の `dMat` は `origD` で約140MB、`rsmplD`(8x) で約1GB、`intpD`(step 0.25) で約2GBになるため、**既定では保存しない**。1セグメント分の `dMat` は `ginput` 無しで作り直せるので、通常は図の作成に不要。必要な場合は別ファイル（`..._dValue.mat`）に分けて保存する。

```matlab
[matPath, dPath] = saveCycleResult(cond, allImg, res_cnt, ...
    DarknessValues=allIntpD, SaveDarknessValues=true);
result = loadCycleResult(matPath, LoadDarknessValues=true);   % result.allD に入る
```

`fitGroove` で選んだ `p1`/`p2`（セグメントごとに1組、手法間で共通）も保存できる。次回以降は保存済みの点を `fitGroove` の `P1`/`P2` に渡せば `ginput` なしで同じ溝を自動選択できる（詳細は「溝の選択（fitGroove）」）。

```matlab
matPath = saveCycleResult(cond, allImg, res_cnt, GrooveSelection=struct('p1',allP1,'p2',allP2));
result  = loadCycleResult(matPath);   % result.grooveSelection.p1/.p2 に入る
```

既存の結果ファイルは既定では上書きせず `..._2.mat` のように連番を付けて保存する（`Overwrite=true` で上書き）。

## 基本的な使用方法

1. MATLABで **`Research.prj`** を開いてプロジェクトを起動します。
2. スクリプト先頭で以下を実行し、ルートフォルダを取得します。パス指定はこの `rootFolder` を基点に行ってください。
   ```matlab
   proj = currentProject;
   rootFolder = proj.RootFolder;
   ```
3. `scripts/` 内の目的に合ったスクリプト（例: `pkCentroid_interp2_1cycle.m`）を実行します。処理途中で `fitGroove` により溝中心をマウス（`ginput`）で指定する操作が必要です。
4. 生成された図・音声は `results/<日付>/` に、1周分の解析結果の`.mat`は `experiments/<日付>/` に保存されます。
