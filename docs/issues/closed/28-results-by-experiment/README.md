- 段階: 準備
- 作成者: main
- 作成日: 2026-11-24
- 入力: issue #28
- 状態: 作業中

# #28 結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す

- issue: [#28 [refactor] 結果の保存先を results/<実験名>/<YYYY-MMDD_説明>/ にし、実行記録を残す](https://github.com/MiwaHiroki/myResearch/issues/28)
- ブランチ: `claude/results-by-experiment`
- PR: （作ったら書く）
- 進め方: `docs/staged-development.md`、受け渡しフォルダの運用: `docs/issues/README.md`

## 解決のまとめ

- 書いた日: 2026-11-26（summarizer が下書き、main が確認）
- 対象のコード: `8a16012`（この時点の `claude/results-by-experiment` の先頭）。PR は [#38](https://github.com/MiwaHiroki/myResearch/pull/38) で、2026-11-26 にマージした（`b5f9a15`）。`src/`・`scripts/`・`test/` は、評価したコミット `d1c6c37` から変わっていない。master から取り込んだ `ccef766`（進捗ログの自動更新と、振り返りの改善案 G1〜G4 の反映 `ad98195`）は、このissueの解決には含めない。

### 言葉

- **実験名**：研究上の問い（何を試して比べたか）ごとに付ける、英語の camelCase の名前（例：`grooveTracking`）。`results/` の直下のフォルダ名になる。
- **実行フォルダ**：スクリプトを1回実行したときの出力を置くフォルダ。`results/<実験名>/<YYYY-MMDD>[_<説明>][_<N>]/` の形にする。**説明**は日付の後ろに付ける短い英語の語（例：`evaluation`）で、付けなくてもよい。
- **実行記録**：実行フォルダに置く `runInfo.json`。何の実行か、読んだ入力、実験条件、実行した環境（git のコミットなど）を書く。
- **実験条件**：処理のしかたを決めるパラメータ（使う画像、高解像度化の方法、溝底の検出のしきい値、溝の選び方など）。
- **cycleResult**：1周分（またはN周分）の結果を `experiments/<日付>/` に保存する .mat。中に実験条件 `conditions` と実行環境 `meta` を持つ。
- **スクリプト55本**：書き換えた、実験のスクリプト23本（出力先を `mkdirFromDate` で作っていたもの）と、図のスクリプト32本。実験のスクリプトのうち、cycleResult を保存する8本を **1周分のスクリプト** と呼ぶ。
- **対応表**：既存のフォルダ・ファイルの、移す前と移した後の名前の表（`scripts/migration/resultsMapping.csv`）。
- **試し**：移行の関数を、ファイルを動かさずに「何をするか」の表だけを返すモード（`DryRun`）で呼ぶこと。
- **承認A・B・C**：途中でユーザーが確かめた3か所。A は README の実行記録の項目の表と実験名の一覧、B は移す直前の試しの表、C は `experiments/` を改名する前のバックアップである。

### 1. 結論

実験の図・音声を、実行フォルダ `results/<実験名>/<YYYY-MMDD>[_<説明>]/` に出力し、同時に実行記録 `runInfo.json` を自動で残すようにした。出力先は新しい関数 `resultDir` が作り、実験条件は `runConditions` が1か所でまとめて、実行記録と cycleResult の両方に使う。スライド用・原稿用の図は発表ごとのフォルダ（`results/figures/<発表名>/{slides,paper}/`）にまとめ、保存先を `figureDir` で作る。スクリプト55本を書き換え、既存の `results/` の658ファイルを対応表で移し、`experiments/` の12ファイルを `YYYY-MMDD` の名前に改名した。評価は**1回目で合格**した（2026-11-26、差し戻し0回）。移す前に記録した817ファイルは、移した後もすべて同じ中身だった。

### 2. 問題とゴール

これまで図・音声は、`results/<MMDD>/` の日付のフォルダ（19個）に置いていた。フォルダ名から何の実験かが分からず、同じ日の別の実験が混ざり、スクリプトに書き込んだ日付が実行した日とずれ、年が無いので翌年とぶつかる。使った画像やパラメータも結果の横に残らず、1つの発表の図が原稿用とスライド用の2か所に分かれていた。ゴールは、フォルダ名を見ればいつ・何の実験かが分かり、過去の出力を上書きせず、どのスクリプト・コード・入力・条件で作ったかを後からたどれるようにすることである。変更は最小限にし、数値の出力（溝形状、音声）と cycleResult の `conditions` の形は変えないことが条件だった。

### 3. 採った方法

#### 考え方

- 出力先を作る処理を `resultDir` 1つに集め、そこで名前の規則を確かめ、実行記録を書く。出力を作る前に記録を書くので、途中で止まった実行にも条件が残る。
- 実験条件は、スクリプト冒頭の定数から `runConditions` で1回だけ作り、実行記録と cycleResult の両方に渡す。同じ値を2回書かないためである。
- スクリプトの書き換えは、出力先・日付・実験条件の行だけにする。`resultDir` は今までの `mkdirFromDate` と同じ形（末尾に区切り文字の付いたパス）を返すので、約200か所ある保存の行は変えずに済む。
- 既存のフォルダは、人が承認できる大きさの対応表を関数で読んで移す。「試し → 承認 → 実行 → もう一度試し」の順にし、移す前に全ファイルのハッシュ値を記録しておき、移した後に1つも失われていないことを数で確かめる。

#### 処理の流れ

新しく実験のスクリプトを実行するとき（実験のスクリプト23本。手順5は1周分のスクリプトだけ）
1. スクリプトの冒頭で、実験名 `EXPERIMENT_NAME`、実行した日 `date`、説明 `LABEL` を決める。`date` は `"YYYY-MMDD"` のまま置いてあり、実行する人が実行した日に書き換える。出力の日付をスクリプトに書き込まないので、フォルダの日付が実行した日とずれない。
2. `runConditions` で、冒頭の定数を実験条件にまとめる。定数を name-value 引数で受け取り、決まった入れ子の struct を返す。
   - (1) グループを処理の順（画像の一部 `region`、分割とマスク `segmentation`、前処理 `preprocessing`、高解像度化 `upsampling`、溝底の検出 `grooveBottom`、溝の選び方 `grooveSelection`、デトレンド `detrend`、音声 `audio`、ほかに入らないもの `other`）に並べ、渡した引数のグループだけを作る。キーの順も、引数を渡した順によらず決まっている。
   - (2) 分割と音声のグループを作るときは、渡さなかった値を既定値で埋める（写真 8(`NumImages`) 枚、横の分割 10(`NumSegments`)、回転数 78\[rpm\](`Rpm`)）。
   - (3) 一覧の値（高解像度化の種類 `upsampling.kind`、検出法 `grooveBottom.methods` など）は、要素が1つでも JSON の配列になるように cell にする。
   - (4) リサンプルを選んだのに倍率 `PRsmpl`・`QRsmpl` が無い（内挿なら間隔 `QueryStep`・方法 `InterpMethod` が無い）、知らないキーがある、入れ子が3段を超える、のどれかならエラーで止める。
3. `resultDir` で実行フォルダを作る。ルート、実験名、日付、手順2の出力と、説明・スクリプト名・使った画像・読んだファイルを受け取り、作ったフォルダのパス（末尾に区切り文字が付く）と、書いた実行記録の struct を返す。
   - (1) 日付が `"YYYY-MMDD"` のままならエラー `resultDir:dateNotSet`、形が違うか暦に無い日付（`2026-0230` など）ならエラー `resultDir:invalidDate` で止める。
   - (2) 実験名が camelCase でないか `figures`（図の置き場所の名前）ならエラーにする。説明は、`_` で区切った各部分を英数字だけにし、数字だけの部分を許さない。末尾に付く番号 `_2` と見分けるためである。
   - (3) 同じ名前のフォルダがあれば、空いている名前になるまで `_2`、`_3`… を付け、警告 `resultDir:folderExists` を出す。過去の出力を上書きしないためである。
   - (4) 実行記録を組み立て、JSON の文字列にする。先頭は形の版 `schemaVersion` で、何の実行か、読んだ入力、実験条件、実行した環境（作った日時、git のコミット・ブランチ・未コミットの変更の有無、MATLAB の版、PC の名前）の順に並べる。ルートの下のパスは `/` 区切りの相対パスにする。実行環境は、`saveCycleResult` の中から `src/` に切り出した `collectMeta`・`gitState` で集める。
   - (5) JSON にできたら、フォルダを作り、`runInfo.json` を UTF-8（BOM なし）で書く。変換を先に行うのは、変換できない値があったときに空のフォルダを残さないためである。
4. 処理と保存は今までどおりに行う。保存の行は `outDir + ファイル名` の形のまま使える。
5. 1周分のスクリプトでは、最後に `cycleConditions` へ、手順2と同じ出力と、日付・保存先・`experiments/` のフォルダ・画像の名前・スクリプト名を渡す。`cycleConditions` は入れ子の値を今までのフィールド（`lMask`・`dThresh`・`wTh` など）に写し、今までの呼び方と同じ組み立てを通す。そのため、cycleResult に保存する `conditions` の形と値は変わらない。溝選択のパラメータは次のように写す。
   - (a) 手動の溝選択のパラメータ（`grooveSelection.manual`）があれば、その4つを写す。
   - (b) 無くて、ヒストグラムによる選択（`grooveSelection.histogram`）があれば、帯の半分の幅とビンの幅を `tol`・`binWidth` に写し、ほかは `NaN` にする。今の `grooveHist_Ncycle.m` と同じ値になる。
   - (c) どちらも無ければ（自動追跡など）、4つとも `NaN` にする。

図のスクリプト（32本）を実行するとき
1. `figureDir` で保存先を作る。用途（進捗報告用・スライド用・原稿用）と名前（テーマか発表名）を受け取り、`results/figures/progress/<テーマ>/` か `results/figures/<発表名>/<slides か paper>/` を作って返す。発表名が「年月6桁と略称」（例：`202609asj`）の形でなければエラーにする。今まで4行で組み立てていた保存先が1行になる。
2. 読み込む cycleResult の日付は、新しい名前（`"2026-0731"`）で書く。図の名前とタイトルには、データの日付を4桁で書く決まりがある。そのため、4桁を取り出した `DATE_MMDD` を名前とタイトルに使う。

既存のフォルダを移すとき（main が実行した）
1. 評価基準の段階で、移す前の `results/`・`experiments/` の817ファイルについて、パス・大きさ・SHA-256（中身から計算するハッシュ値）を `scripts/evaluation/resultsLayout/manifestBeforeMigration.csv` に記録した。
2. 対応表を作った。1行が1つの移す単位で、フォルダごと移す、パターンに合うファイルを移す、1ファイルを名前を変えて移す、空になったフォルダを消す、の4種類がある。混ざったフォルダ（例：`results/1014/`）は、ファイル名のパターンで実行ごとに分け、説明を付けた（`2026-1014_manual`・`_track`・`_evaluation`）。
3. `scripts/migration/migrateResults.m` が対応表を読んで移す。
   - (1) 対応表の列とパスの形を確かめる。
   - (2) すべての行について、先に何をするかを決める。元があって行き先が無ければ移す、元が無くて行き先があれば移し終えたとして飛ばす、両方無ければ警告して飛ばす、両方あればエラー（上書きしない）にする。消すフォルダに、どの行にも当たらないファイルが残るときもエラーにする。
   - (3) エラーが1つでもあれば、何も動かさずに止める。
   - (4) 試し（既定）なら表を返して終える。そうでなければ表の順に移し、空のフォルダを消す。途中で止まっても、もう一度呼べば続きから移せる。
4. 次の順に移した。(2)(3) は「試し → 実行 → もう一度試し（すべて移し終えたことの確認）」で行った。
   - (1) スライド用の図52ファイルを、`git mv` で `results/figures/202609asj/slides/` へ移す（`3f327ed`）。git の履歴を残すためである。
   - (2) 承認B の後に、`results/` の日付のフォルダと原稿用の図、計658ファイルを移す。
   - (3) 承認C の後に、`experiments/` の12ファイルを `YYYY-MMDD` の名前に改名する。.mat の中身は変えない。

#### 選んだ理由と、採らなかった案

- 全体の方針（plan.md 3.1）
  - `mkdirFromDate` に実験名と説明の引数を足すだけの案は、変更は最も少ないが、実行記録が残らず完了条件を満たさないので採らなかった。
  - 実行記録を出力の最後に書く案は、途中で止まった実行（`results/1110/` のような例がある）に条件が残らないので採らなかった。
- 移行の仕組み（plan.md 3.2、mapping-draft.md 5章）：ファイルごとの一覧は700行を超えて承認できず、手で移すと移し忘れや打ち間違いが起きる。対応表の形式は、GitHub で表として読めて README に写しやすい CSV にし、JSON は採らなかった。
- 図の名前の日付（plan.md 3.3）：`DATE` を4桁のまま残して `"2026-" + DATE` でパスを作る案は、年をスクリプトに決め打ちするので採らなかった。4桁を取り出す共通関数を作る案は、issue に無い関数を足すので採らなかった。
- 段階の分け方（plan.md 3.4）：実装を1回にすると、承認A で表が変わったときに55本を書き直すことになる。そのため、関数と README の表を前半、スクリプト55本を後半に分けた。
- `experiments/` を改名する時期（plan.md 8章 Q1）：評価の直前の同じ日に改名し、マージまで master のスクリプトで `experiments/` を読まない運用にした。新しい名前のコピーを作る案は約 1.7 GB の重複ができ、マージの後に改名する案は新しい名前で読めることを評価で確かめられない。
- ヒストグラムで選ぶときの写し方（Q4）：issue の元の案のとおり4つとも `NaN` にすると、`grooveHist_Ncycle.m` の結果の `tol`・`binWidth` が今と変わり、README の記述と食い違う。
- #35 の実験名（Q6）：issue の slug に合わせた `wideBottomOutliers` は、評価スクリプトの置き場所と進捗報告の図のテーマ（`grooveBottomDetection`）とずれるので採らなかった。README の実験名の決め方に、「slug がすでにある名前と違うときは、すでにある名前に合わせる」を足した。
- 実行フォルダの日付（mapping-draft.md の M1）：ファイルの時刻の日付にする案は、上書きで時刻が後になっていることがあり、`experiments/` の日付や過去の記録のパスとも対応が取りにくい。そのため、今のフォルダの日付に年を足した。

#### 主なパラメータ

| 名前 | 値 | 意味 | 決めた根拠 |
|---|---|---|---|
| `EXPERIMENT_NAME` | `upsampling`・`photoshopUpscaling`・`bilateralFilter`・`digitalNeedle`・`grooveTracking`・`multiGroove`・`grooveBottomDetection`・`stylus` のどれか | 実験名。スクリプトごとに既定値を書いてある | plan.md 8章 Q6、README「実験名の一覧」 |
| `date` | スクリプトには `"YYYY-MMDD"` と置く | 実行した日。書き換えずに実行すると止まる | issue「あるべき姿」5 |
| `LABEL` | 多くは `""`。`bilateral/` の1セグメントの4本は元のサブフォルダの名前（`"ori"` など）、`bilateralOri_centroid_1cycle.m` は `"1cycle"`、評価スクリプト4本は `"evaluation"` | 説明 | plan.md 4.4、8章の仮定 |
| `schemaVersion` | 1 | 実行記録の形の版。キーや入れ子を変えたら上げ、README の版の表に書く | issue「あるべき姿」3 |
| `NumImages`・`NumSegments`・`Rpm` の既定値 | 8・10・78 | 写真の枚数、横の分割数、回転数 [rpm] | 今までの `cycleConditions` の既定値と同じ |
| `DryRun`（`migrateResults`） | true | 既定では試しだけを行う | plan.md 4.2.6 |
| `Phase`（`migrateResults`） | `"results"` か `"experiments"`（必須） | 移す段階。`experiments/` は承認C の後に別に移す | plan.md 4.2.6・7.1 |

### 4. 変えたファイル

| 区分 | パス | 役割 |
|---|---|---|
| 新規 | `src/resultDir.m`・`src/runConditions.m` | 実行フォルダを作って実行記録を書く・実験条件を決まった入れ子にまとめる |
| 新規 | `src/figureDir.m` | 図の置き場所を作って返す（`docs/refactoring/common-functions.md` の F1） |
| 新規 | `src/collectMeta.m`・`src/gitState.m` | 実行環境と git の状態を集める（`saveCycleResult` のローカル関数を切り出した。`saveCycleResult` が保存する中身は変わらない） |
| 変更 | `src/cycleConditions.m` | `runConditions` の出力を受け取る呼び方を足した。今までの呼び方も使える |
| 変更（説明だけ） | `src/mkdirFromDate.m`・`experimentDir.m`・`cycleResultPath.m`・`cycleResultFileName.m`・`saveFigure.m` | 使い方の例を新しい日付の形にした。`mkdirFromDate` には「新しいコードでは `resultDir` を使う」と書いた |
| 新規 | `scripts/migration/migrateResults.m`・`resultsMapping.csv` | 移行の関数と対応表（作業の後も残す） |
| 変更 | 1周分のスクリプト8本（`pkCentroid_1cycle.m`・`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m` など） | 冒頭の3行、`runConditions`・`resultDir`、末尾の `cycleConditions` の新しい呼び方。ループの中で決めていた定数は、値を変えずに冒頭へ移した |
| 変更 | ほかの実験のスクリプト15本（`bilateral/` の5本、評価スクリプト4本など） | `runConditions`・`resultDir` で出力先を作る |
| 変更 | 図のスクリプト32本（`scripts/paper/202609asj/`・`scripts/slides/202609asj/`・`scripts/progress/`） | `figureDir` の1行で保存先を作る。読み込みの日付を新しい名前にした |
| 新規 | `scripts/evaluation/resultsLayout/checkResultsLayout.m`・`manifestBeforeMigration.csv` | 評価スクリプトと、移す前の817ファイルの記録（evaluator（A）） |
| 変更 | `.gitignore` | 移した後も、追跡するもの（スライド用・進捗報告用の図）と無視するものが今と同じになる規則 |
| リポジトリの外（git 管理外） | `results/`・`experiments/` | 658ファイルの移動と、12ファイルの改名 |

- 保存形式
  - 実行フォルダに `runInfo.json` が加わる。項目と単位は、ルートの README の「`runInfo.json` の項目」の表にある。`experiments/` には実行記録を作らない（cycleResult に同じ情報があるため）。
  - 新しい cycleResult は `experiments/<YYYY-MMDD>/cycleResult_<条件>_<YYYY-MMDD>.mat` になる。`conditions` と `meta` の形は今までと同じで、`conditions.date` が `"2026-1124"` の形になるだけである。
- 互換性
  - 改名した既存の .mat の中身は変えていないので、中の `conditions.date` は4桁（`"0731"` など）のまま残る。`cycleConditions` の今までの呼び方と、`cycleResultPath` が移行前の置き場所も探す動作も残した。
  - 古い名前（`results/1014/`・`experiments/0731/` など）はもう無い。過去の記録に書かれたパスは、README の「対応表（移す前の置き場所）」で今の場所を引く。図のファイル名は変えていない。
- テストは unit テスト6クラス（46件）と受け入れテスト（42件）を足した。文書は、README、`CLAUDE.md`、`docs/rules/` の4つ、`docs/refactoring/common-functions.md`、`docs/staged-development.md`、`docs/issues/README.md`、`.claude/` の5つ、`.github/ISSUE_TEMPLATE/figure.md` を、新しい置き場所に合わせた。

### 5. 計画から変わったこと

差し戻しは0回。計画からの違いは次のとおり（impl-report-1a.md 3章、impl-report-1b.md 3章、作業履歴）。どれも、数値の出力と cycleResult の形には影響しない。
- `runConditions` は、高解像度化の種類に無いパラメータ（例：`origD` のときの内挿の間隔）も、渡せば実行記録に書く。計画の表はこの場合を決めていなかった。承認A でユーザーがこの扱いに決め、「エラーにする」案は続きのissueの案A にした。
- `runConditions` に空の `ReplayFrom` を渡したときは、渡さなかったのと同じに扱う。ほかに溝の選び方の引数が無ければ、`grooveSelection` のグループも作らない（空のグループを書かないため）。
- `migrateResults` の確かめ方を計画より厳しくした。パスは段階の名前（`results/`・`experiments/`）で始まる相対パスに限り、移動に失敗したときの識別子 `migrateResults:moveFailed` を足した。パターンが重なったときは対応表で先の行が取り、空のフォルダを消すときは空のサブフォルダごと消す。
- README の節に、計画の項目のほかに「言葉」「置き場所」「実験名の決め方」「スクリプトでの使い方」と `runInfo.json` の例を足した。
- 評価スクリプトでは、評価のしきい値を `Other` に `th` で始まるキー（例：`thE1RmseMaxCentroid`）で渡す。うち2本（`compareInclBoundToExclBound.m`・`compareWidthThresh.m`）は、図の表記に `LABEL` の名前をすでに使っているので、説明の変数を `RUN_LABEL` にした。
- 画像の一部だけを使う3本（`bilateral8x_centroid.m`・`darkness3d.m`・`showPhotoshopGrooveExtraction.m`）は、行・列の範囲を、両端ではなく番号の一覧のまま実行記録に書く。そのため、実行記録が長くなる。うち2本は、`runConditions` に渡す定数を、値を変えずに前へ移した。
- `.gitignore` は、計画ではスライド用の図の `git mv` と一緒に、承認の後でコミットする順だった。main が、実装の後半の確認待ちのコミット `0e3527e` に含めた。追跡されているファイルの変更を残したまま夜を越し、進捗ログの自動更新が見送りになるのを避けるためである（retrospective.md 4章の2）。
- 評価スクリプトが自分自身を「実験のスクリプト」に数える不具合を、実装担当が見つけた。ユーザーは評価スクリプトを直さず、外れが評価スクリプト自身の1本だけなら満たしたとする、と決めた（criteria.md 7章、2026-11-25）。

### 6. 評価の結果

- **合格（1回目）**。evaluator（B）の判定は「ユーザー確認待ち」（不合格の項目なし）で、ユーザーが U1〜U3 を確かめて合格とした（2026-11-26。eval-report-1.md の先頭・1章）。評価したコードは `d1c6c37`。
- 主な項目（eval-report-1.md 3章。括弧内は criteria.md の項目 ID）

| 項目 | 結果 | しきい値 |
|---|---|---|
| テスト（T1） | `runAllTests` 346件すべて通過（受け入れテスト 42/42） | 失敗 0件 |
| `checkcode` の警告が増えたファイル（T2） | 0個（74個を調べ、警告は変える前も後も27件） | 0個 |
| 移す前に記録したファイルが、移し先に同じ中身である（Q1・D3） | 817/817。うち `experiments/` は 15/15 | すべて |
| 移ったファイルの数（P8・Q3a） | 日付のフォルダ 603、原稿用 55、スライド用 52、`experiments/` 12。進捗報告用 92 と `experiments/archive/` 3 は動かない。移行の試しは79行すべて「移し終えた」 | 計画と同じ |
| git の追跡（Q5） | 追跡しているのは144ファイルのまま。`results/` の差分は、スライド用の図の移動52行だけ | 今と同じ |
| 古い書き方の残り（Q6a・Q6b） | 0行。要確認の2行は、古い置き場所を過去のこととして書いた行 | 0行 |
| 実データの実行（Q10） | `results/bilateralFilter/2026-1126_1cycle/` に、0924 の実行と同じ名前の36ファイルと `runInfo.json` ができ、値はスクリプトの定数と同じ。wav 4つは 0924 の実行と完全に同じだった（参考） | 外れ 0件 |
| 同じ設定の2回目（Q11）、日付を書き換えずに実行（Q13） | 2回目は `2026-1126_1cycle_2` ができ、警告 `resultDir:folderExists` が出た。書き換えないと `resultDir:dateNotSet` で止まり、フォルダは作られない | 満たす |
| 書き換えで数値が変わらない（Q12） | 1014 の手動選択を再現し、`ycoords`（両手法）が `isequal`、`conditions` が日付・保存先を除いて `isequaln` | すべて |

- 判定の補足
  - P1・P2・Q7 は、評価スクリプトの表では「満たさない」と出た。外れは評価スクリプト自身の1本だけで、ユーザーの決定（5節の最後）により満たしたとした。
- ユーザーの確認（2026-11-26）：次の3つを見て、問題なしとした。
  - U1：移した後の `results/` の並び（eval-report-1.md 6章の表）
  - U2：実データの実行でできた `runInfo.json`
  - U3：ルートの README の「結果の置き場所と実行記録」の節
- 評価に使ったデータ
  - 移す前の記録 `scripts/evaluation/resultsLayout/manifestBeforeMigration.csv`（817行）と、`experiments/2026-0807/`・`experiments/2026-1014/` の cycleResult（eval-report-1.md 2章）。
  - 評価で作った実行フォルダ `results/bilateralFilter/2026-1126_1cycle/`・`2026-1126_1cycle_2/`、`results/grooveTracking/2026-1126_check/` と、実装担当の確認で作った `2026-1125_implCheck/` の2つは、ユーザーの決定で残す。

### 7. 使い方

1. MATLAB で `Research.prj` を開き、実験のスクリプトの冒頭の `date` を実行した日（例 `"2026-1124"`）に書き換えて実行する。必要なら `EXPERIMENT_NAME` と `LABEL` も書き換える。図・音声と `runInfo.json` は `results/<EXPERIMENT_NAME>/<date>[_<LABEL>]/` にでき、同じ名前があれば `_2` が付く。1周分のスクリプトの cycleResult は、今までどおり `experiments/<date>/` に保存される。
2. 新しい手法を試し始めたときは、ルートの README の「結果の置き場所と実行記録」の「実験名の決め方」に従って実験名を決め、「実験名の一覧」に行を足す。
3. 新しいスクリプトは、同じ節の「スクリプトでの使い方」の順（実験名・日付・説明、`runConditions`、`resultDir`、1周分なら最後に `cycleConditions`）で書く。どのグループにも入らない条件は `Other` に入れる。
4. 図のスクリプトは、`figureDir` が保存先を作るので、そのまま実行する。読み込む cycleResult の日付は `"2026-0731"` の形で書く。図の置き場所の決まりは `docs/rules/figures.md` にある。
5. 過去の記録に古いパス（例 `results/1014/`）があれば、README の「対応表（移す前の置き場所）」で今の場所を引く。
6. ほかの PC に古い形の `experiments/` や原稿用の図のコピーがあるときは、`scripts/migration/` を `addpath` し、`migrateResults` を同じ対応表で、試し → 実行の順に呼ぶ。

### 8. 制約と残った課題

- 制約
  - `experiments/` を改名したので、PR をマージするまで、master のスクリプトでは `experiments/` を読めない（plan.md 8章 Q1）。
  - 既存のフォルダには実行記録を作っていない。作ったときの条件を正確には復元できないためである。過去の記録（`docs/issues/closed/`・`docs/progress/`・`slides/progress/`）の古いパスも書き換えていない。
  - 移した `results/grooveBottomDetection/2026-1111_exclBoundVsInclBound/README.md` の相対リンク2つは、移動で切れている（M4 で、そのまま移すと決めた）。
  - 移行はこの PC（desktop）だけで行った。`digitalNeedle` のスクリプトはマージしていないブランチにだけあり、動かすと古い形の名前で保存する。
  - 動かない6本のスクリプトは、出力先と日付の行だけを置き換え、動かない箇所は直していない。今ある `checkcode` の警告27件も直していない（Q5）。
  - 評価スクリプトが自分自身を対象に数える不具合は、直していない。実行記録の画像の範囲の書き方（5節）は、使ってみてから変えるかを決める（retrospective.md 6章）。
  - CI（GitHub Actions の `test`）は、PR #38 で通った（2026-11-26）。
- 続きのissueの案（[`follow-ups.md`](./follow-ups.md)。どちらも #28 のマージ後に作ると決めた、2026-11-26）
  - 案A：`runConditions` に、使われない高解像度化のパラメータを渡したらエラーにする。
  - 案B：書き換えの範囲の外に残った古い置き場所と危ない動き（`sound_from_stylus.m` が `data/` に wav を書く、`pkCentroidAndLocalMax_resample_1cycle.m` が無いフォルダ `results\0615\` を読む、`loadCycleResult.m` の例の古い日付、古い絶対パスのコメント）を直す。

### 9. 詳しく読むには

- 経過と振り返り：[`retrospective.md`](./retrospective.md) 1・2章（書き直し・差し戻し0回）、4章（問題と学び）。改善案 G1〜G4 は同7章（master の `ad98195` で反映し、`ccef766` で作業ブランチに取り込んだ）。
- 問題とゴール：issue #28 の「ゴール」「背景・目的」「あるべき姿」「制約・触らないもの」。
- 方法・パラメータ：[`plan.md`](./plan.md) 1章（結論）、2章（調査結果）、3章（案の比較）、4章（設計。`runInfo.json` の項目は 4.3、スクリプトごとの書き換えは 4.4）、7.1（移行の手順）、8章（決定事項 Q1〜Q6）。対応表の案と M1〜M6 は [`mapping-draft.md`](./mapping-draft.md)。
- 評価基準：[`criteria.md`](./criteria.md) 1章（判定の決め方）、3章（しきい値の根拠）、4章（項目）、5章（古い書き方で残ってよいもの）、7章（決定事項）。
- 実装：[`impl-report-1a.md`](./impl-report-1a.md)（前半。2・3章）、[`impl-report-1b.md`](./impl-report-1b.md)（後半。2・3章、4章の移行の試しの表と実データでの確認）。
- 評価：[`eval-report-1.md`](./eval-report-1.md) の先頭（ユーザーの確認）、2章（条件）、3章（項目ごとの結果）、6章（U1 の並び）。
- 主なコミット：計画の承認 `ef39e86`、評価基準・受け入れテスト・評価スクリプト `0e60754`、実装の前半 `fd98ae0`（`Agent: implementer`）、実装の後半と `.gitignore` `0e3527e`（`Agent: implementer`）、スライド用の図の移動 `3f327ed`、`results/` の移行の記録 `c2ce382`、`experiments/` の改名の記録 `d1c6c37`、評価レポート `ae14c2b`（`Agent: evaluator`）、合格の記録 `bb3d703`。

## 作業履歴

### 準備・全体 — 完了

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | main | issue #28 を受け、ブランチ `claude/results-by-experiment`（`origin/master` の `94e3057` から）と受け渡しフォルダを作る。<br>issue の未決事項は「着手前に決めることは無い」とあり、作業の途中で確かめる3つ（`experiments/` を改名してからマージまでの扱い、`runInfo.json` の項目の表、対応表）だけが書かれているので、着手前に尋ねることは無い。<br>同じフォルダで動いていた #35 の進捗報告の素材の試行のセッションが終わるのを待ってから、ブランチを切った | `README.md`、`c7d2460` |
| 2026-11-23 | ユーザー | **決定** 進め方：各サブエージェントが段階の作業を終えるたびに、main がその内容と未決事項をユーザーに報告する。ユーザーが承認したら、次の段階に進む。<br>**決定** 確認を省く範囲：承認を次の段階の開始の合図とし、エージェントを呼ぶ前の確認と依頼文の事前の提示は省く。手順書どおりの段階ごとのコミット（確認待ち・決定の反映）も、確認なしで main が行う。push・PR の作成・`experiments/` の改名は、そのつどユーザーに確かめる | — |
| 2026-11-23 | ユーザー | **決定** 進捗報告の素材は作らない。結果フォルダの構成と実行記録の整理で、研究の内容（溝の抽出や音声の品質）には関わらないため | — |

### 計画 — 承認済み

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | planner | `plan.md` を書く（1回目）。推奨は、`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState` を `src/` に作り、スクリプト55本は出力先・日付・実験条件の行だけを差し替える案。既存のフォルダは、対応表の CSV を読む `scripts/migration/migrateResults.m` で移す。<br>実装を前半（関数・テスト・README の表。承認A）と後半（スクリプト・文書・`.gitignore`）に分け、移行は main が承認B（対応表）・承認C（バックアップ）を取って行う。`experiments/` の改名は評価の直前。<br>未決事項 Q1〜Q6、対応表の未決事項 M1〜M5。<br>対応表の案は `mapping-draft.md` に分けた（main が依頼文で認めた例外。planner が書いてよいのは本来 `plan.md` だけ） | [`plan.md`](./plan.md)、[`mapping-draft.md`](./mapping-draft.md)、`48798a3` |
| 2026-11-24 | ユーザー | **決定** 承認。Q1〜Q5 は推奨どおり。`experiments/` は評価の直前に改名し、マージまで master のスクリプトで読まない。移行は main が承認B・C を取って行う。`runInfo.json` は 4.3 の表のとおり。`Histogram` があれば `tol`・`binWidth` を写す。既存のスクリプトの不具合は推奨のとおりに扱い、今ある警告は直さない | — |
| 2026-11-24 | ユーザー | **決定** Q6：実験名は (a) の8つ。#35 の実験は `grooveBottomDetection`。<br>issue の規則の「slug に合わせる」と「図のテーマと同じ名前にする」が #35 でぶつかるので、README に書く実験名の決め方に「issue の slug が、すでにある図のテーマや評価スクリプトの置き場所の名前と違うときは、すでにある名前に合わせる」を足す | — |
| 2026-11-24 | main | 決定を `plan.md` 8章（と 5.1 の手順9）・`mapping-draft.md` の M6 に書き、状態を「承認済み」にしてコミットする。M1〜M5 と説明の最終案は承認B で決める | [`plan.md`](./plan.md)、`ef39e86` |

### 評価基準 — 承認済み

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | evaluator（A） | `criteria.md` を書き、受け入れテスト（42件）と評価スクリプトを作る（1回目）。途中で利用上限により止まり、同じエージェントを再開して仕上げた。<br>数値の項目は、テスト T1・T2、計画どおりかの確認 P1〜P8、品質の基準 Q1〜Q13（Q3・Q6 は a・b に分ける）、変えてはいけないもの D1〜D4。ユーザーが判断する項目は U1〜U3（移した後の `results/` の並び、実データの `runInfo.json`、README の節）。<br>移す前の `results/`・`experiments/` の817ファイルのパス・大きさ・SHA-256 を `manifestBeforeMigration.csv` に記録した。数え直した数は計画の見込み（603・55・52・92・144）とすべて同じ。<br>仕様どおりの使い捨ての試作で42件すべてが通り、誤りを入れた試作18通りはすべて落ちることを確かめた。未決事項 Q-a | [`criteria.md`](./criteria.md)、`test/unit/ResultLayoutAcceptanceTest.m`、`scripts/evaluation/resultsLayout/` |
| 2026-11-24 | main | 受け入れテストを実行し、3件が通り39件が失敗することを確かめる（関数がまだ無いので正常）。評価基準・受け入れテスト・評価スクリプトを確認待ちでコミットする | `0e60754` |
| 2026-11-24 | ユーザー | **決定** criteria.md を承認した。Q-a は (a)（「計画」だけを満たさないときも不合格にし、実装に戻す） | — |
| 2026-11-24 | main | 決定を criteria.md 7章に書き、状態を「承認済み」にする。受け入れテストを追加したコミット `0e60754` を criteria.md の先頭と 2.2 に書き入れてコミットする | [`criteria.md`](./criteria.md)、`84942d5` |

### 実装と移行 — 完了

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-24 | implementer | 前半（`plan.md` 5.1 の手順1〜11）。`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState` を `src/` に作り、`saveCycleResult` から `collectMeta`・`gitState` を使う形にした。`cycleConditions` に新しい呼び方を足し、`scripts/migration/migrateResults.m` を作った。unit テスト6クラス（46件）を書き、README に「結果の置き場所と実行記録」の節を作った。<br>`runAllTests` は346件すべて通過（受け入れテスト 42/42）。書いた・変えた `.m` 19個の `checkcode` の警告は0件。<br>計画との違いは細部の5つ（`migrateResults` の CSV の確かめ方を厳しくした、識別子 `migrateResults:moveFailed` を足した、README に小節を足したなど）。未決事項 Q1（`kind` に無い高解像度化のパラメータを渡したときの扱い） | [`impl-report-1a.md`](./impl-report-1a.md) |
| 2026-11-24 | main | 差分を確かめる。変えたファイルは計画の前半の範囲だけで、説明だけを直す5つの `src/` は、コメントの行だけが変わっていた。`runAllTests` を実行し、346件すべての通過を確かめる。前半を確認待ちでコミットする | `fd98ae0` |
| 2026-11-25 | ユーザー | **決定** 承認A：README の「`runInfo.json` の項目」の表と「実験名の一覧」を、そのまま承認した。<br>**決定** Q1 は (a)：`runConditions` は、`kind` に無い高解像度化のパラメータも、渡されれば書く。(c)「エラーにする」は、今後の実装の案として残す | — |
| 2026-11-25 | main | 決定を書き、Q1 の (c) を `follow-ups.md` の案A に下書きする | [`follow-ups.md`](./follow-ups.md)、`2416ee2` |
| 2026-11-25 | implementer | 後半（`plan.md` 5.2 の手順12〜20）。スクリプト55本（実験23本は `runConditions`・`resultDir`、うち1周分の8本は `cycleConditions(runCond, …)` も、図32本は `figureDir`）、`.gitignore`、文書15ファイル、README の「対応表」の節を直し、`scripts/migration/resultsMapping.csv` を `mapping-draft.md` の今の案どおりに作った。<br>`runAllTests` は346件すべて通過（受け入れテスト 42/42）。`checkcode` の警告は変える前と同じ27件。移行の試しは `results` 57行・658ファイル、`experiments` 22行・12ファイルで、エラー・警告なし。<br>実データの確認で、`results/bilateralFilter/2026-1125_implCheck/`（37ファイル、wav は 0924 と同じ）と `results/grooveTracking/2026-1125_implCheck/`（15ファイル、`ycoords` は 1014 と `isequal`）を作り、残した。<br>計画との違いは細部の8つ。未決事項 Q1（評価スクリプトが自分自身を対象に数える不具合）、Q2（M1〜M5 と説明に関わる CSV の行） | [`impl-report-1b.md`](./impl-report-1b.md) |
| 2026-11-25 | main | 差分を確かめる。`src/`・`test/`・受け入れテスト・評価スクリプト・`criteria.md`・`plan.md`・`mapping-draft.md`・`follow-ups.md` は変わっていない。`runAllTests` を実行し、346件すべての通過を確かめる。評価スクリプトの不具合（Q1）は、`baseGrepFiles` が基準のコミットの `scripts/` を探すので、自分自身の `mkdirFromDate`・`cycleConditions(` の文字列に当たることを、コードで確かめた。<br>作業ツリーを空にして進捗ログの定期タスクを止めないよう、計画 7.1 の手順2で入れる予定の `.gitignore` も、このコミットに含める（`git mv` は承認の後に行う） | `0e3527e` |
| 2026-11-25 | ユーザー | **決定** 実装の後半を承認した。<br>**決定** 後半の Q1 は (b)：評価スクリプトは直さない。P1・P2・Q7 で、外れが評価スクリプト自身の1本だけのときは、満たしたとする | — |
| 2026-11-25 | main | 決定を `criteria.md` 7章に書く | [`criteria.md`](./criteria.md)、`6dc758a` |
| 2026-11-25 | main | 計画 7.1 の手順2。`.gitignore` は `0e3527e` で入れてある。`git mv results/figures/slides/202609asj results/figures/202609asj/slides` で52ファイルを移し、差分が移動（R100）52行だけであることを確かめてコミットした。空になった `results/figures/slides/` を消した。`git ls-files results` は144のまま | `3f327ed` |
| 2026-11-25 | main | 承認B の材料。作業ツリーが空の状態で、`migrateResults` の試しを両方の段階で実行した。`results` は57行（移す45行・658ファイル、空のフォルダを消す12行）、`experiments` は22行（移す12行・12ファイル、消す10行）で、警告は出なかった。`impl-report-1b.md` 4章の表と同じ。M1〜M5、説明の語、implCheck の2つのフォルダを残すかを、ユーザーに確かめる | `dbad295` |
| 2026-11-26 | ユーザー | **決定** 承認B：移行の試しの表を承認した。M1〜M5 と説明の語は、すべて推奨の (a)（日付は今のフォルダの日付に年を足す。空の `experiments/1026/`・`1110/` は消す。`0831/digitalNeedle/` はほかと同じ規則で移し、ファイル名の日付も変える。`results/1111/README.md` はそのまま移す。`results/1110/` は移して残す。説明は `mapping-draft.md` の表のとおり）。<br>**決定** 実装担当の確認で作った `results/bilateralFilter/2026-1125_implCheck/` と `results/grooveTracking/2026-1125_implCheck/` は残す。新しい形の名前なので、移さずに残す古い形のフォルダ（評価スクリプトの `APPROVED_LEFTOVERS`）には当たらない。承認B で残す・消すと決めた古い形のものは無いので、`APPROVED_LEFTOVERS`・`APPROVED_DELETIONS` は空のまま | — |
| 2026-11-26 | main | 決定を `mapping-draft.md` の未決事項の節に書く | [`mapping-draft.md`](./mapping-draft.md)、`831e64d` |
| 2026-11-26 | main | 計画 7.1 の手順3。作業ツリーが空の状態で、`migrateResults(..., Phase="results")` の試し（移す45行・658ファイル、消す12行。承認B の表と同じ）→ `DryRun=false` で移す → もう一度試す、の順に行った。最後の試しは57行すべて `done` で、警告は出なかった。<br>`results/` の直下は実験名7つ（`stylus` はまだ無い）と `figures` だけになった。移したファイルの数は、実験名ごとに合計603（implCheck の52を除く）と原稿用の55で、計画と同じ。`git status` は空のままで、`git ls-files results` は144 | `c2ce382` |
| 2026-11-26 | ユーザー | **決定** 承認C：ユーザーが `data/` と `experiments/` のバックアップを取った（main による確認は不要とした）。`experiments/` の改名を指示した | — |
| 2026-11-26 | main | 計画 7.1 の手順4。`migrateResults(..., Phase="experiments")` の試し（移す12行・12ファイル、消す10行）→ `DryRun=false` で移す → もう一度試す、の順に行った。最後の試しは22行すべて `done` で、警告は出なかった。`experiments/` の直下は `archive` と `YYYY-MMDD` の9つになり、`.mat` 12個は新しい名前、`archive/` の3つはそのまま。この時点から PR のマージまで、master のスクリプトで `experiments/` を読めない（計画 Q1） | `d1c6c37` |

### 評価 — 合格（1回目）

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-26 | evaluator（B） | `d1c6c37` を評価した（1回目）。判定は「ユーザー確認待ち」。T・P・Q・D の数値の項目はすべて満たした（`runAllTests` 346件通過、Q1 817/817、D3 15/15、E1〜E5 とも基準どおり）。P1・P2・Q7 の外れは評価スクリプト自身の1本だけで、7章の決定 (b) により満たしたとした。<br>評価で `results/bilateralFilter/2026-1126_1cycle/`・`2026-1126_1cycle_2/`・`results/grooveTracking/2026-1126_check/` を作った。残すかが未決事項 | [`eval-report-1.md`](./eval-report-1.md) |
| 2026-11-26 | main | 作業ツリーに `eval-report-1.md` のほかの変更が無いことを確かめ、確認待ちでコミットする | `ae14c2b` |
| 2026-11-26 | ユーザー | **決定** U1〜U3 は問題なし。評価は合格。評価で作った実行フォルダ3つは残す | — |
| 2026-11-26 | main | ユーザーの確認を `eval-report-1.md` の先頭に追記し、状態を「確定」にする | [`eval-report-1.md`](./eval-report-1.md)、`bb3d703` |

### 振り返り — 確定

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-26 | main | `retrospective.md` を書く。書き直し・差し戻しは0回。改善案は G1〜G4 | [`retrospective.md`](./retrospective.md)、`0163ea2` |
| 2026-11-26 | ユーザー | **決定** 改善案 G1〜G4 をすべて採用した | — |
| 2026-11-26 | main | G1〜G4 を master で反映した（`ad98195`。メインのフォルダで一時的に master に切り替えてコミットし、元のブランチに戻した）。master を作業ブランチに取り込んだ（`ccef766`。ほかに入ったのは進捗ログの自動更新2つ） | `ad98195`、`ccef766` |

### 続きのissue — 確定

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-26 | main | `follow-ups.md` に案B（範囲の外に残った古い置き場所と危ない動き）を足す。案は A・B の2つ | [`follow-ups.md`](./follow-ups.md)、`0163ea2` |
| 2026-11-26 | ユーザー | **決定** 案A・B は、どちらも #28 のマージ後にissueにする | — |

### 解決のまとめ — 完了

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-26 | summarizer | 「解決のまとめ」の節を書く（対象のコード `8a16012`、差分は `master...HEAD`）。記録の抜けとして、CI の結果が無いこと、作業履歴の見出しが古いこと、改名の行のコミットが抜けていることを挙げた | この README の「解決のまとめ」 |
| 2026-11-26 | main | 差分が「解決のまとめ」の節だけであることを確かめる。見出し（実装と移行、解決のまとめ）と、改名の行のコミット `d1c6c37` を直す。CI の結果は、PR を作った後に書き足す | — |
### 仕上げ（closed/ へ移動・PR） — 完了

| 日付 | 担当 | 内容 | 成果物 |
|---|---|---|---|
| 2026-11-26 | main | 受け渡しフォルダを `docs/issues/closed/` へ移し、フォルダの外から指していた3つのファイル（評価スクリプト、`migrateResults.m`、受け入れテスト）のパスを同じコミットで書き換える | — |
| 2026-11-26 | ユーザー | **決定** push と PR の作成を指示した。Auto-fix は使わない | — |
| 2026-11-26 | main | master（`ad98195` まで）と作業ブランチを push し、PR #38 を作った。CI（`test`）は通った | [#38](https://github.com/MiwaHiroki/myResearch/pull/38) |
| 2026-11-26 | ユーザー | PR #38 をマージした（`b5f9a15`） | — |
| 2026-11-26 | main | master で、CI の結果とマージをこの README に書く | — |

## ファイル一覧

- `README.md`：このファイル
- [`plan.md`](./plan.md)：計画
- [`mapping-draft.md`](./mapping-draft.md)：既存のフォルダの対応表の案（計画の付属）
- [`criteria.md`](./criteria.md)：評価基準
- [`impl-report-1a.md`](./impl-report-1a.md)：実装の報告（1回目の前半）
- [`impl-report-1b.md`](./impl-report-1b.md)：実装の報告（1回目の後半）
- [`eval-report-1.md`](./eval-report-1.md)：評価レポート（1回目）
- [`retrospective.md`](./retrospective.md)：振り返り
- [`follow-ups.md`](./follow-ups.md)：続きのissueの案
