# リネーム／リファクタリング提案

作成日: 2026-07-29 / 提案者: Claude

`src/` の5クラス（`MediaData`, `ImageData`, `AudioData`, `DarknessValue`, `GrooveCandidates`）を対象に、**クラス名・プロパティ名・メソッド名**の改善案をまとめる。
Claude が判断した**優先度の高い順**に並べている（P1 が最優先）。

> 本ドキュメントは提案であり、コードはまだ変更していない。各項目を確認のうえ、採否を判断してほしい。

> **2026-08-04 実施済み**: P1（1-1 `DarknessValue`→`DarknessMap`改名、1-2 `GrooveExtractor`への抽出処理分離）を実施した。分離時のメソッド名は本提案のP1-2/P5の案（`findThresholdIntervals`/`findGrooveBottomIntervals`/`extractByCentroid`/`extractByLocalMax`、`startIdxCells`/`endIdxCells`）を採用している。これによりP4-3・P5-1の一部項目も副次的に完了した（各項目に反映済み）。P2〜P5の残り（プロパティ名統一・`GrooveCandidates`改名・`plotD_x`等の改名・`MediaData`継承の是非）は未着手。詳細はCLAUDE.mdのArchitecture notesを参照。
>
> 本ドキュメントが対象とするのは`src/`の5クラスの命名のみ。同時期に行った`fitGroove`（複数pksデータセット対応・`GrooveSelection`による自動選択・figure省略）のリファクタリングはクラス名の変更を伴わないため対象外。詳細はREADME.mdの「溝の選択（fitGroove）」およびCLAUDE.mdのArchitecture notesを参照。

---

## 現状のAPIサマリ（提案の前提、2026-07-29時点）

| クラス | 種別 | 主なプロパティ | 主なメソッド |
|---|---|---|---|
| `MediaData` | abstract handle | `Name` | `save`(abstract) |
| `ImageData` | value | `imgID`, `img`, `width`, `height` | `showImg` |
| `AudioData` | value | `name`, `signal`, `fs`, `filename` | `audioPlot`, `FFTPlot`, `spectrogramPlot`, `saveAudio`, `playAudio` |
| `DarknessValue` | value | `imgID`, `imgWidth`, `imgHeight`, `nRows`, `nCols`, `rsmplTF`, `scaleFactor`, `dMat`, `diffTF`, `sIdxC`, `eIdxC` | `dResample`, `dInterp`, `setDiffTF`, `plotD_x`, `getStartEndIdx`, `getGrooveBtmIdx`, `extractGrv_cnt`, `extractGrv_max` |
| `GrooveCandidates` | value | `imgID`, `width`, `height`, `rsmplTF`, `scaleFactor`, `pksCell` | `showCandidates` |

> 直近コミットで `rRatio → scaleFactor`、`ddiff → setDiffTF` は対応済み。本提案では扱わない。

### 現在の状態（P1実施後、2026-08-04時点）

| クラス | 種別 | 主なプロパティ | 主なメソッド |
|---|---|---|---|
| `MediaData` | abstract handle | `Name` | `save`(abstract) |
| `ImageData` | value | `imgID`, `img`, `width`, `height` | `showImg` |
| `AudioData` | value | `name`, `signal`, `fs`, `filename` | `audioPlot`, `FFTPlot`, `spectrogramPlot`, `saveAudio`, `playAudio` |
| `DarknessMap`（旧`DarknessValue`） | value | `imgID`, `imgWidth`, `imgHeight`, `nRows`, `nCols`, `rsmplTF`, `scaleFactor`, `dMat`, `diffTF` | `dResample`, `dInterp`, `setDiffTF`, `plotD_x` |
| `GrooveExtractor`（新規） | value | `startIdxCells`, `endIdxCells` | `findThresholdIntervals`, `findGrooveBottomIntervals`, `extractByCentroid`, `extractByLocalMax` |
| `GrooveCandidates` | value | `imgID`, `width`, `height`, `rsmplTF`, `scaleFactor`, `pksCell` | `showCandidates` |

抽出系のプロパティ・メソッドが`DarknessMap`から`GrooveExtractor`に移り、名前もP1-2/P5案どおりに改名された。それ以外（`ImageData`/`AudioData`/`MediaData`/`GrooveCandidates`、および`DarknessMap`自身の`imgWidth`/`imgHeight`等）は提案時点のまま。

---

## P1. `DarknessValue` を `DarknessMap` に改名し、溝抽出の責務を分離する ✅ 実施済み（2026-08-04）

**最優先。名前と実体が一致しておらず、かつ責務過多（God クラス化）している。**

### 1-1. クラス名: `DarknessValue` → `DarknessMap` ✅ 実施済み

- 「Value（単一の値）」という名前に反し、実体は**画像全体の暗さの2次元マップ `dMat`**を保持する。
- 代替案: `DarknessMap`（推奨） / `DarknessField` / `DarknessImage`。
- 2次元の「場」であることが名前から伝わるのが狙い。

### 1-2. 溝抽出メソッドを別クラス `GrooveExtractor` へ分離 ✅ 実施済み

クラス冒頭コメント自身が「別クラスに移すべき」と明記している。以下を `DarknessMap` から切り出す。

| 移動するメソッド | 移動先での案 | 状態 |
|---|---|---|
| `getStartEndIdx` | `findThresholdIntervals` | ✅ 実施済み |
| `getGrooveBtmIdx` | `findGrooveBottomIntervals` | ✅ 実施済み |
| `extractGrv_cnt` | `extractByCentroid` | ✅ 実施済み |
| `extractGrv_max` | `extractByLocalMax` | ✅ 実施済み |

- 抽出時の中間状態プロパティ `sIdxC` / `eIdxC` も併せて `GrooveExtractor` 側へ移す（`startIdxCells`/`endIdxCells`に改名。✅ 実施済み）。
- 分離後の `DarknessMap` は「暗さマップの保持・変換（resample/interp）・表示」に責務を限定できる。

> 影響範囲が大きいため、1-1（改名のみ）と1-2（責務分離）は別コミットに分けることを推奨していたが、実施時は影響箇所（`scripts/`・テスト・ドキュメント）が同一のため1コミットにまとめて実施した。現在の設計はCLAUDE.mdのArchitecture notesを参照。

---

## P2. `GrooveCandidates` を `GrooveCandidateSet` に改名する

- クラス名は原則**単数**（1インスタンス＝1概念）。ヘッダコメントも `GrooveCandidateクラス`（単数）で、コードの複数形と食い違っている。
- 実体は「1画像分の候補点の集合」なので、集合であることを明示する名前が誤解を減らす。
- 代替案: `GrooveCandidateSet`（推奨） / `GrooveCandidateMap`。
- 併せてヘッダコメントの表記もクラス名に一致させる。

---

## P3. `MediaData` 継承の是非を決める（孤立した抽象基底クラス）

- `AudioData` / `ImageData` のコメントに「MediaDataを継承しない」「DO NOT derive」とあり、**抽象基底 `MediaData` が誰にも継承されず孤立**している。
- `MediaData` は `save` を abstract で要求するが、`AudioData` は `saveAudio`、`ImageData` は save なし ── インターフェースが噛み合っていない。
- 命名以前に「基底クラスがあるように見えて機能していない」構成が読み手を最も惑わせる。以下いずれかを選ぶ:
  - **(A) 削除**: `MediaData` を廃止し、各クラスを独立させる（現状の実態に合わせる）。
  - **(B) 活用**: `AudioData`/`ImageData` に `MediaData` を継承させ、`save` インターフェースに統一（`saveAudio` → `save`）。
- どちらを選ぶかで下位の命名（`saveAudio` の扱い）が変わるため、P5 より先に方針を確定させたい。

---

## P4. プロパティ命名をクラス間で統一する

同じ概念が別名になっており、データが伝播するクラス群として一貫性を欠く。

### 4-1. 幅・高さの統一

| クラス | 現状（幅 / 高さ） | 提案 | 状態 |
|---|---|---|---|
| `ImageData` | `width` / `height` | `width` / `height` | - |
| `DarknessMap`（旧`DarknessValue`） | `imgWidth` / `imgHeight` | `width` / `height` | 未着手 |
| `GrooveCandidates` | `width` / `height` | `width` / `height` | - |

- `DarknessMap` の `imgWidth`/`imgHeight` を `width`/`height` に揃える（`img` 接頭辞は不要）。P1では扱わなかったため引き続き未着手。

### 4-2. ケーシングの統一

- `MediaData.Name`（PascalCase）と `AudioData.name`（lowercase）が不統一。
- MATLAB のプロパティは **camelCase** に統一する（`Name` → `name`）。

### 4-3. 略語プロパティの明確化

| 現状 | 提案 | 理由 | 状態 |
|---|---|---|---|
| `rsmplTF` | `isResampled` | `TF` 接尾より論理値の意図が明確。`is` 接頭で真偽が伝わる | 未着手（`DarknessMap`に残存） |
| `sIdxC` / `eIdxC` | `startIdxCells` / `endIdxCells` | 略語 `C`（cell）と `s`/`e` を展開 | ✅ 実施済み（P1-2で`GrooveExtractor`へ移動と同時に改名） |
| `pksCell` | `peakCells` | `pks` を展開 | 未着手（`GrooveCandidates`に残存） |
| `dMat` | `darknessMat` or `dMat`（据え置き可） | 中心データ。P1改名時に合わせて検討 | 据え置き（P1で`dMat`のまま維持） |

---

## P5. メソッド命名を統一する

### 5-1. アンダースコア＋略語を camelCase に

| 現状 | 提案 | 状態 |
|---|---|---|
| `plotD_x` | `plotDarknessColumn` / `plotColumn` | 未着手（`DarknessMap`に残存） |
| `extractGrv_cnt` | `extractByCentroid`（P1で移動先の名前と統一） | ✅ 実施済み（`GrooveExtractor.extractByCentroid`） |
| `extractGrv_max` | `extractByLocalMax`（同上） | ✅ 実施済み（`GrooveExtractor.extractByLocalMax`） |

### 5-2. 表示系メソッドの命名パターン統一

- 現状 `audioPlot` / `FFTPlot` / `spectrogramPlot`（名詞+Plot）と `showImg` / `showCandidates`（show+名詞）が混在。
- どちらかに寄せる。案として **`plot〜`** に統一:
  - `audioPlot` → `plotWaveform`
  - `FFTPlot` → `plotFFT`（頭字語は大文字許容、ただし先頭は小文字）
  - `spectrogramPlot` → `plotSpectrogram`
- あわせて `showImg` → `plotImage` などに寄せると、全クラスで「描画は `plot〜`」と統一できる。

### 5-3. `save` インターフェースの統一（P3の方針に依存）

- P3 で (B) を選ぶ場合: `saveAudio` → `save` に統一し `MediaData` の抽象メソッドを実装。
- (A) を選ぶ場合: `saveAudio` のままでよい。

---

## 実施順の推奨

1. ~~**P1-1**（`DarknessValue` → `DarknessMap` 改名のみ）~~ ✅ 実施済み（2026-08-04）
2. ~~**P1-2**（`GrooveExtractor` 分離）~~ ✅ 実施済み（2026-08-04、1-1と同時）
3. **P3 の方針決定**（継承を残すか消すか）── 下位の命名（`saveAudio`の扱い）が変わるため、残りの項目より先に確定させたい。
4. **P2**（`GrooveCandidates` → `GrooveCandidateSet`）。
5. **P4**（プロパティ統一。残るのは`DarknessMap.imgWidth/imgHeight`・`MediaData.Name`ケーシング・`pksCell`・`rsmplTF`）── 参照箇所が多いので単独コミットで。
6. **P5**（メソッド命名統一。残るのは`plotD_x`・表示系メソッドの統一・P3依存の`save`統一）。

> 各ステップ後に `cd test; runAllTests` で回帰確認する。`scripts/`（archive 含む）とテストの参照も同時に更新が必要。
