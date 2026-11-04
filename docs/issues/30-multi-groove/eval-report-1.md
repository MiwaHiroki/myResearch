- 段階: 評価
- 作成者: evaluator（モードB、1回目）
- 作成日: 2026-11-04
- 入力: issue #30、[`./README.md`](./README.md)（決定事項）、[`./plan.md`](./plan.md)（承認済み）、[`./criteria.md`](./criteria.md)（承認済み）、[`./impl-report-1.md`](./impl-report-1.md)、メインからの依頼文（評価1回目）
- 状態: 下書き

# #30 評価レポート（1回目）

## 1. 判定：**ユーザー確認待ち**

- 前提 P1〜P4、テスト T1・T2、数値の項目（計画 11・品質 18・整合 12、E7a〜E7c を含む）を**すべて満たした**。不合格の項目は無い。
- 残っているのは、ユーザーが判断する項目 U1（本実装の部分）・U2・U3（6章）。U1 の正解の部分（`results/1104/grooveTrackN_img1〜8.png` に飛び移りが無いこと）は、2026-11-04 にユーザーが確かめ済み（README の決定）。
- 本実装は計画の試行（plan.md 付録 A.5）と同じ値になった。2〜5本目の64本（8枚×4本×2手法）のうち63本は正解と完全に一致し、残りの1本（重心法・写真8・5本目）も1列（x=2314）だけの違い（RMSE 0.0177 px・相関 0.9981）だった。
- ユーザーのクリック（正解の `seedsY`）は、計画の試行の `seedsY` から ±3.87 px 以内だった。そのため P5 は 80/80 で、「計画」の確認から除いた (i,j) は無い。

## 2. 実行したこと

| 順 | 内容 | 結果 |
|---|---|---|
| 1 | `git status --porcelain` | 空（ブランチ `claude/multi-groove`、HEAD `569e327`） |
| 2 | `cd test; results = runAllTests;`（T1） | 217件：通過 217・失敗 0・未完了 0（`MultiGrooveAcceptanceTest` 41/41） |
| 3 | `checkcode`（T2） | 15ファイルで警告 0（4.2） |
| 4 | E7a〜E7c（基準 `2d06a8a`） | すべて満たす（4.4） |
| 5 | 本実装のデータの作成：`temp/grooveHist_Ncycle_eval1104.m`（2026-11-04 15:28、約40秒） | `experiments/1104/cycleResult_origD_hist5_1104.mat` |
| 6 | 評価スクリプト：`temp/compareHistToTracking_eval1104.m`（2026-11-04 15:30、約43秒） | 数値の項目 46/46。`results/1104/evalMulti_*` |
| 7 | 評価担当による独立の確認（MATLAB で直接） | 評価スクリプトの値と一致（4.3 の末尾） |

### 2.1 `temp/` のコピー（消さずに残した）

| コピー | 元 | 変えた行（ほかは同じ。改行コード CRLF も同じ） |
|---|---|---|
| `temp/grooveHist_Ncycle_eval1104.m` | `scripts/grooveHist_Ncycle.m` | L50 `date = "1104";`、L54 `PREV_RESULT_PATH = fullfile(proj.RootFolder,"experiments","1104","cycleResult_origD_track5_1104.mat");` |
| `temp/compareHistToTracking_eval1104.m` | `scripts/evaluation/multiGroove/compareHistToTracking.m` | L29 `GT_DATE = "1104";`、L31 `HIST_DATE = "1104";`、L33 `OUT_DATE = "1104";`（`GT_FILE`・`HIST_FILE` は空のまま＝既定の名前） |

- 評価スクリプトに不具合は無く、直していない。

### 2.2 使ったデータと `meta`

| 呼び名 | ファイル | `meta.gitCommit` | `meta.gitDirty` | 保存 | `scriptName` |
|---|---|---|---|---|---|
| 正解（D1） | `experiments/1104/cycleResult_origD_track5_1104.mat` | `b9c5db0` | false | 2026/11/04 15:16:58 | `grooveTrack_Ncycle` |
| 本実装（D2） | `experiments/1104/cycleResult_origD_hist5_1104.mat`（今回作成。52.6 MB） | `569e327` | false | 2026/11/04 15:28:54 | `grooveHist_Ncycle` |
| #25 の1周分 | `experiments/1014/cycleResult_origD_track_1014.mat`（読み取りのみ） | — | — | — | — |

- `b9c5db0`・`569e327` はどちらも実装のコミット `560e085` の子孫で、`git diff --name-status 560e085 569e327 -- src scripts test` は空（その後のコミットは docs とマージだけ）。
- `experiments/1104/` には上の2ファイルだけがあり、`_2` 付きのファイルは無い。

### 2.3 実行ログの警告

| 実行 | 警告 |
|---|---|
| 本実装（`temp/grooveHist_Ncycle_eval1104.m`） | `MATLAB:audiovideo:audiowrite:dataClipped` の1件だけ（重心法の wav で ±1 を超えた32サンプルが切り捨て。plan.md Q3 で記録だけにすると決定済み）。`saveCycleResult:fileExists`・`trackGroove:longGap`・`findpeaks` の警告は出ていない |
| 評価スクリプト | なし（`lastwarn` も空） |

- 本実装の表示（写真ごとの山の中心・点が無かった列・同じ列の2点）は、4.3 の E1a・E3a の値と同じ。`fs = 41729 Hz`、±1 を超えたサンプル：重心法 32、局所的最大値法 0（全 160,495 サンプル）。

## 3. 作った出力

- `experiments/1104/cycleResult_origD_hist5_1104.mat`（plan.md 7.1 の2。issue で指示されたもの）
- `results/1104/`：本実装の `grooveHist_img1〜8.png`、`grooveHist_histogram_img1〜8.png`、`audio_(centroid_method)(original)(hist_5_cycles)` と `audio_(local_maximum_method)(original)(hist_5_cycles)` の `.wav`・`_amp`・`_fft`・`_stft`（`.fig`・`.png`）
- `results/1104/`：評価の `evalMulti_summary.csv`・`evalMulti_grooves.csv`・`evalMulti_cycles.csv`、`evalMulti_overlay_img1〜8.png`、`evalMulti_diff_centroid.png`・`evalMulti_diff_localMax.png`、`evalMulti_stft.png`
- 実行前に、これらと同じ名前のファイルが `results/1104/`・`experiments/1104/` に無いことを確かめた。既存のファイル（正解の出力）は上書きしていない。

## 4. 項目ごとの結果

### 4.1 前提

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| P1 | `gitDirty`・`gitCommit`・`_2` 付きのファイル | どちらも false、実装のコミット以後、`_2` なし | 正解 false（`b9c5db0`）、本実装 false（`569e327`）。どちらも `560e085` 以後で `src`・`scripts`・`test` の差分なし。`_2` なし | 満たす |
| P2a | 正解の経路の、中央値からのずれの最大 | < 13 px | 2.21 px（写真8・5本目・重心法） | 満たす |
| P2b | 正解の隣どうしの始点 `y0` の差（重心法）、`seedsY` の並び | ≥ 13 px、中央値の 1.5 倍以下、降順 | 25.1〜28.5 px、比 0.96〜1.04、降順 | 満たす |
| P3 | 正解の1周目と 1014 | 両手法とも `isequal` | true | 満たす |
| P4 | 本実装の `seeds` | `[1列目, 正解の1本目のクリックの y]` | 一致（8枚とも x=1、y は正解の `seeds(:,2)` と同じ） | 満たす |
| U1（正解） | `results/1104/grooveTrackN_img1〜8.png` | ユーザーが飛び移りなしと確認 | 2026-11-04 にユーザーが確認済み（README の決定） | 満たす |
| P5（参考） | 正解が計画の試行の `seedsY` からの追跡と同じ経路の (i,j) | 判定に使わない | 80/80（ユーザーのクリック − 計画の `seedsY` は −3.87〜+2.97 px） | — |

参考：ユーザーの1本目のクリックの y と 1014 の `seeds` の y の差は −2.46〜+2.33 px（同じ溝。P3 のとおり結果も同じ）。

### 4.2 テスト

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| T1 | `runAllTests` の失敗・未完了 | 0件 | 217件中、失敗 0・未完了 0（受け入れテスト 41/41） | 満たす |
| T2 | `checkcode` の警告 | 0件 | 0件：`src/` の `detrendTrackedShape.m`・`findGrooveCenters.m`・`extractGrooveBands.m`・`extractMultiGroove.m`・`cycleMethodResult.m`・`saveCycleResult.m`、`scripts/grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`、`test/unit/` の `FindGrooveCentersTest.m`・`ExtractGrooveBandsTest.m`・`ExtractMultiGrooveTest.m`・`DetrendTrackedShapeTest.m`・`CycleResultTest.m`（参考に `MultiGrooveAcceptanceTest.m`・`compareHistToTracking.m` も 0件） | 満たす |

### 4.3 実データでの数値の項目

| ID | 区分 | 指標 | しきい値 | 重心法 | 局所的最大値法 | 判定 |
|---|---|---|---|---|---|---|
| E1a | 計画 | `centers`（8×5）が plan.md A.5 と同じ | 一致 | 一致 | 一致（写真3・7の1本目が −0.5 も同じ） | 満たす |
| E1b | 品質 | \|山の中心 − 正解の中心\| < 溝の間隔の最小の半分 | すべての (i,j) | \|差\|の最大 0.500 px、余裕の最小 12.26 px（写真6・1本目） | 0.497 px、12.27 px（写真6・1本目） | 満たす |
| E1c | 品質 | 正解の同じ溝との相関 − 隣の溝との相関 | すべて正 | 差の最小 0.828（写真7・3本目）、隣との相関の最大 0.172 | 0.822（写真7・3本目）、0.178 | 満たす |
| E2a | 計画 | 2本目以降で正解と完全に一致（RMSE ≤ 1e-9） | 重心法 31本・局所的最大値法 32本がすべて | 31/31 | 32/32 | 満たす |
| E2b | 計画 | 重心法・写真8・5本目 | RMSE ≤ 0.02 px、相関 ≥ 0.995 | RMSE 0.01769、相関 0.9981 | （対象外） | 満たす（余裕は小さいが計画の試行と同じ値） |
| E2c | 品質 | 2本目以降の RMSE の最大 | ≤ 0.15 px | 0.0177（写真8・5本目） | 0 | 満たす |
| E2d | 品質 | 2本目以降の相関の最小 | ≥ 0.80 | 0.9981（写真8・5本目） | 1 | 満たす |
| E3a | 計画 | 帯の中に点が無かった列の数（8×5） | plan.md A.5 と一致 | 一致 | 一致 | 満たす |
| E3b | 計画 | 正解で採れて本実装で採れなかった列／その逆 | 0／重心法の写真8・5本目だけ1 | 0／1（写真8・5本目） | 0／0 | 満たす |
| E3c | 品質 | 点が無かった列の数の最大 | ≤ 20 列 | 16（写真5・5本目） | 16（写真5・5本目） | 満たす |
| E3d | 品質 | 最も長い連続欠損 | ≤ 40 px | 10 px（写真2・4本目） | 10 px（写真2・4本目） | 満たす |
| E3e | 品質 | 正解で採れて本実装で採れなかった列の最大 | ≤ 20 列 | 0 | 0 | 満たす |
| E4a | 計画 | 5周分の `y_comb`（全体） | 重心法 RMSE ≤ 0.004・相関 ≥ 0.9999、局所的最大値法は一致 | RMSE 0.002832、相関 0.999940 | RMSE 0（一致） | 満たす（余裕は小さいが計画の試行と同じ値） |
| E4b | 品質 | 相関（全体・周ごとの最小） | ≥ 0.90 | 全体 0.99994、周ごと [1 1 1 1 0.99976] | 全体 1、周ごと [1 1 1 1 1] | 満たす |
| E4c | 品質 | RMSE（全体・周ごとの最大） | ≤ 0.15 px | 全体 0.0028、周ごと [0 0 0 0 0.0063] | 全体 0、周ごと [0 0 0 0 0] | 満たす |
| E5 | 整合 | 本実装の1周目（`ycoords(:,1)`・`tracking.yAbs*`・`found*`）と正解 | `isequal` | true | true | 満たす |
| E6a | 整合 | 本実装の `grooveSelection`・`multiGroove`・`ycoords`・`conditions` の形と値 | plan.md 4.4 のとおり | true（`method="histogram"`、`ycoords` 80×5、`binWidth=1`・`tol=3`・`thHist`/`hPrl` は NaN など） | 同左 | 満たす |
| E6b | 整合 | 本実装：連結・振幅・`fs` | ≤ 1e-9、`fs = 41729` | 0、0、41729 | 0、0、41729 | 満たす |
| E6c | 整合 | 本実装：`ycoords` = `detrendTrackedShape(yAbs)` を分けたもの | ≤ 1e-9 | 0（両手法まとめて） | | 満たす |
| E6d | 整合 | 本実装：保存した `pts`・`seeds`・パラメータで再実行 | y・centers ≤ 1e-9、不一致 0 | y 0、found 0、centers 0、numDup 0（両手法まとめて） | | 満たす |
| E6e | 整合 | 正解の `grooveSelection`・`multiGroove` の形 | plan.md 4.2・4.4 のとおり | true | | 満たす |
| E6f | 整合 | 正解：連結・振幅・`fs` | ≤ 1e-9、`fs = 41729` | 0、0、41729 | 0、0、41729 | 満たす |
| E6g | 整合 | 正解：`ycoords` = `detrendTrackedShape(yAbs)` | ≤ 1e-9 | 0 | | 満たす |
| E6h | 整合 | 正解：保存した `seedsY` から `trackGroove` を再実行 | ≤ 1e-9、不一致 0 | y 0、found 0、y0 0 | | 満たす |
| E7d | 整合 | 1014 の `tracking.yAbs*` に今の `detrendTrackedShape` | 1014 の `ycoords` と `isequal`（8枚×2手法） | 違う写真 0 | | 満たす |

区分ごと：前提 5/5、計画 11/11、品質 18/18、整合 12/12（評価スクリプトの判定の表。T・E7a〜E7c はスクリプトの外で確かめた）。

**写真×溝ごと**（表の全体は `results/1104/evalMulti_grooves.csv`）

- 形状（9次デトレンド後、補間後の全列）：重心法は 40本中39本、局所的最大値法は 40本すべてが正解と `isequal`（1本目も含む）。違う1本は重心法・写真8・5本目で、デトレンド前の y（`multiGroove.yAbsCnt{8,5}`）は **x=2314 の1列だけ**違う（差 1.135 px）。その列は、本実装の帯が点を採り（`found=true`）、正解の追跡は採らなかった（`found=false`、補間）。plan.md 2.3 の10のとおり。
- 山の中心と正解の中心の差は、全 (i,j)・両手法で \|差\| ≤ 0.50005 px（`BIN_WIDTH/2` 程度。1本目は補正後の中心がビンの端 0 に来るため約 ±0.5）。
- 帯の中に点が無かった列の数（補間の前。両手法で同じ。1本目は追跡の欠損）：

  | 写真 | 1本目 | 2本目 | 3本目 | 4本目 | 5本目 |
  |---|---|---|---|---|---|
  | 1 | 0 | 0 | 0 | 4 | 0 |
  | 2 | 7 | 0 | 3 | 10 | 7 |
  | 3 | 6 | 6 | 2 | 2 | 0 |
  | 4 | 0 | 0 | 1 | 0 | 0 |
  | 5 | 0 | 0 | 3 | 3 | 16 |
  | 6 | 4 | 0 | 0 | 1 | 0 |
  | 7 | 0 | 2 | 0 | 3 | 0 |
  | 8 | 0 | 2 | 0 | 0 | 0 |

**周ごと**（`results/1104/evalMulti_cycles.csv`）：重心法は1〜4周目が RMSE 0・相関 1、5周目だけ RMSE 0.00633 px・相関 0.99976（上の1列による）。局所的最大値法は全周が一致。

**独立の確認**（評価スクリプトを通さず、MATLAB で直接）：セルごとの `isequal` の数（39/40・40/40）、違う列 x=2314 と `found` の向き、両者の `seeds`、wav（`fs = 41729`、160,495 サンプル、3.846 秒）、`y_comb` の長さ 160,495、`conditions` の値を確かめ、評価スクリプトの結果と一致した。

### 4.4 触らないもの（E7a〜E7c）

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| E7a | `experiments/` の既存のファイルの SHA-256 | criteria.md 4.3 の13件と同じ | 13件すべて同じ（`sha256sum` の出力と criteria.md の表を `diff` して差なし）。`experiments/1026/` は空のフォルダのまま。ほかに増えたのは `experiments/1104/` の正解（ユーザー作成）と本実装（今回作成）だけ | 満たす |
| E7b | `git diff --name-status 2d06a8a -- src scripts test` | plan.md 4.3 の新規・変更のファイルだけ | A：`scripts/grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`、`src/extractGrooveBands.m`・`extractMultiGroove.m`・`findGrooveCenters.m`、`test/unit/ExtractGrooveBandsTest.m`・`ExtractMultiGrooveTest.m`・`FindGrooveCentersTest.m`。M：`src/cycleMethodResult.m`・`detrendTrackedShape.m`・`saveCycleResult.m`、`test/unit/CycleResultTest.m`・`DetrendTrackedShapeTest.m`。「触らないもの」（`trackGroove.m` など、既存のスクリプト、`archive/`、`*AcceptanceTest.m`、`scripts/evaluation/`）は差分なし | 満たす |
| E7c | `git diff 2d06a8a -- src/saveCycleResult.m` | コメント行だけ | 2か所・変更した行はすべて `%` で始まるヘルプの行（`GrooveSelection` の説明に `multiGroove`、`result.centroid` の説明に N周分の形） | 満たす |

### 4.5 判定には使わず、報告だけするもの（criteria.md 4.4）

- 写真ごとの溝の間隔（正解の中心の差、重心法）：25.51〜28.37 px。写真の中ではほぼ一定。
- 両手法の `centers` の差：写真3・7の1本目だけ 1 px（ほかは 0）。
- ±1 を超えたサンプル：本実装 重心法 32・局所的最大値法 0（最大 1.291 / 1.000）、正解 31・0（最大 1.291 / 1.000）。
- 同じ列に2点以上あった列：0（両手法・全写真）。
- 正解の重心法と局所的最大値法の差（写真×溝ごと）：RMSE 0.233〜0.364 px、相関 0.025〜0.841。
- 実装担当の報告の 9-3（`grooveTrack_1cycle.m` の結果が 1014 と `isequal`）：impl-report-1.md 4章のとおり。今回の E7d（同じ趣旨）も満たした。

## 5. 不合格の項目

なし。

## 6. ユーザーに確かめてほしいこと（U1〜U3）

数値の項目はすべて満たしたが、次の3つはユーザーの判断が要る。本実装と正解は5周分でほぼ同じ（重心法 RMSE 0.0028 px、局所的最大値法は一致）なので、**U3 で聞く本実装の音は、正解の音とほぼ同じ**。そのため U3 では、手法の違いではなく、N周分のつなぎ方そのもの（周の順・周の境目）を確かめることになる。

| ID | 見るもの | 観点 |
|---|---|---|
| U1（本実装） | `results/1104/grooveHist_img1〜8.png`（本実装。5本の経路と始点の黄色の三角）、`results/1104/evalMulti_overlay_img1〜8.png`（写真を横に4つに分けたもの。本実装＝細い線、正解＝太い半透明の線、本実装の帯に点が無かった列＝青の×、始点＝黄色の三角。重心法） | 5本の経路が溝の底に沿い、隣の溝に飛び移っていないか。細い線（本実装）が太い線（正解）の中にあり、同じ5本を選んでいるか。唯一違う所は写真8・5本目（緑の線）の x=2314 の1列で、図ではほぼ見分けられない |
| U2 | `results/1104/grooveHist_histogram_img1〜8.png`（補正後の y のヒストグラム。赤の破線がしきい値、赤の丸が選んだ山） | 選んだ5つの山が、1本目（y≈0）から y の小さい側（図の上）へ続く5本の溝か。しきい値の線より上に、選ばれなかった山や、落ちた山が無いか。特に写真2：溝の間の偽の山が線より下にあるか（評価担当が数えた値：写真2の列の数 3999、しきい値 1199.7 点。選ばなかった山の最大は重心法 677 点（0.169 倍、y=−65.5）、局所的最大値法 351 点（0.088 倍）。選んだ5つの山は 2066〜3254 点（重心法）・2082〜2897 点（局所的最大値法）） |
| U3 | wav：本実装 `results/1104/audio_(centroid_method)(original)(hist_5_cycles).wav`・`audio_(local_maximum_method)(original)(hist_5_cycles).wav`（各 3.85 秒）。比べる相手：正解 `results/1104/audio_(centroid_method)(original)(tracking_5_cycles).wav`・`audio_(local_maximum_method)(original)(tracking_5_cycles).wav`、#25 の1周分 `results/1014/audio_(centroid_method)(original)(tracking).wav`・`audio_(local_maximum_method)(original)(tracking).wav`。スペクトログラム：`results/1104/audio_(centroid_method)(original)(hist_5_cycles)_stft.png`（局所的最大値法も同じ名前の形）、`results/1104/evalMulti_stft.png`（本実装と正解を並べたもの） | 周の境目（約 0.77・1.54・2.31・3.08 秒）で音（曲）がつながっているか。周の順が正しいか（数値では確かめられなかった。plan.md 2.3 の15）。写真の境目（約 0.096 秒ごと）のクリック音が、#25 の1周分より目立たないか |

参考：`results/1104/evalMulti_diff_centroid.png`・`evalMulti_diff_localMax.png`（写真×溝ごとの、本実装 − 正解の差）。重心法の写真8・5本目以外はすべて 0 の直線になる。

## 7. 気づいた点（判定には影響しない）

- 評価スクリプトの判定の表で、最大値が 0 の項目（E3e の「0（写真1・1本目）」、局所的最大値法の E2c・E2d の「（写真1・2本目）」）に出る場所は、全部同じ値のときに最初の要素を指しているだけで、意味は無い。数値と判定は正しい。
- MATLAB の `diary` は MCP 経由の実行の出力を残さなかったため、実行ログは MCP の出力から書き写した（警告は 2.3 のとおり）。
- criteria.md・受け入れテストに誤りは見つからなかった。
