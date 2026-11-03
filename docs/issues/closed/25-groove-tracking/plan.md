- 段階: 計画
- 作成者: planner
- 作成日: 2026-10-12（2026-10-13 にユーザーの回答を反映して修正）
- 入力: issue #25、[`./README.md`](./README.md)、メインからの依頼文（issue作成後にユーザーと確認済みの事項）、未決事項Q1〜Q3・仮定A1〜A5へのユーザーの回答と補足（2026-10-13）
- 状態: 承認済み（2026-10-13、ユーザー）

# #25 写真1枚の範囲で1本の溝を自動追跡する — 計画

## 修正の履歴

- 2026-10-13：Q1〜Q3を決定事項にした（8章）。A5を「高解像度化した画像にも使う前提で設計する」に書き換えた。`trackGroove` の窓などのパラメータを、列数から**長さ（元の画像のpx）**に変えた（`FitLength`・`InitLength`・`MaxGapLength`。3.2・4.2）。`mergeSegmentPoints` に `QueryStep` を足した。マスクについてのコメントの指示を足した（4.1・4.5・5章）。評価の基準を「今のコードで手動選択を再現した cycleResult ファイル」にし、その作り方を書いた（2.6・7章）。新しい未決事項Q4（`FitLength` の既定値）を足した。
- 2026-10-13（main）：Q4を60pxで決定し、状態を「承認済み」にした。

## 1. 結論

- **追跡は「逐次追跡」で行う（Q1で決定）。** 写真1枚分（10セグメントを横につないだ約4000列）の溝底の点群で、クリック位置から左右に1列ずつ進む。直近の採った点に直線をあてはめて次の列の位置を予測し、予測から ±2px 以内で最も近い点を採る。実データの8枚すべてで、手動選択（`intpD_0731` の `grooveSelection`）と同じ溝を右端まで追えた。
- **窓などのパラメータは、列数ではなく元の画像の長さ[px]で指定する。** 高解像度化（`dInterp`）すると1列が1/8pxになり、列数のままでは同じ値の意味が8倍変わるため。直線あてはめの窓は「最後に採った点から `FitLength` px 以内の点」とする。`origD` では1列=1pxなので、単位を変えても試行の結果は8枚・2手法とも完全に同じだった（付録A.6）。既定値は `FitLength=60`（30と実データの結果は同じで、長い欠損に強い。Q4で決定）。
- **デトレンドは、新しい関数 `detrendTrackedShape` で写真1枚全体に9次をかける（Q2で決定）。** 次数は、評価段階のスペクトログラム・試聴を見て見直すことがある。
- **保存は既存の `cycleResult` の形のまま**にし、追跡の情報は `grooveSelection` に `method`・`seeds`・`tracking` を足して入れる（Q3で決定）。`saveCycleResult`・`loadCycleResult` は変えない。
- **評価の基準は、今のコードで手動選択を再現した cycleResult ファイル**にする。評価の段階で、`scripts/pkCentroid_1cycle.m` を `PREV_RESULT_PATH` で `intpD_0731` の `p1`/`p2` を再現して実行すれば、`ginput` なしで作れる（2.6・7章）。ただし `date = "0731"` がスクリプトに書かれているので、実行日に変える必要がある。

## 2. 調査結果

### 2.1 置き換える場所（高解像度化なしの既存スクリプト）

高解像度化なしの条件を作っているのは `scripts/pkCentroid_1cycle.m`。正解データ `experiments/0731/cycleResult_origD_0731.mat` の `meta.scriptName` も `"pkCentroid_1cycle"` だった。このスクリプトの流れは次のとおり。

1. 写真 `iImg` × セグメント `jSegment` のループ（L58–156）。セグメントごとに `omitMask` → `ImageData` → `DarknessMap` → `setDiffTF` を通し、`GrooveExtractor` で `pts_cnt`・`pts_max`（`GroovePointCloud`）を作る（L63–104）。
2. **置き換える部分**：`fitGroove`（L112–123）と、`extractGrooveWaveform`（`findGrooveCenter`→`extractGrooveShape`→`detrendGrooveShape`、L130–145）。
3. `y_comb = vertcat(ycoords{:})`、`amp = (y_comb - mean)/(tol/2)`、`AudioData`、図・wav、`saveCycleResult`（L160–234）。

新しいスクリプトでは、1はそのまま使う。2を「写真1枚分の点群をつなぐ → 追跡 → 写真ごとにデトレンド → セグメントごとに分け直す」に置き換える。3は保存形式を変えずに使う。

ユーザーからの補足：`omitMask` で落とす低輝度の列（マスク）は、1/8周分の写真の両端にしか無い。したがって `omitMask`〜`GrooveExtractor` を `for jSegment` の中で行う必要は本来ない。今回は既存と同じくセグメントごとに行い、将来写真1枚単位に変える可能性があることをスクリプトのコメントに残す（4.1・4.5）。

### 2.2 再利用できるもの

| もの | 使い方 |
|---|---|
| `GrooveExtractor`・`GroovePointCloud` | 溝底の点の検出は、`pkCentroid_1cycle.m` L84–104 と同じにする |
| `GroovePointCloud.width` | 元の画像の幅（`DarknessMap.width`。`dInterp`・`dResample` の後も元の幅のまま）。セグメントを横につなぐときのxのずらし量に使う |
| `cycleConditions`・`cycleMethodResult`・`saveCycleResult` | 変えずに使う。`saveCycleResult` は `GrooveSelection` の `p1`/`p2` だけを検証し、他のフィールドはそのまま保存する（コードで確認済み） |
| `fillmissing(...,"linear")` | `extractGrooveShape` と同じ欠損の補間 |
| `ImageData.showImage` | クリック用に写真1枚分の画像を表示する |

使わないもの：`fitGroove`・`extractGrooveShape`・`detrendGrooveShape`（issueの指定）。`detrendGrooveShape` は、`polyfit` でxのセンタリングとスケーリングをしない。約4000列で4次以上にすると「多項式の条件が不適切です」の警告が出た（付録A.5）。

### 2.3 参考ブランチ（`origin/feature/groove-tracking-dp:scripts/grooveTrackDP_interp2.m`）の要点

- 対象は1セグメント・`intpD`。旧名を使っている（`DarknessValue`→`DarknessMap`、`GrooveCandidates`→`GroovePointCloud`、`getStartEndIdx`→`findThresholdIntervals`、`getGrooveBtmIdx`→`findGrooveBottomIntervals`、`extractGrv_cnt`→`extractByCentroid`、`pksCell`→`peakCells`、`showImg`→`showImage`）。
- 点をxでソートする。点jから点iへのコストは `LAMBDA_X*(dx) + LAMBDA_Y*(dy)^2`（`LAMBDA_X=1`、`LAMBDA_Y=15`）。遡るのは `MAX_GAP=15` 列まで。最後の列の点のうち、累積コストが最小のものから逆にたどる。
- **問題点（実データで確認）**：xのコストは、点をいくつ経由しても合計が同じになる。一方yの2乗は、途中の点が少しでもずれていると経由したほうが高くなる。そのため、DPは点を飛ばして滑らかな部分だけを選ぶ。写真1枚に広げると、列の40〜80%が採られず、補間で埋めると音の成分が消えた（付録A.3）。

### 2.4 実データで確かめたこと（すべて読み取りのみ。付録に再現コード）

- **正解データの中身**：`origD_0731` には `grooveSelection` が**無い**。`centroid.pts`・`localMax.pts` は空（`[]`）。使えるのは `ycoords`（80×1、セグメントごとに3次デトレンドして平均0）、`y_comb`、`audio` だけ。
- **始点の入手先**：`intpD_0731` の `grooveSelection.p1`/`p2` は80×2で、座標は元の画像のpx（`p2` のxは293〜395で、セグメントの幅以内）。これを現在のコードで `origD` に当てはめると、正解とのセグメントごとの相関係数は0.70〜0.98になった。隣の溝（±1、±2本）では −0.17〜0.21。つまり**正解と同じ溝**を指している。写真ごとの始点は `p1(1:10:end,:)` =
  `[26 260; 30 289; 97 242; 51 241; 98 337; 83 268; 47 242; 17 249]`。
- **正解データは、今のコードでは完全には再現できない**：同じ溝を同じ方法（`fitGroove`＋`extractGrooveWaveform`）で取り直しても、正解とのRMSEは中央値0.111px、相関は中央値0.854だった。差は、約5%の列で約0.44pxずれていることによる。正解を作ったのは2026-08-01で、その後の `ad46b44`（2026-08-14、溝底検出の境界値の扱いを定義し直した変更）で値が変わった。ユーザーによると、`ad46b44` 以降に1周分のデータは作っていない（`experiments/` にも `0731` の3ファイルより後の cycleResult は無い）。**評価では、今のコードで手動選択を再現した cycleResult ファイルを作って基準にする**（2.6・7章）。
- **逐次追跡の結果**：8枚すべてで、手動選択の各セグメントの右端のクリック（`p2`）との差は3px以内だった。同じ溝を右端まで追えている。採れなかった列は1周で17列（写真2・3・6に4〜7列ずつ。最長7列）。追跡したy座標にセグメントごとの3次デトレンドをかけると、「今のコードで手動選択を再現したもの」と、重心法80セグメント中77で完全に一致した。残りの3セグメント（局所的最大値法では5セグメント）は、手動側が採り逃した点を追跡側が採っていたことによる差だった。手動側は、ヒストグラムのビンの中心から ±3px の固定の幅で点を選ぶので、溝が少し曲がると端の点を落とす。例えば k=68 の局所的最大値法では47列を落としていた。
- **パラメータを変えても結果はほぼ同じ**：許容幅 `Tolerance` が1.5〜4px、あてはめの窓が10〜100px（`origD` なので10〜100点）のどの組み合わせでも、実データの結果は同じだった。`Tolerance=1` にすると追跡が途切れる。
- **クリックのずれ**：始点の初期化（始点から20pxの範囲で、クリックしたyから10px以内の最も近い点を取り、その中央値を使う）を入れると、クリックが ±5px ずれても8枚すべてで同じ結果になった。±8pxでは8枚中1枚で失敗した。溝の間隔は25〜30px。
- **長い欠損（人工的に作ったもの）**：写真1の溝の途中で、x方向に10・20・40pxの範囲の候補をすべて消して追跡した（6か所）。窓が30pxでは、20px以上の欠損の後で溝を見失うことがあった（6か所中2か所）。窓が60pxでは、`origD`・`intpD` とも、40pxまでのすべての欠損の後で元の溝に戻れた（付録A.8）。
- **デトレンドの比較**：写真1枚全体に多項式をかけた場合と、正解（写真ごとに平均0）を比べた。

  | 方法 | 正解とのRMSE [px]（写真8枚の範囲） | 相関係数 | 消える周波数の目安（振幅が−3dB） |
  |---|---|---|---|
  | 写真ごと3次 | 0.15〜0.28 | 0.54〜0.91 | 約15Hz |
  | 写真ごと5次 | 0.13〜0.17 | 0.71〜0.93 | 約25Hz |
  | 写真ごと9次（Q2で決定） | 0.12〜0.15 | 0.75〜0.94 | 約40Hz |
  | 写真ごと15次 | 0.12〜0.14 | 0.76〜0.94 | 約65Hz |
  | セグメントごと3次（旧方式と同じ） | 0.11〜0.12 | 0.81〜0.95 | 約150Hz |

  正解はセグメントごと3次で作られているので、「セグメントごと3次」が正解に一番近くなるのは当然。写真ごとにかけると、40〜150Hzあたりの成分が残る。そのぶん正解とのRMSEは大きくなるが、残った成分が音なのか雑音なのかは、この比較だけでは分からない。
- **境目の段差**：正解（セグメントごとに平均0）では、セグメントの境目の段差の中央値が0.146pxだった。隣どうしの列の差の中央値は0.014pxなので、約10倍になる。写真ごと9次にすると、写真の中の境目の段差は0.012pxで、ふつうの列の差と同じになった。
- 計算時間：80セグメントの点の検出に約5秒、8枚の追跡に約1秒（`origD`）。

### 2.5 横方向（溝に沿った方向）の座標と単位

- `DarknessMap.dResample(p,q)` は `resample(dMat,p,q)` で、**行方向（縦、溝を横切る方向）だけ**を細かくする。`scaleFactor.col` は1のままで、`nCols` は元の幅と同じ。`rsmplD` では1列=1px。
- `DarknessMap.dInterp(step,method)` は縦横の両方を細かくし、`scaleFactor.col = 1/step` になる。`nCols = (width-1)/step + 1`（例：幅398、step 0.125 → 3177列）。既存の `pkCentroid_interp2_1cycle.m` では、点のxを `1+(col-1)*QUERY_STEP` で元の画像のpxに戻し、`xQuery = (1:QUERY_STEP:width)'` を使っている。
- y座標は、`GrooveExtractor.extractByCentroid`/`extractByLocalMax` の中で `(idx-1)/scaleFactor.row + 1` によって元の画像のpxに戻されている。
- したがって、点群 `[x y]` は高解像度化の有無によらず**元の画像のpx**で表されている。変わるのは列の間隔（`origD`・`rsmplD` は1px、`intpD` は `step` px）だけ。
- `intpD` で写真1枚分を連結すると、`xQuery` の間隔はセグメントの中では `step` で、**セグメントの境目では1px**になる（セグメントjの最後の列 `off+width_j` の次は、セグメントj+1の最初の列 `off+width_j+1`）。写真1の2セグメントで確かめた（付録A.7）。

### 2.6 今のコードで手動選択を再現する方法（評価の基準を作るため）

`scripts/pkCentroid_1cycle.m` を読んで確かめた。

- **再現できる**：`PREV_RESULT_PATH` に結果ファイルのパスを入れると、`loadCycleResult` で `grooveSelection` を読み、`fitGroove(jSegment,[],p2,w_prl,h_prl,{pks_max,pks_cnt},P1=grooveSelection.p1(k,:),P2=grooveSelection.p2(k,:))` を呼ぶ（L121–122）。このとき `ginput` も、`fitGroove` の中の図も使わない。
- **`intpD_0731` の `p1`/`p2` をそのまま使える**：`fitGroove` は、平行四辺形の左右の辺を `x=1` と `x=w_prl`（セグメントの幅）に置き、`p1`/`p2` の**yだけ**を使う（xは使わない）。`intpD_0731` の `p1`/`p2` のyは元の画像のpxなので、`origD` にそのまま使える。`TH_HIST=150`・`binWidth=5`・`tol=3`・`h_prl=8` も計画段階の試行（付録A.4）と同じなので、同じ結果（正解とのRMSEの中央値0.111px）になるはず。
- **注意点**
  1. **`date = "0731"` がスクリプトに書かれている**（L28）。このまま実行すると、図・wav（`saveas`・`audiowrite`）が `results/0731/` の既存のファイルを同じ名前で上書きする。結果の.matは `experiments/0731/` に入る。`date` は実行日にする必要がある。
  2. `PREV_RESULT_PATH = ""`（L35）も書き換える必要がある。つまり、スクリプトの2行を変えないと実行できない。リポジトリのスクリプトを変えずに済むよう、スクラッチパッドにコピーして2行を変えて実行することを勧める（仮定A6、7章）。
  3. `saveCycleResult` の呼び出し（L233）は `Overwrite` を渡していないが、既定が `false` なので上書きはしない。ただし、同じ名前のファイルがあると**エラーにはならず**、警告を出して `_2` を付けた名前で保存する（`uniquePath`）。`docs/rules/data.md` の「同名のファイルがあればエラーにする」という書き方とは違う。どちらにしても既存のファイルは消えない。
  4. 実行後、L163 と L186 の図は閉じられずに残るので、閉じる。
  5. 保存されるファイル名は `cycleResult_origD_<実行日>.mat`。追跡の結果は `cycleResult_origD_track_<日付>.mat`（仮定A1）なので、同じ日に作っても重ならない。wavの名前は重ならないように、追跡のスクリプトで `AudioData` の名前を変える（4.5）。

## 3. 案の比較

### 3.1 追跡の方法（Q1で (a) 逐次追跡に決定）

| 案 | 長所 | 短所 | 試した結果 |
|---|---|---|---|
| **A. 逐次追跡（採用）**：直近の点に直線をあてはめて予測し、予測から `Tolerance` 以内で最も近い点を採る。左右の両方向に進む | 単純で速い（8枚で約1秒）。パラメータが少なく、結果がパラメータにほとんど左右されない。分数刻みのxにも対応できる | 1本の溝の点の近く（±2px）に別の点があると、近いほうを採ってしまう。長い欠損では予測がずれる | 8枚とも手動と同じ溝。手動の再現と77/80セグメントで完全一致。許容幅内に候補が2点以上ある列は0 |
| B. DP（参考ブランチの方式を写真1枚に広げ、飛ばした列に罰則 `GAP_PEN` を足す） | 全体で最適な経路になるので、一時的な外れ点に強い | パラメータが4つ（`LX`、`LY`、`MAX_GAP`、`GAP_PEN`）。罰則なし（参考ブランチのまま）では、列の40〜80%を飛ばす。実装が複雑 | `GAP_PEN=0`：列の40〜80%が欠損し、逐次追跡との差は0.16〜0.24px（音の成分と同じくらいの大きさ）。`GAP_PEN=30`：8枚とも逐次追跡と**完全に一致** |
| C. セグメントごとに `p2` を自動で決め、既存の `fitGroove`（`P1`/`P2` 指定）＋`extractGrooveShape` を呼ぶ | 既存の関数をそのまま使える。`p1`/`p2`（80×2）を自然に保存できる | issueの要求（写真1枚分の溝形状を出し、新しいデトレンドをかける）を満たすには、別に繋ぎ直しが要る。固定幅で点を選ぶので、手動と同じく端の点を落とす | 試していない（手動の再現 = この案の上限。上の「端の点を落とす」問題がそのまま残る） |

将来、ホコリなどで A が誤って別の点を採る例が見つかったら、B（罰則つきDP）に差し替える（9章）。インターフェースは同じにしておく。

### 3.2 窓などのパラメータの単位（列数か、長さ[px]か）

ユーザーからの質問を受けて比べた。対象は、あてはめの窓（旧 `NumFit`）、始点の初期化の範囲（旧 `NumInit`）、長い欠損の警告（旧 `MaxGap`）。`Tolerance`・`SnapRadius` はy方向の距離で、もともと元の画像のpx。

| 案 | 長所 | 短所 | 試した結果 |
|---|---|---|---|
| **長さ[px]（採用）**：`FitLength`・`InitLength`・`MaxGapLength`。窓は「最後に採った点のxから `FitLength` 未満の点」 | 同じ値が、高解像度化の有無によらず溝に沿った同じ長さ（同じ時間）を表す。`intpD` で使うときに値を変えなくてよい。欠損の長さもpxで読める | 窓の中の点の数が、列の間隔や欠損で変わる。点の数そのものに意味がある条件（直線あてはめの最小点数）は、別に点の数で決める必要がある | `origD` の8枚・2手法で、列数の版と**完全に同じ結果**（付録A.6）。`intpD`（step 0.125）でも、窓60pxで40pxまでの人工欠損の後に元の溝に戻れた（付録A.8） |
| 列数：`NumFit`・`NumInit`・`MaxGap` | 実装が少し簡単。点の数が固定なので、あてはめの重さが一定 | `intpD`（step 0.125）では、`NumFit=30` は3.75px、`NumInit=20` は2.4px、`MaxGap=50` は6.25px にしかならない。高解像度化のたびに値を8倍にし直す必要がある。補間した隣どうしの列は独立でないので、30点あっても雑音を平均する効果は3.75px分しかない | `intpD` で `NumFit=30`（3.75px）にすると、人工欠損40pxの後で6か所中2か所で溝を見失った。`origD` の窓4px・10pxでも、20px以上の欠損で見失うことがあった（付録A.8） |

**直線あてはめの最小点数は、点の数のまま残す。** 最小二乗の直線を決めるには点が2点以上必要で、1点の外れ値に引きずられないように5点以上にしている。これは長さではなく点の数の問題なので、関数の中の定数 `MIN_FIT_POINTS = 5` とする（引数にはしない）。`intpD` では5点が0.5pxにしかならないが、予測するのは次の1列（0.125px先）だけなので、傾きの誤差が予測に与える影響も列の間隔に比例して小さくなる。

**長い欠損の直後の扱い**：窓の基準を「今の列」ではなく「**最後に採った点**」にする。今の列を基準にすると、`FitLength` より長い欠損の後で窓が空になり、予測が直線から「最後の点のy」に落ちて、傾いた溝では見失いやすくなる。最後に採った点を基準にすれば、欠損の前の `FitLength` px分の点で予測を続けられる。

**`origD` では結果が変わらないか**：欠損の無い所では、窓の中は「最後の点から29px前まで」の30点で、列数30と同じ。欠損があると長さの版の窓の点は少なくなる（例：写真2の7列の欠損の直後は23点）。それでも実データでは、8枚・2手法とも採った点は1点も変わらなかった（付録A.6）。計画段階の試行結果（2.4）はそのまま成り立つ。

## 4. 設計

### 4.1 処理の流れ（新しいスクリプト `scripts/grooveTrack_1cycle.m`）

```
for iImg = 1:8
    写真を1回だけ imread・rgb2gray（pkCentroid_1cycle.m はセグメントごとに読み直しているが、結果は同じ）
    % マスクは写真の両端にしか無いので、将来は写真1枚単位で omitMask〜GrooveExtractor を行う形に変える可能性がある
    for jSegment = 1:10                         ← pkCentroid_1cycle.m L63–104 と同じ
        omitMask → ImageData → DarknessMap → setDiffTF → GrooveExtractor
        → pts_cnt, pts_max（GroovePointCloud）を allPts_* に入れる
    end
    ks = (iImg-1)*10 + (1:10)
    [pksCnt, xQuery, counts, xOffsets] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP)   ← 新規
    [pksMax, ~, ~, ~]                  = mergeSegmentPoints(allPts_max(ks), QueryStep=QUERY_STEP)
    seed = ginput(1)（写真1枚分の画像の上で）  または  seeds(iImg,:)（再現時）
    [ptsCnt, foundCnt, infoCnt] = trackGroove(pksCnt, seed, xQuery, ...)  ← 新規（fitGroove＋extractGrooveShape の代わり）
    [ptsMax, foundMax, infoMax] = trackGroove(pksMax, seed, xQuery, ...)
    detCnt = detrendTrackedShape(ptsCnt, PolyDegree=POLY_DEGREE)          ← 新規（detrendGrooveShape の代わり。写真ごとに平均0）
    detMax = detrendTrackedShape(ptsMax, PolyDegree=POLY_DEGREE)
    ycoords_cnt(ks) = mat2cell(detCnt(:,2), counts)     セグメントごとに分け直す（保存形式を既存と同じにするため）
    ycoords_max(ks) = mat2cell(detMax(:,2), counts)
    xcoords(ks)     = 各セグメントのローカルなx (1:QUERY_STEP:widths(j))'（既存と同じ）
    allP1(ks,:), allP2(ks,:) = 追跡した重心法のy座標（補間済み、デトレンド前）の各セグメントの左端・右端（4.4）
end
y_comb = vertcat(ycoords{:}) → amp = (y_comb - mean(y_comb)) / AMP_DIV → AudioData → 図・wav → saveCycleResult
```

- 今回は `QUERY_STEP = 1`（`origD`）だけを実行する。`QUERY_STEP` を変数にしておくのは、将来 `intpD` にも同じ流れを使うため（仮定A5）。
- **マスクについてのコメント**：`for jSegment` のループの直前（`omitMask` を呼ぶ所の近く）に、次の趣旨のコメントを書く。「マスク（omitMaskで落とす低輝度の列）は写真の両端にしか無いので、将来は写真1枚単位で omitMask〜GrooveExtractor を行う形に変える可能性がある」。今回は `allPts_*` をセグメントごとに作る形のままにする（既存の保存形式 `pts` 80×1 を保つため）。
- 写真どうしのつなぎ目は、ユーザーと確認したとおり既存と同じ扱いにする。写真ごとに平均0にしたy座標をそのまま連結する（`detrendTrackedShape` が平均0にする）。
- 重心法と局所的最大値法は、**同じクリック位置から別々に追跡する**（仮定A3）。実データでは、8枚とも同じ溝を追え、採れなかった列の数も同じだった。

### 4.2 インターフェース

#### `src/trackGroove.m`（新規）

```matlab
function [points, found, info] = trackGroove(pks, seed, xQuery, opts)
% 写真1枚分の溝底の点群 pks から、seed（クリック位置）を通る溝1本を
% 左右に1列ずつ追跡し、xQuery 全体のy座標（欠損は線形補間）を返す。
% fitGroove（溝の選択・傾き補正）と extractGrooveShape（点の抽出・欠損の補間）を
% 兼ねる。セグメントごとの平行四辺形の選択（1周80回のginput）を、
% 写真ごとに1回のクリックに減らすため。
% 長さの引数はすべて元の画像のpxで指定する（高解像度化して列の間隔が
% 変わっても、同じ値が溝に沿った同じ長さを表すように）。
    arguments
        pks (:,2) double              % [x y]。元の画像のpx。xはxQueryのいずれかの値（mergeSegmentPointsの出力）
        seed (1,2) double             % [x y]。クリック位置（元の画像のpx。xは写真1枚分を連結した座標）
        xQuery (:,1) double           % 昇順の列の座標[px]。origDなら (1:nCols)'、intpDなら分数刻み
        opts.Tolerance (1,1) double {mustBePositive} = 2        % 予測位置から採る点までの最大距離（y方向）[px]
        opts.FitLength (1,1) double {mustBePositive} = 60       % 予測の直線あてはめに使う範囲。最後に採った点から x方向にこの長さ未満の採用点を使う[px]（Q4）
        opts.SnapRadius (1,1) double {mustBePositive} = 10      % 初期化でseed(2)から探す範囲（y方向）[px]
        opts.InitLength (1,1) double {mustBePositive} = 20      % 初期化に使う範囲。始点の列から右へこの長さ未満の列[px]
        opts.MaxGapLength (1,1) double {mustBePositive} = 40    % 連続した欠損がこの長さを超えたら警告する[px]
    end
```

- 関数の中の定数：`MIN_FIT_POINTS = 5`（直線あてはめに必要な、窓の中の採用点の最小数。点の数で決める理由は3.2）。
- 出力
  - `points`：`(numel(xQuery),2)`、`[xQuery, y]`。採れなかった列は `fillmissing(y,"linear")` で補間する（`extractGrooveShape` と同じ。両端の欠損は外挿される）。
  - `found`：`(numel(xQuery),1) logical`。その列で点を採れたかどうか。
  - `info`：struct。`y0`（初期化で決めた始点のy）、`seedIdx`（始点の列の番号）、`numFound`・`numMissing`（列の数）、`maxGapLength`（最も長い連続欠損の長さ[px]。下の手順6の定義）。
- 手順（実装担当はこのとおりに書く）
  1. 列ごとに分ける：`[tf, col] = ismember(pks(:,1), xQuery)`。`tf` が false の点は使わない（`extractGrooveShape` と同じく `ismember` で対応させる。分数刻みのxQueryにも使える）。列ごとの候補のy座標を `cands = accumarray(col(tf), pks(tf,2), [n 1], @(v){v}, {[]})` で cell にまとめる（空の列は `[]`）。
  2. 始点の列：`[~, s] = min(abs(xQuery - seed(1)))`。
  3. 初期化：`xQuery(c) - xQuery(s) < InitLength` を満たす列 `c = s, s+1, …` のそれぞれで、`seed(2)` に最も近い候補を取る。距離が `SnapRadius` 以下のものだけを集め、その中央値を `y0` にする。1つも無ければ `error("trackGroove:seedNotFound", ...)`。
  4. 右向きに進む（c = s, s+1, …, n）。採った点を採った順に `(accX, accY)` に追加していく。予測値 `yp` は次のとおり。
     - 窓 `w = abs(accX - accX(end)) < FitLength`（**最後に採った点**からの距離。今の列からではない。理由は3.2）。
     - `nnz(w) >= MIN_FIT_POINTS`：窓の点に1次式をあてはめ、`xQuery(c)` での値。条件が悪くならないよう、xから `xQuery(c)` を引いてからあてはめる（`pp = polyfit(accX(w)-xQuery(c), accY(w), 1); yp = pp(2)`）。
     - 採った点が1点以上で、窓の点が `MIN_FIT_POINTS` 未満：最後に採った点のy（`accY(end)`）。
     - 採った点が0点：`y0`。

     `cands{c}` のうち `yp` に最も近い点が `|d| <= Tolerance` なら採り、`y(c)` に入れる。それ以外は NaN のままにする。
  5. 左向きに進む（c = s-1, …, 1）。`(accX, accY)` の初期値は、右向きで採った点のうち、最も小さいx（`xFirst`）から `FitLength` 未満の点を、**xの大きい順**に並べたもの（最後の要素が最も左の点になるように）。残りは4と同じ。
  6. `found = ~isnan(y)`。連続した欠損の長さは「欠損した列の数 × 列の間隔 `dx`」とする（`dx = median(diff(xQuery))`。`origD` では欠損した列の数と同じ。`intpD` のセグメントの境目の1pxの飛びは無視する。警告の目安なので、この程度の誤差は問題ない）。`info.maxGapLength > MaxGapLength` なら `warning("trackGroove:longGap", ...)`（何pxの位置から何px続いたかを書く）。そのあと `points(:,2) = fillmissing(y,"linear")`。
- 速さ：`intpD`（step 0.125）では窓の中が最大480点になり、`polyfit` を1写真あたり約3万回呼ぶ。遅ければ、最小二乗の閉じた式（Σx、Σy、Σxy、Σx²）で書いてよい。`origD` では問題にならない（8枚で約1秒）。

使用例：

```matlab
[pksCnt, xQuery, counts, xOffsets] = mergeSegmentPoints(allPts_cnt(ks), QueryStep=QUERY_STEP);
[ptsCnt, foundCnt, infoCnt] = trackGroove(pksCnt, seed, xQuery, Tolerance=TRACK_TOL, ...
    FitLength=FIT_LENGTH, SnapRadius=SNAP_RADIUS, InitLength=INIT_LENGTH, MaxGapLength=MAX_GAP_LENGTH);
```

#### `src/detrendTrackedShape.m`（新規）

```matlab
function pointsDetrended = detrendTrackedShape(points, opts)
% trackGroove で追跡した写真1枚分の溝のy座標に、opts.PolyDegree 次の多項式を
% あてはめて差し引き、平均を0にする（x座標は変えない）。
% 約4000列に高い次数をあてはめるので、polyfit の [p,S,mu] 形式（xのセンタリングと
% スケーリング）を使う（detrendGrooveShape は使わない。issue #25）。
    arguments
        points (:,2) double
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 9   % Q2で決定。評価の結果で見直すことがある
    end
    [p, S, mu] = polyfit(points(:,1), points(:,2), opts.PolyDegree);
    ...  y - polyval(p, x, S, mu) をしてから平均を引く
```

- xは元の画像のpxのまま渡すので、`intpD` でも同じ次数が同じ周波数の範囲を消す（列の数にはよらない）。

#### `src/mergeSegmentPoints.m`（新規）

```matlab
function [pks, xQuery, counts, xOffsets] = mergeSegmentPoints(ptsArray, opts)
% 写真1枚分（NumSegments個）の GroovePointCloud の点群を、x方向にずらしながら
% 1つの [x y] 配列に連結し、写真1枚分の xQuery も作る。trackGroove に写真1枚分の
% 点群を渡すため。ずらし量は各セグメントの幅（GroovePointCloud.width = 元の画像の幅）の
% 累積和にする。omitMask で落とした列は詰めて連結する（既存スクリプトが ycoords を
% 連結するのと同じ並び）。
    arguments
        ptsArray (:,1) GroovePointCloud
        opts.QueryStep (1,1) double {mustBePositive} = 1   % 列の間隔[px]。origD・rsmplDは1、intpDはdInterpのstep
    end
```

- 出力
  - `pks (:,2)`：セグメントjの点のxに `xOffsets(j)` を足して縦に連結したもの。
  - `xQuery (:,1)`：各セグメントの `(1:QueryStep:width_j)' + xOffsets(j)` を縦に連結したもの。間隔はセグメントの中で `QueryStep`、境目で1px（2.5）。
  - `counts (N,1)`：各セグメントの列の数（`numel(1:QueryStep:width_j)`）。`mat2cell` でセグメントごとに分け直すときに使う。`QueryStep=1` なら幅と同じ。
  - `xOffsets (N,1)`：`xOffsets(1)=0`、`xOffsets(j) = sum(width(1:j-1))`。
- 中身が空のセグメント（`peakCells` がすべて空）があっても、エラーにしない。
- `QueryStep` で `width_j - 1` が割り切れないときは、`(1:QueryStep:width_j)` の最後がwidth_jにならない。既存の `pkCentroid_interp2_1cycle.m` と同じ扱いなので、そのままにする（`dInterp` の `meshgrid(1:step:width,...)` と同じ並び）。

#### `src/trackingSeeds.m`（新規）

```matlab
function seeds = trackingSeeds(grooveSelection, numSegments)
% cycleResult の grooveSelection から、写真ごとの追跡の始点（numImages x 2）を返す。
% 新しい形式（.seeds がある）ならそれを返す。古い形式（手動選択の .p1 が
% (numImages*numSegments x 2)）なら、各写真の最初のセグメントの p1 を返す。
% 古い結果ファイルの手動選択を使って、ginput なしで追跡を再現するため。
    arguments
        grooveSelection (1,1) struct
        numSegments (1,1) double {mustBeInteger,mustBePositive}
    end
```

- 新しい形式：`isfield(gs,"seeds") && ~isempty(gs.seeds)` → `gs.seeds`。
- 古い形式：`isfield(gs,"p1")` で、行数が `numSegments` の倍数かつ1以上 → `gs.p1(1:numSegments:end, :)`。古い形式の `p1` のxはセグメントの中の座標だが、各写真の最初のセグメントでは `xOffsets(1)=0` なので、写真1枚分を連結した座標と同じになる。
- どちらでもない → `error("trackingSeeds:noSelection", ...)`。`grooveSelection` フィールドそのものが無いファイル（`origD_0731` など）は、スクリプト側で `isfield(prev,"grooveSelection")` を確かめてからエラーを出す。

### 4.3 新しく作るファイルと、変えるファイル

| 区分 | パス | 内容 |
|---|---|---|
| 新規 | `src/trackGroove.m` | 逐次追跡 |
| 新規 | `src/detrendTrackedShape.m` | 写真ごとの多項式デトレンド |
| 新規 | `src/mergeSegmentPoints.m` | セグメントの点群を写真1枚分に連結し、xQueryを作る |
| 新規 | `src/trackingSeeds.m` | 新旧の `grooveSelection` から始点を取り出す |
| 新規 | `scripts/grooveTrack_1cycle.m` | 高解像度化なしで1周分を自動追跡し、cycleResultを保存する |
| 新規 | `test/unit/TrackGrooveTest.m`、`test/unit/DetrendTrackedShapeTest.m`、`test/unit/MergeSegmentPointsTest.m`、`test/unit/TrackingSeedsTest.m` | unitテスト |
| 変更 | `test/unit/CycleResultTest.m` | 追加のフィールドを持つ `GrooveSelection` が保存・読み込みでそのまま残ることのテストを1件追加 |
| 変更（コメントのみ） | `src/saveCycleResult.m` | ヘルプの `GrooveSelection` の説明に「`p1`/`p2` 以外のフィールド（`method`・`seeds`・`tracking`）もそのまま保存される」と追記する。**コードは変えない** |
| 変更 | `README.md` | `src/` の共通関数の一覧に新しい4つの関数、`scripts/` の一覧に `grooveTrack_1cycle.m` を追加する。「溝の自動追跡（trackGroove）」の節を新設し（パラメータが元の画像のpxであることも書く）、「1周分の実験結果の保存」の表の `grooveSelection` の行に、追跡のときのフィールドを追記する |

触らないもの：`fitGroove.m`、`extractGrooveShape.m`、`detrendGrooveShape.m`、`extractGrooveWaveform.m`、`findGrooveCenter.m`、`loadCycleResult.m`、`cycleConditions.m`、`cycleMethodResult.m`、`DarknessMap.m`、既存の `scripts/`（`pkCentroid_1cycle.m` を含む）、`archive/` の下すべて、`data/`、`experiments/` の既存ファイル。

### 4.4 保存形式と互換性

`saveCycleResult(cond, allImg, [res_cnt res_max], GrooveSelection=gs, FileName="cycleResult_origD_track_"+date, Overwrite=false)` で保存する。

- `result.centroid` / `result.localMax`：既存と同じ形（`cycleMethodResult` で作る）。`pts`（80×1 `GroovePointCloud`）、`xcoords`（80×1 cell、各セルはセグメントのローカルなx `(1:QUERY_STEP:width)'`）、`ycoords`（80×1 cell、**写真ごとにデトレンドしたもの**を `counts` で分けたもの）、`y_comb`、`audio`。→ 既存の図・比較スクリプトは、`ycoords`・`y_comb`・`audio` を読むので、そのまま使える。
- `result.grooveSelection`（新しいフィールドを足す。`saveCycleResult` は `p1`/`p2` だけを検証し、他はそのまま保存する）：

  | フィールド | 型 | 内容 |
  |---|---|---|
  | `p1`, `p2` | 80×2 double | 追跡した**重心法**のy座標（補間済み、デトレンド前）から作る。セグメントkの最初と最後の列の番号を `cumsum(counts)` から求め、`p1(k,:) = [1, y(最初の列)]`、`p2(k,:) = [width_j, y(最後の列)]`。既存の再現スクリプト（`fitGroove` の `P1`/`P2`、`bilateralOri_centroid_1cycle.m` の80×2の検査）でも同じ溝を選べる（Q3の案a） |
  | `method` | string | `"tracking"`（古いファイルには無い。無ければ手動選択とみなす） |
  | `seeds` | 8×2 double | 写真ごとのクリック位置 `[x y]`（元の画像のpx）。xは写真1枚分を連結した座標 |
  | `tracking` | 1×1 struct | `tolerance`、`fitLength`、`snapRadius`、`initLength`、`maxGapLength`、`minFitPoints`（5）、`queryStep`、`polyDegree`、`detrendScope`（`"photo"`）、`ampDivisor`、`yAbsCnt`・`yAbsMax`（8×1 cell。写真ごとの補間済み・デトレンド前のy座標）、`foundCnt`・`foundMax`（8×1 cell logical）。長さはすべて元の画像のpx |

  `struct('p1',allP1,...,'tracking',trk)` で作るときは、`trk` を先にdot記法で組み立てる。cellを `struct()` に直接渡すと struct配列になってしまうので注意する。
- `result.conditions`：`cycleConditions` は変えない。追跡では使わない必須の引数 `ThHist`・`BinWidth`・`HPrl`・`Tol` には `NaN` を渡す（仮定A4）。`PolyDegree=POLY_DEGREE`、`ScriptName="grooveTrack_1cycle"`、`Note="自動追跡（パラメータは grooveSelection.tracking）"`、`Upsampling="origD"`。
- ファイル名：`experiments/<日付>/cycleResult_origD_track_<日付>.mat`（仮定A1）。読み込むときは `fullfile(experimentDir(root,date,Create=false), "cycleResult_origD_track_"+date+".mat")` を使う（`cycleResultPath` は `_track` に対応していないので）。
- 読み込みの互換性：
  - 古いファイル（`grooveSelection` が無い／`p1`/`p2` だけ）：比較スクリプトは `ycoords` を読むだけなので問題ない。追跡の再現には `trackingSeeds` を使う（`intpD_0731` などの80×2から8点を取り出す）。
  - 新しいファイル：`trackingSeeds` で `seeds` を返す。`p1`/`p2` も80×2なので、古い再現スクリプトでも読める。
- 振幅：`amp = (y_comb - mean(y_comb)) / AMP_DIV`、`AMP_DIV = 1.5`。既存の `tol/2`（`tol=3`）と同じ値にして、音量を比べられるようにする（仮定A2）。

### 4.5 スクリプト `scripts/grooveTrack_1cycle.m` のパラメータ

```matlab
NUM_IMAGES = 8; NUM_SEGMENTS = 10; TOTAL_SEGMENTS = NUM_IMAGES*NUM_SEGMENTS;
L_MASK = 20; D_THRESH = 0.6; WIDTH_THRESH = 8;      % pkCentroid_1cycle.m と同じ
QUERY_STEP = 1;           % 列の間隔[px]。今回は高解像度化なし（origD）なので1
% trackGroove のパラメータ。長さはすべて元の画像のpx（高解像度化しても値を変えなくてよい）
TRACK_TOL = 2;            % 予測位置から採る点までの最大距離（y方向）
FIT_LENGTH = 60;          % 予測の直線あてはめに使う範囲（最後に採った点から。Q4）
SNAP_RADIUS = 10;         % 始点の初期化でクリック位置から探す範囲（y方向）
INIT_LENGTH = 20;         % 始点の初期化に使う範囲（始点の列から右へ）
MAX_GAP_LENGTH = 40;      % これより長く欠損が続いたら警告する
POLY_DEGREE = 9;          % detrendTrackedShape（Q2で決定。評価の結果で見直すことがある）
AMP_DIV = 1.5;            % 振幅の正規化（既存の tol/2 と同じ）
date = "MMDD";            % 実行日
PREV_RESULT_PATH = "";    % 空なら写真ごとにginput。結果.matのパスを入れるとtrackingSeedsで始点を再現する
SAVE_TRACK_FIG = true;    % 写真ごとに追跡結果を画像に重ねた図を results/<日付>/ に保存する
```

- **マスクについてのコメント**（4.1）：`omitMask` を呼ぶ `for jSegment` のループのところに、「マスク（omitMaskで落とす低輝度の列）は写真の両端にしか無いので、将来は写真1枚単位で omitMask〜GrooveExtractor を行う形に変える可能性がある」という趣旨のコメントを書く。
- **wavと図の名前**：`AudioData` の名前を `"audio (centroid method)(original)(tracking)"`・`"audio (local maximum method)(original)(tracking)"` にする。`pkCentroid_1cycle.m` と同じ名前にすると、同じ日に評価用の手動選択の再現（7章）を作ったときに、`results/<日付>/` の wav・図を上書きし合う（`audiowrite`・`saveas` は黙って上書きする）。
- クリックするとき（`PREV_RESULT_PATH == ""`）：写真1枚分の画像 `[allImg(ks).img]`（高さは同じなので横に連結できる）を `ImageData(imgPhoto,[iImg;0]).showImage("fit")` で表示する。`pksCnt` を小さな点（`scatter(...,2,"cyan","filled")`）で重ね、`title` に「写真iImg：左端付近で追跡する溝をクリック」と書いて、`seed = ginput(1)` → `close`。
- 確認用の図（`SAVE_TRACK_FIG`）：画像に `ptsCnt` の経路（赤線）と `seed`（黄色の三角）を重ね、`results/<日付>/grooveTrack_img<i>.png` に保存する。再現するとき（ginput なし）は `figure('Visible','off')` で作って保存し、閉じる。
- `sum(counts) == numel(xQuery)` を確かめる（`mat2cell` で分け直すため）。
- 実行の最後に、写真ごとの `info.numMissing`・`info.maxGapLength` を `fprintf` で表示する。

## 5. 実装の手順

1. `src/mergeSegmentPoints.m` と `test/unit/MergeSegmentPointsTest.m` を書く（`QueryStep` を含む）。
2. `src/trackGroove.m` と `test/unit/TrackGrooveTest.m` を書く（4.2の手順1〜6のとおり。長さの引数はpx、窓の基準は最後に採った点、`MIN_FIT_POINTS=5`）。
3. `src/detrendTrackedShape.m` と `test/unit/DetrendTrackedShapeTest.m` を書く。次数の既定値は9。
4. `src/trackingSeeds.m` と `test/unit/TrackingSeedsTest.m` を書く。
5. `test/unit/CycleResultTest.m` に、`GrooveSelection` の追加フィールドが保存・読み込みで残ることのテストを足す。`src/saveCycleResult.m` のヘルプに追記する（コードは変えない）。
6. `scripts/grooveTrack_1cycle.m` を書く（4.1・4.4・4.5）。点の検出の部分は `pkCentroid_1cycle.m` L84–104 を写す。**`for jSegment` のループのところに、マスクについてのコメント（「マスクは写真の両端にしか無いので、将来は写真1枚単位で omitMask〜GrooveExtractor を行う形に変える可能性がある」）を書く。** `allPts_*` は今回はセグメントごとに作る。`AudioData` の名前に `(tracking)` を付ける。
7. 書いた `.m` すべてに `checkcode`（`mcp__matlab__check_matlab_code`）をかけ、警告を0にする。`cd test; results = runAllTests;` が全部通ることを確かめる（`StaticAnalysisTest` が新しいスクリプトも検査する）。
8. 動作の確認（実装担当が行ってよい範囲）：`PREV_RESULT_PATH = fullfile(root,"experiments","0731","cycleResult_intpD_0731.mat")` にして、`ginput` なしで1回実行する。`date` は実行日にする。保存先は `experiments/<実行日>/cycleResult_origD_track_<実行日>.mat` で、既存ファイルの上書きにはならない。この保存は issue の要求なので行ってよい。写真ごとの欠損数が付録A.2の値（0,7,6,0,0,4,0,0）と同じであることを確かめる（`FitLength` が30でも60でも同じになる。付録A.6・A.8）。実行が終わったら、スクリプトの `PREV_RESULT_PATH` を `""` に戻すかどうかは実装の報告に書く（リポジトリに残す値を決めるのはメイン）。
9. `README.md` を更新する（4.3）。

## 6. テストの方針（合成データ）

共通：`TestClassSetup` で `PathFixture` を使い `src/` を追加する。図は作らない。

**`TrackGrooveTest`**（合成の点群：`x=1:600`。溝を5本、間隔25px。各溝は `y = y_k + 0.01*x + 0.5*sin(2πx/37)`）
- 真ん中の溝の近く（+1px）をクリックすると、その溝の真のy座標と一致する（`AbsTol` 1e-9）。`found` はすべて true。
- クリックが +4px ずれていても、同じ結果になる（初期化で引き寄せられる）。
- 一部の列（例：x=200〜220）でその溝の点を消すと、そこは `found=false` になり、両端の点を結ぶ直線で補間される。`info.numMissing == 21`、`info.maxGapLength == 21`（列の間隔1px）。欠損の後は元の溝に戻る。
- 外れ点：ある列で、溝から1.5pxの位置に点を追加し、真の点を消す → その点を採る（`Tolerance` 以内なので）。溝から5pxの位置に追加した場合は採らない（`found=false`）。
- 左向きの追跡：`seed(1)=300`（真ん中）をクリックしても、x=1〜299 も同じ溝で埋まる。
- **長さの単位（高解像度化への対応）**：同じ溝を `xQuery=(1:0.25:600)'` で作った点群（各列に5本分の点）でも、同じ引数（pxの値）で追跡でき、整数のxでの値が `xQuery=(1:600)'` の結果と一致する（`AbsTol` 1e-9。点群は真の式から作るので一致する）。
- **欠損の警告がpxで決まる**：`xQuery=(1:0.25:600)'` で x=200〜220 の点を消す（81列、長さ約20px）。`MaxGapLength=25` では警告が出ず（`verifyWarningFree`）、`MaxGapLength=15` では `trackGroove:longGap` が出る（`verifyWarning`）。列数で判定していると、81>25 で警告が出てしまうので、単位の取り違えを検出できる。
- **窓の基準が最後に採った点であること**：傾き0.2の直線の溝（`y = y_k + 0.2*x`）で、`FitLength=10` より長い欠損（x=200〜230）を作る。欠損の後で同じ溝に戻る（今の列を基準にすると、欠損の後は窓が空になり、最後の点のyで予測して6px以上ずれ、`Tolerance=2` を超えて見失う）。
- `seed` から `SnapRadius` 以内に点が無ければ `trackGroove:seedNotFound` でエラーになる。

**`DetrendTrackedShapeTest`**
- `y = 3次式 + 正弦波`、`PolyDegree=3` → 結果の平均が0（`AbsTol` 1e-10）。正弦波を同じ方法でデトレンドしたものと一致する。
- `x=1:4000`、`PolyDegree=9` で警告が出ない（`verifyWarningFree`）。
- x座標が変わらない。

**`MergeSegmentPointsTest`**
- 幅 `[3 4 2]` の `GroovePointCloud` を3つ（手で `peakCells` を入れる）→ `xOffsets == [0;3;7]`、`counts == [3;4;2]`、`xQuery == (1:9)'`、点のx座標がずれて連結される。
- `QueryStep=0.5` → `counts == [5;7;3]`、`xQuery` はセグメントの中で0.5刻み、境目で1px（例：`[1 1.5 2 2.5 3 4 4.5 …]'`）。
- 点が1つも無いセグメントがあってもエラーにならない。

**`TrackingSeedsTest`**
- `seeds` があればそれを返す。
- `p1` が 20×2（`numSegments=10`）なら、`p1([1 11],:)` を返す。
- `p1`/`p2` が空で `seeds` も無ければ `trackingSeeds:noSelection`。

**`CycleResultTest`（追加1件）**
- `GrooveSelection=struct('p1',p1,'p2',p2,'method',"tracking",'seeds',seeds,'tracking',trk)` を保存して読み込み、`method`・`seeds`・`tracking` のフィールド（`trk.fitLength` などを含む）がそのまま残っている。

## 7. 評価担当への申し送り

### 7.1 比べる基準のデータ

1. **今のコードで手動選択を再現した cycleResult（主な基準。評価の段階で作る）**
   - 作るもの：`experiments/<実行日>/cycleResult_origD_<実行日>.mat`（とその図・wav）。`scripts/pkCentroid_1cycle.m` の手動選択を、`experiments/0731/cycleResult_intpD_0731.mat` の `grooveSelection.p1`/`p2` で再現したもの。ユーザーの指示（2026-10-13）により、issue #25 の実装が終わった後の評価の段階で作る。ad46b44 以降で初めての1周分のデータになる。
   - 作り方（リポジトリのスクリプトは変えない。仮定A6）：
     1. 実行前に、`experiments/<実行日>/cycleResult_origD_<実行日>.mat` と、`results/<実行日>/` の `audio_(centroid_method)(original)*`・`audio_(local_maximum_method)(original)*` が無いことを確かめる。あれば止めてメインに報告する。
     2. `scripts/pkCentroid_1cycle.m` をスクラッチパッド（リポジトリの外）に別名でコピーし、コピーの2行だけを変える。
        - L28 `date = "0731";` → `date = "<実行日 MMDD>";`
        - L35 `PREV_RESULT_PATH = "";` → `PREV_RESULT_PATH = fullfile(proj.RootFolder,"experiments","0731","cycleResult_intpD_0731.mat");`
        - 任意：L222 の `cycleConditions` に `Note="intpD_0731のgrooveSelectionを再現（issue #25 の比較基準）"` を足す。L233 の `saveCycleResult` に `Overwrite=false` を明示してもよい（既定と同じ）。
     3. `Research.prj` を開いた状態で、コピーを `run` で実行する（`ginput` は呼ばれない。約5秒＋図・wavの保存）。
     4. 残った図（L163・L186 で作るもの）を閉じる。`saveCycleResult:fileExists` の警告が出ていないかを確かめる（出たら `_2` 付きで保存されている）。
   - 確かめること：`result.grooveSelection.p1`/`p2` が `intpD_0731` のものと同じ。`result.meta.gitCommit` が実装後のコミットになっている。正解（`origD_0731`）との差が、計画段階の値（RMSEの中央値0.111px・最大0.162px、相関の中央値0.854・最小0.704。付録A.4）と同じ。
   - 注意（2.6）：`date` を変えずに実行すると、`results/0731/` の既存の図・wavを上書きする。`saveCycleResult` の `Overwrite=false` は、同名のファイルがあるとエラーではなく `_2` を付けて保存する。
2. **正解データ**：`experiments/0731/cycleResult_origD_0731.mat`（読み取りのみ）。使えるのは `centroid.ycoords`・`localMax.ycoords`（80×1、セグメントごとに3次デトレンドして平均0）。`pts` は空で、`grooveSelection` は無い。写真ごとの溝形状は、`vertcat(ycoords{(i-1)*10+(1:10)})` から平均を引いて作る。**今のコードでは完全には再現できない**（2.4）ので、合格の基準を決めるときは上の下限を考える。
3. **始点**：`experiments/0731/cycleResult_intpD_0731.mat` の `grooveSelection.p1(1:10:end,:)`（`trackingSeeds` で取り出せる）。実装担当が手順8で作る `cycleResult_origD_track_<日付>.mat` には `seeds` が入っているので、以後はそれも使える。

### 7.2 見てほしい点

1. **同じ溝を追えているか**（追跡そのものの確認）：`grooveSelection.tracking.yAbsCnt{i}` を `counts` でセグメントに分け、それぞれに `detrendGrooveShape`（3次）をかけて、7.1の1（手動選択の再現ファイル）の `ycoords` とセグメントごとに比べる。計画段階の試作では、重心法は80中77セグメントでRMSE 0（max 0.087）、局所的最大値法は75セグメントで0（max 0.278、手動側が落とした点の差）。正解とも比べる（中央値0.111、0.854程度になるはず）。
2. **最終の出力**：写真ごとに平均0にした `ycoords`・`y_comb` を、手動選択の再現ファイルと正解の両方と比べる（RMSE・相関係数、写真ごとと全体）。デトレンドの次数によって値が変わる（2.4の表）。この差は「基準がセグメントごとのデトレンドで作られていること」から来るもので、追跡の誤りではない。次数を3・5・9・15と変えた値も報告すると、次数の見直し（Q2）の判断の材料になる（`yAbsCnt` に `detrendTrackedShape` をかけ直せば、再実行は要らない）。
3. **境目の段差**：写真の中のセグメントの境目での段差（正解：中央値0.146px、試作の9次：0.012px）。
4. **確認用の図**：`results/<日付>/grooveTrack_img<i>.png` を見て、溝を外れていないか（目視はユーザーにも頼む）。
5. 欠損の数：写真ごとに `~found` の数（試作では 0,7,6,0,0,4,0,0）と、`info.maxGapLength`（試作では最長7px）。
6. **音声**：手動選択の再現ファイルと追跡の `audio` のスペクトログラムを並べる。再現ファイル側にある約104Hz（セグメントの境目の周期）の線が、追跡側で消えているかを見る。9次で残る40〜150Hzの成分が音か雑音かは、スペクトログラムと試聴（ユーザー）で判断する。**次数は、この結果を見て見直すことがある**（Q2の決定の但し書き）。
- 欠損の扱い：既存の比較の方法と同じく、補間したあとの全列を対象にする（`found` で絞り込まない）。

## 8. 決定事項と未決事項

### 8.1 決定事項（2026-10-13 ユーザーの回答）

- **Q1 追跡の方法：(a) 逐次追跡。** 直近の採用点の直線で予測し、±2px以内の最も近い点を採る。パラメータの単位は、ユーザーの質問を受けて元の画像のpxにした（3.2）。値は `Tolerance=2`、`SnapRadius=10`、`InitLength=20`、`MaxGapLength=40`、`FitLength=60`（Q4）。
- **Q2 デトレンド：(b) 写真ごとに9次。** ただし最終的な次数は、評価段階のスペクトログラム・試聴を見て見直す可能性がある（7.2の2・6）。
- **Q3 保存形式：(a)。** `grooveSelection` に `method="tracking"`・`seeds`（8×2）・`tracking` を足し、`p1`/`p2` には追跡した経路から作ったセグメントの両端の点（80×2）を入れる。`saveCycleResult`・`loadCycleResult` は変えない。
- **仮定A1〜A4：承認済み。** A5は書き換えた（下の「仮定」）。
- **マスク**：`omitMask`〜`GrooveExtractor` は今回はセグメントごとに行い、将来は写真1枚単位に変える可能性があることをスクリプトのコメントに残す（4.1・4.5・5章の6）。
- **評価の基準**：今のコードで手動選択を再現した `cycleResult_origD_<日付>.mat` を、実装の後（評価の段階）に作る（7.1）。

- **Q4 `FitLength` の既定値：(a) 60px。**（2026-10-13 ユーザーの回答。以下は検討の記録）

### 8.2 未決事項

なし（Q4は決定済み。検討の記録を残す）。

**Q4. `FitLength`（予測の直線あてはめに使う範囲）の既定値**
- 背景：単位をpxにしたのを機に見直した。実データ8枚では窓が10〜100pxのどれでも結果は同じ。違いが出るのは長い欠損（ホコリなど）のときだけで、人工的に候補を消した試行では、30pxだと20px以上の欠損の後で溝を見失うことがあった（6か所中2か所）。
- 選択肢：
  - (a) **60px**：実データの結果は30pxと完全に同じ。人工欠損では、`origD`・`intpD` とも40pxまでのすべての欠損の後で元の溝に戻れた。溝が急に曲がる所では、予測が遅れる可能性がある（実データでは問題なし）。
  - (b) 30px（前回の計画の `NumFit=30` と同じ長さ）：実データの結果は同じ。20px以上の欠損に弱い。
- 推奨：**(a) 60px**。理由：今のデータの出力は変わらず、長い欠損への強さだけが上がる。急に曲がる所で問題が出ても、引数なので値を下げられる。
- 止めるか：止めない。決まるまでは60pxで進める（値は1か所の定数と既定値だけなので、後で直しても手戻りは小さい）。

## 仮定（実装担当はこのとおりに進める。A1〜A4はユーザーが承認済み）

- A1：保存ファイル名は `cycleResult_origD_track_<日付>.mat`。同じ日に手動の `cycleResult_origD_<日付>.mat` を作っても重ならないように、`_track` を付ける。
- A2：振幅は `AMP_DIV = 1.5`（既存の `tol/2` と同じ）で割る。音量を既存と比べられるようにするため。
- A3：重心法と局所的最大値法は、同じクリック位置から別々に追跡する。
- A4：`cycleConditions` の追跡で使わない必須の引数（`ThHist`・`BinWidth`・`HPrl`・`Tol`）には `NaN` を渡す。追跡のパラメータは `grooveSelection.tracking` に入れる。
- A5（2026-10-13 書き換え）：今回の実装は高解像度化なし（`origD`）の条件だけを対象にする（`intpD`/`rsmplD` のスクリプトは作らない）。ただし、高解像度化した画像（`intpD`・`rsmplD`）にも今後この手法を使う予定なので、関数はそれを前提に設計する。具体的には、(1) `trackGroove` は分数刻みの `xQuery` を受け付ける、(2) 長さのパラメータ（`FitLength`・`InitLength`・`MaxGapLength`・`Tolerance`・`SnapRadius`）はすべて元の画像のpxで指定する、(3) `mergeSegmentPoints` は `QueryStep` で `intpD` の列の並びを作れる、(4) `detrendTrackedShape` は元の画像のpxのxにあてはめる。`rsmplD` は横方向が細かくならない（2.5）ので、`QueryStep=1` でそのまま使える。
- A6（新規）：評価の基準（手動選択の再現ファイル）は、`scripts/pkCentroid_1cycle.m` をスクラッチパッドにコピーし、`date` と `PREV_RESULT_PATH` の2行だけを変えて実行して作る。リポジトリのスクリプトは変えない（`date="0731"` を書き換えたままコミットしてしまうのを避けるため）。ユーザーが自分で2行を書き換えて実行したい場合は、それでもよい（作られるファイルは同じ）。

## 9. リスク

| リスク | 起きたときの症状 | 代わりの案・対策 |
|---|---|---|
| クリックが溝から8px以上ずれる | 隣の溝や偽の点から追跡が始まる | 確認用の図（`grooveTrack_img<i>.png`）で気づけるようにする。クリックのときの図に点群を重ねる。`SnapRadius` を小さくする |
| ホコリなどで長く欠損する | 予測がずれて、隣の点を採る、または欠損が続く | `trackGroove:longGap` の警告（40px）で気づける。窓の基準を最後に採った点にし、`FitLength=60` にすれば、人工欠損40pxまでは戻れた（付録A.8）。それより長い欠損で困る例が出たら案B（罰則つきDP）に差し替える |
| 許容幅（±2px）の中に偽の点がある | 誤った点を採る（外れ値1点） | 実データでは、許容幅（±3px）の中に候補が2点以上ある列は0だった。出てきたら案Bにする |
| 高い次数のデトレンドで、写真の両端が歪む | 写真の境目に大きな段差やうねりが出る | 評価（7.2の2・3）で確かめる。両端だけ低い次数にするか、次数を下げる |
| 正解との差が、デトレンドの違いと追跡の違いに分けられない | 評価の数字が解釈しにくい | 7.2の1（同じデトレンドをかけて比べる）と2（最終の出力）を分けて評価する。正解のほかに、手動選択の再現ファイルを基準にする |
| 局所的最大値法はy座標が整数なので、1pxずつ飛ぶ | `Tolerance=1` だと追えなくなる（試作で確認） | `Tolerance` は1.5以上にする（既定2） |
| 将来 `intpD` で使うと、窓の中の点が多く（最大480点）遅くなる | 1周の追跡に数十秒以上かかる | 最小二乗の閉じた式で書く（4.2）。今回の `origD` では問題にならない |
| 評価用の再現ファイルを作るときに、`date` を変え忘れる | `results/0731/` の既存の図・wavを上書きする | 7.1の手順1で実行前にファイルの有無を確かめる。スクラッチパッドのコピーで実行する（A6） |

## 10. 付録：MATLABでの試行

A.1〜A.5 は 2026-10-12、A.6〜A.8 は 2026-10-13 に、`Research.prj` を `openProject` で開いて実行した。すべて読み取りのみ。図は閉じ、変数は `clear` した。

### A.1 写真ごとの点群を作る（全80セグメント、約5秒）

```matlab
root = currentProject().RootFolder;
R0 = loadCycleResult(cycleResultPath(root,"origD","0731"));   % 正解
Ri = loadCycleResult(cycleResultPath(root,"intpD","0731"));   % 始点の入手先
fn = R0.conditions.filenames;
PK_cnt = cell(80,1); PK_max = cell(80,1); W = zeros(80,1);
for iImg=1:8
  g = rgb2gray(imread(fn(9-iImg)+".png")); wd = size(g,2);
  dv = round(wd/10); xa = [1:dv:wd wd+1]';
  for j=1:10
    k=(iImg-1)*10+j;
    map = DarknessMap(ImageData(omitMask(g(:,xa(j):xa(j+1)-1),20),[iImg;j]));
    map = map.setDiffTF(0.6); ex = GrooveExtractor(map); c=cell(map.nCols,1); m=c;
    for x=1:map.nCols
      [f1,l1]=ex.findThresholdIntervals(map,x); [ex,~,~,np]=ex.findGrooveBottomIntervals(map,x,f1,l1,8);
      c{x}=[x*ones(np,1) ex.extractByCentroid(map,x)]; m{x}=[x*ones(np,1) ex.extractByLocalMax(map,x)];
    end
    PK_cnt{k}=vertcat(c{:}); PK_max{k}=vertcat(m{:}); W(k)=map.nCols;
  end
end
% 写真ごとに連結（segOff: セグメントのxのずらし量）
PH_cnt=cell(8,1); PH_max=cell(8,1); PW=zeros(8,1); segOff=zeros(80,1);
for i=1:8, off=0; a={}; b={}; for j=1:10, k=(i-1)*10+j; segOff(k)=off; a{j}=PK_cnt{k}+[off 0]; b{j}=PK_max{k}+[off 0]; off=off+W(k); end
  PH_cnt{i}=vertcat(a{:}); PH_max{i}=vertcat(b{:}); PW(i)=off; end
seeds = Ri.grooveSelection.p1(1:10:end,:);
```

結果：写真の幅（連結後）は `[3999 3999 3997 3999 3998 3997 3999 4111]`。1列あたりの候補は中央値17（16〜22）。溝の間隔は25〜30px。セグメントの幅は両端だけが狭い（例：398, 401×8, 393）。写真の高さは454〜562。`Ri.grooveSelection.p1` は80×2、`p2` のxは293〜395。

### A.2 逐次追跡（案A。前回の計画段階の簡易版：x=1から右へ一方向）

```matlab
TOL=2; NFIT=30;
for i=1:8
  P=sortrows(PH_cnt{i},1); nc=PW(i); cols=mat2cell(P(:,2),accumarray(P(:,1),1,[nc 1]));
  y=NaN(nc,1); accX=[]; accY=[];
  for x=1:nc
    if numel(accX)>=5, s=max(1,numel(accX)-NFIT+1); pp=polyfit(accX(s:end),accY(s:end),1); yp=polyval(pp,x);
    elseif ~isempty(accX), yp=accY(end); else, yp=seeds(i,2); end
    if isempty(accX), tl=6; else, tl=TOL; end
    [d,ii]=min(abs(cols{x}-yp)); if d<=tl, y(x)=cols{x}(ii); accX(end+1,1)=x; accY(end+1,1)=y(x); end
  end
  TR_B{i}=y;
end
```

結果：
- 欠損した列の数は `[0 7 6 0 0 4 0 0]`。始点と終点のyは、手動の `p1`（写真の最初のセグメント）・`p2`（最後のセグメント）と1.5px以内で一致した。各セグメントの右端の `p2` との差は、写真ごとに最大1.0〜3.0px。
- `TOL` 1.5〜4 × `NFIT` 10/30/100 のすべてで同じ結果。`TOL=1` は欠損が89〜1960列に増えた。
- 双方向追跡と初期化（`SnapRadius=10`、20列、中央値）を入れると、クリックが ±5px ずれても8枚とも同じ結果。+8px で写真5、±10px で写真1・3・5・6・7・8が失敗した（失敗するのは毎回1〜数枚）。

### A.3 DP（案B。参考ブランチのコストに、飛ばした列の罰則 `GAPPEN*(dx-1)` を足したもの）

```matlab
LX=1; LY=15; MAXGAP=15;   % GAPPEN = 0（参考ブランチのまま）と 30
% 列ごとに：C = cst(jj)' + LX*dx + GAPPEN*(dx-1) + LY*(Y(ii)-Y(jj)').^2 の最小をとる
% 始点（x=1, y=seed）から入れるのは最初のMAXGAP列だけ。終点は、最後のMAXGAP列のノードの
% cst + (LX+GAPPEN)*(nc-X) が最小のもの
```

結果：`GAPPEN=0` では、欠損した列が写真ごとに1678〜3239列（4000列中）。補間すると、逐次追跡との差（RMSE）は0.16〜0.24px で、音の成分（0.16〜0.32px）と同じくらいになった。`GAPPEN=30` では、8枚とも逐次追跡と完全に一致した（`isequaln`）。計算時間は8枚で約1.4秒。

### A.4 手動選択の再現と、正解との比較

```matlab
gs = Ri.grooveSelection;
for k=1:80
  j=mod(k-1,10)+1;
  [p1,~,pc] = fitGroove(j,[],[0 0],W(k),8,{PK_max{k},PK_cnt{k}},P1=gs.p1(k,:),P2=gs.p2(k,:));
  RP{k} = extractGrooveWaveform(pc{2},p1(2),(1:W(k))',BinWidth=5,MinPeakHeight=150,Tolerance=3);
end
% 追跡結果を同じ方法で比べるとき：
% y=fillmissing(TR_B{i},"linear"); t=detrendGrooveShape([(1:W(k))', y(segOff(k)+(1:W(k))')]);
```

`scripts/pkCentroid_1cycle.m` を `PREV_RESULT_PATH` で再現したときと同じ計算（`TH_HIST=150`、`binWidth=5`、`tol=3`、`h_prl=8`、`w_prl=幅`）。評価の段階で作るファイル（7.1の1）の `ycoords` は、この `RP` と同じになるはず。

結果：
- 手動の再現と正解：RMSEは中央値0.111（最大0.162）、相関は中央値0.854（最小0.704）。隣の溝（±1、±2本）では相関が −0.17〜0.21。
- 差の中身：セグメント1では、398列中21列で約±0.44px、それ以外はほぼ0（多項式では説明できない差）。`ad46b44`（2026-08-14、溝底検出の境界値の扱いの変更）より前のコードで正解を作ったことによる。
- 追跡（セグメントごと3次）と手動の再現：重心法はRMSEが中央値0（最大0.087、差があるのは k=1,2,75）。局所的最大値法は中央値0（最大0.278、k=1,2,38,53,68）。差がある列は、すべて追跡側だけが採った点だった。手動側はヒストグラムの中心から ±3px の外にあった点を落としていた（ずれは −3.0〜−3.7px、追跡の経路からの距離は1px以内）。
- 局所的最大値法の追跡と正解：RMSEは中央値0.083、相関は中央値0.962（最小0.653）。

### A.5 デトレンド（写真ごと）の比較

```matlab
for i=1:8
  y=fillmissing(TR_B{i},"linear"); x=(1:PW(i))';
  g=vertcat(R0.centroid.ycoords{(i-1)*10+(1:10)}); g=g-mean(g);
  [p,S,mu]=polyfit(x,y,deg); r=y-polyval(p,x,S,mu); r=r-mean(r);
  % RMSE = sqrt(mean((r-g).^2)), 相関 = corrcoef(r,g)
end
% 周波数の目安：fs=round(32099/(60/78))=41729 Hz、L=3999 の正弦波（位相6通り）に同じデトレンドをかけ、std の比を見る
```

結果：2.4の表のとおり。振幅の比（デトレンド後のstd ÷ 元のstd）は次のとおり。

| 周波数 | 3次 | 5次 | 9次 | 15次 | セグメントごと3次 |
|---|---|---|---|---|---|
| 10Hz | 0.16 | 0.01 | 0 | 0 | 0 |
| 20Hz | 0.87 | 0.37 | 0.01 | 0 | 0 |
| 30Hz | 0.93 | 0.90 | 0.19 | 0 | 0 |
| 50Hz | 0.98 | 0.95 | 0.85 | 0.20 | 0.01 |
| 100Hz | 1.00 | 0.99 | 0.97 | 0.92 | 0.18 |
| 150Hz | 1.00 | 1.00 | 0.99 | 0.97 | 0.56 |
| 200Hz | 1.00 | 1.00 | 0.99 | 0.98 | 0.88 |

`detrendGrooveShape`（スケーリングなしの `polyfit`）を約4000列・高い次数で使うと、`MATLAB:polyfit:RepeatedPointsOrRescale` の警告が出た。`[p,S,mu]` 形式では出なかった。

境目の段差（セグメントの右端と、次のセグメントの左端の差の絶対値）：正解は中央値0.146px（平均0.186px）。隣どうしの列の差の中央値は0.014px。追跡＋写真ごと9次では、セグメントの境目の段差は中央値0.012px。写真どうしの境目の段差は、正解で中央値0.095px。

### A.6 窓の単位：列数と長さ[px]の比較（origD、8枚 × 重心法・局所的最大値法）

4.2の手順（双方向、初期化つき）をそのまま書いたもの。`useLen=false` が列数の版（`NumFit=30`・`NumInit=20`）、`true` が長さの版（`FitLength=30`・`InitLength=20`、窓は最後に採った点から）。A.1の変数を使う。

```matlab
TOL=2; SNAP=10; FITN=30; INITN=20; MINPTS=5;
for useLen=[false true], for meth=["cnt","max"]
  if meth=="cnt", PH=PH_cnt; else, PH=PH_max; end
  for i=1:8
    P=PH{i}; xq=(1:PW(i))'; n=numel(xq); seed=seeds(i,:);
    [tf,col]=ismember(P(:,1),xq); cands=accumarray(col(tf),P(tf,2),[n 1],@(v){v},{[]});
    [~,s]=min(abs(xq-seed(1)));
    if useLen, cs=s:find(xq-xq(s)<INITN,1,'last'); else, cs=s:min(n,s+INITN-1); end
    vals=[]; for c=cs, v=cands{c}; if ~isempty(v), [d,ii]=min(abs(v-seed(2))); if d<=SNAP, vals(end+1)=v(ii); end, end, end
    y0=median(vals); y=NaN(n,1);
    for dirn=[1 -1]
      if dirn==1, aX=[]; aY=[]; cr=s:n;
      else
        fx=find(~isnan(y));
        if useLen, sel=fx(xq(fx)-xq(fx(1))<FITN); else, sel=fx(1:min(FITN,numel(fx))); end
        sel=flipud(sel); aX=xq(sel); aY=y(sel); cr=s-1:-1:1;
      end
      for c=cr
        k=numel(aX);
        if k>0, if useLen, w=abs(aX-aX(end))<FITN; else, w=false(k,1); w(max(1,k-FITN+1):k)=true; end, end
        if k>0 && nnz(w)>=MINPTS, pp=polyfit(aX(w)-xq(c),aY(w),1); yp=pp(2);
        elseif k>0, yp=aY(end); else, yp=y0; end
        v=cands{c};
        if ~isempty(v), [d,ii]=min(abs(v-yp)); if d<=TOL, y(c)=v(ii); aX(end+1,1)=xq(c); aY(end+1,1)=y(c); end, end
      end
    end
    Y{i}=y;   % useLen・meth ごとに保存して isequaln で比べる
  end
end, end
```

結果：
- 欠損した列の数は、4通りとも `[0 7 6 0 0 4 0 0]`。欠損の位置は写真2：2762〜2768、写真3：835〜838・1336〜1337、写真6：452・1821〜1823。
- 列数の版と長さの版は、**8枚・2手法すべてで `isequaln` が true**（採った点が1点も変わらない）。
- 長さの版で、クリックのyを ±5px ずらす、`Tolerance` を1.5・4、`FitLength` を10・60・100 にしても、8枚すべて基準（`FitLength=30`）と同じ（重心法で確認。`FitLength=60` は局所的最大値法でも同じ）。

### A.7 intpD での確認（写真1の最初の2セグメント、step 0.125、約2秒）

```matlab
STEP=0.125; iImg=1;
g = rgb2gray(imread(fn(9-iImg)+".png")); wd=size(g,2); dv=round(wd/10); xa=[1:dv:wd wd+1]';
segP={}; segXq={}; off=0;
for j=1:2
  map = DarknessMap(ImageData(omitMask(g(:,xa(j):xa(j+1)-1),20),[iImg;j]));
  im = map.dInterp(STEP,"spline"); im = im.setDiffTF(0.6); ex=GrooveExtractor(im); c=cell(im.nCols,1);
  for x=1:im.nCols
    [f1,l1]=ex.findThresholdIntervals(im,x); [ex,~,~,np]=ex.findGrooveBottomIntervals(im,x,f1,l1,8);
    c{x}=[(1+(x-1)*STEP)*ones(np,1) ex.extractByCentroid(im,x)];
  end
  segP{j}=vertcat(c{:})+[off 0]; segXq{j}=(1:STEP:map.width)'+off; off=off+map.width;
end
Pi=vertcat(segP{:}); xqi=vertcat(segXq{:});   % これを A.6 と同じ手順で追跡する（seed = seeds(1,:)）
```

結果：
- セグメントの幅398・401 → `nCols` 3177・3201、`scaleFactor.col = 8`。`diff(xqi)` の値は0.125と1（セグメントの境目）だけ。点のxはすべて `xqi` のどれかに一致した（`ismember` で対応がつかない点は0）。
- 列数の版（`NumInit=20` は2.4px分）と長さの版（`InitLength=20px` は160列）で、6378列すべて同じ結果、欠損0（欠損の無い所では差が出ない）。
- 整数のxでの値と、`origD` の追跡結果の差：中央値0.112px、最大0.397px（高解像度化による違い。追跡の問題ではない）。

### A.8 人工的な長い欠損（その範囲のxの候補をすべて消す）

A.6・A.7の追跡で、x = 150・250・330・450・600・700 から長さ 10・20・40px の範囲の候補を消し、欠損の外で「欠損を入れない結果」と一致する列の割合を見た（1なら欠損の後で元の溝に戻れている）。

| データと窓 | 10px | 20px | 40px |
|---|---|---|---|
| origD、窓4px | 6/6 | 4/6 | 4/6 |
| origD、窓10px | 6/6 | 4/6 | 1/6 |
| origD、窓30px | 6/6 | 4/6 | 4/6 |
| **origD、窓60px** | **6/6** | **6/6** | **6/6** |
| intpD、列数30（=3.75px） | 6/6 | 6/6 | 4/6 |
| intpD、窓30px | 6/6 | 5/6 | 3/6 |
| **intpD、窓60px** | **6/6** | **6/6** | **6/6** |

（表の値は、6か所のうち元の溝に戻れた数。戻れなかった所では、一致する列の割合が0.06〜0.79だった）

```matlab
cg=cands; gx = xq>=gapStart & xq<gapStart+gapLen; cg(gx)={[]};   % 候補を消す
% → A.6 と同じ追跡を cg で行い、mean(abs(y(~gx)-yBase(~gx))<1e-9) を見る
```

窓が長いほど、欠損の前の溝の傾きを安定して推定でき、欠損を越えた予測がずれにくい。窓4px（`intpD` の列数30とほぼ同じ長さ）や10pxでは、20px以上の欠損で見失うことがあった。
