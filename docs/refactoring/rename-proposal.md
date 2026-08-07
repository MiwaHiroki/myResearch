# リネーム／リファクタリング提案

作成日: 2026-07-29 / 提案者: Claude

`src/` の5クラス（`MediaData`, `ImageData`, `AudioData`, `DarknessValue`, `GrooveCandidates`）を対象に、**クラス名・プロパティ名・メソッド名**の改善案をまとめる。
Claude が判断した**優先度の高い順**に並べている（P1 が最優先）。

> 本ドキュメントは提案であり、コードはまだ変更していない。各項目を確認のうえ、採否を判断してほしい。

> **2026-08-04 実施済み**: P1（1-1 `DarknessValue`→`DarknessMap`改名、1-2 `GrooveExtractor`への抽出処理分離）を実施した。分離時のメソッド名は本提案のP1-2/P5の案（`findThresholdIntervals`/`findGrooveBottomIntervals`/`extractByCentroid`/`extractByLocalMax`、`startIdxCells`/`endIdxCells`）を採用している。これによりP4-3・P5-1の一部項目も副次的に完了した（各項目に反映済み）。
>
> **2026-08-07 実施済み**: P3を選択肢**(A) 削除**で実施した。`MediaData`は`src/archive/`へ、その単体テストは`test/archive/`へ退避し、`src/`のデータクラスは継承関係を持たない独立した値クラスに統一した。これによりP4-2・P5-3も解消済み（各項目に反映済み）。
>
> **2026-08-07 実施済み**: P2を実施した。ただし採用した名前は提案の`GrooveCandidateSet`ではなく`GroovePointCloud`（併せて`showCandidates`→`showPoints`）。理由は本クラスが「溝底の点」を保持することを主張すべきであり、将来的に点群のクラスタリングメソッドを追加する計画があるため（MATLAB組み込みの`pointCloud`と`pcsegdist`が命名の前例）。詳細はCLAUDE.mdのArchitecture notesを参照。残るのはP4-1・P4-3の一部・P5-1/5-2。
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

### 現在の状態（P1・P3実施後、2026-08-07時点）

| クラス | 種別 | 主なプロパティ | 主なメソッド |
|---|---|---|---|
| `ImageData` | value | `imgID`, `img`, `width`, `height` | `showImg` |
| `AudioData` | value | `name`, `signal`, `fs`, `filename` | `audioPlot`, `FFTPlot`, `spectrogramPlot`, `saveAudio`, `playAudio` |
| `DarknessMap`（旧`DarknessValue`） | value | `imgID`, `imgWidth`, `imgHeight`, `nRows`, `nCols`, `rsmplTF`, `scaleFactor`, `dMat`, `diffTF` | `dResample`, `dInterp`, `setDiffTF`, `plotD_x` |
| `GrooveExtractor`（新規） | value | `startIdxCells`, `endIdxCells` | `findThresholdIntervals`, `findGrooveBottomIntervals`, `extractByCentroid`, `extractByLocalMax` |
| `GroovePointCloud`（旧`GrooveCandidates`） | value | `imgID`, `width`, `height`, `rsmplTF`, `scaleFactor`, `pksCell` | `showPoints`（旧`showCandidates`） |

> `MediaData`はP3(A)により`src/archive/MediaData.m`へ退避したため一覧から外した。現在`src/`のデータクラスは継承関係を持たない独立した値クラスのみ。

抽出系のプロパティ・メソッドが`DarknessMap`から`GrooveExtractor`に移り、名前もP1-2/P5案どおりに改名された。`GrooveCandidates`はP2により`GroovePointCloud`へ改名済み。それ以外（`ImageData`/`AudioData`、および`DarknessMap`自身の`imgWidth`/`imgHeight`等）は提案時点のまま。

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

## P2. `GrooveCandidates` を改名する ✅ 実施済み（2026-08-07、`GroovePointCloud`を採用）

- クラス名は原則**単数**（1インスタンス＝1概念）。ヘッダコメントも `GrooveCandidateクラス`（単数）で、コードの複数形と食い違っている。
- 実体は「1画像分の候補点の集合」なので、集合であることを明示する名前が誤解を減らす。
- 代替案: `GrooveCandidateSet` / `GrooveCandidateMap`。

**実施内容**

- 検討の結果、提案の`GrooveCandidateSet`ではなく**`GroovePointCloud`**を採用した。理由は次の2点:
  - このクラスが保持するのは「候補」ではなく「溝底として抽出された点」であることを主張すべき（論文用語の「ピーク点」もdescriptiveでないため採用しなかった）。
  - 将来このクラスに点群のクラスタリングメソッドを追加する計画があり、MATLAB組み込みの`pointCloud`クラス（`pcsegdist`等でクラスタリングされる対象）が命名の前例になる。
- 併せて `showCandidates` → `showPoints` に改名（クラス名との一貫性のため）。
- ヘッダコメントの表記もクラス名に一致させた。

---

## P3. `MediaData` 継承の是非を決める（孤立した抽象基底クラス） ✅ 実施済み（2026-08-07、(A)削除を採用）

- `AudioData` / `ImageData` のコメントに「MediaDataを継承しない」「DO NOT derive」とあり、**抽象基底 `MediaData` が誰にも継承されず孤立**している。
- `MediaData` は `save` を abstract で要求するが、`AudioData` は `saveAudio`、`ImageData` は save なし ── インターフェースが噛み合っていない。
- 命名以前に「基底クラスがあるように見えて機能していない」構成が読み手を最も惑わせる。以下いずれかを選ぶ:
  - **(A) 削除**: `MediaData` を廃止し、各クラスを独立させる（現状の実態に合わせる）。← **採用**
  - **(B) 活用**: `AudioData`/`ImageData` に `MediaData` を継承させ、`save` インターフェースに統一（`saveAudio` → `save`）。
- どちらを選ぶかで下位の命名（`saveAudio` の扱い）が変わるため、P5 より先に方針を確定させたい。

**実施内容（(A)削除）**

- `src/MediaData.m` → `src/archive/MediaData.m` へ退避（削除ではなく参照用に残置）。
- 単体テスト `test/unit/MediaDataTest.m` と補助クラス `test/unit/helpers/ConcreteMediaData.m` → `test/archive/` へ移動。`runAllTests` は `test/unit/` のみを探索するため対象外になるが、`PathFixture` を `src/archive/` 向けに直してあるので `runtests('test/archive/MediaDataTest.m')` で手動実行すれば通る。
- `AudioData.m` / `ImageData.m` の冒頭コメントを、継承関係を持たない独立した値クラスである旨に書き換え。
- これに伴い P4-2（`MediaData.Name` のケーシング）と P5-3（`save` インターフェース統一）は対応不要になった。

---

## P4. プロパティ命名をクラス間で統一する

同じ概念が別名になっており、データが伝播するクラス群として一貫性を欠く。

### 4-1. 幅・高さの統一

| クラス | 現状（幅 / 高さ） | 提案 | 状態 |
|---|---|---|---|
| `ImageData` | `width` / `height` | `width` / `height` | - |
| `DarknessMap`（旧`DarknessValue`） | `imgWidth` / `imgHeight` | `width` / `height` | 未着手 |
| `GroovePointCloud`（旧`GrooveCandidates`） | `width` / `height` | `width` / `height` | - |

- `DarknessMap` の `imgWidth`/`imgHeight` を `width`/`height` に揃える（`img` 接頭辞は不要）。P1では扱わなかったため引き続き未着手。

### 4-2. ケーシングの統一 ✅ 解消済み（2026-08-07、P3(A)により対応不要）

- `MediaData.Name`（PascalCase）と `AudioData.name`（lowercase）が不統一。
- MATLAB のプロパティは **camelCase** に統一する（`Name` → `name`）。
- → P3で`MediaData`を`src/archive/`へ退避したため、`src/`に残るプロパティは全てcamelCaseになり不統一は解消した。

### 4-3. 略語プロパティの明確化

| 現状 | 提案 | 理由 | 状態 |
|---|---|---|---|
| `rsmplTF` | `isResampled` | `TF` 接尾より論理値の意図が明確。`is` 接頭で真偽が伝わる | 未着手（`DarknessMap`に残存） |
| `sIdxC` / `eIdxC` | `startIdxCells` / `endIdxCells` | 略語 `C`（cell）と `s`/`e` を展開 | ✅ 実施済み（P1-2で`GrooveExtractor`へ移動と同時に改名） |
| `pksCell` | `peakCells` | `pks` を展開 | 未着手（`GroovePointCloud`に残存） |
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

- 現状 `audioPlot` / `FFTPlot` / `spectrogramPlot`（名詞+Plot）と `showImg` / `showPoints`（show+名詞）が混在。
- どちらかに寄せる。案として **`plot〜`** に統一:
  - `audioPlot` → `plotWaveform`
  - `FFTPlot` → `plotFFT`（頭字語は大文字許容、ただし先頭は小文字）
  - `spectrogramPlot` → `plotSpectrogram`
- あわせて `showImg` → `plotImage` などに寄せると、全クラスで「描画は `plot〜`」と統一できる。

### 5-3. `save` インターフェースの統一（P3の方針に依存） ✅ 解消済み（2026-08-07、P3(A)により対応不要）

- P3 で (B) を選ぶ場合: `saveAudio` → `save` に統一し `MediaData` の抽象メソッドを実装。
- (A) を選ぶ場合: `saveAudio` のままでよい。
- → P3で(A)を採用したため、`saveAudio` のまま据え置く。

---

## 実施順の推奨

1. ~~**P1-1**（`DarknessValue` → `DarknessMap` 改名のみ）~~ ✅ 実施済み（2026-08-04）
2. ~~**P1-2**（`GrooveExtractor` 分離）~~ ✅ 実施済み（2026-08-04、1-1と同時）
3. ~~**P3 の方針決定**（継承を残すか消すか）~~ ✅ 実施済み（2026-08-07、(A)削除を採用）
4. ~~**P2**（`GrooveCandidates` → `GroovePointCloud`）~~ ✅ 実施済み（2026-08-07）
5. **P4**（プロパティ統一。残るのは`DarknessMap.imgWidth/imgHeight`・`pksCell`・`rsmplTF`）── 参照箇所が多いので単独コミットで。
6. **P5**（メソッド命名統一。残るのは`plotD_x`・表示系メソッドの統一）。

> 各ステップ後に `cd test; runAllTests` で回帰確認する。`scripts/`（archive 含む）とテストの参照も同時に更新が必要。
