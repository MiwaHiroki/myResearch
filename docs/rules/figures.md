# 図の置き場所・名前・書式

Claude（メインセッション・サブエージェントとも）が図を作って保存するときのルール。ユーザーが作る図も、できるだけこの形にそろえる。Claude が図を作るときの手順は、skill `make-figure`（[`.claude/skills/make-figure/SKILL.md`](../../.claude/skills/make-figure/SKILL.md)）にまとめてある。

目的は、**ファイル名を見れば、何の図かが誤解なく分かるようにすること**。図のファイルだけを別の場所（スライド、Drive など）に移しても分かるようにする。そのために、条件を表す語を下の[語彙表](#語彙表)で1つに決め、ファイル名・タイトル・凡例で同じ語を使う。

## 置き場所と用途

| 用途 | スクリプト | 出力先 | git | タイトル | 大きさ・文字 | 保存 |
|---|---|---|---|---|---|---|
| 作業用（実験・評価） | `scripts/`、`scripts/evaluation/<テーマ>/` | `results/<MMDD>/`（`mkdirFromDate`、実行した日） | 管理外 | 付ける | 自由 | `saveFigure`（png・fig） |
| 進捗報告用 | `scripts/progress/` | `results/figures/progress/` | 管理する | 付ける | 自由 | `saveFigure`（png・fig） |
| スライド用 | `scripts/slides/<YYYYMM><会議略称>/` | `results/figures/slides/<同じ名前>/` | 管理する | 付けない | [スライド用](#スライド用) | `saveSlideFigure` |
| 原稿用 | `scripts/paper/<YYYYMM><会議略称>/` | `results/figures/paper/<同じ名前>/` | 管理外 | 付けない | [原稿用](#原稿用) | `savePaperFigure` |

- 出力先は `currentProject().RootFolder` から組み立てる。スライド用・原稿用は `mkdirFromDate` の日付フォルダを使わない。
- 会議のフォルダ名は `202609asj` のように、年月と会議の略称をつなげる。
- 図は、用途の保存関数（`saveFigure`・`saveSlideFigure`・`savePaperFigure`）で保存する。`exportgraphics`・`saveas` を直接呼ばない。保存関数は、保存の前に名前を確かめる（[名前の確かめ方](#名前の確かめ方)）。
- 同じ名前のファイルがあれば上書きしない（[`data.md`](data.md) の「出力の上書き」）。`saveFigure` は、同じ名前のファイルがあると保存せずにエラー（`saveFigure:fileExists`）を出す。進捗報告用の図を作り直すときのように、上書きしてよいときだけ `Overwrite=true` にする。

## ファイル名

### 形

```
[fig<番号>_]<種類>[_<比較>][_<条件>…][_<データの日付>][_<部分>][_<範囲>][_<表示>]
```

| 要素 | 書くもの | 必須か |
|---|---|---|
| `fig<番号>` | 原稿の図番号（`fig2`、`fig2-1`）。原稿用だけ | 任意 |
| 種類 | 何を描いた図か（`waveform`、`spectrogram` など） | 必須 |
| 比較 | 2つ以上を重ねたり並べたりした図だけ。違う条件の語を `Vs` でつなぐ（`manualVsTrack`） | 比べた図では必須 |
| 条件 | 図が依存する条件を、語彙表の順（画像 → 抽出法 → 溝の選び方 → 周数）に並べる | 依存するものはすべて |
| データの日付 | 読み込んだ `experiments/<MMDD>/` の `MMDD` | cycleResult を使う図では必須 |
| 部分・範囲・表示 | 写真・区間・溝の番号、時間・周波数の範囲、表示の違い。この順に並べる | 任意 |

条件の書き方：

- 図が依存する条件は、既定の値でも省略しない（高解像度化しないときも `origD` と書く）。例外は周数で、1周のときは書かない。
- 図が依存しない条件は書かない（写真そのものの図に、抽出法は書かない）。
- 比較に出した条件は、条件の位置には書かない（`manualVsTrack` と書いたら、溝の選び方は条件に書かない）。
- データの日付は、図を作った日（`results/<MMDD>/` のフォルダ名）とは別物。cycleResult を使わない図（写真から直接作る図）には書かず、写真を `img<i>` で示す。

### 文字

- 英数字と `_`・`-` だけを使う（`savePaperFigure` と同じ制限）。空白・括弧・日本語・`.` は使わない。
- `_` は要素の区切り。1つの要素の中は camelCase にする（`Vs` の後ろの語も先頭を大文字にする：`manualVsTrack`、`origDVsRsmplD`）。
- `-` は番号と範囲だけに使う（`fig2-1`、`0-20ms`）。
- 数には単位を付け、小数点を使わない。単位を変えて整数にする（0.59 s → `590ms`）。

### 使わない語

`_2`、`new`、`old`、`final`、`test`、`tmp`、`mini`、`zoom`、`compare`、作成日。代わりに、何が違うのかを書く（`zoom` → 範囲、`compare` → `Vs`、`_2` → 違う条件）。

### 例

| 図 | ファイル名 |
|---|---|
| 1014のデータで、手動選択と自動追跡の音声の波形を、0〜20 ms の範囲で比べた | `waveform_manualVsTrack_origD_centroid_1014_0-20ms.png` |
| 1104のデータで、ヒストグラムで取り出した5周分の音声（局所的最大値法）のスペクトログラム | `spectrogram_origD_localMax_hist_5cyc_1104.png` |
| 1022のデータで、写真3に自動追跡した溝（重心法）を重ねた | `grooveOnImage_origD_centroid_track_1022_img3.png` |
| 0731のデータで、3つの高解像度化の音声（重心法、手動選択）のスペクトログラムを、0〜5 kHz で並べた | `spectrogram_origDVsRsmplDVsIntpD_centroid_manual_0731_0-5kHz.png` |
| 原稿の図2-1。写真1・区間5の1列の暗さの分布 | `fig2-1_darknessProfile_origD_img1_seg5.pdf` |

### スクリプトでの作り方

- 名前は、パラメータの変数から組み立てる。手で打たない。パラメータを変えたのに名前が変わらない、という食い違いを防ぐため。

  ```matlab
  figName = "waveform_manualVsTrack_" + UPSAMPLING + "_" + METHOD + "_" + DATE;
  saveFigure(fig, saveDir, figName);
  ```

- `AudioData.filename`（`audio_(centroid_method)(original)_...` の形）を図の名前に使わない。
- png・fig・pdf は同じ名前にして、拡張子だけを変える。

### 名前の確かめ方

`checkFigureName(name)` が、名前がこのルールに沿っているかを確かめる。外れていれば、理由を並べた警告（`checkFigureName:invalidName`）を出す（エラーにはしない。保存もする）。保存関数はすべて、保存の前にこれを呼ぶ。`issues = checkFigureName(name, Warn=false)` で、理由だけを受け取ることもできる。

確かめるのは、使える文字、語彙表の語か、並び順、使わない語だけ。図が依存する条件をすべて書いたか、データの日付が読み込んだデータと合っているかは確かめられないので、名前を決める人が確かめる。

## タイトル

作業用・進捗用の図に付ける。スライド用・原稿用の図には付けない（スライドの文字・キャプションに任せる）。

- 形：`<種類>: <比較> (<条件>, data <MMDD>, <部分・範囲>)`。語彙表の「表記」の列の語で書く。比較が無いときは `<種類> (<条件>, …)`。
  - `Waveform: manual vs tracking (original, centroid, data 1014, 0-20 ms)`
  - `Groove on image (original, centroid, tracking, data 1022, photo 3)`
- ファイル名と同じ情報を、同じ順に書く。ファイル名だけ、タイトルだけにある情報を作らない。
- 英語で書く（`setDefaultIntrpr` の LaTeX 表示のまま書ける）。`_` は LaTeX で下付き文字になるので使わない。
- 線や点の色の説明はタイトルに書かず、凡例に書く。
- `ginput` でクリックを促す間は、指示をタイトルに書いてよい（日本語可、`Interpreter="none"`）。保存する前に、上の形のタイトルに置き換える。

## 凡例

- 凡例は、ユーザーが指定しない限り、描画領域（axes）の中に置く（`Location="northeast"` など。`"southoutside"` のような `...outside` は使わない）。描画領域の一部が凡例で隠れるのは、基本的に構わない。
- 比べたものの名前は、語彙表の「表記」の列の語で書く（`manual`、`tracking`）。ファイル名の `Vs` と同じ順に並べる。
- 語彙表に無いもの（`$D_\mathrm{th}$`、`start` のような、図の中の線や点の名前）は自由に書いてよい。

## 軸ラベル

「量 [単位]」の形で、英語で書く（`Time [s]`、`Frequency [Hz]`、`Magnitude [dB]`、`$y$ [px]`）。単位の無い量には単位を書かない（`Amplitude`）。

## 撮影画像の表示

撮影画像（盤面の写真）やその切り出しを描くときは、表示する画素値の範囲を [0 255] に固定する。用途（作業用・進捗報告用・スライド用・原稿用・評価）を問わない。

- 切り出した範囲に合わせた自動の表示範囲、コントラストの強調、ガンマ補正などはしない。見えにくくても変えない。画像の見え方を変えることは、実験データの改変にあたるため。
- `ImageData.showImage`（`imshow(uint8(...))`）はもともと [0 255] で表示する。`imagesc` は表示範囲を自動で合わせるので、`clim(ax,[0 255])` を付ける。
- 見えにくいときは、表示する範囲（切り出し）やマーカーで工夫する。それでも見えにくければ、ユーザーに相談する。

## 語彙表

ファイル名には「語」の列を、タイトル・凡例には「表記」の列を使う。「旧表記」の列は、このルールより前の図を探すときに使う。

新しい語が要るときは、似た語を作らず、まずこの表から探す。無ければ、使う前にこの表と [`src/figureVocabulary.m`](../../src/figureVocabulary.m) の両方に足す（同じコミットで）。`FigureNameTest` が、この表と `figureVocabulary` の一覧が一致しているかを確かめる。`docs/` だけを変えたコミットではCIが走らないので、表を変えたら手元で `runAllTests` を実行する。

`<N>` は、そこに数字が入ることを表す。

### 種類

| 語 | 表記 | 意味 | 旧表記 |
|---|---|---|---|
| `waveform` | Waveform | 音声の振幅の時間波形 | `amp` |
| `spectrum` | Spectrum | FFT の振幅スペクトル | `fft` |
| `spectrogram` | Spectrogram | STFT のスペクトログラム | `stft` |
| `grooveShape` | Groove shape | 溝形状（x に対する溝底の y） | `shape` |
| `grooveShapeDiff` | Groove shape difference | 2つの溝形状の差 | `diff` |
| `grooveOnImage` | Groove on image | 写真に、溝底の点や追跡した溝を重ねた図 | `grooveTrack_img`、`grooveHist_img`、`overlay`、`grooveBtmOnImage` |
| `grooveOnDarkness3d` | Groove on darkness (3D) | 暗さの3次元表示に、溝底を重ねた図 | `grooveBtmOn3d` |
| `grooveHistogram` | Groove histogram | 傾きを補正した後の、溝底の y のヒストグラム | `grooveHist_histogram` |
| `pointCloud` | Groove-bottom points | 溝底の点群 | `PkDots`、`pts` |
| `darknessProfile` | Darkness profile | 1列の暗さの分布 | |
| `darkness3d` | Darkness (3D) | 暗さの3次元表示 | |
| `image` | Image | 写真そのもの | `segment` |

### 条件

並べる順は、この表の上から（処理の順）。

| 分類 | 語 | 表記 | 意味 | 旧表記 |
|---|---|---|---|---|
| 画像 | `origD` | original | 高解像度化しない | `original`、`ori`、`orig` |
| 画像 | `rsmplD` | resampled | `dResample` で高解像度化 | `8x_resampled`、`rsmpl` |
| 画像 | `rsmplD<N>x` | resampled (Nx) | `rsmplD` の倍率を変えて比べるとき | |
| 画像 | `intpD` | interpolated | `dInterp`（interp2）で高解像度化 | `8x_interp`、`intp` |
| 画像 | `intpD<N>x` | interpolated (Nx) | `intpD` の倍率を変えて比べるとき | |
| 画像 | `photoshop8x` | Photoshop 8x | Photoshop で8倍に拡大した写真 | `photoshop`、`photoshopHighRes` |
| 画像 | `bilateralK<N>` | bilateral (k=N) | バイラテラルフィルタ（`NeighborhoodSize` が N） | `bilateral_k05`、`k05` |
| 抽出法 | `centroid` | centroid | 重心法 | `centroid_method`、`cnt` |
| 抽出法 | `localMax` | local maximum | 局所的最大値法 | `local_maximum_method`、`local_max`、`max` |
| 溝の選び方 | `manual` | manual | `fitGroove`（区間ごとにクリックで選ぶ） | （書かれていない） |
| 溝の選び方 | `track` | tracking | `trackGroove`（写真ごとに自動で追跡） | `tracking`、`grooveTrack` |
| 溝の選び方 | `hist` | histogram | `extractMultiGroove`（ヒストグラムで複数本を取り出す） | `grooveHist` |
| 音源 | `stylus` | stylus | 針で再生した音（比べるための音） | `StylusPlayback` |
| 周数 | `<N>cyc` | N cycles | N周分（N本の溝）。1周のときは書かない | `5_cycles`、cycleResult名の `track5`・`hist5` |

- cycleResult のファイル名（`cycleResult_origD_track5_1104.mat`）とは、周数の書き方だけが違う。図では `track_5cyc` と書く。

### 部分

| 語 | 表記 | 意味 |
|---|---|---|
| `img<N>` | photo N | 写真の番号（1〜8） |
| `seg<N>` | segment N | 写真の中の区間の番号（1〜10）。`img<N>` の後に書く |
| `groove<N>` | groove N | N本のうちの何本目の溝か（1が最も外側） |

### 範囲

`<始め>-<終わり><単位>` の形で書く（`0-20ms`、`590-630ms`、`0-5kHz`、`0-500Hz`）。単位は `ms`・`s`・`Hz`・`kHz`。タイトルでは数と単位の間に空白を入れる（`0-20 ms`）。

### 表示

同じ図の表示だけを変えたものを区別する語。何が違うのかを書く。

| 語 | 意味 |
|---|---|
| `noColorbar` | カラーバーを付けない |
| `imgOnly` | 写真だけ（線や点を重ねない） |

## スライド用

- 大きさは、特に指定がなければ 8×8 cm。
- 文字：目盛り 14 pt、軸ラベル 16 pt。カラーバーも同じ。
- 1図1ファイル。複数の図を `tiledlayout`・`subplot` で1枚にまとめない（1つの図だけを `tiledlayout(1,1)` で描くのは可）。
- `saveSlideFigure` で png だけを保存する（300 dpi）。
- タイトルは付けない。`AudioData.plotWaveform` はタイトルを付けるので、呼んだ後に `title(ax,"")` で消す。`AudioData.plotSpectrogram` は `ShowTitle=false` にする。
- スペクトログラムには、図ごとにカラーバーを付ける（付け方は[カラーバーの注意](#カラーバーの注意)）。

## 原稿用

音響学会（LaTeX、A4、二段組）の場合。

- 幅：1段 79 mm、2段 165 mm。原稿に等倍で貼るので、この幅で書き出す。1段の図の高さは 50〜60 mm が目安。
- 文字：目盛り 8 pt、軸ラベル 9 pt、凡例 8 pt。`ax.LabelFontSizeMultiplier = 1` で、ラベルが1.1倍になるのを止める。
- タイトルは付けない（キャプションに任せる）。
- `savePaperFigure` で pdf・png（600 dpi）・fig を保存する。スペクトログラムのようにベクタだと重くなる図は `ContentType="image"` にする。
- 余白は、単体の axes なら `tightenAxes`、`tiledlayout` なら `Padding="tight"` で消す。`exportgraphics` は外側の余白を切り詰めるので、消さないと出力が指定の幅より小さくなる。`savePaperFigure` が表示する実際の大きさを確かめる。

## カラーバーの注意

- カラーバーがある図で `tightenAxes` を呼ばない。axes がカラーバーの場所まで広がり、カラーバーがキャンバスの外に押し出されて消える。
- 単体の axes に `colorbar` を付けたまま図を小さくすると、カラーバーのラベルが切れる。カラーバーを付ける図は、`tiledlayout(fig,1,1,"Padding","tight")` と `nexttile` で作り、`c = colorbar(ax); c.Layout.Tile = "east";` で東側に置く。`AudioData.plotSpectrogram` を使うときは `ShowColorbar=false` にして、呼び出し側でカラーバーを作る。

## 既存の図とスクリプト

- 既存の図は改名しない。`results/<MMDD>/` は過去の結果と比べるための記録で、`results/figures/` の図はスライドや進捗の資料から参照されているため。
- 既存のスクリプトの名前の付け方は、このルールに合わせる作業を頼まれたときに直す（[`coding.md`](coding.md) の「既存の名前は、リファクタリングのタスク以外では改名しない」と同じ扱い）。
