- 段階: 計画（対応表の案）
- 作成者: planner
- 作成日: 2026-11-24
- 入力: issue #28、`docs/issues/28-results-by-experiment/README.md`、`results/`・`experiments/` の中身（2026-11-24 に読み取りだけで確かめた）、`temp/` のスクリプトのコピー、cycleResult の `conditions`・`meta`
- 状態: 下書き

# #28 対応表の案（既存のフォルダの移し先）

`plan.md` の付属の文書。移行の関数が読む対応表（`scripts/migration/resultsMapping.csv`）は、この案をユーザーが承認した後に、実装担当が書き写して作る。

## 結論

- `results/` の日付のフォルダ19個（603ファイル）を、7つの実験名の下の35個の実行フォルダに移す（実験名の案は8つで、`stylus` には移す既存のフォルダが無い）。7個のフォルダは、ファイル名の形で複数の実行に分ける。どのファイルも、ちょうど1つの行き先に当たることを確かめた（付録 A）。
- 実行フォルダの日付には、今のフォルダの日付を使い、年を足して `YYYY-MMDD` にする。実際にファイルを作った日がフォルダの日付と違うものは、メモの列に書く。
- 原稿用の図は `results/figures/202609asj/paper/` に移す。スライド用の図は、main が `git mv` で `results/figures/202609asj/slides/` に移す。
- `experiments/` は、中身のある日付のフォルダ8個と、その中の cycleResult など12ファイルの名前の日付を `YYYY-MMDD` にする。空のフォルダ `1026/`・`1110/` は消す案にする（M2）。
- 決めてほしいことは、末尾の「未決事項」の M1〜M6 にまとめた。実験名（M6 の一部）は、スクリプトの既定値と README の一覧に使うので、計画の承認のときに決める。ほかは、移行の前（承認B）に決めればよい。

## 言葉

- **実験名・実行フォルダ・説明・対応表**：issue #28 の「言葉」と同じ。
- **行き先**：あるファイルを移す先の実行フォルダ。
- **混ざったフォルダ**：1つの日付のフォルダに、複数回の実行の出力が入っているもの。ファイル名の形（`audio_(...)(tracking)` など）で、どの実行の出力かを見分ける。
- **パターン**：ファイル名の一部を `*`（任意の文字の並び）で表したもの。MATLAB の `dir` と同じ書き方である（例：`evalTrack_*`）。

## 決め方

1. 実験名は、そのフォルダを作ったスクリプトと、そのきっかけの issue で決める。手がかりは、スクリプトの中で決め打ちしていた日付、ファイル名の形、ファイルの時刻、`temp/` に残っている実行用のコピー、cycleResult の `meta.scriptName`、受け渡しフォルダの記録である（付録 B）。
2. 実行フォルダの日付は、今のフォルダの日付に年（2026）を足したものにする（M1）。
3. 混ざったフォルダは、実行ごとに分け、説明を付ける。説明は、溝の選び方・高解像度化・手法・評価など、その実行の中身を表す語にする（`track`、`hist5`、`rsmplD`、`evaluation` など）。同じ説明が2回あれば、`resultDir` と同じく後のほうに `_2` を付ける。
4. 実行が1回だけのフォルダは、原則として説明を付けない。ただし、次の2つは中身を説明に書く（issue の「中身を名前で示したいとき」）。
   - (a) 高解像度化の比較（`upsampling`）。同じ実験名に、高解像度化の違う実行が並ぶため、どの高解像度化かを書く。
   - (b) `0820/bilateral/` の4つと `1111`。前者は今のサブフォルダの名前（`ori` など）を、後者は境界値の比較であること（`exclBoundVsInclBound`）を書く。`grooveBottomDetection` の中で、溝底区間の幅の上限の評価（`1118`）と見分けるためである。
5. 中のファイル名と、手書きの記録（`results/1111/README.md`）は変えない。

## 1. 実験名の案

| 実験名 | 内容 | 主なスクリプト | 関連 issue | 移す既存のフォルダ |
|---|---|---|---|---|
| `upsampling` | 高解像度化（リサンプル・内挿）と、溝底の検出法（重心法・局所的最大値法）の比較 | `pkCentroid_1cycle.m`、`pkCentroid_resample_1cycle.m`、`pkCentroid_interp2_1cycle.m`、`pkCentroidAndLocalMax_resample_1cycle.m`、`pkCentroid_resample.m`、`pkCentroid_interp2.m`、`darkness3d.m` | — | `0721`・`0724`・`0731`・`0807` |
| `photoshopUpscaling` | Photoshop で8倍に拡大した写真での溝底の抽出（従来法） | `photoshop_centroid_1cycle.m`、`photoshop_localMax_1cycle.m`、`progress/showPhotoshopGrooveExtraction.m` | — | `0802`・`0817` |
| `bilateralFilter` | バイラテラルフィルタ | `bilateral/` の5本 | — | `0820/bilateral/`・`0924/bilateral1cycle/` |
| `digitalNeedle` | 先行研究 DigitalNeedle の溝の追跡の再現。スクリプトはマージしていないブランチ `claude/DigitalNeedle-reproduction` にだけある | （master には無い） | — | `0831/digitalNeedle/` |
| `grooveTracking` | 1本の溝の自動追跡 | `grooveTrack_1cycle.m`、`evaluation/grooveTracking/compareTrackingToManual.m` | #25 | `1013`・`1014`・`1022`・`1026`・`1110` |
| `multiGroove` | 複数本の溝の抽出（N周分） | `grooveHist_Ncycle.m`、`grooveTrack_Ncycle.m`、`evaluation/multiGroove/compareHistToTracking.m` | #30 | `1028`・`1104` |
| `grooveBottomDetection` | 溝底の判定（境界値を含めるか、溝底区間の幅の上限） | `evaluation/grooveBottomDetection/` の2本 | #35 | `1111`・`1118` |
| `stylus` | 針で再生した音との比較 | `evaluation/stylus/sound_from_stylus.m` | — | （無い） |

- `grooveBottomDetection` は、#35 の slug（`wide-bottom-outliers`）とは違う名前である。評価スクリプトの置き場所（`scripts/evaluation/grooveBottomDetection/`）と進捗報告用の図のテーマ（`results/figures/progress/grooveBottomDetection/`）がすでにこの名前なので、それに合わせた（M6）。
- `stylus` は、評価スクリプトの置き場所（`scripts/evaluation/stylus/`）に合わせた。今、このスクリプトは動かず、移す既存のフォルダも無い（M6）。

## 2. `results/` の対応表

行き先は `results/` からの相対パスで書く。「数」は移すファイルの数である。

| 今のフォルダ | 移すもの | 行き先 | 数 | 作ったスクリプトと根拠 | メモ |
|---|---|---|---|---|---|
| `0710/` | （空） | 消す | 0 | — | issue で消すと決めた |
| `0721/` | フォルダごと | `upsampling/2026-0721/` | 1 | `pkCentroid_interp2.m`（`date = "0721"`） | ファイルの時刻は 07-23 |
| `0724/` | `audio_(4x_interp)*` | `upsampling/2026-0724_intpD/` | 7 | 内挿の1周分（当時の `pkCentroid_interp2_1cycle.m`、4倍） | |
| `0724/` | `audio_(centroid_method)(8x_resampled)*` | `upsampling/2026-0724_rsmplD/` | 7 | リサンプルの1周分（`pkCentroid_resample_1cycle.m`） | |
| `0731/` | `audio_(8x_interp)_*` | `upsampling/2026-0731_intpD/` | 6 | `pkCentroid_interp2_1cycle.m`（07-31 17:42） | 失敗した試行 `experiments/archive/cycleResult_intpD_0731_trash.mat`（07-31 17:43）と同じ時刻。wav は無い |
| `0731/` | `audio_(*)(original)*` | `upsampling/2026-0731_origD/` | 14 | `pkCentroid_1cycle.m`（08-01 13:04。`cycleResult_origD_0731.mat` の `savedAt` と同じ） | |
| `0731/` | `audio_(*)(8x_resampled)*` | `upsampling/2026-0731_rsmplD/` | 14 | `pkCentroid_resample_1cycle.m`（08-01 13:47。`cycleResult_rsmplD_0731.mat` と同じ） | |
| `0731/` | `audio_(8x_interp)(*` | `upsampling/2026-0731_intpD_2/` | 14 | `pkCentroid_interp2_1cycle.m`（08-20 13:13） | 08-20 のコミット `756fdbc`（溝の後処理の切り出し）の直後の実行。cycleResult は残っていない |
| `0802/` | `audio_(photoshop-localMax)*` | `photoshopUpscaling/2026-0802_localMax/` | 7 | `photoshop_localMax_1cycle.m`（08-02） | |
| `0802/` | `audio_(photoshop-centroid)*` | `photoshopUpscaling/2026-0802_centroid/` | 7 | `photoshop_centroid_1cycle.m`（08-03。`cycleResult_origD_0802.mat` と同じ日） | ファイルの時刻は 08-03 |
| `0807/` | フォルダごと | `upsampling/2026-0807_rsmplD/` | 14 | `pkCentroid_resample_1cycle.m`（`cycleResult_rsmplD_0807.mat`、08-07 14:46） | |
| `0817/` | フォルダごと | `photoshopUpscaling/2026-0817/` | 5 | `progress/showPhotoshopGrooveExtraction.m`（`date = "0817"`） | ファイルの時刻は 08-18 |
| `0820/bilateral/ori/` | フォルダごと | `bilateralFilter/2026-0820_ori/` | 13 | `bilateral/bilateralOri_centroid.m` | ファイルの時刻は 09-23 |
| `0820/bilateral/oriRsmpl/` | フォルダごと | `bilateralFilter/2026-0820_oriRsmpl/` | 13 | `bilateral/bilateralOriResample_centroid.m` | ファイルの時刻は 09-01 |
| `0820/bilateral/oriIntp/` | フォルダごと | `bilateralFilter/2026-0820_oriIntp/` | 13 | `bilateral/bilateralOriInterp2_centroid.m` | ファイルの時刻は 09-01 |
| `0820/bilateral/photoshop8x/` | フォルダごと | `bilateralFilter/2026-0820_photoshop8x/` | 13 | `bilateral/bilateral8x_centroid.m` | ファイルの時刻は 09-01 |
| `0820/bilateral/`、`0820/` | （空になる） | 消す | 0 | — | |
| `0831/digitalNeedle/` | フォルダごと | `digitalNeedle/2026-0831/` | 2 | ブランチ `claude/DigitalNeedle-reproduction` の `scripts/digitalNeedle/compareGrooveShapeAccuracy.m`（コミット `631b88b`、08-31） | M3 |
| `0831/` | （空になる） | 消す | 0 | — | |
| `0924/bilateral1cycle/` | フォルダごと | `bilateralFilter/2026-0924_1cycle/` | 36 | `bilateral/bilateralOri_centroid_1cycle.m` | issue の例と同じ |
| `0924/` | （空になる） | 消す | 0 | — | |
| `1013/` | フォルダごと | `grooveTracking/2026-1013/` | 22 | `grooveTrack_1cycle.m`（#25 の実装担当の動作の確認。`cycleResult_origD_track_1013.mat`） | |
| `1014/` | `audio_(*)(original).wav`、`audio_(*)(original)_*` | `grooveTracking/2026-1014_manual/` | 14 | `pkCentroid_1cycle.m` の手動選択の再現（#25 の評価。`temp/pkCentroid_1cycle_eval1014.m`、`cycleResult_origD_1014.mat`） | |
| `1014/` | `audio_(*)(original)(tracking)*`、`grooveTrack_img*` | `grooveTracking/2026-1014_track/` | 22 | `grooveTrack_1cycle.m`（#25 の評価。`temp/grooveTrack_1cycle_eval1014.m`、`cycleResult_origD_track_1014.mat`） | |
| `1014/` | `evalTrack_*` | `grooveTracking/2026-1014_evaluation/` | 24 | `evaluation/grooveTracking/compareTrackingToManual.m`（`temp/compareTrackingToManual_eval1014.m`） | |
| `1022/` | フォルダごと | `grooveTracking/2026-1022/` | 22 | `grooveTrack_1cycle.m`（`cycleResult_origD_track_1022.mat`、`meta.gitDirty = true`） | 目的の記録は見つからなかった |
| `1026/` | フォルダごと | `grooveTracking/2026-1026/` | 22 | `grooveTrack_1cycle.m`（始点の x を1列目に固定した後の確認。`temp/grooveTrack_1cycle_check1026.m`。cycleResult は保存していない） | |
| `1028/` | `audio_(*)(original)(hist_5_cycles)*`、`grooveHist_*` | `multiGroove/2026-1028_hist5/` | 30 | `grooveHist_Ncycle.m`（#30 の実装担当の動作の確認。`temp/grooveHist_Ncycle_check1028.m`） | |
| `1028/` | `audio_(*)(original)(tracking_5_cycles)*`、`grooveTrackN_*` | `multiGroove/2026-1028_track5/` | 22 | `grooveTrack_Ncycle.m`（同上。`temp/grooveTrack_Ncycle_check1028.m`） | |
| `1028/` | `audio_(*)(original)(tracking)*`、`grooveTrack_img*` | `multiGroove/2026-1028_track/` | 22 | `grooveTrack_1cycle.m`（#30 の回帰の確認。`temp/grooveTrack_1cycle_check1028.m`） | 1本の溝の追跡だが、#30 の作業で行ったので `multiGroove` に置く |
| `1104/` | `audio_(*)(original)(tracking_5_cycles)*`、`grooveTrackN_*` | `multiGroove/2026-1104_track5/` | 22 | `grooveTrack_Ncycle.m`（#30 の正解データ。`cycleResult_origD_track5_1104.mat`） | |
| `1104/` | `audio_(*)(original)(hist_5_cycles)*`、`grooveHist_*` | `multiGroove/2026-1104_hist5/` | 30 | `grooveHist_Ncycle.m`（#30 の評価。`cycleResult_origD_hist5_1104.mat`） | |
| `1104/` | `evalMulti_*` | `multiGroove/2026-1104_evaluation/` | 14 | `evaluation/multiGroove/compareHistToTracking.m`（`temp/compareHistToTracking_eval1104.m`） | |
| `1110/` | フォルダごと | `grooveTracking/2026-1110/` | 2 | `grooveTrack_1cycle.m` の途中で止まった実行（写真2枚分の図だけ。`experiments/1110/` は空） | M5 |
| `1111/` | フォルダごと | `grooveBottomDetection/2026-1111_exclBoundVsInclBound/` | 5 | `evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`（`date = "1111"`） | 手書きの `README.md` を含む（M4） |
| `1118/` | `audio_(*)(original)(tracking)*` | `grooveBottomDetection/2026-1118_track/` | 14 | `grooveTrack_1cycle.m`（#35 の評価。`temp/grooveTrack_1cycle_eval1118.m`） | 図は無く、音声だけ |
| `1118/` | `audio_(*)(original)(hist_5_cycles)*` | `grooveBottomDetection/2026-1118_hist5/` | 14 | `grooveHist_Ncycle.m`（`temp/grooveHist_Ncycle_eval1118.m`） | |
| `1118/` | `audio_(*)(original)(tracking_5_cycles)*` | `grooveBottomDetection/2026-1118_track5/` | 14 | `grooveTrack_Ncycle.m`（`temp/grooveTrack_Ncycle_eval1118.m`） | |
| `1118/` | `evalWidthThresh_*`、`grooveOnImage_*`、`waveform_*` | `grooveBottomDetection/2026-1118_evaluation/` | 102 | `evaluation/grooveBottomDetection/compareWidthThresh.m`（`temp/compareWidthThresh_eval1118.m`） | |
| 混ざったフォルダ（`0724`・`0731`・`0802`・`1014`・`1028`・`1104`・`1118`）、`1013`・`1022`・`1026`・`1110`・`1111` の元のフォルダ | （空になる） | 消す | 0 | — | フォルダごと移すものは、移すと元のフォルダが無くなる |

## 3. 図の対応表

| 今の場所 | 行き先 | 数 | git | 移す人 |
|---|---|---|---|---|
| `results/figures/paper/202609asj/` | `results/figures/202609asj/paper/` | 55 | 管理外 | 移行の関数（`results` の段階） |
| `results/figures/slides/202609asj/` | `results/figures/202609asj/slides/` | 52 | 管理する | main が `git mv` で移す（`.gitignore` を直すコミットと同じ） |
| `results/figures/paper/` | 消す（空になる） | 0 | — | 移行の関数（`deleteEmpty` の行） |
| `results/figures/slides/` | 消す（空になる） | 0 | — | main（`git mv` の後。CSV には入れない） |
| `results/figures/progress/` | 変えない | 92 | 管理する | — |

## 4. `experiments/` の対応表

| 今のパス | 新しいパス |
|---|---|
| `0731/cycleResult_intpD_0731.mat` | `2026-0731/cycleResult_intpD_2026-0731.mat` |
| `0731/cycleResult_origD_0731.mat` | `2026-0731/cycleResult_origD_2026-0731.mat` |
| `0731/cycleResult_rsmplD_0731.mat` | `2026-0731/cycleResult_rsmplD_2026-0731.mat` |
| `0802/cycleResult_origD_0802.mat` | `2026-0802/cycleResult_origD_2026-0802.mat` |
| `0807/cycleResult_rsmplD_0807.mat` | `2026-0807/cycleResult_rsmplD_2026-0807.mat` |
| `0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_0831.mat` | `2026-0831/digitalNeedle/grooveShapeAccuracy_img1_seg1_2026-0831.mat`（M3） |
| `1013/cycleResult_origD_track_1013.mat` | `2026-1013/cycleResult_origD_track_2026-1013.mat` |
| `1014/cycleResult_origD_1014.mat` | `2026-1014/cycleResult_origD_2026-1014.mat` |
| `1014/cycleResult_origD_track_1014.mat` | `2026-1014/cycleResult_origD_track_2026-1014.mat` |
| `1022/cycleResult_origD_track_1022.mat` | `2026-1022/cycleResult_origD_track_2026-1022.mat` |
| `1104/cycleResult_origD_hist5_1104.mat` | `2026-1104/cycleResult_origD_hist5_2026-1104.mat` |
| `1104/cycleResult_origD_track5_1104.mat` | `2026-1104/cycleResult_origD_track5_2026-1104.mat` |
| `1026/`（空）、`1110/`（空） | 消す（M2） |
| 元の日付のフォルダ（空になる） | 消す |
| `archive/` | 変えない（issue の決定） |

- .mat の中身（`conditions.date = "0731"` など）は変えない。
- 改名の前に、ユーザーがバックアップを確かめる（承認C）。

## 5. 対応表のファイルの形式

移行の関数が読む形式を、3つの案で比べた。

| 案 | 中身 | 長所 | 短所 |
|---|---|---|---|
| (a) CSV（推奨） | 1行に1つの「移す単位」（フォルダ、パターン、1ファイル、空のフォルダの削除）。列は `phase,kind,source,destination,note` | 約70行で、ユーザーが読んで承認できる。GitHub が表として表示する。README の対応表に書き写しやすい | パターンの意味（`*`）を関数が正しく解く必要がある（テストで確かめる） |
| (b) JSON | (a) と同じ内容を、要素の配列で書く | MATLAB の `jsondecode` で読める。メモにカンマを書ける | 行数が多く、人が見て比べにくい |
| (c) ファイルごとの一覧 | 移す 603 + 107 ファイルを1行ずつ書く | パターンを解かなくてよい | 700行を超え、ユーザーが承認できない |

置き場所は、移行の関数と同じ `scripts/migration/resultsMapping.csv` にする。スライド用の図は main が `git mv` で移すので、CSV には入れない。関数と入力を1か所に置き、作業の後も残すためである。README の「対応表」の節には、フォルダの単位の表を書き写し、細かいパターンは CSV を見るように書く。

CSV の列：

| 列 | 値 |
|---|---|
| `phase` | `results`（`results/` と原稿用の図）か `experiments` |
| `kind` | `dir`（フォルダごと移す）、`files`（パターンに合うファイルを行き先のフォルダへ移す）、`file`（1ファイルを、名前を変えて移す）、`deleteEmpty`（空のフォルダを消す） |
| `source` | プロジェクトのルートからの相対パス（区切りは `/`）。`files` では、最後の要素がパターン |
| `destination` | 同じく相対パス。`deleteEmpty` では空 |
| `note` | メモ（半角のカンマを書かない） |

## 未決事項

背景：移行は、この対応表を CSV にして関数で行う。M6 の実験名は、スクリプトの既定値と README の一覧に使うので、計画の承認のときに決める。M1〜M5 は、移す直前（承認B）までに決めればよい。

決定（2026-11-26、承認B。main が書き足した）：M1〜M5 と M6 の説明は、すべて推奨の (a) に決まった。CSV `scripts/migration/resultsMapping.csv` は、この表のとおりのまま使う。

- **M1 実行フォルダの日付を、どの日付にするか**
  - (a) 今のフォルダの日付に年を足す（推奨）。過去の記録（`docs/issues/closed/` など）に書かれたパスから、対応表で1対1に引ける。`experiments/` の日付とも合う。ファイルの時刻は、上書きで後の日付になっていることがあり（`1111` の図は同じ日に作り直して上書きした）、当てにならない。
  - (b) ファイルの時刻の日付にする。`0820/bilateral/` は `2026-0901`・`2026-0923`、`0731` の内挿の2回目は `2026-0820` になる。フォルダ名が実際の日に合うが、`experiments/` の日付とずれ、過去の記録から引くときに対応表の表をよく読む必要がある。
- **M2 空の `experiments/1026/` と `experiments/1110/` をどうするか**（issue に書かれていたのは `1026/` だけで、`1110/` も空だった）
  - (a) 両方を消す（推奨）。中身が無く、スクリプトの冒頭の `experimentDir` が、保存しなかった実行のときに作っただけのフォルダである。
  - (b) `2026-1026/`・`2026-1110/` に改名して残す。空のフォルダが残る。
  - (c) 今の名前のまま残す。`experiments/` に古い形の名前が残る。
- **M3 `0831/digitalNeedle/` の扱い**（スクリプトは master にマージしていないブランチにだけある）
  - (a) `results/digitalNeedle/2026-0831/` に移し、`experiments/2026-0831/digitalNeedle/` に改名し、ファイル名の日付も `2026-0831` にする（推奨）。ほかと同じ規則になる。ブランチのスクリプトを後で動かすと古い形の名前で保存されるが、今は使っていない。
  - (b) 移し先は (a) と同じにし、`experiments/` のファイル名だけは変えない。ブランチのスクリプトの名前の付け方と合う。
  - (c) どちらも移さない。`results/0831/`・`experiments/0831/` が古い形のまま残る。
- **M4 `results/1111/README.md` の相対リンク**（移すと、`../figures/...` と `../../scripts/...` の2つが切れる）
  - (a) そのまま移す（推奨）。issue の「手書きの記録は、そのまま一緒に移す」に従う。切れたリンクの先は、ファイル名で探せる。
  - (b) 2つのリンクの `../` を1つずつ増やしてから移す。リンクは切れないが、記録を書き換えることになる。
- **M5 `results/1110/`（写真2枚分の図だけの、途中で止まった実行）をどうするか**
  - (a) `grooveTracking/2026-1110/` に移す（推奨）。消してよいかを決める材料が無いので、ほかと同じく残す。
  - (b) 消す。途中の出力で使い道が無いが、issue で消してよいのは空の `0710/` だけである。
- **M6 実験名と説明の最終案**（1章と2章の表）
  - 実験名は、計画の承認で (a) の8つに決まった（2026-11-24、`plan.md` 8章の Q6）。説明は、承認B で決める。
  - (a) 表のとおりにする（推奨）。#35 は、slug ではなく、すでにある評価スクリプトと進捗報告用の図のテーマ `grooveBottomDetection` に合わせる。
  - (b) #35 の実験名を slug に合わせて `wideBottomOutliers` にする。issue の規則には合うが、`scripts/evaluation/grooveBottomDetection/`・`results/figures/progress/grooveBottomDetection/` と名前が違ってしまう。
  - ほかに、名前や説明を変えたいもの（例：`2026-1111_exclBoundVsInclBound` を `2026-1111_evaluation` にする）があれば、指定してほしい。

## 付録 A：パターンがすべてのファイルを1回ずつ覆うことの確認

混ざったフォルダについて、2章のパターンで MATLAB の `dir` を使い、各ファイルが当たる行の数を数えた（2026-11-24）。どのフォルダも、当たらないファイル・2行以上に当たるファイルは0だった。

| フォルダ | ファイル数 | 当たらない | 2行以上 | 行き先ごとの数 |
|---|---|---|---|---|
| `0724` | 14 | 0 | 0 | intpD 7、rsmplD 7 |
| `0731` | 48 | 0 | 0 | intpD 6、origD 14、rsmplD 14、intpD_2 14 |
| `0802` | 14 | 0 | 0 | localMax 7、centroid 7 |
| `1014` | 60 | 0 | 0 | manual 14、track 22、evaluation 24 |
| `1028` | 74 | 0 | 0 | hist5 30、track5 22、track 22 |
| `1104` | 66 | 0 | 0 | track5 22、hist5 30、evaluation 14 |
| `1118` | 144 | 0 | 0 | track 14、hist5 14、track5 14、evaluation 102 |

再現のコード（読み取りだけ。`rows` は2章の表の混ざったフォルダの行）：

```matlab
R = fullfile(string(currentProject().RootFolder), "results");
rows = {"1014", ["audio_(*)(original).wav","audio_(*)(original)_*"], "grooveTracking/2026-1014_manual"
        "1014", ["audio_(*)(original)(tracking)*","grooveTrack_img*"], "grooveTracking/2026-1014_track"
        "1014", ["evalTrack_*"], "grooveTracking/2026-1014_evaluation"};   % 他のフォルダも同じ形で並べる
for f = unique(string(rows(:,1)))'
    all = dir(fullfile(R,f)); names = string({all(~[all.isdir]).name});
    cnt = zeros(size(names));
    for r = find(string(rows(:,1))==f)'
        for p = rows{r,2}
            m = dir(fullfile(R,f,p)); [~,ia] = ismember(string({m(~[m.isdir]).name}), names); cnt(ia) = cnt(ia)+1;
        end
    end
    fprintf("%s: total %d, unmatched %d, multi %d\n", f, numel(names), sum(cnt==0), sum(cnt>1));
end
```

## 付録 B：振り分けの根拠のデータ

- フォルダとファイル数（2026-11-24）：`results/` の日付のフォルダは19個、603ファイル（`0710` は空）。`results/figures/` は `paper/202609asj` 55、`slides/202609asj` 52、`progress/` 92（`grooveBottomDetection` 16、`grooveTracking` 54、`multiGroove` 22）。
- `experiments/` の日付のフォルダは10個（`1026/`・`1110/` は空）、ファイルは12個（ほかに `archive/` に3個）。
- cycleResult の `meta`（`load` で `conditions`・`meta` だけを見た）：

| ファイル | `meta.scriptName` | `savedAt` | `gitCommit` | `gitDirty` | `wTh` |
|---|---|---|---|---|---|
| `0731/cycleResult_origD_0731.mat` | `pkCentroid_1cycle` | 2026-08-01 13:04 | `cd970e9` | true | 8 |
| `0731/cycleResult_rsmplD_0731.mat` | `pkCentroid_resample_1cycle` | 2026-08-01 13:47 | `d3984e7` | false | 8 |
| `0731/cycleResult_intpD_0731.mat` | `pkCentroid_interp2_1cycle` | 2026-08-07 13:41 | `d42df89` | true | — |
| `0807/cycleResult_rsmplD_0807.mat` | `pkCentroid_resample_1cycle` | 2026-08-07 14:46 | `1ffc73e` | true | 8 |
| `1013/cycleResult_origD_track_1013.mat` | `grooveTrack_1cycle` | 2026-10-13 20:26 | `2736d23` | true | 8 |
| `1014/cycleResult_origD_1014.mat` | `pkCentroid_1cycle` | 2026-10-14 15:28 | `3261e62` | false | 8 |
| `1014/cycleResult_origD_track_1014.mat` | `grooveTrack_1cycle` | 2026-10-14 15:30 | `3261e62` | false | 8 |
| `1022/cycleResult_origD_track_1022.mat` | `grooveTrack_1cycle` | 2026-10-22 15:27 | `246b850` | true | 8 |
| `1104/cycleResult_origD_hist5_1104.mat` | `grooveHist_Ncycle` | 2026-11-04 15:28 | `569e327` | false | 8 |
| `1104/cycleResult_origD_track5_1104.mat` | `grooveTrack_Ncycle` | 2026-11-04 15:16 | `b9c5db0` | false | 8 |

- `0802/cycleResult_origD_0802.mat`（791 MB）は、読み込みに時間がかかるので開いていない。日付と名前から `photoshop_centroid_1cycle.m` の結果とした。
- `temp/` に、実行に使ったコピーが残っている：`grooveTrack_1cycle_check1026.m`、`*_check1028.m`（3本）、`*_eval1014.m`（3本）、`*_1104.m`・`*_eval1104.m`（3本）、`*_eval1118.m`（4本）、`compareInclBoundToExclBound_overwrite1111.m`。
- `1013`・`1014`・`1028`・`1104` の内容は、#25・#30 の受け渡しフォルダの `impl-report-1.md`・`eval-report-1.md` の記述と合う。
