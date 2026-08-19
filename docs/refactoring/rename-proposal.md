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
>
> **2026-08-18 実施済み**: P4-3の1行目（`rsmplTF`→`isResampled`）を実施した。提案表は`DarknessMap`のみを対象としていたが、`GroovePointCloud`も自身の`rsmplTF`プロパティを`DarknessMap`からのコピーとして保持しており（コンストラクタで`obj.rsmplTF = dValue.rsmplTF;`）、両クラスの受け渡し地点で名前が食い違うのを避けるため`GroovePointCloud`側も合わせて`isResampled`に改名した（P4-1で`width`/`height`を両クラス揃えて改名した前例を踏襲）。詳細はP4-3の節を参照。
>
> **2026-08-18 実施済み**: P4-3の3行目（`GroovePointCloud.pksCell`→`peakCells`）を実施した。これにより**P4は全項目完了**。詳細はP4-3の節を参照。
>
> **2026-08-19 実施済み**: P5-1（`DarknessMap.plotD_x`→`plotDarknessColumn`）を実施した。詳細はP5-1の節を参照。
>
> **2026-08-19 実施済み**: P5-2（表示系メソッドの命名パターン統一）を実施した。これで**P5は全項目完了**。詳細はP5-2の節を参照。

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

### 現在の状態（P1・P2・P3・P4-1実施後、2026-08-09時点）

| クラス | 種別 | 主なプロパティ | 主なメソッド |
|---|---|---|---|
| `ImageData` | value | `imgID`, `img`, `width`, `height` | `showImg` |
| `AudioData` | value | `name`, `signal`, `fs`, `filename` | `audioPlot`, `FFTPlot`, `spectrogramPlot`, `saveAudio`, `playAudio` |
| `DarknessMap`（旧`DarknessValue`） | value | `imgID`, `width`, `height`（旧`imgWidth`/`imgHeight`）, `nRows`, `nCols`, `isResampled`（旧`rsmplTF`）, `scaleFactor`, `dMat`, `diffTF` | `dResample`, `dInterp`, `setDiffTF`, `plotDarknessColumn`（旧`plotD_x`） |
| `GrooveExtractor`（新規） | value | `startIdxCells`, `endIdxCells` | `findThresholdIntervals`, `findGrooveBottomIntervals`, `extractByCentroid`, `extractByLocalMax` |
| `GroovePointCloud`（旧`GrooveCandidates`） | value | `imgID`, `width`, `height`, `isResampled`（旧`rsmplTF`）, `scaleFactor`, `peakCells`（旧`pksCell`） | `showPoints`（旧`showCandidates`） |

> `MediaData`はP3(A)により`src/archive/MediaData.m`へ退避したため一覧から外した。現在`src/`のデータクラスは継承関係を持たない独立した値クラスのみ。

抽出系のプロパティ・メソッドが`DarknessMap`から`GrooveExtractor`に移り、名前もP1-2/P5案どおりに改名された。`GrooveCandidates`はP2により`GroovePointCloud`へ改名済み。`DarknessMap`の`imgWidth`/`imgHeight`もP4-1により`width`/`height`へ改名済み。P4-3の`rsmplTF`→`isResampled`・`pksCell`→`peakCells`も実施済みで、**P4は全項目完了**。P5-1の`plotD_x`→`plotDarknessColumn`も実施済み。残るのは`ImageData`/`AudioData`のプロパティ名（提案時点のまま）とP5-2（表示系メソッドの命名パターン統一）。

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

### 4-1. 幅・高さの統一 ✅ 実施済み（2026-08-09）

| クラス | 旧（幅 / 高さ） | 現状 | 状態 |
|---|---|---|---|
| `ImageData` | `width` / `height` | `width` / `height` | - |
| `DarknessMap`（旧`DarknessValue`） | `imgWidth` / `imgHeight` | `width` / `height` | ✅ 実施済み |
| `GroovePointCloud`（旧`GrooveCandidates`） | `width` / `height` | `width` / `height` | - |

- `DarknessMap` の `imgWidth`/`imgHeight` を `width`/`height` に改名し、`img` 接頭辞を廃した。プロパティ宣言・コンストラクタ・`dInterp`内のmeshgrid呼び出し、および呼び出し元（`GroovePointCloud`のコンストラクタ・`DarknessMapTest`・`scripts/`内の`origD`/`intpD`参照4ファイル）を更新した。
- **実施方法の特記事項**: `src/DarknessMap.m`本体の3箇所の書き換えは、ローカルLLM（Ollama経由のgemma4, 8B Q4_K_M）に委譲して行った。ただし当初検討した「ファイル全文を渡して書き直させる」方式は記憶`ollama-gemma4-coding-workflow`の運用方針（全文再生成は意図しない改変・脱落のリスクが高い）と相容れないため採用せず、代わりにOllama MCPサーバー（`C:\Users\owner\.gemini\antigravity\scratch\ollama_mcp_server.js`）に**ファイルの一部分だけを安全に書き換える**新ツール`edit_file_with_ollama`を追加した。Claudeが実ファイルから一意なアンカー（`old_string`）を厳密にコピーして渡し、gemma4はそのスニペットの変換後の中身だけを生成、サーバー側で一意一致を確認してから置換・書き込みする設計。3箇所とも1回で正しく変換され（左辺のみ改名し右辺の`imgData.width`等を変えない、というやや紛らわしいケースも含めて正確）、差し戻し・Claudeによる引き取りは発生しなかった。

### 4-2. ケーシングの統一 ✅ 解消済み（2026-08-07、P3(A)により対応不要）

- `MediaData.Name`（PascalCase）と `AudioData.name`（lowercase）が不統一。
- MATLAB のプロパティは **camelCase** に統一する（`Name` → `name`）。
- → P3で`MediaData`を`src/archive/`へ退避したため、`src/`に残るプロパティは全てcamelCaseになり不統一は解消した。

### 4-3. 略語プロパティの明確化

| 現状 | 提案 | 理由 | 状態 |
|---|---|---|---|
| `rsmplTF` | `isResampled` | `TF` 接尾より論理値の意図が明確。`is` 接頭で真偽が伝わる | ✅ 実施済み（2026-08-18） |
| `sIdxC` / `eIdxC` | `startIdxCells` / `endIdxCells` | 略語 `C`（cell）と `s`/`e` を展開 | ✅ 実施済み（P1-2で`GrooveExtractor`へ移動と同時に改名） |
| `pksCell` | `peakCells` | `pks` を展開 | ✅ 実施済み（2026-08-18） |
| `dMat` | `darknessMat` or `dMat`（据え置き可） | 中心データ。P1改名時に合わせて検討 | 据え置き（P1で`dMat`のまま維持） |

**実施内容（`pksCell` → `peakCells`）**

- `src/GroovePointCloud.m`: プロパティ宣言、コンストラクタでの初期化、`showPoints`内の参照を改名。あわせて未使用のコメントアウト済み旧コンストラクタ案（`localMaxMethod`ローカル関数のドラフト。P4-1/P4-3で更新した前例を踏襲）内の`pksCell`参照もすべて`peakCells`に揃えた。
- 呼び出し元（すべて`変数.pksCell`の形でプロパティに実アクセスしているものだけを対象とし、たまたま同名のローカル変数（例: `scripts/photoshop_localMax_1cycle.m`や`scripts/pkCentroid_resample.m`内の`pksCell = cell(...)`という単純代入、`pksCell_r`等の類似名変数）は対象外とした。1件ずつ`変数.pksCell`の形かどうかを確認したうえで含めている）:
  - `test/unit/GroovePointCloudTest.m`（プロパティアクセス8箇所、テストメソッド名`testConstructorInitializesEmptyPksCell`→`testConstructorInitializesEmptyPeakCells`も改名）
  - `test/unit/CycleResultTest.m`（1箇所）
  - `scripts/`側は`GroovePointCloud`を使う`_1cycle`系・比較検討用・`paper/202609asj`配下の図スクリプト計16ファイル（`showPhotoshopGrooveExtraction.m`、`pkCentroid_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`photoshop_centroid_1cycle.m`、`photoshop_localMax_1cycle.m`、`pkCentroid_resample.m`、`pkCentroid_interp2.m`、`darkness3d.m`、`paper/202609asj/fig1_1_grooveBtmOnDarkness3d.m`、`fig1_2_grooveBtmOnImage.m`、`fig3_grooveBtmMethodsOnImage.m`、`fig_GrooveBtmOnImageUpsamplingD.m`、`fig_grvBtmOnImgOrigUpsamplingD.m`）。コメントアウトされた旧実装（ブロックコメント`%{ %}`内や単一行`%`コメント内で`変数.pksCell`の形を保っているもの）も、実体を伴わない参照用コードとはいえプロパティ名との整合を優先し合わせて改名した。一方、`pksCell = cell(...)`のような`findpeaks`ベースの単純ローカル変数（`GroovePointCloud`インスタンスとは無関係）は`photoshop_centroid_1cycle.m`・`photoshop_localMax_1cycle.m`・`pkCentroid_resample.m`に残存しているが、意図的に対象外とした。
  - `src/fitGroove.m`は対象外: この関数の引数`pksCell`（および`arguments`宣言・本体内の参照）は`GroovePointCloud`のプロパティではなく、`{pks_max,pks_cnt}`のような複数データセットを渡すための独立した関数パラメータ（README「溝の選択（fitGroove）」参照）。同名だが別概念のため改名しなかった。
  - `scripts/archive/`・`scripts/paper/202609asj/archive/`配下は対象外（過去の失敗パターンの通り、archiveは意図的に除外）。
- `README.md`の`GroovePointCloud`説明（`pksCell`→`peakCells`、旧名併記）を更新。`CLAUDE.md`は`GroovePointCloud`の`pksCell`に言及していない（`fitGroove`のパラメータ`pksCell`への言及のみで、これは改名対象外のため変更不要）。
- 検証: 変更した18ファイル（`src/GroovePointCloud.m`、テスト2ファイル、`scripts/`15ファイル）すべて`check_matlab_code`で致命的な警告なし（未使用変数系のwarningが数件出た`pkCentroid_interp2.m`・`pkCentroid_resample.m`・`showPhotoshopGrooveExtraction.m`は、diffで変更した行と突き合わせて確認したところ全て本改名と無関係の既存事項）。`cd test; runAllTests`で74件全件成功（回帰なし）。
- `scripts/`は`ginput`や実画像を要するものが多く自動テスト不可なため、`_1cycle`系・`paper/202609asj`配下の図スクリプトは実行結果までは目視確認していない。次回実行時に見た目の崩れがないか確認が必要。

**実施内容（`rsmplTF` → `isResampled`）**

- `src/DarknessMap.m`: プロパティ宣言、コンストラクタでの初期化（`false`）、`dResample`内の設定（`true`）、`plotD_x`内の参照（タイトルへの"resampled"注記の分岐）を改名。あわせて冒頭コメントのメソッド一覧に紛れ込んでいた誤記`isResampled(obj)`（存在しないメソッドとして書かれていた）も削除して整理した。
- `src/GroovePointCloud.m`: 提案表は`DarknessMap`のみを対象としていたが、本クラスも独自に`rsmplTF`プロパティを持ち、コンストラクタで`obj.rsmplTF = dValue.rsmplTF;`と`DarknessMap`から直接コピーしている。コピー元・コピー先で名前が食い違う状態を避けるため、**判断としてこちらも`isResampled`に改名した**（P4-1で`width`/`height`を両クラス揃えて改名した前例と同じ考え方）。プロパティ宣言・コンストラクタ本体・コメントアウトされた旧コンストラクタ案（未使用の参考コードだが同一ファイル内にあるため整合させた）を更新。
- 呼び出し元: `test/unit/DarknessMapTest.m`（3箇所）、`test/unit/GroovePointCloudTest.m`（1箇所）を更新。`scripts/`（`archive`含む）を全文grepしたが`rsmplTF`/`isResampled`の参照はなし。
- 検証: 変更した4ファイルすべて`check_matlab_code`で警告ゼロ（`DarknessMapTest.m`の既存の抑制コメント関連infoは本改名と無関係の既存事項）。`cd test; runAllTests`で74件全件成功（回帰なし）。

---

## P5. メソッド命名を統一する

### 5-1. アンダースコア＋略語を camelCase に ✅ 一部実施済み（`plotD_x`は2026-08-19実施）

| 現状 | 提案 | 状態 |
|---|---|---|
| `plotD_x` | `plotDarknessColumn` / `plotColumn` | ✅ 実施済み（2026-08-19、`plotDarknessColumn`を採用。`DarknessMap`） |
| `extractGrv_cnt` | `extractByCentroid`（P1で移動先の名前と統一） | ✅ 実施済み（`GrooveExtractor.extractByCentroid`） |
| `extractGrv_max` | `extractByLocalMax`（同上） | ✅ 実施済み（`GrooveExtractor.extractByLocalMax`） |

**実施内容（`plotD_x` → `plotDarknessColumn`）**

- 採用名の判断: 提案は`plotDarknessColumn`と`plotColumn`の2案を挙げていたが、**`plotDarknessColumn`を採用**した。理由は`plotColumn`だと読み手がこれが`DarknessMap`のメソッドだと知らなければ「何の列をプロットするのか」が名前だけでは伝わらないため。本コードベースが`extractByCentroid`・`findThresholdIntervals`・`GroovePointCloud`など略語より説明的な名前を一貫して選んできた前例に合わせた。
- `src/DarknessMap.m`: メソッド定義本体（`function p = plotD_x(obj,x,opts)`）と冒頭コメントのメソッド一覧を改名。
- `test/unit/DarknessMapTest.m`: `testPlotDxDrawsLine`→`testPlotDarknessColumnDrawsLine`にテストメソッド名ごと改名（`showCandidates`→`showPoints`改名時の前例を踏襲し、呼び出し箇所`testCase.dMap.plotD_x(1)`も合わせて更新）。
- 呼び出し元: `src/loadCycleResult.m`（ヘッダコメント中の使用例1箇所）、`scripts/paper/202609asj/fig2_darknessProfile.m`（`origD.plotD_x(...)`1箇所）を更新。`scripts/`（`archive`含む）・`test/`全体を`plotD_x`で全文grepし、他に生きた呼び出しがないことを確認した（`test/trash/OOPTest.m`に旧名の言及が残るが、これは`test/trash/`＝廃止済みコードのため対象外とした）。
- `README.md`・`CLAUDE.md`の`DarknessMap`メソッド説明も`plotDarknessColumn`に更新。
- 検証: 変更した4ファイル（`src/DarknessMap.m`、`test/unit/DarknessMapTest.m`、`src/loadCycleResult.m`、`scripts/paper/202609asj/fig2_darknessProfile.m`）すべて`check_matlab_code`で本改名に起因する警告なし（`DarknessMapTest.m`に出た1件のinfoは、既存の抑制コメント`%#ok<NASGU>`に関する無関係な既存事項）。`cd test; runAllTests`で74件全件成功（回帰なし。`StaticAnalysisTest`が`scripts/`側の静的解析も兼ねて通過）。
- `scripts/paper/202609asj/fig2_darknessProfile.m`は実画像を要するため自動テスト不可。次回実行時に図の見た目が崩れていないか目視確認が必要。

### 5-2. 表示系メソッドの命名パターン統一 ✅ 実施済み（2026-08-19）

- 現状 `audioPlot` / `FFTPlot` / `spectrogramPlot`（名詞+Plot）と `showImg` / `showPoints`（show+名詞）が混在。

| 現状 | 提案 | 状態 |
|---|---|---|
| `AudioData.audioPlot` | `plotWaveform` | ✅ 実施済み |
| `AudioData.FFTPlot` | `plotFFT`（頭字語は大文字許容、ただし先頭は小文字） | ✅ 実施済み |
| `AudioData.spectrogramPlot` | `plotSpectrogram` | ✅ 実施済み |
| `ImageData.showImg` | `plotImage`（提案時点の案） | 不採用。**`showImage`を採用**（下記「実施内容」参照） |

**実施内容**

- `AudioData`の3メソッドは提案どおり`plot〜`に統一した: `audioPlot`→`plotWaveform`、`FFTPlot`→`plotFFT`、`spectrogramPlot`→`plotSpectrogram`。
- `ImageData.showImg`は提案の`plotImage`案を**採用しなかった**。ユーザーの判断により、画像表示は「描画（plot）」ではなく「表示（show）」という性質を保つべきとして`show`接頭辞を維持し、略語`Img`のみを`Image`に展開した`showImage`を採用した。これにより`GroovePointCloud.showPoints`（別途スコープ外、変更なし）と合わせて、本コードベースには「音声の描画は`plot〜`」「画像・点群の表示は`show〜`」という2系統の命名パターンが意図的に併存する。5-2着手時点で提案していた「全クラスで`plot〜`に統一する」という当初案からの意図的な逸脱であり、命名の一貫性よりも意味的な正確さ（画像はプロットというよりショーである）を優先した。
- `src/AudioData.m`・`src/ImageData.m`のメソッド定義本体を改名。
- 呼び出し元: `src/loadCycleResult.m`（ヘッダコメント中の使用例）、`test/unit/AudioDataTest.m`（テストメソッド名も`testAudioPlotDrawsLine`→`testPlotWaveformDrawsLine`、`testFFTPlotDrawsLine`→`testPlotFFTDrawsLine`、`testSpectrogramPlotRuns`→`testPlotSpectrogramRuns`に改名）、`test/unit/ImageDataTest.m`（同様に`testShowImgDrawsImage`→`testShowImageDrawsImage`、`testShowImgFitOption`→`testShowImageFitOption`、`testShowImgInvalidArgumentErrors`→`testShowImageInvalidArgumentErrors`に改名）を更新。
  - `scripts/`側は`AudioData`呼び出し6ファイル（`pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`photoshop_centroid_1cycle.m`、`photoshop_localMax_1cycle.m`）と`evaluation/stylus/sound_from_stylus.m`、`paper/202609asj`配下4ファイル（`fig5_spectrogramComparisonOrigD.m`、`fig6_spectrogramUpsampling.m`、`fig_waveformUpsampling.m`、`fig_waveformComparisonOrigD.m`。後2者はコメント中の`spectrogramPlot`言及も含む）を更新。
  - `ImageData.showImg`呼び出しは`scripts/`側9ファイル（`photoshop_localMax_1cycle.m`、`photoshop_centroid_1cycle.m`、`pkCentroid_interp2.m`、`pkCentroid_resample.m`、`pkCentroid_resample_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`pkCentroid_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`progress/showPhotoshopGrooveExtraction.m`）と`paper/202609asj`配下のコメント参照5ファイル（`fig1_2_grooveBtmOnImage.m`、`fig2_darknessProfile.m`、`fig3_grooveBtmMethodsOnImage.m`、`fig_GrooveBtmOnImageUpsamplingD.m`、`fig_grvBtmOnImgOrigUpsamplingD.m`。いずれも「`showImgは使わず`」という説明コメントのみで呼び出しではない）を更新。
  - `scripts/archive/findpeaks2d.m`は対象外（archiveのため）。`test/trash/AudioDataTest.m`・`test/trash/OOPTest.m`も対象外（trashのため）。
- `README.md`の`AudioData`・`ImageData`説明とコード例（`spectrogramPlot(4096)`→`plotSpectrogram(4096)`）を更新。`CLAUDE.md`はこれらのメソッド名に言及していないため変更不要。
- 検証: 変更した23ファイル（`src/`2、`test/unit/`2、`scripts/`19）すべて`check_matlab_code`で本改名に起因する警告なし（`AudioDataTest.m`の1件の`%#ok<NASGU>`関連info、`pkCentroidAndLocalMax_resample_1cycle.m`・`pkCentroid_interp2.m`・`showPhotoshopGrooveExtraction.m`に出た「変数に割り当てられた値は使用されていない可能性」系の警告はいずれも変更箇所と行番号が一致せず、既存事項と確認した）。`cd test; runAllTests`で74件全件成功（回帰なし。`StaticAnalysisTest`が`scripts/`側の静的解析も兼ねて通過）。
- `scripts/`は`ginput`や実画像を要するものが多く自動テスト不可なため、`_1cycle`系・`paper/202609asj`配下の図スクリプト・`evaluation/stylus/sound_from_stylus.m`は実行結果までは目視確認していない。次回実行時に見た目の崩れがないか確認が必要。

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
5. ~~**P4-1**（`DarknessMap.imgWidth/imgHeight` → `width`/`height`）~~ ✅ 実施済み（2026-08-09）。
6. ~~**P4-3の1行目**（`rsmplTF` → `isResampled`、`DarknessMap`と`GroovePointCloud`の両方）~~ ✅ 実施済み（2026-08-18）。
7. ~~**P4-3の3行目**（`GroovePointCloud.pksCell` → `peakCells`）~~ ✅ 実施済み（2026-08-18）。これで**P4**は完了。
8. ~~**P5-1の`plotD_x`**（→`plotDarknessColumn`）~~ ✅ 実施済み（2026-08-19）。
9. ~~**P5-2**（表示系メソッド命名パターンの統一。`AudioData`の`audioPlot`/`FFTPlot`/`spectrogramPlot`→`plotWaveform`/`plotFFT`/`plotSpectrogram`、`ImageData.showImg`→`showImage`）~~ ✅ 実施済み（2026-08-19、ただし`showImg`は提案の`plotImage`案ではなく`showImage`を採用。詳細はP5-2の節を参照）。これで**P5は全項目完了**。

> 各ステップ後に `cd test; runAllTests` で回帰確認する。`scripts/`（archive 含む）とテストの参照も同時に更新が必要。
