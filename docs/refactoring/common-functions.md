# scripts/ の共通関数の候補

作成日: 2026-11-14 / 更新日: 2026-11-22 / 作成者: Claude

この文書は、`scripts/` のスクリプト（`archive/` を除く52本）を読み、何度も書き写されている処理を `src/` の関数にまとめる案を並べたものである。読み手は、この文書を作った会話を知らない Claude（実装を担当する）と、実装の順を決めるユーザーである。調べたのは、`master` のコミット `e6e4edb` の時点のコードである。その後の `master`（`f2e70c7`）でも、`scripts/`・`src/`・`test/` は変わっていない。

> この文書は提案であり、コードはまだ変えていない。実装は、ユーザーが skill・サブエージェントを整えてから行う。

## 1. 言葉

この文書で何度も使う言葉の意味を、本文の前にまとめる。1回しか使わない言葉は、出たところで説明する。

### 撮影画像と、その分け方

- **撮影画像**：盤面を撮ったままの画像ファイル（`data/pictures/` の png）。高解像度化していない `-ori` の画像と、Photoshop で8倍に拡大した `-8x` の画像の2種類がある。
- **写真**：盤面を8回に分けて撮った撮影画像の1枚で、1/8周分にあたる。スクリプトでは番号 `iImg`（1〜8）で表す。この番号は再生の順で、撮影ファイルの番号とは逆順になる（`iImg = 1` は `DSC1111-00008-ori.png`）。
- **セグメント**：写真1枚を横に10等分した、細長い画像の1つ。写真の中の番号は `jSegment`（1〜10）で表す。
- **通し番号**：1周の中でのセグメントの番号。`k = (iImg-1)*10 + jSegment` で、1〜80の値をとる。スクリプトでは `kImgSmall` とも書かれている。
- **マスク**：撮影画像の左右の端にある、画素値がとても小さい（暗い）列。溝が写っていないので、`omitMask` で除く。
- **1周分・N周分**：1周分は、レコード1回転分（80セグメント）のデータや音声である。N周分は、写真ごとに内側の溝も合わせて N 本を取り出し、N 回転分をつないだものである（issue #30）。N 本のうち最も外側の溝を「1本目」と呼ぶ。

### 溝底点の求め方

- **暗さ行列**：画素値 `img` から求めた暗さ `dMat = 1 - img/255` の行列。0（明るい）〜1（暗い）の値をとり、`DarknessMap` クラスが持つ。
- **高解像度化**：暗さ行列の解像度を上げること。条件は次の3つで、結果ファイルの名前にも使う。
  - `origD` は、高解像度化しない条件である。
  - `rsmplD` は、縦方向（溝を横切る方向）だけを1次元にリサンプルする条件である（`DarknessMap.dResample`）。列の数は変わらない。
  - `intpD` は、2次元に内挿する条件である（`DarknessMap.dInterp`）。縦も横も、内挿の刻み `step` の逆数の倍になる。
- **元の画像の座標**：高解像度化する前の画像の、画素の位置 [px]。高解像度化した行列の行番号 `idx` は、`(idx-1)/scaleFactor.row + 1` でこの座標に戻す。列は `scaleFactor.col` で同じように戻す（`scaleFactor` は縦・横の拡大率）。
- **溝底範囲**：列ごとに見つける、溝の底とみなす区間。暗さがしきい値（`D_THRESH`、ふつう 0.6）以上の区間のうち、幅が上限（`WIDTH_THRESH`、ふつう 8 px）以下のものを選ぶ。区間の始めの行を start、終わりの行を end と呼ぶ。
- **溝底点**：溝底範囲から求めた、溝の底の y 座標。1つの列に、写っている溝の本数だけ見つかる。
- **手法**：溝底点の求め方。次の2つがあり、保存のフィールド名では `centroid`・`localMax` と書く。
  - **重心法**（`centroid`）は、溝底範囲の暗さの重心を y にする。
  - **局所的最大値法**（`localMax`）は、溝底範囲で暗さが最大の位置を y にする。
- **点群**：溝底点の集まり。セグメントごとに `GroovePointCloud` クラスが持つ。
- **従来法**：Photoshop で8倍に拡大した撮影画像から溝底点を求める方法。2026年3月に発表した方法で、比べる相手として使う。`photoshop_*_1cycle.m` が作り、その音声は `experiments/2026-0802/cycleResult_origD_2026-0802.mat` にある。

### 溝の選び方と、音声の作り方

- **溝形状**：選んだ1本の溝について、列ごとの溝底点の y を並べたもの。音声の波形のもとになる。
- **ginput**：マウスのクリックで、図の上の座標を受け取る MATLAB の関数。溝を選ぶときに使う。
- **手動選択**：`fitGroove` で、セグメントごとに溝をクリックして選ぶ、自動追跡より前からの方法。1周で80回以上クリックする（従来法とは別のものである）。
- **自動追跡**：`trackGroove` で、写真1枚につき1回のクリックから、溝を1列ずつたどる方法（issue #25）。
- **始点**：自動追跡で溝をたどり始める点。x は写真の1列目に固定し、y だけをクリックで決める。
- **デトレンド**：溝形状から、写真（またはセグメント）全体のゆるやかな傾きと曲がりを多項式で引き、平均を0にすること（`detrendGrooveShape`・`detrendTrackedShape`）。引く前の y を「デトレンド前の y」と呼ぶ。
- **`xQuery`・`counts`**：`mergeSegmentPoints` が返す値。`xQuery` は写真1枚分の列の x 座標、`counts` はセグメントごとの列の数である。
- **標本化周波数**：音声の1秒あたりのサンプル数（`fs`）。1周分のサンプル数を、1周の時間（78 rpm なら 60/78 秒）で割って決める。

### 結果の保存と、比べ方

- **cycleResult**：1周分（または N 周分）の解析結果を入れた `.mat`。`saveCycleResult` で `experiments/<日付>/` に保存し、`loadCycleResult` で読む。中身の構成を、この文書では「保存の形」と呼ぶ。
- **grooveSelection**：cycleResult の中の、溝の選び方を記録したフィールド。手動選択のクリックの位置（`p1`・`p2`）や、自動追跡の始点とパラメータを持つ。
- **再現**：grooveSelection を使い、ginput なしで同じ溝を選び直して、解析をやり直すこと。スクリプトでは、変数 `PREV_RESULT_PATH` に前の cycleResult を指定すると再現になる。
- **実データ**：`data/` の撮影画像と、`experiments/` の cycleResult。CI（GitHub Actions で動くテスト）には無い。
- **RMSE・相関係数**：2つの溝形状の差の二乗平均の平方根 [px] と、Pearson の相関係数。溝形状の比べ方として、`docs/rules/evaluation.md` が決めている。
- **外れ**：2つの方法（例：手動選択と自動追跡）で作った音声の差が、大きいサンプル。原因になった溝底点を調べるため、そのサンプルがどの写真・セグメント・列から来たかを求める。
- **評価スクリプト**：`scripts/evaluation/` にある、手法の結果を比べて合否を判定するスクリプト。
- **単体テスト**：`test/unit/` にある、合成データだけを使うテスト。`runAllTests` で実行し、CI でも動く。

### この文書の言葉

- **共通関数**：何本ものスクリプトで使うために、`src/` に置く関数。
- **重複**：同じ処理を書き写しているスクリプトの数。候補の一覧の「重複」の列に書いた。
- **置き換え**：スクリプトの中で書き写されている処理を、共通関数の呼び出しに書き換えること。
- **動かないスクリプト**：今のコードでは途中でエラーになり、最後まで動かないスクリプト。[7章](#7-先に決めたほうがよいこと動かないスクリプト) の6本である。
- **現役のスクリプト**：今の作業で実行しているスクリプト。`scripts/` 直下の `_1cycle`・`_Ncycle` のスクリプトと、`scripts/progress/`・`scripts/evaluation/` のスクリプトのうち、動かないスクリプトを除いたものを指す。
- **学会用のスクリプト**：`scripts/paper/202609asj/`（原稿の図）と `scripts/slides/202609asj/`（スライドの図）のスクリプト。音響学会2026年9月の発表のために作った。
- **影響の大きさ・重要度**：実装の順を決めるために、各候補に付けた2つの目安。影響の大きさは、置き換えで結果が変わる危険と手間の大きさを表す。重要度は、まとめて得られるものの大きさを表す。どちらも3段階で、決め方は [3章](#3-影響の大きさと重要度の決め方) に書いた。

## 2. 結論

- 最も効く候補は、次の3つである。
  - **B1 溝底点の検出（`detectGroovePoints`）**：暗さ行列の列ごとに溝底点を求めるループが、30本のスクリプトに38か所ある。書き写すうちに、高解像度化した後の x の戻し方とループの範囲が、スクリプトごとに食い違っている。
  - **A2 写真の読み込みと分割（`loadPhotoSegments`）**：写真を読んで10のセグメントに分け、左右のマスクを除く処理が、18本のスクリプトと `src/reconstructImage.m` にある。「写真の番号と撮影ファイルの番号は逆順」という決まりも、各所に `9-iImg` として埋まっている。
  - **E1 結果ファイルの名前の種類（`cycleResultPath` に `Variant` を足す）**：自動追跡・N周分の結果（`_track`・`_hist5` など）のパスを、15本のスクリプトが手で組み立てている。変更が小さく、出力も変わらないので、最初に行うのに向く。
- 実装の前に、**動かないスクリプト6本の扱い**（`archive/` へ移すか、直すか）を決めるとよい（[7章](#7-先に決めたほうがよいこと動かないスクリプト)）。直さないスクリプトまで置き換えるのは、手間が無駄になるため。
- 推奨する順は [4章](#4-推奨する実装の順) にまとめた。順を決めるのはユーザーである。

### 候補の一覧

表の「影響」「重要度」「重複」の意味は、1章に書いた。影響の大きさと重要度の決め方は、[3章](#3-影響の大きさと重要度の決め方) に書いた。

| ID | 関数名（案） | 何をするか | 重複 | 影響 | 重要度 | 先に要る候補 |
|---|---|---|---|---|---|---|
| A1 | `photoFilenames` | 撮影画像のファイル名の一覧を作る | 20本 | 小 | 低 | なし |
| A2 | `loadPhotoSegments` | 写真1枚を読み、セグメントに分け、マスクを除く | 18本＋src 1 | 中 | 高 | A1（なくてもよい） |
| A3 | `segmentIndices` | 写真の番号から、セグメントの通し番号を求める | 5本＋多数 | 小 | 低 | なし |
| B1 | `detectGroovePoints` | 暗さ行列の全列から溝底点（と溝底範囲）を求める | 30本 | 大 | 高 | なし |
| B2 | `detectPhotoGroovePoints` | 写真1枚分の溝底点を、読み込みから一度に求める | 7本 | 大 | 高 | A2、B1 |
| C1 | `selectGrooveSegment` | `fitGroove` の手動選択と再現を切り替える | 5本 | 中 | 低 | なし |
| C2 | `clickGrooveSeeds` | 写真の左端で、追跡する溝をクリックさせる | 3本 | 小 | 低 | なし |
| C3 | `splitPhotoShape`・`segmentEndPoints` | 写真1枚分の溝形状を、セグメントごとに分け直す | 3本 | 中 | 中 | なし |
| C4 | `trackingRecord`・`trackingArgs` | 追跡のパラメータと結果を保存の形にまとめる。保存した値から `trackGroove` の引数を作る | 3本＋評価2本 | 中 | 中 | なし |
| C5 | `methodFieldName` | 手法の名前から、保存のフィールド名（`yAbsCnt` など）を作る | 4本 | 小 | 低 | なし |
| C6 | `extractGrooveShape` の出力を足す | 溝形状に使った点を返す | 1本（＋動かない1本） | 小 | 低 | なし |
| D1 | `makeCycleAudio` | 連結した y 座標から、標本化周波数と振幅を決めて音声にする | 10本 | 中 | 中 | なし |
| D2 | `saveAudioFigures` | 音声の波形・FFT・スペクトログラムの図と wav を保存する | 10本 | 中 | 中 | D1、ユーザーの決定 |
| E1 | `cycleResultPath` などに `Variant` | 結果ファイルの名前に種類（`track`・`hist5` など）を入れる | 15本 | 小 | 高 | なし |
| E2 | `loadCycleAudio` | 結果ファイルから音声を取り出し、無ければ止める | 7本 | 小 | 低 | E1 |
| F1 | `figureDir` | 図の置き場所（`results/figures/...`）を作って返す（issue #28 で作った） | 34本 | 小 | 中 | なし |
| F2 | `showPhoto` | 撮影画像を、表示範囲 [0 255] に固定して描く | 17本 | 中 | 中 | なし |
| F3 | `pointsInView` | 描く範囲にある点だけを残す | 7本 | 小 | 低 | なし |
| F4 | `applyFontStyle` | 原稿用・スライド用の文字の大きさをそろえる | 16本 | 中 | 中 | なし |
| F5 | `formatAudioAxes` など | 波形・スペクトログラムの軸の体裁と、共通のカラーバー・軸ラベルを付ける | 8本 | 中 | 低 | F4 |
| G1 | `rmseCorr`・`longestRun`・`segmentsToPhotos` | 溝形状を RMSE と相関係数で比べる | 評価2本 | 小 | 中 | なし |
| G2 | `sampleToColumn`・`findLargestDiff` | 音声のサンプル番号から、写真・セグメント・列を求める | 2本 | 小 | 中 | なし |
| H1 | `requireDateSet` | 実行日が書き換えられていなければ止める | 5本 | 小 | 低 | なし |

## 3. 影響の大きさと重要度の決め方

ユーザーが実装の順を決めるための目安として、各候補に2つの評価を付けた。

- **影響の大きさ**：リファクタリングで変えるものの多さと、結果が変わってしまう危険の大きさ。
  - 大：20本以上のスクリプトを変える。または、cycleResult・音声の値を作る中心の処理を置き換えるので、実データで前後の結果を比べる確認が要る。
  - 中：5〜20本のスクリプトを変える。または、保存の形・図の見た目・`ginput` の操作に触れるので、出力の比較か目視の確認が要る。
  - 小：変えるスクリプトが少ないか、置き換えが機械的で、結果が変わらないことを単体テストで確かめられる。
- **重要度**：まとめたときに得られるものの大きさ。
  - 高：重複が多いうえに、書き写しによる食い違いや、隠れた決まりがすでにある。または、これが無いと他の候補が進められない。
  - 中：重複が多い。または、ルール（`docs/rules/figures.md`・`evaluation.md`）や保存の形を守らせる効果がある。または、進行中・次の作業で使う見込みが高い。
  - 低：重複が少ないか、置き換えても得られるものが小さい。

## 4. 推奨する実装の順

Claude の推奨である。順を決めるのはユーザーである。

1. 動かないスクリプト6本の扱いを決める（[7章](#7-先に決めたほうがよいこと動かないスクリプト)）。置き換えの対象が減る。
2. **E1**（結果ファイルの名前の種類）を行う。小さく、出力が変わらず、15本の手書きのパスが消える。
3. **A1・A2**（ファイル名と写真の読み込み）を行う。B2 の前提になる。`reconstructImage` も A2 を使う形に直す。
4. **B1**（溝底点の検出）を行う。最も重複が多い。まず `_1cycle` 系と `progress/` の現役のスクリプトから置き換える。
5. **D1**（音声を作る）を行う。数値が同じになることを簡単に確かめられる。
6. **B2**（写真1枚分の検出）を行う。`_1cycle`・`_Ncycle` のスクリプトの中心のループが短くなる。実データで前後の結果を比べる。
7. **F1・F2・F4**（図の置き場所・撮影画像の表示・文字の大きさ）を行う。次の学会・進捗報告の図で使う。
8. **G1・G2**（評価の比べ方と、外れの場所の求め方）を行う。進行中の issue #35 の作業でも使える。
9. **C3・C4・C5**（追跡の結果の保存の形）を行う。
10. 残り（D2、E2、F3、F5、C1、C2、C6、A3、H1）は、ユーザーの決定（[9章](#9-ユーザーが決めること)）を待つか、そのスクリプトを次に触るときに行う。

## 5. 全候補に共通する決まり

### 実装の決まり

- 関数は `src/<関数名>.m` に置く。書き方は [`docs/rules/coding.md`](../rules/coding.md) に従う（`arguments` ブロックでの検証、name-value 引数は `opts.Name`、`error` の識別子は `"<関数名>:<理由>"`、先頭に日本語で「何を・なぜ」）。
- テストは `test/unit/<関数名の先頭を大文字にした名前>Test.m` に、合成データだけで書く。`data/`・`experiments/` は読まない（CI には実データが無いため）。
- 関数を足したら、`README.md` の「`src/` の主なクラス・関数」に1行足す。処理の流れが変わる候補（B2 など）は、「処理の流れ」の節も直す。
- 1つの候補を、1つの目的のコミット（またはPR）にする。関数の追加と、呼び出し側の置き換えは、別のコミットにしてよい。
- `archive/` 配下は触らない。既存の図の名前は変えない（[`figures.md`](../rules/figures.md) の「既存の図とスクリプト」）。
- 名前（関数名・引数名）は案である。実装するときに、既存の名前と重ならないかを `src/` で確かめる。

### 置き換えの範囲

- 現役のスクリプトを先に置き換える。
- 学会用のスクリプトは、発表が終わった資料の図を作ったものである。図の見た目が少しでも変わると、共有済みの資料と食い違う（スライド用の図は git で管理している）。そこで、これらは無理に置き換えず、次の学会のスクリプトから新しい関数を使うことを勧める。置き換えるなら、前後の PNG が一致することを確かめる。

### 出力が変わらないことの確かめ方

リファクタリングで結果が変わっていないことは、次の手順で確かめる。実データの扱いは [`docs/rules/data.md`](../rules/data.md) に従う。

1. 比べる基準を作るため、置き換える前のスクリプトを、プロジェクトの `temp/` にコピーして実行する。
   - (1) 過去の出力を上書きしないよう、`date` を、まだ使っていない日付にする。
   - (2) `ginput` なしで動かすため、`PREV_RESULT_PATH` に既存の cycleResult を指定して、再現にする。
   - (3) `experiments/` に書かないよう、`saveCycleResult` の行を外す。代わりに、`result` に当たる値（`allPts_*`・`xcoords`・`ycoords_*`・`y_comb_*`・音声・`grooveSelection`）を `temp/` の `.mat` に書き出す。
2. 置き換えた後のスクリプトも、同じようにコピーして実行し、`.mat` を書き出す。
3. 2つの `.mat` の値を `isequal` で比べる。`GroovePointCloud` は `peakCells` を、`AudioData` は `signal` と `fs` を比べる。一致しなければ、どのセグメントから違うかを調べる。
4. 図を作るスクリプトは、前後の PNG を `temp/` に書き出し、`isequal(imread(a), imread(b))` で比べる。一致しなければ、両方を開いて目で比べ、違いをユーザーに伝える。

補足として、次のことに気をつける。

- MATLAB は全セッションで1つを共有している。worktree のスクリプトを `currentProject()` 付きで動かすには、その worktree の `Research.prj` を開く必要があり、ほかのセッションに影響する（[`docs/git-rules.md`](../git-rules.md)）。実行する前にユーザーに伝える。
- 次の2つは、保存済みの cycleResult と完全に一致することが、それぞれの issue の評価で確かめられている。直接の比較にも使える。
  - `grooveTrack_1cycle.m` を `experiments/2026-1014/cycleResult_origD_track_2026-1014.mat` から再現した結果（issue #25 の評価の E5d・E5e）
  - `grooveHist_Ncycle.m` の結果 `experiments/2026-1104/cycleResult_origD_hist5_2026-1104.mat`（`compareInclBoundToExclBound.m` が、その写真2の溝底点と一致することを確かめている）

## 6. 候補の詳細

各候補を、次の項目で書く。

- 目的：なぜまとめるのか
- 今の重複：書き写している場所
- 仕様：関数の形と、処理の手順
- 置き換え方：呼び出し側をどう変えるか
- 注意：結果が変わりうる所と、変えてはいけない所
- テスト：単体テストで確かめること
- 評価：影響の大きさと重要度、その理由

### A. 画像の読み込み

#### A1 `photoFilenames`：撮影画像のファイル名の一覧

- 目的
  - 撮影画像のファイル名（`DSC1111-00001-ori` など）を作るループが、20本のスクリプトにある。1か所にまとめ、名前の決まりを関数に持たせる。
- 今の重複
  - `filenames_new(i) = "DSC1111-0000" + num2str(i) + "-ori"` のループ（例：[`pkCentroid_1cycle.m`](../../scripts/pkCentroid_1cycle.m) の14〜19行）。`-8x` の版は `photoshop_*_1cycle.m` にある。
  - 使われていない `filenames_old`（`"DSC0" + num2str(i+112) + "_8x"`）も、6本に残っている。
- 仕様

  ```matlab
  function names = photoFilenames(opts)
      arguments
          opts.Kind (1,1) string {mustBeMember(opts.Kind,["ori","8x"])} = "ori"  % 高解像度化していない画像か、Photoshopで8倍にした画像か
          opts.NumImages (1,1) double {mustBeInteger,mustBePositive} = 8
          opts.Session (1,1) string = "DSC1111"   % 撮影の回（ファイル名の頭）
      end
  ```

  - 出力 `names` は `NumImages×1` の string で、拡張子を付けない（`cycleConditions` の `Filenames` と同じ形）。
  - i 番目の名前は `compose("%s-%05d-%s", Session, i, Kind)` で作る。今の書き方は i が10以上で桁がずれるが、この書き方なら正しい。i が1〜9のときは今と同じ名前になる。
  - 並びはファイルの番号の順のままにする。写真の番号 `iImg` との逆順の対応は A2 が持つ。
- 置き換え方
  - スクリプトのループを `filenames_new = photoFilenames();` の1行にする。`filenames_old` は消す。
- 注意
  - 戻り値の名前を変えないこと。`cycleConditions(Filenames=...)` に入り、`reconstructImage` が後で同じ名前でファイルを探す。
- テスト
  - 既定で `"DSC1111-00001-ori"`〜`"DSC1111-00008-ori"` を返すこと。`Kind="8x"` で `-8x` になること。`NumImages=12` で `"DSC1111-00012-ori"` になること。
- 評価：影響は小、重要度は低
  - 置き換えは機械的で、結果は変わらない。ただし、得られるものも小さい。A2 と一緒に行うと手間が少ない。

#### A2 `loadPhotoSegments`：写真1枚を読み、セグメントに分け、マスクを除く

- 目的
  - 写真の読み込みと分割は、すべての `_1cycle`・`_Ncycle` スクリプトの入り口である。同じ処理が18本と [`src/reconstructImage.m`](../../src/reconstructImage.m) に書き写されている。
  - 写真の番号と撮影ファイルの番号が逆順であること（`9-iImg`）が、各所に説明なしで埋まっている。関数に持たせて、1か所にする。
  - いくつかのスクリプトは、同じ写真をセグメントごとに読み直している（`pkCentroid_1cycle.m` などは `imread` が80回）。写真ごとに1回にすると速くなる。
- 今の重複
  - `imread` → `rgb2gray` → `divWidth = round(width/NUM_SEGMENTS)` → `xarray = [1:divWidth:width width+1]'` → `img_gray(:, xarray(j):xarray(j+1)-1)` → `omitMask` → `ImageData(img, [iImg; jSegment])` の流れ。
  - 主なもの：`pkCentroid_1cycle.m`（63〜73行。セグメントのループの中で読む）、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`grooveTrack_1cycle.m`（87〜103行）、`grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`、`bilateral/bilateralOri_centroid_1cycle.m`、`photoshop_*_1cycle.m`、`paper/202609asj/fig_grooveShape*Comparison.m`、`src/reconstructImage.m`。
  - 写真1枚分を横につないだ画像 `ImageData([allImg(ks).img], [iImg;0])` も5本で作っている。
- 仕様

  ```matlab
  function [imgs, photo] = loadPhotoSegments(filenames, iImg, numSegments, lMask, opts)
      arguments
          filenames (:,1) string          % photoFilenames の出力（拡張子なし、ファイルの番号順）
          iImg (1,1) double {mustBeInteger,mustBePositive}       % 写真の番号（再生の順）
          numSegments (1,1) double {mustBeInteger,mustBePositive}
          lMask (1,1) double              % omitMask のしきい値（L_MASK）
          opts.PhotoDir (1,1) string = "" % 撮影画像のフォルダ。"" なら MATLAB のパスから探す
          opts.ImageFilter = []           % omitMask の後に画像にかける関数（例：バイラテラルフィルタ）。[] ならかけない
      end
  ```

  処理の手順は次のとおり。

  1. 読むファイルの番号を `fileIdx = numel(filenames) + 1 - iImg` で決める。写真の番号は再生の順で、撮影ファイルの番号と逆だからである。`iImg` が `numel(filenames)` を超えたら `loadPhotoSegments:iImgOutOfRange` で止める。
  2. `filenames(fileIdx) + ".png"` を読む（`PhotoDir` があれば `fullfile` でつなぐ）。`rgb2gray` で白黒にする。
  3. 幅を `divWidth = round(width/numSegments)` ずつに分ける。区切りは今と同じ `xarray = [1:divWidth:width width+1]'` で作る。
  4. セグメント `j` = 1〜`numSegments` について、次を行う。
     - (1) `img_gray(:, xarray(j):xarray(j+1)-1)` を切り出す。
     - (2) `omitMask(img, lMask)` で左右の暗い列を除く。
     - (3) `ImageFilter` があれば、それをかける。
     - (4) `ImageData(img, [iImg; j])` を作る。
  5. 出力 `imgs` は `numSegments×1` の `ImageData`。2つ目の出力 `photo` は、全セグメントを横につないだ `ImageData([imgs.img], [iImg; 0])`。高さはすべて同じなので、横につなげる。

  `reconstructImage(conditions, iImg)` は、中で `loadPhotoSegments(conditions.filenames, iImg, conditions.numSegments, conditions.lMask, PhotoDir=opts.PhotoDir)` を呼ぶだけの形にする。引数・エラーの識別子（`reconstructImage:noFilenames` など）は今のまま残す。

- 置き換え方
  - スクリプトでは、写真のループの先頭で `[imgs, photoImg] = loadPhotoSegments(filenames_new, iImg, NUM_SEGMENTS, L_MASK);` と1回呼ぶ。セグメントのループの中では `origImg = imgs(jSegment);` を使う。
  - バイラテラルフィルタのスクリプトは、条件ごとに `ImageFilter=@(img) imbilatfilt(img, ...)` を渡すか、フィルタなしで1回読んでから、各セグメントの画素にフィルタをかける。
- 注意
  - 写真の幅によっては、`xarray` の要素が `numSegments+2` 個になり、右端の数列がどのセグメントにも入らない。保存済みの結果と同じにするため、**この動きは直さない**。関数の説明にそう書く。
  - `imread` を写真ごと1回にしても、画素の値は変わらない。
  - 撮影画像を MATLAB のパスから探すか、`rootFolder` からのフルパスにするかは、ユーザーが決める（[9章](#9-ユーザーが決めること) の Q4）。決まるまでは `PhotoDir=""`（今と同じ）を既定にする。
- テスト
  - 一時フォルダに合成した RGB の PNG を書き（`TemporaryFolderFixture`）、`PhotoDir` で読ませる。
  - `iImg = 1` が最後のファイルを読むこと（逆順）。
  - 各セグメントの `imgID` が `[iImg; j]` であること。
  - 左右の暗い列が除かれること。
  - `photo` の幅が各セグメントの幅の合計であること。
  - `ImageFilter` がかかること。
  - 既存の `ReconstructImageTest` がそのまま通ること。
- 評価：影響は中、重要度は高
  - 影響：変えるスクリプトは約10本で、置き換えは入り口だけである。結果が同じことは [5章](#出力が変わらないことの確かめ方) の手順ですぐ確かめられる。
  - 重要度：隠れた決まり（逆順）を1か所にし、B2 の前提になる。

#### A3 `segmentIndices`：写真の番号からセグメントの通し番号を求める

- 目的
  - `ks = (iImg-1)*NUM_SEGMENTS + (1:NUM_SEGMENTS)` が5本に12か所、`kImgSmall = (iImg-1)*NUM_SEGMENTS + jSegment` がほぼすべての `_1cycle` スクリプトにある。式の意味（写真 i の何番目のセグメントが1周の何番目か）を名前で表す。
- 仕様
  - `ks = segmentIndices(iImg, numSegments)` は、写真 `iImg` に属するセグメントの通し番号を **行ベクトル**（`1×numSegments`）で返す。今の `ks` と同じ向きにするため（`for k = ks` で使っている）。
  - 3つ目の引数 `jSegment` を渡すと、そのセグメントの通し番号（スカラー）を返す。
- テスト
  - `segmentIndices(2,10)` が `11:20` を返すこと。`segmentIndices(2,10,3)` が 13 を返すこと。
- 評価：影響は小、重要度は低
  - 式は1行で、読み違いもまだ起きていない。ほかの候補で同じスクリプトを触るときに、ついでに置き換える程度でよい。

### B. 溝底点の検出

#### B1 `detectGroovePoints`：暗さ行列の全列から溝底点を求める

- 目的
  - 次のループが、30本のスクリプトに38か所ある。この文書で最も多い重複である。

    ```matlab
    extractor = GrooveExtractor(map);
    for x = 1:map.nCols
        [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
        [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH);
        pts_cnt.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByCentroid(map,x)];
        pts_max.peakCells{x} = [x*ones(numPeaks,1), extractor.extractByLocalMax(map,x)];
    end
    ```

  - 書き写すうちに、スクリプトごとに次の食い違いが生まれている。1つの関数にすると、正しい形に一本化できる。
    - (a) `intpD` で x を元の画像の座標に戻すかどうか。`pkCentroid_interp2_1cycle.m`（164・168行）と `bilateral/bilateralOriInterp2_centroid.m` は戻すが、`paper/202609asj/fig_GrooveBtmOnImageUpsamplingD.m` は戻さない。
    - (b) ループの上限が `map.nCols` か `imgData.width` か。`intpD` では列の数が `1/step` 倍なので、`width` までだと写真の左の一部しか調べない（`fig_GrooveBtmOnImageUpsamplingD.m`）。
    - (c) `GroovePointCloud` を、どの暗さ行列から作るか。`fig_GrooveBtmOnImageUpsamplingD.m` の `pts_max_rsmpl` は、`rsmplD` ではなく `origD` から作っている。
  - 溝底範囲（start・end）を元の画像の座標に戻す式も、4本（`paper/202609asj/fig2_darknessProfile.m`、`slides/202609asj/darknessProfile.m`、`progress/grooveOnImageManualAndTrack.m` の `grooveBottomRange`、`pkCentroid_resample.m`）で書き写されている。
- 今の重複（30本）
  - 現役：`pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`grooveTrack_1cycle.m`、`grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`、`progress/grooveOnImageManualAndTrack.m`、`progress/showPhotoshopGrooveExtraction.m`、`evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`
  - バイラテラルフィルタの検討：`bilateral/` の5本（4本はローカル関数 `detectCentroidPoints` として同じものを持つ）
  - 学会用：`paper/202609asj/` の8本、`slides/202609asj/` の5本
  - 動かないもの・検討用：`pkCentroid_resample.m`、`pkCentroid_interp2.m`、`photoshop_centroid_1cycle.m`
- 仕様

  ```matlab
  function [pts, ranges] = detectGroovePoints(map, widthThresh, opts)
      arguments
          map (1,1) DarknessMap                          % setDiffTF を済ませたもの
          widthThresh (1,1) double {mustBePositive}      % 溝底範囲の幅の上限（元の画像のpx。WIDTH_THRESH）
          opts.Methods (1,:) string {mustBeMember(opts.Methods,["centroid","localMax"])} = ["centroid","localMax"]
      end
  ```

  出力は次の2つである。

  - `pts`：`Methods` の手法ごとのフィールド（`pts.centroid`、`pts.localMax`）を持つ struct。各フィールドは `GroovePointCloud(map)` で作り、`peakCells{x}` に `[xOrig*ones(n,1), y]` を入れたもの。
  - `ranges`：溝底範囲の始めと終わり。`ranges.start`・`ranges.end` はどちらも `N×2` の `[xOrig, yOrig]`（N は全列の溝底点の数）。行の順は、`vertcat(pts.centroid.peakCells{:})` の点の順と同じにする。

  処理の手順は次のとおり。

  1. `map.diffTF` が空なら、`detectGroovePoints:noDiffTF` で止める（`setDiffTF` の呼び忘れを見つけるため）。
  2. `extractor = GrooveExtractor(map)` を作る。
  3. `x = 1:map.nCols` の各列について、次を行う。
     - (1) `findThresholdIntervals` → `findGrooveBottomIntervals(map, x, firstIdx, lastIdx, widthThresh)` で溝底範囲を求める。
     - (2) 列の番号を元の画像の座標に戻す：`xOrig = 1 + (x-1)/map.scaleFactor.col`。`origD`・`rsmplD` は `scaleFactor.col = 1` なので x のまま、`intpD` は `1 + (x-1)*step` になる（`pkCentroid_interp2_1cycle.m` と同じ値）。
     - (3) `Methods` に含まれる手法だけ、`extractByCentroid`・`extractByLocalMax` で y を求め、`peakCells{x}` に入れる。y はこの2つのメソッドの中で元の画像の座標に戻されている。
     - (4) 溝底範囲の行番号を `(idx-1)/map.scaleFactor.row + 1` で元の画像の座標に戻し、`ranges` に足す。
  4. `ranges` は、2つ目の出力を受け取るとき（`nargout >= 2`）だけ作る。

- 置き換え方
  - `_1cycle` 系では、セグメントごとのループの中身が次の2行になる。

    ```matlab
    pts = detectGroovePoints(origD, WIDTH_THRESH);
    pts_cnt = pts.centroid;  pts_max = pts.localMax;
    ```

  - 溝底範囲を描くスクリプトは `[pts, ranges] = detectGroovePoints(...)` を使い、`ranges.start(ranges.start(:,1) == X_C, 2)` のように列で絞る。
  - `fig_grooveShape*Comparison.m` は、表示する列の範囲だけを調べているが、全列を調べてから範囲で絞っても結果は同じである（1セグメントなので時間もかからない）。
- 注意
  - 上の食い違い (a)(b)(c) は、置き換えると正しい形にそろう。そのため、`fig_GrooveBtmOnImageUpsamplingD.m` だけは計算する値が変わる。ただし、変わる値（`intpD` の点・`pts_max_rsmpl`）は図に描かれていないので、図は変わらない。置き換えた後に PNG を比べて確かめる。
  - 次の2つは、この関数では置き換えない。
    - `photoshop_*_1cycle.m` は、溝底範囲の幅に下限（`W_MIN`）も付けている。今の `GrooveExtractor` に下限は無い（[9章](#9-ユーザーが決めること) の Q3）。
    - `compareInclBoundToExclBound.m` は、溝底の判定そのものを比べるために、すべての区間の幅と古い判定を独自に書いている。評価の手段なので、そのまま残す。
  - `GroovePointCloud(map)` は `peakCells` を `cell(1, width)` で作る。`intpD` では `nCols > width` なので、代入すると cell が伸びる。今のスクリプトと同じ動きなので、変えない。
  - `GrooveExtractor` はメソッドを呼ぶたびに自分のコピーを返す値クラスである。ループの中で `extractor = extractor.findGrooveBottomIntervals(...)` と代入し直すこと。
- テスト
  - 合成の暗さ行列（[`test/unit/GroovePipelineTest.m`](../../test/unit/GroovePipelineTest.m) のような、波打つ1本の溝）で、今のループを手で書いた結果と `isequal` になること（`origD`・`rsmplD`・`intpD` のそれぞれ）。
  - `intpD` で x が `1 + (x-1)*step` になること。
  - `Methods="centroid"` のときに `pts` が `localMax` を持たないこと。
  - `ranges` の行の数が溝底点の数と同じで、y が元の画像の座標であること。
  - しきい値を超える区間が無い列（ホコリで覆われた列）で止まらないこと。
  - `setDiffTF` を呼んでいない `map` で `detectGroovePoints:noDiffTF` が出ること。
- 評価：影響は大、重要度は高
  - 影響：30本を変え、cycleResult の点群を作る中心の処理を置き換える。実データで前後の結果を比べる必要がある。
  - 重要度：最も重複が多く、すでに食い違いが生まれている。新しい検出法を足すときも、この関数を直すだけで済む。

#### B2 `detectPhotoGroovePoints`：写真1枚分の溝底点を一度に求める

- 目的
  - `_1cycle`・`_Ncycle` スクリプトのセグメントのループ（読み込み → 暗さ行列 → 高解像度化 → 溝底点）は、スクリプトごとに約35行ある。A2 と B1 をつなぎ、高解像度化の条件も引数で選べるようにすると、7本のスクリプトの中心のループが数行になる。
  - スクリプトの中心の処理が関数になると、実データで結果が変わらないことを自動で確かめるテスト（実データがあるときだけ動き、無ければ飛ばすもの）を書きやすくなる。
- 今の重複
  - `pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`grooveTrack_1cycle.m`、`grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`、`bilateral/bilateralOri_centroid_1cycle.m`
  - `photoshop_*_1cycle.m` は、溝底点の求め方が独自なので対象にしない（`centroid` は幅の下限付きの判定で [9章](#9-ユーザーが決めること) の Q3 次第、`localMax` は `findpeaks` を使う）。
- 仕様

  ```matlab
  function [imgs, pts, maps] = detectPhotoGroovePoints(filenames, iImg, opts)
      arguments
          filenames (:,1) string
          iImg (1,1) double {mustBeInteger,mustBePositive}
          opts.NumSegments (1,1) double {mustBeInteger,mustBePositive} = 10
          opts.LMask (1,1) double = 20
          opts.DThresh (1,1) double = 0.6
          opts.WidthThresh (1,1) double {mustBePositive} = 8
          opts.Upsampling (1,1) string {mustBeMember(opts.Upsampling,["origD","rsmplD","intpD"])} = "origD"
          opts.PRsmpl (1,1) double {mustBePositive} = 8     % rsmplD のときだけ使う
          opts.QRsmpl (1,1) double {mustBePositive} = 1
          opts.QueryStep (1,1) double {mustBePositive} = 0.125  % intpD のときだけ使う
          opts.InterpMethod (1,1) string = "spline"
          opts.Methods (1,:) string = ["centroid","localMax"]
          opts.PhotoDir (1,1) string = ""
          opts.ImageFilter = []
      end
  ```

  - 既定値は、今の `pkCentroid_*_1cycle.m` の値と同じにする。スクリプトは、冒頭のパラメータ（`L_MASK` など）を必ず明示して渡す（パラメータを冒頭にまとめる決まりを守るため）。
  - 出力は次の3つである。
    - `imgs`：`NumSegments×1` の `ImageData`（A2 の出力）
    - `pts`：手法ごとのフィールドを持つ struct。各フィールドは `NumSegments×1` の `GroovePointCloud`
    - `maps`：`NumSegments×1` の `DarknessMap`（高解像度化した後のもの）。3つ目の出力を受け取るときだけ返す。`intpD` では写真1枚分で数百MBになるため。

  処理の手順は次のとおり。

  1. `loadPhotoSegments(filenames, iImg, NumSegments, LMask, PhotoDir=..., ImageFilter=...)` で、セグメントの画像を得る。
  2. セグメントごとに、次を行う。
     - (1) `map = DarknessMap(imgs(j))` を作る。
     - (2) `Upsampling` で場合を分ける。
       - (a) `origD` のときは、そのまま使う。
       - (b) `rsmplD` のときは、`map = dResample(map, PRsmpl, QRsmpl)` にする。
       - (c) `intpD` のときは、`map = dInterp(map, QueryStep, InterpMethod)` にする。
     - (3) `map = map.setDiffTF(DThresh)` を呼ぶ。
     - (4) `detectGroovePoints(map, WidthThresh, Methods=Methods)` で溝底点を求める。
- 置き換え方
  - `_1cycle` 系では、写真のループの中身が次の形になる。手動選択（`fitGroove`）の処理は、この後にセグメントのループとして残す。

    ```matlab
    ks = segmentIndices(iImg, NUM_SEGMENTS);
    [allImg(ks), pts] = detectPhotoGroovePoints(filenames_new, iImg, NumSegments=NUM_SEGMENTS, ...
        LMask=L_MASK, DThresh=D_THRESH, WidthThresh=WIDTH_THRESH, Upsampling="intpD", ...
        QueryStep=QUERY_STEP, InterpMethod=INTERP_METHOD);
    allPts_cnt(ks) = pts.centroid;  allPts_max(ks) = pts.localMax;
    ```

  - バイラテラルフィルタの1周のスクリプトは、条件ごとに `ImageFilter` を変えて呼ぶ（写真を条件の数だけ読むが、今もセグメントごとに読んでいるので遅くはならない）。
- 注意
  - `origD` の `setDiffTF` を高解像度化の前にも呼んでいるスクリプトがあるが、高解像度化した行列の判定には使われていない。呼ばなくても結果は変わらない。
  - `pkCentroid_interp2_1cycle.m` は80セグメント分の `DarknessMap`（`allIntpD`、合計で約2GB）をメモリに持っているが、保存にも使っていない。置き換えるときに持たないようにしてよい。
  - `pkCentroid_1cycle.m` などは、写真の中では、`fitGroove` で前のセグメントの右端の点 `p2` を次のセグメントの左端にしている（各写真の最初のセグメントだけ、左端もクリックする）。検出とセグメントの選択を別のループに分けても、選択のループの順を同じにすれば結果は変わらない。
- テスト
  - 合成の PNG を一時フォルダに書き、`Upsampling` の3通りで、A2 と B1 を手で順に呼んだ結果と `isequal` になること。
  - `nargout < 3` のとき `maps` を作らないこと（作らないことは、関数の中で `nargout` を見ていることをコードで確かめる程度でよい）。
- 評価：影響は大、重要度は高
  - 影響：7本の中心のループを置き換え、cycleResult の値を作る処理に直接触れる。実データで前後の結果を比べる必要がある。
  - 重要度：スクリプトが大幅に短くなり、新しい条件（例：フィルタ、別の高解像度化）を試すスクリプトを作るのが楽になる。実データでの回帰テストの土台にもなる。

### C. 溝の選択と、形状の保存の形

#### C1 `selectGrooveSegment`：`fitGroove` の手動選択と再現を切り替える

- 目的
  - 手動選択のスクリプトは、セグメントごとに「前の cycleResult が無ければ図を出してクリックさせ、あれば再現する」という同じ分岐を持つ。
- 今の重複
  - `pkCentroid_1cycle.m`（112〜128行）、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`photoshop_*_1cycle.m`。`bilateral/bilateralOri_centroid_1cycle.m` は再現の側だけを持つ。
- 仕様

  ```matlab
  function [p1, p2, pksCorCell] = selectGrooveSegment(imgData, ptsList, jSegment, p2Prev, hPrl, opts)
      arguments
          imgData (1,1) ImageData
          ptsList (1,:) GroovePointCloud      % 補正する点群（例：[pts_max, pts_cnt]）。この順で pksCorCell が返る
          jSegment (1,1) double
          p2Prev (1,2) double                 % 前のセグメントの p2（fitGroove の第3引数）
          hPrl (1,1) double                   % 平行四辺形の高さ（h_prl）
          opts.Selection = []                 % 前の結果の grooveSelection（p1・p2 が 80×2）。[] なら手動で選ぶ
          opts.K (1,1) double = NaN           % セグメントの通し番号（Selection を使うときは必須）
          opts.Title (1,1) string = ""
      end
  ```

  - 点群 `pksCell` は、`ptsList` の各要素の `vertcat(peakCells{:})` で作る。
  - `Selection` で場合を分ける。
    - (a) `Selection` が空のときは、`figure` を作り、`imgData.showImage()` の上に各点群を `showPoints()` で描いて、`fitGroove(jSegment, fig, p2Prev, imgData.width, hPrl, pksCell)` を呼ぶ。
    - (b) `Selection` があるときは、図を作らずに `fitGroove(jSegment, [], p2Prev, imgData.width, hPrl, pksCell, P1=Selection.p1(K,:), P2=Selection.p2(K,:))` を呼ぶ。`K` が `NaN` なら `selectGrooveSegment:noIndex` で止める。
- 注意
  - 平行四辺形の幅 `w_prl` は、今のスクリプトでも常に `imgData.width` なので、引数にしない。
  - 手動の側（a）は `ginput` を使うので、自動のテストでは確かめられない。置き換えた後に、ユーザーが1回動かして確かめる必要がある。
- テスト
  - (b) の側だけを確かめる。保存した `p1`・`p2` を渡したときに、`fitGroove` を直接呼んだ結果と同じになること。図が作られないこと（`groot().Children` の数が増えない）。
- 評価：影響は中、重要度は低
  - 影響：`ginput` の操作に触れ、ユーザーの確認が要る。
  - 重要度：手動選択は、自動追跡（issue #25）に置き換わりつつある。新しい作業で使う見込みは小さい。

#### C2 `clickGrooveSeeds`：写真の左端で、追跡する溝をクリックさせる

- 目的
  - 自動追跡の3本のスクリプトが、写真を表示して溝の始点をクリックさせる処理（図・点・表示範囲・タイトル・`ginput`・クリックの数の確認）をそれぞれ持つ。
- 今の重複
  - `grooveTrack_1cycle.m`（140〜150行）、`grooveHist_Ncycle.m`（163〜177行）、`grooveTrack_Ncycle.m`（162〜186行）
- 仕様

  ```matlab
  function clicksY = clickGrooveSeeds(photoImg, pks, numClicks, opts)
      arguments
          photoImg (1,1) ImageData        % 写真1枚分（A2 の2つ目の出力）
          pks (:,2) double                % 写真1枚分の溝底点（mergeSegmentPoints の出力）
          numClicks (1,1) double {mustBeInteger,mustBePositive} = 1
          opts.ViewWidth (1,1) double = Inf   % 表示する、左端からの幅[px]
          opts.GuideY (1,:) double = []       % 目安の y。1列目に黄色の三角で示す
          opts.Title (1,1) string = ""        % クリックを促す文（日本語可、Interpreter="none"）
          opts.MarkerSize (1,1) double = 4
      end
  ```

  処理の手順は次のとおり。

  1. `figure` を作り、`photoImg.showImage("fit")` で写真を描く。
  2. x が `ViewWidth` 以下の溝底点を、水色で重ねる。`GuideY` があれば、1列目に黄色の三角を描く。`ViewWidth` が有限なら、`xlim([0.5, ViewWidth+0.5])` にする。
  3. `ginput(numClicks)` でクリックを受け、図を閉じる。
  4. クリックの数が `numClicks` と違えば、`clickGrooveSeeds:clickCount` で止める。
  5. クリックの **y だけ** を、クリックした順の列ベクトルで返す。始点の x は呼び出し側で写真の1列目に固定する決まり（README「溝の自動追跡」）なので、x は返さない。並べ替え（外側から）も呼び出し側で行う。
- 注意
  - 今の3本は、点の大きさ（2 と 4）と表示範囲が少しずつ違う。クリックのための図なので、そろえて構わない。
- テスト
  - `ginput` を使うので、単体テストは書かない（書けない）。置き換えた後に、ユーザーが1回クリックして確かめる。
- 評価：影響は小、重要度は低
  - 3本だけで、クリックの図は保存しないので、結果に影響しない。

#### C3 `splitPhotoShape`・`segmentEndPoints`：写真1枚分の形状をセグメントごとに分け直す

- 目的
  - 自動追跡は写真1枚分の y を作るが、保存の形はセグメントごとの cell（`ycoords` が 80×1 または 80×N）である。分け直す処理と、各セグメントの両端の点（`p1`・`p2`）を求める処理が、3本に書き写されている。保存の形に関わるので、1か所にして食い違いを防ぐ。
- 今の重複
  - `grooveTrack_1cycle.m`（133〜137行の数の確認、167〜179行）、`grooveHist_Ncycle.m`（156〜160行、186〜203行）、`grooveTrack_Ncycle.m`（155〜159行、199〜204行、229〜233行）
- 仕様

  ```matlab
  function [ycoordsSeg, xcoordsSeg] = splitPhotoShape(y, counts, widths, opts)
      arguments
          y (:,1) double          % 写真1枚分の y（xQuery と同じ長さ）
          counts (:,1) double     % セグメントごとの列の数（mergeSegmentPoints の3つ目の出力）
          widths (:,1) double     % セグメントごとの幅[px]（GroovePointCloud.width）
          opts.QueryStep (1,1) double {mustBePositive} = 1
      end

  function [p1, p2] = segmentEndPoints(yAbs, counts, widths)
  ```

  - `splitPhotoShape` は次を行う。
    1. `sum(counts) ~= numel(y)` なら `splitPhotoShape:countMismatch` で止める（今の3本の `countMismatch` の確認と同じ）。
    2. `ycoordsSeg = mat2cell(y, counts)` を作る（`numSegments×1` の cell）。
    3. `xcoordsSeg{j} = (1:QueryStep:widths(j))'` を作る。各 `numel(xcoordsSeg{j})` が `counts(j)` と違えば `splitPhotoShape:widthMismatch` で止める。
  - `segmentEndPoints` は、デトレンド前の y（`yAbs`）から、各セグメントの左端・右端の点を返す。`lastIdx = cumsum(counts)`、`firstIdx = lastIdx - counts + 1` として、`p1 = [ones, yAbs(firstIdx)]`、`p2 = [widths, yAbs(lastIdx)]`（どちらも `numSegments×2`）。古い再現スクリプトが `grooveSelection.p1`・`p2` を使うため、今の値と同じにする。
- 置き換え方
  - `ycoords_cnt(ks, jGroove) = splitPhotoShape(shape(:,2), counts, widths);` のように使う。`xcoords` は2つ目の出力から入れる。
- テスト
  - 合成の `y`・`counts`・`widths` で、今の書き方と `isequal` になること。`QueryStep=0.25` のときに `xcoordsSeg` の刻みが 0.25 になること。数が合わないときに2つのエラーが出ること。
- 評価：影響は中、重要度は中
  - 影響：保存する `ycoords`・`xcoords`・`p1`・`p2` を作る処理なので、置き換えた後に保存済みの結果と比べる必要がある。
  - 重要度：N周分の保存の形（80×N）を守る処理で、N周分の作業が続くなら使う。

#### C4 `trackingRecord`・`trackingArgs`：追跡のパラメータと結果を保存の形にまとめる

- 目的
  - 追跡のスクリプト3本は、`grooveSelection.tracking` に入れる struct を、14個のフィールドを1行ずつ代入して作っている。評価スクリプトは、このフィールド名がそろっていることを確かめている（`compareTrackingToManual.m` の `needTrk`）。作る側を1か所にすれば、名前の書き間違いが起きない。
  - 評価スクリプト2本は、保存したパラメータから `trackGroove` の name-value 引数を手で並べ直している。保存の形から引数を作る関数があれば、パラメータを足したときに直す所が1か所になる。
- 今の重複
  - 作る側：`grooveTrack_1cycle.m`（249〜263行）、`grooveHist_Ncycle.m`（285〜299行）、`grooveTrack_Ncycle.m`（315〜329行）
  - 引数を並べる側：`grooveTrack_1cycle.m`（157〜162行）、`grooveTrack_Ncycle.m` の `trackArgs`、`grooveHist_Ncycle.m` の `mgArgs` の一部、`evaluation/grooveTracking/compareTrackingToManual.m`（152〜154行）、`evaluation/multiGroove/compareHistToTracking.m`（203行・528行）
- 仕様

  ```matlab
  function trk = trackingRecord(opts)
      arguments
          opts.Tolerance (1,1) double     % 以下、必須（既定値なし）。trackGroove の引数と同じ意味
          opts.FitLength (1,1) double
          opts.SnapRadius (1,1) double
          opts.InitLength (1,1) double
          opts.MaxGapLength (1,1) double
          opts.MinFitPoints (1,1) double  % trackGroove の中の定数（記録用）
          opts.QueryStep (1,1) double
          opts.PolyDegree (1,1) double
          opts.AmpDivisor (1,1) double
          opts.DetrendScope (1,1) string = "photo"
          opts.YAbsCnt (:,1) cell = {}    % 写真ごとのデトレンド前の y（重心法）
          opts.YAbsMax (:,1) cell = {}
          opts.FoundCnt (:,1) cell = {}   % 写真ごとの、点を採れた列
          opts.FoundMax (:,1) cell = {}
      end

  function args = trackingArgs(trk)
  ```

  - `trackingRecord` は、今のスクリプトと同じフィールド名（`tolerance`・`fitLength`・`snapRadius`・`initLength`・`maxGapLength`・`minFitPoints`・`queryStep`・`polyDegree`・`detrendScope`・`ampDivisor`・`yAbsCnt`・`yAbsMax`・`foundCnt`・`foundMax`）の struct を返す。cell を `struct()` に直接渡すと struct 配列になるので、ドット記法で組み立てる（今のスクリプトの注意書きと同じ）。必須の値が欠けていれば `trackingRecord:missingParam` で止める。
  - `trackingArgs(trk)` は、`trackGroove` に渡す `{"Tolerance", trk.tolerance, "FitLength", ..., "MaxGapLength", ...}` の cell を返す。呼び出し側は `args = trackingArgs(trk); trackGroove(pks, seed, xQuery, args{:})` と使う。
- 置き換え方
  - スクリプトは、パラメータ部分だけの `trk` を先に作り、`trackingArgs(trk)` で追跡し、最後に `yAbs*`・`found*` を足して保存する。
  - `multiGroove` の struct（`grooveHist_Ncycle.m` と `grooveTrack_Ncycle.m` で中身が違う）は、それぞれ1本ずつなので、まとめない。
- テスト
  - フィールド名の一覧が、上の14個とちょうど同じであること。`trackingArgs` の値を `trackGroove` に渡して、引数を手で並べたときと同じ結果になること。
- 評価：影響は中、重要度は中
  - 影響：保存の形を作る処理なので、置き換えた後に、保存済みの結果のフィールドと `isequal` で比べる。
  - 重要度：保存の形の食い違いを防ぎ、評価スクリプトとの約束を1か所で守れる。

#### C5 `methodFieldName`：手法の名前から保存のフィールド名を作る

- 目的
  - 保存の形では、手法ごとの値のフィールド名が `yAbsCnt`（重心法）・`yAbsMax`（局所的最大値法）のように終わる。手法の名前（`"centroid"`・`"localMax"`）からこの名前を作る処理が、4本でそれぞれ書かれている。
- 今の重複
  - `evaluation/multiGroove/compareHistToTracking.m` の `fieldFor`、`evaluation/grooveTracking/compareTrackingToManual.m` の `trackingFields`、`progress/multiGrooveOnePhoto.m` と `progress/grooveOnImageManualAndTrack.m` の `suffix` の if 文
- 仕様
  - `name = methodFieldName(method, base)` は、`method` が `"centroid"` なら `base + "Cnt"`、`"localMax"` なら `base + "Max"` を返す。それ以外は `methodFieldName:unknownMethod` で止める。
- テスト
  - 2つの手法と、知らない手法のエラー。
- 評価：影響は小、重要度は低
  - 置き換えは機械的で、得られるものも小さい。C4 と一緒に行うとよい。

#### C6 `extractGrooveShape` に、使った点の出力を足す

- 目的
  - 手動選択で、どの溝底点を溝形状に使ったかを知りたいスクリプトは、`extractGrooveShape` の中と同じ範囲の式（中心から ±`Tolerance`）を書き写している。関数がその点を返せば、書き写しが要らない。
- 今の重複
  - `progress/grooveOnImageManualAndTrack.m`（`inGroove` の計算）、`pkCentroid_resample.m`（4か所。動かないスクリプト）
- 仕様
  - `[points, inGroove] = extractGrooveShape(pksCor, grooveCenter, xQuery, Tolerance=...)` とし、2つ目の出力 `inGroove` に、`pksCor` の各行が範囲に入ったかを表す logical の列ベクトルを返す。1つ目の出力は今と同じにする。
- テスト
  - 既存の `ExtractGrooveShapeTest` に、`inGroove` が範囲の式と一致することを足す。
- 評価：影響は小、重要度は低
  - 既存の関数に出力を1つ足すだけで、呼び出し側は1本である。

### D. 音声

#### D1 `makeCycleAudio`：連結した y 座標から音声を作る

- 目的
  - 1周分の y 座標から、標本化周波数を決め、平均を引いて振幅を正規化し、`AudioData` を作る処理が、10本にある。標本化周波数の決め方（1周のサンプル数 ÷ 1周の時間 60/78 秒）は、音声の時間軸を決める大事な定義である。
- 今の重複
  - `pkCentroid_1cycle.m`（170〜191行）、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`grooveTrack_1cycle.m`（210〜219行）、`grooveHist_Ncycle.m`（242〜253行）、`grooveTrack_Ncycle.m`、`bilateral/bilateralOri_centroid_1cycle.m`、`photoshop_*_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`
- 仕様

  ```matlab
  function [audio, info] = makeCycleAudio(yComb, name, opts)
      arguments
          yComb (:,1) double              % 連結した y 座標（vertcat(ycoords{:})）
          name (1,1) string               % AudioData の名前（wav のファイル名にもなる）
          opts.AmpDivisor (1,1) double {mustBePositive}  % 必須。振幅の正規化 [px]（今の tol/2 や AMP_DIV）
          opts.Rpm (1,1) double {mustBePositive} = 78
          opts.SamplesPerCycle (1,1) double {mustBePositive} = numel(yComb)  % 1周のサンプル数
      end
  ```

  - `fs = round(SamplesPerCycle / (60/Rpm))`、`amp = (yComb - mean(yComb)) / AmpDivisor` とし、`audio = AudioData(name, amp, fs)` を返す。計算の順は今のスクリプトと同じにする（浮動小数点の値をそろえるため）。
  - `info.fs` と、±1を超えたサンプルの数 `info.numClipped` を返す。
  - N周分では、`SamplesPerCycle` に1周目の列の数（`sum(cellfun(@numel, ycoords(:,1)))`）を渡す。
- 注意
  - 保存する `y_comb`（平均を引く前の値）は今のまま、スクリプトで作って `cycleMethodResult` に渡す。
- テスト
  - 合成の `yComb` で、今の式で作った `signal`・`fs` と `isequal` になること。`SamplesPerCycle` を変えたときに `fs` だけが変わること。
- 評価：影響は中、重要度は中
  - 影響：10本を変えるが、数値が同じことは単体テストと [5章](#出力が変わらないことの確かめ方) の比較で簡単に確かめられる。
  - 重要度：音声の時間軸の定義を1か所にできる。

#### D2 `saveAudioFigures`：音声の3つの図と wav を保存する

- 目的
  - 音声ごとに「波形・FFT・スペクトログラムの図を作って fig と png で保存し、wav を書く」処理が、10本に書き写されている。この10本には `saveas` の行が計88行あり、その大半がこの3つの図の保存である。
  - 今の書き方は、`docs/rules/figures.md` の決まり（保存関数を使う、`AudioData.filename` を図の名前に使わない、同じ名前のファイルを上書きしない）に合っていない。関数にすれば、決まりに合わせやすい。
  - `src/soundCheck.m` は同じ目的の古い関数だが、動かない `evaluation/stylus/sound_from_stylus.m` の中のコメントにしか出てこない。
- 今の重複
  - D1 と同じ10本
- 仕様（名前の付け方が決まってから確定する）

  ```matlab
  function files = saveAudioFigures(audio, outDir, opts)
      arguments
          audio (1,1) AudioData
          outDir (1,1) string
          opts.BaseName (1,1) string          % 図の名前の元（Q2 の決定で既定を決める）
          opts.WinSize (1,1) double = 1024    % スペクトログラムの窓長
          opts.SaveWav (1,1) logical = true
          opts.Overwrite (1,1) logical = false
          opts.Visible (1,1) logical = true
      end
  ```

  処理の手順は次のとおり。

  1. 図を作り、`audio.plotWaveform()` を描いて、`<BaseName>_amp` の名前で保存して閉じる。
  2. 同じように `plotFFT()` を `<BaseName>_fft`、`plotSpectrogram(WinSize)` を `<BaseName>_stft` で保存する。
  3. `SaveWav` なら、`audio.saveAudio(outDir)` で wav を書く。同じ名前の wav があり、`Overwrite` が false なら、`saveAudioFigures:fileExists` で止める（今の `audiowrite` は黙って上書きする）。
- 注意
  - 図の名前をどうするかで、保存の方法が変わる（[9章](#9-ユーザーが決めること) の Q2）。
    - (a) 今の名前（`audio_(centroid_method)(original)_amp` など）を保つときは、`saveFigure` を使うと名前の確かめで警告が出る。過去の実行フォルダの図と並べて比べやすい。
    - (b) 語彙表の名前（例：`waveform_origD_centroid_track_<日付>`）にするときは、`saveFigure` で保存でき、決まりに合う。呼び出し側が `BaseName` を組み立てる。
  - スペクトログラムの窓長は、スクリプトごとに 1024 と 8192 がある。引数で渡す。
- テスト
  - 一時フォルダに3つの図と wav ができること。同じ名前があるときに止まること。`Visible=false` で図が画面に出ないこと。
- 評価：影響は中、重要度は中
  - 影響：出力のファイル名と保存の方法が変わりうる。
  - 重要度：図のルールに合わせる効果がある。ただし、名前の決定が先に要る。

### E. 結果の読み込み

#### E1 `cycleResultFileName`・`cycleResultPath`・`saveCycleResult` に `Variant` を足す

- 目的
  - 結果ファイルの名前の決まり（`cycleResult_<高解像度化>_<日付>.mat`）は、`cycleResultFileName` が持っている。ところが、自動追跡や N 周分の結果（`cycleResult_origD_track_1014.mat`、`cycleResult_origD_hist5_1104.mat`、`cycleResult_origD_track5_<日付>.mat`）は、この関数で作れない。そのため、保存側も読み込み側も、15本のスクリプトが名前を手で組み立てている。README にも「`cycleResultPath` が `_track` に対応していない」と書かれている。
- 今の重複
  - 保存側：`grooveTrack_1cycle.m`（273行）、`grooveHist_Ncycle.m`（330行）、`grooveTrack_Ncycle.m`（356行）が `FileName=` で渡している。
  - 読み込み側：`evaluation/grooveTracking/compareTrackingToManual.m`、`evaluation/multiGroove/compareHistToTracking.m`、`evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`、`progress/` の5本、`paper/202609asj/fig6_spectrogramUpsampling.m`・`fig_waveformUpsampling.m`、`slides/202609asj/waveformAndSpectrogramUpsampling.m`・`waveformUpsampling.m`
- 仕様
  - `cycleResultFileName(upsampling, date, Variant="")` とする。名前は次のとおり。
    - (a) `Variant` が空なら、今と同じ `cycleResult_<upsampling>_<date>.mat`。
    - (b) 空でなければ、`cycleResult_<upsampling>_<Variant>_<date>.mat`（例：`Variant="track"` → `cycleResult_origD_track_1014.mat`、`Variant="hist5"` → `cycleResult_origD_hist5_1104.mat`）。
  - `Variant` は英数字だけ（正規表現 `^[A-Za-z][A-Za-z0-9]*$`）に限る。外れたら `cycleResultFileName:invalidVariant` で止める。
  - `cycleResultPath(rootFolder, upsampling, date, Variant="")` は、`Variant` を `cycleResultFileName` に渡すだけにする。探す場所（`experiments/` → `results/`）は今のまま。
  - `saveCycleResult(..., Variant="")` を足す。`FileName` が空のときの既定の名前に `Variant` を使う。`FileName` と `Variant` を両方渡したら `saveCycleResult:conflictingName` で止める。
  - 再実行で `_2` などが付いたファイル（`compareHistToTracking.m` の `GT_FILE` のように）は、今までどおりファイル名を直接書く。
- 置き換え方
  - 読み込み：`fullfile(experimentDir(rootFolder,DATE,Create=false), "cycleResult_origD_track_" + DATE + ".mat")` を `cycleResultPath(rootFolder, "origD", DATE, Variant="track")` にする。
  - 保存：`FileName="cycleResult_origD_hist" + NUM_GROOVES + "_" + date` を `Variant="hist" + NUM_GROOVES` にする。
  - 従来法の音声（`cycleResult_origD_0802.mat`）を `fullfile` で組み立てている4本は、`cycleResultPath(root, "origD", "0802")` にする。
- テスト
  - 既存の `CycleResultTest` が通ること（`Variant` を渡さなければ今と同じ）。`Variant` を渡したときの名前、不正な `Variant`、`FileName` との同時指定のエラー、`saveCycleResult(..., Variant="track")` で保存したファイルを `cycleResultPath(..., Variant="track")` で見つけられること。
- 評価：影響は小、重要度は高
  - 影響：既定の動きは変わらない（後方互換）。スクリプトの置き換えは機械的で、パスの文字列が同じことはすぐ確かめられる。
  - 重要度：保存と読み込みの名前の約束を1か所に戻す。手で組み立てた名前の打ち間違いは、ファイルが見つからないエラーとして後で出るので、早く直す価値がある。

#### E2 `loadCycleAudio`：結果ファイルから音声を取り出す

- 目的
  - 図のスクリプトは、cycleResult を読み、手法ごとの音声があるかを確かめてから取り出す。この確かめが7本にあり、エラーの識別子が `fig5:noAudio` のまま書き写されている。従来法の音声を読む部分（4本）は、`loadCycleResult` を使わずに `load` していて、1本（`fig_waveformUpsampling.m`）は `load` の行がコメントになったまま動かない。
- 今の重複
  - `paper/202609asj/` の4本（`fig5_spectrogramComparisonOrigD.m`、`fig6_spectrogramUpsampling.m`、`fig_waveformComparisonOrigD.m`、`fig_waveformUpsampling.m`）、`slides/202609asj/` の3本（`waveformAndSpectrogramOrigD.m`、`waveformAndSpectrogramUpsampling.m`、`waveformUpsampling.m`）
- 仕様
  - `audios = loadCycleAudio(matPath, methods)` は、`loadCycleResult(matPath)` で読み、`methods`（string の行ベクトル、例：`["localMax","centroid"]`）の順に `AudioData` の行ベクトルを返す。
  - 手法のフィールドが無い、`audio` が空、または `AudioData` でないときは、`loadCycleAudio:noAudio` で止める。メッセージにファイルのパスと手法を書く。
- 注意
  - 従来法のファイル（`cycleResult_origD_0802.mat`）は `saveCycleResult` で保存したものなので、`load(...).result` と `loadCycleResult(...)` は同じ中身のはずである。置き換える前に、実際に同じであることを確かめる。
- テスト
  - `TemporaryFolderFixture` で小さな cycleResult を保存し、音声を取り出せること。手法が無いときのエラー。
- 評価：影響は小、重要度は低
  - 学会用のスクリプトだけが使う。次の学会の図で使うときに行えばよい。

### F. 図

#### F1 `figureDir`：図の置き場所を作って返す

- 状態：issue #28 で、下の仕様のとおり `src/figureDir.m` を作り、図のスクリプト32本の4行を置き換えた。そのとき、スライド用・原稿用の置き場所を発表名ごとにまとめる形に変えた（最初の案は `results/figures/<用途>/<会議>/` だった）。
- 目的
  - `docs/rules/figures.md` は、用途ごとの図の置き場所を決めている。この場所を `fullfile(..., "results","figures", <用途>, <名前>)` と組み立て、無ければ作る4行が、図のスクリプトに書き写されていた。
- 仕様（issue #28 で作ったもの）

  ```matlab
  function saveDir = figureDir(rootFolder, purpose, name)
      arguments
          rootFolder (1,1) string
          purpose (1,1) string {mustBeMember(purpose,["progress","slides","paper"])}
          name (1,1) string   % 進捗報告用はテーマ（"grooveTracking"）、スライド用・原稿用は発表名（"202609asj"）
      end
  ```

  - (a) `purpose` が `"progress"` のときは、`results/figures/progress/<name>` を返す。`name` が camelCase でなければ `figureDir:invalidTheme` で止める。
  - (b) `"slides"`・`"paper"` のときは、`results/figures/<name>/<purpose>` を返す。`name` が「年月6桁＋略称」（正規表現 `^\d{6}[a-z]+$`）でなければ `figureDir:invalidVenue` で止める（figures.md の決まり）。
  - フォルダが無ければ作る。戻り値の末尾に区切り文字は付けない（`fullfile(saveDir, ...)` で使う）。
  - 作業用の図は、実験の実行フォルダ（`resultDir` が作る `results/<実験名>/<YYYY-MMDD>[_<説明>]/`）に出す。
- テスト
  - 一時フォルダの下にフォルダができ、パスが返ること。会議の名前の形のエラー。
- 評価：影響は小、重要度は中
  - 影響：34本の置き換えは機械的で、パスの文字列は変わらない。
  - 重要度：図の置き場所の決まりを、コードで守らせられる。次の学会の図のスクリプトから使える。

#### F2 `showPhoto`：撮影画像を、表示範囲 [0 255] に固定して描く

- 目的
  - figures.md は、撮影画像を描くときに表示範囲を [0 255] に固定することを求めている（見え方を変えるのは実験データの改変にあたるため）。`imagesc` → `colormap gray` → `clim([0 255])` → `axis image` → 軸の向き・ラベルの組が、17本に24か所ある。`clim` を書き忘れると、決まりを破った図ができてしまう。
- 今の重複
  - `paper/202609asj/` の5本、`slides/202609asj/` の4本、`progress/` の3本（`grooveOnImageManualAndTrack.m` の `plotImageInRange` など）、`bilateral/` の4本の `showPointsOnImage`、`compareInclBoundToExclBound.m` の `plotPointsOnImage`
- 仕様

  ```matlab
  function im = showPhoto(ax, img, opts)
      arguments
          ax (1,1) matlab.graphics.axis.Axes
          img (:,:) {mustBeNumeric}               % 画素値 0〜255（uint8 か double）
          opts.XRange (1,:) double = 1:size(img,2) % 描く列（元の画像の座標）
          opts.YRange (1,:) double = 1:size(img,1) % 描く行
          opts.XAxisLocation (1,1) string {mustBeMember(opts.XAxisLocation,["top","bottom"])} = "top"
          opts.LabelUnit (1,1) string = ""         % "" なら "$x$"、"px" なら "$x$ [px]"
      end
  ```

  処理の手順は次のとおり。

  1. `imagesc(ax, img(YRange, XRange), XData=XRange([1 end]), YData=YRange([1 end]))` で描く。切り出しても、目盛りは元の画像の座標になる。
  2. `colormap(ax, gray)`、`clim(ax, [0 255])`、`axis(ax, "image")` を設定する。
  3. `set(ax, "YDir","reverse", "TickDir","out", "XAxisLocation", XAxisLocation)` を設定する。
  4. x・y の軸ラベルを付ける。
  5. 画像のハンドル `im` を返す。`hold on` は呼び出し側に任せる。
- 注意
  - 今の図は、x 軸の位置（上か下か）とラベルの単位が、用途ごとに違う。見た目を変えないよう、置き換えるときは今の設定を引数で渡す。
  - `ImageData.showImage`（`imshow` で描き、axes を指定できない）は、このまま残す。
- テスト
  - `figure("Visible","off")` で描き、`ax.CLim` が `[0 255]`、`ax.YDir` が `"reverse"` であること。切り出したときの `XData`・`YData`。
- 評価：影響は中、重要度は中
  - 影響：図の見た目に触れるので、置き換えた後に PNG を比べる必要がある。
  - 重要度：データの扱いに関わるルールを、書き忘れなく守らせられる。

#### F3 `pointsInView`：描く範囲にある点だけを残す

- 目的
  - 切り出した画像に点を重ねるとき、範囲の中の点だけを選ぶ式（と、切り出した左上を原点にずらす式）が、7本にある。
- 今の重複
  - `bilateral/` の4本の `cropView`、`progress/grooveOnImageManualAndTrack.m` の `pointsInView`、`progress/grooveBtmOnImageTrackOutlier.m`、`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m` の `inView`（x だけ）
- 仕様
  - `[pksView, inView] = pointsInView(pks, xRange, yRange, Shift=false)` は、`xRange`・`yRange` の端を含む範囲にある `pks` の行だけを返す。`Shift=true` なら、`[xRange(1)-1, yRange(1)-1]` を引いて、切り出した画像の座標にする（`cropView` と同じ）。y で絞らないときは `yRange=[-Inf Inf]` を渡す。
- テスト
  - 境界の点が残ること。`Shift` の有無。
- 評価：影響は小、重要度は低
  - 式は1〜2行である。F2 と一緒に行うとよい。

#### F4 `applyFontStyle`：原稿用・スライド用の文字の大きさをそろえる

- 目的
  - figures.md は、原稿用（目盛り 8 pt、軸ラベル 9 pt、凡例 8 pt）とスライド用（目盛り 14 pt、軸ラベル 16 pt）の文字の大きさを決めている。これを設定する4〜5行（`ax.FontSize`、`ax.LabelFontSizeMultiplier = 1`、`ax.XLabel.FontSize` など）が、16本に27か所ある。
- 仕様

  ```matlab
  function applyFontStyle(ax, purpose, opts)
      arguments
          ax (1,:) matlab.graphics.axis.Axes
          purpose (1,1) string {mustBeMember(purpose,["paper","slides"])}
          opts.Legend = []       % 凡例のハンドル（あれば目盛りと同じ大きさにする）
          opts.Colorbar = []     % カラーバーのハンドル（目盛り・ラベルの大きさをそろえる）
      end
  ```

  - 用途ごとの大きさは、関数の中の定数として持つ。figures.md の値を変えたら、この関数も直す（関数の説明にそう書く）。
  - 各 axes に、`FontSize`（目盛り）、`LabelFontSizeMultiplier = 1`、`XLabel`・`YLabel`・`ZLabel` の `FontSize`（軸ラベル）を設定する。
  - `tightenAxes` は呼ばない。カラーバーがある図で呼ぶとカラーバーが消える（figures.md の注意）ので、呼び出し側が決める。
- 注意
  - スライド用の一部のスクリプトは `LabelFontSizeMultiplier` を設定していないが、軸ラベルの大きさを直接設定しているので、結果の大きさは同じになるはずである。置き換えた後に PNG を比べて確かめる。
- テスト
  - `figure("Visible","off")` で、用途ごとの大きさになること。凡例・カラーバー。
- 評価：影響は中、重要度は中
  - 影響：見た目に触れる（PNG の比較が要る）。
  - 重要度：ルールの数値を1か所にでき、次の学会の図で必ず使う。

#### F5 `formatAudioAxes`・`addSharedColorbar`・`setSharedLabels`：音声の図の体裁

- 目的
  - 波形とスペクトログラムを原稿・スライドに載せるスクリプトは、描いた後に同じ体裁の処理をしている。8本に書き写されている。
    - 時間軸をデータの終わりまでに詰める（`findobj(ax,"Type","line")` の `XData` の最大）
    - 目盛りの間隔、LaTeX の目盛り、枠、タイトルを消す
    - 複数の図に共通のカラーバーと軸ラベルを付ける
- 仕様
  - `formatAudioAxes(ax, kind, opts)`：`kind` は `"waveform"` か `"spectrogram"`。name-value は `TStep`（時間の目盛り間隔、既定 0.2 s）、`YView`（波形の振幅の範囲、既定 [-1 1]）、`FView`（周波数の範囲、既定 [0 5000] Hz）、`FStep`（既定 1000 Hz）、`CView`（レベルの範囲、既定 [-120 0] dB）、`ClearTitle`（既定 true）、`ClearLabels`（共通の軸ラベルを使うとき true）。`fig5_spectrogramComparisonOrigD.m` の描画のループの中身と同じ処理をする。
  - `addSharedColorbar(ax, purpose, CView=..., CStep=30)`：`colorbar(ax)` を `Layout.Tile = "east"` に置き、目盛り・LaTeX・ラベル `Magnitude [dB]` と、F4 の文字の大きさを設定する。
  - `setSharedLabels(tl, xText, yText, purpose)`：`tiledlayout` の共通の軸ラベルに文字と LaTeX と大きさを設定する（`tiledlayout` のラベルには `setDefaultIntrpr` の既定が効かないため）。
- 注意
  - `AudioData.plotSpectrogram` のカラーバーのラベルは `Magintude` と綴りが誤っている。共通のカラーバーではこの綴りを使わない。`AudioData` の綴りを直すかどうかは別の話として扱う。
- テスト
  - 合成の `AudioData` を描き、`xlim` がデータの終わりになること、目盛り、カラーバーの位置。
- 評価：影響は中、重要度は低
  - 学会用のスクリプトだけが使う。次の学会の図を作るときに行えばよい。

### G. 評価

#### G1 `rmseCorr`・`longestRun`・`segmentsToPhotos`：溝形状の比べ方

- 目的
  - `docs/rules/evaluation.md` は、溝形状を RMSE [px] と Pearson の相関係数で比べると決めている。その計算 `rmseCorr` と、連続した欠損の長さを数える `longestRun` が、2本の評価スクリプトにまったく同じ形で書き写されている。今後の評価（issue #35 など）でも使う。
- 今の重複
  - `evaluation/grooveTracking/compareTrackingToManual.m` の `rmseCorr`・`longestRun`・`photoCells`・`fillCells`・`segmentMetrics`・`photoMetrics`
  - `evaluation/multiGroove/compareHistToTracking.m` の `rmseCorr`・`longestRun`
  - `trackGroove.m` の中にも、連続した欠損を数えるローカル関数 `longestMissingRun` がある（始まりの位置も返す）。
- 仕様
  - `[r, c] = rmseCorr(a, b)`：`r = sqrt(mean((a-b).^2))`。`isequal(a,b)` なら `c = 1`、そうでなければ `corrcoef(a,b)` の (1,2) 要素。今のローカル関数とまったく同じにする（評価の数値を変えないため）。長さが違えば `rmseCorr:sizeMismatch` で止める。
  - `n = longestRun(tf)`：logical のベクトルで、true が続く最も長い数を返す（無ければ 0）。
  - `photos = segmentsToPhotos(segCells, numSegments)`：セグメントごとの cell（80×1）を、写真ごとに縦につないだ cell（8×1）にする（`photoCells` と同じ）。
- 置き換え方
  - 2本の評価スクリプトのローカル関数を消し、`src/` の関数を呼ぶ。`segmentMetrics`・`photoMetrics` のような評価ごとの組み立ては、スクリプトに残してよい。
- テスト
  - 既知の値での RMSE・相関、同じ入力で相関が 1、定数の入力で `NaN`（今と同じ）、`longestRun` の端の場合。
- 評価：影響は小、重要度は中
  - 影響：評価スクリプト2本だけで、表の数値が同じことはすぐ確かめられる。
  - 重要度：評価の方法の決まりを関数で守らせ、次の評価スクリプトで書き写さずに済む。

#### G2 `sampleToColumn`・`findLargestDiff`：音声の外れの場所を求める

- 目的
  - 2つの音声の差が大きい時刻を探し、そのサンプルがどの写真・セグメント・列から来たかを求める処理が、2本の進捗報告のスクリプトに書き写されている。今の作業（issue #35、溝底の外れ）で使っている。
- 今の重複
  - `progress/grooveBtmOnImageTrackOutlier.m`（「外れたサンプルが…から来たかを求める」の節）、`progress/grooveOnImageManualAndTrack.m`（「切り出す範囲」の節）
- 仕様
  - `n = findLargestDiff(sigA, sigB, fs, tWin)`：時間 `tWin = [t0 t1]` [s] の中で、`|sigA - sigB|` が最大のサンプル番号を返す。サンプル n の時刻は `n/fs` とする（`AudioData.plotWaveform` と同じ）。
  - `loc = sampleToColumn(n, counts, numSegments)`：`counts = cellfun(@numel, ycoords)`（80×1 か 80×N）を受け取り、`vertcat(ycoords{:})` の n 番目のサンプルについて、次のフィールドを持つ struct を返す。
    - `k`：セグメントの通し番号（1〜80）
    - `jGroove`：何本目の溝（何周目）か（1周分なら 1）
    - `iImg`・`jSegment`：写真とセグメントの番号
    - `col`：セグメントの中の列
    - `photoCol`：写真1枚分の中の列（`grooveSelection.tracking.yAbsCnt{iImg}` の添字）
  - N周分では、`vertcat(ycoords{:})` が列の順（1本目の80セグメント → 2本目 …）になることを使い、線形の添字を `ind2sub(size(counts), ...)` で `k`・`jGroove` に分ける。
- テスト
  - 合成の `counts` で、セグメントの境目の前後のサンプル、2本目の溝のサンプルの対応。
- 評価：影響は小、重要度は中
  - 影響：2本だけで、図が同じ場所を切り出すことを確かめればよい。
  - 重要度：進行中の作業で使っていて、今後の外れの調査でも使う。

### H. スクリプトの冒頭

#### H1 `requireDateSet`：実行日が書き換えられていなければ止める

- 状態：issue #28 で、出力の日付の確認は `resultDir` が受け持つようになった。スクリプトには `date = "YYYY-MMDD"` と書いておき、書き換えずに実行すると `resultDir` がエラー（`resultDir:dateNotSet`）で止める。自動追跡の3本（`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`）の確認の4行は消した。評価スクリプト2本（`compareTrackingToManual.m`・`compareHistToTracking.m`）には、読み込みの日付が `"YYYY-MMDD"` のままなら止める確認が残っている。この候補は、その2本のためだけになった。
- 目的
  - 新しいスクリプトは、出力先の日付 `date` が `"MMDD"` のままなら止まるようにしている（過去の出力を上書きしないため）。この4行が5本にある。
- 仕様
  - `requireDateSet(dates, scriptName)` は、`dates`（string の配列）に `"MMDD"` が1つでもあれば、識別子 `"<scriptName>:dateNotSet"` で止める。識別子をスクリプトの名前で作るので、今のエラーの識別子は変わらない。
- 評価：影響は小、重要度は低
  - 4行の書き写しで、食い違いも無い。新しいスクリプトを作るときに使う程度でよい。

## 7. 先に決めたほうがよいこと：動かないスクリプト

読んでいるうちに、今のコードでは最後まで動かないスクリプトが6本見つかった。`test/unit/StaticAnalysisTest.m` は構文の誤りだけを調べるので、これらは CI を通っている。置き換えの前に、`archive/` へ移すか直すかを決めると、置き換えの手間が減る。

| スクリプト | 止まる所 | 確かめ方 |
|---|---|---|
| `pkCentroidAndLocalMax_resample_1cycle.m` | 92〜98行で、今の `DarknessMap` に無いメソッド（`startEndIdx`・`grooveBtmIdx`・`extractGrv_cnt`・`extractGrv_max`）を呼ぶ | `src/DarknessMap.m` のメソッドの一覧と照らした |
| `photoshop_centroid_1cycle.m` | 103〜104行で、`GrooveExtractor.startIdxCells`（`SetAccess=protected`）に書き込む | MATLAB で同じ代入をすると `MATLAB:class:SetProhibited` になることを確かめた |
| `pkCentroid_interp2.m` | 278行で、定義されていない `W_PRL`・`H_PRL` を使う（前半の図までは動く） | 変数の代入を検索した |
| `pkCentroid_resample.m` | 125行で、定義されていない `z` を使う（ほかに `th`・`imgHeight` も無い） | 変数の代入を検索した |
| `paper/202609asj/fig_waveformUpsampling.m` | 64行で、読み込んでいない `S` を使う（`S = load(...)` の行がコメント） | 該当の行を読んだ |
| `evaluation/stylus/sound_from_stylus.m` | 定義されていない `y`・`y2` と、無い関数 `mySaveForPapers` を使う。Windows の絶対パスも書かれている | 変数の代入と `src/` の関数を検索した |

補足として、次のことも分かった。

- `photoshop_localMax_1cycle.m` は動くが、cycleResult の `ScriptName` に `"pkLocalMax_1cycle"` と別の名前を書いている（220行）。
- `pkCentroidAndLocalMax_resample_1cycle.m` は、撮影画像を `./pictures/1111/original/` という古い相対パスで読む。

## 8. 採らなかった候補

次のものは、関数にしないほうがよいと判断した。

- 共通の定数（`NUM_IMAGES = 8`、`L_MASK = 20`、`D_THRESH = 0.6` など）を1つの関数にまとめる案
  - `docs/rules/coding.md` は、パラメータをスクリプトの冒頭にまとめ、実行する人が見て書き換えられるようにすると決めている。関数に隠すと、この決まりに反する。
- 凡例のクリックで表示を切り替える2行（`lgd = legend; lgd.ItemHitFcn = @togglevisibility;`。11本に計34行）
  - 2行で済み、関数にしても短くならない。
- 前の結果から選択を読み、形を確かめる処理（`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m` の `isReplay` の節）
  - 2本だけで、エラーの識別子がスクリプトごとに違う。`trackingSeeds` がすでに中心の処理を持っている。
- 評価の判定の表（`rows(end+1,:) = {...}` と表示・CSV への書き出し）
  - 2本の評価スクリプトで列の数が違い（5列と6列）、評価ごとに形が変わる。評価の手順（`.claude/agents/evaluator.md`）を整えるときに、一緒に考えるのがよい。
- `compareInclBoundToExclBound.m` の古い溝底の判定（`detectExclBound`）と点の対応づけ（`matchPoints`）
  - 1回限りの比較のための書き直しで、ほかで使う見込みがない。
- `cycleConditions`・`cycleMethodResult`・`saveCycleResult` の呼び出しの組み立て
  - すでに関数で、スクリプトごとの違い（引数の値）しか残っていない。

## 9. ユーザーが決めること

実装の前に、次の5つを決めてほしい。

- Q1 動かないスクリプト6本（[7章](#7-先に決めたほうがよいこと動かないスクリプト)）をどうするか。
  - (a) `scripts/archive/` へ移す（推奨。どれも、今の作業で使っていない）。
  - (b) 直してから、共通関数に置き換える。
  - (c) そのまま残し、置き換えの対象から外す。
- Q2 D2 で保存する音声の図の名前をどうするか。
  - (a) 今の名前（`audio_(centroid_method)(original)_amp` など）を保つ。過去の実行フォルダの図と並べて比べやすい。
  - (b) 語彙表の名前にし、`saveFigure` で保存する（推奨。figures.md の決まりに合う）。
- Q3 Photoshop で8倍にした画像の溝底の判定（幅の下限 `W_MIN` 付き）を、`GrooveExtractor.findGrooveBottomIntervals` の引数（例：`MinWidth`）として入れるか。
  - (a) 入れる。`photoshop_centroid_1cycle.m` が動くようになり、B1 で置き換えられる。
  - (b) 入れない。Photoshop の2本は Q1 の扱いに合わせる（推奨。従来法との比較は 202609asj で済んでいる）。
- Q4 撮影画像の場所を、どう指定するか（A2）。
  - (a) 今のまま、MATLAB のパス（`Research.prj` が足すフォルダ）から探す。
  - (b) `rootFolder` からのフルパス（`data/pictures/1111/original/`）で読む（推奨。プロジェクトのパスの設定に頼らず、テストからも呼びやすい）。
- Q5 スクリプトを置き換えたときの実データでの確認を、どこまで行うか（[5章](#出力が変わらないことの確かめ方)）。
  - (a) 置き換えたスクリプトごとに、全80セグメントで前後を比べる（推奨。数分で終わる）。
  - (b) 写真1枚（10セグメント）だけで比べる。
  - (c) 実データでの比較は行わず、単体テストだけにする。
