# 写真に溝底点を重ねた図の作り方

溝形状を抽出する手法が妥当かを、写真の上で目で確かめるための図の作り方。実験の確認から進捗報告・スライド・原稿まで、繰り返し使う。

- 図は2種類ある。**① すべての溝底点**を写真に重ねた図と、**② その上に、手法が取り出した溝底点**を色を変えて重ねた図。
- ②で描くのは、手法が**実際に選んだ点だけ**。欠損を補間した列の値は描かない。補間した値まで描くと、点の無い所でも溝に乗って見え、手法の失敗が隠れるため。
- 溝形状には独立した正解が無い（[`rules/evaluation.md`](rules/evaluation.md) の「正解の考え方」）。この図は、数値の一致度とは別に、選んだ点が溝底に乗っているか、どこで隣の溝やノイズに移ったかを示す。

図の置き場所・名前・タイトル・凡例・大きさのルールは [`rules/figures.md`](rules/figures.md) が正。この文書は、それに沿って、この図を作る手順だけを書く。

## 今あるスクリプト

| スクリプト | 図 |
|---|---|
| [`scripts/progress/grooveOnImageManualAndTrack.m`](../scripts/progress/grooveOnImageManualAndTrack.m) | 1周分の従来法と自動追跡。①②を、写真全体と、外れた時刻の切り出しで作る |
| [`scripts/progress/multiGrooveOnePhoto.m`](../scripts/progress/multiGrooveOnePhoto.m) | N周分。写真全体の①と、取り出した溝を線で描いた図 |
| [`scripts/evaluation/grooveBottomDetection/compareInclBoundToExclBound.m`](../scripts/evaluation/grooveBottomDetection/compareInclBoundToExclBound.m) | 溝底の判定の違い（`exclBound`・`inclBound`）で、片方だけにある溝底点の色を変えた図 |

新しく作るときは、まずこれらのスクリプトを直すか、パラメータを変えて使えないかを考える。取り出した溝底点を求めるコード（下の手順4）は、今はスクリプトの中に書いてある。

## 手順

### 1. 読み込む結果を決める

`experiments/<日付>/` の cycleResult を `loadCycleResult` で読む。フォルダは `experimentDir(rootFolder,DATE,Create=false)` で作る。

| 溝の選び方 | ファイル | 作ったスクリプト |
|---|---|---|
| 従来法（`manual`） | `cycleResult_<画像>_<日付>.mat` | `pkCentroid_1cycle.m` など |
| 自動追跡（`track`）、1周 | `cycleResult_<画像>_track_<日付>.mat` | `grooveTrack_1cycle.m` |
| 自動追跡、N周 | `cycleResult_<画像>_track<N>_<日付>.mat` | `grooveTrack_Ncycle.m` |
| ヒストグラム（`hist`）、N周 | `cycleResult_<画像>_hist<N>_<日付>.mat` | `grooveHist_Ncycle.m` |

- **溝底の判定を確かめる。** 図の名前に `inclBound`・`exclBound` を書くため。`result.meta.gitCommit` が `ad46b44` 以降なら `inclBound`、それより前なら `exclBound`。`git merge-base --is-ancestor ad46b44 <gitCommit>` が成功すれば以降。
- **2つの結果を比べるときは、溝底点が同じかを確かめる。** 写真ごとに、手順3でつないだ点を `isequal` で比べ、違えば止める。溝底点が違うと、取り出した点の違いが溝の選び方によるものか分からなくなるため。

### 2. 写真を読み直す

```matlab
imgs = reconstructImage(result.conditions,iImg); % 写真 iImg の全区間の ImageData
photoImg = [imgs.img];                           % 高さは同じなので横に連結できる
```

- cycleResult の `allImg` には画素（`.img`）が保存されていない（数百MBになるため。issue #17）。`reconstructImage` が、`conditions.filenames` の撮影画像を、音声を作ったときと同じ処理（区間に分け、`omitMask` をかける）で読み直す。`Research.prj` を開き、撮影画像が MATLAB のパス上にあること。
- `size(photoImg,2)` が、手順3の `numel(xQuery)` と同じかを確かめる。

### 3. すべての溝底点（①）

```matlab
ks = (iImg-1)*numSegments + (1:numSegments);
[pks,xQuery,counts,xOffsets] = mergeSegmentPoints(result.(METHOD).pts(ks), ...
    QueryStep=result.grooveSelection.tracking.queryStep);
```

- `pks` は、写真1枚分の座標（元の画像の px）。区間 `j` の中の座標にするには、x から `xOffsets(j)` を引く。
- `METHOD` は `"centroid"` か `"localMax"`。`grooveSelection.tracking` が無い（従来法だけの）結果では、`QueryStep` は高解像度化しないとき1。

### 4. 取り出した溝底点（②）

溝の選び方ごとに、保存されているものが違う。どれも、元の画像の px の、デトレンドする前の y にする。

| 溝の選び方 | 保存されているもの | 取り出し方 |
|---|---|---|
| 従来法 | `grooveSelection.p1`・`.p2`（区間ごとのクリック位置、80×2） | 下の「従来法の点」 |
| 自動追跡、1周 | `grooveSelection.tracking.yAbsCnt{i}`・`.foundCnt{i}` | `[xQuery(found), yAbs(found)]` |
| 自動追跡・ヒストグラム、N周 | `grooveSelection.multiGroove.yAbsCnt{i,j}`・`.foundCnt{i,j}`（`j` は溝の番号） | 溝 `j` ごとに同じ |

（`Cnt` は重心法。局所的最大値法は `Max`）

- `yAbs*` は、欠損を補間した後の y なので、そのまま描かない。`found*`（その列で点を採れたか）で絞る。
- 絞った点が、すべて手順3の `pks` の中にあるかを `ismember(...,"rows")` で確かめる。1014の1周分と、1104の track5・hist5 で、すべて中にあることを確かめた。

**従来法の点**：保存されている `ycoords` は、補間とデトレンドをした後の値なので、点として描けない。保存したクリック位置で、溝の選択を ginput なしでやり直す。

```matlab
segPts = result.(METHOD).pts(k);           % 区間 k の溝底点
segPks = vertcat(segPts.peakCells{:});
[p1,~,pksCorCell] = fitGroove(jSegment,[],zeros(1,2),segPts.width,cond.hPrl,{segPks}, ...
    P1=sel.p1(k,:),P2=sel.p2(k,:));        % P1・P2 を渡すと ginput も figure も使わない
pksCor = pksCorCell{1};                    % 傾きを補正した点。行は segPks と同じ順
grooveCenter = findGrooveCenter(pksCor,p1(2),BinWidth=cond.binWidth,MinPeakHeight=cond.thHist);
inGroove = (pksCor(:,2) >= grooveCenter - cond.tol) & (pksCor(:,2) <= grooveCenter + cond.tol);
ptsManual = [segPks(inGroove,1) + xOffsets(jSegment), segPks(inGroove,2)]; % 補正前の点に戻す
```

- `cond = result.conditions`、`sel = result.grooveSelection`。
- 点を選ぶ式は、`extractGrooveShape` と同じにする（`abs(y - c) <= tol` にすると、浮動小数点の丸めで結果が変わることがある）。
- **選んだ点が、音声に使った点と同じかを確かめる。** 同じ点から `extractGrooveShape` → `detrendGrooveShape`（`PolyDegree=cond.polyDegree`）で y を作り直し、保存した `ycoords{k}` との差が 1e-9 以下であることを確かめる。違えば止める。

### 5. 描く範囲を決める

| 範囲 | 座標 | 図の大きさ | 点の大きさ（`SizeData`） |
|---|---|---|---|
| 写真全体（1/8周） | 写真1枚分の px | 30×7 cm | 1 |
| 切り出し | 区間の中の px | 14.8×11.1 cm | 15 |

- 切り出す範囲は、見たい所の列と y を中心に、±`X_HALF`（溝に平行な方向）・±`Y_HALF`（溝を横切る方向）にする。今のスクリプトは、2つの手法の音声の差 `|track − manual|` が時間 `T_WINDOWS` の中で最大のサンプルを中心にする（`X_HALF = 35`、`Y_HALF = 32`。上下の隣の溝も入る）。
- サンプルの番号から区間と列を求めるには、`counts = cellfun(@numel,result.(METHOD).ycoords)` の累積和を使う。1周分の結果の音声は `vertcat(ycoords{:})` を並べたものなので、累積和でサンプルが区間 `k` の何列目かが分かる。N周分の結果は並びが違う（README の「複数本の溝の抽出（N周分）」）ので、この求め方はまだ確かめていない。
- 描く範囲の外の点は、描く前に除く。fig ファイルが重くなるのを防ぐため。

### 6. 描く

```matlab
fig = createFigure([0 0 FIG_SIZE]);
tl = tiledlayout(fig,1,1,Padding="compact");
ax = nexttile(tl);
imagesc(ax,img(yRange,xRange),XData=xRange([1 end]),YData=yRange([1 end]));
colormap(ax,gray); clim(ax,[0 255]);       % 撮影画像の表示範囲は [0 255] に固定する
axis(ax,"image");
hold(ax,"on");
hAll = scatter(ax,pks(:,1),pks(:,2),MARKER_SIZE,"cyan","filled","o");
hManual = scatter(ax,ptsManual(:,1),ptsManual(:,2),MARKER_SIZE,"yellow","filled","o");
hTrack = scatter(ax,ptsTrack(:,1),ptsTrack(:,2),MARKER_SIZE,"magenta","filled","o");
hold(ax,"off");
lgd = legend(ax,[hAll hManual hTrack],["all groove-bottom points","manual","tracking"],Location="northeast");
lgd.ItemHitFcn = @togglevisibility;        % 凡例のクリックで表示を切り替える
```

- **色**：すべての溝底点は cyan。取り出した点は、従来法が yellow、自動追跡が magenta（2026/11/11 時点の仮の色）。ヒストグラムの色はまだ決めていない。
- **重なり**：同じ位置の点は、後に描いた色だけが見える。今は自動追跡を後に描くので、2つの手法が同じ点を選んだ所は magenta、従来法だけの点は yellow に見える。隠れた点は、凡例のクリックで上の点を消して確かめる。
- **凡例**：描画領域の中に置く（[`rules/figures.md`](rules/figures.md) の「凡例」）。凡例には実際の点のハンドルを渡す。`SizeData` が1でも、凡例の点は見える大きさで描かれる。凡例用に別の点を描くと、`togglevisibility` がその点だけを切り替え、実際の点が消えなくなる。凡例が点を隠すときは `Location="best"` にする（切り出しの図では、右上だと上隣の溝の点を隠した）。
- **タイトル**：[`rules/figures.md`](rules/figures.md) の「タイトル」の形で書く。切り出しの図のように幅に収まらないときは、`["Groove on image: manual vs tracking", "(original, ...)"]` のように2行に分ける。

### 7. 名前を付けて保存する

名前は [`rules/figures.md`](rules/figures.md) の「ファイル名」に沿って、パラメータの変数から組み立てる。

| 図 | 名前の例 |
|---|---|
| ①、写真全体 | `grooveOnImage_origD_inclBound_centroid_1014_img1` |
| ②（2つの手法）、写真全体 | `grooveOnImage_manualVsTrack_origD_inclBound_centroid_1014_img1` |
| ②（1つの手法）、写真全体 | `grooveOnImage_origD_inclBound_centroid_track_1014_img1` |
| ①、切り出し | `grooveOnImage_origD_inclBound_centroid_1014_img8_seg5_715-716ms` |
| ②（2つの手法）、切り出し | `grooveOnImage_manualVsTrack_origD_inclBound_centroid_1014_img8_seg5_715-716ms` |

- ①は溝の選び方に依らないので、選び方を書かない。
- 保存は用途の保存関数で行う。保存した後、PNG を開いて、点が溝底に乗っているか、凡例が見たい点を隠していないか、タイトルが切れていないかを確かめる。
- **容量**：写真全体の図は、fig が1枚あたり約5 MB、png が約1 MB ある（溝底点が1枚に約7万点あるため）。`results/figures/progress/` のように git で管理する場所に、写真8枚分を何度も作り直すと、履歴が大きくなる。作成済みの図を作り直さないよう、スクリプトに作るかどうかのパラメータ（`MAKE_PHOTO_FIGS` など）を設ける。

## 用途ごとの違い

| 用途 | 違い |
|---|---|
| 作業用・進捗報告用 | 上のとおり。fig も保存するので、凡例のクリックで点を切り替えられる |
| スライド用・原稿用 | タイトルを付けない。大きさ・文字は [`rules/figures.md`](rules/figures.md) の「スライド用」「原稿用」に従う。原稿の1段（79 mm）に写真全体を入れると点が見えないので、切り出しの図を使う |

## 今後

- 取り出した溝底点を求めるコード（手順4）を `src/` の関数にし、合成データのテストを付けると、評価・スライド・原稿のスクリプトで同じ処理を使える（未着手）。
- N周分の結果で、ヒストグラムで取り出した点を②の形で描く図は、まだ作っていない（手順4の取り出し方は確かめた）。
