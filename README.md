# SPレコード音声復元プロジェクト

SPレコードの盤面写真から音溝（溝底）の形状を読み取り、音声を復元するためのMATLABプロジェクトです。

盤面画像の各列（x）について、輝度から求めた「暗さ」の分布をもとに溝底のy座標を検出し、その並びを1周分つなげて音声波形とします。溝底の検出には**重心法（centroid method）**と**局所的最大値法（local maximum method）**の2種類があり、解像度を上げる手法として**リサンプル**と**内挿（interp2）**を比較しています。

## 処理の流れ

1. 盤面画像（8分割撮影の8枚）を読み込み、各画像をさらに横方向に10分割して細長い画像（`img_small`）にする（計80セグメント）。
2. `omitMask` で左右の無効領域（マスク）を除去する。
3. `ImageData` → `DarknessMap` を作り、暗さ行列 `dMat = 1 - img/255` を得る。必要に応じて `dResample`（リサンプル）や `dInterp`（interp2内挿）で高解像度化する。
4. `DarknessMap` の `setDiffTF` でしきい値 `D_THRESH` を超える領域の立ち上がり／立ち下がりを求め、`GrooveExtractor` で各xの溝底候補の区間（`findThresholdIntervals`）と幅の狭い溝底区間（`findGrooveBottomIntervals`）を特定する。
5. `GrooveExtractor` の `extractByCentroid`（重心法）／`extractByLocalMax`（局所的最大値法）で溝底のy座標を求め、`GroovePointCloud` に格納する。
6. `fitGroove` で選択した平行四辺形内の点群を直線近似し、溝の傾きを補正する（詳細は「溝の選択（fitGroove）」）。
7. `findGrooveCenter` でヒストグラムのピークから追跡対象の溝1本を選び、`extractGrooveShape` でその中心付近（`Tolerance`／`TOL_DISTANCE`／`tol`）の点だけを抽出して欠損を `fillmissing` で補間し、`detrendGrooveShape` で多項式デトレンドする（3つをまとめて呼ぶ `extractGrooveWaveform` を使うのが基本）。`grooveTrack_1cycle.m` では、6・7の代わりに写真1枚ごとに `mergeSegmentPoints` → `trackGroove` → `detrendTrackedShape` を使う（詳細は「溝の自動追跡（trackGroove）」）。`grooveHist_Ncycle.m` では、さらに1回のクリックから内側の溝も含めて N 本を取り出し、N周分の音声を作る（`extractMultiGroove`。詳細は「複数本の溝の抽出（N周分）」）。
8. 全セグメントの座標を連結し、回転数78rpmから標本化周波数を計算して `AudioData` を生成、波形・FFT・スペクトログラムを描画・保存し、wavに書き出す。
9. `saveCycleResult` で実験条件と解析結果（`ImageData`／`GroovePointCloud`／`AudioData`／`y_comb` など）を `experiments/<日付>/` の `.mat` に保存する（詳細は「1周分の実験結果の保存」）。

## ディレクトリ構成

- **`Research.prj`**: MATLABプロジェクトファイル
- **`src/`**: クラス定義と共通関数（配線されていない旧コードは `archive/`）
- **`scripts/`**: 溝底抽出・音声生成の実行スクリプト群（旧版は `archive/`、針再生の評価は `evaluation/`）
- **`data/`**: 入力データ（`pictures/` は盤面写真、`stylus playback/` は針再生の音源）
- **`experiments/`**: 1周分の解析結果の`.mat`（日付ごと。旧版・失敗した試行は `archive/`）
- **`results/`**: 図・音声の出力先（日付ごと。原稿用の図は `figures/paper/<会議名>/`。図の置き場所と名前の付け方は [`docs/rules/figures.md`](docs/rules/figures.md)）
- **`test/`**: テストコード（`unit/` が `runAllTests` の対象。廃止したクラスのテストは `archive/`）

`experiments/` と `results/` は寿命が違うので分けている。`results/` の図・音声は `experiments/` の`.mat`から何度でも作り直せるが、`.mat` 自体は `fitGroove` の手動操作を80セグメント分やり直さないと作れない。**バックアップの対象は `data/` と `experiments/` の2つ**で、`results/` は消してよい。どちらもgit管理外。

## `src/` の主なクラス・関数

### クラス

- **`ImageData`**: 盤面画像（グレースケール行列）と幅・高さ・IDを保持。`showImage`（旧`showImg`。2026-08-19改名）で画像を表示。`clearImage()`で`img`だけ破棄した軽量コピーを作れる（`cycleResult`保存時に使用。「1周分の実験結果の保存」参照）。
- **`DarknessMap`**: 暗さ行列 `dMat` の保持・変換・表示を担うクラス。
  - `dResample(p,q)` / `dInterp(step,method)`: 解像度変換（リサンプル／内挿）
  - `setDiffTF(D_THRESH)`: しきい値超えの立ち上がり・立ち下がりを計算
  - `plotDarknessColumn(x)`: 列xの暗さ分布をプロット
- **`GrooveExtractor`**: `DarknessMap` から溝底候補点を抽出するクラス。`dMat`（最大約2GB）を複製しないよう、各メソッドは対象の `DarknessMap` インスタンスを引数として都度受け取る。
  - `findThresholdIntervals(map,x)` / `findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH)`: 溝底候補区間の特定（区間は `startIdxCells`/`endIdxCells` に保持）
  - `extractByCentroid(map,x)` / `extractByLocalMax(map,x)`: 重心法／局所的最大値法で溝底のy座標を算出
- **`GroovePointCloud`**（旧`GrooveCandidates`。2026-08-07改名）: 検出した溝底の点群（`peakCells`。旧`pksCell`。2026-08-18改名）を保持し、`showPoints` で散布図表示。
- **`AudioData`**: 復元音声を保持し、波形（`plotWaveform`。旧`audioPlot`）・FFT（`plotFFT`。旧`FFTPlot`）・スペクトログラム（`plotSpectrogram`。旧`spectrogramPlot`。いずれも2026-08-19改名）の描画、wav保存（`saveAudio`）、再生（`playAudio`）を行う。

上記はいずれも継承関係を持たない独立した値クラス。共通の抽象基底クラスだった`MediaData`は誰にも継承されず孤立していたため、`src/archive/MediaData.m`へ退避した（単体テストも`test/archive/`に移動済み）。

### 共通関数

- **`omitMask`**: 画像左右の無効領域を除去
- **`fitGroove`**: 手動（`ginput`）または保存済みの点（`P1`/`P2`）で選んだ平行四辺形内の点群を直線近似し、溝の傾きを補正する。複数の溝底候補点データセット（例: 重心法と局所的最大値法）を`cell`でまとめて渡すと、1回の選択で全データセットを補正できる（詳細は「溝の選択（fitGroove）」）
  - `src/archive/fitGroove_multiPeaks.m`: 旧版（1溝で複数検出された点を平均してから処理）。現行の`fitGroove`に統合されていないため参照用として残置
- **`findGrooveCenter`**: `fitGroove` で傾き補正済みの点群からy座標のヒストグラムを作り、前回選んだ中心（`prevCenter`）に最も近いピークを追跡対象の溝の中心として返す
- **`extractGrooveShape`**: 溝の中心から`Tolerance`以内の点をx座標全域のNaN埋め配列に展開し、`fillmissing`で欠損を線形補間する（分数刻みの`xQuery`にも`ismember`で対応）
- **`detrendGrooveShape`**: 点群のy座標に多項式（既定3次）をpolyfitして差し引き、平均を0にする
- **`extractGrooveWaveform`**: 上記3つを`findGrooveCenter`→`extractGrooveShape`→`detrendGrooveShape`の順に呼び出す合成関数。`scripts/pkCentroid_resample.m`は疎な点群（fillmissing前）だけが必要なため`findGrooveCenter`のみを直接使う
- **`mergeSegmentPoints`**: 写真1枚分（10セグメント）の`GroovePointCloud`の点群を、セグメントの幅の累積和だけxをずらして1つの`[x y]`に連結し、写真1枚分の`xQuery`と、セグメントごとの列の数`counts`・ずらし量`xOffsets`を返す（`QueryStep`で`intpD`の分数刻みの列も作れる）。詳細は「溝の自動追跡（trackGroove）」
- **`trackGroove`**: 写真1枚分の点群から、クリック位置を通る溝1本を左右に1列ずつ逐次追跡し、`xQuery`全体のy座標（欠損は線形補間）、点を採れた列`found`、`info`を返す。`fitGroove`＋`extractGrooveShape`の代わり。詳細は「溝の自動追跡（trackGroove）」
- **`detrendTrackedShape`**: 追跡した写真1枚分のy座標に多項式（既定9次）を`polyfit`の`[p,S,mu]`形式（xのセンタリング・スケーリング）であてはめて差し引き、平均を0にする。`detrendGrooveShape`の代わり（約4000列に高い次数をかけても警告が出ない）。2つ目の出力`trend`（`.p`・`.S`・`.mu`・`.degree`）は、あてはめた多項式で、複数本の溝を選ぶときに写真全体の点の傾きの補正に使う
- **`findGrooveCenters`**: 1本目の溝で傾きを補正した点群のyのヒストグラムから、`FirstCenter`（既定0）に最も近い山を1本目とし、yの小さい側（内側）へ続く N−1 個の山のビンの中心を返す。山が足りなければ`findGrooveCenters:notEnoughPeaks`、1本目の山が`MaxFirstOffset`より離れていれば`findGrooveCenters:firstPeakNotFound`。詳細は「複数本の溝の抽出（N周分）」
- **`extractGrooveBands`**: 補正後のyが各中心から±`Tolerance`の帯にある点を取り出し、補正前（元の画像）のyで`xQuery`全体に並べて欠損を線形補間する。同じ列に2点以上あれば中心に最も近い点を採る（`extractGrooveShape`はエラーになる）。点を採れた列`found`も返す
- **`extractMultiGroove`**: 写真1枚分の点群と1回のクリックから、N本の溝の形状を返す（`trackGroove`→`detrendTrackedShape`→`findGrooveCenters`→`extractGrooveBands`→溝ごとに`detrendTrackedShape`）。詳細は「複数本の溝の抽出（N周分）」
- **`trackingSeeds`**: cycleResultの`grooveSelection`から写真ごとの追跡の始点（8×2）を返す。新しい形式（`.seeds`）ならそれを、手動選択の古い形式（`.p1`が80×2）なら各写真の最初のセグメントの`p1`を返す
- **`createFigure`**: サイズ指定でfigureを作成
- **`saveFigure`**: 作業用・進捗用の図を png（と fig）で保存する。保存の前に `checkFigureName` で名前を確かめる。同じ名前のファイルがあれば保存せずにエラー（`saveFigure:fileExists`。`Overwrite=true` で上書き）
- **`saveSlideFigure`** / **`savePaperFigure`**: スライド用（png 300 dpi）・原稿用（pdf・png 600 dpi・fig）の図を、指定の大きさ[cm]にそろえて保存する。どちらも保存の前に `checkFigureName` で名前を確かめる
- **`checkFigureName`**: 図のファイル名が命名規則（[`docs/rules/figures.md`](docs/rules/figures.md)）に沿っているかを確かめ、外れていれば理由を返して警告（`checkFigureName:invalidName`）を出す。確かめるのは使える文字・語彙表の語・並び順・使わない語だけで、条件の書き漏れは確かめられない
- **`figureVocabulary`**: 図のファイル名に使う語の一覧（`figures.md` の語彙表と同じ内容。`FigureNameTest` が一致を確かめる）
- **`soundCheck`**: 波形・FFT・スペクトログラムをまとめて描画・保存
- **`mkdirFromDate`**: 図・音声の出力先 `results/<日付>/` を作成しパスを返す
- **`experimentDir`**: 実験結果`.mat`の保存先 `experiments/<日付>/` を作成しパスを返す（`Create=false` でパスを組むだけ）
- **`setDefaultIntrpr`**: 描画のインタプリタをLaTeXに設定
- **`cycleConditions`**: 1周分の音声を作成したときの実験条件（定数・日付・保存先・高解像度化のパラメータ）をstructにまとめる。必須の定数が欠けていればエラーになる
- **`cycleMethodResult`**: 溝底抽出手法1つ分の1周データ（`GroovePointCloud`配列・x/y座標・`y_comb`・`AudioData`）をstructにまとめる。要素数の整合性をここで検証する。N周分のときは`xcoords`・`ycoords`を (TOTAL_SEGMENTS × N) cell にする（j列目が j周目、`pts`は (TOTAL_SEGMENTS × 1) のまま）
- **`saveCycleResult`**: 上記2つをまとめて `experiments/<日付>/cycleResult_<条件>_<日付>.mat` に保存する（詳細は下記「1周分の実験結果の保存」）
- **`loadCycleResult`**: `saveCycleResult` で保存した結果を読み込む
- **`cycleResultFileName`**: 結果.matのファイル名の命名規則を返す（保存側・読み込み側で共有）
- **`cycleResultPath`**: 結果.matのフルパスを返す（読み込み側用。`experiments/<日付>/` を見て、無ければ移行前の `results/<日付>/` も探す）
- **`togglevisibility`**: 凡例クリックでプロットの表示/非表示を切り替えるコールバック

## `scripts/` の主なスクリプト

- **`pkCentroid_resample_1cycle.m`**: リサンプルしたデータに重心法を適用し、1周分の音声を生成する基本スクリプト。末尾で `saveCycleResult` により `cycleResult_rsmplD_<日付>.mat` を保存。
- **`pkCentroid_interp2_1cycle.m`**: 上記を内挿（`dInterp`）ベースに置き換えた版。1周分の音声を生成し、`cycleResult_intpD_<日付>.mat` を保存。
- **`grooveTrack_1cycle.m`**: 高解像度化していない画像で、写真1枚につき1回のクリックから溝1本を自動追跡し（`trackGroove`）、写真ごとに多項式デトレンド（`detrendTrackedShape`、9次）をかけて、重心法・局所的最大値法の1周分の音声を作る。`pkCentroid_1cycle.m`の`fitGroove`＋`extractGrooveWaveform`（1周80回の`ginput`）を置き換えたもの（1周8回）。`cycleResult_origD_track_<日付>.mat`を保存する。`PREV_RESULT_PATH`に以前の結果.matを指定すると、保存したクリック位置（または手動選択の`p1`）で`ginput`なしに再現する。`date`は`"MMDD"`のままだとエラーで止まるので、実行日に書き換える。詳細は「溝の自動追跡（trackGroove）」
- **`grooveHist_Ncycle.m`**: 写真1枚につき1回のクリックから`NUM_GROOVES`本（既定5）の溝を取り出し（`extractMultiGroove`。1本目は追跡、2本目以降はヒストグラムの山と帯）、重心法・局所的最大値法のN周分の音声を作る。`cycleResult_origD_hist<N>_<日付>.mat`を保存する。図は`grooveHist_img<i>.png`（N本の経路）・`grooveHist_histogram_img<i>.png`（補正後のyのヒストグラム）。`PREV_RESULT_PATH`の扱いと`date`は`grooveTrack_1cycle.m`と同じ。詳細は「複数本の溝の抽出（N周分）」
- **`grooveTrack_Ncycle.m`**: `grooveHist_Ncycle.m`を評価するための正解データを作る。写真ごとにN本をクリックし（8×N回の`ginput`）、それぞれを`trackGroove`→`detrendTrackedShape`で別々に追跡してN周分の音声を作り、`cycleResult_origD_track<N>_<日付>.mat`を保存する。図は`grooveTrackN_img<i>.png`。詳細は「複数本の溝の抽出（N周分）」
- **`pkCentroidAndLocalMax_resample_1cycle.m`**: 重心法と局所的最大値法、リサンプルの有無（計4パターン）で1周分の音声を作り比較。移動平均・移動中央値による平滑化や針再生との比較も含む。
- **`pkCentroid_resample.m`**: 画像1枚（1セグメント）について、リサンプルの有無×2手法の溝底検出結果を比較する検討用スクリプト。
- **`pkCentroid_interp2.m`**: 画像1枚について、元データ・リサンプル・内挿の溝底検出結果を比較する検討用スクリプト。
- **`darknessInterp2.m`**: 小領域画像を `interp2` で疑似高解像度化する動作確認用スクリプト。
- **`bilateral/bilateralOri_centroid.m`**: 高解像度化していない画像(`*-ori.png`)の1セグメントにバイラテラルフィルタ（`imbilatfilt`、カーネル3通り）をかけ、重心法の溝底点を画像上に表示する検討用スクリプト。
- **`bilateral/bilateralOriResample_centroid.m`**: 上記のフィルタ後に暗度の1次元リサンプル（`dResample`）を行ってから重心法を適用する版。
- **`bilateral/bilateralOriInterp2_centroid.m`**: 上記のフィルタ後に暗度の2次元内挿（`dInterp`、`step=0.125`・spline）を行ってから重心法を適用する版。
- **`bilateral/bilateral8x_centroid.m`**: Photoshopで8xに高解像度化した画像(`*-8x.png`)の一部にバイラテラルフィルタをかけ、重心法の溝底点を表示する版（画像が大きいため元画像座標で指定した窓を切り出して処理する）。
- **`bilateral/bilateralOri_centroid_1cycle.m`**: 高解像度化していない画像にバイラテラルフィルタ（カーネル3通り＋フィルタなし）をかけ、条件ごとに1周分の音声を重心法で作成して波形・FFT・スペクトログラムを比較する。溝の選択は過去の`cycleResult`の`grooveSelection`を再利用するので`ginput`は不要。動作確認用のため実験結果`.mat`は保存しない。
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

## 溝の自動追跡（trackGroove）

`fitGroove`はセグメントごとに平行四辺形を選ぶので、1周で80回の`ginput`が要る。`scripts/grooveTrack_1cycle.m`では、処理の流れの6・7（`fitGroove`→`findGrooveCenter`→`extractGrooveShape`→`detrendGrooveShape`）を、写真1枚（10セグメント）ごとに次の手順で置き換え、クリックを1周8回に減らしている（issue #25）。

1. `mergeSegmentPoints`で、写真1枚分の点群を横につなぐ（セグメントjの点のxに、それより左のセグメントの幅の合計を足す）。
2. 写真1枚分の画像の左端で、追跡する溝を1回クリックする（または保存した`seeds`を使う）。**クリックのyだけを使い、始点のxは写真の1列目に固定する**（`seed = [xQuery(1), y]`。`fitGroove`が平行四辺形の左端を`[1, p1(2)]`にしているのと同じ）。クリックしたxで始点の列が変わって追跡の再現性が下がるのを防ぐため。保存した`seeds`や手動選択の`p1`から再現するときも、保存されたxによらず同じ規則で1列目にする。
3. `trackGroove`で、始点から左右に1列ずつ追跡する（始点が1列目なので、実際には右向きだけになる）。重心法と局所的最大値法は、同じ始点から別々に追跡する。
4. `detrendTrackedShape`で写真ごとに多項式デトレンドし（既定9次、平均0）、`counts`でセグメントごとに分け直して、既存と同じ形の`ycoords`（80×1 cell）にする。写真どうしは、既存と同じく平均0にしたものをそのまま連結する。

`trackGroove(pks,seed,xQuery,opts)`の追跡のしかた：

- **初期化**：始点の列から右へ`InitLength`未満の列で、クリックのyに最も近い点（`SnapRadius`以内）を集め、その中央値を始点のyにする。クリックが少しずれても同じ溝から始まる。1点も無ければ`trackGroove:seedNotFound`でエラー。
- **追跡**：各列で、最後に採った点からx方向に`FitLength`未満の採用点に直線をあてはめて（5点未満なら最後の点のy）その列のyを予測し、予測から`Tolerance`以内で最も近い点を採る。窓の基準を「今の列」ではなく「最後に採った点」にしているので、`FitLength`より長い欠損の後でも、欠損の前の点で予測を続けられる。
- **欠損**：採れなかった列は`found=false`にし、`fillmissing(y,"linear")`で補間する。連続した欠損の長さ（欠損した列の数×列の間隔`median(diff(xQuery))`）が`MaxGapLength`を超えると`trackGroove:longGap`の警告を出す。

| 引数 | 既定値 | 意味 |
| --- | --- | --- |
| `Tolerance` | 2 | 予測位置から採る点までの最大距離（y方向）[px] |
| `FitLength` | 60 | 予測の直線あてはめに使う範囲（最後に採った点から）[px] |
| `SnapRadius` | 10 | 初期化でクリックのyから探す範囲 [px] |
| `InitLength` | 20 | 初期化に使う範囲（始点の列から右へ）[px] |
| `MaxGapLength` | 40 | これより長く欠損が続いたら警告する [px] |

**長さの引数はすべて元の画像のpxで指定する**（列の数ではない）。点群`[x y]`は高解像度化の有無によらず元の画像のpxで表されているので、`intpD`（`dInterp`で列の間隔が`step` pxになる）でも同じ値が溝に沿った同じ長さを表す。`mergeSegmentPoints`の`QueryStep`に`dInterp`の`step`を渡せば、`intpD`の列の並び（セグメントの中は`step`刻み、境目は1px）の`xQuery`が作れる。今の`grooveTrack_1cycle.m`は高解像度化なし（`QUERY_STEP = 1`）だけを扱う。

```matlab
ks = (iImg-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS);
[pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
[ptsCnt, foundCnt, infoCnt] = trackGroove(pksCnt, seed, xQuery, FitLength=60);
detCnt = detrendTrackedShape(ptsCnt, PolyDegree=9);
ycoords_cnt(ks) = mat2cell(detCnt(:,2), counts);

% 保存したクリック位置で再現する（新しい形式の seeds、または手動選択の p1）
prev  = loadCycleResult(prevMatPath);
seeds = trackingSeeds(prev.grooveSelection, NUM_SEGMENTS);   % (8 x 2)
seed  = [xQuery(1), seeds(iImg,2)];                          % xは1列目に固定し、yだけを使う
```

結果は`saveCycleResult(..., GrooveSelection=gs, FileName="cycleResult_origD_track_"+date)`で`experiments/<日付>/cycleResult_origD_track_<日付>.mat`に保存する（同じ日に手動選択の`cycleResult_origD_<日付>.mat`を作っても重ならない）。`centroid`/`localMax`の形は既存と同じなので、`ycoords`・`y_comb`・`audio`を読む比較スクリプトはそのまま使える。`grooveSelection`に足すフィールドは「1周分の実験結果の保存」の表を参照。読み込むときは`cycleResultPath`が`_track`に対応していないので、`fullfile(experimentDir(root,date,Create=false),"cycleResult_origD_track_"+date+".mat")`でパスを作る。追跡で使わない`cycleConditions`の必須の引数（`ThHist`・`BinWidth`・`HPrl`・`Tol`）は`NaN`になっている。

## 複数本の溝の抽出（N周分）

1周分（約0.77秒）では短いので、`scripts/grooveHist_Ncycle.m`では、写真1枚につき1回のクリックから N 本（`NUM_GROOVES`、既定5）の溝を取り出し、N周分の音声を作る（issue #30）。旧`scripts/archive/Ncycle_omitMask.m`のヒストグラムによる溝の選択を、今の処理の流れ（`mergeSegmentPoints`→`trackGroove`→`detrendTrackedShape`）に合わせて作り直したもの。写真1枚ごとに`extractMultiGroove`が次の手順を行う。

1. 1本目（クリックした溝）を`trackGroove`で追跡し、`detrendTrackedShape`で写真ごとに9次でデトレンドする（`grooveTrack_1cycle.m`と同じ。結果も同じになる）。
2. `detrendTrackedShape`の2つ目の出力（1本目の多項式`trend`）を写真全体の点から引き、傾きを補正する。1本目が y≈0 に水平になり、他の溝もほぼ水平に並ぶ。
3. `findGrooveCenters`で、補正後のyのヒストグラム（ビンの幅`BIN_WIDTH`）から、0に最も近い山を1本目とし、yの小さい側へ続く N−1 個の山を選ぶ。
4. `extractGrooveBands`で、各山の中心から±`BAND_TOL`の帯にある点を取り出し、補正前のyで並べて欠損を線形補間する。
5. 2本目以降も、溝ごとに`detrendTrackedShape`（9次）をかける（1本目・正解データと同じ前処理）。

重心法と局所的最大値法は、同じクリックから別々に処理する（ヒストグラムもそれぞれの点で作る）。

**溝の向きと並び**：y座標が小さい側（画像の上側）がレコードの内側。クリックする1本目は N 本の中で最も外側（最初に再生される）溝で、2本目以降はyの小さい側に並ぶ。スクリプトでは`shapesCnt{i,j}`（8×N cell、各`[xQuery, y]`）に「i枚目の写真のj本目の溝」を入れる。レコードは1周するごとに溝1本分内側へ進むので、j本目の写真8の次には j+1本目の写真1が続く。そのため、`vertcat(shapesCnt{:})`（列の順に連結）がそのまま再生順になる。保存は`counts`でセグメントごとに分けた 80×N の`ycoords`で、`y_comb = vertcat(ycoords{:})`も同じ再生順になる。この並びは、8枚の1本目のクリックが1本の溝を1周分たどっていることが前提。

| パラメータ | 値 | 根拠 |
| --- | --- | --- |
| `BIN_WIDTH` | 1 px | ビンの端が`BIN_WIDTH`の倍数にそろうので、ビンの中心と溝の中心のずれは最大で約`BIN_WIDTH/2`。1なら0.5px以下で、帯から点が落ちない（旧スクリプトの5では最大2.3pxずれ、1本で最大203点を落とした） |
| `TH_HIST_RATIO` | 0.3 | 山とみなす高さ（写真の列の数に対する割合）。1つの溝は1列に1点なので山の高さは列の数に比例し、高解像度化しても同じ値を使える。実データでは0.20〜0.45倍なら8枚とも同じ山を選ぶ（溝の間の偽の山は最大0.19倍） |
| `BAND_TOL` | 3 px | 帯の半分の幅。実データで、帯から落ちる点・同じ列の2点が0。正解データの作り方と64本中63本が完全に一致した |
| `POLY_DEGREE` | 9 | すべての溝で同じ（写真ごと） |
| `AMP_DIV` | 1.5 px | 振幅の正規化（`grooveTrack_1cycle.m`と同じ）。±1を超えたサンプルの数を表示する |

```matlab
[pksCnt, xQuery, counts] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
seed = [xQuery(1), y];                                   % xは1列目に固定し、yだけを使う
[shapesCnt(iImg,:), infoCnt] = extractMultiGroove(pksCnt, seed, xQuery, NUM_GROOVES, ...
    PolyDegree=9, BinWidth=1, MinPeakRatio=0.3, BandTolerance=3);
for j = 1:NUM_GROOVES
    ycoords_cnt(ks, j) = mat2cell(shapesCnt{iImg,j}(:,2), counts);   % 80 x N
end
y_comb_cnt = vertcat(ycoords_cnt{:});                    % N周分（再生順）
```

1本目より内側に N−1 個の山が無い（内側の溝が画像の上端に近いなど）ときは`findGrooveCenters:notEnoughPeaks`で止まり、スクリプトは写真の番号と手法を書いた`grooveHist_Ncycle:grooveSelectionFailed`に包んで出し直す。結果は`experiments/<日付>/cycleResult_origD_hist<N>_<日付>.mat`に保存する。`cycleConditions`の`BinWidth`・`Tol`は実際の値、`ThHist`・`HPrl`は`NaN`（しきい値は割合になり旧`ThHist`と意味が違うので`grooveSelection.multiGroove.thHistRatio`に入れる）。読み込むときは`fullfile(experimentDir(root,date,Create=false),"cycleResult_origD_hist5_"+date+".mat")`でパスを作る。

**正解データ（`scripts/grooveTrack_Ncycle.m`）**：評価のため、写真ごとに N 本をクリックし、それぞれを`trackGroove`→`detrendTrackedShape`で別々に追跡したものを作る。

- 写真ごとに、左端`CLICK_VIEW_WIDTH`（300px）を拡大した図で`ginput(NUM_GROOVES)`を1回行う。クリックはyの大きい順（外側から）に並べ替えて1本目〜N本目にする（クリックの順によらない）。`trackGroove`の始点の初期化は1列目から20pxの範囲だけを見るので、左端の近くをクリックする。
- 隣どうしの始点の差が`MIN_SEED_GAP`（13px）より小さいと`grooveTrack_Ncycle:sameGroove`、差の中央値の1.5倍を超えると`grooveTrack_Ncycle:grooveSkipped`の警告を出す。図（`grooveTrackN_img<i>.png`）で、N本とも隣の溝に飛び移っていないかを確かめる。
- `GUIDE_RESULT_PATH`に以前の結果（例：`experiments/1014/cycleResult_origD_track_1014.mat`）を指定すると、その1本目の始点のyをクリックの図に黄色の三角で示す（1本目を#25と同じ溝にするため）。
- `PREV_RESULT_PATH`に以前の正解データを指定すると、保存した`multiGroove.seedsY`で`ginput`なしに再現する。`RECLICK_IMAGES`（例：`[3 7]`）に書いた写真だけ、もう一度クリックする（飛び移りがあった写真だけ直すため。`saveCycleResult`の`Overwrite=false`で`_2`付きの別のファイルになる）。
- `grooveSelection.seeds`には1本目のクリック`[1, seedsY(:,1)]`を入れるので、`grooveHist_Ncycle.m`・`grooveTrack_1cycle.m`の`PREV_RESULT_PATH`にこのファイルを指定すれば、同じ1本目から再現できる。

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
figure; result.centroid.audio.plotSpectrogram(4096);
```

`ExperimentDir` を省略すると `SaveDir` に保存される（移行前の動作）。読み込み側の `cycleResultPath` は `experiments/<日付>/` を先に見て、無ければ `results/<日付>/` も探すので、古い場所に残っている結果もそのまま読める。

`result` の構成:

| フィールド | 内容 |
| --- | --- |
| `conditions` | 実験条件（`cycleConditions` の出力。定数・日付・保存先・高解像度化のパラメータ・画像ファイル名） |
| `meta` | 実行日時・スクリプト名・MATLAB版・gitコミット・ルートフォルダ |
| `allImg` | (TOTAL_SEGMENTS x 1) `ImageData`（`.img`は保存しない。下記参照） |
| `centroid` / `localMax` | `.pts` (N x 1 `GroovePointCloud`)、`.xcoords`、`.ycoords`（各 N x 1 cell）、`.y_comb`、`.audio` (1x1 `AudioData`)。N周分の結果（`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`）では `.xcoords`・`.ycoords` が (N x 周の数) cell（j列目が j周目）で、`.y_comb`・`.audio` は全周分。線形インデックスの `ycoords{k}`（k=1〜80）は1周目を指す。`numel(ycoords)` を80とみなすコード（`compareTrackingToManual.m` など）はN周分のファイルには使えない |
| `dValueFile` | `DarknessMap` を保存した.matのファイル名（未保存なら `""`） |
| `grooveSelection` | `fitGroove` で選んだ点。`.p1`、`.p2` とも (TOTAL_SEGMENTS x 2)（渡さなかった場合は空の (0 x 2)）。自動追跡（`grooveTrack_1cycle.m`）の結果では、`.p1`/`.p2` は追跡した重心法の経路（補間済み・デトレンド前）の各セグメントの左端・右端の点で、さらに `.method`（`"tracking"`。無ければ手動選択）、`.seeds`（8×2、写真ごとの追跡の始点 `[x y]`。xは写真の1列目に固定、yはクリック位置。2026-10-26より前に作ったファイルでは、xにクリックしたxがそのまま入っている）、`.tracking`（追跡のパラメータ `tolerance`・`fitLength`・`snapRadius`・`initLength`・`maxGapLength`・`minFitPoints`・`queryStep`・`polyDegree`・`detrendScope`・`ampDivisor`（長さは元の画像のpx）と、写真ごとのデトレンド前のy座標 `yAbsCnt`/`yAbsMax`・点を採れた列 `foundCnt`/`foundMax`（8×1 cell））を持つ。N周分の結果では、`.p1`/`.p2`・`.seeds`・`.tracking` は1本目（1周目）のもので、さらに `.multiGroove` を持つ。`grooveHist_Ncycle.m`（`.method = "histogram"`）では `numGrooves`・`binWidth`・`thHistRatio`・`bandTol`・`polyDegree`・`detrendScope`・`ampDivisor`、写真×溝ごとの補正後の山の中心 `centersCnt`/`centersMax`（8×N）、デトレンド前・補間済みのy `yAbsCnt`/`yAbsMax`・点を採れた列 `foundCnt`/`foundMax`（8×N cell）、帯の中に2点以上あった列の数 `numDupCnt`/`numDupMax`（8×N）、1本目の多項式 `trendCnt`/`trendMax`（8×1 cell）。`grooveTrack_Ncycle.m`（`.method = "tracking"`）では `numGrooves`、クリックのy `seedsY`（8×N、各行は大きい順）、`trackGroove` の始点 `y0Cnt`/`y0Max`（8×N）、`minSeedGap`・`polyDegree`・`detrendScope`・`ampDivisor`、`yAbsCnt`/`yAbsMax`・`foundCnt`/`foundMax`（8×N cell） |

`DarknessMap` の `dMat` は `origD` で約140MB、`rsmplD`(8x) で約1GB、`intpD`(step 0.25) で約2GBになるため、**既定では保存しない**。1セグメント分の `dMat` は `ginput` 無しで作り直せるので、通常は図の作成に不要。必要な場合は別ファイル（`..._dValue.mat`）に分けて保存する。

`ImageData` の `img`（画素データ）も同じ理由（80セグメント分で数百MBになる）で`allImg`には**保存しない**（`imgID`/`width`/`height`は残る）。必要な撮影画像（`iImg`）だけ、元のPNGファイルから`reconstructImage(conditions,iImg)`で作り直せる。`allImg`をまとめて再構成すると再びメモリを圧迫するため、`iImg`単位（撮影1枚＝`NumSegments`セグメント分）で呼び出すこと。撮影画像ファイルがカレントフォルダに無い場合は`PhotoDir`オプションでフォルダを指定する。

```matlab
result = loadCycleResult(matPath);
imgs = reconstructImage(result.conditions, 3);   % iImg=3 の全セグメント分
imgData = imgs(jSegment);                        % 特定のセグメントだけ使う
```

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
