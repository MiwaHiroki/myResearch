# SPレコード音声復元プロジェクト

SPレコードの盤面写真から音溝（溝底）の形状を読み取り、音声を復元するためのMATLABプロジェクトです。

盤面画像の各列（x）について、輝度から求めた「暗さ」の分布をもとに溝底のy座標を検出し、その並びを1周分つなげて音声波形とします。溝底の検出には**重心法（centroid method）**と**局所的最大値法（local maximum method）**の2種類があり、解像度を上げる手法として**リサンプル**と**内挿（interp2）**を比較しています。

## 処理の流れ

1. 盤面画像（8分割撮影の8枚）を読み込み、各画像をさらに横方向に10分割して細長い画像（`img_small`）にする（計80セグメント）。
2. `omitMask` で左右の無効領域（マスク）を除去する。
3. `ImageData` → `DarknessMap` を作り、暗さ行列 `dMat = 1 - img/255` を得る。必要に応じて `dResample`（リサンプル）や `dInterp`（interp2内挿）で高解像度化する。
4. `DarknessMap` の `setDiffTF` でしきい値 `D_THRESH` を超える領域の立ち上がり／立ち下がりを求め、`GrooveExtractor` で各xの溝底候補の区間（`findThresholdIntervals`）と幅の狭い溝底区間（`findGrooveBottomIntervals`）を特定する。溝底区間とみなす幅（最後の行 − 最初の行）の上限 `WIDTH_THRESH` は、自動追跡の3つのスクリプト（`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`）では 4 px、従来法のスクリプト（`pkCentroid_1cycle.m` など）では 8 px である（理由は「溝の自動追跡（trackGroove）」の「溝底区間の幅の上限」）。
5. `GrooveExtractor` の `extractByCentroid`（重心法）／`extractByLocalMax`（局所的最大値法）で溝底のy座標を求め、`GroovePointCloud` に格納する。
6. `fitGroove` で選択した平行四辺形内の点群を直線近似し、溝の傾きを補正する（詳細は「溝の選択（fitGroove）」）。
7. `findGrooveCenter` でヒストグラムのピークから追跡対象の溝1本を選び、`extractGrooveShape` でその中心付近（`Tolerance`／`TOL_DISTANCE`／`tol`）の点だけを抽出して欠損を `fillmissing` で補間し、`detrendGrooveShape` で多項式デトレンドする（3つをまとめて呼ぶ `extractGrooveWaveform` を使うのが基本）。`grooveTrack_1cycle.m` では、6・7の代わりに写真1枚ごとに `mergeSegmentPoints` → `trackGroove` → `detrendTrackedShape` を使う（詳細は「溝の自動追跡（trackGroove）」）。`grooveHist_Ncycle.m` では、さらに1回のクリックから内側の溝も含めて N 本を取り出し、N周分の音声を作る（`extractMultiGroove`。詳細は「複数本の溝の抽出（N周分）」）。
8. 全セグメントの座標を連結し、回転数78rpmから標本化周波数を計算して `AudioData` を生成、波形・FFT・スペクトログラムを描画・保存し、wavに書き出す。
9. `saveCycleResult` で実験条件と解析結果（`ImageData`／`GroovePointCloud`／`AudioData`／`y_comb` など）を `experiments/<日付>/` の `.mat` に保存する（詳細は「1周分の実験結果の保存」）。

## ディレクトリ構成

- **`Research.prj`**: MATLABプロジェクトファイル
- **`src/`**: クラス定義と共通関数（配線されていない旧コードは `archive/`）
- **`scripts/`**: 溝底抽出・音声生成の実行スクリプト群（旧版は `archive/`、評価は `evaluation/`、図は `paper/<発表名>/`・`slides/<発表名>/`・`progress/`、古い結果のフォルダの移行は `migration/`）
- **`data/`**: 入力データ（`pictures/` は盤面写真、`stylus playback/` は針再生の音源）
- **`experiments/`**: 1周分の解析結果の`.mat`（`YYYY-MMDD` の日付ごと。旧版・失敗した試行は `archive/`）
- **`results/`**: 図・音声の出力先。実験の出力は実験名と実行した日のフォルダ `results/<実験名>/<YYYY-MMDD>[_<説明>]/`（実行フォルダ）に、完成した図は `results/figures/` に置く（詳細は「結果の置き場所と実行記録」。図の置き場所と名前の付け方は [`docs/rules/figures.md`](docs/rules/figures.md)）
  - 図のスクリプトは `scripts/<用途>/<発表名>/`（例：`scripts/paper/202609asj/`）に置き、図は `results/figures/<発表名>/<用途>/`（例：`results/figures/202609asj/paper/`）に出る。スクリプトと図とで、用途と発表名の階層の順が逆になる（スクリプトの置き場所は変えず、図だけを発表名ごとにまとめたため。issue #28）。進捗報告用は、どちらも `progress/` の下にある。
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
- **`resultDir`**: 実行フォルダ `results/<実験名>/<YYYY-MMDD>[_<説明>]/` を作り、実行記録 `runInfo.json` を書いて、そのパス（末尾に区切り文字が付く）を返す。同じ名前のフォルダがあれば `_2`、`_3`… を付けて警告（`resultDir:folderExists`）し、日付が `"YYYY-MMDD"` のままならエラー（`resultDir:dateNotSet`）で止める。詳細は「結果の置き場所と実行記録」
- **`runConditions`**: スクリプトの冒頭の定数を、実験条件の決まった入れ子の struct（`runInfo.json` の `conditions` と同じ形）にまとめる。出力は `resultDir` と、1周分のスクリプトでは `cycleConditions` にも渡す
- **`figureDir`**: 完成した図の置き場所（進捗報告用は `results/figures/progress/<テーマ>/`、スライド用・原稿用は `results/figures/<発表名>/{slides,paper}/`）を作り、パスを返す（末尾に区切り文字は付けない）。発表名が「年月6桁と略称」の形でなければエラー（`figureDir:invalidVenue`）
- **`collectMeta`** / **`gitState`**: 実行した環境（日時・スクリプト名・MATLAB の版・PC の名前・git のコミット・未コミットの変更の有無・ブランチ）を集める。`saveCycleResult`（cycleResult の `meta`）と `resultDir`（`runInfo.json` の `meta`）が使う。git が無い場所でもエラーにならない
- **`mkdirFromDate`**: 古い形の出力先 `results/<日付>/` を作成しパスを返す。新しいコードでは `resultDir` を使う（`scripts/archive/` の古いスクリプトが使うので残している）
- **`experimentDir`**: 実験結果`.mat`の保存先 `experiments/<日付>/` を作成しパスを返す（`Create=false` でパスを組むだけ）
- **`setDefaultIntrpr`**: 描画のインタプリタをLaTeXに設定
- **`cycleConditions`**: 1周分の音声を作成したときの実験条件（定数・日付・保存先・高解像度化のパラメータ）をstructにまとめる。必須の定数が欠けていればエラーになる。`runConditions` の出力を受け取る呼び方（`cycleConditions(runCond, Date=..., SaveDir=..., ...)`。実行ごとに変わるものだけを name-value で渡す）と、すべてを name-value で渡す今までの呼び方があり、どちらでも同じ struct になる
- **`cycleMethodResult`**: 溝底抽出手法1つ分の1周データ（`GroovePointCloud`配列・x/y座標・`y_comb`・`AudioData`）をstructにまとめる。要素数の整合性をここで検証する。N周分のときは`xcoords`・`ycoords`を (TOTAL_SEGMENTS × N) cell にする（j列目が j周目、`pts`は (TOTAL_SEGMENTS × 1) のまま）
- **`saveCycleResult`**: 上記2つをまとめて `experiments/<日付>/cycleResult_<条件>_<日付>.mat` に保存する（詳細は下記「1周分の実験結果の保存」）
- **`loadCycleResult`**: `saveCycleResult` で保存した結果を読み込む
- **`cycleResultFileName`**: 結果.matのファイル名の命名規則を返す（保存側・読み込み側で共有）
- **`cycleResultPath`**: 結果.matのフルパスを返す（読み込み側用。`experiments/<日付>/` を見て、無ければ移行前の置き場所（`results/` の直下の日付のフォルダ）も探す）
- **`togglevisibility`**: 凡例クリックでプロットの表示/非表示を切り替えるコールバック

## `scripts/` の主なスクリプト

- **`pkCentroid_resample_1cycle.m`**: リサンプルしたデータに重心法を適用し、1周分の音声を生成する基本スクリプト。末尾で `saveCycleResult` により `cycleResult_rsmplD_<日付>.mat` を保存。
- **`pkCentroid_interp2_1cycle.m`**: 上記を内挿（`dInterp`）ベースに置き換えた版。1周分の音声を生成し、`cycleResult_intpD_<日付>.mat` を保存。
- **`grooveTrack_1cycle.m`**: 高解像度化していない画像で、写真1枚につき1回のクリックから溝1本を自動追跡し（`trackGroove`）、写真ごとに多項式デトレンド（`detrendTrackedShape`、9次）をかけて、重心法・局所的最大値法の1周分の音声を作る。`pkCentroid_1cycle.m`の`fitGroove`＋`extractGrooveWaveform`（1周80回の`ginput`）を置き換えたもの（1周8回）。`cycleResult_origD_track_<日付>.mat`を保存する。`PREV_RESULT_PATH`に以前の結果.matを指定すると、保存したクリック位置（または手動選択の`p1`）で`ginput`なしに再現する。`date`は`"YYYY-MMDD"`のままだと`resultDir`がエラーで止めるので、実行した日（`"2026-1124"`の形）に書き換える。図・音声は実行フォルダ`results/grooveTracking/<YYYY-MMDD>/`に出る。溝底区間の幅の上限`WIDTH_THRESH`は4 pxで、`pkCentroid_1cycle.m`の8 pxより狭い（issue #35）。詳細は「溝の自動追跡（trackGroove）」
- **`grooveHist_Ncycle.m`**: 写真1枚につき1回のクリックから`NUM_GROOVES`本（既定5）の溝を取り出し（`extractMultiGroove`。1本目は追跡、2本目以降はヒストグラムの山と帯）、重心法・局所的最大値法のN周分の音声を作る。`cycleResult_origD_hist<N>_<日付>.mat`を保存する。図は`grooveHist_img<i>.png`（N本の経路）・`grooveHist_histogram_img<i>.png`（補正後のyのヒストグラム）。`PREV_RESULT_PATH`の扱い、`date`、溝底区間の幅の上限（4 px）は`grooveTrack_1cycle.m`と同じ。図・音声は実行フォルダ`results/multiGroove/<YYYY-MMDD>/`に出る。詳細は「複数本の溝の抽出（N周分）」
- **`grooveTrack_Ncycle.m`**: `grooveHist_Ncycle.m`を評価するための正解データを作る。写真ごとにN本をクリックし（8×N回の`ginput`）、それぞれを`trackGroove`→`detrendTrackedShape`で別々に追跡してN周分の音声を作り、`cycleResult_origD_track<N>_<日付>.mat`を保存する。図は`grooveTrackN_img<i>.png`。溝底区間の幅の上限（4 px）は`grooveTrack_1cycle.m`と同じ。詳細は「複数本の溝の抽出（N周分）」
- **`pkCentroidAndLocalMax_resample_1cycle.m`**: 重心法と局所的最大値法、リサンプルの有無（計4パターン）で1周分の音声を作り比較。移動平均・移動中央値による平滑化や針再生との比較も含む。
- **`pkCentroid_resample.m`**: 画像1枚（1セグメント）について、リサンプルの有無×2手法の溝底検出結果を比較する検討用スクリプト。
- **`pkCentroid_interp2.m`**: 画像1枚について、元データ・リサンプル・内挿の溝底検出結果を比較する検討用スクリプト。
- **`darknessInterp2.m`**: 小領域画像を `interp2` で疑似高解像度化する動作確認用スクリプト。
- **`bilateral/bilateralOri_centroid.m`**: 高解像度化していない画像(`*-ori.png`)の1セグメントにバイラテラルフィルタ（`imbilatfilt`、カーネル3通り）をかけ、重心法の溝底点を画像上に表示する検討用スクリプト。
- **`bilateral/bilateralOriResample_centroid.m`**: 上記のフィルタ後に暗度の1次元リサンプル（`dResample`）を行ってから重心法を適用する版。
- **`bilateral/bilateralOriInterp2_centroid.m`**: 上記のフィルタ後に暗度の2次元内挿（`dInterp`、`step=0.125`・spline）を行ってから重心法を適用する版。
- **`bilateral/bilateral8x_centroid.m`**: Photoshopで8xに高解像度化した画像(`*-8x.png`)の一部にバイラテラルフィルタをかけ、重心法の溝底点を表示する版（画像が大きいため元画像座標で指定した窓を切り出して処理する）。
- **`bilateral/bilateralOri_centroid_1cycle.m`**: 高解像度化していない画像にバイラテラルフィルタ（カーネル3通り＋フィルタなし）をかけ、条件ごとに1周分の音声を重心法で作成して波形・FFT・スペクトログラムを比較する。溝の選択は過去の`cycleResult`の`grooveSelection`を再利用するので`ginput`は不要。動作確認用のため実験結果`.mat`は保存しない。図・音声は実行フォルダ`results/bilateralFilter/<YYYY-MMDD>_1cycle/`に出る（1セグメントの4本は、説明が`ori`・`oriRsmpl`・`oriIntp`・`photoshop8x`の実行フォルダに出る）。
- **`evaluation/stylus/sound_from_stylus.m`**: 針で再生した音源を切り出し・フィルタ処理し、復元音声と比較・評価する。
- **`migration/migrateResults.m`**: 対応表（CSV）を1行ずつ読み、日付だけの名前の古い形の `results/`・`experiments/` のフォルダとファイルを、新しい形の名前（「結果の置き場所と実行記録」）へ移す関数（issue #28）。既定は試し（`DryRun=true`）で、移す内容を表にして返すだけで、何も動かさない。全部の行を先に確かめ、行き先にすでにあるものがあれば何も動かさずに止める。移し終えた行は飛ばすので、途中で止まっても、もう一度呼べば続きを移せる。`scripts/migration/` は MATLAB プロジェクトのパスに入っていないので、`addpath` してから呼ぶ。
- **`evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`**: 溝底の判定で境界値を含めない（`exclBound`：`D > D_THRESH`・幅 `< W_TH`。コミット`ad46b44`（2026-08-14）より前のコードで、0731のデータはこれで作った）か、含める（`inclBound`：`D >= D_THRESH`・幅 `<= W_TH`。今の`DarknessMap`・`GrooveExtractor`）かで、写真1枚の溝底点（重心法）がどう変わるかを数え、片方だけにある点の色を変えて写真全体と1区間に重ねた図を実行フォルダ`results/grooveBottomDetection/<YYYY-MMDD>_evaluation/`に保存する。`exclBound`の判定は今の`src/`に無いので、スクリプトのローカル関数で書き直している。`inclBound`の点が保存済みのcycleResultの点と一致することも確かめる。

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

**溝底区間の幅の上限**：自動追跡の3つのスクリプト（`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`）は、幅が 4 px を超える溝底区間から溝底点を作らない（`WIDTH_THRESH = 4`。issue #35）。従来法の`pkCentroid_1cycle.m`などの 8 px より狭い。重心法と局所的最大値法の両方に、同じ上限を使う。ここで溝底区間は、各列で暗さが`D_THRESH`以上の行が続く範囲で、幅はその最後の行 − 最初の行である。

- 理由
  - 溝底の暗い線のすぐ隣に、暗さがしきい値すれすれの行が続いていることがある。この行は、溝の斜面と考えられる所である。
  - この行がしきい値をわずかに上回ると、溝底区間がそこまでつながり、幅が 5 px 以上になる。つまり、溝の斜面と考えられる所が、溝底として検出される。
  - 重心法では、しきい値すれすれの行も溝底の行とほぼ同じ重みで効く。そのため、溝底点が溝底の線から 1〜2 px ずれる。
  - 追跡が許す範囲（`Tolerance`の 2 px）も、2本目以降を取り出す帯（±3 px）も、このずれより広い。そのため、ずれた点が選ばれ、正規化した振幅が 1 付近の外れ値（クリックのような音）になっていた。
  - 1104 の5周分のデータでは、前後21列の中央値から 1 px を超えてずれた点が26点あり、すべて幅 5 px 以上の点だった。上限を 4 px にすると、こうした点は無くなった。
- 欠点
  - 溝底区間が広く、かつ取り出した点が正しく溝底の上にあるときも、その点を溝底点にせず、前後の列からの補間に置き換えてしまう場合がある。1104 では、幅 5 px 以上で外れ値でない78点が補間に置き換わった（y の変化の中央値 0.45 px）。暗さがしきい値以上の範囲を溝底とするこの方法では、避けられない部分である。
  - ほかのレコードや撮影条件で、溝底の線そのものが幅 5 px 以上になると、溝底点が大量に消える。そのときは`trackGroove:longGap`の警告が出るので、上限を見直す。

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
- `GUIDE_RESULT_PATH`に以前の結果（例：`experiments/2026-1014/cycleResult_origD_track_2026-1014.mat`）を指定すると、その1本目の始点のyをクリックの図に黄色の三角で示す（1本目を#25と同じ溝にするため）。
- `PREV_RESULT_PATH`に以前の正解データを指定すると、保存した`multiGroove.seedsY`で`ginput`なしに再現する。`RECLICK_IMAGES`（例：`[3 7]`）に書いた写真だけ、もう一度クリックする（飛び移りがあった写真だけ直すため。`saveCycleResult`の`Overwrite=false`で`_2`付きの別のファイルになる）。
- `grooveSelection.seeds`には1本目のクリック`[1, seedsY(:,1)]`を入れるので、`grooveHist_Ncycle.m`・`grooveTrack_1cycle.m`の`PREV_RESULT_PATH`にこのファイルを指定すれば、同じ1本目から再現できる。

## 1周分の実験結果の保存

`fitGroove` の手動操作を80セグメント分繰り返す必要がある（`GrooveSelection`による自動選択を使わない場合）ため、1周分の解析は図を作るたびに再実行できない。そこで解析結果を `.mat` に保存し、図の作成スクリプトはそれを読むだけにする。

- 保存先は `experiments/<YYYY-MMDD>/`。図・音声の出力先（実行フォルダ `results/<実験名>/<YYYY-MMDD>[_<説明>]/`。「結果の置き場所と実行記録」）とは分ける。
- **1ファイル = 1つの高解像度化条件**（`origD` / `rsmplD` / `intpD`）。1ファイルの中に重心法・局所的最大値法の両方の結果を入れる（`allImg` を手法ごとに二重保存しないため）。
- 保存される変数は `result`（struct）1つだけ。

```matlab
% スクリプトの冒頭：実験条件をまとめ、出力先を作る（「結果の置き場所と実行記録」）
runCond = runConditions(NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, LMask=L_MASK, ...
    Upsampling="intpD", QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD, ...
    Methods=["centroid","localMax"], DThresh=D_THRESH, WidthThresh=WIDTH_THRESH, ...
    Selection="manual", ReplayFrom=PREV_RESULT_PATH, ...
    Manual=struct(thHist=TH_HIST, tol=tol, binWidth=binWidth, hPrl=h_prl));
dir    = resultDir(rootFolder, EXPERIMENT_NAME, date, runCond, Label=LABEL, ...
    ScriptName="pkCentroid_interp2_1cycle", Images=filenames_new, InputFiles=PREV_RESULT_PATH);   % 図・音声の出力先
expDir = experimentDir(rootFolder, date);    % 実験結果.matの保存先

% 保存（1周分の解析の最後で実行）。実験条件は runCond から写し、実行ごとに変わるものだけを渡す
cond = cycleConditions(runCond, Date=date, SaveDir=dir, ExperimentDir=expDir, ...
    Filenames=filenames_new, ScriptName="pkCentroid_interp2_1cycle");

res_cnt = cycleMethodResult("centroid", allPts_cnt_intpD, xcoords, ycoords, y_comb, intpAudio);

matPath = saveCycleResult(cond, allImg, res_cnt);

% 読み込み（図の作成スクリプト）
matPath = cycleResultPath(rootFolder, "intpD", "2026-0731");
result  = loadCycleResult(matPath);
figure; result.centroid.audio.plotSpectrogram(4096);
```

`ExperimentDir` を省略すると `SaveDir` に保存される（移行前の動作）。読み込み側の `cycleResultPath` は `experiments/<日付>/` を先に見て、無ければ移行前の置き場所（`results/` の直下の日付のフォルダ）も探すので、古い場所に残っている結果もそのまま読める。

`experiments/` の日付のフォルダとファイル名の日付は、`2026-0731` のように年を付けた `YYYY-MMDD` の形である（issue #28 で改名した。古い名前との対応は「結果の置き場所と実行記録」の「対応表」）。改名の前に保存したファイルの中の `conditions.date` は、`"0731"` のように4桁のまま残っている。

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

## 結果の置き場所と実行記録

実験の図・音声は、実験名と実行した日で名前を付けたフォルダに出力する。フォルダ名を見れば、いつ・何の実験かが分かるようにするためである。出力先を作るときには、読んだ入力と実験条件を書いた実行記録も自動で残す。どのスクリプト・コード・入力・条件で作ったかを、後からたどれるようにするためである（issue #28）。

### 言葉

- **実験名**：研究上の問い（何を試して比べたか）ごとに付ける、英語の camelCase の名前（例：`grooveTracking`）。`results/` の直下のフォルダ名になる。
- **実行フォルダ**：スクリプトを1回実行したときの出力を置くフォルダ。`results/<実験名>/<YYYY-MMDD>[_<説明>[_<詳細>]][_<N>]/` の形にする。
- **説明**：実行フォルダの日付の後ろに付ける、短い英語の camelCase の語（例：`evaluation`）。付けなくてもよい。
- **実行記録**：実行フォルダに置く `runInfo.json`。何の実行か、読んだ入力、実験条件、実行した環境を書く。
- **実験条件**：処理のしかたを決めるパラメータ（使う画像、高解像度化の方法、溝底の検出のしきい値、溝の選び方、デトレンドの次数など）。

### 置き場所

```
results/<実験名>/<YYYY-MMDD>[_<説明>[_<詳細>]][_<N>]/       実行フォルダ（図・音声と runInfo.json）
    例: results/grooveTracking/2026-1014_evaluation/
        results/bilateralFilter/2026-0924_1cycle/
experiments/<YYYY-MMDD>/cycleResult_<条件>_<YYYY-MMDD>.mat    1周分の実験結果（日付ごとに分ける形は今までと同じ）
results/figures/progress/<テーマ>/                           進捗報告用の図（git で追跡する）
results/figures/<発表名>/slides/                             スライド用の図（git で追跡する）
results/figures/<発表名>/paper/                              原稿用の図（git では追跡しない）
```

- 実行フォルダは `resultDir` が作る。`experiments/` の日付のフォルダは、今までと同じく `experimentDir` が作る。
- `experiments/` には実行記録を作らない。cycleResult の `conditions` と `meta` に、同じ情報があるためである。
- 図のフォルダは `figureDir` が作る。完成品の置き場所なので、日付で分けず、実行記録も作らない。発表名は、年月6桁と略称をつなげる（例：`202609asj`、修士論文なら `202702thesis` のような形）。図の名前の付け方は [`docs/rules/figures.md`](docs/rules/figures.md) にある。

### 実験名の一覧

| 実験名 | 内容 | 主なスクリプト | 関連 issue |
| --- | --- | --- | --- |
| `upsampling` | 高解像度化（リサンプル・内挿）と、溝底の検出法（重心法・局所的最大値法）の比較 | `pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`pkCentroid_resample.m`、`pkCentroid_interp2.m`、`darkness3d.m` | — |
| `photoshopUpscaling` | Photoshop で8倍に拡大した写真での溝底の抽出（従来法） | `photoshop_centroid_1cycle.m`、`photoshop_localMax_1cycle.m`、`progress/showPhotoshopGrooveExtraction.m` | — |
| `bilateralFilter` | バイラテラルフィルタ | `bilateral/` の5本 | — |
| `digitalNeedle` | 先行研究 DigitalNeedle の溝の追跡の再現 | master には無い（マージしていないブランチ `claude/DigitalNeedle-reproduction` の `scripts/digitalNeedle/compareGrooveShapeAccuracy.m`） | — |
| `grooveTracking` | 1本の溝の自動追跡 | `grooveTrack_1cycle.m`、`evaluation/grooveTracking/compareTrackingToManual.m` | #25 |
| `multiGroove` | 複数本の溝の抽出（N周分） | `grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`、`evaluation/multiGroove/compareHistToTracking.m` | #30 |
| `grooveBottomDetection` | 溝底の判定（境界値を含めるか、溝底区間の幅の上限） | `evaluation/grooveBottomDetection/` の2本 | #35 |
| `stylus` | 針で再生した音との比較 | `evaluation/stylus/sound_from_stylus.m` | — |

新しく実験名を作ったら、この表に行を足す。

### 実験名の決め方

- 新しい手法・処理を試し始めたら、新しい実験名を作る（例：バイラテラルフィルタ、溝の自動追跡）。
- パラメータの変更、やり直し、評価、図の作り直しは、既存の実験名の下に実行フォルダを足す。
- 2つの実験名にまたがるときは、その実験を始めたきっかけのほうに置く。
- issue があるときは、issue の slug に名前を合わせる（例：#25 の `groove-tracking` は `grooveTracking`、#30 の `multi-groove` は `multiGroove`）。進捗報告用の図のテーマ（`results/figures/progress/<テーマ>/`）とも同じ名前にする。
- issue の slug が、すでにある進捗報告用の図のテーマや評価スクリプトの置き場所の名前と違うときは、すでにある名前に合わせる（例：#35 の `wide-bottom-outliers` は `grooveBottomDetection`）。
- `figures` は図の置き場所なので、実験名に使わない。

### 実行フォルダの名前の決め方

- 日付には、出力を作った日（実行した日）を `YYYY-MMDD` の形で書く（`docs/progress/` のファイル名と同じ形）。スクリプトには `date = "YYYY-MMDD"` と書いておき、実行する人が実行した日に書き換える。書き換えずに実行すると、`resultDir` がエラー（`resultDir:dateNotSet`）で止める。形の違う日付や暦に無い日付も、エラー（`resultDir:invalidDate`）にする。
- 説明は、同じ日に同じ実験名で別の実験をするときや、中身を名前で示したいときに付ける。長くなるときは、`_` で区切って詳細を足す（例：`2026-1014_evaluation_polyDegree`）。`_` で区切った各部分は英数字だけにし、数字だけの部分は作らない。末尾に付く `_2` などの番号と見分けるためである。
- 同じ名前のフォルダがすでにあれば、`resultDir` が `_2`、`_3`… を自動で付けて、警告（`resultDir:folderExists`）を出す。過去の出力を上書きしないためである（`saveCycleResult` が既存のファイルを上書きしないのと同じ考え方）。
- 出力先は、1回の実行で1回だけ、スクリプトの冒頭で作る。

### スクリプトでの使い方

1. スクリプトの冒頭で、実験名（`EXPERIMENT_NAME`）、実行した日（`date`）、説明（`LABEL`）を決める。実行する人が書き換える場所を1か所にまとめるためである。
2. パラメータの定数が決まった直後に `runConditions` を1回呼び、実験条件を決まった入れ子の struct にまとめる。渡すのはスクリプトの冒頭の定数だけにし、スクリプトの中に直接書いた値（回転数の `78` など）は渡さない。どのグループにも入らない条件（評価のしきい値など）は、`Other` に、定数名を camelCase にしたキーで入れる。
3. `resultDir` で実行フォルダを作り、`runInfo.json` を書く。戻り値の末尾には区切り文字が付くので、`outDir + "grooveHist_img1.png"` のように保存に使える。
4. 1周分のスクリプトでは、手順2と同じ `runConditions` の出力を `cycleConditions` にも渡す。画像の数やしきい値などを2回書かないためである。cycleResult に保存する `conditions` の形は、今までと同じになる。

```matlab
EXPERIMENT_NAME = "multiGroove";   % results/ の下の実験名（上の一覧から選ぶ）
date  = "YYYY-MMDD";               % 実行した日（例 "2026-1124"）。書き換えないと resultDir が止める
LABEL = "hist5";                   % 説明（付けないなら ""）

runCond = runConditions(NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, LMask=L_MASK, ...
    Upsampling="origD", Methods=["centroid","localMax"], DThresh=D_THRESH, WidthThresh=WIDTH_THRESH, ...
    Selection="histogram", ReplayFrom=PREV_RESULT_PATH, ...
    Tracking=struct(tolerance=TRACK_TOL, fitLength=FIT_LENGTH, snapRadius=SNAP_RADIUS, ...
                    initLength=INIT_LENGTH, maxGapLength=MAX_GAP_LENGTH, minFitPoints=MIN_FIT_POINTS), ...
    Histogram=struct(numGrooves=NUM_GROOVES, binWidth=BIN_WIDTH, thHistRatio=TH_HIST_RATIO, bandTol=BAND_TOL), ...
    PolyDegree=POLY_DEGREE, DetrendScope="photo", Rpm=RPM, AmpDiv=AMP_DIV);
outDir = resultDir(proj.RootFolder, EXPERIMENT_NAME, date, runCond, Label=LABEL, ...
    ScriptName="grooveHist_Ncycle", Images=filenames_new, InputFiles=PREV_RESULT_PATH);
expDir = experimentDir(proj.RootFolder, date);   % 1周分のスクリプトだけ

% ...（処理）...

cond = cycleConditions(runCond, Date=date, SaveDir=outDir, ExperimentDir=expDir, ...
    Filenames=filenames_new, ScriptName="grooveHist_Ncycle");
```

### `runInfo.json` の項目

`resultDir` は、実行記録を次のように書く。

- 何の実行か（`experiment`・`run`・`script`・`note`）、読んだ入力（`inputs`）、実験条件（`conditions`）、実行した環境（`meta`）の順に、上から読む順に並べる。普段読むのは上の3つで、`meta` は後からコードをたどるときに使う。
- MATLAB の `jsonencode`（`PrettyPrint=true`）で、UTF-8（BOM なし）で書く。`jsondecode` で読み戻せる。
- 値は `"fitLength": 60` のようにそのまま書き、`{"value": 60}` のようには包まない。
- 一覧は、要素が1つでも配列（`["..."]`）で書く。`NaN` は `null` になる。
- パスは、プロジェクトのルートからの `/` 区切りの相対パスで書く（`conditions` の中のパスも同じ）。
- `conditions` は、処理の順に並べた決まったグループに分ける。渡さなかった引数のグループは書かない。
- キーの名前は、スクリプトの定数名を camelCase にしたもの（`D_THRESH` なら `dThresh`）にする。`trackGroove` などの関数の引数に当たる値は、引数名に合わせる（`TRACK_TOL` なら `tolerance`）。普段見ている定数と、そのまま対応させるためである。
- 入れ子は3段（`conditions.grooveSelection.tracking`）までにする。長さの単位は、元の画像の px である。
- JSON に書ききれない複雑な実験条件（手順の意図、試行錯誤の経緯など）は、別の文書にまとめる。`note` には、その文書への参照や一言の説明を書いてよい。

表の「元の引数」は、`resultDir`・`runConditions`・`collectMeta` の引数と、そこへ渡すスクリプトの定数である。

| キー | 型 | 意味・単位 | 元の引数（スクリプトの定数） | 書く条件 |
| --- | --- | --- | --- | --- |
| `schemaVersion` | 数 | 実行記録の形の版（下の「版ごとの違い」）。最初は 1 | — | いつも |
| `experiment` | 文字列 | 実験名 | `resultDir` の第2引数（`EXPERIMENT_NAME`） | いつも |
| `run` | 文字列 | 実行フォルダの名前（`_<N>` を含む） | — | いつも |
| `script` | 文字列 | スクリプトのルートからのパス（`scripts/` の下で見つからなければ名前だけ） | `ScriptName` | いつも（渡さなければ `""`） |
| `note` | 文字列 | 一言の説明、別の文書への参照 | `Note` | いつも |
| `inputs.images` | 一覧 | 撮影画像のファイル名（拡張子なし） | `Images`（`filenames_new`） | いつも |
| `inputs.files` | 一覧 | 読んだファイルのルートからのパス | `InputFiles`（`PREV_RESULT_PATH` など。`""` は除く） | いつも |
| `conditions.region.*` | 数・一覧 | 写真の番号、セグメント、行・列の範囲 [px] など（キーは定数名の camelCase。例 `imgIndex`・`jSegment`） | `Region` | 渡したとき |
| `conditions.segmentation.numImages` | 数 | 写真の枚数 | `NumImages`（`NUM_IMAGES`。既定 8） | segmentation の引数を1つでも渡したとき |
| `conditions.segmentation.numSegments` | 数 | 写真を横に分ける数 | `NumSegments`（`NUM_SEGMENTS`。既定 10） | 同上 |
| `conditions.segmentation.lMask` | 数 | マスクの輝度のしきい値（0〜255） | `LMask`（`L_MASK`） | 渡したとき |
| `conditions.preprocessing.bilateral.kernelSizes` | 一覧 | バイラテラルフィルタの近傍の大きさ [px] | `Bilateral`（`KERNEL_SIZES`） | `Bilateral` を渡したとき |
| `conditions.preprocessing.bilateral.spatialSigmas` | 一覧 | 空間方向の標準偏差 [px] | `Bilateral`（`SPATIAL_SIGMAS`） | 同上 |
| `conditions.preprocessing.bilateral.degreeOfSmoothing` | 数 | 平滑化の度合い（輝度の2乗） | `Bilateral`（`DEGREE_OF_SMOOTHING`） | 同上 |
| `conditions.upsampling.kind` | 一覧 | `"origD"`・`"rsmplD"`・`"intpD"`。比べるスクリプトでは2つ以上 | `Upsampling` | 渡したとき |
| `conditions.upsampling.p`・`q` | 数 | リサンプルの倍率 p/q | `PRsmpl`・`QRsmpl`（`P_RSMPL`・`Q_RSMPL`） | `kind` に `rsmplD` があるとき（必須）。ほかのときも、渡せば書く |
| `conditions.upsampling.queryStep` | 数 | 内挿の間隔 [px] | `QueryStep`（`QUERY_STEP`） | `kind` に `intpD` があるとき（必須）。ほかのときも、渡せば書く |
| `conditions.upsampling.interpMethod` | 文字列 | `interp2` の方法 | `InterpMethod`（`INTERP_METHOD`） | 同上 |
| `conditions.grooveBottom.methods` | 一覧 | `"centroid"`・`"localMax"` | `Methods` | 渡したとき |
| `conditions.grooveBottom.dThresh` | 数 | 暗さのしきい値（0〜1） | `DThresh`（`D_THRESH`） | 渡したとき |
| `conditions.grooveBottom.widthThresh` | 数 | 溝底区間の幅の上限 [px] | `WidthThresh`（`WIDTH_THRESH`） | 渡したとき |
| `conditions.grooveSelection.method` | 文字列 | 溝の選び方。`"manual"`（`fitGroove` の手動選択）・`"tracking"`（自動追跡）・`"histogram"`（ヒストグラム） | `Selection` | 渡したとき |
| `conditions.grooveSelection.replayFrom` | 文字列 | 選択を再現した結果のルートからのパス | `ReplayFrom`（`PREV_RESULT_PATH`） | 空でないとき |
| `conditions.grooveSelection.tracking.tolerance`・`fitLength`・`snapRadius`・`initLength`・`maxGapLength` | 数 | `trackGroove` の引数 [px]（「溝の自動追跡（trackGroove）」の表） | `Tracking`（`TRACK_TOL`・`FIT_LENGTH`・`SNAP_RADIUS`・`INIT_LENGTH`・`MAX_GAP_LENGTH`） | `Tracking` を渡したとき |
| `conditions.grooveSelection.tracking.minFitPoints` | 数 | 直線のあてはめに要る点の数 | `Tracking`（`MIN_FIT_POINTS`） | 同上 |
| `conditions.grooveSelection.tracking.numGrooves`・`minSeedGap`・`reclickImages` | 数・数・一覧 | 本数、始点の間隔の下限 [px]、もう一度クリックする写真の番号 | `Tracking`（`NUM_GROOVES`・`MIN_SEED_GAP`・`RECLICK_IMAGES`。`grooveTrack_Ncycle.m`） | 同上 |
| `conditions.grooveSelection.histogram.numGrooves`・`binWidth`・`thHistRatio`・`bandTol` | 数 | 本数、ビンの幅 [px]、山の高さ（列の数に対する割合）、帯の半分の幅 [px] | `Histogram`（`NUM_GROOVES`・`BIN_WIDTH`・`TH_HIST_RATIO`・`BAND_TOL`） | `Histogram` を渡したとき |
| `conditions.grooveSelection.manual.thHist`・`tol`・`binWidth`・`hPrl` | 数 | ヒストグラムの山の高さ [点]、溝に含める距離 [px]、ビンの幅 [px]、平行四辺形の高さ [px] | `Manual`（`TH_HIST`・`tol`・`binWidth`・`h_prl`） | `Manual` を渡したとき |
| `conditions.detrend.polyDegree` | 数 | デトレンドの多項式の次数 | `PolyDegree`（`POLY_DEGREE`） | 渡したとき |
| `conditions.detrend.scope` | 文字列 | `"photo"`（写真ごと）・`"segment"`（セグメントごと） | `DetrendScope` | 渡したとき |
| `conditions.audio.rpm` | 数 | 回転数 [rpm]（既定 78） | `Rpm`（`RPM`） | audio の引数を1つでも渡したとき |
| `conditions.audio.ampDiv` | 数 | 振幅の正規化 [px] | `AmpDiv`（`AMP_DIV`） | 渡したとき |
| `conditions.other.*` | 数・文字列・一覧 | ほかに入らないもの（評価のしきい値など。キーは定数名の camelCase） | `Other` | 渡したとき |
| `meta.createdAt` | 文字列 | 作った日時 `yyyy-MM-ddTHH:mm:ss`（その PC の時刻） | `collectMeta` の `savedAt` | いつも |
| `meta.git.commit` | 文字列 | コミット（短い形） | `collectMeta` の `gitCommit` | いつも |
| `meta.git.branch` | 文字列 | ブランチ | `collectMeta` の `gitBranch` | いつも |
| `meta.git.dirty` | 真偽 | 未コミットの変更があったか（未追跡のファイルも含む） | `collectMeta` の `gitDirty` | いつも |
| `meta.matlabRelease` | 文字列 | MATLAB の版（`R2024b` の形） | `collectMeta` の `matlabRelease` | いつも |
| `meta.computerName` | 文字列 | PC の名前 | `collectMeta` の `computerName` | いつも |

`segmentation` と `audio` は、そのグループの引数を1つでも渡したときだけ書き、書くときは省いた値を既定値（8・10・78）で埋める。音声を作らないスクリプトに `audio.rpm` を書かないためである。`runConditions` の引数の型の間違い、表に無いキー（`runConditions:unknownField`）、深すぎる入れ子（`runConditions:tooDeep`）、高解像度化に要る引数の不足（`runConditions:missingArgument`）は、エラーで止まる。

例（`grooveHist_Ncycle.m` の定数の場合。実際のファイルは、配列の要素を1行に1つ書く）：

```json
{
  "schemaVersion": 1,
  "experiment": "multiGroove",
  "run": "2026-1028_hist5",
  "script": "scripts/grooveHist_Ncycle.m",
  "note": "",
  "inputs": {
    "images": ["DSC1111-00001-ori", "...（8つ）"],
    "files": ["experiments/2026-1014/cycleResult_origD_track_2026-1014.mat"]
  },
  "conditions": {
    "segmentation": { "numImages": 8, "numSegments": 10, "lMask": 20 },
    "upsampling": { "kind": ["origD"] },
    "grooveBottom": { "methods": ["centroid", "localMax"], "dThresh": 0.6, "widthThresh": 4 },
    "grooveSelection": {
      "method": "histogram",
      "replayFrom": "experiments/2026-1014/cycleResult_origD_track_2026-1014.mat",
      "tracking": { "tolerance": 2, "fitLength": 60, "snapRadius": 10, "initLength": 20, "maxGapLength": 40, "minFitPoints": 5 },
      "histogram": { "numGrooves": 5, "binWidth": 1, "thHistRatio": 0.3, "bandTol": 3 }
    },
    "detrend": { "polyDegree": 9, "scope": "photo" },
    "audio": { "rpm": 78, "ampDiv": 1.5 }
  },
  "meta": {
    "createdAt": "2026-10-28T14:02:11",
    "git": { "commit": "c7d2460", "branch": "claude/results-by-experiment", "dirty": false },
    "matlabRelease": "R2024b",
    "computerName": "（PC の名前）"
  }
}
```

#### 版ごとの違い

`schemaVersion` は、実行記録の形の版である。キーの名前や入れ子の形を変えたら1つ上げ、この表に行を足す。後で形を変えても、古いファイルと見分けられるようにするためである。パラメータが既定値かどうかを示す仕組みは、まだ無い（別の issue で決める。そのときも、今のキーは変えずに足す）。

| 版 | 使い始め | 変えたこと |
| --- | --- | --- |
| 1 | 2026-11（issue #28） | 最初の形 |

### 対応表（移す前の置き場所）

issue #28 で、日付だけの名前だった古いフォルダを、上の形の置き場所へ移した。過去の記録（`docs/issues/closed/` など）に書かれた古いパスから、今の場所を引くための表である。

- 表はフォルダの単位で書く。1つのフォルダに複数回の実行の出力が混ざっていたものは、ファイル名の形で実行ごとに分けた。どのパターンをどの実行フォルダへ移したかと、移したファイルの数は、移行の関数 `scripts/migration/migrateResults.m` が読む対応表 `scripts/migration/resultsMapping.csv` にある。
- 実行フォルダの日付には、移す前のフォルダの日付に年（2026）を足したものを使った。過去の記録のパスから1対1に引けるようにするためである。
- 中のファイル名と、手書きの記録（`results/1111/README.md`）は変えていない。

`results/` の日付のフォルダ（行き先は `results/` からのパス）：

| 移す前 | 移した後 | 中身（作ったスクリプト） |
| --- | --- | --- |
| `results/0710/` | （空なので消した） | — |
| `results/0721/` | `upsampling/2026-0721/` | 1セグメントの元データ・リサンプル・内挿の比較（`pkCentroid_interp2.m`） |
| `results/0724/` | `upsampling/2026-0724_intpD/`、`upsampling/2026-0724_rsmplD/` | 内挿・リサンプルの1周分 |
| `results/0731/` | `upsampling/2026-0731_origD/`、`upsampling/2026-0731_rsmplD/`、`upsampling/2026-0731_intpD/`、`upsampling/2026-0731_intpD_2/` | 高解像度化なし・リサンプル・内挿の1周分（`pkCentroid_1cycle.m` など）。内挿は、失敗した試行（`_intpD`。wav は無い）と、2026-08-20 の再実行（`_intpD_2`） |
| `results/0802/` | `photoshopUpscaling/2026-0802_localMax/`、`photoshopUpscaling/2026-0802_centroid/` | 従来法の1周分（`photoshop_*_1cycle.m`） |
| `results/0807/` | `upsampling/2026-0807_rsmplD/` | リサンプルの1周分（`pkCentroid_resample_1cycle.m`） |
| `results/0817/` | `photoshopUpscaling/2026-0817/` | `progress/showPhotoshopGrooveExtraction.m` |
| `results/0820/bilateral/ori/`・`oriRsmpl/`・`oriIntp/`・`photoshop8x/` | `bilateralFilter/2026-0820_ori/`・`_oriRsmpl/`・`_oriIntp/`・`_photoshop8x/` | バイラテラルフィルタの1セグメントの検討（`bilateral/` の4本） |
| `results/0831/digitalNeedle/` | `digitalNeedle/2026-0831/` | DigitalNeedle の再現（マージしていないブランチ `claude/DigitalNeedle-reproduction`） |
| `results/0924/bilateral1cycle/` | `bilateralFilter/2026-0924_1cycle/` | バイラテラルフィルタの1周分（`bilateral/bilateralOri_centroid_1cycle.m`） |
| `results/1013/` | `grooveTracking/2026-1013/` | 自動追跡（`grooveTrack_1cycle.m`。#25 の実装の確認） |
| `results/1014/` | `grooveTracking/2026-1014_manual/`、`grooveTracking/2026-1014_track/`、`grooveTracking/2026-1014_evaluation/` | #25 の評価（手動選択の再現、自動追跡、評価スクリプト） |
| `results/1022/` | `grooveTracking/2026-1022/` | 自動追跡（`grooveTrack_1cycle.m`） |
| `results/1026/` | `grooveTracking/2026-1026/` | 自動追跡の始点を1列目に固定した後の確認 |
| `results/1028/` | `multiGroove/2026-1028_hist5/`、`multiGroove/2026-1028_track5/`、`multiGroove/2026-1028_track/` | #30 の実装の確認（ヒストグラム、N本の追跡、1本の追跡） |
| `results/1104/` | `multiGroove/2026-1104_track5/`、`multiGroove/2026-1104_hist5/`、`multiGroove/2026-1104_evaluation/` | #30 の正解データ、本実装、評価スクリプト |
| `results/1110/` | `grooveTracking/2026-1110/` | 自動追跡の途中で止まった実行（写真2枚分の図だけ） |
| `results/1111/` | `grooveBottomDetection/2026-1111_exclBoundVsInclBound/` | 境界値を含めるかの比較（`compareInclBoundToExclBound.m`） |
| `results/1118/` | `grooveBottomDetection/2026-1118_track/`、`grooveBottomDetection/2026-1118_hist5/`、`grooveBottomDetection/2026-1118_track5/`、`grooveBottomDetection/2026-1118_evaluation/` | #35 の評価（3つのスクリプトの作り直しと評価スクリプト） |

図のフォルダ：

| 移す前 | 移した後 | 移し方 |
| --- | --- | --- |
| `results/figures/paper/202609asj/` | `results/figures/202609asj/paper/` | 移行の関数（git では追跡しない） |
| `results/figures/slides/202609asj/` | `results/figures/202609asj/slides/` | `git mv`（git で追跡する。移行の関数の対応表には入れない） |
| `results/figures/progress/` | 変えない | — |

`experiments/`：

| 移す前 | 移した後 |
| --- | --- |
| `experiments/<MMDD>/cycleResult_<条件>_<MMDD>.mat`（`0731`・`0802`・`0807`・`1013`・`1014`・`1022`・`1104` の11ファイル） | `experiments/2026-<MMDD>/cycleResult_<条件>_2026-<MMDD>.mat`（例：`experiments/0731/cycleResult_origD_0731.mat` は `experiments/2026-0731/cycleResult_origD_2026-0731.mat`） |
| `experiments/0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_0831.mat` | `experiments/2026-0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_2026-0831.mat` |
| `experiments/1026/`・`experiments/1110/`（空） | 消した |
| `experiments/archive/` | 変えない |

.mat の中身（`conditions.date = "0731"` など）は変えていない。

## 基本的な使用方法

1. MATLABで **`Research.prj`** を開いてプロジェクトを起動します。
2. スクリプト先頭で以下を実行し、ルートフォルダを取得します。パス指定はこの `rootFolder` を基点に行ってください。
   ```matlab
   proj = currentProject;
   rootFolder = proj.RootFolder;
   ```
3. `scripts/` 内の目的に合ったスクリプト（例: `pkCentroid_interp2_1cycle.m`）の冒頭で、実行した日 `date` を `"2026-1124"` の形に書き換え、必要なら説明 `LABEL` を書いてから実行します。`date` が `"YYYY-MMDD"` のままだと、`resultDir` がエラーで止めます。処理途中で `fitGroove` により溝中心をマウス（`ginput`）で指定する操作が必要です。
4. 生成された図・音声と実行記録 `runInfo.json` は実行フォルダ `results/<実験名>/<YYYY-MMDD>[_<説明>]/` に、1周分の解析結果の`.mat`は `experiments/<YYYY-MMDD>/` に保存されます。同じ日に同じ設定でもう一度実行すると、上書きせずに `_2` の付いた実行フォルダに出力します。完成した図は、図のスクリプトが `results/figures/` に保存します（「結果の置き場所と実行記録」）。
