- 段階: 評価
- 作成者: evaluator（モードB）
- 作成日: 2026-11-18
- 入力: issue #35（本文。コメントなし）、[`./README.md`](./README.md)（作業履歴の決定）、[`./plan-2.md`](./plan-2.md)（承認済み）、[`./criteria.md`](./criteria.md)（承認済み 2026-11-17。Q-a・Q-b はどちらも (a)）、[`./impl-report-1.md`](./impl-report-1.md)、メインからの依頼文（評価1回目、`OUT_DATE` = `1118`）
- 状態: 確定（2026-11-20、ユーザーが U1〜U4 を確認）

# #35 正規化した振幅が1付近の外れ値が、溝の選び方によらず出る — 評価レポート（1回目）

## 0. ユーザーの確認の結果（2026-11-20、main が追記）

- **最終の判定：合格。**
- ユーザーは、4章の U1〜U4 の図を見て、合格とした。気になる点の指摘は無かった。
  - main は、各項目の代表の図として、次の4枚を送った。`results/1118/` の `grooveOnImage_..._track_1014_img8_715-716ms.png`（U1）、`grooveOnImage_..._hist_5cyc_1104_img5_groove4_2718-2719ms.png`（U1・U2）、`waveform_..._hist_5cyc_1104_img5_groove4_2717-2720ms.png`（U3）、`waveform_..._hist_5cyc_1104_1537-1540ms.png`（U4）。
- 4章の U3 で評価担当が挙げた、2717〜2720 ms に残る振幅 0.7〜0.8 の持ち上がりについても、指摘は無かった。溝底の線そのものが約 1 px 下がった分で、計画の段階で本実装の欠点として挙げた所である（plan-2.md 9章）。

以下は評価担当が書いた、ユーザーの確認の前の内容。

## 判定：ユーザー確認待ち

- 数値の項目は、すべて満たした。
  - テスト（T1・T2）、整合（R1〜R5）7/7、計画どおりかの確認（P1〜P11）25/25、品質の基準（Q1〜Q5）15/15、変えてはいけないもの（D1〜D4）4/4。
  - 不合格の項目は無い。
- 残っているのは、ユーザーが図を見て判断する項目 U1〜U4 である。見る図と観点は 4章に書いた。各項目で、まず見てほしい図を2〜3枚挙げた。
- 実装（`d34563c`）は、計画（plan-2.md）の値をぴったり再現した。直した後は、3つのデータとも外れ値が0になり、幅4以下の点を採っていた列は1列も変わらなかった。

## 言葉

criteria.md 2.2 と同じ意味で使う。

- **t1014・h1104・t1104**：比べる3つの保存済みのデータ。t1014 は1周分の自動追跡（`experiments/1014/cycleResult_origD_track_1014.mat`）、h1104 は5周分の本実装（`experiments/1104/cycleResult_origD_hist5_1104.mat`）、t1104 は5周分の正解データ（`experiments/1104/cycleResult_origD_track5_1104.mat`）。m1014 は同じ写真の従来法（`experiments/1014/cycleResult_origD_1014.mat`）で、参考の比較だけに使う。
- **溝底区間**：写真の各列で、暗さ（1 − 画素値/255）が 0.6 以上の行が続く範囲。**幅**は、その最後の行 − 最初の行 [px]。
- **直す前・直した後**：溝底区間の幅の上限を 8・4 にして、保存したクリック位置で溝底点の検出からデトレンドまでをやり直した結果。
- **局所的なずれ**：選んだ点のデトレンド前の y から、前後10列（合わせて21列）で点を採れた列の y の中央値を引いた値。点を採れずに補間した列では求めない。
- **外れ値**：局所的なずれの絶対値が 1 px を超える点。
- **幅の広い点**：選んだ点のうち、幅が5以上のもの（直す前にだけある）。
- **変わった列**：直す前と後で、デトレンド前の y の差が 1e-9 を超える列。
- **振幅**：デトレンドした y を再生順につなぎ、全体の平均を引いて 1.5 px で割ったもの。
- **temp のコピー**：日付などの数行だけを変えて `temp/` に置いた、スクリプトのコピー（`docs/rules/data.md`）。

## 1. 評価したもの

### 1.1 コードと環境

- 評価したコードは `d34563c`（`claude/wide-bottom-outliers` の先頭）である。
- `git status --porcelain` は、評価の前にも、データと図を作り終えた後にも空だった。R5 のコピーと評価スクリプトは、この状態で実行した。
- 実行日は 2026-11-18、出力の日付（`OUT_DATE`）は `1118` である。実行の前に、`results/1118/`・`experiments/1118/`・`temp/check_*_1118.mat` が無いことを確かめた。
- MATLAB で `Research.prj` を開いて実行した。

### 1.2 使ったデータ（どれも読むだけ）

| 呼び名 | ファイル | 作ったスクリプト | `meta.gitCommit` | `meta.gitDirty` |
|---|---|---|---|---|
| t1014 | `experiments/1014/cycleResult_origD_track_1014.mat` | `grooveTrack_1cycle` | `3261e62` | false |
| h1104 | `experiments/1104/cycleResult_origD_hist5_1104.mat` | `grooveHist_Ncycle` | `569e327` | false |
| t1104 | `experiments/1104/cycleResult_origD_track5_1104.mat` | `grooveTrack_Ncycle` | `b9c5db0` | false |
| m1014 | `experiments/1014/cycleResult_origD_1014.mat` | `pkCentroid_1cycle`（従来法） | `3261e62` | false |

写真は `DSC1111-0000{1..8}-ori.png`（`data/`）を、`reconstructImage` で読み直した。

### 1.3 実行したもの

| 手順 | 実行したファイル | もとのファイル | 変えた行 | 実行時間 | 警告 |
|---|---|---|---|---|---|
| T1 | `test/runAllTests.m`（`cd test; results = runAllTests;`） | — | — | — | — |
| R5 | `temp/grooveTrack_1cycle_eval1118.m` | `scripts/grooveTrack_1cycle.m` | criteria.md 8章の手順4(2)のとおり（下の補足） | 21.1 s | 0件 |
| R5 | `temp/grooveHist_Ncycle_eval1118.m` | `scripts/grooveHist_Ncycle.m` | 同上 | 18.4 s | 0件 |
| R5 | `temp/grooveTrack_Ncycle_eval1118.m` | `scripts/grooveTrack_Ncycle.m` | 同上（`RECLICK_IMAGES` は空、`GUIDE_RESULT_PATH` は空文字のまま） | 22.0 s | 0件 |
| R・P・Q・S・U | `temp/compareWidthThresh_eval1118.m` | `scripts/evaluation/grooveBottomDetection/compareWidthThresh.m` | `OUT_DATE = "1118"` と `SCRIPT_CHECK_PATHS`（R5 の3つの .mat）だけ | 107.5 s | 0件 |

- R5 のコピーで変えた行
  - `date` を `"1118"` にした。
  - `PREV_RESULT_PATH` を、そのスクリプトが作ったデータ（t1014・h1104・t1104）にした。
  - `SAVE_TRACK_FIG`（`grooveTrack_1cycle.m`）・`SAVE_FIG`（ほかの2つ）を `false` にした。
  - `expDir = experimentDir(...)` に `Create=false` を付けた。
  - `saveCycleResult(...)`（続きの行を含む）を、`temp/check_<スクリプト名>_1118.mat` に `y_comb_cnt`・`y_comb_max`・`cond` を保存する行に置き換えた。
  - 冒頭に、temp のコピーであることを書いたコメントを3行足した。
  - 元のファイルとの差（`diff`）で、これ以外の行が変わっていないことを確かめた。
- 警告の確かめ方：実行の前に `lastwarn('')` で空にし、実行の後に `lastwarn` が空であることを確かめた。コマンドウィンドウにも警告は出なかった。評価スクリプトの中の溝の選択の警告（`sel.warnings`）も、3つのデータ・両手法・直す前と後のすべてで0件だった。
- R5 の .mat は `save` で保存したので、`meta` を持たない。実行したときのコードは `d34563c` で、作業ツリーはきれいだった（1.1）。
- 評価スクリプトは直していない（実行時のエラーは無かった）。

## 2. 項目ごとの結果

### 2.1 テスト

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| T1 | `runAllTests` の失敗・未完了の件数 | 0件 | 258件中258件が通過（失敗0、未完了0）。受け入れテスト `WideBottomOutlierAcceptanceTest` は15件中15件、`FigureNameTest` は18件中18件が通過 | 満たす |
| T2 | 変えた `.m` 5つの `checkcode` の警告 | 0件 | `scripts/grooveTrack_1cycle.m`・`scripts/grooveHist_Ncycle.m`・`scripts/grooveTrack_Ncycle.m`・`src/figureVocabulary.m`・`test/unit/FigureNameTest.m` のすべてで0件 | 満たす |

### 2.2 整合

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| R1 | 幅の上限8で検出した溝底点と、4つのファイルの保存した `pts`（両手法・写真8枚） | 差 ≤ 1e-9、点の数も同じ | 差 0 | 満たす |
| R2 | 幅の上限4の点 ＝ 幅の上限8の点のうち幅4以下のもの（両手法、並びも同じ） | `isequal` | true | 満たす |
| R3 | 直す前の溝の選択と、保存した `yAbs`・`found`（h1104 は山の中心も） | 差 ≤ 1e-9、`found` の不一致 0 | y の差 0、`found` の不一致 0、山の中心の差 0 | 満たす |
| R4 | 直す前の振幅と、保存した `audio.signal` | 差 ≤ 1e-9 | 差 0 | 満たす |
| R5-t1014 | 直した `grooveTrack_1cycle.m` の `y_comb_cnt`・`y_comb_max` と、評価スクリプトの直した後。`cond.wTh` | 差 ≤ 1e-9、`wTh` = 4、警告なし | 差 0、`wTh` = 4、警告0件 | 満たす |
| R5-h1104 | 同、`grooveHist_Ncycle.m` | 同上 | 差 0、`wTh` = 4、警告0件 | 満たす |
| R5-t1104 | 同、`grooveTrack_Ncycle.m` | 同上 | 差 0、`wTh` = 4、警告0件 | 満たす |

### 2.3 計画どおりかの確認

数えた値は一致、実数は差が 0.0005 以下なら満たす。値は「直す前 → 直した後」。

| ID | 指標 | t1014 | h1104 | t1104 | 判定 |
|---|---|---|---|---|---|
| P1 | 重心法の外れ値の数 | 1 → 0（計画 1 → 0） | 26 → 0（26 → 0） | 25 → 0（25 → 0） | 満たす |
| P2 | 重心法の \|振幅\| > 0.8 のサンプル | 2 → 1（2 → 1） | 56 → 9（56 → 9） | 55 → 9（55 → 9） | 満たす |
| P3 | 重心法の \|振幅\| > 1 のサンプル | 1 → 0（1 → 0） | 32 → 0（32 → 0） | 31 → 0（31 → 0） | 満たす |
| P4 | 重心法の幅の広い点 | 7 → 0（7 → 0） | 104 → 0（104 → 0） | 103 → 0（103 → 0） | 満たす |
| P5 | 重心法の変わった列（(i) 幅の広い点の列／(ii) 補間していた列／(iii) 幅4以下の点の列） | [7 0 0]（[7 0 0]） | [104 2 0]（[104 2 0]） | [103 3 0]（[103 3 0]） | 満たす |
| P6 | 重心法の、y が変わらなかった列の振幅の変化の最大 | 0.00657（0.0066） | 0.02453（0.0245） | 0.02356（0.0236） | 満たす |
| P11 | 幅の広い点の列での、重心法と局所的最大値法（直す前）の \|差\| の平均・最大 [px] | 平均 0.7390 → 0.2689、最大 1.3935 → 0.4472（7列。計画と同じ） | 平均 0.8744 → 0.2161、最大 2.3201 → 0.6026（104列。同） | 平均 0.8653 → 0.2174、最大 2.3201 → 0.6026（103列。同） | 満たす |

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| P7 | 直した後の h1104 と t1104 の、デトレンド前の y と点を採れた列（重心法） | `isequal` | 一致（参考：局所的最大値法も一致） | 満たす |
| P8 | h1104：山の中心（両手法）が変わらない、帯の中に2点以上ある列（重心法）、最も長い連続欠損（重心法）[列] | 差 ≤ 1e-9、0 → 0、10 → 15 | 差 0・0、0 → 0、10 → 15 | 満たす |
| P9 | h1104・局所的最大値法：変わった列、\|振幅\| > 0.8、\|振幅\| > 1 | 33、112 → 100、0 → 0 | 33、112 → 100、0 → 0 | 満たす |
| P10 | h1104・重心法：y の変化 [px]。外れ値だった列の中央値／外れ値でなかった幅の広い点の列の中央値・最大 | 1.3912／0.4504・1.2393 | 1.3912（26列）／0.4504・1.2393（78列） | 満たす |

計画どおりかの確認は、25項目すべてを満たした。

### 2.4 品質の基準

| ID | 指標 | しきい値 | t1014 | h1104 | t1104 | 判定 |
|---|---|---|---|---|---|---|
| Q1 | 直した後の外れ値の数（重心法） | 0 | 0 | 0 | 0 | 満たす |
| Q2 | 変わった列のうち、直す前に幅4以下の点を採っていた列（重心法・局所的最大値法） | 0・0 | 0・0 | 0・0 | 0・0 | 満たす |
| Q3 | 直した後の最も長い連続欠損と、溝の選択の警告（重心法・局所的最大値法） | ≤ 40 px、警告0件 | 7・7 px、0・0件 | 15・15 px、0・0件 | 15・15 px、0・0件 | 満たす |
| Q4 | 幅の広い点の列での、直した後の重心法と局所的最大値法（直す前）の \|差\| の平均 [px] | ふつうの列の平均 + 3 × 標準誤差 | 0.269 ≤ 0.460（直す前 0.739） | 0.216 ≤ 0.258（直す前 0.874） | 0.217 ≤ 0.258（直す前 0.865） | 満たす |
| Q5 | 直す前と後の溝形状（デトレンド後）の RMSE [px]・相関（写真×溝ごと・全体、両手法） | 写真×溝ごと RMSE ≤ 0.15・相関 ≥ 0.80、全体 RMSE ≤ 0.15・相関 ≥ 0.90 | 下の表 | 下の表 | 下の表 | 満たす |

Q5 の値（RMSE の最大・全体、相関の最小・全体）

| データ | 重心法 | 局所的最大値法 |
|---|---|---|
| t1014 | RMSE 最大 0.0264・全体 0.0094、相関 最小 0.9921・全体 0.9993 | RMSE 最大 0.0084・全体 0.0030、相関 最小 0.9996・全体 1.0000 |
| h1104 | RMSE 最大 0.0910・全体 0.0228、相関 最小 0.9490・全体 0.9961 | RMSE 最大 0.0312・全体 0.0059、相関 最小 0.9949・全体 0.9998 |
| t1104 | RMSE 最大 0.0875・全体 0.0225、相関 最小 0.9525・全体 0.9962 | RMSE 最大 0.0312・全体 0.0059、相関 最小 0.9949・全体 0.9998 |

- 最も悪い値は、h1104 の写真8・5本目（重心法）の RMSE 0.0910 px・相関 0.9490 である。変わった列は29列で、しきい値まで余裕がある。
- 写真×溝ごとの値は `results/1118/evalWidthThresh_shapes.csv` にある。変わった列が無い写真×溝は、RMSE 0・相関 1 である。

品質の基準は、15項目すべてを満たした。

### 2.5 変えてはいけないもの

| ID | 指標 | しきい値 | 実測値 | 判定 |
|---|---|---|---|---|
| D1 | `git diff --name-status c557c33 -- src scripts test docs/rules README.md CLAUDE.md` に出るファイル | 許した7ファイルの変更だけ（master から取り込んだ変更は除く） | `README.md`・`docs/rules/figures.md`・`scripts/grooveHist_Ncycle.m`・`scripts/grooveTrack_1cycle.m`・`scripts/grooveTrack_Ncycle.m`・`src/figureVocabulary.m`・`test/unit/FigureNameTest.m` の変更（M）と、`docs/rules/writing.md`。`writing.md` は master から取り込んだもので除く（下の補足）。受け入れテスト・評価スクリプト・`CLAUDE.md`・ほかの `src/`・`scripts/` は差分なし | 満たす |
| D2 | 3つのスクリプトの、コメントでない変わった行 | `WIDTH_THRESH = 4;` の行だけ | 3つとも、`-WIDTH_THRESH = 8;` と `+WIDTH_THRESH = 4;` の1組だけ（行の頭の空白を除いてから `%` で始まる行を除いて数えた）。ほかは、作成日の下の変更の1行と、パラメータの行の続きのコメント2行 | 満たす |
| D3 | 図の語：新しい分類「溝底区間の幅」と語 `wTh<N>`。図の名前の警告 | すべて満たす | `docs/rules/figures.md` の語彙表と `src/figureVocabulary.m` の `conditionTable` で、`inclBound`（溝底の判定）のすぐ下に「溝底区間の幅」`wTh<N>` がある。`figures.md` の並び順の文（画像 → 溝底の判定 → 溝底区間の幅 → …）と、`figureVocabulary.m` の冒頭の分類の一覧にも足してある。評価スクリプトの実行で `checkFigureName:invalidName` の警告は出ず（`lastwarn` が空）、保存した図48枚の名前を `checkFigureName(...,Warn=false)` にかけても、理由のある名前は0件だった | 満たす |
| D4 | `experiments/` の既存のファイルの SHA-256 | criteria.md 4.5 の値と同じ。新しいファイルが無い | 評価の前と、データと図を作り終えた後の2回、15ファイルすべてが一致した。ファイルは15個のままで、`experiments/1118/` はできていない | 満たす |

- D1 の補足
  - `c557c33` の後のコミットのうち、D1 の対象の場所で `docs/rules/writing.md` を変えたのは、master のコミット `6f65d55` だけである（`git log c557c33..HEAD -- docs/rules/writing.md`）。HEAD の `writing.md` は `6f65d55` のものと同じだった。
  - 取り込みのコミット `2027600` が `c557c33` から変えたファイルは、`docs/rules/writing.md` と `docs/issues/35-wide-bottom-outliers/criteria.md` だけで、D1 の対象の場所では `writing.md` だけである。
  - criteria.md 4.5 の補足の除く範囲（`git diff --name-status c557c33 <取り込んだ master のコミット>`）を `6f65d55` で文字どおりに計算すると、`writing.md` のほかに、受け入れテストと評価スクリプトの削除（D）も出る。master にはこの2つが無いためである。この2つは除かずに確かめ、どちらも `c557c33` から差分が無かった。そのため、どちらの読み方でも D1 は満たす。

### 2.6 参考（判定には使わない）

| ID | 内容 | 結果 |
|---|---|---|
| S1 | t1014・重心法と従来法（m1014）が、同じ列で選んだ点 | 直す前は、同じ点 32,055、追跡だけ 27、従来法だけ 0、違う点 0。直した後は、同じ点 32,051、追跡だけ 24、従来法だけ 4、違う点 0（criteria.md 4.6 の試行と同じ） |
| S2 | 局所的最大値法：外れ値、\|振幅\| > 0.8、\|振幅\| > 1、幅の広い点、変わった列 | t1014 は 0 → 0、21 → 21、0 → 0、7 → 0、4列。h1104・t1104 は 0 → 0、112 → 100、0 → 0、104 → 0、33列 |
| S3 | 重心法：写真×溝ごとの、点を採れなかった列の最大 | t1014 は 7 → 7。h1104・t1104 は 16 → 29（写真8・5本目。Q-b の決定で品質の基準には使わない） |
| S4 | 変わらなかった幅4以下の列での、重心法と局所的最大値法の \|差\|（平均・中央値・75・90・95・99パーセンタイル・最大）[px] | t1014 は [0.198 0.033 0.485 0.496 0.497 0.502 0.961]（32,075列）。h1104・t1104 は [0.191 0.032 0.482 0.495 0.497 0.503 0.967]（160,309列） |
| S5 | 重心法：写真の境目の振幅の跳びの変化（直した後 − 直す前）の最大の絶対値 | t1014 は 0.0066（境目7か所）。h1104・t1104 は 0.0120（境目39か所） |

## 3. 外れ値の数と場所（直す前と後、重心法）

直した後の外れ値は、3つのデータとも0点だった。直す前の外れ値は次のとおりである（h1104 は26点、t1104 は25点、t1014 は1点）。どれも幅5以上の点だった。

| 周（溝） | 写真 | x [px] | 幅 [px] | 局所的なずれ [px] | 振幅（直す前） | 時刻の目安 | h1104 | t1104 | t1014 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 8 | 1865 | 5 | 1.38 | 1.03 | 715 ms | あり | あり | あり |
| 2 | 3 | 1161・1162 | 5・5 | 1.49・1.47 | 1.23・1.22 | 989 ms | あり | あり | — |
| 2 | 8 | 4011 | 8 | 1.34 | 0.95 | 1536 ms | あり | あり | — |
| 3 | 8 | 883・884・885・917 | 6 | 1.40〜1.84 | 0.99〜1.18 | 2230 ms | あり | あり | — |
| 4 | 8 | 913・999・1020・1025・1076・1150 | 5〜7 | 1.35〜1.84 | 0.80〜1.20 | 2999〜3006 ms | あり | あり | — |
| 5 | 3 | 1011・1012 | 5・5 | 1.43・1.45 | 1.21・1.23 | 3293 ms | あり | あり | — |
| 5 | 8 | 2006・2007・2009・2010・2089〜2093 | 6〜7 | 1.34〜1.85 | 0.76〜1.29 | 3795〜3798 ms | あり | あり | — |
| 5 | 8 | 2314 | 6 | 1.35 | 1.27 | 3803 ms | あり | なし | — |

- h1104 と t1104 の違いは、5本目・写真8の x=2314 の1点だけである（issue の背景の2と同じ）。
- 直した後に \|振幅\| > 0.8 で残るサンプル（重心法）は、t1014 で1点、h1104 で9点だった。どれも幅1〜3の点で、局所的なずれは最大 0.935 px（1 px 以下）である。t1014 の1点は、写真1の x=2433（振幅 −0.838）である。
- 幅の広い点が続く区間（2列以下のすき間はつなぐ）は、t1014 で2か所、h1104・t1104 で31か所だった。11列以上続くのは、次の2か所である（どちらも h1104・t1104 で同じ）。
  - 4本目・写真5 x=1141〜1159（19列、うち幅の広い点17列。外れ値は0点）。\|振幅\| の最大は 1.228 → 0.777。
  - 2本目・写真8 x=4004〜4030（27列、うち幅の広い点20列。外れ値は1点）。\|振幅\| の最大は 0.950 → 0.338。
- 一覧の表は `results/1118/evalWidthThresh_outliers.csv`（外れ値）、`evalWidthThresh_amp.csv`（\|振幅\| > 0.8）、`evalWidthThresh_wideRuns.csv`（幅の広い点が続く区間）にある。

## 4. ユーザーに見てほしい図（ユーザー確認待ち）

図はすべて `results/1118/` にある（png と fig）。切り出しの図は27枚、波形の図は21枚（外れの波形15枚、写真の境目6枚）で、criteria.md 5章の試行と同じ枚数である。t1104 の切り出しは、すべて h1104 と同じ場所なので作られていない（評価スクリプトの決まり）。

- 切り出しの図の見方：上の段が写真だけ、下の段が写真と点である。cyan はすべての溝底点（幅の上限8）、黄は直す前に選んだ点、マゼンタの点は直した後に選んだ点、マゼンタの線は直した後の経路（補間した列を含む）である。黄の点が見える所が、直したことで除いた点である。
- 波形の図の見方：赤橙が直す前、青が直した後である。青の丸は y が変わった列、縦の点線は写真の境目である。

### U1 外れ値の場所（切り出しの図）

観点は2つある。
(1) 除いた点（黄）が、溝底の暗い線から外れていたか。
(2) 直した後の経路（マゼンタ）が、溝底の暗い線の上を通っているか。

まず見てほしい図

- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_715-716ms.png`：issue の発端の 715 ms（1周分）。
- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img8_groove5_3795-3797ms.png`：外れ値が4点まとまった所で、局所的なずれが最も大きい（1.85 px）。
- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2718-2719ms.png`：11列以上続く所（19列）。

ほかの図（ファイル名の前半 `grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_` を略す）

- 1本目：`img8_groove1_715-716ms`
- 2本目：`img3_groove2_988-989ms`、`img8_groove2_1535-1537ms`
- 3本目：`img8_groove3_2230-2231ms`、`img8_groove3_2231-2232ms`
- 4本目：`img8_groove4_2999-3001ms`、`img8_groove4_3002-3003ms`、`img8_groove4_3004-3005ms`、`img8_groove4_3005-3006ms`
- 5本目：`img3_groove5_3292-3293ms`、`img8_groove5_3797-3798ms`、`img8_groove5_3803-3804ms`

### U2 外れ値ではない幅の広い点の場所（切り出しの図）

観点は2つある。
(1) 変わった量が受け入れられるか（ユーザーは、外れ値でない点が変わることを受け入れている）。
(2) 写真5の4本目では、溝底の線そのものが約 1 px 下がった分が、直した後も残っていること（plan-2.md 9章）。

まず見てほしい図

- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img8_groove2_1535-1537ms.png`：写真8の2本目 x=4004〜4030（27列。外れ値を1点含む。ユーザーが「おおむね正しく追跡できている」とした所）。
- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img4_groove5_3453-3454ms.png`：写真4の5本目 x=3701〜3707。
- `results/1118/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_671-672ms.png`：写真8の1本目 x=33〜36（1周分。S1 で「従来法だけ」になった4列）。

ほかの図（同じく前半を略す）：`img8_groove1_671-672ms`、`img5_groove4_2718-2719ms`（U1 と同じ図）、`img8_groove2_1440-1441ms`、`img8_groove2_1537-1539ms`、`img8_groove3_2271-2272ms`、`img8_groove4_3075-3076ms`、`img8_groove5_3748-3749ms`、`img8_groove5_3751-3752ms`、`img8_groove5_3756-3757ms`、`img8_groove5_3840-3841ms`、`img8_groove5_3844-3845ms`

### U3 外れの波形（波形の図）

観点は2つある。
(1) 直す前（赤橙）の鋭い外れが、直した後（青）で消えているか。
(2) 変わった列（青の丸）の外では、2本の線が重なっているか。

まず見てほしい図

- `results/1118/waveform_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_714-717ms.png`：715 ms（1周分）。
- `results/1118/waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img8_groove5_3794-3798ms.png`：外れが4か所並ぶ所。
- `results/1118/waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2717-2720ms.png`：11列以上続く所。

見るときの注意

- 写真ごとの9次のデトレンドが少し変わるので、変わった列の外でも、2本の線がわずかに（振幅で最大 0.025。P6）ずれて見える写真がある（例：写真8・5本目の 3794〜3798 ms）。
- 2717〜2720 ms では、直した後も振幅が 0.7〜0.8 に持ち上がった所が残る。溝底の線そのものが約 1 px 下がった分である（U2 の (2)）。

ほかの図（ファイル名の前半 `waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_` を略す）：`img8_groove1_714-717ms`、`img3_groove2_987-990ms`、`img8_groove2_1534-1538ms`、`img8_groove3_2229-2232ms`、`img8_groove3_2230-2233ms`、`img8_groove4_2998-3002ms`、`img8_groove4_3001-3004ms`、`img8_groove4_3003-3006ms`、`img8_groove4_3004-3007ms`、`img3_groove5_3291-3294ms`、`img8_groove5_3796-3799ms`、`img8_groove5_3802-3805ms`

### U4 写真の境目（波形の図）

観点：境目（点線）の前後で、直す前と後の波形がほぼ重なり、直したことで新しい跳びが出ていないか。跳びの変化の最大は 0.012 だった（S5）。

まず見てほしい図

- `results/1118/waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_1537-1540ms.png`：跳びの変化が最も大きい境目（2本目の写真8 → 3本目の写真1、0.012）。
- `results/1118/waveform_wTh8VsWTh4_origD_inclBound_centroid_track_1014_669-672ms.png`：1周分で変化が最も大きい境目（写真7 → 写真8、0.0066）。

ほかの図：`waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_669-672ms.png`、`..._hist_5cyc_1104_2689-2692ms.png`、`..._track_1014_190-193ms.png`、`..._track_1014_286-289ms.png`

### 参考（判定には使わない）

R5 のコピーの実行で、直した後の wav が `results/1118/` にできた。直す前の wav と聞き比べてもよい（外れはクリックのような音になる）。

- 1周分：`results/1118/audio_(centroid_method)(original)(tracking).wav` と `results/1014/audio_(centroid_method)(original)(tracking).wav`
- 5周分：`results/1118/audio_(centroid_method)(original)(hist_5_cycles).wav` と `results/1104/audio_(centroid_method)(original)(hist_5_cycles).wav`

## 5. 不合格の項目

無い。

## 6. 気づいた点

- 評価基準・受け入れテストの誤り
  - 誤りは見つからなかった。
  - criteria.md 4.5 の D1 の補足は、文字どおりに読むと除く範囲が広くなる（2.5 の D1 の補足）。今回はどちらの読み方でも結果が同じなので、判定には影響しない。次に同じ形の基準を書くときは、除く範囲を「master のコミット `6f65d55` で変わったファイル（`git diff --name-status 6f65d55^ 6f65d55`）」のように書くと、読み違えが起きない。
- 実装の報告との照合
  - impl-report-1.md 4.4 の値（\|振幅\| の数、変わった列、写真ごとの欠損、警告0件）は、コミットの後に実行し直した今回の値と一致した。
- 出力
  - `results/1118/` には、R5 の wav・図（42ファイル）と、評価スクリプトの図（png・fig 各48）と CSV（6つ）の、合わせて144ファイルがある。既存のファイルは上書きしていない（フォルダは今回作った）。

## 7. 作ったファイル

- 受け渡しフォルダ：この報告（`docs/issues/35-wide-bottom-outliers/eval-report-1.md`）。
- `results/1118/`（git管理外）
  - 評価スクリプトの図：`grooveOnImage_wTh8VsWTh4_*`（27枚）、`waveform_wTh8VsWTh4_*`（21枚）。png と fig。
  - 表：`evalWidthThresh_summary.csv`（判定の表）、`evalWidthThresh_outliers.csv`、`evalWidthThresh_amp.csv`、`evalWidthThresh_wideRuns.csv`、`evalWidthThresh_shapes.csv`、`evalWidthThresh_boundaries.csv`。
  - R5 のコピーの出力：`audio_(…)(tracking)`・`(hist_5_cycles)`・`(tracking_5_cycles)` の wav と、`_amp`・`_fft`・`_stft` の図。
- `temp/`（git管理外。消さずに残す）
  - temp のコピー：`grooveTrack_1cycle_eval1118.m`、`grooveHist_Ncycle_eval1118.m`、`grooveTrack_Ncycle_eval1118.m`、`compareWidthThresh_eval1118.m`。
  - R5 の .mat：`check_grooveTrack_1cycle_1118.mat`、`check_grooveHist_Ncycle_1118.mat`、`check_grooveTrack_Ncycle_1118.mat`。
- `experiments/`・`data/`・`src/`・`scripts/`・`test/` には、何も作らず、何も変えていない。
