- 段階: 計画
- 作成者: planner
- 作成日: 2026-10-26
- 入力: issue #30（本文。コメントなし）、[`./README.md`](./README.md)（決定事項）、メインからの依頼文（issue作成後にユーザーと決めたこと）、`docs/issues/closed/25-groove-tracking/`（`plan.md`・`criteria.md`・`eval-report-1.md`・`follow-ups.md`・`retrospective.md`）、`scripts/grooveTrack_1cycle.m`、`scripts/archive/Ncycle_omitMask.m`（L107–147）
- 状態: 承認済み（2026-10-27、ユーザー。Q1〜Q4・A2・A4 はすべて推奨どおり。8章の「決定事項」）

# #30 写真ごとに1回のクリックからN本の溝を抽出し、N周分の音声を作る — 計画

## 修正の履歴

- 2026-10-27（main）：ユーザーの回答を8章の「決定事項」に書き、状態を「承認済み」にした。本文の設計は変えていない。

## 1. 結論

- **1本目は #25 と同じ**（`trackGroove` → `detrendTrackedShape`、写真ごと9次）。**2本目以降は旧スクリプトの流れ**のまま、1本目の9次多項式で写真全体の点を補正 → y座標のヒストグラム → 1本目の山から y の小さい側へ N−1 個の山 → 山の中心から±`tol` の帯の点 → 欠損を線形補間 → 溝ごとに9次デトレンド、とする。
- **パラメータは `binWidth = 1` px、山の高さのしきい値 = 写真の列の数 × 0.3、帯の幅 `tol = 3` px を推奨する（Q1）。** 実データ（8枚 × 2〜5本目 × 2手法 = 64本）で、正解データの作り方（5本を `trackGroove` で別々に追跡）と **63本で完全に一致**し、残り1本も1列だけの違い（RMSE 0.018 px）だった。
- **旧スクリプトの値（`binWidth = 5`・`tol = 3`）は使えない。** ビンの端が `binWidth` の倍数にそろうので、ビンの中心が溝の中心から最大 2.3 px ずれ、帯から点が落ちる（1本で最大203点）。さらに帯の中の同じ列に2点が入り、`extractGrooveShape` が64本中9本でエラーになる。
- 新しい関数は3つ（`findGrooveCenters`・`extractGrooveBands`・まとめ役の `extractMultiGroove`）。`detrendTrackedShape` に多項式を返す2つ目の出力を足し、`cycleMethodResult` を 80×N の `ycoords` を受け付けるように広げる（Q4）。スクリプトは本実装 `scripts/grooveHist_Ncycle.m` と正解データ用 `scripts/grooveTrack_Ncycle.m` の2本。
- 未決事項 Q1〜Q4（issue の未決事項1〜4）は、すべて issue の推奨と同じ向き（Q1 は (b) の値を実データで決めたもの）を推奨する（8章）。

## 2. 調査結果

### 2.1 再利用できるもの

| もの | 使い方 |
|---|---|
| `scripts/grooveTrack_1cycle.m` L86–127 | 写真ごとの点群の作り方（`omitMask`〜`GrooveExtractor`、`allPts_cnt`・`allPts_max`）をそのまま写す |
| `mergeSegmentPoints` | 写真1枚分の点群 `pks`・`xQuery`・`counts` |
| `trackGroove`・`detrendTrackedShape` | 1本目（#25 と同じ）。正解データ用スクリプトでは N 本すべて |
| `trackingSeeds` | 保存したクリック（`grooveSelection.seeds`）から1本目の始点を返す。正解データの結果ファイルにも `seeds` を入れるので、本実装はそれを再現できる |
| `cycleConditions`・`saveCycleResult`・`loadCycleResult` | 変えずに使う（`saveCycleResult` は `GrooveSelection` の `p1`/`p2` だけを検証し、他のフィールドはそのまま保存する） |
| `findGrooveCenter`（考え方） | 「`prevCenter` に最も近い山」を1本目の山にする選び方を、新しい `findGrooveCenters` で同じにする |
| `extractGrooveShape`（考え方） | 帯の点を `xQuery` 全体に並べ、`fillmissing(...,"linear")` で埋める。ただし関数そのものは使わない（2.4、3.2） |

使わない・変えないもの：`fitGroove`、`findGrooveCenter`、`extractGrooveShape`、`extractGrooveWaveform`、`detrendGrooveShape`、`trackGroove`、`mergeSegmentPoints`、`trackingSeeds`、既存のスクリプト。

### 2.2 旧スクリプト（`scripts/archive/Ncycle_omitMask.m` L107–147）の要点

- `fitGroove` で傾きを補正した点の y のヒストグラム（`BinWidth = 5`）で、`findpeaks(counts,'MinPeakHeight',th_hist)` の山のうち `p1(2)` に最も近いものを1本目とし、`histPkLocs(idx-laps+1:idx)` を `flip` して、**y の小さい側**に `laps` 個の山を選ぶ。向きは今回の決定（y が小さい側が内側）と同じ。
- 帯は `grooveCenters ± tol` で、帯の中の点をそのまま `sortrows` して使う（同じ列の2点はそのまま2サンプルになる）。今のパイプラインは `xQuery` 全体に並べて長さをそろえるので、ここは変える必要がある。
- 振幅は `y / (tol/2)`。

### 2.3 実データで確かめたこと（読み取りのみ。付録に再現コード）

対象：`data/pictures/1111/original/` の8枚、`origD`。1本目の始点の y は `experiments/1014/cycleResult_origD_track_1014.mat` の `grooveSelection.seeds`、x は写真の1列目（`seed = [xQuery(1), y]`）。

1. **1本目は #25 と完全に一致する。** 8枚・2手法とも、`trackGroove` の結果が 1014 の `tracking.yAbsCnt`/`yAbsMax` と `isequal`（付録 A.1）。
2. **補正後のヒストグラムには、1本目より y の小さい側に 8〜10 本の山がある**（`binWidth = 1`、しきい値 0.3×列の数）。N=5 なら余裕がある。5本目の溝の y は写真の上端から 89 px 以上離れている（付録 A.2・A.3）。
3. **溝の間隔は 25.5〜28.4 px**（写真ごとにほぼ一定。写真の中の4つの間隔は、中央値から ±5% 以内）。
4. **山の幅：補正後の溝の点は、1本目から離れても狭いまま。** 正解の作り方で追跡した経路（補正後）の、中央値からのずれの標準偏差は、重心法で 1本目 0.24 px → 5本目 0.35 px、局所的最大値法で 0.33 → 0.42 px。99% が −1.4〜+1.1 px に入る。1本目からの「平行でなさ」（溝ごとの9次多項式の差、RMS）は 2本目 0.11 px → 5本目 0.20 px と少しずつ増える（付録 A.6）。
5. **山の高さ**：`binWidth = 1` では、どの溝も、山の最も高いビンが列の数の 0.50 倍以上（2〜5本目の平均は 0.67〜0.77 倍）。1本目は補正後の中心がちょうど 0（ビンの端）に来るので、いつも2つのビンにほぼ半分ずつ分かれ、約 0.50 倍になる。溝と溝の間に出る偽の山は、写真2で 0.17〜0.19 倍、それ以外は 0.05 倍以下。
6. **しきい値の範囲**：`binWidth = 1` で、8枚すべてで正しい5本を選べるのは、しきい値が列の数の **0.20〜0.45 倍**のとき（重心法では 0.15 倍以下で写真2の偽の山を数え、0.50 倍では両手法とも1枚で山を1つ落とす）。`binWidth = 2・2.5・3・5` でも 0.20〜0.45 倍なら正しい山を選べる（付録 A.4）。
7. **ビンの中心のずれ**：選んだ山（ビンの中心）と、正解の作り方の経路の中心のずれの最大は、`binWidth` が 1・2・2.5・3・5 で 0.48・0.98・1.20・1.48・2.27 px。ビンの端が `binWidth` の整数倍にそろうため、ほぼ `binWidth/2` になる。
8. **帯から落ちる点と、同じ列の2点**（しきい値 0.3、2〜5本目の 32本 × 2手法。付録 A.4。値は「重心法 / 局所的最大値法」）

   | `binWidth` / `tol` | 落ちる点（1本の最大） | 帯の中の、追跡では採らない点（1本の最大） | 同じ列に2点以上ある列（全体の合計） | `extractGrooveShape` のエラー |
   |---|---|---|---|---|
   | **1 / 3（推奨）** | **0 / 0** | 1 / 0 | **0 / 0** | **0本** |
   | 1 / 2.5 | 1 / 0 | 0 / 0 | 0 / 0 | 0本 |
   | 1 / 3.5 | 0 / 0 | 1 / 0 | 0 / 0 | 0本 |
   | 2 / 3 | 1 / 0 | 0 / 0 | 0 / 0 | 0本 |
   | 2 / 3.5 | 0 / 0 | 合計 11 / 15 | 10 / 15 | 1本 / 1本 |
   | 2.5 / 3、3 / 3 | 0 / 0 | 5〜10 / 9〜15 | 9〜16 / 14〜17 | — |
   | **5 / 3（旧スクリプトの値）** | **121 / 203** | 10 / 15 | **24 / 32** | **4本 / 5本**（`MATLAB:subsassigndimmismatch`） |
   | 任意 / 4以上 | 0 / 0 | 10〜97 | 18〜323 | 起きる |

9. **`extractGrooveShape` の同じ列の2点**：issue の注意点のとおり、`points(Lia,2) = clusteredPoints(:,2)` の要素数が合わずにエラーになることを、旧スクリプトの値で確かめた（上の表）。推奨の値では起きない。
10. **正解の作り方（5本を `trackGroove` で別々に追跡）との差**：推奨の値で、帯の点を元の画像の y で並べて補間すると、64本中63本で `isequal`（デトレンド前の y が完全に同じ）。残り1本（重心法、写真8、5本目）は、追跡では採らなかった1列（x=2314、中心から 2.6 px の点）を帯が採った差で、デトレンド後の RMSE 0.018 px・相関 0.998。5周分の `y_comb` では、重心法 RMSE 0.0028 px・相関 0.99994、局所的最大値法は完全に一致（付録 A.5）。
11. **帯の中で点が無い列**（補間の前）は、2〜5本目で1本あたり 0〜16 列。正解の作り方の欠損と同じ列（付録 A.5 の表）。
12. **未決事項2の (a) と (b) の違い**（付録 A.6）
    - (a)（溝ごとに9次）は、正解の作り方と同じ前処理なので、上の10のとおり一致する。
    - (b)（補正して平均を引くだけ）と正解（9次）の差は、RMSE 0.06〜0.29 px、相関 0.60〜0.99。差の中身は「その溝と1本目の、ゆっくりした形の違い」（9次以下の多項式）で、RMS が 2本目 0.11 px → 5本目 0.20 px と内側ほど大きい。音の成分そのもの（(a) の RMS：重心法 0.26 px、局所的最大値法 0.33 px）の 40〜80% にあたる。
    - 5周分をつないだときの、写真の境目の段差（重心法）：(a) 中央値 0.28 px・最大 0.78 px、(b) 中央値 0.32 px・最大 1.43 px。
13. **振幅（未決事項3）**：`AMP_DIV = 1.5` で割ると、重心法は 160,495 サンプル中 32（0.020%）が ±1 を超える（最大 1.29、写真8の5本目）。局所的最大値法は超えない（最大 1.000）。1本目だけなら最大 1.03 で、#25 と同じ。
14. **標本化周波数**：1周分の列の数は 32,099（8枚の幅の合計）なので、`fs = round(32099/(60/78)) = 41729` Hz（#25 と同じ）。N周分でも1周あたりのサンプル数は同じ。
15. **周の順は、数値では確かめられなかった。** 写真 i の右端と写真 i+1 の左端、写真8の j本目と写真1の j+1本目の間で、200列の波形の相互相関（ずらし 0〜1300列）を見たが、最大でも 0.25〜0.66 で、写真の重なりは見つからなかった（付録 A.8）。周の順と、周の境目のつながりは、ユーザーの試聴（U3）で確かめる。
16. 計算時間：80セグメントの点の検出に約5秒。ヒストグラムと帯は1枚あたり 0.1 秒以下。

### 2.4 `extractGrooveShape` を使わない理由

issue の設計案（手順3.2）では `extractGrooveShape` を使う予定だったが、次の3点から、同じ考え方の新しい関数 `extractGrooveBands` にする。

1. 帯の中の同じ列に2点以上あるとエラーになる（2.3 の8）。推奨の値ではこのデータで起きないが、別のレコードや高解像度化した画像では起きうる。`extractGrooveShape` は変えない約束なので、新しい関数の中で「中心に最も近い点を採る」ことにする（`trackGroove` が予測に最も近い点を採るのと同じ考え方）。
2. 評価で「帯の中に点が無かった列」（E3）を数えるには、補間の前の `found` が要る。`extractGrooveShape` は返さない。
3. **補正前（元の画像）の y で並べてから補間する**と、同じ点を採ったときに正解の作り方（`trackGroove` は元の画像の y で補間する）と完全に同じ結果になる。補正後の y で補間すると、欠損の所だけ 1e-6 px 程度ずれる（2.3 の10は、元の y で補間したときの値）。

## 3. 案の比較

### 3.1 2本目以降の選び方

ユーザーの指定で、提案 P1〜P5 は採用しない。下の表の B・C は、ユーザーが判断するための参考として載せる。

| 案 | 長所 | 短所 | 試した結果 |
|---|---|---|---|
| **A. ヒストグラム＋帯（旧スクリプトの流れ。採用）** | issue の要求どおり。ユーザーが理解しやすい。山の数でN本を数えるので、溝を飛ばしたかどうかがヒストグラムの図で見える | パラメータ（`binWidth`・しきい値・`tol`）の選び方で結果が大きく変わる（2.3 の8）。帯が固定幅なので、溝が大きく曲がると端の点を落とす | 推奨の値で、正解の作り方と 63/64 本が完全に一致 |
| B. 山の中心から `trackGroove`（P1。参考） | 曲がりに強い。正解データと同じ作り方 | 採用しない（ユーザーの指定） | A と同じ（今回の正解の作り方の試行そのもの） |
| C. 帯の中の点の中央値を中心にする（P3。参考） | ビンのずれが消える | 採用しない（ユーザーの指定） | `binWidth = 1` ならずれは 0.5 px 以下で、必要ない。`binWidth = 5` なら必要 |

参考：P2（山の間隔の確認）は、このデータでは間隔が中央値の ±5% 以内なので、1.5倍・0.5倍の判定はどちらも起きない。P4・P5 は試していない。

### 3.2 帯の点の取り出し方

| 案 | 長所 | 短所 |
|---|---|---|
| **a. 新しい関数 `extractGrooveBands`（採用）**：補正後の y で帯を選び、同じ列に2点以上あれば中心に最も近い点を採り、元の y で並べて補間する。`found` と、2点以上あった列の数も返す | 同じ列の2点でエラーにならない。正解の作り方と完全に同じ結果になりうる（2.4） | 関数が1つ増える |
| b. `extractGrooveShape` をそのまま使う | 既存の関数を使う（issue の設計案） | 同じ列の2点でエラーになる。`found` を返さない。補正後の y で補間するので、正解と 1e-6 px ずれる |
| c. `extractGrooveShape` に引数を足して同じ列の2点を扱う | 関数が増えない | 既存の関数の動作を変える（issue の制約）。`found` は別に要る |

### 3.3 関数の分け方

`extractGrooveWaveform`（`findGrooveCenter`→`extractGrooveShape`→`detrendGrooveShape` をまとめたもの）にならい、部品2つ（`findGrooveCenters`・`extractGrooveBands`）と、写真1枚分の処理をまとめた `extractMultiGroove`（`trackGroove` から N 本のデトレンドまで）に分ける。スクリプトでは重心法・局所的最大値法でそれぞれ `extractMultiGroove` を1回呼ぶだけにし、2つの手法で手順が食い違わないようにする。部品は合成データで個別にテストできる。

## 4. 設計

### 4.1 処理の流れ（本実装 `scripts/grooveHist_Ncycle.m`）

```
for iImg = 1:8
    写真を読み、10セグメントの点群を作る              ← grooveTrack_1cycle.m L86–127 と同じ
    [pksCnt, xQuery, counts] = mergeSegmentPoints(...); pksMax = ...
    seed = ginput(1)（左端付近を拡大した図で） または trackingSeeds(...)(iImg,:)（再現）
    seed = [xQuery(1), seed(2)]                        ← xは1列目に固定（ab66350 と同じ）
    [shapesCnt(iImg,:), infoCnt] = extractMultiGroove(pksCnt, seed, xQuery, NUM_GROOVES, ...)   ← 新規
    [shapesMax(iImg,:), infoMax] = extractMultiGroove(pksMax, seed, xQuery, NUM_GROOVES, ...)
        └ 1. trackGroove → 1本目（#25 と同じ）
          2. detrendTrackedShape → shapes{1} と1本目の多項式 trend（2つ目の出力。新規）
          3. pksCor = 点群の y − trend(x)                ← 1本目が y≈0 に水平になる
          4. findGrooveCenters(pksCor, N, ...)           ← 新規。y≈0 に最も近い山＋y の小さい側の N−1 個
          5. extractGrooveBands(pks, trend, centers(2:N), xQuery, Tolerance=BAND_TOL)  ← 新規
          6. 2本目以降に detrendTrackedShape（Q2 の (a)）
    ycoords_cnt(ks, j) = mat2cell(shapesCnt{iImg,j}(:,2), counts)   ← 80×N
    確認用の図（N本の経路、ヒストグラム）
end
y_comb = vertcat(ycoords_cnt{:})        ← 列の順（j=1 の80セグメント → j=2 …）がそのまま再生順
fs = round(1周分のサンプル数 / (60/RPM)); amp = (y_comb − mean(y_comb)) / AMP_DIV
AudioData → 図・wav → cycleConditions / cycleMethodResult（80×N）/ saveCycleResult
```

- `shapesCnt`・`shapesMax`（8×N cell、各セルは `[xQuery, y]`）は issue の決定どおり。`vertcat(shapesCnt{:})` の2列目と `vertcat(ycoords_cnt{:})` は同じになる（スクリプトで確かめる）。
- 重心法と局所的最大値法は、同じクリックから別々に処理する（ヒストグラムもそれぞれの点で作る。issue の決定、#25 の仮定A3）。

### 4.2 インターフェース

#### `src/detrendTrackedShape.m`（変更：2つ目の出力を足す）

```matlab
function [pointsDetrended, trend] = detrendTrackedShape(points, opts)
```

- `trend`：struct。`p`・`S`・`mu`（`polyfit` の `[p,S,mu]`）と `degree`（`opts.PolyDegree`）。`polyval(trend.p, x, trend.S, trend.mu)` で、あてはめた多項式の値が得られる。
- 1つ目の出力は今と同じ（今の呼び出し方の結果は変わらない）。`trend` は dot 記法で組み立てる（`S` は struct）。
- ヘルプに「2つ目の出力は、複数本の溝を選ぶときに写真全体の点の傾きを補正するために使う（issue #30）」と書く。

#### `src/findGrooveCenters.m`（新規）

```matlab
function [centers, info] = findGrooveCenters(pksCor, numGrooves, opts)
% 1本目の溝で傾きを補正した点群 pksCor の y のヒストグラムから、FirstCenter に最も近い山を
% 1本目とし、そこから y の小さい側（レコードの内側）へ続く numGrooves-1 個の山を選んで、
% それぞれのビンの中心を返す。写真1枚の中の複数本の溝を、1回のクリックから数えるため
% （旧 scripts/archive/Ncycle_omitMask.m のヒストグラムによる溝の選択と同じ考え方）。
    arguments
        pksCor (:,2) double                                  % [x y]。yは補正後の値（1本目が y≈0）
        numGrooves (1,1) double {mustBeInteger,mustBePositive}
        opts.BinWidth (1,1) double {mustBePositive}          % 必須。ヒストグラムのビンの幅[px]
        opts.MinPeakHeight (1,1) double {mustBePositive}     % 必須。山とみなす高さ（点の数）
        opts.FirstCenter (1,1) double = 0                    % 1本目の山を探す基準のy[px]
        opts.MaxFirstOffset (1,1) double {mustBePositive} = 5   % 1本目の山がFirstCenterからこれより離れていたらエラー[px]
    end
```

手順：
1. `[counts, edges] = histcounts(pksCor(:,2), 'BinWidth', opts.BinWidth)`、`binCenters = edges(1:end-1) + diff(edges)/2`（`findGrooveCenter` と同じ）。
2. `[pkHeights, locs] = findpeaks(counts, 'MinPeakHeight', opts.MinPeakHeight)`。空なら `error("findGrooveCenters:noPeaksFound", ...)`。
3. `peakCenters = binCenters(locs)`（昇順）。`[d, i0] = min(abs(peakCenters - opts.FirstCenter))`。`d > opts.MaxFirstOffset` なら `error("findGrooveCenters:firstPeakNotFound", ...)`（1本目の山が低すぎて隣の山を1本目にすると、以後の周がすべて1本ずれるため。メッセージに `d` を書く）。
4. `i0 - numGrooves + 1 < 1` なら `error("findGrooveCenters:notEnoughPeaks", ...)`（「1本目より y の小さい側に山が i0−1 個しかなく、N−1 個に足りない。画像の上端に近い可能性」と書く）。
5. `centers = peakCenters(i0:-1:i0-numGrooves+1).'`（`(numGrooves,1)`、`centers(1)` が1本目、以後 y が小さくなる）。

出力 `info`：`binCenters`、`counts`、`peakCenters`、`peakHeights`、`firstIdx`（`i0`）。確認用のヒストグラムの図に使う。

#### `src/extractGrooveBands.m`（新規）

```matlab
function [bands, found, info] = extractGrooveBands(pks, trend, centers, xQuery, opts)
% 1本目の多項式 trend で傾きを補正した y が、centers のそれぞれから ±Tolerance の帯にある点を
% 取り出し、補正前（元の画像）の y で xQuery 全体に並べて、欠損を線形補間する。
% extractGrooveShape と同じ考え方だが、同じ列に2点以上あれば中心に最も近い点を採る
% （extractGrooveShape はエラーになる）。元の y で補間するのは、同じ点を採ったときに
% trackGroove で追跡した結果と完全に同じにするため（issue #30）。
    arguments
        pks (:,2) double              % [x y]。元の画像のpx（mergeSegmentPoints の出力）
        trend (1,1) struct            % detrendTrackedShape の2つ目の出力（.p .S .mu）
        centers (:,1) double          % 補正後のyでの帯の中心（findGrooveCenters の出力の2本目以降）
        xQuery (:,1) double           % 昇順の列の座標[px]
        opts.Tolerance (1,1) double {mustBePositive}   % 必須。帯の半分の幅[px]
    end
```

手順：
1. `yCor = pks(:,2) - polyval(trend.p, pks(:,1), trend.S, trend.mu)`、`[tf, col] = ismember(pks(:,1), xQuery)`（`xQuery` に無いxの点は使わない。`trackGroove` と同じ）。
2. 帯 k ごとに：`inBand = tf & abs(yCor - centers(k)) <= opts.Tolerance`。中心からの距離の大きい順に `y(col(idx)) = pks(idx,2)` と代入する（同じ列では最後に代入した、最も近い点が残る）。同じ列に2点以上あった列の数を `accumarray(col(inBand),1,[n 1]) >= 2` で数える。
3. 採れた列が2列未満なら `error("extractGrooveBands:tooFewPoints", ...)`（補間できないため）。
4. `found(:,k) = ~isnan(y)`、`bands{k} = [xQuery, fillmissing(y,"linear")]`。

出力：`bands`（`(numel(centers),1)` cell、各 `(numel(xQuery),2)`）、`found`（`(numel(xQuery), numel(centers))` logical）、`info.numDuplicateCols`・`info.numMissing`（各 `(1, numel(centers))`）。

#### `src/extractMultiGroove.m`（新規）

```matlab
function [shapes, info] = extractMultiGroove(pks, seed, xQuery, numGrooves, opts)
% 写真1枚分の溝底の点群から、seed（クリック）を通る溝を1本目として、レコードの内側
% （y座標が小さい側）へ順に numGrooves 本の溝の形状を返す。1本目は trackGroove で追跡し、
% 2本目以降は、1本目の多項式で写真全体の点の傾きを補正した y のヒストグラムの山
% （findGrooveCenters）の帯から取り出す（extractGrooveBands）。各溝に detrendTrackedShape を
% かける。1周目のクリックだけで N周分の溝を得るため（issue #30）。
    arguments
        pks (:,2) double
        seed (1,2) double
        xQuery (:,1) double
        numGrooves (1,1) double {mustBeInteger,mustBePositive}
        % 1本目の追跡（trackGroove の引数。名前の Tolerance は帯と区別するため TrackTolerance）
        opts.TrackTolerance (1,1) double {mustBePositive} = 2
        opts.FitLength (1,1) double {mustBePositive} = 60
        opts.SnapRadius (1,1) double {mustBePositive} = 10
        opts.InitLength (1,1) double {mustBePositive} = 20
        opts.MaxGapLength (1,1) double {mustBePositive} = 40
        % デトレンド（すべての溝で同じ次数。Q2）
        opts.PolyDegree (1,1) double {mustBeInteger,mustBeNonnegative} = 9
        % 2本目以降（Q1）。長さは元の画像のpx
        opts.BinWidth (1,1) double {mustBePositive} = 1
        opts.MinPeakRatio (1,1) double {mustBePositive} = 0.3   % 山とみなす高さ ＝ MinPeakRatio × numel(xQuery)
        opts.BandTolerance (1,1) double {mustBePositive} = 3
    end
```

手順：4.1 の1〜6。`numGrooves == 1` のときは3〜6を行わない（#25 と同じ結果を返す。ヒストグラムでエラーになることもない）。

- しきい値を列の数に対する割合にするのは、1つの溝は1列に1点なので山の高さが列の数に比例し、高解像度化（`intpD`）で列が8倍になっても同じ値を使えるようにするため（#25 で長さをpxにしたのと同じ考え方）。
- 出力
  - `shapes`：`(1, numGrooves)` cell。各 `(numel(xQuery),2)` `[xQuery, y]`（デトレンド後、平均0）。
  - `info`：struct
    - `track`：1本目の `trackGroove` の `info`
    - `trend`：1本目の多項式（`detrendTrackedShape` の2つ目の出力）
    - `centers`：`(numGrooves,1)`。補正後の山の中心（`centers(1)` は1本目の山）。`numGrooves == 1` なら `[]`
    - `hist`：`findGrooveCenters` の `info`（`numGrooves == 1` なら `[]`）
    - `minPeakHeight`：`MinPeakRatio * numel(xQuery)`
    - `yAbs`：`(numel(xQuery), numGrooves)`。デトレンド前・補間済みの y（元の画像のpx）。1列目は `trackGroove` の出力
    - `found`：`(numel(xQuery), numGrooves)` logical。1列目は `trackGroove` の `found`、2列目以降は帯の中に点があった列
    - `numDuplicateCols`：`(1, numGrooves)`。1列目は0
- エラーは部品の識別子をそのまま出す（`trackGroove:seedNotFound`、`findGrooveCenters:*`、`extractGrooveBands:tooFewPoints`）。

使用例：

```matlab
[shapes, info] = extractMultiGroove(pksCnt, seed, xQuery, NUM_GROOVES, ...
    TrackTolerance=TRACK_TOL, FitLength=FIT_LENGTH, SnapRadius=SNAP_RADIUS, ...
    InitLength=INIT_LENGTH, MaxGapLength=MAX_GAP_LENGTH, PolyDegree=POLY_DEGREE, ...
    BinWidth=BIN_WIDTH, MinPeakRatio=TH_HIST_RATIO, BandTolerance=BAND_TOL);
```

#### `src/cycleMethodResult.m`（変更：N周分を受け付ける）

- `xcoords`・`ycoords` の引数の検証を `(:,1) cell` から `(:,:) cell` にする。
- **ベクトル（どちらかの次元が1）なら、今と同じく列ベクトルにしてから検証する**（`xcoords = xcoords(:)`。今は `(:,1)` の検証で行ベクトルも列に直されて通るので、その動作を保つ。付録 A.9）。
- 行列（`TOTAL_SEGMENTS × N`）なら、`size(xcoords) == size(ycoords)` と `numel(pts) == size(ycoords,1)` を確かめる（違えば今と同じ `cycleMethodResult:sizeMismatch`）。
- `y_comb` の長さの検証（`sum(cellfun(@numel, ycoords))`）と、`audio` の長さの警告は今のまま（行列でもそのまま使える）。
- ヘルプに「N周分のときは `xcoords`・`ycoords` を (TOTAL_SEGMENTS x N) にする。j列目が j周目。`y_comb = vertcat(ycoords{:})` が再生順になる。`pts` は (TOTAL_SEGMENTS x 1) のまま」と書く。

#### `scripts/grooveTrack_Ncycle.m`（新規、正解データ用）

- 写真ごとに、左端付近を拡大した図で `ginput(NUM_GROOVES)` を1回行い、クリックの y を大きい順（外側から）に並べて1本目〜N本目にする（クリックの順によらない）。クリックの数が `NUM_GROOVES` と違えば `error("grooveTrack_Ncycle:clickCount", ...)`。
- 各クリックから `trackGroove`（始点の x は1列目）→ `detrendTrackedShape` を、重心法・局所的最大値法でそれぞれ行う（#25 と同じ処理を N 回）。
- 隣どうしの始点（`trackGroove` の `info.y0`、重心法）の差が `MIN_SEED_GAP`（13 px、溝の間隔の半分）より小さければ `warning("grooveTrack_Ncycle:sameGroove", ...)`。差が隣どうしの差の中央値の1.5倍を超えれば `warning("grooveTrack_Ncycle:grooveSkipped", ...)`（`NUM_GROOVES >= 3` のとき。クリックで溝を1本飛ばしたことに気づくため）。どちらも写真の番号と y を書く。
- `PREV_RESULT_PATH` に以前の正解データを指定すると、保存した `multiGroove.seedsY` で `ginput` なしに再現する。`RECLICK_IMAGES`（例：`[3 7]`）に書いた写真だけ、もう一度クリックする（飛び移りがあった写真だけ直すため）。`seedsY` が無い、または列の数が `NUM_GROOVES` と違えば `error("grooveTrack_Ncycle:noSeeds", ...)`。
- `GUIDE_RESULT_PATH` に以前の結果（例：1014 の追跡）を指定すると、`trackingSeeds` で取り出した始点の y を、クリックの図に黄色の三角で示す（1本目を #25 と同じ溝にするため）。

### 4.3 新しく作るファイルと、変えるファイル

| 区分 | パス | 内容 |
|---|---|---|
| 新規 | `src/findGrooveCenters.m` | ヒストグラムの山から N 本の溝の中心を選ぶ |
| 新規 | `src/extractGrooveBands.m` | 帯の点を取り出して並べ、補間する |
| 新規 | `src/extractMultiGroove.m` | 写真1枚分で、1回のクリックから N 本の溝の形状を返す |
| 新規 | `scripts/grooveHist_Ncycle.m` | 本実装（N周分の音声、cycleResult） |
| 新規 | `scripts/grooveTrack_Ncycle.m` | 正解データ用（N本を `trackGroove` で別々に追跡） |
| 新規 | `test/unit/FindGrooveCentersTest.m`、`test/unit/ExtractGrooveBandsTest.m`、`test/unit/ExtractMultiGrooveTest.m` | unitテスト |
| 変更 | `src/detrendTrackedShape.m` | 2つ目の出力 `trend` |
| 変更 | `src/cycleMethodResult.m` | (TOTAL_SEGMENTS × N) の `xcoords`・`ycoords` を受け付ける |
| 変更（コメントのみ） | `src/saveCycleResult.m` | ヘルプの `result.centroid` の説明に「N周分では `xcoords`・`ycoords` が (N_seg x N)」、`GrooveSelection` の説明に `multiGroove` を追記。**コードは変えない** |
| 変更 | `test/unit/DetrendTrackedShapeTest.m`、`test/unit/CycleResultTest.m` | 追加のテスト（6章） |
| 変更 | `README.md` | `src/`・`scripts/` の一覧、新しい節「複数本の溝の抽出（N周分）」、「1周分の実験結果の保存」の表（`ycoords` の形、`grooveSelection.multiGroove`） |
| 変更 | `CLAUDE.md` | Architecture notes に、N周分の流れ（`extractMultiGroove`、80×N の `ycoords`）の項目を1つ足す |

触らないもの：`trackGroove.m`、`mergeSegmentPoints.m`、`trackingSeeds.m`、`extractGrooveShape.m`、`findGrooveCenter.m`、`fitGroove.m`、`detrendGrooveShape.m`、`extractGrooveWaveform.m`、`loadCycleResult.m`、`cycleConditions.m`、`DarknessMap.m`・`GrooveExtractor.m`・`GroovePointCloud.m`、既存のスクリプト（`grooveTrack_1cycle.m` を含む）、`archive/` の下、受け入れテスト、`data/`・`experiments/`。

### 4.4 保存形式と互換性

本実装：`saveCycleResult(cond, allImg, [res_cnt res_max], GrooveSelection=gs, FileName="cycleResult_origD_hist"+NUM_GROOVES+"_"+date, Overwrite=false)` → `experiments/<日付>/cycleResult_origD_hist5_<日付>.mat`。
正解データ：同じく `FileName="cycleResult_origD_track"+NUM_GROOVES+"_"+date` → `cycleResult_origD_track5_<日付>.mat`（#25 の `cycleResult_origD_track_<日付>.mat` とも重ならない）。

- `result.centroid` / `result.localMax`（`cycleMethodResult`）：`pts`（80×1）、`xcoords`・`ycoords`（**80×N** cell。j列目が j周目、各セルは1セグメント分）、`y_comb`（`vertcat(ycoords{:})`、N周分）、`audio`（N周分）。
  - 線形インデックス `ycoords{k}`（k=1〜80）は1周目（1本目）を指すので、`ycoords{(i-1)*10+(1:10)}` のように書いた既存のコードは1本目を読む。`numel(ycoords)` を使うコード（`compareTrackingToManual.m` など）は N 周分のファイルには使えない（評価担当への申し送り、7章）。
  - `y_comb`・`audio` を読む図のスクリプトは、そのまま N 周分を読める。
- `result.conditions`（`cycleConditions` は変えない）：`Upsampling="origD"`、`PolyDegree=POLY_DEGREE`、`ScriptName`。本実装は `BinWidth=BIN_WIDTH`・`Tol=BAND_TOL`（旧スクリプトと同じ意味）、`ThHist=NaN`・`HPrl=NaN`（しきい値は割合になり意味が変わるので、`grooveSelection.multiGroove.thHistRatio` に入れる）、`Note="N周分（NUM_GROOVES=5、ヒストグラムで2本目以降を選択。パラメータは grooveSelection.multiGroove）"`。正解データは #25 と同じく `ThHist`・`BinWidth`・`HPrl`・`Tol` を `NaN` にする。
- `result.grooveSelection`（`struct` に cell を直接渡さず、dot 記法で組み立てる）

  | フィールド | 本実装 | 正解データ |
  |---|---|---|
  | `p1`, `p2`（80×2） | 1本目（重心法）の経路の各セグメントの両端（#25 と同じ） | 同じ |
  | `method` | `"histogram"` | `"tracking"` |
  | `seeds`（8×2） | 写真ごとの1本目の始点 `[1, y]` | 1本目のクリック `[1, seedsY(:,1)]`（`trackingSeeds` で本実装・`grooveTrack_1cycle.m` が再現できる） |
  | `tracking`（struct） | #25 と同じ（1本目の `trackGroove` のパラメータ、`yAbsCnt`/`yAbsMax`/`foundCnt`/`foundMax` は 8×1 cell の1本目） | 同じ |
  | `multiGroove`（struct） | `numGrooves`、`binWidth`、`thHistRatio`、`bandTol`、`polyDegree`、`detrendScope`（`"photo"`）、`ampDivisor`、`centersCnt`/`centersMax`（8×N）、`yAbsCnt`/`yAbsMax`（8×N cell、デトレンド前・補間済み・元の画像のpx）、`foundCnt`/`foundMax`（8×N cell）、`numDupCnt`/`numDupMax`（8×N）、`trendCnt`/`trendMax`（8×1 cell、1本目の多項式） | `numGrooves`、`seedsY`（8×N、クリックの y を大きい順）、`y0Cnt`/`y0Max`（8×N、`trackGroove` の `info.y0`）、`minSeedGap`、`polyDegree`、`detrendScope`、`ampDivisor`、`yAbsCnt`/`yAbsMax`（8×N cell）、`foundCnt`/`foundMax`（8×N cell） |

- 振幅：`amp = (y_comb - mean(y_comb)) / AMP_DIV`、`AMP_DIV = 1.5`（Q3）。`fs = round(sum(cellfun(@numel, ycoords_cnt(:,1))) / (60/RPM))`。±1 を超えたサンプルの数を手法ごとに `fprintf` で表示する。
- `AudioData` の名前：本実装 `"audio (centroid method)(original)(hist " + NUM_GROOVES + " cycles)"`、正解データ `"... (tracking " + NUM_GROOVES + " cycles)"`（局所的最大値法も同様）。同じ日に #25 のスクリプトや互いを実行しても、`results/<日付>/` の wav・図が重ならない。
- 読み込むとき：`cycleResultPath` は対応していないので、`fullfile(experimentDir(root,date,Create=false), "cycleResult_origD_hist5_"+date+".mat")` のように組む（#25 と同じ）。
- #28（結果の保存先の変更）：2026-10-26 時点で open。実装の開始時に `git log master --oneline -1 -- src/resultDir.m` で確かめ、master に入っていれば `resultDir` を、入っていなければ今の `mkdirFromDate`・`experimentDir` を使う（issue の「作業の進め方」）。

### 4.5 スクリプトのパラメータ（冒頭にまとめる）

```matlab
% grooveTrack_1cycle.m と同じもの
NUM_IMAGES = 8; NUM_SEGMENTS = 10; TOTAL_SEGMENTS = NUM_IMAGES*NUM_SEGMENTS;
L_MASK = 20; D_THRESH = 0.6; WIDTH_THRESH = 8; QUERY_STEP = 1; RPM = 78;
TRACK_TOL = 2; FIT_LENGTH = 60; SNAP_RADIUS = 10; INIT_LENGTH = 20; MAX_GAP_LENGTH = 40; MIN_FIT_POINTS = 5;
POLY_DEGREE = 9;          % すべての溝で同じ（Q2）
AMP_DIV = 1.5;            % 振幅の正規化[px]（Q3）
% 複数本
NUM_GROOVES = 5;          % 抽出する溝の本数（=周の数）。1本目はクリックした溝、2本目以降はy座標が小さい側（内側）
CLICK_VIEW_WIDTH = 300;   % クリックの図に表示する、写真の左端からの幅[px]（溝の間が画面で広く見えるように）
% grooveHist_Ncycle.m だけ（Q1）
BIN_WIDTH = 1;            % ヒストグラムのビンの幅[px]
TH_HIST_RATIO = 0.3;      % 山とみなす高さ（写真の列の数に対する割合）
BAND_TOL = 3;             % 帯の半分の幅[px]
% grooveTrack_Ncycle.m だけ
MIN_SEED_GAP = 13;        % 隣どうしの始点がこれより近ければ警告[px]（溝の間隔 25.5〜28.4px の約半分）
RECLICK_IMAGES = [];      % PREV_RESULT_PATH から再現するとき、もう一度クリックする写真の番号
GUIDE_RESULT_PATH = "";   % 1本目の目安（以前の結果.matの始点）を図に示す
% 実行する人が書き換える場所
date = "MMDD"; PREV_RESULT_PATH = ""; SAVE_FIG = true;
```

- `date == "MMDD"` のままならエラーで止める（`grooveTrack_1cycle.m` と同じ。識別子は `<スクリプト名>:dateNotSet`）。
- クリックの図：写真1枚分の画像を `showImage("fit")` で表示し、`xlim([0.5, CLICK_VIEW_WIDTH+0.5])` で左端を拡大、その範囲の点群を小さな点で重ねる。タイトルに「写真i：左端付近で、外側（下）の溝から N 本をクリック（順不同、yだけを使う）」（本実装は「1本目の溝を1回クリック」）。`trackGroove` の始点の初期化は1列目から 20 px の範囲だけを見るので、左端の近くをクリックするよう書く。
- 確認用の図（`SAVE_FIG`）：
  - 本実装：`results/<日付>/grooveHist_img<i>.png`（画像に N 本の経路 `info.yAbs`（重心法）を色を変えて重ね、始点に黄色の三角）、`results/<日付>/grooveHist_histogram_img<i>.png`（補正後の y のヒストグラム。横軸に点の数、縦軸に y。しきい値の線と、選んだ N 個の山に印。範囲は `centers(N)−20` から `+20` px）。
  - 正解データ：`results/<日付>/grooveTrackN_img<i>.png`（N 本の経路とクリック位置）。
  - 再現のとき（`ginput` なし）は `figure('Visible','off')` で作って保存し、閉じる。
- 写真ごとに、両手法の `centers`、帯の中で点が無かった列の数、同じ列に2点以上あった列の数（本実装）、または `y0`（正解データ）を `fprintf` で表示する。
- `extractMultiGroove` のエラー（`findGrooveCenters:*` など）は、スクリプトで `try`/`catch` し、写真の番号と手法を書いた `error("grooveHist_Ncycle:grooveSelectionFailed", ...)` に `addCause` して出し直す（どの写真で止まったかを分かるようにする）。
- `sum(counts) == numel(xQuery)` の確認、マスクについてのコメントは `grooveTrack_1cycle.m` と同じ。

## 5. 実装の手順

正式なデータ（`experiments/` に残すもの）は、実装では作らない。評価の段階（7章）で作る。

0. **#28 の確認**：`git log master --oneline -1 -- src/resultDir.m`。master に入っていれば、出力先は `resultDir` に合わせる（その場合は報告に書く）。
1. `src/detrendTrackedShape.m` に2つ目の出力を足し、`test/unit/DetrendTrackedShapeTest.m` にテストを足す。既存のテストが通ることを確かめる。
2. `src/findGrooveCenters.m` と `test/unit/FindGrooveCentersTest.m`。
3. `src/extractGrooveBands.m` と `test/unit/ExtractGrooveBandsTest.m`。
4. `src/extractMultiGroove.m` と `test/unit/ExtractMultiGrooveTest.m`。
5. `src/cycleMethodResult.m` を広げ、`test/unit/CycleResultTest.m` にテストを足す。`src/saveCycleResult.m` のヘルプに追記する（コードは変えない）。
6. `scripts/grooveHist_Ncycle.m`（4.1・4.4・4.5）。点の検出は `grooveTrack_1cycle.m` L86–127 を写す。
7. `scripts/grooveTrack_Ncycle.m`（4.2 の最後・4.4・4.5）。保存・音声・図の部分は 6 と同じ書き方にする。
8. 書いた・変えた `.m` すべてに `checkcode` をかけ、警告を0にする。`cd test; results = runAllTests;` がすべて通ることを確かめる（`StaticAnalysisTest` が新しいスクリプトも検査する）。
9. **実データでの動作確認（`experiments/` には保存しない）**。スクリプトは `temp/` にコピーし、`date`（出力先に同じ名前のファイルが無い日付）・`PREV_RESULT_PATH`・保存の行（`saveCycleResult` の呼び出しを `matPath = "";` に置き換える）だけを変えて実行する。コピーは消さずに残す。
   1. 本実装：`temp/grooveHist_Ncycle_check<MMDD>.m`、`PREV_RESULT_PATH = fullfile(proj.RootFolder,"experiments","1014","cycleResult_origD_track_1014.mat")`。確かめること：
      - 1周目（`ycoords_cnt(:,1)`・`ycoords_max(:,1)`）が 1014 の `centroid.ycoords`・`localMax.ycoords` と `isequal`（1本目が #25 と同じ）。
      - 写真ごとの `centers` が付録 A.5 の表と同じ。帯の中で点が無かった列の数が付録 A.5 の表と同じ。同じ列に2点以上あった列が0。
      - ±1 を超えたサンプルの数が、重心法 32、局所的最大値法 0（付録 A.7）。`fs = 41729`。
   2. 正解データ用：`temp/grooveTrack_Ncycle_check<MMDD>.m`。`ginput` と再現の代わりに、付録 A.10 の `seedsY`（8×5）を直接使う行に置き換える。確かめること：
      - 1本目が 1014 と同じ（上と同じ確かめ方）。
      - 2〜5本目の `multiGroove.yAbsCnt`・`yAbsMax` が、9-1 の本実装の `yAbs` と、重心法の写真8・5本目を除いて `isequal`。除いた1本は x=2314 の1列だけが違う（付録 A.5）。
      - `sameGroove`・`grooveSkipped` の警告が出ない。
   3. 回帰の確認：`scripts/grooveTrack_1cycle.m` を `temp/` にコピーし（`date`、`PREV_RESULT_PATH` = 1014 の追跡、保存の行を外す）、`ycoords_cnt`・`ycoords_max` が 1014 と `isequal` であることを確かめる（`detrendTrackedShape` の変更で結果が変わらないこと）。
   - 実行ログの警告はすべて報告に書く。図は `results/<日付>/` に出してよい（実行前に同じ名前のファイルが無いことを確かめる）。
10. `README.md` と `CLAUDE.md` を更新する（4.3）。README の新しい節には、4.1 の流れ、溝の向き（y が小さい側が内側）と `shapes{i,j}` の並び、`vertcat` が再生順になる理由、パラメータの表（`BIN_WIDTH`・`TH_HIST_RATIO`・`BAND_TOL` とその根拠を1行ずつ）、正解データ用スクリプトの使い方（`RECLICK_IMAGES`・`GUIDE_RESULT_PATH`）を書く。

## 6. テストの方針（合成データ）

共通：`TestClassSetup` で `PathFixture` を使い `src/` を追加する。図は作らない。

合成データの作り方（`ExtractMultiGrooveTest` などで共通に使う）：
`x = (1:600)'`、`base = 300 + 0.02*(x-300) + 1e-4*(x-300).^2`（曲がった溝）。溝 g = 0〜5 の y は `base - 27*g + 0.4*sin(2*pi*x/(37+5*g)) + 5e-4*g*(x-300)`（溝ごとに違う「音」と、1px 以下の平行でなさ）。点群は全溝の `[x, y_g]` を縦に並べたもの。溝と溝の間（`base - 13.5`）に、50列ごとに偽の点を1つ足す。

**`DetrendTrackedShapeTest`（追加）**
- 2つ目の出力を受け取っても、1つ目の出力が今と同じ（`isequal`）。
- `points(:,2) - polyval(trend.p, x, trend.S, trend.mu)` から平均を引いたものが、1つ目の出力の y と一致する（`AbsTol` 1e-10）。`trend.degree == PolyDegree`。

**`FindGrooveCentersTest`**
- 補正後の y が 0, −27, −54, −81, −108, −135（各600点、±0.4 の正弦波のゆらぎ）＋偽の点 → `numGrooves=4`・`BinWidth=1`・`MinPeakHeight=0.3*600` で、真の中心から `BinWidth/2` 以内の4つが降順で返る。`centers(1)` は 0 の近く。
- 1本目の中心がビンの端（y=0）にあっても選べる（点が2つのビンに分かれても、`MinPeakHeight` を超える）。
- `FirstCenter` を −27 にすると、2本目から数える。
- 山が足りない（`numGrooves=7`）→ `findGrooveCenters:notEnoughPeaks`。
- `MinPeakHeight` が高すぎる → `findGrooveCenters:noPeaksFound`。
- 1本目の溝の点を消す（y≈0 の山が無い）→ `findGrooveCenters:firstPeakNotFound`（隣の山を1本目にしない）。
- `info` の `peakCenters` が昇順で、`peakCenters(info.firstIdx) == centers(1)`。

**`ExtractGrooveBandsTest`**
- 2次式の `trend`（`polyfit` の `[p,S,mu]` で作る）を足した3本の溝で、帯の中の点の y が元の y のまま返る。欠損列（一部の列の点を消す）は `found=false` で、元の y で線形補間される（補正後で補間した値ではない）。
- 同じ列に、帯の中で2点（中心から 0.3 px と 2 px）→ 0.3 px の点を採り、`info.numDuplicateCols == 1`。
- 帯の外（中心から `Tolerance` より遠い）の点は採らない。`xQuery` に無い x の点は使わない。
- 帯の中の点が1つしか無い → `extractGrooveBands:tooFewPoints`。
- `xQuery = (1:0.25:600)'` でも使える。

**`ExtractMultiGrooveTest`**
- 合成データで、溝0の左端の近く（+1 px）をクリック、`numGrooves=4` → `shapes{j}` が `detrendTrackedShape([x, y_{j-1}])` と一致する（`AbsTol` 1e-9）。`shapes{2}` は溝1（y が小さい側）であること。
- `numGrooves=1` → `trackGroove` → `detrendTrackedShape` と同じ結果で、`info.centers` が空。
- `info.yAbs(:,1)` が `trackGroove` の y と、`info.found(:,1)` が `trackGroove` の `found` と同じ。
- 溝2の一部の列の点を消す → `info.found(:,3)` のその列が false。
- `numGrooves=8`（溝が6本しかない）→ `findGrooveCenters:notEnoughPeaks`。
- `xQuery = (1:0.25:600)'` で同じ式から点群を作り、同じ引数で、整数の x での `info.yAbs` が `xQuery=(1:600)'` の結果と一致する（`AbsTol` 1e-9）。`MinPeakRatio` が列の数に対する割合なので、列が4倍でも同じ溝を選ぶことの確認。`shapes`（デトレンド後）や `centers` は、あてはめる点の数が変わる・ビンの境目の点が入れ替わることで少し変わりうるので比べない（`centers` は差が `BinWidth` 以内であることだけを確かめる）。

**`CycleResultTest`（追加）**
- `cycleMethodResult` が (4×2) の `xcoords`・`ycoords`（`pts` は 4×1）を受け付け、`y_comb = vertcat(ycoords{:})` で通る。保存・読み込みで (4×2) の形が残る。
- `xcoords` と `ycoords` の形が違う、または `pts` の数が `size(ycoords,1)` と違う → `cycleMethodResult:sizeMismatch`。
- 1×4 の行の cell は、今と同じく列に直されて通る。

## 7. 評価担当への申し送り

### 7.1 評価の段階で作るデータ（作業ツリーがきれいな状態で、実装のコミットの後）

| 順 | 作る人 | ファイル | 作り方 |
|---|---|---|---|
| 1 | **ユーザー**（`ginput` 40回） | 正解：`experiments/<D1>/cycleResult_origD_track5_<D1>.mat`、図 `results/<D1>/grooveTrackN_img1〜8.png`、wav・図（`(tracking_5_cycles)`） | `scripts/grooveTrack_Ncycle.m` を `temp/grooveTrack_Ncycle_gt<D1>.m` にコピーし、`date = "<D1>"` と `GUIDE_RESULT_PATH = fullfile(proj.RootFolder,"experiments","1014","cycleResult_origD_track_1014.mat")` だけを変えて実行する。写真ごとに、黄色の三角の溝（#25 と同じ1本目）を含めて、そこから上（y の小さい側）へ5本を、左端付近でクリックする。図で5本とも飛び移りが無いかを見る。直すときは、同じコピーで `PREV_RESULT_PATH` に保存したファイル、`RECLICK_IMAGES` に写真の番号を入れて実行し直す（`_2` 付きのファイルができる。どれを正解にするかをメインに伝える） |
| 2 | 評価担当 | 本実装：`experiments/<D2>/cycleResult_origD_hist5_<D2>.mat`、図 `results/<D2>/grooveHist_img*.png`・`grooveHist_histogram_img*.png`、wav・図（`(hist_5_cycles)`） | `scripts/grooveHist_Ncycle.m` を `temp/` にコピーし、`date` と `PREV_RESULT_PATH`（＝1の正解のファイル）だけを変えて実行する（`ginput` なし。`trackingSeeds` が正解の1本目のクリックを返す） |
| 3 | 評価担当 | 評価の出力 `results/<D2>/` | 評価スクリプト（`scripts/evaluation/multiGroove/`、評価担当が作る） |

- D1 と D2 は同じ日でもよい（ファイル名・wav の名前が重ならない）。実行前に、出力先に同じ名前のファイルが無いことを確かめる。
- 正解データは、ユーザーが `temp/` のコピーで作るので、リポジトリの作業ツリーはきれいなまま（`meta.gitDirty = false`）になる。実行前に `git status --porcelain` が空であることをメインが確かめる。
- 評価スクリプトの準備（モードA）で正解データの代わりが要るときは、付録 A.3 のコードと A.10 の `seedsY` で、正解の作り方を再現できる（`experiments/` には保存しない）。

### 7.2 指標（issue の「評価方法」の2を出発点に。しきい値は評価担当が決める）

写真i × j本目（8×5）ごとの値、溝ごと（j）・全体の値を報告する。主に見るのは2本目以降。参考値はこの計画の試行（正解の作り方を `seedsY` で再現したもの）。

| ID | 見ること | 指標の作り方 | 計画の試行での値 |
|---|---|---|---|
| E1 | 同じ溝を選べているか | 本実装の `multiGroove.centersCnt(i,j)` と、正解の `yAbsCnt{i,j}` から本実装の `trendCnt{i}` の値を引いたもの（`found` の列）の中央値との差。溝の間隔（正解の中心の差の中央値）の半分と比べる。隣の溝（j±1）の正解との相関も出す | 差は最大 0.49 px（`BIN_WIDTH/2` 以内）。間隔は 25.5〜28.4 px。隣の溝との相関は −0.15〜0.18 |
| E2 | 形状の一致 | `ycoords(:, j)` を写真ごとにつないだもの（9次デトレンド後）と、正解の同じもの。RMSE [px]・相関、補間後の全列 | 64本中63本で RMSE 0（`isequal`）。重心法の写真8・5本目だけ RMSE 0.018 px・相関 0.998 |
| E3 | 欠損 | 本実装の `foundCnt{i,j}` が false の列の数（補間の前）。正解では採れているのに本実装で採れなかった列の数、その逆 | 1本あたり 0〜16 列（付録 A.5 の表）。正解で採れて本実装で採れなかった列は 0。逆は1列（写真8・5本目・重心法） |
| E4 | 最終出力 | N周分の `y_comb` の RMSE・相関（全体、周ごと） | 重心法 RMSE 0.0028 px・相関 0.99994、局所的最大値法は完全に一致 |
| E5 | 1本目の一致 | 本実装の1周目（`ycoords(:,1)`）が正解の1周目と `isequal`。さらに、1014 の `ycoords` とも `isequal`（ユーザーが #25 と同じ溝をクリックしたことの確認） | どちらも `isequal`（付録 A.1） |
| E6 | 保存と再現 | `grooveSelection` のフィールドと形（4.4 の表）。`y_comb == vertcat(ycoords{:})`、`audio.signal == (y_comb − mean)/ampDivisor`、`fs == 41729`。保存した `pts`・`seeds`・`multiGroove` のパラメータだけで `mergeSegmentPoints`→`extractMultiGroove` を実行し直した結果が `multiGroove.yAbs*`・`found*` と同じ | — |
| E7 | 触らないもの | `experiments/` の既存ファイルの SHA-256（`0731`・`1013`・`1014`・`1022`）。4.3 の「触らないもの」の差分なし。`detrendTrackedShape`・`cycleMethodResult` は、既存のテストが通ることと、5章の9-3（`grooveTrack_1cycle.m` の結果が 1014 と同じ）で確かめる | — |

- 前処理：Q2 が (a) なら、本実装と正解は同じ前処理（溝ごとに写真ごと9次）なので、そのまま比べる。Q2 が (b) になった場合は、正解の `yAbs` から本実装の `trend` を引いて平均を引いたもの（同じ前処理）とも比べ、前処理の差と選び方の差を分けて報告する（付録 A.6 の値：前処理の差だけで RMSE 0.06〜0.29 px）。
- `scripts/evaluation/grooveTracking/compareTrackingToManual.m` は `numel(ycoords)` を80として使うので、N周分のファイルには使えない。
- 報告だけするもの（判定に使わない）：写真ごとの山の間隔（P2 の参考）、両手法の `centers` の差、±1 を超えたサンプルの数、同じ列に2点以上あった列の数。

### 7.3 ユーザーが判断する項目

| ID | 見るもの | 観点 |
|---|---|---|
| U1 | `grooveHist_img1〜8.png`（本実装）、`grooveTrackN_img1〜8.png`（正解） | 5本の経路が溝の底に沿い、隣の溝に飛び移っていないか。本実装と正解で同じ5本か |
| U2 | `grooveHist_histogram_img1〜8.png` | 選んだ5つの山が、1本目から上（y の小さい側）へ続く5本の溝か。しきい値の線より上に、余計な山や落ちた山が無いか |
| U3 | 5周分の wav（本実装・正解）とスペクトログラム | 周の境目（約0.77秒ごと）で音がつながっているか、周の順が正しいか（数値では確かめられなかった。2.3 の15）。写真の境目（約0.096秒ごと）のクリック音が #25 の1周分より目立たないか |

## 8. 未決事項

### 決定事項（2026-10-27、ユーザーの回答）

- **Q1：(b) と (b-1)。** `BIN_WIDTH = 1` px、`BAND_TOL = 3` px、山の高さのしきい値は列の数に対する割合 `TH_HIST_RATIO = 0.3`。
- **Q2：(a)。** 2本目以降も溝ごとに `detrendTrackedShape`（写真ごと9次）をかける。
- **Q3：(a)。** `AMP_DIV = 1.5` px（固定）。±1 を超えたサンプルの数を表示して記録する。
- **Q4：(a)。** `cycleMethodResult` を広げ、`xcoords`・`ycoords` を 80×N にする。
- **仮定 A1〜A7：承認。** 特に A2（`extractGrooveShape` ではなく新しい `extractGrooveBands` を使う）と A4（正解データ用スクリプトの `sameGroove`・`grooveSkipped` の警告、`RECLICK_IMAGES`、`GUIDE_RESULT_PATH`、左端の拡大表示）は、issue から変わる点としてユーザーが確認した。

以下は、決める前の検討の記録（issue の未決事項1〜4）。

### Q1. ヒストグラムと帯のパラメータ（`binWidth`・しきい値・`tol`）

- 背景：写真1枚（約4000列）のヒストグラムでは、1つの溝の山の高さが列の数の 0.5 倍以上になる。ビンの端は `binWidth` の整数倍にそろうので、ビンの中心と溝の中心のずれは最大で約 `binWidth/2` になり、それが帯の取りこぼしと、`extractGrooveShape` のエラー（同じ列の2点）を決める（2.3 の5〜9）。
- 選択肢：
  - (a) 旧スクリプトの値 `binWidth = 5`・`tol = 3`（しきい値だけ決め直す）：ずれが最大 2.3 px になり、帯から1本で最大203点を落とす。同じ列に2点入る列が出て、`extractGrooveShape` が64本中9本でエラーになる。**使えない。**
  - (b) **`binWidth = 1`・`tol = 3`・しきい値 = 列の数 × 0.3**：ずれは 0.5 px 以下。落ちる点0、同じ列の2点0。正解の作り方と 63/64 本が完全に一致。しきい値は 0.20〜0.45 倍の範囲ならどれでも同じ山を選び、0.3 はその中ほど。`tol` を 2.5〜3.5 に変えても、落ちる点は1点以下で同じ列の2点も出ない。
  - (c) `binWidth = 2`・`tol = 3`・しきい値 = 列の数 × 0.3：このデータでは使える（落ちる点1）。ただ、`tol = 3.5` で同じ列の2点が出るなど、(b) より余裕が小さい。
  - しきい値の書き方：(b-1) **列の数に対する割合**（`TH_HIST_RATIO = 0.3`）、または (b-2) 点の数（`TH_HIST = 1200`。写真の列の数は 3997〜4111 なので、どの写真でもほぼ 0.3 倍）。(b-2) は旧スクリプトと同じ書き方だが、高解像度化（`intpD`、列が8倍）では値を8倍にし直す必要がある。
- 推奨：**(b) と (b-1)**。理由：実データで正解の作り方とほぼ完全に一致し、`tol`・しきい値を少し変えても結果がほとんど変わらない（余裕がある）。割合にすれば、#25 で長さを px にしたのと同じく、高解像度化しても値を変えなくてよい。

### Q2. 2本目以降のデトレンド

- 背景：1本目は写真ごと9次でデトレンドする。2本目以降を、(a) 同じ9次でデトレンドするか、(b) 1本目の多項式で補正したあと平均を引くだけにするかで、残る低い周波数の成分が変わる（2.3 の12）。
- 選択肢：
  - (a) **溝ごとに `detrendTrackedShape`（写真ごと9次）**：正解データ・1本目と同じ前処理になり、そのまま比べられる（2.3 の10）。9次多項式で表せる成分（約40Hz以下）は、どの溝でも消える。
  - (b) 補正して平均を引くだけ：その溝と1本目のゆっくりした形の違い（RMS 0.11〜0.20 px。音の成分の40〜80%）が残る。内側の溝ほど大きい。写真の境目の段差が大きくなる（最大 0.78 → 1.43 px）。正解（9次）との差は RMSE 0.06〜0.29 px。
- 推奨：**(a)**。理由：(b) で残る成分は、溝どうしの平行でなさ（写真の写り方）と、両方の溝の低い音が混ざったもので、音として意味を持たない。どの周も同じ前処理になり、#25 の1周分とも比べられる。

### Q3. 正規化に使う値（`amp = (y_comb − mean(y_comb)) / AMP_DIV`）

- 背景：5周分では、ずれの大きな所が1周分より増える（重心法の最大 1.94 px、写真8の5本目）。
- 選択肢：
  - (a) **固定値 `AMP_DIV = 1.5` px**（#25 と同じ）：重心法は 32 サンプル（0.020%）が ±1 を超え、wav では切り捨てられる（最大 1.29）。局所的最大値法は超えない。手法・周の数によらず、同じずれが同じ音量になる。
  - (b) 帯の幅/2：Q1 が `tol = 3` なら (a) と同じ 1.5。`tol` を変えると音量も変わる。
  - (c) 最大値で割る：超えないが、重心法は 1.94 px で割ることになり、音量が (a) の 0.77 倍になる。手法・条件ごとに割る値が変わり、音量を比べられない。
  - (d) 99.9 パーセンタイルで割る：重心法は 1.05 px で割り、音量が 1.43 倍になる一方、0.1%（約160サンプル）が ±1 を超える。
- 推奨：**(a)**。理由：#25 の1周分・手動選択の音と音量を比べられる。超えるのは 0.02% で、#25 でも同じ切り捨てを許容した（#25 criteria.md 5章）。超えた数はスクリプトで表示して記録する。

### Q4. N周分の保存の形

- 背景：今の `cycleMethodResult` は、`xcoords`・`ycoords` が `pts`（80×1）と同じ要素数であることを検証している。
- 選択肢：
  - (a) **`cycleMethodResult` を広げ、`xcoords`・`ycoords` を 80×N にする**（j列目が j周目）：N周分の音声と形状が、今と同じ場所（`centroid.audio`・`ycoords`）に入る。`y_comb = vertcat(ycoords{:})` がそのまま再生順。今の 80×1（と行の cell）の呼び出しは、そのまま通る（4.2）。`numel(ycoords)` を80とみなす既存の評価スクリプトは、N周分のファイルには使えない。
  - (b) `centroid`/`localMax` には1周目だけを入れ、N周分は `grooveSelection` などの別のフィールドに入れる：既存の関数は変えなくてよいが、N周分の音声を読むには専用のコードが要る。
  - (c) 溝ごとに1周分のファイルを N 個保存する：1回の実行で5ファイルになり、N周分の音声はどのファイルにも無い。
- 推奨：**(a)**。理由：図のスクリプトは `y_comb`・`audio` を読むだけなので、N周分をそのまま使える。変更は検証の1か所で、今の呼び出し方の結果は変わらない。

### 仮定（承認されれば、実装担当はこのとおりに進める。どれも、このデータの出力は変わらない）

- A1：スクリプト名は issue の案のとおり `scripts/grooveHist_Ncycle.m`（本実装）・`scripts/grooveTrack_Ncycle.m`（正解データ用）。結果のファイル名は `cycleResult_origD_hist<N>_<日付>.mat`・`cycleResult_origD_track<N>_<日付>.mat`。図・wav の名前は 4.4・4.5。
- A2：帯の点の取り出しは `extractGrooveShape` ではなく新しい `extractGrooveBands` で行い、同じ列に2点以上あれば中心に最も近い点を採る（2.4・3.2）。このデータでは起きない。
- A3：`findGrooveCenters` は、1本目の山が `FirstCenter`（0）から 5 px より離れていたらエラーにする（隣の山を1本目にして、以後の周がすべて1本ずれるのを防ぐ）。P2（間隔の確認）とは別の、1本目だけの確認。
- A4：正解データ用スクリプトに、`sameGroove` に加えて `grooveSkipped` の警告、`RECLICK_IMAGES`、`GUIDE_RESULT_PATH` を足す。クリックの図は左端 300 px を拡大する（本実装も同じ）。40回のクリックを正確に、やり直しを少なくするため。
- A5：`cycleConditions` は変えない。本実装は `BinWidth`・`Tol` に実際の値、`ThHist`・`HPrl` に `NaN`。正解データは #25 と同じく4つとも `NaN`。複数本のパラメータは `grooveSelection.multiGroove` に入れる。
- A6：#28 は open なので、今は `mkdirFromDate`・`experimentDir` を使う（5章の0で確かめ直す）。
- A7：スクリプトの中では、形状を issue の決定どおり 8×N の cell（`[xQuery, y]`）に入れ、保存は `counts` で分けた 80×N の `ycoords` にする。

## 9. リスク

| リスク | 起きたときの症状 | 代わりの案・対策 |
|---|---|---|
| ある溝が長い範囲で途切れ（大きな傷など）、山がしきい値より低くなる | その溝を飛ばし、以後の周がすべて1本ずれる（エラーにならない） | ヒストグラムの図（U2）と経路の図（U1）で気づける。起きたら P2（山の間隔の確認）を足す。間隔はこのデータで ±5% 以内なので、1.5倍の判定は誤報が出にくい |
| 溝の間に、しきい値を超える偽の山がある | 余計な山を1本と数える | 写真2の偽の山は 0.19 倍で、しきい値 0.3 に対して余裕は 0.11。同じく図と P2 で対処 |
| 溝の曲がり方の違いが、他のレコードや N を増やしたときに大きくなる | 帯（±3 px）の端の点を落とす | このデータでは、補正後の経路は中央値から −1.7〜+2.2 px、ビンのずれ 0.5 px を足しても 3 px に収まる（余裕 0.3 px）。落ちたら `BAND_TOL = 3.5`（このデータでは同じ列の2点が出ない）か、P1・P3 を検討する |
| N を増やすと、内側の溝が写真の上端からはみ出す | `findGrooveCenters:notEnoughPeaks`（はみ出して山が低くなった場合も同じ） | 識別子付きのエラーで止まる（要求どおり）。このデータでは 8〜10 本まで山がある |
| ユーザーのクリックが溝から 8 px 以上ずれる、隣の溝を2回クリックする、溝を飛ばす | 正解データの溝がずれる | 左端の拡大表示、`sameGroove`・`grooveSkipped` の警告、`GUIDE_RESULT_PATH`、`RECLICK_IMAGES`、図（U1）、E5（1014 との一致）で気づける |
| 周の順・向きが違う（y が小さい側が内側でない、写真8の次が j+1 本目でない） | 周の境目で音が飛ぶ | ユーザーが確認済みの前提。数値では確かめられなかった（2.3 の15）ので、試聴（U3）で確かめる。必要なら P4（針で再生した音との相互相関）を続きの issue にする |
| `cycleMethodResult` の変更で既存の結果が変わる | 既存のスクリプトでエラー・形の違い | ベクトルの場合は今と同じ処理にする。既存のテストと、5章の9-3の回帰の確認で確かめる |

## 10. 付録：MATLABでの試行

2026-10-26 に `Research.prj` を `openProject` で開いて実行した（R2024b Update 6）。すべて読み取りのみ。図は作っていない。

### A.1 点群と1本目（#25 と同じことの確認。約5秒）

```matlab
root = currentProject().RootFolder;
R14 = loadCycleResult(fullfile(root,"experiments","1014","cycleResult_origD_track_1014.mat"));
gs14 = R14.grooveSelection; fn = R14.conditions.filenames; N = 5;
allPts_cnt(80,1) = GroovePointCloud(); allPts_max(80,1) = GroovePointCloud();
for iImg=1:8
  g = rgb2gray(imread(fn(9-iImg)+".png")); [~,width]=size(g);
  dv = round(width/10); xa = [1:dv:width width+1]';
  for j=1:10
    k=(iImg-1)*10+j; oi = ImageData(omitMask(g(:,xa(j):xa(j+1)-1),20),[iImg;j]);
    map = DarknessMap(oi); map = map.setDiffTF(0.6);
    pc = GroovePointCloud(map); pm = GroovePointCloud(map); ex = GrooveExtractor(map);
    for x=1:oi.width
      [f1,l1]=ex.findThresholdIntervals(map,x); [ex,~,~,np]=ex.findGrooveBottomIntervals(map,x,f1,l1,8);
      pc.peakCells{x}=[x*ones(np,1) ex.extractByCentroid(map,x)]; pm.peakCells{x}=[x*ones(np,1) ex.extractByLocalMax(map,x)];
    end
    allPts_cnt(k)=pc; allPts_max(k)=pm;
  end
end
PH = struct();
for iImg=1:8
  ks=(iImg-1)*10+(1:10);
  [pc, xq] = mergeSegmentPoints(allPts_cnt(ks)); pm = mergeSegmentPoints(allPts_max(ks));
  seed = [xq(1), gs14.seeds(iImg,2)];
  PH(iImg).pc=pc; PH(iImg).pm=pm; PH(iImg).xq=xq;
  PH(iImg).tc = trackGroove(pc, seed, xq); PH(iImg).tm = trackGroove(pm, seed, xq);
  % isequal(PH(iImg).tc(:,2), gs14.tracking.yAbsCnt{iImg}) → 8枚とも true（局所的最大値法も）
end
```

結果：8枚・2手法とも 1014 と `isequal`。欠損は `[0 7 6 0 0 4 0 0]`（#25 と同じ）。

### A.2 補正とヒストグラム（0.5 px のビンで山の位置を見る）

```matlab
for iImg=1:8
  for m=["c","m"]
    t = PH(iImg).("t"+m); P = PH(iImg).("p"+m);
    [p,S,mu] = polyfit(t(:,1), t(:,2), 9);                % detrendTrackedShape と同じあてはめ
    PH(iImg).("base"+m) = polyval(p, PH(iImg).xq, S, mu);
    PH(iImg).("cor"+m)  = [P(:,1), P(:,2) - polyval(p, P(:,1), S, mu)];
  end
  edges = -200:0.5:60; ctr = edges(1:end-1)+0.25;
  ns = movsum(histcounts(PH(iImg).corc(:,2), edges), 5);
  [~, loc] = findpeaks(ns, 'MinPeakHeight', 1000, 'MinPeakDistance', 30);
  cts = sort(ctr(loc),'descend'); [~,i0]=min(abs(cts)); PH(iImg).fineCenters = cts(i0:i0+N-1);
end
```

結果：どの写真も、2.5 px の範囲に約4000点（ほぼ全列）が入る山が 26〜28 px おきに並ぶ（写真1：…, −107.3, −80.8, −54.3, −27.3, −0.3, 26.8, 54.3）。

### A.3 正解の作り方の再現（2〜5本目を `trackGroove` で追跡）

```matlab
for iImg=1:8
  xq = PH(iImg).xq;
  for m=["c","m"]
    P = PH(iImg).("p"+m); base = PH(iImg).("base"+m); TR = cell(1,N); FD = cell(1,N);
    for j=1:N
      [TR{j}, FD{j}] = trackGroove(P, [xq(1), base(1) + PH(iImg).fineCenters(j)], xq);
    end
    PH(iImg).("trk"+m) = TR; PH(iImg).("fnd"+m) = FD;
    cc = zeros(1,N);
    for j=1:N, f=FD{j}; yc=TR{j}(:,2)-base; cc(j)=median(yc(f)); end
    PH(iImg).("true"+m) = cc;   % 補正後の経路の中心
  end
end
```

結果：補正後の経路は、中央値から −1.71〜+2.21 px に収まる。溝の間隔は写真ごとに 25.5〜28.4 px（写真1：27.1 27.0 26.7 26.6、写真2：26.2 26.2 25.8 26.5、写真5：27.9 27.5 27.4 28.0、写真8：28.3 27.8 27.7 28.4）。5本目の y は 89〜289（写真の高さは 454〜562）。各写真で、1本目より y の小さい側に、0.3 倍のしきい値を超える山が 8〜10 個ある。

### A.4 パラメータの比較

```matlab
% 写真 iImg・手法 m について。Pc = PH(iImg).("cor"+m)、xq = PH(iImg).xq
% 山の選び方（bw: binWidth、th: 列の数に対する割合）
[cnt,e] = histcounts(Pc(:,2),'BinWidth',bw); cen = e(1:end-1)+diff(e)/2;
[~,locs] = findpeaks(cnt,'MinPeakHeight',th*numel(xq)); [~,i0] = min(abs(cen(locs)));
sel = cen(locs(i0:-1:i0-N+1));            % 正しいか：all(abs(sel - PH(iImg).("true"+m)) < 13)
% 帯（tol）：落ちる点・余計な点・同じ列の2点（j = 2..N）
t = PH(iImg).("trk"+m){j}; f = PH(iImg).("fnd"+m){j}; base = PH(iImg).("base"+m);
trP = [t(f,1), t(f,2)-base(f)];            % 正解の作り方で採った点（補正後）
B = Pc(abs(Pc(:,2)-sel(j))<=tol,:);
lost = nnz(~ismember(trP,B,'rows')); extra = nnz(~ismember(B,trP,'rows'));
multi = nnz(accumarray(round(B(:,1)),1,[max(xq) 1])>=2);
try, extractGrooveShape(Pc, sel(j), xq, Tolerance=tol); catch ME, disp(ME.identifier), end
```

結果（8枚で正しい5本を選べた枚数。左が重心法、右が局所的最大値法）：

| `binWidth` \ しきい値（×列の数） | 0.10 | 0.15 | 0.20〜0.45 | 0.50 | ビンの中心のずれの最大 [px] |
|---|---|---|---|---|---|
| 1 | 7 / 8 | 7 / 8 | 8 / 8 | 7 / 7 | 0.48 / 0.49 |
| 2 | 7 / 7 | 7 / 8 | 8 / 8 | 8 / 8 | 0.98 / 0.99 |
| 2.5 | 7 / 7 | 7 / 8 | 8 / 8 | 8 / 8 | 1.20 / 1.17 |
| 3 | 7 / 7 | 7 / 8 | 8 / 8 | 8 / 8 | 1.48 / 1.49 |
| 5 | 7 / 7 | 7 / 7 | 8 / 8 | 8 / 8 | 2.27 / 2.27 |

しきい値 0.3 での帯の結果は 2.3 の8の表。山の高さ（最も高いビン ÷ 列の数、`binWidth = 1`、8枚の最小 / 平均）は、1本目 0.50 / 0.51、2〜5本目 0.50〜0.71 / 0.67〜0.77。溝の間の最も高いビンは、写真2で 0.17〜0.19、それ以外は 0.05 以下。

### A.5 推奨の値での帯の取り出し（元の y で並べて補間）と、正解の作り方との比較

```matlab
BW=1; TOL=3; THR=0.3;
% 写真 iImg・手法 m について（P: 点群、T1: 1本目の trackGroove の出力、xq: xQuery）
[p,S,mu] = polyfit(T1(:,1),T1(:,2),9); yCor = P(:,2)-polyval(p,P(:,1),S,mu);
[cnt,e] = histcounts(yCor,'BinWidth',BW); cen = e(1:end-1)+diff(e)/2;
[~,locs] = findpeaks(cnt,'MinPeakHeight',THR*numel(xq)); [~,i0] = min(abs(cen(locs)));
ctrs = cen(locs(i0:-1:i0-N+1));
[tf,col] = ismember(P(:,1),xq);
for j=2:N
  inB = tf & abs(yCor-ctrs(j))<=TOL; idx = find(inB);
  [~,ord] = sort(abs(yCor(idx)-ctrs(j)),'descend'); idx = idx(ord);
  y = NaN(numel(xq),1); y(col(idx)) = P(idx,2);            % 同じ列では中心に最も近い点が残る
  yAbs = [xq fillmissing(y,"linear")];
  % isequal(yAbs, PH(iImg).("trk"+m){j}) を数える。形状は detrendTrackedShape(yAbs,PolyDegree=9)
end
```

結果：
- `isequal`：重心法 31/32、局所的最大値法 32/32。違う1本（重心法・写真8・5本目）は x=2314 の1列（帯の点 −109.9、中心 −112.5 から 2.6 px。追跡では予測から 2 px を超えて採らなかった）で、デトレンド後の RMSE 0.0177 px。
- 同じ列に2点以上ある列：0（両手法）。
- 選んだ山の中心（補正後、`centers`。左から1〜5本目）

  | 写真 | 重心法 | 局所的最大値法 | 列の数 |
  |---|---|---|---|
  | 1 | 0.5 −27.5 −53.5 −80.5 −107.5 | 同じ | 3999 |
  | 2 | −0.5 −26.5 −52.5 −78.5 −104.5 | 同じ | 3999 |
  | 3 | 0.5 −26.5 −52.5 −78.5 −104.5 | −0.5 −26.5 −52.5 −78.5 −104.5 | 3997 |
  | 4 | 0.5 −27.5 −54.5 −80.5 −108.5 | 同じ | 3999 |
  | 5 | 0.5 −27.5 −55.5 −82.5 −110.5 | 同じ | 3998 |
  | 6 | −0.5 −26.5 −51.5 −77.5 −103.5 | 同じ | 3997 |
  | 7 | 0.5 −27.5 −53.5 −80.5 −108.5 | −0.5 −27.5 −53.5 −80.5 −108.5 | 3999 |
  | 8 | −0.5 −28.5 −56.5 −83.5 −112.5 | 同じ | 4111 |

- 帯の中で点が無かった列の数（補間の前。2〜5本目。両手法とも同じで、正解の作り方の欠損とも同じ。ただし重心法の写真8・5本目は正解の作り方では1列）

  | 写真 | 2本目 | 3本目 | 4本目 | 5本目 |
  |---|---|---|---|---|
  | 1 | 0 | 0 | 4 | 0 |
  | 2 | 0 | 3 | 10 | 7 |
  | 3 | 6 | 2 | 2 | 0 |
  | 4 | 0 | 1 | 0 | 0 |
  | 5 | 0 | 3 | 3 | 16 |
  | 6 | 0 | 0 | 1 | 0 |
  | 7 | 2 | 0 | 3 | 0 |
  | 8 | 2 | 0 | 0 | 0 |

- 5周分の `y_comb`（8×5 を `vertcat`）：重心法 RMSE 0.0028 px・相関 0.99994（周ごとの RMSE `[0 0 0 0 0.0063]`）、局所的最大値法は一致。帯を補正後の y で補間した場合は、欠損の所で 1e-7〜2e-6 px の差が出る（2.4 の3）。

### A.6 未決事項2：(a) 溝ごとに9次、(b) 補正して平均を引くだけ

```matlab
yAbs = ...;                                          % A.5 の yAbs（元の画像の y、補間済み）
base = PH(iImg).("base"+m);                          % 1本目の多項式の値 polyval(p,xq,S,mu)
ya = detrendTrackedShape(yAbs,PolyDegree=9); ya = ya(:,2);    % (a)
yb = yAbs(:,2) - base; yb = yb - mean(yb);                     % (b)
yt = detrendTrackedShape(PH(iImg).("trk"+m){j},PolyDegree=9); yt = yt(:,2);   % 正解の作り方
% RMSE = sqrt(mean((ya-yt).^2))、corr(ya,yt)。(b) は yb と yt で同じく計算
% 写真の境目の段差：shapes(8×5) を列の順に並べ、隣どうしの cell の「最後の値 − 最初の値」の絶対値
```

結果：
- (a) と正解の作り方：A.5 のとおり（63/64 で RMSE 0）。
- (b) と正解の作り方：RMSE 0.058〜0.287 px、相関 0.60〜0.96（重心法）、0.073〜0.288 px・0.74〜0.99（局所的最大値法）。(b) を、正解の経路に同じ補正をかけて平均を引いたものと比べると RMSE 0（差はすべて前処理による）。
- (a)−(b) の RMS（写真8枚の平均 / 最大、重心法）：2本目 0.114 / 0.169、3本目 0.136 / 0.179、4本目 0.178 / 0.287、5本目 0.197 / 0.268 px。局所的最大値法：0.132 / 0.197、0.146 / 0.209、0.188 / 0.288、0.210 / 0.269 px。差の最大値は 0.5〜0.9 px。
- 補正後の経路の、中央値からのずれの標準偏差（8枚の平均、1〜5本目）：重心法 0.24 0.24 0.33 0.29 0.35、局所的最大値法 0.33 0.33 0.40 0.36 0.42 px。
- 写真の境目の段差（5周分、39か所）：重心法 (a) 中央値 0.279・最大 0.775、(b) 0.319・1.432。局所的最大値法 (a) 0.495・1.176、(b) 0.515・1.771 px。隣どうしの列の差の中央値は 0.014・0.011 px。

### A.7 正規化（`AMP_DIV = 1.5`）

```matlab
yall = vertcat(SA{:}); a = (yall - mean(yall))/1.5;   % SA：8×5 の (a) の形状
nnz(abs(a)>1), max(abs(a)), prctile(abs(a),99.9), rms(a)
```

結果：重心法 32 サンプル（0.020%）、最大 1.291（写真8・5本目）、99.9 パーセンタイル 0.700、RMS 0.172。局所的最大値法 0 サンプル、最大 1.000、0.777、0.223。(b) の前処理では重心法 45・局所的最大値法 20 サンプルが超える。溝ごとの最大の |y|（重心法）：1.55 1.84 1.77 1.84 1.94 px。

### A.8 写真の重なり（周の順を数値で確かめられるか）

```matlab
L=200; W=1500; tail = a(end-L+1:end) - mean(a(end-L+1:end));     % a：写真 i（または写真8の j本目）の形状
for s=1:W-L, seg=b(s:s+L-1)-mean(b(s:s+L-1)); r(s)=sum(tail.*seg)/sqrt(sum(tail.^2)*sum(seg.^2)); end
max(r)                                                            % b：写真 i+1（または写真1の j / j+1本目）
```

結果：写真 i → i+1（1本目）で最大 0.25〜0.66、写真8の j本目 → 写真1の j本目 / j+1本目で 0.25〜0.60 で、はっきりした違いが無い。写真の重なりは見つからず、周の順は数値では確かめられない。

### A.9 `cycleMethodResult` の今の検証

```matlab
f = @(c) cycleMethodResult("centroid", repmat(GroovePointCloud(),3,1), c, c, [1;2;3], AudioData("a",[1;2;3],10));
f({1,2,3})          % 通る（行の cell が 3×1 に直される）
f(repmat({1},3,2))  % MATLAB:validation:IncompatibleSize
```

### A.10 正解の作り方を再現する始点（`seedsY`、8×5、外側から。動作確認用）

`seedsY(i,j) = 1本目の多項式の1列目の値 + A.2 の山の位置` を 0.1 px に丸めたもの（重心法の多項式）。この値で `trackGroove`（始点 `[1, seedsY(i,j)]`）を両手法にかけると、A.3 の結果と `isequal` になる。1列目は #25 の始点（`gs14.seeds(:,2)` = 260 289 242 241 337 268 242 249）から 0.2〜2 px の違いで、同じ溝になる。

```matlab
seedsY = [259.4 232.4 205.4 178.9 152.4
          288.4 262.4 235.9 210.4 183.9
          242.3 216.3 189.8 164.3 137.8
          241.6 214.6 187.6 160.6 133.6
          338.3 310.3 283.3 255.8 227.8
          266.0 240.0 214.5 189.0 162.5
          241.8 214.8 187.8 161.3 133.8
          248.5 220.0 192.5 164.5 136.0];
```
