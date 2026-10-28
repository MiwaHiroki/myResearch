# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MATLAB project for restoring audio from photographs of an SP (78rpm) record surface. It reads the groove-bottom y-coordinate from column-wise "darkness" of the disc image, chains one revolution together into a waveform, and writes a wav. `README.md` (Japanese) is the authoritative description of the processing pipeline, the `src/` classes/functions, and each `scripts/` entry — read it before making pipeline changes rather than re-deriving intent from code.

## Commands

Run all unit tests (from project root or `test/`):

```matlab
cd test
results = runAllTests;   % discovers test/unit/*Test.m via TestSuite.fromFolder
```

Run a single test class or method:

```matlab
runtests('test/unit/DarknessMapTest.m')
runtests('test/unit/DarknessMapTest.m', 'ProcedureName', 'testConstructorComputesDMat')
```

Tests do **not** need a manual `addpath` — each test class adds `src/` in its `TestClassSetup` via `PathFixture`.

CI: `.github/workflows/matlab-tests.yml` (GitHub Actions) runs `runAllTests` + `assertSuccess` on every PR and every push to `master` (changes touching only `docs/**` or `*.md` are skipped). It uses MATLAB R2024b on `ubuntu-24.04` with only Signal Processing Toolbox, and has no `data/`/`experiments/` — so tests must stay synthetic-data-only and Linux-safe (exact file-name case, no Windows paths).

An installed MATLAB is available through the `mcp__matlab__*` tools (static analysis, running scripts/tests). MATLAB is visible to the user and figures render in its UI; prefer these tools over asking the user to run code by hand.

## Working conventions

- **Claude（メインセッション・サブエージェントとも）は `docs/rules/` のルールに従う。**
  - [`docs/rules/coding.md`](docs/rules/coding.md): プログラムの書き方（命名、構造、引数、コメント、テスト、確認）
  - [`docs/rules/data.md`](docs/rules/data.md): 生データ（`data/`・`experiments/` 配下のすべてのファイル）の扱い、MATLABの実行
  - [`docs/rules/communication.md`](docs/rules/communication.md): ユーザーへの質問の仕方、受け渡しファイル、報告の書き方
  - [`docs/rules/evaluation.md`](docs/rules/evaluation.md): 手法の評価の方法（溝形状の比べ方、正解の考え方、合格基準、受け入れテスト・評価スクリプトの置き場所）
- **Open `Research.prj` first.** Scripts assume the MATLAB project is loaded and resolve paths from the project root:
  ```matlab
  proj = currentProject();
  rootFolder = proj.RootFolder;
  ```
  Base all path construction on `rootFolder`; do not hard-code absolute paths.
- **`scripts/` are interactive, with an unattended escape hatch.** The `fitGroove` step calls `ginput` to have the user click the groove center with the mouse — these scripts cannot run fully unattended *unless* a previous `cycleResult_*.mat`'s `grooveSelection.p1`/`.p2` is replayed (see the `fitGroove` architecture note below), in which case `ginput` and figure creation are both skipped.
- Outputs go to `results/<date>/`, created via `mkdirFromDate(rootFolder, "MMDD")`.
- `data/` and `results/` are gitignored (`CLAUDE.md` is tracked); input images and generated output are not committed. Exception: `results/figures/slides/` (the スライド用の完成図表) is tracked so it can be shared across machines — `results/figures/paper/` and everything else under `results/` (date folders, etc.) stays ignored.
- git操作（コミットメッセージ・ブランチ・PR・worktreeでの並行作業のルール）は [`docs/git-rules.md`](docs/git-rules.md) を参照。worktree内では`data/`・`experiments/`がメインへのジャンクション（共有）なので、削除・上書きに注意。
- タスクはGitHub Issuesで管理している。issueを受け取ったら [`docs/issue-guide.md`](docs/issue-guide.md) の手順に従う（「未決事項」があれば着手前に確認）。ラベルごとのひな型は `.github/ISSUE_TEMPLATE/`。段階を分けて進めるissueの受け渡しファイルは `docs/issues/<番号>-<slug>/`（closeしたら `docs/issues/closed/` へ移す。ルールは [`docs/issues/README.md`](docs/issues/README.md)）。計画→評価基準→実装→評価をサブエージェント（`.claude/agents/` の planner・evaluator・implementer）に任せて進めるときは、[`docs/staged-development.md`](docs/staged-development.md) の手順に従う。
- 進捗レポート（数週間に一度、Googleスライド化する前提のまとめ）は `docs/progress/` 配下で自動更新している。状態は `docs/progress/.state.json`（`current_file`/`next_report_date`/`last_commit`など）で管理し、スケジュールタスク`progress-report-daily`（毎日3時実行、詳細はアプリのスケジュールタスク管理から確認可能）が**masterの**コミット履歴を元に追記し、**masterに**コミットする。作業ブランチをチェックアウト中なら、追跡されているファイルに未コミットの変更が無いときだけ、一時的にmasterへ切り替えてコミットし、元のブランチに戻す。変更があれば、その日は見送って通知する（issue #27）。進捗ログの最新は常にmasterにある（作業ブランチの`docs/progress/`は古いことがある）。進行中の期間ファイル名は`<開始日 YYYY-MMDD>_<次回予定日 MMDD>.md`（`next_report_date`が未定な間は、日付の代わりに文字列`MMDD`をそのまま使い`<開始日>_MMDD.md`とする。`YYYY-MMDD_MMDD`という命名パターンを保ちつつ、未定であることを示すため）。**ユーザーから次回の進捗報告・打ち合わせ予定日を伝えられたら（Claudeから尋ねた場合に限らず、どのセッションでも）、masterをチェックアウトしているセッションでは、`.state.json`の`next_report_date`を更新し、それに合わせて現在の`current_file`を`git mv`でリネームし、`current_file`の値とファイル先頭の見出しも更新すること。作業ブランチやworktreeのセッションでは自分では変えず、masterをチェックアウトしているセッションで更新する必要があることをユーザーに伝えること**（masterの状態と食い違い、マージのときにぶつかるため）。進捗ファイルへの自動commitの扱いは [`docs/git-rules.md`](docs/git-rules.md) の例外規定を参照。

## Git ブランチの安全確認
- 毎回のコミット前に `git branch --show-current` を実行し、返信の中でブランチ名を明記する。
- 「master/main にコミットして」と言われたら、そこへ直接コミットする。基本的には、頼まれない限り新しいブランチは作らない。
- フィーチャーブランチは最新の master からのみ作る（`git fetch && git switch -c <name> origin/master`）。
- 前回確認したときからブランチが変わっていないと決めつけない。進捗ログの定期タスクや並行する worktree によって、セッション中にブランチが切り替わったり master が進んだりすることがある。


## MATLAB の規約
- フォルダを MATLAB プロジェクトの恒久パスに追加しない。各スクリプトが必要なフォルダを `addpath` する。
- 定数は UPPER_SNAKE_CASE（例：`W_TH`）。変数は camelCase で、`iImg` のようなインデックス接頭辞を付ける。
- スライド用の図は、特に指定がなければ 8x8 cm。図を変更したら、MATLAB MCP 経由でスクリプトを実行し、書き出した PNG を目視で確認する（凡例とマーカーの重なりも含む）。
- MATLAB プロジェクトが閉じていたら、スクリプトを実行する前に開き直す。
- scripts/ の現行の命名規則に従い、新しいスクリプトに名前を付ける前に既存ファイルを確認する。

## Windows／自動化の環境
- シェルは Bash ではなく PowerShell であることが多い。無人の定期タスク用に許可ルールを書くときは、`Bash(...)` と `PowerShell(...)` の両方の形と、使われるすべてのフラグの変種（例：`git commit -q`、`git commit -m`）をカバーする。
- 無人ルーチンを「完了」とする前に、実際に試し実行して承認プロンプトが 1 つも出ないことを確認する。
- 日本語を含む `gh issue create`／`gh pr create` では、本文を UTF-8（BOM なし）のファイルに書き出して `--body-file` を使う。ヒアドキュメントは使わない。

## 計画と説明
- 結論を先に述べ、詳細はその後に書く。
- 実装計画では、各手順の目的を説明し、新しく導入する記号や変数はすべて初出時に定義する。
- バグや NaN が起きる理由を述べる前に、コードで確認する。推測で答えない。
- 返答は日本語か英語のみ。それ以外の言語は使わない。


## Architecture notes

- **Value classes, not handles — and no inheritance.** `src/` classes (`ImageData`, `DarknessMap`, `GrooveExtractor`, `GroovePointCloud`, `AudioData`) are plain `classdef` value types with no common base class. Transform methods return a modified copy (e.g. `newObj = dResample(obj,p,q)`, `obj = setDiffTF(obj,D_THRESH)`); reassign the result — mutating in place does nothing. Constructors are written to accept zero args so arrays can be preallocated (`allImg(N,1) = ImageData()`). An abstract `MediaData` base class used to exist but was never inherited from; it now sits unused in `src/archive/MediaData.m` (its test moved to `test/archive/`) — do not reintroduce inheritance without a reason.
- **`DarknessMap` holds the darkness matrix; `GrooveExtractor` finds groove bottoms in it.** `DarknessMap` holds `dMat = 1 - img/255` and handles upsampling/display: `dResample`/`dInterp` (upsampling) → `setDiffTF(D_THRESH)` (threshold crossings) → `plotDarknessColumn`. `GrooveExtractor` is a separate value class that consumes a `DarknessMap` instance passed into each call (it does not copy `dMat`, which can reach ~2GB after upsampling): `findThresholdIntervals(map,x)` → `findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH)` (candidate intervals, held in the extractor's own `startIdxCells`/`endIdxCells`) → `extractByCentroid(map,x)` / `extractByLocalMax(map,x)`. Typical call-site idiom:
  ```matlab
  map = DarknessMap(imgData);
  map = map.setDiffTF(D_THRESH);
  extractor = GrooveExtractor(map);
  for x = 1:map.nCols
      [firstIdx,lastIdx] = extractor.findThresholdIntervals(map,x);
      [extractor,~,~,numPeaks] = extractor.findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH);
      centroidY = extractor.extractByCentroid(map,x);
  end
  ```
- **`fitGroove` takes multiple pks datasets and can skip both `ginput` and figure creation.** `fitGroove(jSegment,fig,p2,w,h,pksCell,opts)` fits a straight line to points inside a user- (or replay-) selected parallelogram and detrends every dataset in `pksCell` (e.g. `{pks_max,pks_cnt}`) with that single fit, so centroid and local-max no longer need separate `ginput` clicks per segment. Passing `opts.P1`/`opts.P2` (both) replaces `ginput` with those points *and* skips all figure/plotting calls entirely — pass `fig=[]` in that path. `_1cycle` scripts persist the per-segment `p1`/`p2` via `saveCycleResult(...,GrooveSelection=struct('p1',allP1,'p2',allP2))` and can replay them from `result.grooveSelection` on a later run (see README "溝の選択（fitGroove）"). The old multi-peak-averaging variant lives at `src/archive/fitGroove_multiPeaks.m`, unintegrated.
- **After `fitGroove`, `findGrooveCenter` → `extractGrooveShape` → `detrendGrooveShape` (or the `extractGrooveWaveform` wrapper that chains all three) turn one `fitGroove`-corrected dataset into a single groove's clean y-shape.** `findGrooveCenter(pksCor,prevCenter,BinWidth=...,MinPeakHeight=...)` picks the histogram peak nearest `prevCenter` (typically `p1(2)`); `extractGrooveShape(pksCor,grooveCenter,xQuery,Tolerance=...)` gathers points within `Tolerance` into a NaN-filled array over `xQuery` and fills gaps with `fillmissing` (`ismember`-based, so `xQuery` can be integer or fractional, e.g. `dInterp`'s `QUERY_STEP` grid); `detrendGrooveShape(points,PolyDegree=...)` (default 3) removes a polynomial trend and recenters to zero mean. Most `_1cycle` scripts and `pkCentroid_interp2.m` call `extractGrooveWaveform` directly; `scripts/pkCentroid_resample.m` only needs the sparse pre-`fillmissing` point cloud, so it calls `findGrooveCenter` alone and keeps its own inline tolerance filter.
- **`scripts/grooveTrack_1cycle.m` replaces `fitGroove` → `extractGrooveWaveform` with per-photo automatic tracking (issue #25).** For each of the 8 photos (10 segments each), `mergeSegmentPoints(ptsArray,QueryStep=...)` concatenates the segments' `GroovePointCloud` points into one `[x y]` array (x shifted by cumulative segment widths) and returns the photo's `xQuery` and per-segment `counts`; `trackGroove(pks,seed,xQuery,...)` starts from one click (`seed`) at the left edge — the script uses only the click's y and pins the seed's x to the photo's first column (`seed = [xQuery(1), y]`, mirroring `fitGroove`'s `[1, p1(2)]`, also when replaying saved seeds/`p1`) so the click's x cannot change the start column — and tracks that groove column by column in both directions (line fit over the last `FitLength` px of accepted points, nearest point within `Tolerance`), returning the gap-filled y over `xQuery`, a `found` mask and `info`; `detrendTrackedShape(points,PolyDegree=9)` removes a polynomial fitted over the whole photo (`polyfit` `[p,S,mu]` form) and recenters to zero mean; the result is split back into the usual 80×1 `ycoords` with `mat2cell(...,counts)`. All length parameters are in original-image px (not columns) so the same values work for `dInterp`'s fractional grid. Clicks are saved as `grooveSelection.seeds` (8×2) alongside `method="tracking"`, `tracking` (params and pre-detrend y), and derived 80×2 `p1`/`p2`; `trackingSeeds(grooveSelection,numSegments)` returns seeds from either the new format or an old manual 80×2 `p1`, so `PREV_RESULT_PATH` can replay either without `ginput`. Only the non-upsampled (`origD`) path is implemented so far. See README "溝の自動追跡（trackGroove）".
- **`scaleFactor` scaling is load-bearing.** After resample/interp, `scaleFactor.row` is the vertical (across-groove) scale factor. Extracted y-coordinates are mapped back to original image space with `(idx - 1) / scaleFactor.row + 1`. Any new detection method must apply the same inverse scaling.
- **Two detection methods × two upsampling methods.** Centroid vs. local-max, and resample vs. interp2, are compared throughout — most `scripts/` exist to run some subset of that 2×2 matrix. `_1cycle` scripts produce a full revolution of audio; the non-`1cycle` ones inspect a single image segment.
- One record image = 8 photos × 10 horizontal splits = 80 segments; scripts iterate `TOTAL_SEGMENTS = 80`.
- `scripts/archive/`, `src/archive/`, and `test/archive/` hold superseded code kept for reference (not wired into the live pipeline; `checkStaticAnalysis` skips any `archive` folder and `runAllTests` only scans `test/unit/`); `scripts/evaluation/stylus/` compares the restored audio against a physical stylus playback.
