- 段階: 評価（1回目）
- 作成者: evaluator（モードB）
- 作成日: 2026-11-26
- 入力: issue #28（本文。コメントなし）、[`./README.md`](./README.md)（作業履歴の決定。承認B・承認C、2026-11-25〜26）、[`./criteria.md`](./criteria.md)（承認済み。7章の決定、8章の手順）、[`./plan.md`](./plan.md)、[`./mapping-draft.md`](./mapping-draft.md)、[`./impl-report-1a.md`](./impl-report-1a.md)、[`./impl-report-1b.md`](./impl-report-1b.md)、main の依頼文
- 状態: 確定（2026-11-26、ユーザーが U1〜U3 を確認し、合格とした）

> **ユーザーの確認（2026-11-26、main が追記）**：U1〜U3 は問題なし。判定は**合格**。7章の未決事項は (a)：評価で作った実行フォルダ3つ（`results/bilateralFilter/2026-1126_1cycle/`・`2026-1126_1cycle_2/`、`results/grooveTracking/2026-1126_check/`）は残す。

# #28 評価レポート（1回目）

## 1. 判定：ユーザー確認待ち

- 数値の項目（T・P・Q・D）は、すべて満たした。
  - P1・P2・Q7 は、評価スクリプトの判定の表では「満たさない」と出た。外れたのは、どれも評価スクリプト自身 `scripts/evaluation/resultsLayout/checkResultsLayout.m` の1本だけだった。`criteria.md` 7章の決定（2026-11-25、(b)）により、満たしたとする。
  - 評価担当が判断する項目（Q6b、Q9 の (2)）は、どちらも「残ってはいけない行」が0だった（4章）。
- ユーザーが判断する項目 U1〜U3 が残っている（6章）。ユーザーが良いと判断すれば合格になる。
- 不合格の項目は無い。実装に戻すものは無い。

## 2. 評価の条件

- 評価したコードは `d1c6c37`（ブランチ `claude/results-by-experiment`）である。評価の前と後とで、`git status --porcelain` は空だった。
- 基準のコミット `BASE_COMMIT` は `0e60754` とした。master からのマージのコミットは無いので、`MERGE_COMMITS` は空にした。
- 承認B で「移さずに残す」「消す」と決めた古い形のものは無いので、`APPROVED_LEFTOVERS`・`APPROVED_DELETIONS` は空にした。`E1_REF_DIR` は `results/bilateralFilter/2026-0924_1cycle` のままにした。
- 移行は、作業履歴のとおり終わっていた。スライド用の図の `git mv` は `3f327ed`、`results/` の移行は `c2ce382`、`experiments/` の改名は `d1c6c37` の作業履歴の行に記録がある。
- 実行した日は 2026-11-26 である。実行の前に、`results/*/2026-1126*` と `experiments/2026-1126/` が無いことを確かめた。
- MATLAB は R2024b で、`Research.prj` を開いた状態で実行した。

### 実行したもの

`temp/28-eval/` のコピーは消さずに残した。どれも、リポジトリのスクリプトから、下に書いた行だけを変えた。

| 手順 | 実行したファイル | 変えた行 | 出力 |
|---|---|---|---|
| T1 | `cd test; results = runAllTests;` | — | — |
| E1（Q10） | `temp/28-eval/bilateralOri_centroid_1cycle_eval1126.m` | `date = "2026-1126"` | `results/bilateralFilter/2026-1126_1cycle/`（37ファイル）。約36秒 |
| E2（Q11） | `temp/28-eval/bilateralOri_centroid_1cycle_eval1126_again.m` | E1 のコピーの `resultDir` の文の直後に `return` | `results/bilateralFilter/2026-1126_1cycle_2/`（`runInfo.json` だけ） |
| E3（Q12） | `temp/28-eval/pkCentroid_1cycle_eval1126.m` | `EXPERIMENT_NAME = "grooveTracking"`、`date = "2026-1126"`、`LABEL = "check"`、`PREV_RESULT_PATH` を `experiments/2026-1014/cycleResult_origD_2026-1014.mat`、`experimentDir(...,Create=false)`、`saveCycleResult` の2行を `temp/` への `save` の1行に | `results/grooveTracking/2026-1126_check/`（15ファイル）、`temp/28-eval/check_pkCentroid_1cycle.mat`。約16秒 |
| E4（Q9 の (1)） | `temp/28-eval/waveformManualVsTrack_eval1126.m` | `figureDir` の行を、`temp/28-eval/fig_waveformManualVsTrack/` を作って返す行に | `temp/28-eval/fig_waveformManualVsTrack/`（8ファイル） |
| E5（Q13） | `scripts/bilateral/bilateralOri_centroid_1cycle.m`（書き換えていないもの） | — | なし |
| 評価スクリプト | `temp/28-eval/checkResultsLayout_eval1126.m` | `BASE_COMMIT`、`E1_RUN_DIR`・`E2_RUN_DIR`・`E3_CHECK_MAT`・`E3_RUN_DIR`・`E4_FIG_DIR` | 表示だけ。全文を `temp/28-eval/checkResultsLayout_eval1126_out.txt` に写した。約63秒 |

- 使ったデータ
  - `experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat`（E1・E2 の溝の選択）
  - `experiments/2026-1014/cycleResult_origD_2026-1014.mat`（E3 の溝の選択と、比べる相手）
  - `experiments/2026-1014/cycleResult_origD_track_2026-1014.mat`（E4）
  - `results/bilateralFilter/2026-0924_1cycle/`（E1 の出力のファイル名と wav を比べる相手）
  - `scripts/evaluation/resultsLayout/manifestBeforeMigration.csv`（移す前の記録、817行）
- `experiments/` と `data/` には、何も保存・上書き・削除していない。E3 の `experimentDir` は `Create=false` で、`experiments/2026-1126/` はできていない。`ginput` は一度も呼ばれていない。
- 評価スクリプトの不具合は無かったので、直していない。ただし1回目の実行では、`diary` に出力が残らなかった（MCP の実行が出力を取り込むため）。そのため、同じコピーを `evalc` でもう一度実行し、出力をファイルに写した。2回の判定の表は同じだった。

## 3. 項目ごとの結果

### 3.1 テスト（T）

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| T1 | `runAllTests` の失敗・未完了 | 0件 | 346件すべて通過（失敗 0、未完了 0）。受け入れテスト `ResultLayoutAcceptanceTest` は 42/42 | 満たす |
| T2 | `checkcode` の警告が増えたファイル | 0個 | 0個。変えた・足した `.m` 74個を調べ、変える前 27件、後 27件（7本。内訳は `criteria.md` 3.4 と同じ） | 満たす |

### 3.2 計画どおりかの確認（P）

| ID | しきい値 | 実測値 | 判定 |
|---|---|---|---|
| P1 | 外れ 0本（23本） | 対象 24本のうち外れ 1本。外れは評価スクリプト自身 `scripts/evaluation/resultsLayout/checkResultsLayout.m` だけ（「`resultDir` が 0回、`runConditions` が 0回」）。ほかの23本は、実験名・説明が `plan.md` 4.4 の既定値と同じで、`resultDir` の第4引数が `runCond` | 満たす（7章の決定による） |
| P2 | 外れ 0本（8本） | 対象 9本のうち外れ 1本。外れは評価スクリプト自身だけ（「`cycleConditions` の第1引数が `runConditions` の出力でない」）。ほかの8本は第1引数が `runCond` | 満たす（7章の決定による） |
| P3 | 外れ 0本（32本） | 0本。32本とも `figureDir` が1回で、用途と名前が基準のコミットの保存先と同じ | 満たす |
| P4 | 計画の外の差分 0件 | 0件。55本以外の `scripts/` の変更は無い | 満たす |
| P5 | 読むパス9個で無いもの 0個 | 0個 | 満たす |
| P6 | README の記述の外れ 0件 | 0件。実験名の決め方の1行、階層の順が逆になることの記述、版の表（版1、2026-11、issue #28）を読んで確かめた | 満たす |
| P7 | ほかの文書と `.gitignore` の外れ 0件 | 0件 | 満たす |
| P8 | 移るファイルの数が計画と同じ | 日付のフォルダ 603、原稿用 55、スライド用 52、`experiments/` 12 が移り、進捗報告用 92 と `archive/` 3 は動かない。行き先のフォルダごとの数を README の「対応表」と `mapping-draft.md` の数と比べ、すべて同じだった | 満たす |

### 3.3 品質の基準（Q）

| ID | しきい値 | 実測値 | 判定 |
|---|---|---|---|
| Q1 | 817/817 | 817/817（移し先に無い 0、大きさが違う 0、SHA-256 が違う 0） | 満たす |
| Q2 | 余計なファイル 0個 | 移し先 0個、`experiments/` 0個 | 満たす |
| Q3a | 試しの status がすべて `done` | 79行（`results` 57、`experiments` 22）のうち `done` 以外 0行 | 満たす |
| Q3b | 古い形のフォルダ 0個 | 0個 | 満たす |
| Q4 | 名前の規則の外れ 0件 | 0件 | 満たす |
| Q5 | git の追跡 | `git ls-files results` 144（スライド用 52、進捗報告用 92）。基準のコミットからの `results/` の差分は R100 の52行だけ。`check-ignore` の14の例はすべて期待どおり。`git status --porcelain` 0行 | 満たす |
| Q6a | 検索1〜3と補いに当たる行 0行 | 0行 | 満たす |
| Q6b | 要確認の行のうち、残ってはいけない行 0行 | 要確認 2行。どちらも残ってよい行で、残ってはいけない行は 0行（4章） | 満たす |
| Q7 | 日付の変数がすべて `"YYYY-MMDD"` | 外れ 1本。評価スクリプト自身だけ（`resultDir` を呼ばないので日付の変数が無い）。ほかの23本は `"YYYY-MMDD"` | 満たす（7章の決定による） |
| Q8 | スクリプトに書かれた日付のフォルダ・ファイルで無いもの 0個 | 0個（日付 26行、ファイル名 15行を確かめた） | 満たす |
| Q9 | (1) 図の名前に `_1014` があり `2026-` が無い。(2) 図の名前・タイトルを組み立てる文 0 | (1) 図8個すべて満たす（例 `waveform_manualVsTrack_centroid_origD_1014_full.png`）。(2) 候補 2文。どちらも図の名前・タイトルではない（4章） | 満たす |
| Q10 | E1 の外れ 0件 | 0件。`results/bilateralFilter/2026-1126_1cycle/` に、0924 の実行と同じ名前の36ファイルと `runInfo.json` ができた。`runInfo.json` の値は `criteria.md` 8章の表と同じ。`meta.git.dirty` は false、`meta.git.commit` は `d1c6c37` | 満たす |
| Q11 | `_2` が付き、`run` も同じ。警告が出る | `results/bilateralFilter/2026-1126_1cycle_2/` ができ、`runInfo.json` の `run` は `2026-1126_1cycle_2`。警告は下の引用のとおり | 満たす |
| Q12 | `ycoords` が `isequal`、`cond` が `isequaln`（3つを除く）、`runInfo.json` が `cond` と同じ | 外れ 0件。評価担当が別に読み直しても、重心法・局所的最大値法の `ycoords` は `isequal`、`cond` は `date`・`saveDir`・`experimentDir` を除いて `isequaln` だった | 満たす |
| Q13 | 止まり、フォルダを作らない | `resultDir:dateNotSet` で止まった。`results/bilateralFilter/` の一覧は実行の前後で同じ | 満たす |

- Q11 の警告（識別子 `resultDir:folderExists`）
  - 「results/bilateralFilter/2026-1126_1cycle はすでにあるので、2026-1126_1cycle_2 に出力します（上書きしないため）。」
- Q13 のエラーのメッセージ
  - 「date が "YYYY-MMDD" のままです。実行した日を "2026-1124" の形で書いてください。」

### 3.4 変えてはいけないもの（D）

| ID | しきい値 | 実測値 | 判定 |
|---|---|---|---|
| D1 | 差分 0件 | 0件 | 満たす |
| D2 | コメントでない差分 0行、`mkdirFromDate.m` が残る | 5つとも 0行、`mkdirFromDate.m` は残っている | 満たす |
| D3 | 15/15 | 15/15 | 満たす |
| D4a | 進捗報告用の図の git の差分 0件 | 0件 | 満たす |
| D4b | 92/92 | 92/92 | 満たす |

## 4. 評価担当が判断した項目

- Q6b（検索4の要確認の2行）
  - `README.md` 75行は、`mkdirFromDate` の説明である。「古い形の出力先 `results/<日付>/` を作成し…新しいコードでは `resultDir` を使う」と書いている。古い置き場所を過去のこととして書いた行で、`criteria.md` 5章の「残ってよい」の例そのものである。
  - `docs/rules/figures.md` 251行は、#28 の例外の記録である。移す前の置き場所（`results/0731/`、`results/figures/slides/202609asj/` など）を、移したことの記録として書いている。5章の「残ってよい」の例そのものである。
- Q9 の (2)（日付の変数を、読み込みのパス以外で使っている2文）
  - どちらも `scripts/evaluation/grooveTracking/compareTrackingToManual.m`（109行・136行）で、評価の表の行の説明の文字列に `GT_DATE` を入れている。コマンドウィンドウに出す表の文で、図の名前・タイトルではない。

## 5. 気づいた点（判定には使わない）

- E1 の wav 4つは、移した 0924 の実行の wav と完全に同じだった（`audioread` の値が `isequal`）。
- E3 では、`audiowrite` の警告「ファイルの書き込みに際しデータが切り捨てられました」（`MATLAB:audiovideo:audiowrite:dataClipped`）が1回出た。振幅が ±1 を超える標本を切り捨てたという意味で、`pkCentroid_1cycle.m` の音声の作り方による、前からある動作である。このissueの変更とは関係ない（`ycoords` は保存した結果と同じ）。
- 評価の実行で、`results/` に次の3つの実行フォルダができた。`results/` は git の管理外である。U1 の並びに出る。
  - `results/bilateralFilter/2026-1126_1cycle/`（37ファイル）
  - `results/bilateralFilter/2026-1126_1cycle_2/`（`runInfo.json` だけ）
  - `results/grooveTracking/2026-1126_check/`（15ファイル）
- 実装担当の確認で作った `results/bilateralFilter/2026-1125_implCheck/`（37ファイル）と `results/grooveTracking/2026-1125_implCheck/`（15ファイル）は、ユーザーの決定のとおり残っており、問題として扱っていない。名前は Q4 の規則に合う。

## 6. ユーザーが判断する項目

### U1 results/ の並び

- 見るもの：下の表（評価スクリプトの出力 `temp/28-eval/checkResultsLayout_eval1126_out.txt` の「U1」）。エクスプローラで `results/` を開いてもよい。
- 観点：フォルダ名を見れば、いつ・何の実験かが分かるか。混ざっていたフォルダ（`0731`・`1014`・`1028`・`1104`・`1118` など）の分け方と、説明の語（`origD`・`manual`・`track5`・`evaluation` など）が分かりやすいか。
- 表のうち `2026-1125_implCheck` は実装担当の確認、`2026-1126_*` はこの評価で作ったものである。

| 実験名 | 実行フォルダ（ファイルの数） |
|---|---|
| `bilateralFilter` | `2026-0820_ori`（13）、`2026-0820_oriIntp`（13）、`2026-0820_oriRsmpl`（13）、`2026-0820_photoshop8x`（13）、`2026-0924_1cycle`（36）、`2026-1125_implCheck`（37）、`2026-1126_1cycle`（37）、`2026-1126_1cycle_2`（1） |
| `digitalNeedle` | `2026-0831`（2） |
| `grooveBottomDetection` | `2026-1111_exclBoundVsInclBound`（5）、`2026-1118_evaluation`（102）、`2026-1118_hist5`（14）、`2026-1118_track`（14）、`2026-1118_track5`（14） |
| `grooveTracking` | `2026-1013`（22）、`2026-1014_evaluation`（24）、`2026-1014_manual`（14）、`2026-1014_track`（22）、`2026-1022`（22）、`2026-1026`（22）、`2026-1110`（2）、`2026-1125_implCheck`（15）、`2026-1126_check`（15） |
| `multiGroove` | `2026-1028_hist5`（30）、`2026-1028_track`（22）、`2026-1028_track5`（22）、`2026-1104_evaluation`（14）、`2026-1104_hist5`（30）、`2026-1104_track5`（22） |
| `photoshopUpscaling` | `2026-0802_centroid`（7）、`2026-0802_localMax`（7）、`2026-0817`（5） |
| `upsampling` | `2026-0721`（1）、`2026-0724_intpD`（7）、`2026-0724_rsmplD`（7）、`2026-0731_intpD`（6）、`2026-0731_intpD_2`（14）、`2026-0731_origD`（14）、`2026-0731_rsmplD`（14）、`2026-0807_rsmplD`（14） |
| `figures` | `202609asj/paper`（55）、`202609asj/slides`（52）、`progress/grooveBottomDetection`（16）、`progress/grooveTracking`（54）、`progress/multiGroove`（22） |

`stylus` は、まだ実行していないのでフォルダが無い。

### U2 実データの runInfo.json

- 見るもの
  - `results/bilateralFilter/2026-1126_1cycle/runInfo.json`（`bilateralOri_centroid_1cycle.m` の実行）
  - `results/grooveTracking/2026-1126_check/runInfo.json`（`pkCentroid_1cycle.m` で 1014 の手動選択を再現した実行）
- 観点：使った画像、バイラテラルフィルタのカーネル（`conditions.preprocessing.bilateral`）、溝の選び方（`conditions.grooveSelection`）などの実験条件を、後から読んで分かるか。キーの名前と並び、README の「`runInfo.json` の項目」の表の単位の説明が分かりやすいか。

### U3 README の節

- 見るもの：`README.md` の「結果の置き場所と実行記録」（295行から）。中の「実験名の一覧」（323行）、「実験名の決め方」（338行）、「実行フォルダの名前の決め方」（347行）、「`runInfo.json` の項目」（383行）、「対応表（移す前の置き場所）」（486行）。
- 観点：新しく実験を始めるとき、実験名と説明をどう決め、出力がどこにできるかが分かるか。過去の記録に書かれた古いパス（例 `results/1014/`）から、今の場所を引けるか。

## 7. 未決事項

- 評価で作った実行フォルダ3つ（5章）を残すか、消すか。
  - 背景：`results/` は git の管理外で、評価担当は既存の出力を消さない決まりなので、残したままにした。
  - (a) 残す。`2026-1126_1cycle` は、新しい形で作った最初の実データの実行記録の例になる。`_2` は `runInfo.json` だけのフォルダとして残る。
  - (b) `2026-1126_1cycle_2` だけを消す。中身が `runInfo.json` だけで、警告の確認のためだけに作ったものだからである。
  - (c) 3つとも消す。
  - 推奨：(a)。消さなくても害が無く、implCheck のフォルダを残したユーザーの決定とそろうため。
