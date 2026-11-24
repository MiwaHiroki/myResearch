- 段階: 計画
- 作成者: planner
- 作成日: 2026-11-24
- 入力: issue #28、`docs/issues/28-results-by-experiment/README.md`（作業履歴の「準備・全体」の決定）、main の依頼文（issue 作成後にユーザーと決めたこと）
- 状態: 承認済み（2026-11-24、ユーザー。Q1〜Q5 は推奨どおり。Q6 は (a) に、実験名の決め方の規則を1行足す。8章の「決定事項」）

# #28 計画：結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す

付属の文書：[`mapping-draft.md`](./mapping-draft.md)（既存のフォルダの対応表の案）

## 修正の履歴

- 2026-11-24（main）：ユーザーの回答を8章の「決定事項」に書き、状態を「承認済み」にした。Q6 の決定に合わせて、5.1 の手順9に、README に書く実験名の決め方の規則の1行を足した。ほかの設計は変えていない。

## 1. 結論

- `src/` に、実行フォルダを作って実行記録を書く `resultDir`、実験条件を決まった入れ子にまとめる `runConditions`、図の置き場所を返す `figureDir` を作る。`saveCycleResult` の中の `collectMeta`・`gitState` は `src/` の関数に切り出す。`cycleConditions` には、`runConditions` の出力を受け取る呼び方を足す。`experimentDir`・`cycleResultPath`・`cycleResultFileName` は変えず、`"2026-0731"` の形の日付をそのまま渡す。
- スクリプト55本は、出力先の行・日付の行・実験条件の呼び出しだけを差し替える（1周分のスクリプトのうち5本は、ループの中で決めている実験条件の定数を、値を変えずに冒頭へ移す）。`resultDir` は `mkdirFromDate` と同じく、末尾に区切り文字の付いたパスを返す。そのため、`dir + ファイル名` で保存している行は変えなくてよい。
- 既存のフォルダは、対応表（CSV）を読む移行の関数 `scripts/migration/migrateResults.m` で移す。既定では試しだけを行い、上書きせず、移し終えたものは飛ばす。
- 進め方は「計画 → 評価基準 → 実装の前半（関数・テスト・README の表。承認A）→ 実装の後半（スクリプト・文書・`.gitignore`）→ 移行（main。承認B・C）→ 評価」とする。`experiments/` の改名は評価の直前に行い、マージまでの間は master のスクリプトで `experiments/` を読まない運用を推奨する（8章 Q1）。

## 言葉

- **実験名・実行フォルダ・説明・実行記録・実験条件・発表名・対応表・データの日付**：issue #28 の「言葉」と同じ意味で使う。説明は、スクリプトでは定数 `LABEL` に書く。
- **1周分のスクリプト（8本）**：`cycleConditions` を呼んで cycleResult を保存する8本。`pkCentroid_1cycle.m`・`pkCentroid_resample_1cycle.m`・`pkCentroid_interp2_1cycle.m`・`photoshop_centroid_1cycle.m`・`photoshop_localMax_1cycle.m`・`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m` である。
- **動かない6本**：`docs/refactoring/common-functions.md` の7章に挙がっている、今のコードでは最後まで動かない6本のスクリプト。
- **前半・後半**：実装を2回に分けたときの1回目（関数・テスト・README の表）と2回目（スクリプト・文書）。評価で不合格になったときの「2回目」とは別のものである。
- **承認A・B・C**：途中でユーザーの承認を取る3か所。A は README の「`runInfo.json` の項目」の表と実験名の一覧、B は対応表（移す直前の試しの結果）、C は `experiments/` のバックアップの確認である。
- **試し（DryRun）**：移行の関数が、移す内容を表にして返すだけで、ファイルを何も動かさないこと。
- **改名の期間**：`experiments/` を改名してから、PR をマージするまでの間。

## 2. 調査結果

### 2.1 対象ファイルの一覧（2026-11-24 の数）

issue の「対象ファイル」の4つの検索を、今のブランチ（`c7d2460`）で実行した。

| 検索 | issue を書いた時点 | 今 | 補足 |
|---|---|---|---|
| 実験のスクリプト（`mkdirFromDate`） | 23本 | 23本 | |
| 図のスクリプト（`"results","figures"`） | 30本 | 31本 | `progress/wideBottomOutlierWidthThresh.m` は `"results", "figures"` と空白を入れて書いているので、issue の検索には出ない。`git grep -lE '"results" *, *"figures"'` で探すと32本になる |
| `experiments/` を日付で読むもの | — | 22本 | すべて上の2つに含まれる。ほかに、読み込みの日付を `"MMDD"` のまま置いている評価スクリプトが2本ある |
| 文書 | — | 15ファイル | ほかに `src/` の説明の6ファイルと、検索に出ない `.github/ISSUE_TEMPLATE/figure.md` がある |

スクリプトは、上の2つを合わせて55本になる（重なりは無い）。種類ごとに、何を書き換えるかを次に書く。書き換え方の詳細は 4.4 にある。

#### (1) 1周分のスクリプト（8本）

`pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`photoshop_centroid_1cycle.m`、`photoshop_localMax_1cycle.m`、`grooveTrack_1cycle.m`、`grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`

- 冒頭に、実験名・日付・説明の3行を置く。
- `runConditions` を1回呼び、その出力を `resultDir` と `cycleConditions` の両方に渡す。
- `mkdirFromDate` の行を `resultDir` に置き換える。
- 3本（`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`）にある日付の確認（`dateNotSet`）を消す。`resultDir` が同じ確認をするためである。
- 5本（`pkCentroid_*_1cycle.m` の3本、`photoshop_*_1cycle.m` の2本）は、実験条件の定数の一部（`WIDTH_THRESH`・`tol`・`binWidth`・`h_prl` など）をループの中で決めている。値を変えずに冒頭へ移す（Q5）。

#### (2) ほかの実験のスクリプト（15本）

`bilateral/` の5本（`bilateral8x_centroid.m`、`bilateralOriInterp2_centroid.m`、`bilateralOriResample_centroid.m`、`bilateralOri_centroid.m`、`bilateralOri_centroid_1cycle.m`）、`darkness3d.m`、`evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`、`evaluation/grooveBottomDetection/compareWidthThresh.m`、`evaluation/grooveTracking/compareTrackingToManual.m`、`evaluation/multiGroove/compareHistToTracking.m`、`evaluation/stylus/sound_from_stylus.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`pkCentroid_interp2.m`、`pkCentroid_resample.m`、`progress/showPhotoshopGrooveExtraction.m`

- 冒頭に実験名・日付・説明の3行を置き、`runConditions` と `resultDir` で出力先を作る。
- `bilateral/` の1セグメントの4本は、`results/0820/bilateral/<名前>/` という日付の下のフォルダに出していた。その名前（`ori` など）を説明の既定値にする。
- 評価スクリプト4本は、出力の日付（`OUT_DATE`・`date`）を `resultDir` に渡す。`compareTrackingToManual.m`・`compareHistToTracking.m` には、読み込みの日付（`TRACK_DATE` など）が `"MMDD"` のままなら止める確認がある。この確認は残し、未設定を表す値を `"YYYY-MMDD"` にし、確認する日付から `OUT_DATE` を外す（`resultDir` が確かめるため）。

#### (3) 図のスクリプト（32本）

`scripts/paper/202609asj/` の13本、`scripts/slides/202609asj/` の11本、`scripts/progress/` の8本（`showPhotoshopGrooveExtraction.m` を除く）

- 保存先を組み立てて `mkdir` する4行を、`figureDir` の1行に置き換える。
- 読み込みの日付（`DATE = "0731"` など）を、新しい名前（`"2026-0731"`）にする。
- 進捗報告用の8本は、図のファイル名とタイトルにも `DATE` を使っている。データの日付は4桁のまま書く決まり（ユーザーの決定）なので、`DATE_MMDD = extractAfter(DATE, "-")` を作り、名前とタイトルではそちらを使う。`evaluation/grooveBottomDetection/compareWidthThresh.m` の `DATA_DATES` も同じである。

#### (4) `experiments/` を日付で読むもの（22本。(1)〜(3) に含まれる）

`bilateral/bilateralOri_centroid_1cycle.m`、`evaluation/grooveBottomDetection/` の2本、`evaluation/grooveTracking/compareTrackingToManual.m`、`evaluation/multiGroove/compareHistToTracking.m`、`paper/202609asj/` の4本（`fig5_spectrogramComparisonOrigD.m`・`fig6_spectrogramUpsampling.m`・`fig_waveformComparisonOrigD.m`・`fig_waveformUpsampling.m`）、`pkCentroid_interp2_1cycle.m`、`pkCentroid_resample_1cycle.m`（コメントの中のパス）、`progress/` の8本、`slides/202609asj/` の3本（`waveformAndSpectrogramOrigD.m`・`waveformAndSpectrogramUpsampling.m`・`waveformUpsampling.m`）

- 日付の値とパスの中の日付を、新しい名前にする。読むパスは 7.4 の表にまとめた。
- 説明のコメントに書いたパス（`compareWidthThresh.m` の冒頭など）も、新しい名前にする。

#### (5) 動かない6本

`pkCentroidAndLocalMax_resample_1cycle.m`、`photoshop_centroid_1cycle.m`、`pkCentroid_interp2.m`、`pkCentroid_resample.m`、`paper/202609asj/fig_waveformUpsampling.m`、`evaluation/stylus/sound_from_stylus.m`

- ユーザーの決定どおり、出力先と日付の行だけを機械的に置き換える。動かない箇所は直さない。実データでの確認の対象にもしない。
- `photoshop_centroid_1cycle.m` は1周分のスクリプトでもあるので、ほかの7本と同じく `cycleConditions` の新しい呼び方に移す。

#### (6) 文書（git で追跡しているもの）

| ファイル | 直すこと |
|---|---|
| `README.md` | ディレクトリ構成、`src/` と `scripts/` の一覧、「1周分の実験結果の保存」の例、「基本的な使用方法」。新しく「結果の置き場所と実行記録」の節（実験名の一覧、実行フォルダの名前の決め方、`runInfo.json` の項目、対応表）を作る |
| `CLAUDE.md` | 48〜49行（出力先と `.gitignore` の例外） |
| `docs/rules/figures.md` | 「置き場所と用途」の表、出力先の説明、データの日付の説明（`experiments/<YYYY-MMDD>/` の MMDD）、「既存の図は改名しない」の例外の記録 |
| `docs/rules/data.md` | 出力の置き場所（`resultDir`）、出力の上書き（実行フォルダは `_<N>` で分かれる）、`date = "0731"` の例 |
| `docs/rules/coding.md` | 「スクリプト」の節の、冒頭に置くもの（実験名・日付・説明、`runConditions`・`resultDir`） |
| `docs/rules/evaluation.md` | 評価スクリプトの出力先 |
| `docs/refactoring/common-functions.md` | F1 の仕様を新しいフォルダの形にし、#28 で作ったことを書く。H1 に、日付の確認は #28 の `resultDir` が受け持つことを書く。ほかの節の `experiments/1014/...` などの例も新しい名前にする |
| `docs/staged-development.md` | 2章の表、5.5・5.6 の日付（`YYYY-MMDD`）と出力先 |
| `docs/issues/README.md` | 進捗報告の素材のひな型の `experiments/<MMDD>/`・`results/<MMDD>/` |
| `.claude/agents/implementer.md`・`evaluator.md`・`illustrator.md` | `results/<日付>/`・`results/<MMDD>/` の書き方 |
| `.claude/skills/make-figure/SKILL.md`・`progress-material/SKILL.md` | データの日付、作業用の出力先 |
| `.github/ISSUE_TEMPLATE/figure.md` | 出力先（`results/figures/<発表名>/{paper,slides}/`） |
| `.gitignore` | issue の規則にし、2回書かれている `# editor` と `/.vscode` を1つにする |
| `src/` の説明（`mkdirFromDate.m`・`experimentDir.m`・`cycleResultPath.m`・`cycleResultFileName.m`・`saveFigure.m`・`saveCycleResult.m`） | 使い方の例の日付と出力先。`mkdirFromDate` には「新しいコードでは `resultDir` を使う」と書く |

過去の記録（`docs/issues/closed/`、`docs/progress/`、`slides/progress/`）は書き換えない。

### 2.2 既存のコードで使えるもの

- `experimentDir`・`cycleResultFileName`・`cycleResultPath` は、日付を文字列として連結するだけなので、`"2026-0731"` を渡せば `experiments/2026-0731/cycleResult_origD_2026-0731.mat` になる。変える必要が無い。
- `saveCycleResult` は、保存のファイル名を `conditions.date` から作る。新しい実行では `cycleResult_<条件>_2026-1124.mat` のようになり、改名後の既存のファイルと同じ形になる。
- `mkdirFromDate` は、末尾に区切り文字の付いたパスを返す。スクリプトの多くが `dir + ファイル名`（`saveas`・`AudioData.saveAudio`・`soundCheck`）で保存しているので、`resultDir` も同じ形で返す。
- `cycleConditions` の `checkGiven`（必須の引数がそろっているかを確かめるローカル関数）は、新しい呼び方でも使える。
- `saveCycleResult` の `uniquePath`（`_2` を付けて別名にする）と同じ考え方を、`resultDir` のフォルダ名に使う。

### 2.3 実データ・実行で確かめたこと

MATLAB R2024b で、読み取りだけで確かめた（コードは付録）。

- `results/` の日付のフォルダは19個、603ファイル。`results/figures/` は、原稿用 55（git の管理外）、スライド用 52（管理する）、進捗報告用 92（管理する）。
- `experiments/` の日付のフォルダは10個で、空のものが `1026/` と `1110/` の2つある（issue に書かれていたのは `1026/` だけ）。`0831/digitalNeedle/` にも .mat が1つある。
- 混ざったフォルダは7個（`0724`・`0731`・`0802`・`1014`・`1028`・`1104`・`1118`）。ファイル名のパターンで、すべてのファイルを1つずつの行き先に振り分けられた（`mapping-draft.md` 付録 A）。
- `pkCentroid_interp2_1cycle.m` の `PREV_RESULT_PATH` は `experiments/0731/cycleResult_intpD_0731_2.mat` を指しているが、このファイルは無い。今ある `cycleResult_intpD_0731.mat` の `meta.savedAt` は 2026-08-07 13:41:34 で、`_2` を指すようにしたコミット `b721060`（2026-08-07 14:56）の直前である。`_2` として保存したものを、後で元の名前に改名したと考えられる。
- `photoshop_localMax_1cycle.m` は、`cycleConditions` に `WTh=W_MAX` を渡しているが、`W_MAX` はコメントの中でしか定義されていない。そのため、最後の `cycleConditions` の行で止まる。溝底の検出には `findpeaks` を使っていて、幅の上限は使っていない。
- `grooveHist_Ncycle.m` は、`cycleConditions` に `Tol=BAND_TOL`・`BinWidth=BIN_WIDTH`（`NaN` ではない値）を渡している。issue の「`Manual` が無ければ `NaN` にする」をそのまま実装すると、この2つが `NaN` に変わり、今と同じ `conditions` にならない（付録 A.4）。
- `jsonencode` は、要素が1つの string の配列を、配列ではなく1つの文字列にする。cell に入れると配列になる。`NaN` は `null` になり、`jsondecode` で読み戻すと空の double になる（付録 A.1）。
- `isequal` は、`NaN` を含む struct どうしを等しいとしない。`isequaln` と `verifyEqual` は等しいとする（付録 A.3）。追跡の場合（`NaN` を渡す）の一致は、`isequal` ではなく `isequaln` か `verifyEqual` で確かめる必要がある。
- 省略できる位置引数（`struct`）と name-value 引数を `arguments` ブロックで両立でき、今の name-value だけの呼び方もそのまま通る（付録 A.2）。知らない name-value を渡すと `MATLAB:TooManyInputs` のエラーになる。
- issue の `.gitignore` の規則を使い捨てのリポジトリで試し、スライド用・進捗報告用だけが追跡され、原稿用・実行フォルダ・`results/figures/` の直下のファイルが無視されることを確かめた（付録 A.6）。
- `checkcode` は、55本のうち7本に、今の時点で27件の警告を出す（付録 A.8）。動かない2本（`pkCentroid_resample.m` 13件、`pkCentroid_interp2.m` 8件）が大部分である。
- MATLAB プロジェクトのパスには `src`・`scripts`・`scripts/evaluation`・`scripts/evaluation/stylus`・`test` が入っている。`scripts/migration/` は入らないので、移行の関数は `addpath` してから呼ぶ。
- 関数名 `resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState`・`migrateResults` は、MATLAB のパス上のほかの関数とぶつからない。

### 2.4 参考ブランチ

- `claude/DigitalNeedle-reproduction`（master にマージしていない）に、`results/0831/digitalNeedle/` と `experiments/0831/digitalNeedle/` を作ったスクリプト `scripts/digitalNeedle/compareGrooveShapeAccuracy.m` がある（コミット `631b88b`）。このブランチは変えない。

## 3. 案の比較

### 3.1 全体の方針

| 案 | 中身 | 長所 | 短所 |
|---|---|---|---|
| 案1（推奨） | issue のとおりに関数を作る。スクリプトは、出力先の行・日付の行・実験条件の呼び出しだけを差し替える。`resultDir` は `mkdirFromDate` と同じ形のパスを返す | 保存の行（約200か所）を変えずに済む。実行記録を、出力を作る前に必ず残せる | `runConditions` の引数を、スクリプトごとに書く必要がある |
| 案2（最小の変更） | `mkdirFromDate` に実験名と説明の引数を足し、パスだけを新しい形にする | 変更が最も少ない | 実行記録が残らず、完了条件を満たさない |
| 案3 | 実行記録を、出力の最後（`saveCycleResult` のように）に書く | 実行の結果（警告の数など）も書ける | 途中で止まった実行の記録が残らない。スクリプトの末尾にも手を入れる必要がある |

案2は完了条件を満たさないので採らない。案3は、途中で止まった実行（`results/1110/` のような例がある）の出力に条件が残らないので採らない。

### 3.2 移行の仕組み

| 案 | 中身 | 長所 | 短所 |
|---|---|---|---|
| (a) 対応表の CSV と移行の関数（推奨） | 1行に「フォルダ」「パターン」「1ファイル」「空のフォルダの削除」のどれかを書き、関数が読んで移す | 約70行でユーザーが承認できる。試しで全体を先に確かめられる。合成データでテストできる。laptop でも同じ表で移せる | パターンの解き方を正しく作る必要がある |
| (b) ファイルごとの一覧 | 700行を超える一覧を作る | パターンを解かなくてよい | 承認できる量ではない |
| (c) 手で移す | エクスプローラーやシェルで移す | 道具を作らなくてよい | 移し忘れ・打ち間違いが起きやすい（issue が避けたいこと） |

形式（CSV・JSON）の比較は `mapping-draft.md` の5章にある。CSV にするのは、GitHub が表として表示し、README の表に書き写しやすいためである。

### 3.3 図の名前に書くデータの日付

| 案 | 中身 | 長所 | 短所 |
|---|---|---|---|
| (a)（推奨） | 各スクリプトで `DATE_MMDD = extractAfter(DATE, "-")` を作る。`DATE` は新しい名前にし、名前とタイトルの組み立てだけ `DATE_MMDD` を使う | issue の「値だけを新しい名前にする」に合う。年をスクリプトに書かない | 9本で、名前を組み立てる行を変える |
| (b) | `DATE` は4桁のまま残し、パスを作るときに `"2026-" + DATE` にする | 名前の組み立ては変えない | 年をスクリプトに決め打ちする。読むパスの組み立てを全部変える |
| (c) | 4桁を取り出す共通関数を作る | 1か所で決まりを持てる | issue に無い共通関数を作ることになる |

### 3.4 段階の分け方

| 案 | 中身 | 長所 | 短所 |
|---|---|---|---|
| (a) 実装を前半・後半に分ける（推奨） | 前半で関数・テスト・README の表を作って承認A を取り、後半でスクリプト55本と文書を書き換える | issue の「表をスクリプトの書き換えの前に承認する」に合う。表を直しても、書き換えたスクリプトをやり直さずに済む | 実装担当を2回呼ぶ |
| (b) 実装を1回にする | すべてを一度に書き換える | 呼ぶ回数が少ない | 承認A で表が変わると、55本をやり直す |
| (c) スクリプトの種類ごとに3回に分ける | 1周分、ほかの実験、図で分ける | 1回の量が少ない | 種類ごとの書き換えは機械的で、分ける利点が小さい |

## 4. 設計

### 4.1 処理の流れ

#### 実験のスクリプトの冒頭

今の「`date` を書き、`mkdirFromDate` で出力先を作る」所を、次の形に置き換える。`runConditions` と `resultDir` は、渡す定数がすべて決まった直後（処理を始める前）に1回だけ呼ぶ。

```matlab
% 実行する人が書き換える場所
EXPERIMENT_NAME = "multiGroove";   % results/ の下の実験名（README の「実験名の一覧」から選ぶ）
date = "YYYY-MMDD";                % 実行した日（例 "2026-1124"）。書き換えないと resultDir がエラーで止める
LABEL = "";                        % 実行フォルダの説明（付けないなら ""）
PREV_RESULT_PATH = "";             % （今あるもの）

runCond = runConditions( ...       % 冒頭の定数を実験条件にまとめる（runInfo.json と cycleConditions の両方に使う）
    NumImages=NUM_IMAGES, NumSegments=NUM_SEGMENTS, LMask=L_MASK, ...
    Upsampling="origD", Methods=["centroid","localMax"], DThresh=D_THRESH, WidthThresh=WIDTH_THRESH, ...
    Selection="histogram", ReplayFrom=PREV_RESULT_PATH, ...
    Tracking=struct(tolerance=TRACK_TOL, fitLength=FIT_LENGTH, snapRadius=SNAP_RADIUS, ...
                    initLength=INIT_LENGTH, maxGapLength=MAX_GAP_LENGTH, minFitPoints=MIN_FIT_POINTS), ...
    Histogram=struct(numGrooves=NUM_GROOVES, binWidth=BIN_WIDTH, thHistRatio=TH_HIST_RATIO, bandTol=BAND_TOL), ...
    PolyDegree=POLY_DEGREE, DetrendScope="photo", Rpm=RPM, AmpDiv=AMP_DIV);
outDir = resultDir(proj.RootFolder, EXPERIMENT_NAME, date, runCond, Label=LABEL, ...
    ScriptName="grooveHist_Ncycle", Images=filenames_new, InputFiles=PREV_RESULT_PATH);
expDir = experimentDir(proj.RootFolder, date);       % 1周分のスクリプトだけ
```

- `runConditions` の出力の変数名は `runCond` にする。1周分のスクリプトは、`cycleConditions` の出力をすでに `cond` と呼んでいるので、その名前を変えずに済むようにするためである。
- 出力先の変数名（`dir`・`outDir`・`saveDir`）は、スクリプトごとに今の名前のままにする。

#### 1周分のスクリプトの末尾

```matlab
cond = cycleConditions(runCond, Date=date, SaveDir=outDir, ExperimentDir=expDir, ...
    Filenames=filenames_new, ScriptName="grooveHist_Ncycle", Note="（今と同じ）");
matPath = saveCycleResult(cond, allImg, [res_cnt res_max], ...);   % 変えない
```

#### 図のスクリプト

```matlab
saveDir = figureDir(proj.RootFolder, "paper", "202609asj");      % 今の4行を置き換える
DATE = "2026-0731";                                               % 読み込みの日付（値だけ変える）
DATE_MMDD = extractAfter(DATE, "-");   % 図の名前とタイトルに書くデータの日付（MMDD。docs/rules/figures.md）
```

### 4.2 インターフェース

#### 4.2.1 `resultDir`（`src/resultDir.m`、新規）

```matlab
function [outDir, runInfo] = resultDir(rootFolder, experiment, date, conditions, opts)
    arguments
        rootFolder (1,1) string
        experiment (1,1) string                 % 実験名（README の一覧から）
        date (1,1) string                       % 実行した日 "YYYY-MMDD"
        conditions (1,1) struct                 % runConditions の出力（struct() でもよい）
        opts.Label (1,1) string = ""            % 説明。詳細は "_" でつなぐ（"evaluation_polyDegree"）
        opts.ScriptName (1,1) string = ""       % スクリプトの名前（拡張子なし）
        opts.Images string = strings(0,1)       % 使った撮影画像のファイル名
        opts.InputFiles string = strings(0,1)   % 読んだファイル（cycleResult など）。"" は除く
        opts.Note (1,1) string = ""             % 一言の説明、別の文書への参照
    end
```

- 戻り値
  - `outDir`：作った実行フォルダの絶対パス。**末尾に `filesep` が付く**（`mkdirFromDate` と同じ。`outDir + "name.png"` で使えるようにするため）。
  - `runInfo`：`runInfo.json` に書いた内容の struct（テストと表示のため）。
- 処理の順
  1. 日付を確かめる。
     - (a) `"YYYY-MMDD"` のままなら、エラー `resultDir:dateNotSet` で止める。メッセージで、実行した日を `2026-1124` の形で書くように伝える。
     - (b) `^\d{4}-\d{4}$` に合わないか、`datetime(date,"InputFormat","yyyy-MMdd")` が読めない日付（`2026-0230` など）なら、エラー `resultDir:invalidDate` で止める。
  2. 実験名を確かめる。`^[a-z][a-zA-Z0-9]*$`（camelCase）に合わないか、`"figures"` なら、エラー `resultDir:invalidExperiment` で止める。
  3. 説明を確かめる。`""` か、`_` で区切った各部分が英数字だけで、数字だけの部分が無いこと（`_2` などの番号と見分けるため）。外れればエラー `resultDir:invalidLabel`。
  4. フォルダ名を決める。`<date>` か `<date>_<Label>` とし、`results/<experiment>/` の下に同じ名前があれば、無い名前になるまで `_2`、`_3`… を付け、警告 `resultDir:folderExists` を出す（元の名前と付けた名前をメッセージに書く）。
  5. 実行記録の struct を 4.3 の順に組み立て、`jsonencode(..., PrettyPrint=true)` で文字列にする。フォルダを作る前に行うのは、変換できない値があったときに空のフォルダを残さないためである。
  6. フォルダを作り（親も作る）、`runInfo.json` を UTF-8（BOM なし。`writelines(..., Encoding="UTF-8")`）で書く。
- 細目
  - `script`：`<rootFolder>/scripts/**/<ScriptName>.m` を探し（`archive` を含むパスは除く）、1つだけ見つかれば `scripts/...` の相対パス（区切りは `/`）にする。見つからないか2つ以上なら、`<ScriptName>.m` にして警告 `resultDir:scriptNotFound` を出す。`ScriptName` が `""` なら `""` にする。
  - `inputs.files` と `conditions` の中の文字列のうち、`rootFolder` + 区切り文字で始まるものは、`rootFolder` からの相対パス（区切りは `/`）にする。
  - `inputs.images`・`inputs.files` は、要素が1つでも JSON の配列になるように cell の行にする。
  - `meta` は `collectMeta(ScriptName, IncludeBranch=true)` の出力から作る（4.3）。
- 使用例：4.1 のとおり。

#### 4.2.2 `runConditions`（`src/runConditions.m`、新規）

```matlab
function cond = runConditions(opts)
    arguments
        opts.Region (1,1) struct                  % 画像の一部だけを使うとき（キーは自由。値に struct は不可）
        opts.NumImages (1,1) double {mustBeInteger,mustBePositive}     % 既定 8（segmentation を書くとき）
        opts.NumSegments (1,1) double {mustBeInteger,mustBePositive}   % 既定 10
        opts.LMask (1,1) double
        opts.Bilateral (1,1) struct               % キーは kernelSizes・spatialSigmas・degreeOfSmoothing
        opts.Upsampling (1,:) string {mustBeMember(opts.Upsampling,["origD","rsmplD","intpD"])}
        opts.PRsmpl (1,1) double {mustBePositive}
        opts.QRsmpl (1,1) double {mustBePositive}
        opts.QueryStep (1,1) double {mustBePositive}
        opts.InterpMethod (1,1) string
        opts.Methods (1,:) string {mustBeMember(opts.Methods,["centroid","localMax"])}
        opts.DThresh (1,1) double
        opts.WidthThresh (1,1) double
        opts.Selection (1,1) string {mustBeMember(opts.Selection,["manual","tracking","histogram"])}
        opts.ReplayFrom (1,1) string
        opts.Tracking (1,1) struct                % キーは 4.3 の tracking の表
        opts.Histogram (1,1) struct               % キーは 4.3 の histogram の表
        opts.Manual (1,1) struct                  % キーは thHist・tol・binWidth・hPrl
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative}
        opts.DetrendScope (1,1) string {mustBeMember(opts.DetrendScope,["photo","segment"])}
        opts.Rpm (1,1) double {mustBePositive}    % 既定 78（audio を書くとき）
        opts.AmpDiv (1,1) double {mustBePositive}
        opts.Other (1,1) struct                   % ほかに入らないもの（キーは自由。値に struct は不可）
    end
```

- すべて省略できる。`arguments` ブロックには既定値を書かず、渡されたかどうかを `isfield(opts, ...)` で判定する。既定値（`NumImages=8`・`NumSegments=10`・`Rpm=78`）は、そのグループを書くときにコードの中で入れる。
- 戻り値 `cond` は、4.3 の `conditions` と同じ入れ子の struct。グループは `region`・`segmentation`・`preprocessing`・`upsampling`・`grooveBottom`・`grooveSelection`・`detrend`・`audio`・`other` の順に並べ、使わないグループは作らない。グループの中のキーの順も、4.3 の表の順にする（引数を渡した順によらない）。
- グループを作る条件：そのグループの引数を1つでも渡したとき。`segmentation` は `NumImages`・`NumSegments`・`LMask`、`audio` は `Rpm`・`AmpDiv`、`grooveSelection` は `Selection`・`ReplayFrom`・`Tracking`・`Histogram`・`Manual` のどれか。`ReplayFrom` が `""` のときは、`replayFrom` のキーを作らない。
- 一覧のキー（`upsampling.kind`・`grooveBottom.methods`・`preprocessing.bilateral.kernelSizes`・`spatialSigmas`・`grooveSelection.tracking.reclickImages`）は、`num2cell(x(:)')` で cell の行にする。要素が1つでも JSON の配列になるようにするためである。
- エラー
  - `runConditions:missingArgument`：`Upsampling` に `"rsmplD"` があるのに `PRsmpl`・`QRsmpl` が無い、`"intpD"` があるのに `QueryStep`・`InterpMethod` が無い。
  - `runConditions:unknownField`：`Tracking`・`Histogram`・`Manual`・`Bilateral` に、4.3 の表に無いキーがある。
  - `runConditions:tooDeep`：`Region`・`Bilateral`・`Tracking`・`Histogram`・`Manual`・`Other` の値に struct がある（入れ子を3段までにするため）。
  - 知らない name-value：`arguments` ブロックが `MATLAB:TooManyInputs` を出す（自分では書かない）。

#### 4.2.3 `cycleConditions` の新しい呼び方（`src/cycleConditions.m`、変更）

```matlab
function cond = cycleConditions(runCond, opts)
    arguments
        runCond (1,1) struct = struct()   % runConditions の出力。今の呼び方では渡さない
        opts.Upsampling ...               % ここから下は今と同じ name-value 引数
        ...
    end
```

- 今の name-value だけの呼び方は、そのまま使える（テストと受け入れテストが使っている）。出力も変えない。
- 新しい呼び方：`cycleConditions(runCond, Date=..., SaveDir=..., ExperimentDir=..., Filenames=..., SegmentXRanges=..., ScriptName=..., Note=...)`。実行ごとに変わるものだけを name-value で渡す。
- 新しい呼び方かどうかは、`runCond` にフィールドがあるかで決める（`~isempty(fieldnames(runCond))`）。
- `runCond` と一緒に、実験条件の name-value（`Upsampling`・`LMask`・`ThHist`・`DThresh`・`WTh`・`Tol`・`BinWidth`・`HPrl`・`NumImages`・`NumSegments`・`PolyDegree`・`Rpm`・`PRsmpl`・`QRsmpl`・`QueryStep`・`InterpMethod`）を渡したら、エラー `cycleConditions:mixedForms` で止める。これを判定できるように、`NumImages`・`NumSegments`・`PolyDegree`・`Rpm` の既定値は `arguments` ブロックからコードの中へ移す（今の呼び方の出力は変わらない）。
- 写し方（`runCond` → 今のフィールド）

| 今のフィールド | 写す元 | 無いとき |
|---|---|---|
| `upsampling` | `runCond.upsampling.kind`（ちょうど1つ）と `p`・`q`・`queryStep`・`interpMethod`。`scaleFactor` は今と同じ式で計算する | `kind` が無ければ `cycleConditions:missingArgument`、2つ以上なら `cycleConditions:multipleUpsampling` |
| `numImages`・`numSegments` | `segmentation.numImages`・`numSegments` | 8・10 |
| `lMask` | `segmentation.lMask` | `cycleConditions:missingArgument` |
| `dThresh`・`wTh` | `grooveBottom.dThresh`・`widthThresh` | `cycleConditions:missingArgument` |
| `thHist`・`tol`・`binWidth`・`hPrl` | (a) `grooveSelection.manual` があれば、その `thHist`・`tol`・`binWidth`・`hPrl`（4つとも必須）。(b) 無くて `grooveSelection.histogram` があれば、`thHist = NaN`、`tol = bandTol`、`binWidth = binWidth`、`hPrl = NaN`（今の `grooveHist_Ncycle.m` と同じ。Q4）。(c) どちらも無ければ4つとも `NaN` | — |
| `polyDegree` | `detrend.polyDegree` | 3 |
| `rpm` | `audio.rpm` | 78 |
| `date`・`saveDir`・`experimentDir`・`filenames`・`segmentXRanges`・`scriptName`・`note` | name-value | 今と同じ既定値 |

- 実装は、`runCond` から今の name-value の並びを作り、今の組み立ての処理を通すことを勧める。同じ処理を通れば、出力が今の呼び方と同じになることを保ちやすいためである。

#### 4.2.4 `figureDir`（`src/figureDir.m`、新規。common-functions.md の F1 を直したもの）

```matlab
function saveDir = figureDir(rootFolder, purpose, name)
    arguments
        rootFolder (1,1) string
        purpose (1,1) string {mustBeMember(purpose,["progress","slides","paper"])}
        name (1,1) string   % 進捗報告用はテーマ（"grooveTracking"）、スライド用・原稿用は発表名（"202609asj"）
    end
```

- (a) `purpose` が `"progress"` のときは、`results/figures/progress/<name>` を返す。`name` が `^[a-z][a-zA-Z0-9]*$` に合わなければ、エラー `figureDir:invalidTheme`。
- (b) `"slides"`・`"paper"` のときは、`results/figures/<name>/<purpose>` を返す。`name` が `^\d{6}[a-z]+$`（年月6桁と略称）に合わなければ、エラー `figureDir:invalidVenue`。
- フォルダが無ければ作る。戻り値は `fullfile` のまま（**末尾に区切り文字を付けない**）。今の図のスクリプトの `saveDir` と同じ形にして、`fullfile(saveDir, ...)` や保存関数への渡し方を変えずに済ませるためである。
- 使用例：`saveDir = figureDir(rootFolder, "progress", THEME);`

#### 4.2.5 `collectMeta`・`gitState`（`src/collectMeta.m`・`src/gitState.m`、新規。`saveCycleResult.m` から移す）

```matlab
function meta = collectMeta(scriptName, opts)
    arguments
        scriptName (1,1) string
        opts.IncludeBranch (1,1) logical = false   % true なら meta.gitBranch を最後に足す（resultDir 用）
    end

function [commit, isDirty, branch] = gitState(rootFolder)
    arguments
        rootFolder (1,1) string
    end
```

- `collectMeta` の出力のフィールドと順は、今の `saveCycleResult` のローカル関数と同じにする（`savedAt`・`scriptName`・`matlabRelease`・`matlabVersion`・`computerName`・`rootFolder`・`gitCommit`・`gitDirty`）。`IncludeBranch=true` のときだけ、最後に `gitBranch` を足す。`saveCycleResult` は `IncludeBranch` を渡さないので、保存する中身は変わらない。
- `gitState` は、今のローカル関数と同じく、git が無くても失敗しない（`""`・`false`・`""` を返す）。3つ目の出力 `branch` は、要求されたとき（`nargout >= 3`）だけ `git -C <root> rev-parse --abbrev-ref HEAD` で求める。
- `saveCycleResult.m` のローカル関数 `collectMeta`・`gitState` は消す（同じ名前のローカル関数が残ると、`src/` の関数を隠すため）。

#### 4.2.6 `migrateResults`（`scripts/migration/migrateResults.m`、新規）

```matlab
function actions = migrateResults(rootFolder, mappingFile, opts)
    arguments
        rootFolder (1,1) string
        mappingFile (1,1) string                    % 対応表の CSV
        opts.Phase (1,1) string {mustBeMember(opts.Phase,["results","experiments"])}   % 必須
        opts.DryRun (1,1) logical = true            % true なら表を返すだけで、何も動かさない
    end
```

- CSV の列と `kind` の意味は `mapping-draft.md` の5章のとおり。`Phase` に合う行だけを、CSV の順に扱う。
- 処理の順
  1. CSV を読み、列と `kind` を確かめる。外れればエラー `migrateResults:invalidMapping`。`Phase` を渡さなければエラー `migrateResults:missingPhase`。
  2. 全部の行について、何をするかを先に決める（ファイルはまだ動かさない）。`dir`・`file` は行ごとに、`files` はパターンに合うファイルごとに判定する（`files` では、行き先のフォルダがすでにあってもかまわない。同じ行き先に2つのパターンを移すことがあるため）。
     - (a) 元があり、行き先が無い：移す（`move`）。
     - (b) 元が無く、行き先がある：移し終えたとみなして飛ばす（`done`）。`files` では、パターンに合うファイルが元に無く、行き先のフォルダにあるとき。
     - (c) 元も行き先も無い：警告 `migrateResults:sourceMissing` を出して飛ばす（`missing`）。laptop のように、一部のフォルダが無い PC でも動かせるようにするため。
     - (d) 元も行き先もある（`files` では、同じ名前のファイルが行き先にある）：エラー `migrateResults:destinationExists`（上書きしない）。
     - (e) `deleteEmpty` の行：その行までの移動を済ませた後に、フォルダにファイルが残るなら、エラー `migrateResults:unmatchedFiles`（残るファイルを並べる）。空になるなら `delete`、すでに無ければ `done`。
  3. エラーが1つでもあれば、何も動かさずに止める。
  4. `DryRun` が true なら、表を返して終える。false なら、表の順に `movefile`・`rmdir` を行う（行き先の親のフォルダは作る）。途中で `movefile` が失敗したら、そこでエラーで止める。もう一度呼べば、移し終えた行は (b) で飛ばされる。
- 戻り値 `actions`：行ごとの `phase`・`kind`・`source`・`destination`・`status`（`move`・`done`・`missing`・`delete`）・`count`（移すファイルの数）の table。表示もする。
- 使用例（main が実行する）：

  ```matlab
  root = string(currentProject().RootFolder);
  addpath(fullfile(root,"scripts","migration"));
  csv = fullfile(root,"scripts","migration","resultsMapping.csv");
  actions = migrateResults(root, csv, Phase="results");                % 試し
  actions = migrateResults(root, csv, Phase="results", DryRun=false);  % 承認B の後
  ```

### 4.3 `runInfo.json` の項目

README の「`runInfo.json` の項目」の表は、この表から作る（承認A）。並びは上から読む順で、`jsonencode` はこの順にキーを書く。

- 一覧の値は、要素が1つでも JSON の配列（`["..."]`）で書く。
- `NaN` は `null` になる（`jsonencode` の動作）。
- キーの名前は、cycleResult にすでに同じものがあればそれに合わせ（`grooveSelection.tracking`・`grooveSelection.multiGroove`・`conditions`）、無ければスクリプトの定数名を camelCase にする。
- `runConditions` に渡すのは、スクリプトの冒頭の定数（とループの中から冒頭へ移した定数）だけにする。スクリプトの中に直接書かれた値（回転数の `78`、振幅の正規化の `tol/2`、`extractGrooveWaveform` の既定の次数 3）は渡さない（Q3）。

| キー | 型 | 意味・単位 | 元の引数（スクリプトの定数） | 書く条件 |
|---|---|---|---|---|
| `schemaVersion` | 数 | 実行記録の形の版。最初は 1 | — | いつも |
| `experiment` | 文字列 | 実験名 | `resultDir` の第2引数（`EXPERIMENT_NAME`） | いつも |
| `run` | 文字列 | 実行フォルダの名前（`_<N>` を含む） | — | いつも |
| `script` | 文字列 | スクリプトのルートからのパス | `ScriptName` | いつも（無ければ `""`） |
| `note` | 文字列 | 一言の説明 | `Note` | いつも |
| `inputs.images` | 一覧 | 撮影画像のファイル名（拡張子なし） | `Images`（`filenames_new`） | いつも |
| `inputs.files` | 一覧 | 読んだファイルのルートからのパス | `InputFiles`（`PREV_RESULT_PATH` など） | いつも |
| `conditions.region.*` | 数・一覧 | 写真の番号、セグメント、行・列の範囲 [px] など（キーは定数名の camelCase。例 `imgIndex`・`jSegment`） | `Region` | 渡したとき |
| `conditions.segmentation.numImages` | 数 | 写真の枚数 | `NumImages`（`NUM_IMAGES`。既定 8） | segmentation の引数を1つでも渡したとき |
| `conditions.segmentation.numSegments` | 数 | 写真を横に分ける数 | `NumSegments`（`NUM_SEGMENTS`。既定 10） | 同上 |
| `conditions.segmentation.lMask` | 数 | マスクの輝度のしきい値（0〜255） | `LMask`（`L_MASK`） | 渡したとき |
| `conditions.preprocessing.bilateral.kernelSizes` | 一覧 | バイラテラルフィルタの近傍の大きさ [px] | `KERNEL_SIZES` | `Bilateral` を渡したとき |
| `conditions.preprocessing.bilateral.spatialSigmas` | 一覧 | 空間方向の標準偏差 [px] | `SPATIAL_SIGMAS` | 同上 |
| `conditions.preprocessing.bilateral.degreeOfSmoothing` | 数 | 平滑化の度合い（輝度の2乗） | `DEGREE_OF_SMOOTHING` | 同上 |
| `conditions.upsampling.kind` | 一覧 | `"origD"`・`"rsmplD"`・`"intpD"`。比べるスクリプトでは2つ以上 | `Upsampling` | 渡したとき |
| `conditions.upsampling.p`・`q` | 数 | リサンプルの倍率 p/q | `PRsmpl`・`QRsmpl`（`P_RSMPL`・`Q_RSMPL`） | `kind` に `rsmplD` があるとき（必須） |
| `conditions.upsampling.queryStep` | 数 | 内挿の間隔 [px] | `QueryStep`（`QUERY_STEP`） | `kind` に `intpD` があるとき（必須） |
| `conditions.upsampling.interpMethod` | 文字列 | `interp2` の方法 | `InterpMethod`（`INTERP_METHOD`） | 同上 |
| `conditions.grooveBottom.methods` | 一覧 | `"centroid"`・`"localMax"` | `Methods` | 渡したとき |
| `conditions.grooveBottom.dThresh` | 数 | 暗さのしきい値（0〜1） | `DThresh`（`D_THRESH`） | 渡したとき |
| `conditions.grooveBottom.widthThresh` | 数 | 溝底区間の幅の上限 [px] | `WidthThresh`（`WIDTH_THRESH`） | 渡したとき |
| `conditions.grooveSelection.method` | 文字列 | `"manual"`・`"tracking"`・`"histogram"` | `Selection` | 渡したとき |
| `conditions.grooveSelection.replayFrom` | 文字列 | 選択を再現した結果のルートからのパス | `ReplayFrom`（`PREV_RESULT_PATH`） | 空でないとき |
| `conditions.grooveSelection.tracking.tolerance`・`fitLength`・`snapRadius`・`initLength`・`maxGapLength` | 数 | `trackGroove` の引数 [px] | `TRACK_TOL`・`FIT_LENGTH`・`SNAP_RADIUS`・`INIT_LENGTH`・`MAX_GAP_LENGTH` | `Tracking` を渡したとき |
| `conditions.grooveSelection.tracking.minFitPoints` | 数 | 直線のあてはめに要る点の数 | `MIN_FIT_POINTS` | 同上 |
| `conditions.grooveSelection.tracking.numGrooves`・`minSeedGap`・`reclickImages` | 数・数・一覧 | 本数、始点の間隔の下限 [px]、もう一度クリックする写真の番号 | `NUM_GROOVES`・`MIN_SEED_GAP`・`RECLICK_IMAGES`（`grooveTrack_Ncycle.m`） | 同上 |
| `conditions.grooveSelection.histogram.numGrooves`・`binWidth`・`thHistRatio`・`bandTol` | 数 | 本数、ビンの幅 [px]、山の高さ（列の数に対する割合）、帯の半分の幅 [px] | `NUM_GROOVES`・`BIN_WIDTH`・`TH_HIST_RATIO`・`BAND_TOL` | `Histogram` を渡したとき |
| `conditions.grooveSelection.manual.thHist`・`tol`・`binWidth`・`hPrl` | 数 | ヒストグラムの山の高さ [点]、溝に含める距離 [px]、ビンの幅 [px]、平行四辺形の高さ [px] | `TH_HIST`・`tol`・`binWidth`・`h_prl` | `Manual` を渡したとき |
| `conditions.detrend.polyDegree` | 数 | デトレンドの多項式の次数 | `PolyDegree`（`POLY_DEGREE`） | 渡したとき |
| `conditions.detrend.scope` | 文字列 | `"photo"`（写真ごと）・`"segment"`（セグメントごと） | `DetrendScope` | 渡したとき |
| `conditions.audio.rpm` | 数 | 回転数 [rpm]（既定 78） | `Rpm`（`RPM`） | audio の引数を1つでも渡したとき |
| `conditions.audio.ampDiv` | 数 | 振幅の正規化 [px] | `AmpDiv`（`AMP_DIV`） | 渡したとき |
| `conditions.other.*` | 数・文字列・一覧 | ほかに入らないもの（評価のしきい値など。キーは定数名の camelCase） | `Other` | 渡したとき |
| `meta.createdAt` | 文字列 | 作った日時 `yyyy-MM-ddTHH:mm:ss`（その PC の時刻） | `collectMeta` の `savedAt` | いつも |
| `meta.git.commit` | 文字列 | コミット（短い形） | `gitCommit` | いつも |
| `meta.git.branch` | 文字列 | ブランチ | `gitBranch` | いつも |
| `meta.git.dirty` | 真偽 | 未コミットの変更があったか | `gitDirty` | いつも |
| `meta.matlabRelease` | 文字列 | `R2024b` の形（`collectMeta` の値に `R` を付ける） | `matlabRelease` | いつも |
| `meta.computerName` | 文字列 | PC の名前 | `computerName` | いつも |

版ごとの違いの表（README）は、版 1 の1行から始める。

### 4.4 スクリプトごとの書き換え

#### 4.4.1 1周分のスクリプト（8本）

共通：冒頭の3行（4.1）、`runConditions`、`resultDir`（`ScriptName` は今 `cycleConditions` に渡している名前、`Images` は撮影画像の名前の配列、`InputFiles` は `PREV_RESULT_PATH`）、末尾の `cycleConditions(runCond, ...)`。`expDir = experimentDir(...)` は残す。`runConditions` には、8本とも `NumImages=NUM_IMAGES`・`NumSegments=NUM_SEGMENTS`・`LMask=L_MASK`・`DThresh=D_THRESH`・`ReplayFrom=PREV_RESULT_PATH` を渡し、ほかは次の表のとおりにする。

| スクリプト | 実験名の既定 | ループの中から冒頭へ移す定数 | `runConditions` に渡すもの | ほかの変更 |
|---|---|---|---|---|
| `pkCentroid_1cycle.m` | `upsampling` | `WIDTH_THRESH`・`h_prl`・`tol`・`binWidth` | `NumImages`・`NumSegments`・`LMask`、`Upsampling="origD"`、`Methods=["centroid","localMax"]`、`DThresh`・`WidthThresh`、`Selection="manual"`、`ReplayFrom=PREV_RESULT_PATH`、`Manual=struct(thHist=TH_HIST, tol=tol, binWidth=binWidth, hPrl=h_prl)` | — |
| `pkCentroid_resample_1cycle.m` | `upsampling` | 上に加えて `P_RSMPL`・`Q_RSMPL` | 上の `Upsampling` を `"rsmplD"` にし、`PRsmpl`・`QRsmpl` | コメントの中の `PREV_RESULT_PATH` の例を新しい名前にする |
| `pkCentroid_interp2_1cycle.m` | `upsampling` | 上に加えて `QUERY_STEP`・`INTERP_METHOD` | `Upsampling="intpD"`、`QueryStep`・`InterpMethod` | `PREV_RESULT_PATH` を、今ある `experiments/2026-0731/cycleResult_intpD_2026-0731.mat` にする（Q5） |
| `photoshop_centroid_1cycle.m` | `photoshopUpscaling` | `W_MAX`・`W_MIN`・`h_prl`・`binWidth`・`tol` | `Upsampling="origD"`、`Methods="centroid"`、`WidthThresh=W_MAX`、`Selection="manual"`、`Manual=...`、`Other=struct(wMin=W_MIN)` | 動かない6本。`Note` は今のまま |
| `photoshop_localMax_1cycle.m` | `photoshopUpscaling` | `h_prl`・`binWidth`・`tol` | `Methods="localMax"`、`WidthThresh=NaN`（Q5）、`Selection="manual"`、`Manual=...` | `ScriptName` を `"photoshop_localMax_1cycle"` に直す（Q5） |
| `grooveTrack_1cycle.m` | `grooveTracking` | — | `NumImages`・`NumSegments`・`LMask`、`Upsampling="origD"`、`Methods=["centroid","localMax"]`、`DThresh`・`WidthThresh`、`Selection="tracking"`、`ReplayFrom`、`Tracking=struct(tolerance=TRACK_TOL, fitLength=FIT_LENGTH, snapRadius=SNAP_RADIUS, initLength=INIT_LENGTH, maxGapLength=MAX_GAP_LENGTH, minFitPoints=MIN_FIT_POINTS)`、`PolyDegree=POLY_DEGREE`、`DetrendScope="photo"`、`Rpm=RPM`、`AmpDiv=AMP_DIV` | `dateNotSet` の確認を消す |
| `grooveHist_Ncycle.m` | `multiGroove` | — | 上と同じで、`Selection="histogram"` にし、`Histogram=struct(numGrooves=NUM_GROOVES, binWidth=BIN_WIDTH, thHistRatio=TH_HIST_RATIO, bandTol=BAND_TOL)` を足す（4.1 の例） | 同上 |
| `grooveTrack_Ncycle.m` | `multiGroove` | — | `grooveTrack_1cycle.m` と同じで、`Tracking` に `numGrooves=NUM_GROOVES`・`minSeedGap=MIN_SEED_GAP`・`reclickImages=RECLICK_IMAGES` を足す | 同上。`InputFiles=[PREV_RESULT_PATH GUIDE_RESULT_PATH]` |

- 説明の既定値は8本とも `""` にする（同じ日に同じ実験名で2回実行すれば、`resultDir` が `_2` を付ける）。
- 冒頭へ移す定数は、値と名前を変えずに、パラメータの並びの所へ移す。行末に意味と単位のコメントを付ける（`docs/rules/coding.md`）。

#### 4.4.2 ほかの実験のスクリプト（15本）

| スクリプト | 実験名の既定 | 説明の既定 | 置き換える所 |
|---|---|---|---|
| `bilateral/bilateralOri_centroid.m` | `bilateralFilter` | `"ori"` | `saveDir = fullfile(mkdirFromDate(rootFolder,"0820"),"bilateral","ori")` と、その `mkdir` の3行 |
| `bilateral/bilateralOriResample_centroid.m` | `bilateralFilter` | `"oriRsmpl"` | 同上 |
| `bilateral/bilateralOriInterp2_centroid.m` | `bilateralFilter` | `"oriIntp"` | 同上 |
| `bilateral/bilateral8x_centroid.m` | `bilateralFilter` | `"photoshop8x"` | 同上 |
| `bilateral/bilateralOri_centroid_1cycle.m` | `bilateralFilter` | `"1cycle"` | `date = "0924"` から `saveDir + filesep` までの6行。`PREV_RESULT_PATH` の行を `runConditions` より前へ移す |
| `darkness3d.m` | `upsampling` | `""` | `date = "0725"`、`mkdirFromDate`、`dir = "results/"+date+"/"` の3行（`D_THRESH` などが決まった後に置く） |
| `evaluation/grooveBottomDetection/compareInclBoundToExclBound.m` | `grooveBottomDetection` | `"evaluation"` | `date = "1111"` と `mkdirFromDate` の行 |
| `evaluation/grooveBottomDetection/compareWidthThresh.m` | `grooveBottomDetection` | `"evaluation"` | `OUT_DATE` の確認と `mkdirFromDate`（`SAVE_OUTPUTS` のときだけ作るのは今のまま） |
| `evaluation/grooveTracking/compareTrackingToManual.m` | `grooveTracking` | `"evaluation"` | `OUT_DATE` と `mkdirFromDate`。読み込みの日付の確認から `OUT_DATE` を外す |
| `evaluation/multiGroove/compareHistToTracking.m` | `multiGroove` | `"evaluation"` | 同上 |
| `evaluation/stylus/sound_from_stylus.m` | `stylus` | `""` | `date = "stylus"` と `mkdirFromDate`（動かない6本） |
| `pkCentroidAndLocalMax_resample_1cycle.m` | `upsampling` | `""` | 冒頭の `date = "0615"` と `mkdirFromDate` を `resultDir` にし、519〜520行・586〜587行の `date = "0710"; dir = mkdirFromDate(...)` を消す（出力先を1回だけ作るため。動かない6本） |
| `pkCentroid_interp2.m` | `upsampling` | `""` | `date = "0721"` と `mkdirFromDate`（動かない6本） |
| `pkCentroid_resample.m` | `upsampling` | `""` | 同上（動かない6本） |
| `progress/showPhotoshopGrooveExtraction.m` | `photoshopUpscaling` | `""` | `date = "0817"` と `mkdirFromDate` |

`runConditions` に渡すものは、次の規則で実装担当が決める。

1. 処理のしかたを決める冒頭の定数を、4.3 の表のグループに入れる（1セグメントの検討なら `Region` に写真とセグメントの番号、`bilateral/` なら `Bilateral`）。
2. 表に無いもの（評価のしきい値、比べる条件など）は、`Other` に、定数名を camelCase にしたキーで入れる。
3. 図の体裁・表示・保存の切り替え（色、大きさ、`SAVE_FIG`、`OVERWRITE`、`ZOOM_SEC` など）と、読み込むファイルの日付・名前は渡さない。読み込むファイルは `InputFiles` に渡す。
4. 動かない6本は、冒頭にある定数だけを渡し、ループの中の値は探さない。

#### 4.4.3 図のスクリプト（32本）

1. `saveDir = fullfile(<root>,"results","figures","<用途>","<名前>"); if ~isfolder(saveDir) mkdir(saveDir); end` の4行（`multiGrooveOnePhoto.m` は変数名が `saveDirMulti`）を、`saveDir = figureDir(<root>, "<用途>", "<名前>");` の1行にする。`THEME` の定数がある3本は、それを渡す。
2. 読み込みの日付の値を新しい名前にする（`DATE`・`CONV_DATE`・`DATA_DATES`）。`CONV_MAT` のように `"experiments"` と日付を組み立てる行は、値が変われば正しいパスになる。
3. 進捗報告用の8本（`grooveBtmOnImageTrackOutlier.m`・`grooveOnImageManualAndTrack.m`・`multiGrooveOnePhoto.m`・`waveformManualVsTrack.m`・`waveformTrackVsHist.m`・`wideBottomOutlier.m`・`wideBottomOutlierWaveform.m`・`wideBottomOutlierWidthThresh.m`）は、`DATE_MMDD`（`DATA_DATES` なら `DATA_MMDD`）を作り、図の名前とタイトルを組み立てる行の `DATE` をそれに替える。読み込みのパスを作る行は `DATE` のままにする。

### 4.5 新しく作るファイルと、変えるファイル

- 新しく作る
  - `src/resultDir.m`、`src/runConditions.m`、`src/figureDir.m`、`src/collectMeta.m`、`src/gitState.m`
  - `scripts/migration/migrateResults.m`、`scripts/migration/resultsMapping.csv`
  - `test/unit/ResultDirTest.m`、`test/unit/RunConditionsTest.m`、`test/unit/CycleConditionsTest.m`、`test/unit/FigureDirTest.m`、`test/unit/CollectMetaTest.m`、`test/unit/MigrateResultsTest.m`
- 変える
  - `src/cycleConditions.m`、`src/saveCycleResult.m`、`src/mkdirFromDate.m`（説明）、`src/experimentDir.m`・`src/cycleResultPath.m`・`src/cycleResultFileName.m`・`src/saveFigure.m`（説明の例）
  - 2.1 の (1)〜(3) のスクリプト55本
  - `.gitignore`
  - 2.1 の (6) の文書
- main が行う git の操作：`results/figures/slides/202609asj/` → `results/figures/202609asj/slides/` の `git mv`
- 触らないもの：`src/archive/`・`scripts/archive/`・`test/archive/`、`scripts/paper/202609asj/archive/`、`mkdirFromDate`（消さない）、`checkFigureName`・`figureVocabulary`、過去の記録

### 4.6 互換性

- cycleResult：保存する `conditions`・`meta` の形と値は変えない。新しい実行では、`conditions.date` とファイル名の日付が `2026-1124` の形になる。既存の .mat の中身（`conditions.date = "0731"` など）は変えない。
- `cycleConditions` の今の呼び方：そのまま使え、出力も同じ。
- `cycleResultPath`：`experiments/<日付>/` に無ければ `results/<日付>/` も探す動作を変えない（移行の後は使われないが、issue の制約どおり残す）。
- 図のファイル名とタイトル：データの日付は4桁のまま。`checkFigureName` は変えない。
- `.gitignore`：追跡するもの・無視するものは今と同じ（スライド用は移した先で追跡する）。
- 既存の図：ファイル名は変えない。置き場所の移動は、`docs/rules/figures.md` の「既存の図は改名しない」の例外として、表を直すときに記録する。

## 5. 実装の手順

実装担当は2回呼ぶ。報告は `impl-report-1a.md`（前半）と `impl-report-1b.md`（後半）に分ける。どちらも `experiments/` には何も保存しない。実データでの確認は、`temp/` のコピーで保存の行を外して行う。

### 5.1 前半（関数・テスト・README の表）

1. `src/gitState.m`・`src/collectMeta.m` を作り、`src/saveCycleResult.m` のローカル関数を消して呼ぶ形にする（4.2.5）。既存の `CycleResultTest` が通ることで、保存の中身が変わらないことを確かめる。
2. `src/runConditions.m` を作る（4.2.2）。
3. `src/resultDir.m` を作る（4.2.1）。
4. `src/figureDir.m` を作る（4.2.4）。
5. `src/cycleConditions.m` に新しい呼び方を足す（4.2.3）。今の呼び方の既定値をコードの中へ移しても、出力が変わらないことをテストで確かめる。
6. `src/` の説明を直す（`mkdirFromDate` に「新しいコードでは `resultDir` を使う」、ほかは使い方の例の日付）。
7. `scripts/migration/migrateResults.m` を作る（4.2.6）。CSV はまだ作らない。
8. 6章の unit テストを書く。
9. README に「結果の置き場所と実行記録」の節を作り、「実験名の一覧」（`mapping-draft.md` 1章。承認された名前）、「実行フォルダの名前の決め方」（issue の「あるべき姿」1）、「`runInfo.json` の項目」（4.3 の表と、版の表）を書く。`src/` と `scripts/` の一覧にも足す。
   - 実験名の決め方には、issue の規則に次の1行を足す（8章の Q6 の決定）。「issue の slug が、すでにある進捗報告用の図のテーマや評価スクリプトの置き場所の名前と違うときは、すでにある名前に合わせる（例：#35 の `wide-bottom-outliers` は `grooveBottomDetection`）。」
10. 書いた・変えた `.m` に `checkcode` をかけ、`runAllTests` を通す（受け入れテストのうち、前半の関数のものを含む）。
11. `impl-report-1a.md` を書く。ここで止め、main が承認A を取る。

### 5.2 後半（スクリプト・文書・`.gitignore`・対応表）

12. 1周分のスクリプト8本を書き換える（4.4.1）。
13. ほかの実験のスクリプト15本を書き換える（4.4.2）。
14. 図のスクリプト32本を書き換える（4.4.3）。
15. `.gitignore` を直す（issue の規則。`# editor`・`/.vscode` を1つにする）。
16. 2.1 の (6) の文書を直す。README は、ディレクトリ構成（スクリプトと図とで階層の順が逆になること）、「1周分の実験結果の保存」の例、「基本的な使用方法」も直す。
17. `scripts/migration/resultsMapping.csv` を、承認された `mapping-draft.md` から作る。スライド用の図（`results/figures/slides/`）の行は CSV に入れない（main が `git mv` で移し、空になったフォルダも main が消す）。README の「対応表」の節に、フォルダの単位の表を書き写す（スライド用の図の `git mv` の行も書く）。`migrateResults(..., Phase="results")` と `Phase="experiments"` を、**試しだけ**で実行し、エラーが無く、移すファイルの数が `mapping-draft.md` と合うことを確かめる。
18. 実データで動作を確かめる（`experiments/` には保存しない。`experiments/` の名前はまだ古いので、`temp/` のコピーでは読むパスを古い名前にする。`experimentDir` は `Create=false` にする）。
    - (1) `bilateral/bilateralOri_centroid_1cycle.m` のコピーで、`date` を実行日、`LABEL = "implCheck"` にして実行し、`results/bilateralFilter/<日付>_implCheck/` に図・wav と `runInfo.json` ができることを確かめる。
    - (2) `pkCentroid_1cycle.m` のコピーで、`PREV_RESULT_PATH` を `experiments/1014/cycleResult_origD_1014.mat`、`EXPERIMENT_NAME = "grooveTracking"`・`LABEL = "implCheck"` にし、`saveCycleResult` の行を外して、`ycoords_cnt`・`ycoords_max` が 1014 の結果と `isequal` になること、`cond` が 1014 の `conditions` と（`date`・`saveDir`・`experimentDir` を除いて）`isequaln` になることを確かめる。ループの中の定数を冒頭へ移しても結果が変わらないことの確認である。
19. 変えた `.m` すべてに `checkcode` をかけ、警告が変更の前より増えていないことを確かめる（付録 A.8 の27件を基準にする。Q5）。`runAllTests` を通す。
20. `impl-report-1b.md` を書く。

## 6. テストの方針

実装担当が書く unit テスト。すべて合成データと `TemporaryFolderFixture` の一時フォルダを使い、Linux の CI でも通る形にする。

- `ResultDirTest`
  - 説明あり・なしで、`results/<実験名>/<日付>[_<説明>]/` ができ、戻り値の末尾に区切り文字が付く。
  - 同じ引数で2回・3回呼ぶと `_2`・`_3` ができ、`resultDir:folderExists` の警告が出る。
  - `"YYYY-MMDD"` で `resultDir:dateNotSet`、`"1028"`・`"2026-1328"`・`"2026-0230"` で `resultDir:invalidDate`。
  - 実験名 `"figures"`・`"MultiGroove"`・`"multi-groove"` で `resultDir:invalidExperiment`。説明 `"a b"`・`"hist_2"` で `resultDir:invalidLabel`。
  - `runInfo.json` を `jsondecode` で読み戻せる。先頭のキーが `schemaVersion`（値 1）で、`experiment`・`run`（`_2` を含む）・`script`・`note`・`inputs`・`conditions`・`meta` の順に並ぶ。
  - 要素が1つの `Images`・`InputFiles`・`Methods` も配列になる（読み戻すと cell）。`InputFiles` の `""` は除かれる。ルートの下のパスは `/` 区切りの相対パスになる（`conditions.grooveSelection.replayFrom` も）。
  - 一時フォルダの下に `scripts/sub/foo.m` を作ると、`script` が `scripts/sub/foo.m` になる。無い名前では `resultDir:scriptNotFound` の警告が出る。
  - `meta.createdAt` が `yyyy-MM-ddTHH:mm:ss` の形、`meta.matlabRelease` が `R` で始まる、`meta.git` に `commit`・`branch`・`dirty` がある。
  - 変換できない値（関数ハンドルを `Other` に入れたもの）では、エラーになり、フォルダが作られない。
- `RunConditionsTest`
  - issue の例の呼び出しで、グループとキーが 4.3 の順に並ぶ（引数の順を入れ替えても同じ）。
  - 引数なしでは空の struct。`LMask` だけで `segmentation` に既定の 8・10 が入る。`AmpDiv` だけで `audio.rpm` に 78 が入る。
  - 一覧のキーが、要素が1つでも cell になる。
  - `rsmplD` で `PRsmpl` が無い、`intpD` で `QueryStep` が無いと `runConditions:missingArgument`。`Tracking` の知らないキーで `runConditions:unknownField`。`Other` の値が struct で `runConditions:tooDeep`。知らない name-value で `MATLAB:TooManyInputs`。
- `CycleConditionsTest`
  - 同じ定数から今の呼び方と新しい呼び方で作った出力が等しい（`verifyEqual`。`NaN` を等しいとみなすため `isequal` は使わない）。場合は `origD`（手動）、`rsmplD`、`intpD`、追跡（`NaN`）、ヒストグラム（`Tol`・`BinWidth` が実際の値）の5つ。
  - `runCond` と `LMask` を一緒に渡すと `cycleConditions:mixedForms`。`upsampling` が無いと `cycleConditions:missingArgument`。`kind` が2つで `cycleConditions:multipleUpsampling`。
  - 今の呼び方の既存のテスト（`CycleResultTest`）は変えない。
- `FigureDirTest`：3つの用途のパスとフォルダの作成。`"202609"`・`"asj202609"` で `figureDir:invalidVenue`、`"Grooves"` で `figureDir:invalidTheme`。戻り値の末尾に区切り文字が付かない。
- `CollectMetaTest`：`collectMeta` のフィールドの名前と順が今と同じ（8つ）。`IncludeBranch=true` で `gitBranch` が最後に付く。git のリポジトリでない一時フォルダでは、`gitState` が `""`・`false`・`""` を返し、エラーにならない。
- `MigrateResultsTest`（`PathFixture` で `scripts/migration` を足す）
  - 合成の `results/1014/`（パターンの違う数ファイル）と CSV で、試しでは何も動かず、表の `status` が `move` になる。
  - 実行で移り、元のフォルダが消える。もう一度呼ぶと、すべて `done` になる。
  - 行き先にファイルがあると `migrateResults:destinationExists` で、何も動かない。どの行にも当たらないファイルが残ると `migrateResults:unmatchedFiles` で、何も動かない。
  - `experiments` の段階の `file`（名前を変えて移す）。元も行き先も無い行は `migrateResults:sourceMissing` の警告で飛ばす。

## 7. 評価担当への申し送り

### 7.1 段階の割り当て

issue の「作業の進め方」の7つの手順と、3か所の承認を、次のように割り当てる。

| issue の手順 | 段階 | 行う人 | ユーザーの承認 |
|---|---|---|---|
| — | 評価基準（`criteria.md`・受け入れテスト・評価スクリプト） | evaluator（A） | 評価基準の承認 |
| 1. 関数・テスト・README の表 | 実装の前半 | implementer | **承認A**（README の `runInfo.json` の項目の表、実験名の一覧） |
| 2. スクリプト・文書の書き換え | 実装の後半 | implementer。コミットは main | 報告の確認 |
| 3. `.gitignore` とスライド用の図の `git mv` | 実装の後半の後 | `.gitignore` は implementer が書き、`git mv` とコミットは main | — |
| 4. 対応表 | 案は計画（`mapping-draft.md`）、CSV は実装の後半、最終の確認は移行の直前 | planner・implementer・main | **承認B**（移す直前の試しの表） |
| 5. `results/` と原稿用の図の移動 | 移行（評価の前） | main（Q2） | 承認B の後 |
| 6. `experiments/` の改名 | 移行（評価の直前） | main（Q2） | **承認C**（ユーザーがバックアップを確かめる） |
| 7. 読み込みと実データでの確認 | 評価 | evaluator（B） | ユーザーが判断する項目があれば、その確認 |

main が行う順番：

1. 実装の後半を確かめ、`.gitignore` 以外をコミットする（`Agent: implementer`）。
2. `.gitignore` を加え、`mkdir -p results/figures/202609asj` の後に `git mv results/figures/slides/202609asj results/figures/202609asj/slides` を行う。`git status --short` で、スライド用の図が移動（`R`）だけになっていることを確かめてコミットする。空になった `results/figures/slides/` を消す。
3. 作業ツリーがきれいなことを確かめ、`migrateResults(..., Phase="results")` の試しの表をユーザーに見せる（**承認B**）。承認されたら `DryRun=false` で移し、もう一度試しを実行して、すべての行が `done` になることを確かめる。
4. ユーザーに `data/` と `experiments/` のバックアップを確かめてもらう（**承認C**）。`Phase="experiments"` で同じく試し → 実行 → 試しを行う。
5. 同じ日のうちに、評価担当を呼ぶ（改名の期間を短くするため。Q1）。

`results/` は git の管理外なので、移しても作業ツリーは汚れない。原稿用の図の行き先 `results/figures/202609asj/paper/` は、`.gitignore` を直した後でも無視されるので、`git mv` と `results` の段階の移行は、どちらを先にしてもよい。

### 7.2 評価基準の段階（evaluator A）に頼みたいこと

- 受け入れテスト（例 `test/unit/ResultLayoutAcceptanceTest.m`）で、4.2 のインターフェースを外側から確かめる。特に、`cycleConditions` の今の呼び方と新しい呼び方の一致（5つの場合。`NaN` があるので `verifyEqual` か `isequaln`）、`resultDir` の `_<N>` と日付の確認、要素が1つの一覧が配列になること、`migrateResults` が上書きせず、当たらないファイルがあると何も動かさないこと。
- `criteria.md` に、改名の前の `experiments/` のすべてのファイルの SHA-256 を記録する（#30・#35 と同じ）。改名の後に、対応表で名前を引いて、中身が同じことを確かめるためである。
- `results/` の移す前のファイルの数（日付のフォルダごと、合計 603）と、`results/figures/` の数（原稿用 55、スライド用 52、進捗報告用 92）、`git ls-files results/figures` の数（144）を記録する。
- 評価スクリプト（例 `scripts/evaluation/resultsLayout/checkResultsLayout.m`）は、次を表にして表示する。出力のファイルは作らなくてよい。
  - 「対象ファイル」の4つの検索（`system("git grep ...")`）の残り。残ってよいもの（README の対応表、`mkdirFromDate` 自身とその説明、`docs/rules/figures.md` の例外の記録、`scripts/archive/`）は、`criteria.md` に一覧で書いておく。
  - 7.4 の読むパスの `isfile`。
  - 移行の完了（`migrateResults` の試しが両方の段階ですべて `done`、元の日付のフォルダが無い、ファイルの数）。
  - SHA-256 の照合。

### 7.3 評価の段階（evaluator B）で確かめること

前提：`experiments/` の改名まで終わっていること。評価は、作業ツリーがきれいな状態で始める。

1. `cd test; results = runAllTests;` がすべて通る。
2. `.gitignore`：issue の検証方法 2 のコマンド。`git ls-files results/figures` が 144 のまま。`git mv` のコミットを `git show -M --stat` で見て、52ファイルが移動（`R100`）になっている。
3. 古い書き方が残っていない（評価スクリプトの表）。
4. 読むパスがすべてある（7.4、評価スクリプトの表）。
5. 実データ（issue の検証方法 5）：`scripts/bilateral/bilateralOri_centroid_1cycle.m` を `temp/` にコピーし、`date` を実行した日にして実行する。`ginput` は要らない。`experiments/` には保存しない。
   - (1) `results/bilateralFilter/<実行した日>_1cycle/` に、図・wav と `runInfo.json` ができる（実装担当の確認のフォルダは `_implCheck` なので、ぶつからない）。
   - (2) `runInfo.json` の `inputs.images`（8枚）・`inputs.files`（`experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat`）と、`conditions`（`segmentation`・`upsampling.kind = ["origD"]`・`grooveBottom`・`grooveSelection.manual`・`preprocessing.bilateral` のカーネル `[3,5,9]` など）が、スクリプトの定数と一致する。`meta.git.dirty` が false で、`meta.git.commit` が評価したコミットである。
   - (3) 同じ設定でもう一度実行し、`_2` の付いたフォルダができて `resultDir:folderExists` の警告が出る。
6. 1周分のスクリプトの書き換えで結果が変わらないこと：`scripts/pkCentroid_1cycle.m` を `temp/` にコピーし、`PREV_RESULT_PATH` を `experiments/2026-1014/cycleResult_origD_2026-1014.mat`、`EXPERIMENT_NAME = "grooveTracking"`、`LABEL = "check"` にし、`saveCycleResult` の行を外して実行する。`ycoords`（両手法）が 1014 の結果と `isequal`、`cond` が保存された `conditions` と（`date`・`saveDir`・`experimentDir` を除いて）`isequaln` になる。1014 のデータを作った後に、このスクリプトが使う `src/` の関数は変わっていない（`git log 3261e62..HEAD` で確かめた）。
7. 図のスクリプトの名前の組み立て：`scripts/progress/waveformManualVsTrack.m` を `temp/` にコピーし、`figureDir` の行だけを `temp/` の下のフォルダに替えて実行する。できた図の名前に `_1014` があり、`_2026-1014` が無い。`results/figures/` の既存の図は上書きしない。
8. 移行と改名の結果（評価スクリプトの表）：試しがすべて `done`、ファイルの数が 7.2 の記録と同じ、SHA-256 が改名の前と同じ。
9. 変えた `.m` の `checkcode` の警告が、変更の前（付録 A.8）より増えていない。

ユーザーが判断する項目の候補：移した後の `results/` のフォルダの並び（評価担当が `dir` で一覧にしたもの）を見て、名前で中身が分かるか。

### 7.4 読むパスの一覧（改名の後）

| スクリプト | 読むパス（`experiments/` の下） |
|---|---|
| `bilateral/bilateralOri_centroid_1cycle.m` | `2026-0807/cycleResult_rsmplD_2026-0807.mat` |
| `evaluation/grooveBottomDetection/compareInclBoundToExclBound.m` | `2026-1104/cycleResult_origD_hist5_2026-1104.mat` |
| `evaluation/grooveBottomDetection/compareWidthThresh.m` | `2026-1014/cycleResult_origD_track_2026-1014.mat`、`2026-1104/cycleResult_origD_hist5_2026-1104.mat`、`2026-1104/cycleResult_origD_track5_2026-1104.mat`、`2026-1014/cycleResult_origD_2026-1014.mat` |
| `evaluation/grooveTracking/compareTrackingToManual.m` | `2026-0731/cycleResult_origD_2026-0731.mat`、`2026-0731/cycleResult_intpD_2026-0731.mat`（`TRACK_DATE`・`MANUAL_DATE` は `"YYYY-MMDD"` のまま） |
| `evaluation/multiGroove/compareHistToTracking.m` | `2026-1014/cycleResult_origD_track_2026-1014.mat`（`GT_DATE`・`HIST_DATE` は `"YYYY-MMDD"` のまま） |
| `paper/202609asj/fig5_spectrogramComparisonOrigD.m`、`fig_waveformComparisonOrigD.m` | `2026-0731/cycleResult_origD_2026-0731.mat` |
| `paper/202609asj/fig6_spectrogramUpsampling.m`、`fig_waveformUpsampling.m` | `2026-0731/cycleResult_rsmplD_2026-0731.mat`、`2026-0731/cycleResult_intpD_2026-0731.mat`、`2026-0802/cycleResult_origD_2026-0802.mat` |
| `pkCentroid_interp2_1cycle.m` | `2026-0731/cycleResult_intpD_2026-0731.mat`（Q5） |
| `pkCentroid_resample_1cycle.m` | コメントの中の `2026-0807/cycleResult_rsmplD_2026-0807.mat` |
| `progress/grooveBtmOnImageTrackOutlier.m`、`grooveOnImageManualAndTrack.m`、`waveformManualVsTrack.m`、`wideBottomOutlierWaveform.m` | `2026-1014/cycleResult_origD_2026-1014.mat`、`2026-1014/cycleResult_origD_track_2026-1014.mat` |
| `progress/wideBottomOutlier.m` | `2026-1014/cycleResult_origD_track_2026-1014.mat` |
| `progress/multiGrooveOnePhoto.m`、`waveformTrackVsHist.m` | `2026-1104/cycleResult_origD_track5_2026-1104.mat`、`2026-1104/cycleResult_origD_hist5_2026-1104.mat` |
| `progress/wideBottomOutlierWidthThresh.m` | `2026-1014/cycleResult_origD_track_2026-1014.mat`、`2026-1104/cycleResult_origD_hist5_2026-1104.mat` |
| `slides/202609asj/waveformAndSpectrogramOrigD.m` | `2026-0731/cycleResult_origD_2026-0731.mat` |
| `slides/202609asj/waveformAndSpectrogramUpsampling.m`、`waveformUpsampling.m` | `2026-0731/cycleResult_rsmplD_2026-0731.mat`、`2026-0731/cycleResult_intpD_2026-0731.mat`、`2026-0802/cycleResult_origD_2026-0802.mat` |

### 7.5 評価の段階で作る正式なデータ・ユーザーが作るデータ

- `experiments/` に新しく作るデータは無い。評価の出力は `results/bilateralFilter/`・`results/grooveTracking/` の実行フォルダと `temp/` に置く。
- `ginput` が要るデータは無い（ユーザーが作るデータは無い）。

## 8. 決定事項と未決事項

### 決定事項（2026-11-24、ユーザーの回答）

- **Q1：(a)。** `experiments/` は評価の直前（同じ日）に改名する。マージまでは、master のスクリプトで `experiments/` を読まない。
- **Q2：(a)。** 移行は main が行う。承認B・C のたびに試しの表を見せ、ユーザーが了承してから実行する。
- **Q3：(a)。** `runInfo.json` の形は 4.3 の表のとおりにする。
- **Q4：(a)。** `Histogram` があれば、`tol` に `bandTol`、`binWidth` に `binWidth` を写し、ほかは `NaN` にする。
- **Q5：(a)。** ループの中の定数は値を変えずに冒頭へ移す。`pkCentroid_interp2_1cycle.m` は `cycleResult_intpD_2026-0731.mat` を読む。`photoshop_localMax_1cycle.m` には `WidthThresh=NaN` を渡し、`ScriptName` を直す。今ある `checkcode` の警告は直さず、変更で警告を増やさない。
- **Q6：(a) に1行を足す。** 実験名は8つ（`upsampling`・`photoshopUpscaling`・`bilateralFilter`・`digitalNeedle`・`grooveTracking`・`multiGroove`・`grooveBottomDetection`・`stylus`）にする。README に書く実験名の決め方には、「issue の slug が、すでにある進捗報告用の図のテーマや評価スクリプトの置き場所の名前と違うときは、すでにある名前に合わせる」を足す（5.1 の手順9）。
  - ユーザーは、issue の規則のうち「slug に合わせる」と「図のテーマと同じ名前にする」が #35 でぶつかることを確かめたうえで、こう決めた。
- **仮定：承認。** 否定されなかったので、8章末尾の2つの仮定のとおりに進める。
- **まだ決めていないこと**
  - `mapping-draft.md` の M1〜M5 と、M6 のうち説明（`LABEL`）の最終案は、移す直前（承認B）に決める。

以下は、決める前の検討の記録。

計画の承認のときに、次の Q1〜Q6 を決めてほしい。`mapping-draft.md` の M1〜M5 は、移す直前（承認B）までに決めればよい（M6 は Q6 と同じ）。

- **Q1 `experiments/` を改名してから PR をマージするまでの間の扱い**
  - 背景：改名の後は、master のスクリプトが古い名前を探して動かない。評価で新しい名前のデータを読むので、改名は評価の前に行う必要がある。
  - (a) 評価の直前（同じ日）に改名し、マージまで master のスクリプトで `experiments/` を読まない（推奨）。改名の期間に master のスクリプトを動かすと「ファイルが無い」エラーで止まるだけで、データは消えない。進捗ログの定期タスクは `experiments/` を読まない。急ぎで図を作るときは、作業ブランチのスクリプトを使う。評価に合格したら、仕上げと PR を急ぎ、期間を1〜2日にする。
  - (b) 評価の直前に、新しい名前のコピーを作り、マージの後で古い名前のフォルダを消す。master は動き続けるが、約 1.7 GB の重複ができる。古いほうを消す作業（ユーザーの確認が要る）が後に残り、バックアップのソフトが両方を写す。
  - (c) 改名をマージの後にする。評価では `temp/` のコピーで古い名前を読む。新しい名前で読めることを評価で確かめられず、マージの後に main がもう一度確かめる必要がある。
- **Q2 移行（`results/` の移動と `experiments/` の改名）を実行する人**
  - (a) main が、承認B・C のたびに試しの表を見せ、ユーザーが「進めてよい」と答えたら実行する（推奨）。作業履歴の決定（`experiments/` の改名はそのつど確かめる）に合う。
  - (b) ユーザーが、MATLAB のコマンドウィンドウで `migrateResults` を実行する。main は試しの表と手順を渡す。
- **Q3 `runInfo.json` の形（4.3 の表）**
  - 背景：issue の例から、次の3点を決めた。(1) `upsampling.kind` は一覧にする。リサンプルと内挿を比べるスクリプト（`darkness3d.m` など）では2つ以上になるため。(2) `segmentation` と `audio` は、その引数を1つでも渡したときだけ書き、書くときは既定値（8・10・78）で埋める。音声を作らないスクリプトに `audio.rpm` を書かないため。(3) `runConditions` に渡すのは冒頭の定数だけにする。そのため、従来法のスクリプト（`pkCentroid_1cycle.m` など）の実行記録には、`audio`・`detrend` が書かれない（回転数と次数をスクリプトの中に直接書いているため）。
  - (a) 4.3 の表のとおりにする（推奨）。
  - (b) (3) を変え、従来法のスクリプトにも回転数などの定数（`RPM = 78` など）を足して渡す。実行記録はそろうが、計算の行（`60/78` など）も書き換えることになる。
  - (c) (2) を変え、`segmentation` と `audio` をいつも書く。実装は少し簡単になるが、音声を作らないスクリプトにも `audio.rpm: 78` が書かれる。
- **Q4 `cycleConditions` の新しい呼び方で、`Manual` が無いときの写し方**
  - 背景：issue は「`Manual` が無ければ `ThHist`・`Tol`・`BinWidth`・`HPrl` を `NaN` にする」としているが、`grooveHist_Ncycle.m` は今 `Tol=BAND_TOL`・`BinWidth=BIN_WIDTH` を渡している（README にもそう書いてある）。
  - (a) `Histogram` があれば、`tol` に `bandTol`、`binWidth` に `binWidth` を写し、ほかは `NaN` にする（推奨）。今と同じ `conditions` になり、issue の「今の呼び方と `isequal`」も満たせる。
  - (b) issue のとおり4つとも `NaN` にする。新しく作る `grooveHist_Ncycle.m` の結果では `conditions.tol`・`binWidth` が `NaN` になり、README の記述と食い違う。
- **Q5 書き換えのときに見つかった、既存のスクリプトの不具合の扱い**
  - 背景：次の4つが、出力先と日付の機械的な置き換えだけでは片付かない。(1) 5本の1周分のスクリプトが、実験条件の定数をループの中で決めている。(2) `pkCentroid_interp2_1cycle.m` の `PREV_RESULT_PATH` が、無いファイル（`cycleResult_intpD_0731_2.mat`）を指している。(3) `photoshop_localMax_1cycle.m` の `W_MAX` が定義されておらず、`ScriptName` が別の名前（`pkLocalMax_1cycle`）になっている。(4) 変える55本のうち7本に、今の時点で `checkcode` の警告が27件ある。
  - (a) 次のようにする（推奨）。(1) 値を変えずに冒頭へ移す。(2) 今ある `cycleResult_intpD_2026-0731.mat` を指す（`meta.savedAt` から、`_2` を改名したものと分かる）。(3) 幅の上限を使っていないので `WidthThresh=NaN` を渡し、`ScriptName` を `"photoshop_localMax_1cycle"` に直す。(4) 今ある警告は直さず、完了条件の「`checkcode` の警告が無い」を「変更で警告を増やさない」と読む。
  - (b) (1)〜(3) は推奨のとおりにし、(4) の警告も直す。動かない2本（`pkCentroid_resample.m`・`pkCentroid_interp2.m`）の21件は使っていない変数の警告で、直すと「機械的に置き換えるだけ」の決定を超える。
  - (c) (1) は推奨のとおりにし、(2)(3) は直さずに日付だけを置き換える。`pkCentroid_interp2_1cycle.m` は無いファイルを読もうとして止まり、完了条件の「読むパスがすべてある」を満たさない。`photoshop_localMax_1cycle.m` は、冒頭の `runConditions` に渡す `W_MAX` が無いので、今（最後の行）より早く、冒頭で止まる。
- **Q6 実験名の一覧（`mapping-draft.md` の1章、M6）**
  - 背景：実験名は、スクリプトの `EXPERIMENT_NAME` の既定値と、README の一覧に使うので、実装の前半までに決める必要がある。
  - (a) 案のとおり8つ（`upsampling`・`photoshopUpscaling`・`bilateralFilter`・`digitalNeedle`・`grooveTracking`・`multiGroove`・`grooveBottomDetection`・`stylus`）にする（推奨）。#35 の実験は、評価スクリプトと進捗報告の図のテーマに合わせて `grooveBottomDetection` にする。
  - (b) #35 の実験を slug に合わせて `wideBottomOutliers` にする。issue の規則には合うが、評価スクリプトの置き場所・進捗報告の図のテーマと名前がずれる。
  - ほかに変えたい名前があれば、指定してほしい。

仮定（承認で否定されなければ、このまま進める）：

- 図のスクリプト（32本）は、`figureDir` の1行と日付の値・`DATE_MMDD` だけを変え、図の保存の仕方は変えない。
- 説明の既定値は、`bilateral/` の1セグメントの4本は今のサブフォルダの名前、評価スクリプト4本は `"evaluation"`、ほかは `""` にする。

## 9. リスク

- **改名の期間に、master や別の worktree のスクリプトが動かない**：Q1 の (a) では、期間を短くし、その間は作業ブランチのスクリプトを使う。worktree の `experiments/` はメインへのジャンクションなので、同じく新しい名前に見える。
- **移行の途中で失敗する**（ファイルが開かれていて `movefile` が失敗するなど）：移行の関数は、全部の行き先を先に確かめ、上書きせず、もう一度呼べば移し終えた行を飛ばす。改名の前に MATLAB で .mat を開いていないことを確かめる（`clear` してから行う）。
- **進捗ログの定期タスクが、夜に master へ切り替える**：スライド用の図は、作業ブランチでは新しい場所、master では古い場所で追跡されているので、切り替えのたびに git が置き場所を入れ替える。どちらのブランチにもあるので、失われるものは無い。`results/` の実行フォルダと原稿用の図は、どちらのブランチでも無視されるので変わらない。
- **laptop**：`results/<MMDD>/` が無いので、`Phase="results"` の行は `missing` の警告で飛ばされる。laptop に `experiments/` があれば、同じ CSV で `Phase="experiments"` を実行する。原稿用の図があれば、`Phase="results"` の該当の行だけが移る。
- **`runInfo.json` に書けない値**（関数ハンドルなど）を `Other` に渡す：`resultDir` はフォルダを作る前に変換するので、エラーで止まり、空のフォルダは残らない。
- **`ScriptName` からパスが決まらない**（名前の重複など）：警告を出し、名前だけを書く。出力は作られる。
- **リポジトリの外の原稿（LaTeX）が、`results/figures/paper/202609asj/` を直接参照している**：202609asj の発表は終わっているので影響は小さい。必要なら、ユーザーが原稿の図のパスを直す。
- **実装の後半の量（55本）**：機械的な書き換えが多い。評価スクリプトの検索（7.3 の3）で、残りを機械的に見つけられるようにしておく。

## 10. 付録：MATLAB での試行

すべて読み取りだけで、`results/`・`experiments/`・`data/` には何も保存していない。関数の形を試すための使い捨ての関数は、リポジトリの外（セッションのスクラッチパッド）に置き、試した後にパスから外した。

### A.1 `jsonencode`・`jsondecode` の動作

```matlab
s = struct("scalarStr","origD", "oneStrArr",["centroid"], "twoStrArr",["centroid" "localMax"], ...
    "oneCell",{{"centroid"}}, "emptyStr",strings(0,1), "nanVal",NaN, "numVec",[3 5 9], ...
    "oneNumCell",{{3}}, "logicalVal",true, "nested",struct("a",1,"b",struct("c","x")), ...
    "jp","N周分（テスト）", "dt",datetime(2026,10,28,14,2,11));
txt = jsonencode(s, PrettyPrint=true); d = jsondecode(txt);
```

| 値 | `jsonencode` | `jsondecode` で読み戻した型 |
|---|---|---|
| 要素が1つの string の配列 `["centroid"]` | `"centroid"`（配列にならない） | char |
| 要素が2つの string の配列 | `["centroid","localMax"]` | 2×1 cell |
| cell `{"centroid"}` | `["centroid"]` | 1×1 cell |
| 空の string・空の cell・`[]` | `[]` | 空の double |
| `NaN` | `null` | 空の double |
| 数のベクトル（行・列とも） | `[3,5,9]` | 3×1 double |
| cell `{3}` | `[3]` | double |
| struct の入れ子 | オブジェクトの入れ子（フィールドの順のまま） | struct |
| 日本語 | そのまま | そのまま |
| datetime | `"2026/10/28 14:02:11"`（表示の形式） | char |

- `PrettyPrint=true` は2文字の字下げで、配列の要素を1行に1つ書く。
- `writelines(txt, path, Encoding="UTF-8")` は BOM を書かない（先頭のバイトが `{`）。`fileread(path, Encoding="UTF-8")` で読み戻せた。
- 日時は `string(datetime(...), "yyyy-MM-dd'T'HH:mm:ss")` で `2026-10-28T14:02:11` になる。

### A.2 省略できる位置引数と name-value 引数

```matlab
function out = trialCc(runCond, opts)
    arguments
        runCond (1,1) struct = struct()
        opts.Upsampling (1,1) string
        opts.Date (1,1) string
        opts.LMask (1,1) double
    end
    out = struct("nFields", numel(fieldnames(runCond)), "given", strjoin(string(fieldnames(opts)),","));
end
```

- `trialCc(Upsampling="origD", Date="0731", LMask=20)` → `nFields = 0`、3つとも name-value として受け取れた。
- `trialCc(struct("x",1), Date="2026-0731")` → `nFields = 1`。
- `trialCc("Upsampling","origD","Date","0731")`（カンマ区切りの書き方）も通った。
- `trialCc(Foo=1)` → エラー `MATLAB:TooManyInputs`。

### A.3 `NaN` を含む struct の比べ方

- `isequal(struct("v",NaN), struct("v",NaN))` は false、`isequaln` は true。
- `matlab.unittest` の `verifyEqual(struct("v",NaN), struct("v",NaN))` は通る。
- `isequal` は struct のフィールドの順によらない（`isequal(struct("x",1,"y",2), struct("y",2,"x",1))` は true）。

### A.4 `cycleConditions` への写し方の試作

試作の `runConditions`（4.2.2 の簡略版）と、その出力を今の `cycleConditions` の name-value に写して呼ぶ関数を作り、今の呼び方の出力と比べた。

```matlab
function cond = protoCycleFromRun(rc, opts)   % 試作（リポジトリには置かない）
    arguments
        rc (1,1) struct
        opts.Date (1,1) string
        opts.SaveDir (1,1) string
        opts.ExperimentDir (1,1) string = ""
        opts.Filenames (:,1) string = strings(0,1)
        opts.ScriptName (1,1) string = ""
        opts.Note (1,1) string = ""
    end
    kinds = string(rc.upsampling.kind);
    nv = {"Upsampling",kinds,"Date",opts.Date,"SaveDir",opts.SaveDir,"ExperimentDir",opts.ExperimentDir, ...
        "Filenames",opts.Filenames,"ScriptName",opts.ScriptName,"Note",opts.Note, ...
        "NumImages",rc.segmentation.numImages,"NumSegments",rc.segmentation.numSegments, ...
        "LMask",rc.segmentation.lMask,"DThresh",rc.grooveBottom.dThresh,"WTh",rc.grooveBottom.widthThresh};
    switch kinds
        case "rsmplD", nv = [nv, {"PRsmpl",rc.upsampling.p,"QRsmpl",rc.upsampling.q}];
        case "intpD",  nv = [nv, {"QueryStep",rc.upsampling.queryStep,"InterpMethod",rc.upsampling.interpMethod}];
    end
    gs = struct(); if isfield(rc,"grooveSelection"), gs = rc.grooveSelection; end
    if isfield(gs,"manual")
        m = gs.manual; nv = [nv, {"ThHist",m.thHist,"Tol",m.tol,"BinWidth",m.binWidth,"HPrl",m.hPrl}];
    elseif isfield(gs,"histogram")
        h = gs.histogram; nv = [nv, {"ThHist",NaN,"Tol",h.bandTol,"BinWidth",h.binWidth,"HPrl",NaN}];
    else
        nv = [nv, {"ThHist",NaN,"Tol",NaN,"BinWidth",NaN,"HPrl",NaN}];
    end
    if isfield(rc,"detrend") && isfield(rc.detrend,"polyDegree"), nv = [nv, {"PolyDegree",rc.detrend.polyDegree}]; end
    if isfield(rc,"audio"), nv = [nv, {"Rpm",rc.audio.rpm}]; end
    cond = cycleConditions(nv{:});
end
```

各スクリプトの今の `cycleConditions` の呼び出しと同じ定数（`pkCentroid_1cycle.m`・`pkCentroid_resample_1cycle.m`・`pkCentroid_interp2_1cycle.m`・`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`）で比べた結果：

| 場合 | `isequal` | `isequaln` |
|---|---|---|
| origD（手動） | 1 | 1 |
| rsmplD（手動） | 1 | 1 |
| intpD（手動） | 1 | 1 |
| 追跡（`NaN`） | 0 | 1 |
| ヒストグラム（`Tol=3`・`BinWidth=1`） | 0 | 1 |
| ヒストグラムを、issue の「`Manual` が無ければ `NaN`」で写した場合 | — | 0（`tol`・`binWidth` が `NaN` になる） |

### A.5 `runInfo.json` の例（試作の出力）

`grooveHist_Ncycle.m` の定数を試作の `runConditions` に渡し、4.3 の順に並べて `jsonencode` した（`meta` は試行した PC の値）。

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
      "tracking": { "tolerance": 2, "fitLength": 60, "snapRadius": 10, "initLength": 20, "maxGapLength": 40 },
      "histogram": { "numGrooves": 5, "binWidth": 1, "thHistRatio": 0.3, "bandTol": 3 }
    },
    "detrend": { "polyDegree": 9, "scope": "photo" },
    "audio": { "rpm": 78, "ampDiv": 1.5 }
  },
  "meta": {
    "createdAt": "2026-11-24T13:33:32",
    "git": { "commit": "c7d2460", "branch": "claude/results-by-experiment", "dirty": false },
    "matlabRelease": "R2024b",
    "computerName": "（PC の名前）"
  }
}
```

（実際の出力は `PrettyPrint` で配列の要素を1行に1つ書く。ここでは読みやすさのために詰めた。）`jsondecode` で読み戻すと、`upsampling.kind`・`methods`・`inputs.files` はどれも cell になった。

### A.6 `.gitignore` の規則

使い捨てのリポジトリ（スクラッチパッド）に issue の規則を書き、ファイルを置いて `git add -A` した。

```
/results/*
!/results/figures/
/results/figures/*
!/results/figures/*/
/results/figures/*/*
!/results/figures/*/slides/
!/results/figures/progress/*
```

- 追跡された：`results/figures/202609asj/slides/x.png`、`results/figures/202609asj/slides/sub/y.png`、`results/figures/202702thesis/slides/a.png`、`results/figures/progress/grooveTracking/x.png`、`results/figures/progress/x.png`
- 無視された：`results/figures/202609asj/paper/x.png`、`results/figures/202702thesis/paper/fig.pdf`、`results/figures/202609asj/x.png`、`results/figures/x.png`、`results/grooveTracking/2026-1014/x.png`、`results/0731/a.wav`

### A.7 日付の確かめ方

`datetime(s, "InputFormat", "yyyy-MMdd")` は、`"2026-1124"` を読み、`"2026-0230"`・`"2026-1328"`・`"2026-0000"` ではエラー `MATLAB:datetime:ParseErr` を出した。`resultDir` は、このエラーを `resultDir:invalidDate` に置き換える。

### A.8 変える前の `checkcode` の警告

55本（実験のスクリプト23本と図のスクリプト32本）に `checkcode` をかけた（2026-11-24）。

| スクリプト | 件数 | 内容 |
|---|---|---|
| `pkCentroid_resample.m` | 13 | 使っていない変数 |
| `pkCentroid_interp2.m` | 8 | 使っていない変数 |
| `progress/multiGrooveOnePhoto.m` | 2 | ループの中の `axes` |
| `bilateral/bilateralOri_centroid_1cycle.m` | 1 | ループの中で大きさが変わる変数 |
| `progress/showPhotoshopGrooveExtraction.m` | 1 | 使っていない関数 |
| `paper/202609asj/fig4_darkness3dComparison.m` | 1 | ループの中の `axes` |
| `slides/202609asj/darkness3dComparison.m` | 1 | ループの中の `axes` |
| 合計（7本） | 27 | |

### A.9 そのほか

- `cycleResult_intpD_0731.mat` の `meta`：`savedAt = 2026/08/07 13:41:34`、`scriptName = pkCentroid_interp2_1cycle`、`gitCommit = d42df89`、`gitDirty = 1`（読み込みに約19秒）。
- `git rev-parse --abbrev-ref HEAD` は約0.2秒、`git status --porcelain` は約0.14秒。`dir(fullfile(root,"scripts","**","<名前>.m"))` は約0.01秒。
- `test/unit/` のテストは、今 27クラス・258件ある。
- `pkCentroid_1cycle.m` が使う `src/` の関数（`fitGroove`・`extractGrooveWaveform`・`GrooveExtractor`・`DarknessMap` など）は、1014 のデータを作ったコミット `3261e62` の後に変わっていない（`git log 3261e62..HEAD -- <ファイル>` で確かめた）。その後に変わった `cycleMethodResult.m`（N周分への対応）は、#30 の回帰の確認で、1周分の `ycoords` が 1014 と `isequal` のままだった。
