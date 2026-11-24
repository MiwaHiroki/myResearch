- 段階: 評価基準
- 作成者: evaluator（モードA）
- 作成日: 2026-11-24
- 入力: issue #28（本文。コメントなし）、[`./plan.md`](./plan.md)（承認済み。8章の決定事項）、[`./mapping-draft.md`](./mapping-draft.md)、[`./README.md`](./README.md)（作業履歴の決定）、main の依頼文、`docs/issues/closed/35-wide-bottom-outliers/criteria.md`
- 状態: 下書き

# #28 結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す — 評価基準

## 1. 結論（判定の決め方）

- このissueで評価するのは、次の4つである。
  - 新しい関数（`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState`・`migrateResults`）と、`cycleConditions` の新しい呼び方。受け入れテスト（T1）で確かめる。
  - スクリプト55本・文書・`.gitignore` の書き換え。評価スクリプトが、スクリプトを読んで計画どおりか（P）と古い書き方が残っていないか（Q6〜Q9）を確かめる。
  - main が行う移行（`results/` の移動、スライド用の図の `git mv`、`experiments/` の改名）。移す前に記録したすべてのファイル（817個）の SHA-256 と照らす（Q1〜Q5）。
  - 実データでの実行（Q10〜Q13）。スクリプトの `temp/` のコピーで、新しい実行フォルダと実行記録ができること、数値の出力が変わらないことを確かめる。
- しきい値は、次の2種類に分けた（4章）。
  - **計画どおりかの確認（P）**：実験名・説明の既定値、`figureDir` の引数、変えたファイルの範囲、移すファイルの数など、`plan.md` と対応表に書かれた値と同じかを確かめる。計画どおりなら同じ値になるので、余裕は無い（ぴったり同じであることを求める）。品質の基準ではない。
  - **品質の基準（Q）**：issue の判断の基準（フォルダ名で分かる、上書きしない、後からたどれる）と制約（数値の出力を変えない、追跡するものを変えない、`experiments/` の中身を変えない）から決めた。ファイルが1つでも失われる・中身が変わる・出力の数値が変わることを許さないので、しきい値は「0件」「同じ」になる。
- 判定
  - **合格**：T・P・Q・D の数値の項目をすべて満たし、ユーザーが判断する項目 U1〜U3 でユーザーが良いと判断したとき。
  - **ユーザー確認待ち**：数値の項目をすべて満たし、U1〜U3 が残っているとき。評価レポートはこの判定で出し、見るものと観点を書く。
  - **不合格**：実装担当が作ったもの（`src/`、スクリプト、文書、`.gitignore`、対応表の CSV、`migrateResults`）が原因で、T・P・Q・D のどれか1つでも満たさないとき。どのファイルの何行目・どのファイルがどう外れたかを書いて、実装に戻す。「計画」だけを満たさず「品質」をすべて満たすときも不合格にする（#30・#35 と同じ決め方。7章の Q-a）。
  - **評価の保留**：main が行う移行の手順（`git mv`、`migrateResults` の実行、`experiments/` の改名）が終わっていないか、その手順の誤りが原因で Q1〜Q5 を満たさないとき。特に Q1（ファイルが無い・中身が違う）は、データが失われた疑いがあるので、評価をそこで止め、直そうとせずに main に報告する。
- 基準は実装の前に決めたもので、実装の結果に合わせて変えない（`docs/rules/evaluation.md`）。ただし、対応表の細部（`mapping-draft.md` の M1〜M5 と説明の最終案）は承認B で決まる。そのため、移行の項目は、実行フォルダの名前を決め打ちせず、承認B で決まった対応表の CSV（`scripts/migration/resultsMapping.csv`）を読んで確かめる。
- このissueでは `experiments/` に新しいデータを作らない。ユーザーが作るデータも無い（`plan.md` 7.5）。

## 2. 評価するものと、この文書の言葉

### 2.1 評価するもの

| 区分 | 中身 | 作る人 | 確かめ方 |
|---|---|---|---|
| 関数 | `src/resultDir.m`・`runConditions.m`・`figureDir.m`・`collectMeta.m`・`gitState.m`、`src/cycleConditions.m` の新しい呼び方、`scripts/migration/migrateResults.m` | implementer（前半） | 受け入れテスト `test/unit/ResultLayoutAcceptanceTest.m`（T1） |
| スクリプト | 実験のスクリプト23本、図のスクリプト32本 | implementer（後半） | 評価スクリプト（P1〜P5、Q6〜Q9） |
| 文書 | README、`CLAUDE.md`、`docs/rules/`、`docs/refactoring/common-functions.md`、`.claude/`、`.github/ISSUE_TEMPLATE/figure.md`、`.gitignore` | implementer（前半・後半） | 評価スクリプト（P6・P7・Q6）と、評価担当（B）が読む |
| 対応表 | `scripts/migration/resultsMapping.csv`（承認B のもの） | implementer（後半）、ユーザーが承認 | 評価スクリプト（P8・Q1〜Q4） |
| 移行 | `results/` の移動、スライド用の図の `git mv`、`experiments/` の改名 | main（承認B・C の後） | 評価スクリプト（Q1〜Q5、D3・D4） |
| 実データの実行 | `temp/` のスクリプトのコピーで作る実行フォルダ | evaluator（B） | 評価スクリプト（Q9〜Q12）と、評価担当の記録（Q11 の警告、Q13） |

### 2.2 言葉

- **基準のコミット**：受け入れテストと評価スクリプトを追加したコミット。この文書では `<受け入れテストを追加したコミット>` と書き、main がコミットするときにハッシュを埋める。差分はこのコミットと評価する時点の `HEAD` の間でとる。
- **移す前の記録**：評価基準の段階（2026-11-24）に、`results/` と `experiments/` のすべてのファイルについて、ルートからのパス・大きさ・SHA-256 を記録した表。`scripts/evaluation/resultsLayout/manifestBeforeMigration.csv`（817行）に置いた。
- **対応表**：既存のフォルダ・ファイルの、移す前の名前と移した後の名前の表。移行の関数が読む CSV（`scripts/migration/resultsMapping.csv`）を指す。列は `phase,kind,source,destination,note`（`mapping-draft.md` 5章）。
- **移し先**：移す前の記録の各ファイルに、対応表の行を上から順に当てはめ、最後にスライド用の図の `git mv`（`results/figures/slides/202609asj/` → `results/figures/202609asj/slides/`）を当てはめて求めた、そのファイルがあるはずの場所。`files` の行のパターンは、MATLAB の `dir`（Windows）と同じく `*` だけを使い、大文字・小文字を区別しない。
- **実験のスクリプト（23本）**：基準のコミットで `mkdirFromDate` を使っていた `scripts/` のスクリプト（archive を除く）。**1周分のスクリプト（8本）**はそのうち `cycleConditions` を呼ぶもの。**図のスクリプト（32本）**は、基準のコミットで `"results","figures"` を組み立てていたもの。どれも評価スクリプトが基準のコミットから探す（`plan.md` 2.1 の一覧と同じになる）。
- **古い書き方**：`mkdirFromDate` で作る出力先、`results/<MMDD>/`・`experiments/<MMDD>/` の形のパスと日付、`results/figures/{paper,slides}/<発表名>/` の置き場所。
- **B**：評価の段階の評価担当（evaluator モードB）。評価スクリプトの表で「B が判断」となった項目は、B が一覧を読んで、この文書の基準で判断する。

## 3. しきい値の根拠（実測値）

評価担当が 2026-11-24 に、作業ブランチ `claude/results-by-experiment` の `ef39e86`（計画の承認のコミット）で、読み取りだけで確かめた。`results/`・`experiments/`・`data/` には何も作っていない。試行のファイルは `temp/28-criteria/`（git 管理外）に置いた。

### 3.1 移す前のファイルの数と中身（Q1〜Q5、P8 の根拠）

数え直した値は、依頼文と `plan.md` 2.3・`mapping-draft.md` 付録 B の見込みとすべて同じだった（違いは無い）。

| 置き場所 | ファイルの数 | 補足 |
|---|---|---|
| `results/` の日付のフォルダ（19個） | 603 | 内訳は付録 B。`0710/` は空 |
| `results/figures/paper/202609asj/`（原稿用） | 55 | git 管理外 |
| `results/figures/slides/202609asj/`（スライド用） | 52 | git で追跡 |
| `results/figures/progress/`（進捗報告用） | 92 | git で追跡。`grooveBottomDetection` 16、`grooveTracking` 54、`multiGroove` 22 |
| `experiments/` の日付のフォルダ（10個） | 12 | `1026/`・`1110/` は空。`0831/digitalNeedle/` に1つ |
| `experiments/archive/` | 3 | 改名しない |
| 合計（移す前の記録の行数） | 817 | |
| `git ls-files results/figures` | 144 | スライド用 52 ＋ 進捗報告用 92。`results/` の下で追跡しているのはこれだけ |

- SHA-256 は、評価スクリプトと同じ MATLAB の関数（Java の `MessageDigest` で 16MB ずつ読む）で求めた。Python の `hashlib` で求めた値と、817個すべてで一致した。`experiments/` の15個は、#35 の評価基準（2026-11-14）に記録された値とも同じだった（付録 A）。
- ファイル名に半角のカンマを含むものが1つある（`results/0721/PkDots(muteSection)(orig,rsmpl,intp(spline)).fig`）。移す前の記録の CSV では、パスを `"` で囲んだ。

### 3.2 対応表の案で求めた移し先（P8 の根拠）

`mapping-draft.md` の2〜4章を、評価担当が試しの CSV（`temp/28-criteria/trialMapping.csv`。実装担当が作る CSV ではない）に書き写し、評価スクリプトの移し先の計算に通した。

- `results/` の603個、原稿用の55個、スライド用の52個、`experiments/` の12個がすべて移し先を持ち、進捗報告用の92個と `archive/` の3個は動かなかった。
- 行き先のフォルダごとの数は、`mapping-draft.md` 2章の「数」の列とすべて同じだった（例：`multiGroove/2026-1028_hist5` 30、`grooveBottomDetection/2026-1118_evaluation` 102、`upsampling/2026-0731_intpD_2` 14）。
- 移す前のパスのまま残るファイルは0個だった。

### 3.3 1014 の手動選択の再現（Q12 の根拠）

`docs/rules/evaluation.md` の「基準にするデータが、今のコードで再現できるかを先に確かめる」に従い、変える前のコードで確かめた。

- `scripts/pkCentroid_1cycle.m` を `temp/28-criteria/pkCentroid_1cycle_base1124.m` に写し、`PREV_RESULT_PATH` を `experiments/1014/cycleResult_origD_1014.mat`、出力先を `temp/`、`experimentDir` を `Create=false` にし、`saveCycleResult` を `temp/` への `save` に替えて実行した（約20秒）。
- 重心法・局所的最大値法の `ycoords` は保存した結果と `isequal` だった。`cond` は、`date`・`saveDir`・`experimentDir` を除いて `isequaln` だった。保存した結果は `3261e62`（作業ツリーはきれい）で作られている。
- したがって、書き換えの後も `isequal`・`isequaln` であることを求める。外れたら、スクリプトの書き換え（ループの中の定数を冒頭へ移したことなど）か `cycleConditions` の新しい呼び方に誤りがある。

### 3.4 変える前の checkcode の警告（T2 の根拠）

スクリプト55本に `checkcode` をかけ、`plan.md` 付録 A.8 と同じ、7本・27件を得た（`pkCentroid_resample.m` 13、`pkCentroid_interp2.m` 8、`progress/multiGrooveOnePhoto.m` 2、`bilateral/bilateralOri_centroid_1cycle.m`・`progress/showPhotoshopGrooveExtraction.m`・`paper/202609asj/fig4_darkness3dComparison.m`・`slides/202609asj/darkness3dComparison.m` が1ずつ）。決定 Q5 により、ファイルごとに「変える前より増やさない」を基準にする。評価スクリプトは、変えた `.m` ごとに、基準のコミットの版を一時フォルダに書き出して `checkcode` をかけ、今の版と比べる。

### 3.5 受け入れテストの試行

受け入れテスト `test/unit/ResultLayoutAcceptanceTest.m` は42件である（`resultDir` 13、`runConditions` 8、`cycleConditions` 7、`figureDir` 2、`collectMeta`・`gitState`・`saveCycleResult` 3、`migrateResults` 9）。

- 実装の前に実行すると、3件が通り、39件が失敗する（関数が無いため。正常）。通る3件は、今の動作を変えないことの確認（`cycleConditions` の今の呼び方、`saveCycleResult` が保存する `meta`）と、JSON にできない値のエラーの確認（関数が無くてもエラーになるため）である。
- `cd test; runAllTests` は300件のうち261件が通り、失敗は受け入れテストの39件だけだった。
- 受け入れテストが正しい実装を通すことを、使い捨ての試作（`temp/28-criteria/proto/`。`plan.md` 4.2 の仕様どおりに書き、`cycleConditions` の写し方は付録 A.4 の試作を流用した）で確かめた。42件すべてが通った。試作は、受け入れテストを継承したクラス（`temp/28-criteria/ResultLayoutAcceptanceTrial.m`）から使い、終わった後に MATLAB のパスから外した。
- 誤った実装を落とせることを、試作に誤りを1つずつ入れて確かめた（`temp/28-criteria/runMutants.m`）。18通りすべてを、少なくとも1件のテストが落とした。

  | 入れた誤り | 落としたテスト |
  |---|---|
  | 同じ名前のフォルダに上書きする（`_2` を付けない） | `testSameNameGetsNumberAndWarning` |
  | 画像の名前の一覧を配列にしない | `testListsAreArraysAndPathsAreRelative` |
  | ルートの下のパスを相対パスにしない | 同上、`testScriptPath` |
  | 暦に無い日付（`2026-0230`）を通す | `testInvalidDate` |
  | 数字だけの説明（`hist_2`）を通す | `testInvalidLabel` |
  | フォルダを作ってから JSON にする | `testUnencodableValueLeavesNoFolder` |
  | `archive` の中のスクリプトも数える | `testScriptPath` |
  | `audio.rpm` の既定値 78 を入れない | `testIssueExampleGroupsAndKeys`、`testDefaultsAreFilledPerGroup` |
  | 一覧のキーを cell にしない（要素1つが配列にならない） | `testIssueExampleGroupsAndKeys`、`testSingleElementListsBecomeJsonArrays` |
  | 空の `ReplayFrom` も書く | `testEmptyReplayFromIsOmitted` |
  | ヒストグラムでも `tol`・`binWidth` を `NaN` にする（issue の元の案。Q4 で採らなかったもの） | `testNewCallEqualsOldCall(histogram)` |
  | 2つの書き方を混ぜても止めない | `testNewCallErrors` |
  | `figureDir` の戻り値の末尾に区切り文字を付ける | `testFigureDirPaths` |
  | `collectMeta` がいつも `gitBranch` を付ける | `testCollectMetaFields` |
  | 移行で、全部の行き先を先に確かめずに動かす | 行き先がある2件、当たらないファイルの1件 |
  | 行き先のファイルを確かめない | `testExistingDestinationFileStopsEverything` |
  | ファイルが残るフォルダも消す | `testUnmatchedFileStopsEverything` |
  | 試し（`DryRun`）でも移す | `testDryRunMovesNothing` |

### 3.6 評価スクリプトの試行

評価スクリプトを `temp/28-criteria/` に写し、パラメータだけを変えて、今の（変える前の）作業ツリーで動かした。どれも最後まで動いた（SHA-256 を計算して約1分）。

- 空の対応表（行が無い CSV）で動かすと、Q1 は 817/817（すべて元の場所に同じ SHA-256）になった。移す前の記録と SHA-256 の計算が正しいことの確認である。
- 3.2 の試しの CSV で動かすと、P8 の数と行き先ごとの数が `mapping-draft.md` と同じになった。移す前なので、Q1 は「移し先に無い」が722個（603＋55＋52＋12）になる（正常）。
- 実データの実行の項目（Q10〜Q12）は、試作の `resultDir` で作った偽の実行フォルダ（`temp/28-criteria/fakeRoot/`）と、3.3 の `.mat` で動かし、値の比べ方が正しく働くことを確かめた。
- 変える前なので、P1〜P7、Q3〜Q7 などは満たさない（正常）。検索4（6章）は今、149行に当たる（許される場所 52、要確認 97）。

## 4. 評価の項目

評価スクリプト `scripts/evaluation/resultsLayout/checkResultsLayout.m` の判定の表の ID は、この章の ID と同じである。「B が判断」「B が確かめる」と書いた項目は、評価スクリプトが材料（一覧、数）を出し、B が判断する。

### 4.1 テスト（T）

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| T1 | `cd test; results = runAllTests;` の失敗・未完了の件数 | 0件（受け入れテスト42件と、実装担当の unit テストを含む） | issue の完了条件、`docs/rules/coding.md` | `runAllTests`（評価スクリプトでは実行しない） |
| T2 | `checkcode` の警告。変えた `.m` ごとに、基準のコミットの版の件数と比べる。新しい `.m` は0件 | 増えたファイル 0個 | 決定 Q5（変更で警告を増やさない）。変える前は7本・27件（3.4） | 評価スクリプト |

受け入れテストが確かめること（合成データと一時フォルダだけを使う）：

- `resultDir`
  - `results/<実験名>/<日付>[_<説明>]/` を作り、末尾に区切り文字の付いた絶対パスを返す。同じ名前があれば `_2`・`_3` を付けて警告 `resultDir:folderExists` を出し、先にあるフォルダの `runInfo.json` を書き換えない。
  - `"YYYY-MMDD"` で `resultDir:dateNotSet`、形の違う日付・暦に無い日付で `resultDir:invalidDate`、`figures`・camelCase でない実験名で `resultDir:invalidExperiment`、英数字でない・数字だけの部分がある説明で `resultDir:invalidLabel` になり、何も作らない。
  - `runInfo.json` は UTF-8（BOM なし）で、`jsondecode` で読み戻せる。先頭が `"schemaVersion": 1` で、`plan.md` 4.3 の順にキーが並ぶ。要素が1つの一覧も配列になり、`""` の入力ファイルは除かれ、ルートの下のパスは `/` 区切りの相対パスになる（`conditions` の中も）。
  - `script` は `scripts/` の下（`archive` を除く）のパスになり、見つからなければ名前だけを書いて `resultDir:scriptNotFound` を出す。`meta` は `createdAt`・`git`（`commit`・`branch`・`dirty`）・`matlabRelease`・`computerName` の順。
  - JSON にできない値ではエラーにし、フォルダを残さない。
- `runConditions`：グループとキーが `plan.md` 4.3 の順に並び、引数の順によらない。`segmentation`・`audio` は既定値で埋まる。一覧のキーは要素が1つでも JSON の配列になる。空の `ReplayFrom` は書かない。`missingArgument`・`unknownField`・`tooDeep`・`MATLAB:TooManyInputs` のエラー。
- `cycleConditions`：同じ定数から今の呼び方と新しい呼び方で作った出力が、`origD`（手動）・`rsmplD`・`intpD`・追跡（`NaN`）・ヒストグラム（`tol = bandTol`、`binWidth`）の5つで等しく、フィールドの順も同じ。今の呼び方の出力の形と既定値は変わらない。`mixedForms`・`missingArgument`・`multipleUpsampling` のエラー。
- `figureDir`：3つの用途のパス（末尾に区切り文字なし）とフォルダの作成。発表名・テーマの形が違えば `invalidVenue`・`invalidTheme` で、フォルダを作らない。
- `collectMeta`・`gitState`：フィールドの名前と順が今と同じ8つで、`IncludeBranch=true` のときだけ `gitBranch` が最後に付く。git のリポジトリでないフォルダでは `""`・`false`・`""` を返す。`saveCycleResult` が保存する `meta` は今と同じ8つ。
- `migrateResults`：試しでは何も動かさない。実行すると移して空になった元のフォルダを消し、もう一度呼ぶとすべて `done` になる。途中で止まった移行の続きを移せる。行き先にファイル・フォルダがあると `destinationExists`、当たらないファイルが残ると `unmatchedFiles` で、どの行も動かさない。元も行き先も無い行は `sourceMissing` の警告で飛ばす。`Phase` が無いと `missingPhase`、知らない `kind`・足りない列で `invalidMapping`。

### 4.2 計画どおりかの確認（P）

計画（`plan.md`、承認B の対応表）に書かれた値と同じかを確かめる。計画どおりなら同じになるので、余裕は無い。品質の基準ではない。

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| P1 | 実験のスクリプト23本：`resultDir` と `runConditions` をそれぞれ1回呼び、`resultDir` の第4引数が `runConditions` の出力である。実験名と説明の値が `plan.md` 4.4.1・4.4.2 の既定値と同じ | 外れるもの 0本 | `plan.md` 4.1・4.4、完了条件「実験のスクリプトが resultDir と runConditions を使い、冒頭で実験名・日付・説明を決めている」 | 評価スクリプト（引数の変数を、スクリプトの中の代入から読む） |
| P2 | 1周分のスクリプト8本：`cycleConditions` を1回呼び、その第1引数が `runConditions` の出力である | 外れるもの 0本 | 完了条件「runConditions の出力を resultDir と cycleConditions の両方に使っている」 | 評価スクリプト |
| P3 | 図のスクリプト32本：`figureDir` を1回呼び、その用途と名前が、基準のコミットで組み立てていた保存先（`"results","figures",<用途>,<名前>`）と同じ | 外れるもの 0本 | `plan.md` 4.4.3、完了条件「図のスクリプトが figureDir で保存先を作っている」 | 評価スクリプト |
| P4 | 基準のコミットからの `src/`・`test/`・`scripts/` の差分のうち、計画の外のもの | 0件。`src/` は `plan.md` 4.5 の追加5つ（すべて要る）と変更7つだけ、`test/` は `test/unit/*Test.m` の追加だけ（既存のテストの変更・削除なし）、`scripts/` は変更と `scripts/migration/` の追加だけ（削除・移動なし） | `plan.md` 4.5 | 評価スクリプト。55本以外の `scripts/` の変更は B が中身を見て判断する |
| P5 | `plan.md` 7.4 の読むパス9個が `experiments/` にある | 無いもの 0個 | 完了条件「experiments/ を日付で読むスクリプトの日付を新しい名前にし、読むパスがすべてある」 | 評価スクリプト |
| P6 | README に「結果の置き場所と実行記録」の節があり、その中に実験名8つ（決定 Q6）、`runInfo.json` の項目（`plan.md` 4.3 のキー）がある。README に、実験名の決め方の1行（slug がすでにある名前と違うときは、すでにある名前に合わせる。決定 Q6）、「対応表」の節（古い日付のフォルダ19個とスライド用の図の移動）、スクリプトと図とで階層の順が逆になることの記述がある | 外れ 0件 | `plan.md` 5.1 の手順9・5.2 の手順16〜17、issue の「あるべき姿」7 | 評価スクリプト（言葉で探す）。版の表と、見つけた行の中身は B が読む |
| P7 | `docs/rules/figures.md` に `figureDir`・`resultDir` と #28 の例外の記録がある。`common-functions.md` の F1 に #28 と `figureDir`、H1 に `resultDir` がある。`CLAUDE.md`・`data.md`・`coding.md`・`evaluation.md` に `resultDir` がある。`.gitignore` に issue の規則の7行がこの順にあり、`# editor` と `/.vscode` が1つずつ | 外れ 0件 | `plan.md` 2.1 (6)、issue の「あるべき姿」2・7 | 評価スクリプト |
| P8 | 対応表で求めた移し先で、移るファイルの数 | `results/` の日付のフォルダ 603、原稿用 55、スライド用 52、`experiments/`（archive 以外）12 が移り、進捗報告用 92 と `archive/` 3 は動かない。行き先のフォルダごとの数が、README の対応表（承認B のもの）と同じ | 3.1・3.2、`mapping-draft.md` | 評価スクリプト（行き先ごとの数の表を、B が README と比べる） |

### 4.3 品質の基準（Q）

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| Q1 | 移す前の記録の817個が、移し先に、同じ大きさ・同じ SHA-256 である | 817/817 | issue の判断の基準2「過去の出力を上書きしない」と制約「既存の出力・データは上書きしない」「experiments/ の .mat の中身は変えない」。移す前は 817/817（3.6） | 評価スクリプト（`COMPUTE_SHA = true`） |
| Q2 | 対応表の移し先のフォルダ（とスライド用の図の移し先）と `experiments/` にある、移す前の記録に無いファイル | 0個 | 移行で別のものが混ざっていないこと。`experiments/` には新しいデータを作らない（`plan.md` 7.5） | 評価スクリプト |
| Q3a | `migrateResults` の試し（`Phase="results"`・`"experiments"`）の status | すべて `done` | 移し終えたこと（`plan.md` 7.1 の手順3・4） | 評価スクリプト |
| Q3b | 古い形のフォルダ（`results/`・`experiments/` の直下の4桁の日付、`results/figures/paper/`・`slides/`） | 0個 | issue のゴール | 評価スクリプト |
| Q4 | 名前の規則：`results/` の直下が実験名8つと `figures` だけ。実験名の下が `YYYY-MMDD[_説明…][_N]`（暦にある日付）のフォルダだけ。`results/figures/` の下が `progress` と発表名（年月6桁と略称）だけで、発表名の下は `paper`・`slides` だけ。`experiments/` の下が `archive` と `YYYY-MMDD` だけ。cycleResult のファイル名の日付がフォルダの日付と同じ | 外れ 0件 | issue の判断の基準1「フォルダ名を見れば、いつ・何の実験かが分かる」 | 評価スクリプト |
| Q5 | git の追跡：`git ls-files results` が144（スライド用 52 は `results/figures/202609asj/slides/`、進捗報告用 92）。基準のコミットからの `results/` の差分が、スライド用の図の `R100` の移動52行だけ。`git check-ignore --no-index` の14の例（6章の表のとおり無視・追跡）。`git status --porcelain` が空 | すべて満たす | 制約「.gitignore を直した後も、追跡するもの・無視するものは今と同じ」、issue の検証方法2 | 評価スクリプト |
| Q6a | issue の「対象ファイル」の検索1〜3と、その補い（コードの中の `"dddd"` の文字列、`"MMDD"` の印）に当たる行 | 0行 | issue の検証方法3。除く場所は5章 | 評価スクリプト |
| Q6b | 検索4の「要確認」の行のうち、新しい出力・読み込みに古い置き場所を使うように書いている行 | 0行 | issue の検証方法3。判断の仕方は5章 | 評価スクリプトの一覧を B が読む |
| Q7 | 実験のスクリプト23本で、`resultDir` に渡す日付の変数の値 | すべて `"YYYY-MMDD"`（実行した日を書き込まない） | issue の「あるべき姿」5、判断の基準3（実行した日とフォルダの日付がずれない） | 評価スクリプト |
| Q8 | スクリプト（コメントを含む）に書かれた `YYYY-MMDD` の日付の `experiments/` のフォルダと、`cycleResult_…_YYYY-MMDD.mat` のファイル | 無いもの 0個 | 完了条件「読むパスがすべてある」（P5 の一覧の外も含めて確かめる） | 評価スクリプト |
| Q9 | 図の名前とタイトルに書くデータの日付が4桁のまま：(1) `progress/waveformManualVsTrack.m` のコピーで作った図の名前に `_1014` があり、`2026-` が無い。(2) 図のスクリプトと評価スクリプトで、`YYYY-MMDD` の日付の変数を、読み込みのパスを作る文以外で使っている文 | (1) すべての図で満たす。(2) 図の名前・タイトルを組み立てている文が0（B が判断） | ユーザーの決定（図の名前のデータの日付は4桁のまま。`checkFigureName` は変えない） | 評価スクリプト（(2) は一覧を B が読む） |
| Q10 | 実データの実行（E1）：`bilateral/bilateralOri_centroid_1cycle.m` のコピーで、`results/bilateralFilter/<実行した日>_1cycle/` ができる。出力のファイル名が、移した過去の実行 `results/bilateralFilter/2026-0924_1cycle/`（承認B で名前が変われば、その名前）の36個と同じで、`runInfo.json` が加わる。`runInfo.json` の値がスクリプトの定数と同じ（8章の表）。`meta.git.dirty` が false で、`meta.git.commit` が評価したコミット | 外れ 0件 | issue の検証方法5の(1)(2)、完了条件「実データで1本実行し、…中身がスクリプトの定数と一致する」 | 8章の手順3、評価スクリプト |
| Q11 | 同じ設定でもう一度実行する（E2）と、`_1cycle_2` のフォルダができ、その `runInfo.json` の `run` も同じ名前で、警告 `resultDir:folderExists` が出る | 満たす | issue の検証方法5の(3)、判断の基準2 | 8章の手順4（警告は B が記録）、評価スクリプト |
| Q12 | 1周分のスクリプトの書き換えで数値が変わらない（E3）：`pkCentroid_1cycle.m` のコピーで 1014 の手動選択を再現し、`ycoords`（重心法・局所的最大値法）が保存した結果と `isequal`、`cond` が `date`・`saveDir`・`experimentDir` を除いて `isequaln`。その実行の `runInfo.json` の値（`lMask`・`dThresh`・`widthThresh`・`manual` の4つ・`upsampling.kind`・`inputs`）が `cond` と同じ | すべて満たす | 制約「数値の出力（溝形状、音声）は変えない」「cycleResult に保存する conditions の形は変えない」。変える前のコードで `isequal`・`isequaln` を確かめた（3.3） | 8章の手順5、評価スクリプト |
| Q13 | 書き換えていない `scripts/bilateral/bilateralOri_centroid_1cycle.m` をそのまま実行すると、`resultDir:dateNotSet` で止まり、`results/` に新しいフォルダができない | 満たす | issue の「あるべき姿」5（`"YYYY-MMDD"` のまま実行すると止める） | 8章の手順7（B が確かめる） |

### 4.4 変えてはいけないもの（D）

差分の基準は `<受け入れテストを追加したコミット>` である。評価基準をコミットした後に master から取り込んだマージのコミット `<M>` があれば、その変更（`git diff --name-status <M>^1 <M>` に出るファイル）は D1・P4 から除く（`docs/staged-development.md` 5.1）。除いた範囲は評価レポートに書く。

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| D1 | `git diff --name-status <受け入れテストを追加したコミット> HEAD` のうち、`src/archive`・`scripts/archive`・`test/archive`・`docs/issues/closed`・`docs/progress`・`slides/progress`・`src/checkFigureName.m`・`src/figureVocabulary.m`・`test/unit/*AcceptanceTest.m`・`scripts/evaluation/resultsLayout` の差分と、`test/` の既存のファイルの変更・削除・移動 | 0件 | issue の制約（archive・過去の記録・図の名前の決まりを変えない）、`docs/rules/evaluation.md`（受け入れテストは変えない）。移す前の記録も変えない | 評価スクリプト |
| D2 | `src/mkdirFromDate.m`・`experimentDir.m`・`cycleResultPath.m`・`cycleResultFileName.m`・`saveFigure.m` の差分のうち、コメント・空行でない行。`mkdirFromDate.m` が残っている | 0行、残っている | `plan.md` 4.5（説明だけを直す）、issue の制約（`mkdirFromDate` は消さない、`cycleResultPath` の動作は変えない） | 評価スクリプト |
| D3 | `experiments/` の15ファイルが、改名した後の名前（`archive/` の3つは同じ名前）で、付録 A と同じ SHA-256 である | 15/15 | issue の制約（`.mat` の中身は変えない、`archive/` は改名しない） | 評価スクリプト（Q1 の一部を分けて出す） |
| D4 | `results/figures/progress/` の92ファイル：git の差分が無く、同じ場所に同じ SHA-256 である | 差分 0件、92/92 | 進捗報告用の図の置き場所は変えない（ユーザーの決定 2026-11-23） | 評価スクリプト（D4a・D4b） |

## 5. 古い書き方の検索で、残ってよいもの（Q6 の基準）

検索の範囲と式は、issue の「対象ファイル」のとおりにする。評価スクリプトは、`git ls-files` の各ファイルを UTF-8 で読み、行ごとに正規表現で探す（`git grep` の出力は、日本語が Windows の文字コードで化けるため）。

- 検索1〜3と補い（`scripts/` の `.m`）は、次の場所を除き、当たる行を0にする。
  - `*/archive/*`（issue の検索の式が除いているもの）
  - `scripts/migration/`（対応表と移行の関数。古い名前を書くのが役目）
  - `scripts/evaluation/resultsLayout/`（この評価のスクリプトと、移す前の記録）
  - 補いの「`"dddd"` の文字列」では、写真のフォルダ `"pictures","1111"` の行も除く（`data/pictures/1111/` は撮影日のフォルダで、`experiments/` の日付ではない）。
- 検索4（文書を含むリポジトリ全体。`docs/issues/closed/`・`docs/progress/`・`slides/progress/` を除く）は、当たった行を3つに分ける。
  - (a) 許される場所（評価スクリプトが自動で分ける）：`*/archive/*`、このissueの受け渡しフォルダ `docs/issues/28-results-by-experiment/`、`scripts/migration/`、`scripts/evaluation/resultsLayout/`、受け入れテスト `test/unit/ResultLayoutAcceptanceTest.m`、移行の関数の unit テスト `test/unit/MigrateResultsTest.m`（合成の古い名前を使うため。名前が違えば B が判断する）、`src/mkdirFromDate.m`（関数そのもの）、`src/cycleResultPath.m`（移行前の置き場所も探す動作を、issue の制約で残す）。
  - (b) README の「対応表」の節の行（過去の記録のパスから引けるようにするため）。
  - (c) 要確認：それ以外。B が1行ずつ読み、次のどちらかに分ける。
    - 残ってよい：古い置き場所を、過去のこととして書いている行。例：`mkdirFromDate` の説明で「新しいコードでは `resultDir` を使う」と書いたもの、`saveCycleResult` の `ExperimentDir` を渡さない古い `conditions` のときの保存先の説明、`docs/rules/figures.md` の「既存の図は改名しない」の例外の記録（移す前の置き場所を書くもの）、過去の結果のフォルダの名前としての言及。
    - 残ってはいけない（Q6b に数える）：新しく作る出力を `results/<MMDD>/` や `results/figures/{paper,slides}/<発表名>/` に置く、新しいコードで `mkdirFromDate` を使う、`experiments/<MMDD>/` を読む、と指示・説明している行。

## 6. ユーザーが判断する項目

数値の結果だけで合格にしない。どれも、評価スクリプトの出力やファイルを**読んで**判断する（図や音は無い）。

| ID | 見るもの | 観点 |
|---|---|---|
| U1 | 評価スクリプトが出す「U1 results/ の並び」（実験名ごとの実行フォルダの名前と、ファイルの数）。評価レポートに写す | issue の判断の基準1：フォルダ名を見れば、いつ・何の実験かが分かるか。混ざっていたフォルダ（`0731`・`1014`・`1118` など）の分け方と説明の語が分かりやすいか |
| U2 | 実データの実行で作った `results/bilateralFilter/<実行した日>_1cycle/runInfo.json` と、`results/grooveTracking/<実行した日>_check/runInfo.json`（Q10・Q12） | 実験条件（使った画像、バイラテラルフィルタのカーネル、溝の選び方など）を、後から読んで分かるか。キーの名前と並び、単位の説明（README の「`runInfo.json` の項目」の表）が分かりやすいか |
| U3 | README の「結果の置き場所と実行記録」の節（実験名の一覧、実行フォルダの名前の決め方、`runInfo.json` の項目、対応表） | 新しく実験を始めるとき、実験名と説明をどう決め、出力がどこにできるかが分かるか。過去の記録に書かれた古いパス（例 `results/1014/`）から、今の場所を引けるか |

`git check-ignore --no-index` の14の例（Q5）：

| パス | 期待 |
|---|---|
| `results/figures/202609asj/paper/x.png`、`results/figures/202702thesis/paper/fig.pdf`、`results/grooveTracking/2026-1014/x.png`、`results/upsampling/2026-0731_origD/a.wav`、`results/0731/a.wav`、`results/figures/x.png`、`results/figures/202609asj/x.png`、`experiments/2026-1014/x.mat`、`temp/x.m` | 無視される |
| `results/figures/202609asj/slides/x.png`、`results/figures/202609asj/slides/sub/y.png`、`results/figures/202702thesis/slides/a.png`、`results/figures/progress/grooveTracking/x.png`、`results/figures/progress/x.png` | 追跡される |

## 7. 未決事項

評価の段階までに決まればよい（止めない）。

**Q-a. 「計画」だけを満たさず、「品質」をすべて満たす場合の判定**

- 背景：P の項目（実験名・説明の既定値、`figureDir` の引数、変えたファイルの範囲など）は、計画どおりならぴったり同じになる。品質（データの保全、数値の出力、追跡するもの）を満たしたまま P だけが外れるのは、実装担当が計画と違う名前や書き方を選んだときである。
- 選択肢
  - (a) 不合格にして実装に戻す。評価レポートで、計画と違う点と、品質は満たしていることを分けて書く（#30・#35 と同じ決め方）。
  - (b) ユーザー確認待ちにして、違いを受け入れるかをユーザーがその場で決める。
- 推奨：(a)。スクリプトの既定値や文書は、ほかのissueやセッションが前提にするので、計画との違いが偶然か意図かを、実装担当が確かめてから判断したほうが安全なため。

## 8. 評価（モードB）の手順

日付 `<MMDD>` は評価を実行する日、`<YYYY-MMDD>` はその年付きの形である。スクリプトのコピーは `temp/28-eval/` に置き、消さずに残す。

1. 前提を確かめる。目的は、どのコードと、どの移行の結果を評価したかを記録すること。
   - (1) README の作業履歴で、承認B・承認C と、移行（`results/` の移動、`git mv`、`experiments/` の改名）の実行が記録されていることを確かめる。終わっていなければ、評価を保留して main に報告する。
   - (2) `git status --porcelain` が空であることを確かめ、`git log --oneline -1` を記録する。
   - (3) この文書の `<受け入れテストを追加したコミット>` の値、作業履歴にある master からのマージのコミット、承認B で「残す」「消す」と決めたものを控える（評価スクリプトの `BASE_COMMIT`・`MERGE_COMMITS`・`APPROVED_LEFTOVERS`・`APPROVED_DELETIONS`）。
2. `cd test; results = runAllTests;` を実行する（T1）。
3. E1（Q10）：`scripts/bilateral/bilateralOri_centroid_1cycle.m` を `temp/28-eval/bilateralOri_centroid_1cycle_eval<MMDD>.m` に写し、`date` を `"<YYYY-MMDD>"` にする。ほかは変えない（`ginput` は使わない。`experiments/` には保存しないスクリプトである）。実行の前に `results/bilateralFilter/<YYYY-MMDD>_1cycle/` が無いことを確かめる。実行し（数分）、出た警告を記録する。
4. E2（Q11）：手順3のコピーをもう一度写し、`resultDir` を呼ぶ文の直後に `return` を足したもの（`..._eval<MMDD>_again.m`）を実行する。目的は、同じ設定の2回目が `_2` の付いたフォルダになることを、重い処理を繰り返さずに確かめること。警告 `resultDir:folderExists` が出ることと、そのメッセージを記録する。
5. E3（Q12）：`scripts/pkCentroid_1cycle.m` を `temp/28-eval/pkCentroid_1cycle_eval<MMDD>.m` に写し、次の行だけを変えて実行する（約20秒）。
   - `date` を `"<YYYY-MMDD>"`、`EXPERIMENT_NAME` を `"grooveTracking"`、`LABEL` を `"check"` にする。
   - `PREV_RESULT_PATH` を `experiments/2026-1014/cycleResult_origD_2026-1014.mat`（`fullfile` で組み立てる）にする。
   - `experimentDir(...)` に `Create=false` を付ける（`experiments/<YYYY-MMDD>/` を作らないため）。
   - `saveCycleResult(...)` の呼び出し（続きの行を含む）を、`save(fullfile(proj.RootFolder,"temp","28-eval","check_pkCentroid_1cycle.mat"),"ycoords_cnt","ycoords_max","cond")` にする。
6. E4（Q9 の (1)）：`scripts/progress/waveformManualVsTrack.m` を `temp/28-eval/` に写し、`figureDir` の行だけを `temp/28-eval/fig_waveformManualVsTrack/` を作って返す行に替えて実行する。`results/figures/` の既存の図は上書きしない。
7. E5（Q13）：`results/bilateralFilter/` の一覧を控え、書き換えていない `scripts/bilateral/bilateralOri_centroid_1cycle.m` をそのまま実行する。`resultDir:dateNotSet` で止まること、`results/bilateralFilter/` の一覧が変わらないことを確かめる。
8. 評価スクリプト `scripts/evaluation/resultsLayout/checkResultsLayout.m` を `temp/28-eval/checkResultsLayout_eval<MMDD>.m` に写し、冒頭のパラメータ（`BASE_COMMIT`、手順1の(3)の値、`E1_RUN_DIR`・`E2_RUN_DIR`・`E3_CHECK_MAT`・`E3_RUN_DIR`・`E4_FIG_DIR`。承認B で `2026-0924_1cycle` の名前が変わったら `E1_REF_DIR` も）だけを変える。`clear` してから実行する（約1〜2分）。判定の表、各項目の一覧、U1 の並びを得る。
   - Q10 の `runInfo.json` で確かめる値は次のとおり（`bilateralOri_centroid_1cycle.m` の定数）。`experiment` `bilateralFilter`、`script` `scripts/bilateral/bilateralOri_centroid_1cycle.m`、`inputs.images` は `DSC1111-0000{1..8}-ori` の8つ、`inputs.files` は `experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat`、`segmentation` は 8・10・20、`preprocessing.bilateral` は `[3,5,9]`・`[0.5,1,2]`・650.25、`upsampling.kind` は `["origD"]`、`grooveBottom` の `dThresh` 0.6・`widthThresh` 8、`grooveSelection.manual` は 150・3・5・8。`grooveBottom.methods`・`grooveSelection.method`・`replayFrom` は、あれば `["centroid"]`・`manual`・`inputs.files` と同じであること。
9. 実行の後にもう一度 `git status --porcelain` が空であることを確かめる。
10. `eval-report-<n>.md` に、判定、項目ごとの表（区分つき）、Q6b・Q9 の (2) の判断と理由、Q11 の警告、Q13 の結果、使ったコピーのパス、実行日、`runAllTests` の件数、U1〜U3 の見るものと観点を書く。U1 の並びは評価レポートに写す。

## 9. 仮定と、気づいた点

- 仮定
  - 評価スクリプトと E1〜E5 は、`Research.prj` を開いた状態で、プロジェクトのパスにある `src/` を使う。
  - E1 は Image Processing Toolbox の `imbilatfilt` を使う（今のスクリプトのまま）。この PC にはある。
  - 移行の関数の unit テストの名前は `plan.md` 4.5 の `MigrateResultsTest.m` とした（5章の (a)）。違う名前なら、B が同じ扱いをしてよいかを判断する。
- 決めたこと（plan.md の申し送りからの変更・補い）
  - 受け入れテストと評価スクリプトの名前は、`plan.md` 7.2 の例のとおりにした。
  - 移す前の SHA-256 は、`experiments/` の15個だけでなく、`results/` と `results/figures/` を含む817個すべてを記録した。`results/` は対応表どおりに移したかを中身で確かめるためで、`experiments/` の15個は付録 A にも書いた。
  - 検索の補いとして、スクリプトのコードにある `"dddd"` の文字列と `"MMDD"` の印を足した。issue の検索3の式は `DATA_DATES = ["1014", …]` のような配列と、小文字の `date = "0731"` に当たらないためである。
  - 実データの実行の2回目（E2）は、`resultDir` の直後で止めたコピーで行う。issue の「同じ設定でもう一度実行」の目的（`_2` と警告）を、重い処理を繰り返さずに確かめるためである。
  - 承認B で「残す」「消す」と決めたものは、評価スクリプトのパラメータで除けるようにした（`mapping-draft.md` の M3・M5 で (c)・(b) を選んだ場合）。決定が README の作業履歴に無いものは除かない。
- 気づいた点
  - 受け入れテストを足したコミットから実装の前半を終えるまで、`runAllTests` が39件失敗する。CI は PR と master への push で動くので、その間に PR を作ると CI が失敗する。
  - 受け入れテストの `migrateResults` のテストは、`scripts/migration/` が無いと止まる（`assertTrue`）。`plan.md` 5.1 の手順7で前半に作るので、前半の後には42件すべてが通るはずである。
  - 受け入れテストの補助のメソッドは `protected` にした。評価担当が試作で確かめるときに、継承したクラスで置き換えるためである（実装担当は変えない）。
  - 評価スクリプトは、ワークスペースに `height` などの変数が残っていると名前がぶつかって止まる。`clear` してから実行する。
  - 対応表に `files` の行で書くパターンは、Windows の `dir` と同じく大文字・小文字を区別しない前提で照らす。移行はこの PC（desktop、Windows）で行う（ユーザーの決定、2026-11-23）ためである。

## 10. 作ったファイル

- `test/unit/ResultLayoutAcceptanceTest.m`：受け入れテスト（42件、合成データと一時フォルダだけ）。実装の前は39件が失敗する（正常）。`checkcode` の警告 0。
- `scripts/evaluation/resultsLayout/checkResultsLayout.m`：評価スクリプト。何も書き出さず、判定の表と一覧を表示する。`checkcode` の警告 0。`temp/` のコピーで、変える前の作業ツリーに対して最後まで動くことを確かめた（3.6）。
- `scripts/evaluation/resultsLayout/manifestBeforeMigration.csv`：移す前の記録（817行。列は `path,bytes,sha256`）。変えない（D1）。
- `temp/28-criteria/`（git 管理外。参考）：移す前の記録を作ったスクリプト（`makeManifest.m`・`sha256File.m`）、試作（`proto/`）と、それで受け入れテストを動かすクラス（`ResultLayoutAcceptanceTrial.m`・`ResultLayoutAcceptanceMutant.m`・`runMutants.m`）、試しの対応表（`trialMapping.csv`・`emptyMapping.csv`）、評価スクリプトの試行のコピーと出力（`checkResultsLayout_trial*.m`・`trial*_out.txt`）、1014 の再現（`pkCentroid_1cycle_base1124.m` と、その出力 `check_pkCentroid_1cycle_base1124.mat`・`out_base1124/`）、偽の実行フォルダ（`fakeRoot/`）。

## 付録 A：`experiments/` の SHA-256（2026-11-24、改名の前）

改名の後は、対応表で引いた新しい名前のファイルが同じ値であること（D3）。`archive/` の3つは同じ名前のまま。

```
22c5cc26a9d8c7068cebfd037b13e38d4c72217ac92b5979e0d353600df4c524  experiments/0731/cycleResult_intpD_0731.mat
0fbab0b6925963f8cf7383f62a71941255c3db2b6b6b4af501a6a8156abdd468  experiments/0731/cycleResult_origD_0731.mat
d182322e7f227049b50192f78acd4c260342223c268b222ed05734b031c41358  experiments/0731/cycleResult_rsmplD_0731.mat
cabbfe85222017257f82bb381ba3c81a015d55835e843d4b9d8b8354198cccbb  experiments/0802/cycleResult_origD_0802.mat
43951e21271b8a1214bc66b1e93dc2cdb79cbe953ec68c98f7c4ef78200781ea  experiments/0807/cycleResult_rsmplD_0807.mat
60e29fb4e3169ffd78e6fdf43c9383c01af09edcee1327e6637cad8f31ba053c  experiments/0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_0831.mat
7bd1a7f23436c6b839c5da83c07d113f07e790247415a6636da6a809482844db  experiments/1013/cycleResult_origD_track_1013.mat
e1b7128bd7e49e168990db9fcce8fe3194508cb5fd8a61fb3cab28161cf962fc  experiments/1014/cycleResult_origD_1014.mat
8b0e29e337a14f35e2d249c01737b5427775f6a3640796b3d598ee0d26e6fdbe  experiments/1014/cycleResult_origD_track_1014.mat
3abad3a6d9320da305086a28d5c48651e57ee5624c4f65cd28cdfcb18281bc08  experiments/1022/cycleResult_origD_track_1022.mat
041eb2489528802fecabccb22bf3b0e8f08c6d1825f703f7d1c0c4443e6c31ec  experiments/1104/cycleResult_origD_hist5_1104.mat
9cddbcee7611266896c3a6bfc1495dbf561f5304f3e4bde45709647fcb4880e8  experiments/1104/cycleResult_origD_track5_1104.mat
ea471ebf29442c4565ccabc52f6c136233a93270adad7102739864c03132715f  experiments/archive/cycleResult_intpD_0731_trash.mat
115152ac453b6ab6a7b397bfa9395ebfe5266465cc4d863bb17030db78dac3ae  experiments/archive/cycleResult_origD_0731_trash.mat
47d8374b4c2dd537138a33ad42d8caf9316bb2d6fbde916b98614948493f44e6  experiments/archive/cycleResult_rsmplD_0731_trash.mat
```

## 付録 B：`results/` の日付のフォルダごとのファイルの数（2026-11-24、移す前）

サブフォルダの中のファイルも数えた。合計は603で、見込みと同じだった。

| フォルダ | 数 | フォルダ | 数 | フォルダ | 数 |
|---|---|---|---|---|---|
| `0710` | 0 | `0820`（`bilateral/` の4つ、13ずつ） | 52 | `1028` | 74 |
| `0721` | 1 | `0831`（`digitalNeedle/`） | 2 | `1104` | 66 |
| `0724` | 14 | `0924`（`bilateral1cycle/`） | 36 | `1110` | 2 |
| `0731` | 48 | `1013` | 22 | `1111` | 5 |
| `0802` | 14 | `1014` | 60 | `1118` | 144 |
| `0807` | 14 | `1022` | 22 | | |
| `0817` | 5 | `1026` | 22 | | |
