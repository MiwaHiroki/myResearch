- 段階: 評価基準
- 作成者: evaluator（モードA）
- 作成日: 2026-10-27
- 入力: issue #30（本文。コメントなし）、[`./plan.md`](./plan.md)（承認済み）、[`./README.md`](./README.md)（決定事項）、メインからの依頼文、`docs/issues/closed/25-groove-tracking/criteria.md`
- 状態: 承認済み（2026-10-28、ユーザー。Q-a・Q-b は推奨どおり (a)。6章）

# #30 写真ごとに1回のクリックからN本の溝を抽出し、N周分の音声を作る — 評価基準

## 1. 結論（判定の決め方）

- 本実装（ヒストグラムで2本目以降を選ぶ `grooveHist_Ncycle.m`）を、正解データ（5本を `trackGroove` で別々に追跡した `grooveTrack_Ncycle.m`）と比べる。N=5。主に見るのは2本目以降。
- しきい値は2種類に分ける。
  - **計画**（計画どおりかの確認）：計画の試行（plan.md 付録 A.5、評価担当が再現して同じ値を確認）と同じ値になるか。品質の基準ではない。余裕の小さい項目がある（3.1）。
  - **品質**（手法として十分かの基準）：溝の間隔、隣の溝との相関、#25 で手法として受け入れた一致度（基準データの再現性の限界）を根拠にする（3.2）。
  - ほかに **整合**（保存と再現。誤差 1e-9 以下か一致）と、**前提**（正解データの確認）がある。
- 判定
  - **合格**：前提 P1〜P4 を満たし、テスト T1・T2 と数値の項目（計画・品質・整合）をすべて満たし、ユーザーが判断する項目 U1〜U3 でユーザーが良いと判断したとき。
  - **ユーザー確認待ち**：P・T・数値の項目をすべて満たし、U が残っているとき。評価レポートはこの判定で出し、見てほしいファイルと観点を書く。
  - **不合格**：T・数値の項目のどれか1つでも満たさないとき。どの写真・溝・列でどう外れたかを評価レポートに書き、実装に戻す。「計画」だけを満たさず「品質」をすべて満たす場合も不合格とし、計画と違う点と、品質は満たしていることを分けて書く（未決事項 Q-a）。
  - **評価の保留**：前提 P1〜P4 を満たさないとき（正解データの作り直しが要るなど）。実装の誤りではないので不合格にはせず、メインに報告して止める。U1 のうち正解データの図（`grooveTrackN_img*.png`）に飛び移りがある場合も保留にする（依頼文の決定）。
- 正解データが計画の試行の始点（plan.md A.10 の `seedsY`）から追跡した経路と違う (i,j) があれば（P5）、その (i,j) は「計画」の確認から除き、「品質」の基準だけで判定する。クリックが `seedsY` から ±8 px 以内なら同じ経路になることを確かめてあるので（3.2）、通常は除くものが無い。
- 基準は実装の前に決めたもので、実装の結果に合わせて変えない（`docs/rules/evaluation.md`）。

## 2. 比べるデータ

| 呼び名 | ファイル | 中身 | 作る時期・人 |
|---|---|---|---|
| 正解 | `experiments/<D1>/cycleResult_origD_track5_<D1>.mat` | `scripts/grooveTrack_Ncycle.m` を `temp/` のコピーで実行（plan.md 7.1 の1。`GUIDE_RESULT_PATH` = 1014）。写真ごとに5本をクリック | 実装のコミットの後、ユーザー |
| 本実装 | `experiments/<D2>/cycleResult_origD_hist5_<D2>.mat` | `scripts/grooveHist_Ncycle.m` を `temp/` のコピーで、`date` と `PREV_RESULT_PATH`（＝正解）だけを変えて実行（`ginput` なし） | 評価（モードB）、評価担当 |
| #25 の1周分 | `experiments/1014/cycleResult_origD_track_1014.mat` | #25 で合格した追跡の結果。1本目の比較（P3）と、`detrendTrackedShape` の回帰（E7d） | 既存（読み取りのみ） |

評価スクリプト：`scripts/evaluation/multiGroove/compareHistToTracking.m`（冒頭の `GT_DATE`・`GT_FILE`・`HIST_DATE`・`HIST_FILE`・`OUT_DATE` を書き換える）。判定の表・写真×溝ごとの表・周ごとの表を表示し、`results/<OUT_DATE>/evalMulti_summary.csv`・`evalMulti_grooves.csv`・`evalMulti_cycles.csv` に書く。表の ID はこの文書と同じ。

## 3. しきい値の根拠（実測値）

評価担当が 2026-10-27 に、今のコード（`22aa553`）で読み取りのみで確かめた値。正解の代わりに plan.md 付録 A.3・A.10 の作り方（`seedsY` で5本を `trackGroove`）、本実装の代わりに plan.md 4.2 どおりの使い捨ての試作（`temp/multiGroove/`、リポジトリには入れていない）を使い、両方を cycleResult の形で `temp/` に保存して、評価スクリプトを最後まで実行した（46項目すべて合格）。

### 3.1 計画の試行の再現（「計画」の区分の根拠）

plan.md の値とすべて一致した。

| 項目 | 値 |
|---|---|
| 正解の1本目 と 1014 | 両手法とも `isequal` |
| 本実装の山の中心 `centers`（8×5） | plan.md A.5 の表と同じ（局所的最大値法は写真3・7の1本目が −0.5） |
| 帯の中に点が無かった列の数（8×5） | plan.md A.5 の表と同じ（1本目は #25 の `[0 7 6 0 0 4 0 0]`）。両手法で同じ |
| 2本目以降で正解と完全に一致 | 重心法 31/32、局所的最大値法 32/32。重心法の写真8・5本目は RMSE 0.0177 px・相関 0.9981（x=2314 の1列） |
| 正解で採れて本実装で採れなかった列／その逆 | 0 列／1 列（重心法の写真8・5本目） |
| 5周分の `y_comb` | 重心法 RMSE 0.00283 px・相関 0.999940（周ごとの RMSE `[0 0 0 0 0.00633]`）、局所的最大値法は一致 |
| 同じ列に2点以上あった列 | 0（両手法） |
| `fs`、±1 を超えたサンプル | 41729 Hz、重心法 32・局所的最大値法 0（正解は 31・0） |

- **余裕が小さい項目**：E2b（RMSE 0.0177 に対して 0.02、相関 0.9981 に対して 0.995）、E4a（RMSE 0.00283 に対して 0.004、相関 0.999940 に対して 0.9999）。計画どおりなら同じ値になるので、外れたら実装が計画と違う（帯の点の選び方、補間する y の取り方など）ことを示す。
- **山の中心と正解の中心の差**は最大 0.50005 px（重心法・写真8・1本目。1本目は補正後の中心がちょうどビンの端 0 に来る）。「`BIN_WIDTH/2` 以内」とすると計画どおりの実装でも 5e-5 px だけ外れるので、計画の確認は差ではなく、山の中心の表との一致（E1a）にした。

### 3.2 品質の基準の根拠

| 根拠 | 値 | 使う項目 |
|---|---|---|
| 溝の間隔（正解の経路を1本目の多項式で補正した中心の差） | 25.51〜28.37 px。写真ごとの最小の半分は 12.76〜13.86 px | E1b（別の溝を選んだら外れる） |
| 隣の溝との相関（正解どうし・重心法／本実装と正解の隣の溝・両手法） | −0.141〜0.172／−0.150〜0.178 | E1c、E2d（相関 0.80 は隣の溝の値より十分に高い） |
| #25 で手法として受け入れた一致度（#25 criteria.md。手動選択を取り直したときの、写真ごとの相関の最小 0.808、セグメントごとの RMSE の最大 0.162 px） | #25 の E4：写真ごとの相関 ≥ 0.80、全体の相関 ≥ 0.90、全体の RMSE ≤ 0.15 px | E2c・E2d・E4b・E4c |
| #25 の欠損の基準 | 写真ごとの欠損 ≤ 20 列（写真の幅の0.5%）、最も長い連続欠損 ≤ 40 px（`MaxGapLength`） | E3c・E3d・E3e |
| 正解の作り方の再現性（クリックの y を `seedsY` から ±d px ずらして追跡し直す） | ±1〜±8 px：40本 × 2手法すべて同じ経路。±10 px：26〜35/40 | P5（ユーザーのクリックが ±8 px 以内なら、計画の確認がそのまま使える） |
| 補正後の正解の経路の、中央値からのずれの最大 | 2.21 px（飛び移りがあれば溝の間隔の約27 px） | P2a（しきい値 13 px） |
| 参考：同じ溝の、重心法と局所的最大値法の差（正解） | RMSE 0.233〜0.364 px、相関 0.025〜0.841。形状の RMS は 0.19〜0.48 px | 品質のしきい値（0.15 px・0.80）が、検出方法による違いより厳しいことの確認 |

品質の基準で、却下した案が落ちることを確かめた（同じ試作で値だけ変えた）。

| 案 | RMSE の最大（E2c ≤ 0.15） | 相関の最小（E2d ≥ 0.80） | 正解で採れて帯で採れない列の最大（E3e ≤ 20） | 判定 |
|---|---|---|---|---|
| `BIN_WIDTH = 1`（採用） | 0.018 | 0.998 | 0 | 満たす |
| `BIN_WIDTH = 2`（plan.md Q1 の (c)） | 0.018 | 0.998 | 1 | 満たす |
| `BIN_WIDTH = 5`（旧スクリプトの値。同じ列は中心に最も近い点を採る） | **0.186** | 0.860 | **120** | 満たさない |
| 2本目以降のデトレンドを (b)（plan.md A.6） | **0.29** | **0.60** | — | 満たさない |

## 4. 評価の項目

### 4.1 前提（満たさなければ評価の保留）

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| P1 | 正解・本実装の `meta.gitDirty`、`meta.gitCommit`。`saveCycleResult:fileExists` の警告（`_2` 付きのファイル） | `gitDirty` がどちらも false。`gitCommit` が実装のコミット（またはその後の、`src/`・`scripts/` を変えていないコミット）。意図しない `_2` 付きのファイルが無い（ユーザーが作り直した正解の `_2` は、メインが指定したものを使う） | `docs/rules/data.md` の「実データの記録と作業ツリー」 | 評価スクリプト（`gitDirty`）、`git merge-base --is-ancestor`、`ls experiments/<日付>/`、実行ログ |
| P2a | 正解の経路（正解の1本目の多項式で補正）の、中央値からのずれの最大 | < 13 px | 飛び移りがあると約27 px ずれる。試行 2.21 px。U1 の正解の図と合わせて見る | 評価スクリプト |
| P2b | 正解の隣どうしの始点 `y0`（重心法）の差、`seedsY` の並び | ≥ 13 px（`MIN_SEED_GAP`）、その写真の差の中央値の 1.5 倍以下、各行が降順 | 同じ溝を2回・溝を飛ばしたクリックが無いこと（plan.md 4.2 の警告と同じ条件）。試行 25.1〜28.5 px、比 0.96〜1.04 | 評価スクリプト |
| P3 | 正解の1周目（`ycoords(:,1)`・`tracking.yAbsCnt/Max`）と 1014 | 両手法とも `isequal` | ユーザーが #25 と同じ1本目をクリックしたことの確認（plan.md E5）。違えば計画の確認（E1a・E3a）が使えない | 評価スクリプト |
| P4 | 本実装の `grooveSelection.seeds` | `[1列目, 正解の1本目のクリックの y]` と一致 | 本実装を正解の1本目のクリックで再現したことの確認 | 評価スクリプト |
| U1（正解） | 正解の図 `results/<D1>/grooveTrackN_img1〜8.png` | ユーザーが、5本とも隣の溝に飛び移っていないと確かめた | 依頼文の決定（評価の前提） | ユーザー |
| P5（参考） | 正解が、`seedsY` から追跡した経路と同じ (i,j) の数 | 判定には使わない。違う (i,j) は「計画」の確認から除く | 3.2 の再現性 | 評価スクリプト |

### 4.2 テスト

| ID | 指標 | しきい値 | 根拠 | 確かめる方法 |
|---|---|---|---|---|
| T1 | `cd test; results = runAllTests;` の失敗・未完了の件数 | 0件（受け入れテスト `MultiGrooveAcceptanceTest` の41件を含む） | issue の完了条件、`docs/rules/coding.md` | `runAllTests` |
| T2 | 新しく書いた・変えた `.m`（`src/` の5つ、`scripts/grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`、unitテスト）の `checkcode` の警告 | 0件 | `docs/rules/coding.md` の「確認」 | `mcp__matlab__check_matlab_code` |

受け入れテスト `test/unit/MultiGrooveAcceptanceTest.m`（41件、合成データのみ）が確かめること：

- `detrendTrackedShape`：2つ目の出力を受け取っても1つ目の出力は変わらない。`trend` の `p`・`S`・`mu` で `polyval` した値を引いて平均を引くと1つ目の出力になる。`trend.degree`（既定9）。
- `findGrooveCenters`：0 に最も近い山から y の小さい側へ、ビンの中心を返す（真の中心から `BinWidth/2` 以内、降順）。1本目がビンの端にあっても選べる。`FirstCenter`・`MaxFirstOffset`・`BinWidth` が効く。`numGrooves=1`。`info` のフィールドと、`peakCenters(firstIdx) == centers(1)`。エラー `notEnoughPeaks`・`noPeaksFound`・`firstPeakNotFound`。
- `extractGrooveBands`：元の画像の y を返す。欠損は `found=false` で、元の y で線形補間する（補正後の y で補間しない）。同じ列の2点は中心に近い点を採り、`numDuplicateCols` に数える（遠い点を後に並べても）。`Tolerance` の外の点・`xQuery` に無い x の点は使わない。列の間隔 0.25 px。エラー `tooFewPoints`。
- `extractMultiGroove`：クリックした溝から y の小さい側へ N 本（外側にも溝がある場合も、外側を選ばない）。各溝は `detrendTrackedShape` をかけた真の形状と一致し、`PolyDegree` はすべての溝に効く。1本目は `trackGroove` の結果そのもの。`info` のフィールドと大きさ、`minPeakHeight = MinPeakRatio × 列の数`。内側の溝の欠損列。`TrackTolerance`・`BandTolerance`・`MinPeakRatio` が効く。name-value 引数をすべて受け付ける。列の間隔 0.25 px でも整数の x で同じ y。エラーは部品の識別子のまま（`findGrooveCenters:notEnoughPeaks`・`noPeaksFound`、`trackGroove:seedNotFound`）。
- `cycleMethodResult`：(4×2) の `xcoords`・`ycoords` を受け付ける。形の違い・`pts` の数の違いは `sizeMismatch`。`y_comb` が1周目だけなら `yCombLength`（全周の長さで検証する）。1周分の行の cell は今と同じく列に直る。
- 保存と読み込み：(4×3) の `ycoords`・`xcoords`、`y_comb`、`audio` と、`grooveSelection.method`・`multiGroove`（cell・`trend` の struct を含む）がそのまま残り、`trackingSeeds` で1本目の始点を取り出せる。
- 写真2枚（各3セグメント）を `mergeSegmentPoints` → `extractMultiGroove` → `mat2cell` で通すと、`vertcat(ycoords{:})` が再生順（1本目の写真1・2 → 2本目 …）になり、`cycleMethodResult` が受け付ける。

受け入れテストは、plan.md 4.2 どおりに書いた使い捨ての試作（`temp/multiGroove/src/`）で41件すべて通ることを確かめた。また、試作をわざと誤らせた12種（選ぶ向きが逆、1本目の距離の確認なし、補正後の y で補間、同じ列で後の点を採る、しきい値を割合でなく点の数で使う、2本目以降をデトレンドしない、`y_comb` の長さを周ごとに数える、x を丸めて列に合わせる、`yAbs` に補正後の y を入れる、`BandTolerance`・`TrackTolerance` を無視、点が1つでもエラーにしない）のうち、すべてで狙ったテストが落ちることを確かめた。今の `src/` では40件が「関数が無い」などで失敗する（正常。実装の後に通る）。

### 4.3 実データでの数値の項目

区分：計画＝計画どおりかの確認、品質＝品質の基準、整合＝保存と再現。「2本目以降」は j=2〜5（j=1 は E5 で見る）。指標はどれも両手法（重心法・局所的最大値法）で別々に判定する。

| ID | 区分 | 指標 | しきい値 | 根拠 |
|---|---|---|---|---|
| **E1 同じ溝を選べているか** | | | | |
| E1a | 計画 | 本実装の `multiGroove.centersCnt`・`centersMax`（8×5） | plan.md A.5 の表と一致（誤差 1e-9 以下） | 3.1。1本目が 1014 と同じ（P3）なら、山の中心は正解のクリックによらず決まる |
| E1b | 品質 | \|山の中心 − 正解の中心\|（正解の `yAbs` から本実装の `trend` を引いたものの、`found` の列の中央値） | すべての (i,j) で、その写真の溝の間隔の最小の半分より小さい | 3.2（間隔の半分 12.76〜13.86 px）。試行の差の最大 0.50 px |
| E1c | 品質 | 本実装と正解の同じ溝の相関 − 隣の溝（j±1）の正解との相関の最大 | すべての (i,j) で正 | 別の溝を選ぶと、正解の同じ溝との相関が隣の溝の値（−0.15〜0.18）になり、隣の溝が正解と一致する。試行の差の最小 0.82 |
| **E2 形状の一致（写真ごと・溝ごとの9次デトレンド後、補間後の全列）** | | | | |
| E2a | 計画 | 2本目以降で、正解と完全に一致する (i,j)（RMSE ≤ 1e-9） | 計画の試行で一致した (i,j) がすべて一致（重心法 31本、局所的最大値法 32本。P5 で除いたものは数えない） | 3.1 |
| E2b | 計画 | 計画の試行でも完全には一致しなかった (i,j)（重心法の写真8・5本目） | RMSE ≤ 0.02 px、相関 ≥ 0.995 | 3.1（0.0177・0.9981）。余裕が小さい |
| E2c | 品質 | 2本目以降の写真×溝ごとの RMSE の最大 | ≤ 0.15 px | 3.2（#25 で受け入れた一致度）。却下した案（`BIN_WIDTH=5`、デトレンド (b)）は満たさない |
| E2d | 品質 | 2本目以降の写真×溝ごとの相関係数の最小 | ≥ 0.80 | 3.2（#25 の写真ごとの相関の基準。隣の溝は 0.18 以下） |
| **E3 欠損（補間の前の `found`）** | | | | |
| E3a | 計画 | 帯の中に点が無かった列の数（8×5、1本目は追跡の欠損） | plan.md A.5 の表と一致（両手法とも同じ表） | 3.1 |
| E3b | 計画 | 正解で採れて本実装で採れなかった列／その逆 | すべての (i,j) で 0 列／計画の試行と同じ（重心法の写真8・5本目だけ1列、ほかは0） | 3.1 |
| E3c | 品質 | 写真×溝ごとの、帯の中に点が無かった列の数の最大 | ≤ 20 列 | 3.2（#25 の E2a）。試行 16（写真5・5本目） |
| E3d | 品質 | 最も長い連続欠損 | ≤ 40 px | 3.2（#25 の E2b、`MaxGapLength`）。試行 10 px |
| E3e | 品質 | 正解で採れて本実装で採れなかった列の数の最大（写真×溝ごと） | ≤ 20 列 | 3.2。帯が溝の点を落とすと増える（`BIN_WIDTH=5` で 120） |
| **E4 最終出力（5周分の `y_comb`）** | | | | |
| E4a | 計画 | 全体の RMSE・相関 | 局所的最大値法は一致（RMSE ≤ 1e-9）。重心法は RMSE ≤ 0.004 px、相関 ≥ 0.9999。P5 で除いた (i,j) があれば判定しない | 3.1（0.00283・0.999940）。余裕が小さい |
| E4b | 品質 | 相関係数（全体と、周ごとの最小） | ≥ 0.90 | 3.2（#25 の E4b） |
| E4c | 品質 | RMSE（全体と、周ごとの最大） | ≤ 0.15 px | 3.2（#25 の E4c） |
| **E5 1本目の一致** | | | | |
| E5 | 整合 | 本実装の1周目（`ycoords(:,1)`・`tracking.yAbs*`・`found*`）と正解の1周目 | `isequal` | 1本目は正解と同じ処理（plan.md E5）。1014 との一致は P3 で見る |
| **E6 保存と再現（plan.md 4.4）** | | | | |
| E6a | 整合 | 本実装の `grooveSelection`（`method="histogram"`、`seeds` 8×2、`tracking`、`p1`/`p2` 80×2）と `multiGroove` のフィールド・大きさ・値（`binWidth=1`・`thHistRatio=0.3`・`bandTol=3`・`polyDegree=9`・`detrendScope="photo"`・`ampDivisor=1.5`、8×5 の `centers*`・`numDup*`、8×5 cell の `yAbs*`・`found*`、8×1 cell の `trend*`）、`ycoords`・`xcoords` が 80×5、`conditions`（`BinWidth=1`・`Tol=3`・`ThHist`/`HPrl` は NaN） | すべて満たす | plan.md 4.4 |
| E6b | 整合 | 本実装：`y_comb = vertcat(ycoords{:})`、`audio.signal = (y_comb − mean)/ampDivisor`、`fs` | 誤差 ≤ 1e-9、`fs = 41729`（＝1周分の列の数 ÷ (60/78)） | plan.md 2.3 の14、4.4 |
| E6c | 整合 | 本実装：`ycoords(:,j)` が `multiGroove.yAbs*{i,j}` に `detrendTrackedShape`（9次）をかけてセグメントの列の数で分けたもの。`yAbs*(:,1)` が `tracking.yAbs*` | 誤差 ≤ 1e-9 | 保存したデトレンド前の y と最終出力の整合 |
| E6d | 整合 | 本実装：保存した `pts`・`seeds`・パラメータだけで `mergeSegmentPoints` → `extractMultiGroove` を実行し直した `yAbs`・`found`・`centers`・`numDuplicateCols` | y・centers の誤差 ≤ 1e-9、`found`・`numDup` の不一致 0 | 要求「保存したクリックから `ginput` なしで再現できる」 |
| E6e | 整合 | 正解の `grooveSelection`（`method="tracking"`、`seeds = [1, seedsY(:,1)]`、`trackingSeeds` で同じ値）と `multiGroove`（`seedsY`・`y0Cnt`・`y0Max` 8×5、`seedsY` の各行が降順、`yAbs*`・`found*` 8×5 cell、`minSeedGap`・`polyDegree`・`detrendScope`・`ampDivisor`） | すべて満たす | plan.md 4.2・4.4 |
| E6f | 整合 | 正解：E6b と同じ | 同じ | 同じ |
| E6g | 整合 | 正解：E6c と同じ | 同じ | 同じ |
| E6h | 整合 | 正解：保存した `seedsY` から `trackGroove` を実行し直した `yAbs`・`found`・`y0` | 誤差 ≤ 1e-9、不一致 0 | 正解データ用スクリプトの再現性 |
| **E7 触らないもの** | | | | |
| E7a | 整合 | `experiments/` の既存のファイルの SHA-256 | 下の値と同じ | `docs/rules/data.md` |
| E7b | 整合 | `git diff --name-status 2d06a8a -- src scripts test` に出るファイル | plan.md 4.3 の「新規」「変更」のファイルだけ（`src/detrendTrackedShape.m`・`cycleMethodResult.m`・`saveCycleResult.m` の変更と、新しい `src/` 3つ・スクリプト2つ・unitテスト3つ、`DetrendTrackedShapeTest.m`・`CycleResultTest.m` の変更）。4.3 の「触らないもの」（`trackGroove.m`・`mergeSegmentPoints.m`・`trackingSeeds.m`・`extractGrooveShape.m`・`findGrooveCenter.m`・`fitGroove.m`・`detrendGrooveShape.m`・`extractGrooveWaveform.m`・`loadCycleResult.m`・`cycleConditions.m`・`DarknessMap.m`・`GrooveExtractor.m`・`GroovePointCloud.m`、既存のスクリプト、`archive/` の下、`test/unit/*AcceptanceTest.m`、`scripts/evaluation/`）は差分なし | issue の制約、plan.md 4.3 |
| E7c | 整合 | `git diff 2d06a8a -- src/saveCycleResult.m` | コメント行だけ | plan.md 4.3（ヘルプの追記だけ） |
| E7d | 整合 | 1014 の `tracking.yAbs*` に今の `detrendTrackedShape` をかけ、セグメントに分けたもの | 1014 の `ycoords` と `isequal`（8枚×2手法） | `detrendTrackedShape` の変更で、今の呼び出し方の結果が変わらない（plan.md 5章の 9-3 と同じ趣旨） |

`experiments/` の既存のファイルの SHA-256（2026-10-27 に記録）：

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
ea471ebf29442c4565ccabc52f6c136233a93270adad7102739864c03132715f  experiments/archive/cycleResult_intpD_0731_trash.mat
115152ac453b6ab6a7b397bfa9395ebfe5266465cc4d863bb17030db78dac3ae  experiments/archive/cycleResult_origD_0731_trash.mat
47d8374b4c2dd537138a33ad42d8caf9316bb2d6fbde916b98614948493f44e6  experiments/archive/cycleResult_rsmplD_0731_trash.mat
```

（`experiments/1026/` は空のフォルダ。）

### 4.4 判定には使わず、報告だけするもの

- 写真ごとの溝の間隔（P2 の参考。試行 25.5〜28.4 px）、両手法の `centers` の差（試行では写真3・7の1本目だけ 1 px）。
- ±1 を超えたサンプルの数（試行：本実装 32・0、正解 31・0。plan.md Q3 で記録だけにすると決定）。
- 同じ列に2点以上あった列の数（試行 0）。
- 正解の重心法と局所的最大値法の差（試行 RMSE 0.233〜0.364 px、相関 0.025〜0.841）。
- 実装担当の報告にある、plan.md 5章の 9-3（`grooveTrack_1cycle.m` の結果が 1014 と同じ）の結果。

## 5. ユーザーが判断する項目

数値の結果だけで合格にしない。評価レポートに「ユーザー確認待ち」と書き、次のファイルと観点を示す。

| ID | 見るもの | 観点 |
|---|---|---|
| U1 | `results/<D1>/grooveTrackN_img1〜8.png`（正解。**評価の前提**）、`results/<D2>/grooveHist_img1〜8.png`（本実装）、`results/<OUT_DATE>/evalMulti_overlay_img1〜8.png`（評価スクリプト。写真を横に4つに分け、本実装＝細い線、正解＝太い半透明の線、本実装の帯に点が無かった列＝青の×、1本目の始点＝黄色の三角。重心法） | 5本の経路が溝の底に沿い、隣の溝に飛び移っていないか。本実装と正解が同じ5本か。正解の図に飛び移りがあれば評価の保留 |
| U2 | `results/<D2>/grooveHist_histogram_img1〜8.png` | 選んだ5つの山が、1本目から y の小さい側へ続く5本の溝か。しきい値の線より上に、余計な山や落ちた山が無いか（写真2には溝の間に 0.17〜0.19 倍の偽の山がある。しきい値 0.3 との余裕） |
| U3 | 5周分の wav（本実装 `results/<D2>/audio_(centroid_method)(original)(hist_5_cycles).wav` など、正解 `results/<D1>/..._(tracking_5_cycles).wav`）、各スクリプトの `_stft.png`、`results/<OUT_DATE>/evalMulti_stft.png`（本実装と正解を並べたもの） | 周の境目（約0.77秒ごと）で音がつながっているか、周の順が正しいか（数値では確かめられなかった。plan.md 2.3 の15）。写真の境目（約0.096秒ごと）のクリック音が #25 の1周分より目立たないか |

`results/<OUT_DATE>/evalMulti_diff_centroid.png`・`evalMulti_diff_localMax.png`（写真×溝ごとの、本実装 − 正解の差）も、どこで違うかを見る参考にする。

## 6. 未決事項

**決定事項（2026-10-28、ユーザーの回答）**：Q-a は (a)（「計画」だけを満たさない場合も不合格にして実装に戻す）、Q-b は (a)（形状の一致の品質のしきい値は #25 の値、RMSE ≤ 0.15 px・相関 ≥ 0.80）。以下は検討の記録。

**Q-a. 「計画」だけを満たさず、「品質」をすべて満たす場合の判定**
- 背景：「計画」は、実装が承認した設計どおりかの確認で、外れても品質としては十分なことがある（例：帯の点の選び方を変えて、1〜2列が計画の試行と違う）。
- 選択肢：
  - (a) **不合格**にして実装に戻す。評価レポートで、計画と違う点と、品質は満たしていることを分けて書く。違いを受け入れるかはユーザーが決め、受け入れるなら criteria.md を改めて承認を取り直す。
  - (b) **ユーザー確認待ち**にして、違いを受け入れるかをユーザーがその場で決める。
- 推奨：(a)。理由：計画の違いが偶然の一致なのか誤りなのかを、実装担当が確かめてから判断したほうが安全。差し戻しは最大3回までなので、受け入れる場合も1往復で済む。
- 止めるか：止めない（評価の段階までに決まればよい）。

**Q-b. 形状の一致（E2c・E2d）の品質のしきい値**
- 背景：本実装と正解は同じ点群から作るので、計画どおりなら RMSE は最大 0.018 px になる。品質の基準を #25 で受け入れた一致度（RMSE ≤ 0.15 px、相関 ≥ 0.80）にすると、却下した `BIN_WIDTH=5`（RMSE 0.186）はかろうじて落ちるが、余裕は小さい（欠損の E3e では 120 列で確実に落ちる）。
- 選択肢：
  - (a) **#25 の値（RMSE ≤ 0.15 px、相関 ≥ 0.80）**：基準データの再現性という、手法によらない根拠がある。#25 の追跡と同じ物差しで比べられる。
  - (b) 厳しくする（例：RMSE ≤ 0.05 px、相関 ≥ 0.95）：`BIN_WIDTH=2`（0.018）は満たし、`BIN_WIDTH=5`（0.186）ははっきり落ちる。ただし根拠は試作の結果だけで、「計画」との区別があいまいになる。
- 推奨：(a)。理由：品質の基準は、試作ではなく基準データの再現性から決める（`docs/rules/evaluation.md`）。計画との細かな違いは「計画」の項目（E2a・E2b）で捕まえられる。
- 止めるか：止めない。

## 7. 仮定と、気づいた点

- 仮定：P3（正解の1本目が 1014 と同じ）を前提にした。クリックが ±8 px 以内なら同じ経路になるので、違えば別の溝をクリックしたことになり、正解の作り直し（`RECLICK_IMAGES`）が要る。
- 仮定：本実装と正解は、どちらも仕組みの上で欠損しない（帯・追跡とも `fillmissing` 済み）ので、補わずにそのまま比べる。評価スクリプトは NaN の数を表示する（試行 0）。
- 仮定：評価スクリプトの `src/` は、プロジェクトのパス上のもの（`currentProject` を開いた状態）を使う。
- **気づいた点（実装担当への申し送り）：plan.md 4.2 の `cycleMethodResult` の説明の誤り。** 「`y_comb` の長さの検証（`sum(cellfun(@numel, ycoords))`）は今のまま（行列でもそのまま使える）」とあるが、`ycoords` が 80×N のとき `sum` は 1×N の行ベクトルを返す。試作では、正しい `y_comb` でも `yCombLength` のエラー（`error` の書式の引数がスカラーでないエラー）になった。逆に1周目だけの `y_comb` は通ってしまう。`sum(..., "all")` などにする必要がある。受け入れテスト `testMethodResultAcceptsSegmentsByCycles`・`testMethodResultChecksYCombOverAllCycles` がこれを確かめる。
- 気づいた点：`findpeaks` は配列の両端のビンを山にしない。クリックした溝より y の大きい側に点が無いと1本目の山を見つけられず（`firstPeakNotFound`）、内側の溝が y の最小の端にあると `notEnoughPeaks` になる。このデータでは両側に溝があるので起きない。受け入れテストの合成データは、plan.md 6章の溝 g=0〜5 に、外側の溝 g=−1 と端の偽の点を足して、この影響を受けないようにした。
- 気づいた点：`MinPeakHeight` を超えるビンが1つも無いとき、`findpeaks` は警告（「MinPeakHeight が無効です」）を出してから空を返す。`findGrooveCenters:noPeaksFound` のエラーの前に警告が出る。テストでは問わないが、先に `max(counts)` で確かめれば警告を避けられる。

## 8. 評価（モードB）の手順

1. `git status --porcelain` が空であることを確かめる。`cd test; results = runAllTests;`（T1）。新しい・変えた `.m` に `checkcode`（T2）。
2. E7a：`sha256sum` で 4.3 の値と比べる。E7b・E7c：`git diff --name-status 2d06a8a -- src scripts test`、`git diff 2d06a8a -- src/saveCycleResult.m`。
3. 正解（ユーザーが作ったもの。どのファイルを使うかはメインの指示）の `meta` と、`results/<D1>/grooveTrackN_img*.png` をユーザーが確かめたことを確認する（P1・U1 の正解）。
4. 本実装のデータを作る：`scripts/grooveHist_Ncycle.m` を `temp/grooveHist_Ncycle_eval<D2>.m` にコピーし、`date = "<D2>"` と `PREV_RESULT_PATH`（＝正解）だけを変えて実行する。実行前に `experiments/<D2>/cycleResult_origD_hist5_<D2>.mat` と `results/<D2>/` の同名の図・wav が無いことを確かめる。実行ログの警告（`saveCycleResult:fileExists`、`trackGroove:longGap` など）を記録する。データを作り終えるまで、git で追跡される場所にファイルを作らない。
5. `scripts/evaluation/multiGroove/compareHistToTracking.m` を `temp/` にコピーし、`GT_DATE`・`GT_FILE`（必要なら）・`HIST_DATE`・`OUT_DATE` だけを変えて実行する（約1分）。P・E1〜E7d の表を得る。
6. `eval-report-<n>.md` に、項目ごとの表（区分つき）、使ったファイル名と `meta.gitCommit`・`gitDirty`、スクリプトのパス、実行日、`runAllTests` の件数、U1〜U3 のファイルと観点を書く。

## 9. 作ったファイル

- `test/unit/MultiGrooveAcceptanceTest.m`：受け入れテスト（41件、合成データのみ）。今の `src/` では40件が失敗する（実装の前なので正常）。`checkcode` の警告 0。
- `scripts/evaluation/multiGroove/compareHistToTracking.m`：評価スクリプト。`checkcode` の警告 0。計画の試行の作り方で作った模擬の正解・本実装（`temp/multiGroove/mock/`）で試運転し、46項目の表・図・CSV が出ることと、試行の値で46項目すべて合格することを確かめた（約1分）。
- `temp/multiGroove/`（git の管理外。参考）：試作（`src/`）、誤らせた試作（`mut/`）、模擬データの作成（`buildMocks.m`）、3.2 の値の計算（`qualityBasis.m`）、評価スクリプトの試運転用のコピー（`compareHistToTracking_mock.m`）、試運転の出力（`evalOut/`）。
