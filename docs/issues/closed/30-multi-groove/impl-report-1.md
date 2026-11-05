- 段階: 実装
- 作成者: implementer
- 作成日: 2026-10-28
- 入力: issue #30、[`./README.md`](./README.md)（決定事項）、[`./plan.md`](./plan.md)（承認済み）、[`./criteria.md`](./criteria.md)（承認済み）、`test/unit/MultiGrooveAcceptanceTest.m`、`scripts/evaluation/multiGroove/compareHistToTracking.m`、メインからの依頼文（実装1回目）
- 状態: 下書き

# #30 実装レポート（1回目）

## 1. 結論

- `plan.md` 5章の手順0〜10をすべて終えた。
- `cd test; results = runAllTests;`：**217件すべて通過**（失敗0・未完了0）。受け入れテスト `MultiGrooveAcceptanceTest` は **41/41 通過**。
- 書いた・変えた `.m`（12ファイル）の `checkcode` の警告は **0件**。
- 計画の誤り（criteria.md 7章）を直した：`cycleMethodResult` の `y_comb` の長さの検証を `sum(cellfun(@numel, ycoords), "all")` にした。
- 実データでの動作確認（手順9-1〜9-3）は、すべて計画の付録 A.5・A.7・A.10 の値と一致した（4章）。`experiments/` には何も保存していない（`experiments/1028/` も作っていない）。

## 2. 変更したファイル

| 区分 | パス | 要点 |
|---|---|---|
| 新規 | `src/findGrooveCenters.m` | plan 4.2 のとおり。`max(counts) < MinPeakHeight` なら `findpeaks` を呼ばずに `noPeaksFound`（`findpeaks` の警告 `signal:findpeaks:largeMinPeakHeight` を出さないため。criteria 7章の指摘） |
| 新規 | `src/extractGrooveBands.m` | plan 4.2 のとおり。中心から遠い順に代入して、同じ列では最も近い点を残す。帯の中に点のある列が2列未満なら `tooFewPoints` |
| 新規 | `src/extractMultiGroove.m` | plan 4.2 のとおり。`numGrooves == 1` ならヒストグラムを作らない。`info.numDuplicateCols` は1本目を0にした `(1, numGrooves)` |
| 新規 | `scripts/grooveHist_Ncycle.m` | 本実装（plan 4.1・4.4・4.5）。`extractMultiGroove` の呼び出しと図はスクリプト末尾のローカル関数（`runMultiGroove`・`savePathFigure`・`saveHistogramFigure`）にした |
| 新規 | `scripts/grooveTrack_Ncycle.m` | 正解データ用（plan 4.2 の最後・4.4・4.5）。`sameGroove`・`grooveSkipped` の警告、`RECLICK_IMAGES`、`GUIDE_RESULT_PATH`、左端の拡大表示 |
| 新規 | `test/unit/FindGrooveCentersTest.m`（8件）、`ExtractGrooveBandsTest.m`（7件）、`ExtractMultiGrooveTest.m`（8件） | unitテスト（合成データ） |
| 変更 | `src/detrendTrackedShape.m` | 2つ目の出力 `trend`（`p`・`S`・`mu`・`degree`）。`nargout >= 2` のときだけ組み立てる。1つ目の出力の計算は変えていない |
| 変更 | `src/cycleMethodResult.m` | `xcoords`・`ycoords` の検証を `(:,:) cell` にし、ベクトルなら列に直す。形の一致・`pts` の数と行の数の一致を `sizeMismatch` で確かめる。`y_comb` の長さは `"all"` で全周の合計と比べる。ヘルプに N周分の説明 |
| 変更（コメントのみ） | `src/saveCycleResult.m` | ヘルプの `result.centroid` と `GrooveSelection` の説明に追記。コードの差分なし |
| 変更 | `test/unit/DetrendTrackedShapeTest.m`（+2件）、`test/unit/CycleResultTest.m`（+3件） | `trend` の確認、N周分の保存・読み込み、形の違い、1周分が今までと同じこと |
| 変更 | `README.md` | 処理の流れ、`src/`・`scripts/` の一覧、新しい節「複数本の溝の抽出（N周分）」、「1周分の実験結果の保存」の表（`ycoords` の形、`grooveSelection.multiGroove`） |
| 変更 | `CLAUDE.md` | Architecture notes に N周分の流れの項目を1つ追加 |

`git diff --name-status 2d06a8a -- src scripts test` に出るのは、上の新規・変更のファイルだけ（「触らないもの」の差分なし）。

## 3. 計画との違い

1. **`cycleMethodResult` の `y_comb` の長さの検証**（criteria.md 7章・依頼文の指示）：plan 4.2 の「今のまま」ではなく `sum(cellfun(@numel, ycoords), "all")` にした。受け入れテスト `testMethodResultAcceptsSegmentsByCycles`・`testMethodResultChecksYCombOverAllCycles` が通る。
2. **`findGrooveCenters` で `findpeaks` の前に `max(counts)` を確かめる**：plan 4.2 の手順2は「`findpeaks` の結果が空ならエラー」だが、その前に `findpeaks` が警告を出すので、先に確かめるようにした（criteria.md 7章の「気づいた点」）。エラーの識別子・条件は計画どおり。
3. **確認用の図のラベルの解釈系**：`setDefaultIntrpr` で LaTeX になっているため、日本語の軸ラベル・しきい値の線のラベルは `"Interpreter","none"` にした（出力の数値は変わらない）。
4. **ヒストグラムの図の縦軸**：画像と同じ向き（y の小さい側を上、`YDir reverse`）にし、範囲は `[centers(N)-20, centers(1)+20]` とした（plan 4.5 の「`centers(N)−20` から `+20` px」をこう解釈した）。

ほかは計画どおり。#28（手順0）：`git log master --oneline -1 -- src/resultDir.m` は空（master に未反映）なので、`mkdirFromDate`・`experimentDir` を使った。

## 4. 確認の結果

### checkcode

`src/detrendTrackedShape.m`・`findGrooveCenters.m`・`extractGrooveBands.m`・`extractMultiGroove.m`・`cycleMethodResult.m`・`saveCycleResult.m`、`scripts/grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m`、`test/unit/FindGrooveCentersTest.m`・`ExtractGrooveBandsTest.m`・`ExtractMultiGrooveTest.m`・`DetrendTrackedShapeTest.m`・`CycleResultTest.m`：すべて0件。

### runAllTests

217件、通過217・失敗0・未完了0（`MultiGrooveAcceptanceTest` 41/41、`StaticAnalysisTest` も通過）。

### 実データでの動作確認（2026-10-28、日付 `1028`）

実行前に `results/1028/`・`experiments/1028/` が無いことを確かめた。`temp/` のコピーでは、`date`・`PREV_RESULT_PATH`・保存の行（`saveCycleResult` を `matPath = "";` に置き換え）に加えて、`expDir = experimentDir(...,Create=false)` にした（`experimentDir` は既定で `experiments/<日付>/` の空のフォルダを作るため。仮定 A を参照）。実行後も `experiments/1028/` は無い。

**9-1 本実装**（`temp/grooveHist_Ncycle_check1028.m`、`PREV_RESULT_PATH` = `experiments/1014/cycleResult_origD_track_1014.mat`。約37秒）

- 1周目 `ycoords_cnt(:,1)`・`ycoords_max(:,1)` は 1014 の `centroid.ycoords`・`localMax.ycoords` と `isequal`（両方 true）。`tracking.yAbsCnt/Max` も `isequal`。
- 写真ごとの `centers`（8×5）は付録 A.5 の表と同じ（局所的最大値法の写真3・7の1本目が −0.5 であることも同じ）。
- 帯の中で点が無かった列の数は付録 A.5 の表と同じ（両手法とも）。1本目の欠損は `[0 7 6 0 0 4 0 0]`。
- 同じ列に2点以上あった列：0（両手法・全写真）。
- `fs = 41729` Hz。±1 を超えたサンプル：重心法 32、局所的最大値法 0（全 160,495 サンプル）。
- `ycoords` は 80×5、`res_cnt.ycoords` も 80×5（`cycleMethodResult` が通った）。`vertcat(shapes{:})` と `vertcat(ycoords{:})` の一致の確認もスクリプト内で通った。
- `seeds` は 1014 と `isequal` ではない：1014 の `seeds` の x はクリックした x（26, 30, 97, …）のまま保存されており、本実装は規則どおり x=1。y は8枚とも同じ（README の既存の記述「2026-10-26より前に作ったファイルでは、xにクリックしたxがそのまま入っている」のとおり）。
- 警告：`MATLAB:audiovideo:audiowrite:dataClipped`（重心法の wav で ±1 を超えた32サンプルが切り捨て。Q3 で許容済み）の1件だけ。

**9-2 正解データ用**（`temp/grooveTrack_Ncycle_check1028.m`。`needClick = false` にし、`prevSeedsY` に付録 A.10 の `seedsY` を直接入れた。約26秒）

- 1周目は 1014 と `isequal`（両手法）。
- 2〜5本目の `yAbsCnt`・`yAbsMax` は、9-1 の本実装の `yAbs` と、**重心法の写真8・5本目を除いて `isequal`**。除いた1本は **x=2314 の1列だけ**が違う。点を採れた列の違いは「本実装で採れて正解で採れない」1列だけ（逆は0）。付録 A.5 のとおり。
- ±1 を超えたサンプル：重心法 31、局所的最大値法 0。
- `grooveTrack_Ncycle:sameGroove`・`grooveSkipped` の警告は出なかった。警告は `MATLAB:audiovideo:audiowrite:dataClipped` の1件だけ。

**9-3 回帰**（`temp/grooveTrack_1cycle_check1028.m`、`PREV_RESULT_PATH` = 1014。約21秒）

- `ycoords_cnt`・`ycoords_max` は 1014 と `isequal`（両方 true）。`detrendTrackedShape`・`cycleMethodResult` の変更で既存の結果は変わらない。
- 警告は `MATLAB:audiovideo:audiowrite:dataClipped` の1件だけ（#25 と同じ）。

**目視**：`results/1028/grooveHist_img2.png`・`grooveHist_histogram_img2.png`・`grooveTrackN_img8.png` を見た。5本の経路が溝に沿い、ヒストグラムでは選んだ5つの山がしきい値の線より上にある（写真2の溝の間の偽の山は線より下）。

## 5. 評価担当への申し送り

- 動作確認で作ったファイル（`results/1028/`。正式なデータではない）：`grooveHist_img1〜8.png`、`grooveHist_histogram_img1〜8.png`、`grooveTrackN_img1〜8.png`、`grooveTrack_img1〜8.png`（9-3）、`audio_(centroid_method)(original)(hist_5_cycles)*`・`(tracking_5_cycles)*`・`(tracking)*` の wav・`_amp`・`_fft`・`_stft`（`.fig`・`.png`）、局所的最大値法も同様。**評価で D1・D2 に `1028` を使うと、これらと同じ名前になる**ので、別の日付にするか、メインに扱いを確かめてほしい。
- `temp/` のコピー（消さずに残した）：`temp/grooveHist_Ncycle_check1028.m`、`temp/grooveTrack_Ncycle_check1028.m`、`temp/grooveTrack_1cycle_check1028.m`。
- 正式なデータの作成（plan 7.1）では、リポジトリのスクリプトの `expDir = experimentDir(proj.RootFolder,date)` はそのまま（`experiments/<日付>/` を作って保存する）。
- 見てほしい点：E2b・E4a（余裕が小さい項目）。動作確認では計画の試行と同じ値になった。
- `grooveSelection.seeds` の x は1（本実装・正解とも）。正解データの P4 の確認は `[1, 正解の1本目のクリックの y]` と比べればよい。

## 6. 未決事項・仮定

- 未決事項：なし。
- **仮定 A**：動作確認の `temp/` のコピーで、`experimentDir(...,Create=false)` にした（依頼文の「保存の行」の範囲の変更とみなした）。そのままだと `experiments/1028/` という空のフォルダが作られ、`docs/rules/data.md` の「`data/`・`experiments/` に新しいファイルを作らない」に触れるため。リポジトリのスクリプトは変えていない。
- **仮定 B**：plan 4.5 のヒストグラムの図の範囲「`centers(N)−20` から `+20` px」を、`[centers(N)-20, centers(1)+20]`（選んだ N 個の山の外側に 20 px ずつ）と解釈した。図だけの話で、数値の出力は変わらない。
- 自分で決めたこと（後の作業に影響しうるもの）：
  - `findGrooveCenters` の `BinWidth`・`MinPeakHeight` は既定値なし（`findGrooveCenter` と同じ。省略すると MATLAB の `MATLAB:nonExistentField` になる）。
  - `extractGrooveBands` の `info.numMissing` は `(1, numel(centers))`。`centers` が空なら空の出力を返す（エラーにしない）。
  - `extractMultiGroove` の `info.numDuplicateCols` は `numGrooves == 1` のとき `0`。
  - `grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m` は、写真ごとの確認の表示に加え、`vertcat(shapes{:})` と `vertcat(ycoords{:})` が違えば `<スクリプト名>:orderMismatch` で止まる。
  - `grooveTrack_Ncycle.m` の再現の検証：`seedsY` が無い、または大きさが `NUM_IMAGES × NUM_GROOVES` でなければ `grooveTrack_Ncycle:noSeeds`（plan は列の数だけを挙げていたが、行の数も確かめた）。
