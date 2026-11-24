- 段階: 実装（1回目の後半）
- 作成者: implementer
- 作成日: 2026-11-25
- 入力: issue #28（本文。コメントなし）、[`./README.md`](./README.md)（作業履歴の決定、承認A）、[`./plan.md`](./plan.md)（承認済み。4.4・4.5・5.2・8章）、[`./criteria.md`](./criteria.md)（承認済み）、[`./mapping-draft.md`](./mapping-draft.md)、[`./impl-report-1a.md`](./impl-report-1a.md)、`test/unit/ResultLayoutAcceptanceTest.m`、`scripts/evaluation/resultsLayout/checkResultsLayout.m`、main の依頼文
- 状態: 下書き

# #28 実装の報告（1回目の後半）

## 言葉

- **前半・後半**：`plan.md` の「言葉」と同じ。後半は `plan.md` 5.2 の手順12〜20（スクリプト55本・文書・`.gitignore`・対応表の CSV・実データでの確認）である。
- **55本**：基準のコミット `0e60754` で `mkdirFromDate` を使っていた実験のスクリプト23本と、`"results","figures"` で保存先を組み立てていた図のスクリプト32本（`plan.md` 2.1）。
- **試し**：`migrateResults` を `DryRun=true`（既定）で呼ぶこと。移す内容を表にして返すだけで、ファイルを何も動かさない。
- **implCheck のフォルダ**：この報告の確認（手順18）で、`temp/` のコピーを実行して作った実行フォルダ。説明を `implCheck` にした。

## 1. 結論

- `plan.md` 5.2 の手順12〜20 をすべて終えた。
  - スクリプト55本を書き換えた。実験のスクリプト23本は `runConditions`・`resultDir` で出力先を作り、1周分の8本は同じ `runConditions` の出力を `cycleConditions` にも渡す。図のスクリプト32本は `figureDir` の1行で保存先を作る。
  - `.gitignore`、文書15ファイル（`plan.md` 2.1 の (6)）、README の「対応表」の節を直した。
  - 対応表の CSV `scripts/migration/resultsMapping.csv` を、`mapping-draft.md` の今の案（推奨）どおりに作った。
- `cd test; results = runAllTests;` は **346 件すべて通った**（失敗 0、未完了 0）。受け入れテスト `ResultLayoutAcceptanceTest` は **42/42** 通った。
- `checkcode` の警告は、変えた `.m` 55個のどれでも増えていない。変える前と同じ7本・27件である（付録 A.8 と同じ）。
- `migrateResults` の試しは、両方の段階でエラーも警告も無く通った。
  - `Phase="results"` は 57 行で、移すファイルは 658 個（日付のフォルダ 603、原稿用の図 55）である。
  - `Phase="experiments"` は 22 行で、移すファイルは 12 個である。
  - 行き先のフォルダごとの数は、`mapping-draft.md` 2〜4章の「数」とすべて同じだった。
- 実データでの確認（手順18）は、2つとも通った。
  - (1) `bilateralOri_centroid_1cycle.m` のコピーは、`results/bilateralFilter/2026-1125_implCheck/` に、0924 の実行と同じ名前の36ファイルと `runInfo.json` を作った。wav 4つは 0924 の実行と完全に同じだった。
  - (2) `pkCentroid_1cycle.m` のコピーは、1014 の手動選択を再現した。`ycoords`（両手法）は `isequal`、`cond` は `date`・`saveDir`・`experimentDir` を除いて `isequaln` だった。
- 計画と違う点は、細部の8つである（3章）。出力の数値と cycleResult の形には影響しない。
- 評価スクリプト `checkResultsLayout.m` に、P1・P2・Q7 を誤って「満たさない」にする不具合を見つけた（6章の Q1）。自分では直していない。

## 2. 変更したファイル

### 一覧（`git status --short`）

```
 M .claude/agents/evaluator.md
 M .claude/agents/illustrator.md
 M .claude/agents/implementer.md
 M .claude/skills/make-figure/SKILL.md
 M .claude/skills/progress-material/SKILL.md
 M .github/ISSUE_TEMPLATE/figure.md
 M .gitignore
 M CLAUDE.md
 M README.md
 M docs/issues/README.md
 M docs/refactoring/common-functions.md
 M docs/rules/coding.md
 M docs/rules/data.md
 M docs/rules/evaluation.md
 M docs/rules/figures.md
 M docs/staged-development.md
 M scripts/bilateral/bilateral8x_centroid.m
 M scripts/bilateral/bilateralOriInterp2_centroid.m
 M scripts/bilateral/bilateralOriResample_centroid.m
 M scripts/bilateral/bilateralOri_centroid.m
 M scripts/bilateral/bilateralOri_centroid_1cycle.m
 M scripts/darkness3d.m
 M scripts/evaluation/grooveBottomDetection/compareInclBoundToExclBound.m
 M scripts/evaluation/grooveBottomDetection/compareWidthThresh.m
 M scripts/evaluation/grooveTracking/compareTrackingToManual.m
 M scripts/evaluation/multiGroove/compareHistToTracking.m
 M scripts/evaluation/stylus/sound_from_stylus.m
 M scripts/grooveHist_Ncycle.m
 M scripts/grooveTrack_1cycle.m
 M scripts/grooveTrack_Ncycle.m
 M scripts/paper/202609asj/fig1_1_grooveBtmOnDarkness3d.m
 M scripts/paper/202609asj/fig1_2_grooveBtmOnImage.m
 M scripts/paper/202609asj/fig2_darknessProfile.m
 M scripts/paper/202609asj/fig3_grooveBtmMethodsOnImage.m
 M scripts/paper/202609asj/fig4_darkness3dComparison.m
 M scripts/paper/202609asj/fig5_spectrogramComparisonOrigD.m
 M scripts/paper/202609asj/fig6_spectrogramUpsampling.m
 M scripts/paper/202609asj/fig_GrooveBtmOnImageUpsamplingD.m
 M scripts/paper/202609asj/fig_grooveShapeComparison.m
 M scripts/paper/202609asj/fig_grooveShapeMethodComparison.m
 M scripts/paper/202609asj/fig_grvBtmOnImgOrigUpsamplingD.m
 M scripts/paper/202609asj/fig_waveformComparisonOrigD.m
 M scripts/paper/202609asj/fig_waveformUpsampling.m
 M scripts/photoshop_centroid_1cycle.m
 M scripts/photoshop_localMax_1cycle.m
 M scripts/pkCentroidAndLocalMax_resample_1cycle.m
 M scripts/pkCentroid_1cycle.m
 M scripts/pkCentroid_interp2.m
 M scripts/pkCentroid_interp2_1cycle.m
 M scripts/pkCentroid_resample.m
 M scripts/pkCentroid_resample_1cycle.m
 M scripts/progress/grooveBtmOnImageTrackOutlier.m
 M scripts/progress/grooveOnImageManualAndTrack.m
 M scripts/progress/multiGrooveOnePhoto.m
 M scripts/progress/showPhotoshopGrooveExtraction.m
 M scripts/progress/waveformManualVsTrack.m
 M scripts/progress/waveformTrackVsHist.m
 M scripts/progress/wideBottomOutlier.m
 M scripts/progress/wideBottomOutlierWaveform.m
 M scripts/progress/wideBottomOutlierWidthThresh.m
 M scripts/slides/202609asj/darkness3dComparison.m
 M scripts/slides/202609asj/darknessProfile.m
 M scripts/slides/202609asj/grooveBtmOn3d.m
 M scripts/slides/202609asj/grooveBtmOnImage.m
 M scripts/slides/202609asj/grooveBtmOnImgOrigUpsamplingD.m
 M scripts/slides/202609asj/grooveShape3d.m
 M scripts/slides/202609asj/photoshopNoise.m
 M scripts/slides/202609asj/stylusPlayback.m
 M scripts/slides/202609asj/waveformAndSpectrogramOrigD.m
 M scripts/slides/202609asj/waveformAndSpectrogramUpsampling.m
 M scripts/slides/202609asj/waveformUpsampling.m
?? scripts/migration/resultsMapping.csv
```

この報告（`impl-report-1b.md`）は、上の一覧を取った後に書いたので、一覧には入っていない。`src/`・`test/` は変えていない。`git mv`・`git add`・`git commit` はしていない。

### 要点

| 区分 | ファイル | 要点 |
|---|---|---|
| 1周分のスクリプト（8本） | `pkCentroid_1cycle.m`・`pkCentroid_resample_1cycle.m`・`pkCentroid_interp2_1cycle.m`・`photoshop_centroid_1cycle.m`・`photoshop_localMax_1cycle.m`・`grooveTrack_1cycle.m`・`grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m` | 冒頭に `EXPERIMENT_NAME`・`date = "YYYY-MMDD"`・`LABEL = ""` を置き、`runConditions` → `resultDir` → `experimentDir` の順に出力先を作る。末尾は `cycleConditions(runCond, Date=…, SaveDir=…, ExperimentDir=…, Filenames=…, ScriptName=…[, Note=…])`。`plan.md` 4.4.1 の表のとおり、ループの中の定数（`WIDTH_THRESH`・`h_prl`・`tol`・`binWidth`・`P_RSMPL`・`Q_RSMPL`・`QUERY_STEP`・`INTERP_METHOD`・`W_MAX`・`W_MIN`）を値を変えずに冒頭へ移した。`pkCentroid_interp2_1cycle.m` の `PREV_RESULT_PATH` は `experiments/2026-0731/cycleResult_intpD_2026-0731.mat`、`photoshop_localMax_1cycle.m` は `WidthThresh=NaN` と `ScriptName="photoshop_localMax_1cycle"`（Q5）。自動追跡の3本の `dateNotSet` の確認は消した |
| ほかの実験のスクリプト（15本） | `bilateral/` の5本、`darkness3d.m`、評価スクリプト4本、`evaluation/stylus/sound_from_stylus.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`pkCentroid_interp2.m`、`pkCentroid_resample.m`、`progress/showPhotoshopGrooveExtraction.m` | `plan.md` 4.4.2 の表の実験名・説明の既定値で `runConditions`・`resultDir` を呼ぶ。`pkCentroidAndLocalMax_resample_1cycle.m` の途中の `date = "0710"; dir = mkdirFromDate(...)` の2か所は消した。評価スクリプト2本（`compareTrackingToManual.m`・`compareHistToTracking.m`）は、読み込みの日付の確認を `"YYYY-MMDD"` にし、確認する日付から `OUT_DATE` を外した。読み込みの日付とファイル名は新しい名前にした |
| 図のスクリプト（32本） | `scripts/paper/202609asj/` の13本、`scripts/slides/202609asj/` の11本、`scripts/progress/` の8本 | 保存先の4行を `figureDir` の1行にした。読み込みの日付を `"2026-0731"` の形にした。進捗報告用の8本と `compareWidthThresh.m` は `DATE_MMDD`（`DATA_MMDD`）`= extractAfter(DATE, "-")` を作り、図の名前とタイトルだけに使う |
| 対応表 | `scripts/migration/resultsMapping.csv`（新規） | `mapping-draft.md` 2〜4章の今の案（推奨）をそのまま書いた。`results` の段階 57 行、`experiments` の段階 22 行。スライド用の図（`results/figures/slides/202609asj/`）の行は入れていない |
| `.gitignore` | `.gitignore` | issue の7行の規則にし、2回あった `# editor`・`/.vscode` を1つにした |
| README | `README.md` | ディレクトリ構成（スクリプトと図とで階層の順が逆になること）、`scripts/` の一覧の出力先、「1周分の実験結果の保存」の例と `experiments/` の名前の説明、「基本的な使用方法」、新しい小節「対応表（移す前の置き場所）」。承認A の「`runInfo.json` の項目」の表と「実験名の一覧」は変えていない |
| ほかの文書 | `CLAUDE.md`（48〜49行）、`docs/rules/figures.md`・`data.md`・`coding.md`・`evaluation.md`、`docs/refactoring/common-functions.md`（F1・H1・例のパス）、`docs/staged-development.md`（2章の表・5.5・5.6）、`docs/issues/README.md`、`.claude/agents/` の3つ、`.claude/skills/` の2つ、`.github/ISSUE_TEMPLATE/figure.md` | 出力先を実行フォルダと `figureDir` に、データの日付を `YYYY-MMDD` にした。`figures.md` に、`DATE_MMDD` の決まり、階層の順が逆になること、#28 の例外の記録（図の置き場所だけを移したこと）を書いた |

## 3. 計画との違い

どれも、出力の数値と cycleResult の形には影響しない。計画の書き方（`runConditions` に何を渡すかを実装担当が決める、4.4.2 の規則）の範囲で決めた細部も含めて書く。

1. **`darkness3d.m` と `showPhotoshopGrooveExtraction.m` では、定数を `runConditions` の前へ移した。** 値と名前は変えていない。
   - `darkness3d.m` は、リサンプル・内挿の定数（`p_rsmpl`・`q_rsmpl`・`step`・`INTERP_METHOD`）が、最初の図を保存した後で決まっていた。`plan.md` 8章 Q3 の背景のとおり `Upsampling=["origD","rsmplD","intpD"]` を渡すには、`runConditions` が `PRsmpl` などを求める（無いと `runConditions:missingArgument`）。そのため、4つを `D_THRESH` の直後へ移した。
   - `showPhotoshopGrooveExtraction.m` は、`D_THRESH`・`WIDTH_THRESH` が、図1を保存した後で決まっていた。2つを保存先の前へ移し、元の場所には、移したことを書いた1行のコメントを置いた。
   - 計画の「置き換える所」には、この移動が書かれていない。
2. **評価スクリプト2本では、説明の変数を `RUN_LABEL` にした。** `compareInclBoundToExclBound.m`・`compareWidthThresh.m` は、図の表記の struct に `LABEL` の名前をすでに使っているためである。ほかの21本は `LABEL` のままにした。
3. **`compareInclBoundToExclBound.m` に、読むファイルを `InputFiles` に渡すための4行（`checkFiles`）を足した。** 照らす cycleResult（`CHECK_RESULT_FILE`）が `""` のときは何も渡さないようにするためである。
4. **評価スクリプト4本の `runConditions` には、しきい値を `Other` に、`th` で始まる camelCase のキーで渡した。** 例：`TH.E1_RMSE_MAX.centroid` は `thE1RmseMaxCentroid`。`Other` の値に struct を入れられないので、入れ子を1段にほどいた。計画の試行の値（`PLAN.*`・`EXPECTED_*`）は、条件ではなく答え合わせの値なので渡していない。`Images` は、評価スクリプトでは読んだ cycleResult の中にあるので渡していない（`compareWidthThresh.m`・`compareTrackingToManual.m`・`compareHistToTracking.m` は `resultDir` の時点では画像の名前を持っていない）。
5. **`Region` の行・列の範囲は、範囲の両端ではなく、定数の値（すべての番号の一覧）をそのまま渡した。** `bilateral8x_centroid.m` の `ORI_ROWS`・`ORI_COLS`（200個ずつ）、`darkness3d.m` の `heightIdx`・`widthIdx`（100個ずつ）、`showPhotoshopGrooveExtraction.m` の `ROW_RANGE`・`COL_RANGE`（32個ずつ）である。キーを定数名の camelCase にする決まり（README の表）に合わせるためである。その代わり、`runInfo.json` は長くなる（`PrettyPrint` で1行に1つ書くため）。
6. **`sound_from_stylus.m` は `runConditions()`（引数なし）にし、`InputFiles` も渡していない。** 動かない6本の規則（冒頭にある定数だけを渡す）で、このスクリプトには冒頭の定数が無いためである。
7. **スクリプトの説明のコメントのうち、古い置き場所を書いた行も直した。** `bilateral/` の5本の「出力（results/0820/bilateral/ori/）」など、自動追跡の3本の「results/<日付>/ に保存する」、`grooveOnImageManualAndTrack.m` のスライド用の図のパス、`wideBottomOutlierWidthThresh.m` の `results/1118/` の2か所である。`cycleConditions` の上にある「`NaN` を渡す」という説明は、新しい呼び方では `cycleConditions` が `NaN` にするので、そう書き直した。
   - `wideBottomOutlierWidthThresh.m` の2か所は、対応表の今の案の行き先 `results/grooveBottomDetection/2026-1118_evaluation/` にした。承認B で説明の語が変われば、ここも直す必要がある（6章）。
8. **README と文書に、計画の項目のほかに次を書いた。**
   - README の「1周分の実験結果の保存」に、`experiments/` の名前が `YYYY-MMDD` になったことと、改名の前のファイルの `conditions.date` は4桁のまま残ることの2文を足した。
   - README と `cycleResultPath` の説明の「移行前の `results/<日付>/` も探す」を、「移行前の置き場所（`results/` の直下の日付のフォルダ）も探す」と書き直した。評価の検索4（`criteria.md` 5章）で「要確認」の行を増やさないためである。
   - `common-functions.md` の F1・H1 の先頭に、#28 で作った・受け持つようになったことを書いた「状態」の行を足した。F1 の仕様は、作った `figureDir` に合わせて書き直した。

## 4. 確認の結果

### checkcode

変えた `.m` 55個すべてに `checkcode` をかけ、変える前（同じファイルの、書き換えの前の版。`temp/28-impl/checkcodeBefore.csv`）と比べた。代表の5本（`pkCentroid_1cycle.m`・`grooveTrack_Ncycle.m`・`compareWidthThresh.m`・`darkness3d.m`・`wideBottomOutlierWidthThresh.m`）は `mcp__matlab__check_matlab_code` でも確かめ、どれも 0 件だった。

| ファイル | 変える前 | 変えた後 | 内容 |
|---|---|---|---|
| `scripts/pkCentroid_resample.m` | 13 | 13 | 使っていない変数 |
| `scripts/pkCentroid_interp2.m` | 8 | 8 | 使っていない変数 |
| `scripts/progress/multiGrooveOnePhoto.m` | 2 | 2 | ループの中の `axes` |
| `scripts/bilateral/bilateralOri_centroid_1cycle.m` | 1 | 1 | ループの中で大きさが変わる変数 |
| `scripts/progress/showPhotoshopGrooveExtraction.m` | 1 | 1 | 使っていない関数 |
| `scripts/paper/202609asj/fig4_darkness3dComparison.m` | 1 | 1 | ループの中の `axes` |
| `scripts/slides/202609asj/darkness3dComparison.m` | 1 | 1 | ループの中の `axes` |
| ほかの48本 | 0 | 0 | — |
| 合計 | 27 | 27 | 増えたファイル 0 |

### runAllTests

- 346 件すべて通った（失敗 0、未完了 0）。件数は前半と同じで、後半でテストは足していない。
- 受け入れテスト `ResultLayoutAcceptanceTest` は 42/42 通った。

### migrateResults の試し

2026-11-25 に、`Phase="results"` と `Phase="experiments"` を `DryRun=true` だけで実行した。どちらもエラーも警告も出なかった。implCheck のフォルダを作った後にもう一度実行し、同じ表になることを確かめた。`count` は移すファイルの数である。

`Phase="results"`（57 行。`move` 45 行・658 ファイル、`delete` 12 行）：

| source | destination | status | count |
|---|---|---|---|
| `results/0710` | （deleteEmpty） | delete | 0 |
| `results/0721` | `results/upsampling/2026-0721` | move | 1 |
| `results/0724/audio_(4x_interp)*` | `results/upsampling/2026-0724_intpD` | move | 7 |
| `results/0724/audio_(centroid_method)(8x_resampled)*` | `results/upsampling/2026-0724_rsmplD` | move | 7 |
| `results/0724` | （deleteEmpty） | delete | 0 |
| `results/0731/audio_(8x_interp)_*` | `results/upsampling/2026-0731_intpD` | move | 6 |
| `results/0731/audio_(*)(original)*` | `results/upsampling/2026-0731_origD` | move | 14 |
| `results/0731/audio_(*)(8x_resampled)*` | `results/upsampling/2026-0731_rsmplD` | move | 14 |
| `results/0731/audio_(8x_interp)(*` | `results/upsampling/2026-0731_intpD_2` | move | 14 |
| `results/0731` | （deleteEmpty） | delete | 0 |
| `results/0802/audio_(photoshop-localMax)*` | `results/photoshopUpscaling/2026-0802_localMax` | move | 7 |
| `results/0802/audio_(photoshop-centroid)*` | `results/photoshopUpscaling/2026-0802_centroid` | move | 7 |
| `results/0802` | （deleteEmpty） | delete | 0 |
| `results/0807` | `results/upsampling/2026-0807_rsmplD` | move | 14 |
| `results/0817` | `results/photoshopUpscaling/2026-0817` | move | 5 |
| `results/0820/bilateral/ori` | `results/bilateralFilter/2026-0820_ori` | move | 13 |
| `results/0820/bilateral/oriRsmpl` | `results/bilateralFilter/2026-0820_oriRsmpl` | move | 13 |
| `results/0820/bilateral/oriIntp` | `results/bilateralFilter/2026-0820_oriIntp` | move | 13 |
| `results/0820/bilateral/photoshop8x` | `results/bilateralFilter/2026-0820_photoshop8x` | move | 13 |
| `results/0820` | （deleteEmpty） | delete | 0 |
| `results/0831/digitalNeedle` | `results/digitalNeedle/2026-0831` | move | 2 |
| `results/0831` | （deleteEmpty） | delete | 0 |
| `results/0924/bilateral1cycle` | `results/bilateralFilter/2026-0924_1cycle` | move | 36 |
| `results/0924` | （deleteEmpty） | delete | 0 |
| `results/1013` | `results/grooveTracking/2026-1013` | move | 22 |
| `results/1014/audio_(*)(original).wav` | `results/grooveTracking/2026-1014_manual` | move | 2 |
| `results/1014/audio_(*)(original)_*` | `results/grooveTracking/2026-1014_manual` | move | 12 |
| `results/1014/audio_(*)(original)(tracking)*` | `results/grooveTracking/2026-1014_track` | move | 14 |
| `results/1014/grooveTrack_img*` | `results/grooveTracking/2026-1014_track` | move | 8 |
| `results/1014/evalTrack_*` | `results/grooveTracking/2026-1014_evaluation` | move | 24 |
| `results/1014` | （deleteEmpty） | delete | 0 |
| `results/1022` | `results/grooveTracking/2026-1022` | move | 22 |
| `results/1026` | `results/grooveTracking/2026-1026` | move | 22 |
| `results/1028/audio_(*)(original)(hist_5_cycles)*` | `results/multiGroove/2026-1028_hist5` | move | 14 |
| `results/1028/grooveHist_*` | `results/multiGroove/2026-1028_hist5` | move | 16 |
| `results/1028/audio_(*)(original)(tracking_5_cycles)*` | `results/multiGroove/2026-1028_track5` | move | 14 |
| `results/1028/grooveTrackN_*` | `results/multiGroove/2026-1028_track5` | move | 8 |
| `results/1028/audio_(*)(original)(tracking)*` | `results/multiGroove/2026-1028_track` | move | 14 |
| `results/1028/grooveTrack_img*` | `results/multiGroove/2026-1028_track` | move | 8 |
| `results/1028` | （deleteEmpty） | delete | 0 |
| `results/1104/audio_(*)(original)(tracking_5_cycles)*` | `results/multiGroove/2026-1104_track5` | move | 14 |
| `results/1104/grooveTrackN_*` | `results/multiGroove/2026-1104_track5` | move | 8 |
| `results/1104/audio_(*)(original)(hist_5_cycles)*` | `results/multiGroove/2026-1104_hist5` | move | 14 |
| `results/1104/grooveHist_*` | `results/multiGroove/2026-1104_hist5` | move | 16 |
| `results/1104/evalMulti_*` | `results/multiGroove/2026-1104_evaluation` | move | 14 |
| `results/1104` | （deleteEmpty） | delete | 0 |
| `results/1110` | `results/grooveTracking/2026-1110` | move | 2 |
| `results/1111` | `results/grooveBottomDetection/2026-1111_exclBoundVsInclBound` | move | 5 |
| `results/1118/audio_(*)(original)(tracking)*` | `results/grooveBottomDetection/2026-1118_track` | move | 14 |
| `results/1118/audio_(*)(original)(hist_5_cycles)*` | `results/grooveBottomDetection/2026-1118_hist5` | move | 14 |
| `results/1118/audio_(*)(original)(tracking_5_cycles)*` | `results/grooveBottomDetection/2026-1118_track5` | move | 14 |
| `results/1118/evalWidthThresh_*` | `results/grooveBottomDetection/2026-1118_evaluation` | move | 6 |
| `results/1118/grooveOnImage_*` | `results/grooveBottomDetection/2026-1118_evaluation` | move | 54 |
| `results/1118/waveform_*` | `results/grooveBottomDetection/2026-1118_evaluation` | move | 42 |
| `results/1118` | （deleteEmpty） | delete | 0 |
| `results/figures/paper/202609asj` | `results/figures/202609asj/paper` | move | 55 |
| `results/figures/paper` | （deleteEmpty） | delete | 0 |

`Phase="experiments"`（22 行。`move` 12 行・12 ファイル、`delete` 10 行）：

| source | destination | status | count |
|---|---|---|---|
| `experiments/0731/cycleResult_intpD_0731.mat` | `experiments/2026-0731/cycleResult_intpD_2026-0731.mat` | move | 1 |
| `experiments/0731/cycleResult_origD_0731.mat` | `experiments/2026-0731/cycleResult_origD_2026-0731.mat` | move | 1 |
| `experiments/0731/cycleResult_rsmplD_0731.mat` | `experiments/2026-0731/cycleResult_rsmplD_2026-0731.mat` | move | 1 |
| `experiments/0731` | （deleteEmpty） | delete | 0 |
| `experiments/0802/cycleResult_origD_0802.mat` | `experiments/2026-0802/cycleResult_origD_2026-0802.mat` | move | 1 |
| `experiments/0802` | （deleteEmpty） | delete | 0 |
| `experiments/0807/cycleResult_rsmplD_0807.mat` | `experiments/2026-0807/cycleResult_rsmplD_2026-0807.mat` | move | 1 |
| `experiments/0807` | （deleteEmpty） | delete | 0 |
| `experiments/0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_0831.mat` | `experiments/2026-0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_2026-0831.mat` | move | 1 |
| `experiments/0831` | （deleteEmpty） | delete | 0 |
| `experiments/1013/cycleResult_origD_track_1013.mat` | `experiments/2026-1013/cycleResult_origD_track_2026-1013.mat` | move | 1 |
| `experiments/1013` | （deleteEmpty） | delete | 0 |
| `experiments/1014/cycleResult_origD_1014.mat` | `experiments/2026-1014/cycleResult_origD_2026-1014.mat` | move | 1 |
| `experiments/1014/cycleResult_origD_track_1014.mat` | `experiments/2026-1014/cycleResult_origD_track_2026-1014.mat` | move | 1 |
| `experiments/1014` | （deleteEmpty） | delete | 0 |
| `experiments/1022/cycleResult_origD_track_1022.mat` | `experiments/2026-1022/cycleResult_origD_track_2026-1022.mat` | move | 1 |
| `experiments/1022` | （deleteEmpty） | delete | 0 |
| `experiments/1104/cycleResult_origD_hist5_1104.mat` | `experiments/2026-1104/cycleResult_origD_hist5_2026-1104.mat` | move | 1 |
| `experiments/1104/cycleResult_origD_track5_1104.mat` | `experiments/2026-1104/cycleResult_origD_track5_2026-1104.mat` | move | 1 |
| `experiments/1104` | （deleteEmpty） | delete | 0 |
| `experiments/1026` | （deleteEmpty） | delete | 0 |
| `experiments/1110` | （deleteEmpty） | delete | 0 |

`mapping-draft.md` との照合：

- 行き先のフォルダごとの数は、`mapping-draft.md` 2章の「数」の列とすべて同じだった（例：`2026-1014_manual` は 2＋12＝14、`2026-1118_evaluation` は 6＋54＋42＝102）。
- 評価スクリプトと同じ求め方（対応表の行を上から当てはめ、最後にスライド用の図の `git mv` を当てはめる）で、移す前の記録 `manifestBeforeMigration.csv`（817個）の移し先を求めた。移るのは、日付のフォルダ 603、原稿用 55、スライド用 52、`experiments/`（archive 以外）12 で、進捗報告用 92 と `experiments/archive/` 3 は動かない。古い日付のフォルダに残るファイルは 0 個だった（criteria.md の P8 と同じ数）。

### 実データでの確認（手順18）

どちらも、`temp/28-impl/` のコピーで、日付と説明と読むパスの行だけを変えて実行した。`experiments/` はまだ改名していないので、読むパスは古い名前にした。`ginput` は使っていない。`experiments/` と `data/` には何も作らず、上書きも削除もしていない（実行の前後で `experiments/` の一覧が同じであることを確かめた）。

- (1) `bilateralOri_centroid_1cycle.m`
  - コピー：`temp/28-impl/bilateralOri_centroid_1cycle_implCheck1125.m`（`date = "2026-1125"`、`LABEL = "implCheck"`、`PREV_RESULT_PATH` を `experiments/0807/cycleResult_rsmplD_0807.mat` にした）。
  - 実行の前に、`results/bilateralFilter/` が無いことを確かめた。実行は約 33 秒で、警告は出なかった。
  - できたフォルダは `results/bilateralFilter/2026-1125_implCheck/` で、ファイルは **37 個** である。名前は `results/0924/bilateral1cycle/` の36個と同じで、`runInfo.json` が加わった。
  - wav 4つ（`audio_(centroid)(bilateral_<none・k03・k05・k09>).wav`）は、0924 の実行の wav と `isequal` だった（標本化周波数も 41729 Hz で同じ）。
  - `runInfo.json` の値は、スクリプトの定数と同じだった。`experiment` は `bilateralFilter`、`script` は `scripts/bilateral/bilateralOri_centroid_1cycle.m`、`inputs.images` は8枚、`inputs.files` は `experiments/0807/cycleResult_rsmplD_0807.mat` である。`conditions` は、`segmentation` が 8・10・20、`bilateral` が `[3,5,9]`・`[0.5,1,2]`・650.25、`upsampling.kind` が `["origD"]`、`grooveBottom` が `["centroid"]`・0.6・8、`grooveSelection` が `manual`・`replayFrom`・`manual` 150・3・5・8 である。
  - `meta.git` は `commit` が `2416ee2`、`dirty` が `true` だった。書き換えをコミットする前に実行したためである（評価の E1 では `false` になるはず）。先頭のバイトは `{` で、BOM は無かった。
- (2) `pkCentroid_1cycle.m`
  - コピー：`temp/28-impl/pkCentroid_1cycle_implCheck1125.m`（`EXPERIMENT_NAME = "grooveTracking"`、`date = "2026-1125"`、`LABEL = "implCheck"`、`PREV_RESULT_PATH` を `experiments/1014/cycleResult_origD_1014.mat`、`experimentDir(...,Create=false)`）。
  - `saveCycleResult` の行は外し、比べる値（`ycoords_cnt`・`ycoords_max`・`cond`）だけを `temp/28-impl/check_pkCentroid_1cycle_1125.mat` に書き出した。
  - 実行は約 16 秒だった。`experiments/2026-1125/` は作られていない。
  - できたフォルダは `results/grooveTracking/2026-1125_implCheck/` で、ファイルは **15 個**（図・wav 14個と `runInfo.json`）である。
  - 1014 の結果（`cycleResult_origD_1014.mat`）との比較
    - `ycoords_cnt` と `centroid.ycoords`、`ycoords_max` と `localMax.ycoords` は、どちらも `isequal` だった。
    - `cond` と `conditions` は、`date`・`saveDir`・`experimentDir` を除いて `isequaln` で、フィールドの順も同じだった。
    - wav 2つは、`results/1014/` の手動選択の wav と `isequal` だった。
  - `runInfo.json` の値（`lMask` 20、`dThresh` 0.6、`widthThresh` 8、`manual` 150・3・5・8、`upsampling.kind` `["origD"]`、`inputs.images` 8枚、`inputs.files`）は、`cond` と同じだった。
  - 実行の記録に出た警告は1つである。`MATLAB:audiovideo:audiowrite:dataClipped`（「ファイルの書き込みに際しデータが切り捨てられました」）が、局所的最大値法の wav を書く `origMaxAudio.saveAudio(dir)` で出た。振幅が ±1 を超えたサンプルがあるためで、wav が 1014 の実行のものと同じなので、書き換えの前からある動きである。

### そのほかの確認

- 書き換えた実験のスクリプトのうち20本を、`date = "YYYY-MMDD"` のまま実行した（`temp/28-impl/checkScriptsReachResultDir.m`）。20本とも、`resultDir` の前までがエラーなく動き、`resultDir:dateNotSet` で止まった。`results/`・`experiments/` には何もできなかった（ファイルの一覧が前後で同じ）。
  - 読み込みの日付の確認で先に止まる `compareTrackingToManual.m`・`compareHistToTracking.m` は、パラメータの節を実行してから `runConditions` の文だけを実行し、`jsonencode` できることを確かめた。
  - `sound_from_stylus.m` は、`resultDir` の前に `data/stylus_playback/` へ wav を書くので、実行していない（6章の「気づいた点」）。
- 評価スクリプトの `temp/` のコピー（`temp/28-impl/checkResultsLayout_implCheck1125.m`。`BASE_COMMIT = "0e60754"`、SHA-256 と移行の試しは切った）を、読み取りだけで実行した。表示は `temp/28-impl/checkResultsLayout_implCheck1125_out.txt` にある。移行とコミットの前なので、移行に関わる項目（P5・Q1〜Q5・Q8・D3）は満たさない（正常）。後半の書き換えに関わる項目は次のとおりだった。
  - P3（図のスクリプト32本）、P6（README）、P7（文書と `.gitignore`）、Q6a（検索1〜3と補い）は満たした。
  - P1・P2・Q7 は、書き換えた23本・8本はすべて満たした。ただし、評価スクリプト自身が対象に入るので、それぞれ「1本が外れ」となり、判定は「満たさない」になる（6章の Q1）。
  - Q6b の「要確認」は2行だった。README の `mkdirFromDate` の説明（75行）と、`figures.md` の #28 の例外の記録（251行）である。どちらも `criteria.md` 5章の「残ってよい」の例に当たる。
  - Q9 の一覧は2文だった。`compareTrackingToManual.m` の判定の表の行の説明（`"手動の再現の p1/p2 が intpD_" + GT_DATE + " と同じ"` など）で、図の名前・タイトルではない。新しい名前では `intpD_2026-0731` と表示される。
  - Q8 で「無い」とされた46個は、すべて対応表の `experiments` の段階の行き先（改名の後の名前）だった。改名の後には、すべてあるはずである。
- `.gitignore` は、`criteria.md` 6章の14の例を `git check-ignore -q --no-index` で確かめ、すべて期待どおり（9つが無視、5つが追跡）だった。`git ls-files results` は 144 のままである。
- 古い書き方の検索（評価の検索1〜4と同じ式）で、`scripts/` に当たる行は 0 行である。検索4で、許される場所と README の「対応表」の節のほかに当たるのは、上の Q6b の2行だけである。

## 5. 評価担当への申し送り

- 作ったデータ
  - `results/bilateralFilter/2026-1125_implCheck/`（37 ファイル）と `results/grooveTracking/2026-1125_implCheck/`（15 ファイル）を残してある。どちらも git の管理外である。残すか消すかは、main が承認B でユーザーに確かめる。
  - 残した場合、評価スクリプトの U1 の一覧に、この2つが出る。名前は Q4 の規則（`YYYY-MMDD_説明`）に合う。Q2 の行き先のフォルダではないので、Q2 には数えられない。E1 の `2026-1125_1cycle`・E3 の `_check` とも名前がぶつからない（評価を 2026-11-25 に行うときも同じ）。
  - `temp/28-impl/` に、使ったコピーと出力を残した：`bilateralOri_centroid_1cycle_implCheck1125.m`、`pkCentroid_1cycle_implCheck1125.m`、`check_pkCentroid_1cycle_1125.mat`、`checkScriptsReachResultDir.m`、`checkResultsLayout_implCheck1125.m` とその出力 `_out.txt`、`checkcodeBefore.csv`・`checkcodeAfter.csv`、試しの表 `dryrun_results.mat`・`dryrun_experiments.mat`、対象の55本の一覧 `targetScripts.txt`。
- 評価スクリプトの P1・P2・Q7 は、6章の Q1 の不具合で「満たさない」になる。書き換えた23本だけを見れば満たしている（4章の「そのほかの確認」）。
- 対応表の行のうち、承認B で決まる M1〜M5 と説明に関わる行は、6章の Q2 にまとめた。承認B で案が変われば、CSV、README の「対応表」の節、`wideBottomOutlierWidthThresh.m` のコメントの3か所を直す必要がある。評価スクリプトの `E1_REF_DIR`（`results/bilateralFilter/2026-0924_1cycle`）も、名前が変わるときは直す。
- 評価の E1（`bilateralOri_centroid_1cycle.m` のコピー）は、約 33 秒で終わる。E3（`pkCentroid_1cycle.m`）は約 16 秒で、局所的最大値法の wav を書くときに `MATLAB:audiovideo:audiowrite:dataClipped` の警告が出る（書き換えの前からある）。
- 書き換えた後の図のスクリプトは、スライド用・原稿用の図を `results/figures/202609asj/{slides,paper}/` に保存する。main の `git mv` と移行の前に図のスクリプトを実行すると、新しい置き場所に図ができる（古い場所の図は上書きしない）。

## 6. 未決事項・仮定

### 未決事項

- **Q1 評価スクリプトが自分自身を「実験のスクリプト」「1周分のスクリプト」に数える不具合の扱い**
  - 背景：`checkResultsLayout.m` の `baseGrepFiles` は、基準のコミットの `scripts/`（archive を除く）から `mkdirFromDate`・`cycleConditions(` を含むファイルを探す。基準のコミット `0e60754` では、`scripts/evaluation/resultsLayout/checkResultsLayout.m` 自身がこの2つの文字列を含むので、対象が 24 本・9 本になる。そのため、P1 は「1 本（対象 24 本）」、P2 は「1 本（対象 9 本）」、Q7 は「1 本」の外れになり、3つとも「満たさない」と出る。外れの1本は、どれも評価スクリプト自身である。私は評価スクリプトを変えていない。
  - (a) 評価担当（A）か main が、`baseGrepFiles` の検索から `scripts/evaluation/resultsLayout/` を除く（`":!scripts/evaluation/resultsLayout/*"` を足す）。判定の基準は変わらず、数え方の誤りだけが直る。
  - (b) 評価スクリプトは変えず、評価担当（B）が、外れの1本が評価スクリプト自身であることを確かめて、P1・P2・Q7 を満たすと判断する。`criteria.md` の P1 の基準の「23 本」と表の数（24 本）が食い違ったまま残る。
  - 推奨：(a)。評価スクリプトの不具合で、判定に人の解釈を挟まずに済むため。
- **Q2 対応表の未決事項（M1〜M5）と説明に関わる CSV の行**（承認B で決める。CSV は `mapping-draft.md` の今の案（推奨）どおりに作った）
  - M1（実行フォルダの日付を、今のフォルダの日付に年を足したものにする）：`results` の段階の `move` の行すべての行き先に関わる。特に、ファイルの時刻とフォルダの日付が違う行である。`results/0721`（時刻は 07-23）、`results/0731/audio_(8x_interp)(*`（08-20）、`results/0802/audio_(photoshop-centroid)*`（08-03）、`results/0817`（08-18）、`results/0820/bilateral/` の4行（09-01・09-23）。
  - M2（空の `experiments/1026/`・`1110/` を消す）：`experiments,deleteEmpty,experiments/1026` と `experiments/1110` の2行。
  - M3（`0831/digitalNeedle/` を移し、ファイル名の日付も変える）：`results,dir,results/0831/digitalNeedle` の行、`experiments,file,experiments/0831/digitalNeedle/...` の行、`results/0831`・`experiments/0831` の `deleteEmpty` の2行。
  - M4（`results/1111/README.md` をそのまま移す）：`results,dir,results/1111` の行。
  - M5（`results/1110/` を移す）：`results,dir,results/1110` の行。
  - 説明の語（M6 の説明の部分）：説明を付けた行き先のすべて（`_intpD`・`_rsmplD`・`_origD`・`_intpD_2`・`_localMax`・`_centroid`・`_ori` など・`_1cycle`・`_manual`・`_track`・`_evaluation`・`_hist5`・`_track5`・`_exclBoundVsInclBound`）。
  - どれかを変えるときは、CSV、README の「対応表」の節、`wideBottomOutlierWidthThresh.m` のコメント（`2026-1118_evaluation`）を直す。

### 仮定

- 仮定：`.claude/agents/`・`.claude/skills/`・`CLAUDE.md` の書き換えは、`plan.md` 2.1 の (6) と issue の「対象ファイル」に挙がっているので、行ってよい。書き換えたのは、出力先とデータの日付の書き方だけである。
- 仮定：README の「対応表」の節は、移行が終わった後の状態（過去形）で書いてよい。PR をマージする時点では移行が終わっているためである。
- 仮定：`Region` の行・列の範囲は、定数の値をそのまま（すべての番号の一覧で）書いてよい（3章の5）。

### 気づいた点

- `sound_from_stylus.m`（動かない6本の1つ）は、`resultDir` の前の行で `data/stylus_playback/` に wav を書き出す（`StylusPlayback.saveAudio(proj.RootFolder+"\data\stylus_playback\")`）。書き換えの前からある動きで、計画の範囲外なので変えていない。このスクリプトを実行すると `data/` に書き込むので、実行しないほうがよい。
- `pkCentroidAndLocalMax_resample_1cycle.m`（動かない6本の1つ）は、`audioread(proj.RootFolder+"\results\0615\...")` で、無いフォルダ `results/0615/` を読む。区切りが `\` なので、評価の検索の式には当たらない。計画の「機械的に置き換える」範囲の外なので、変えていない。
- 1周分のスクリプトのいくつかには、`% dir = "C:\Users\owner\...\data\"+date+"\";` という古いコメントが残っている。出力先や日付の行ではないので、変えていない。
- `compareWidthThresh.m`・`wideBottomOutlierWidthThresh.m` の期待する図の名前（`..._1104_img5...` など）は4桁の日付のままで、`DATA_MMDD` で作る名前と合う。
- 前半の報告の気づいた点（`src/loadCycleResult.m` の例の `"0731"`）は、依頼どおり変えていない。
