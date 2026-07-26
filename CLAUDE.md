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
runtests('test/unit/DarknessValueTest.m')
runtests('test/unit/DarknessValueTest.m', 'ProcedureName', 'testConstructorComputesDMat')
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
- **`scripts/` are interactive.** The `fitGroove` step calls `ginput` to have the user click the groove center with the mouse — these scripts cannot run fully unattended.
- Outputs go to `results/<date>/`, created via `mkdirFromDate(rootFolder, "MMDD")`.
- `data/`, `results/`, and `CLAUDE.md` are gitignored; input images and generated output are not committed.

## Architecture notes

- **Value classes, not handles.** `src/` classes (`ImageData`, `DarknessValue`, `GrooveCandidates`, `AudioData`) are plain `classdef` value types. Transform methods return a modified copy (e.g. `newObj = dResample(obj,p,q)`, `obj = setDiffTF(obj,D_th)`); reassign the result — mutating in place does nothing. Constructors are written to accept zero args so arrays can be preallocated (`allImg(N,1) = ImageData()`).
- **`DarknessValue` is the core.** It holds `dMat = 1 - img/255` and drives groove-bottom detection: `dResample`/`dInterp` (upsampling) → `setDiffTF(D_th)` (threshold crossings) → `getStartEndIdx`/`getGrooveBtmIdx` (candidate intervals) → `extractGrv_cnt` (centroid) / `extractGrv_max` (local maximum). Header comments note that the index-finding methods arguably belong in a separate class — treat that as known tech debt, not a cleanup target.
- **`scaleFactor` scaling is load-bearing.** After resample/interp, `scaleFactor.row` is the vertical (across-groove) scale factor. Extracted y-coordinates are mapped back to original image space with `(idx - 1) / scaleFactor.row + 1`. Any new detection method must apply the same inverse scaling.
- **Two detection methods × two upsampling methods.** Centroid vs. local-max, and resample vs. interp2, are compared throughout — most `scripts/` exist to run some subset of that 2×2 matrix. `_1cycle` scripts produce a full revolution of audio; the non-`1cycle` ones inspect a single image segment.
- One record image = 8 photos × 10 horizontal splits = 80 segments; scripts iterate `TOTAL_SEGMENTS = 80`.
- `scripts/archive/` is superseded code kept for reference; `scripts/evaluation/stylus/` compares the restored audio against a physical stylus playback.
