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

An installed MATLAB is available through the `mcp__matlab__*` tools (static analysis, running scripts/tests). MATLAB is visible to the user and figures render in its UI; prefer these tools over asking the user to run code by hand.

## Working conventions

- **Open `Research.prj` first.** Scripts assume the MATLAB project is loaded and resolve paths from the project root:
  ```matlab
  proj = currentProject();
  rootFolder = proj.RootFolder;
  ```
  Base all path construction on `rootFolder`; do not hard-code absolute paths.
- **`scripts/` are interactive, with an unattended escape hatch.** The `fitGroove` step calls `ginput` to have the user click the groove center with the mouse — these scripts cannot run fully unattended *unless* a previous `cycleResult_*.mat`'s `grooveSelection.p1`/`.p2` is replayed (see the `fitGroove` architecture note below), in which case `ginput` and figure creation are both skipped.
- Outputs go to `results/<date>/`, created via `mkdirFromDate(rootFolder, "MMDD")`.
- `data/`, `results/`, and `CLAUDE.md` are gitignored; input images and generated output are not committed.

## Architecture notes

- **Value classes, not handles — and no inheritance.** `src/` classes (`ImageData`, `DarknessMap`, `GrooveExtractor`, `GroovePointCloud`, `AudioData`) are plain `classdef` value types with no common base class. Transform methods return a modified copy (e.g. `newObj = dResample(obj,p,q)`, `obj = setDiffTF(obj,D_THRESH)`); reassign the result — mutating in place does nothing. Constructors are written to accept zero args so arrays can be preallocated (`allImg(N,1) = ImageData()`). An abstract `MediaData` base class used to exist but was never inherited from; it now sits unused in `src/archive/MediaData.m` (its test moved to `test/archive/`) — do not reintroduce inheritance without a reason.
- **`DarknessMap` holds the darkness matrix; `GrooveExtractor` finds groove bottoms in it.** `DarknessMap` holds `dMat = 1 - img/255` and handles upsampling/display: `dResample`/`dInterp` (upsampling) → `setDiffTF(D_THRESH)` (threshold crossings) → `plotD_x`. `GrooveExtractor` is a separate value class that consumes a `DarknessMap` instance passed into each call (it does not copy `dMat`, which can reach ~2GB after upsampling): `findThresholdIntervals(map,x)` → `findGrooveBottomIntervals(map,x,firstIdx,lastIdx,WIDTH_THRESH)` (candidate intervals, held in the extractor's own `startIdxCells`/`endIdxCells`) → `extractByCentroid(map,x)` / `extractByLocalMax(map,x)`. Typical call-site idiom:
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
- **`scaleFactor` scaling is load-bearing.** After resample/interp, `scaleFactor.row` is the vertical (across-groove) scale factor. Extracted y-coordinates are mapped back to original image space with `(idx - 1) / scaleFactor.row + 1`. Any new detection method must apply the same inverse scaling.
- **Two detection methods × two upsampling methods.** Centroid vs. local-max, and resample vs. interp2, are compared throughout — most `scripts/` exist to run some subset of that 2×2 matrix. `_1cycle` scripts produce a full revolution of audio; the non-`1cycle` ones inspect a single image segment.
- One record image = 8 photos × 10 horizontal splits = 80 segments; scripts iterate `TOTAL_SEGMENTS = 80`.
- `scripts/archive/`, `src/archive/`, and `test/archive/` hold superseded code kept for reference (not wired into the live pipeline; `checkStaticAnalysis` skips any `archive` folder and `runAllTests` only scans `test/unit/`); `scripts/evaluation/stylus/` compares the restored audio against a physical stylus playback.
