- 段階: 実装
- 作成者: implementer
- 作成日: 2026-11-17
- 入力: issue #35（本文。コメントなし）、[`./README.md`](./README.md)（作業履歴の決定）、[`./plan-2.md`](./plan-2.md)（承認済み）、[`./plan.md`](./plan.md)（plan-2.md が参照する章）、[`./criteria.md`](./criteria.md)（承認済み）、`test/unit/WideBottomOutlierAcceptanceTest.m`、`scripts/evaluation/grooveBottomDetection/compareWidthThresh.m`、メインからの依頼文（実装1回目）
- 状態: 下書き

# #35 正規化した振幅が1付近の外れ値が、溝の選び方によらず出る — 実装の報告（1回目）

## 言葉

- **溝底区間**：写真の各列で、暗さ（1 − 画素値/255）がしきい値 `D_THRESH`（0.6）以上の行が続く範囲。**幅**は、その最後の行 − 最初の行 [px]。幅の上限 `WIDTH_THRESH` 以下の区間だけが溝底点になる。
- **3つのスクリプト**：自動追跡の `scripts/grooveTrack_1cycle.m`（1周分）・`scripts/grooveHist_Ncycle.m`（5周分の本実装）・`scripts/grooveTrack_Ncycle.m`（5周分の正解データ）。
- **t1014・h1104・t1104**：3つのスクリプトがそれぞれ作った、保存済みの結果（`experiments/1014/cycleResult_origD_track_1014.mat`・`experiments/1104/cycleResult_origD_hist5_1104.mat`・`experiments/1104/cycleResult_origD_track5_1104.mat`）。criteria.md 2.1 と同じ呼び名。
- **振幅**：デトレンドした y を再生順につなぎ、全体の平均を引いて 1.5 px で割ったもの（スクリプトの `amp_cnt`・`amp_max`）。
- **変わった列**：直す前（保存した結果）と直した後で、デトレンド前の y の差が 1e-9 を超える列。
- **temp のコピー**：動作確認のために `temp/35-impl/` にコピーし、日付・出力先・`PREV_RESULT_PATH`・保存の行だけを変えたスクリプト。

## 1. 結論

- plan-2.md 5章の手順1〜6を、すべて終えた。
  - 3つのスクリプトの `WIDTH_THRESH` を 8 から 4 にし、理由をコメントに書いた。ほかのコードの行は変えていない。
  - 図の語 `wTh<N>` を、新しい分類「溝底区間の幅」として「溝底の判定」のすぐ下に足した（`docs/rules/figures.md` と `src/figureVocabulary.m`）。`FigureNameTest` に確認を1つ足した。
  - README の3か所に、幅の上限が4であることと、その理由・欠点を書いた。
- 受け入れテストは、直す前（値 8）は15件中6件が失敗し、直した後は15件すべて通った。
- `cd test; results = runAllTests;` は **258件すべて通った**（受け入れテスト15件を含む。失敗0、未完了0）。変えた `.m` 5つの `checkcode` の警告は0件。
- temp のコピーで、3つのスクリプトを保存したクリック位置で実行した。警告は出ず、重心法の \|振幅\| > 1 は 0・0・0、\|振幅\| > 0.8 は 1・9・9 で、plan-2.md 7.3 の直した後の値と同じだった。
- 計画との違いは、ドキュメントの小さな書き足し2つと、動作確認での出力先・保存の扱いだけである（3章）。インターフェースとコードの変更は計画どおり。

## 2. 変更したファイル

| 区分 | パス | 要点 |
|---|---|---|
| 変更 | `scripts/grooveTrack_1cycle.m` | `WIDTH_THRESH = 4;` にし、行末のコメントを plan-2.md 4.2 の3行に置き換えた。冒頭の作成日の下に「`% 2026/11/17：溝底区間の幅の上限 WIDTH_THRESH を 8 から 4 に変えた（issue #35）`」を足した |
| 変更 | `scripts/grooveHist_Ncycle.m` | 同上 |
| 変更 | `scripts/grooveTrack_Ncycle.m` | 同上 |
| 変更 | `src/figureVocabulary.m` | `conditionTable` の `inclBound` の次に `"溝底区間の幅", "wTh<N>"` を足した。冒頭のコメントの分類の一覧に「溝底区間の幅」を足した |
| 変更 | `docs/rules/figures.md` | 語彙表の「条件」の `inclBound` の次に `wTh<N>` の行を足した（表記 width threshold N px、意味は plan-2.md 4.3 のとおり）。「条件」の並び順の文に「溝底区間の幅」を足した。「条件の書き方」の例外の文に、溝底区間の幅を足した（3章） |
| 変更 | `test/unit/FigureNameTest.m` | `testOtherValidForms` に `grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4` を1行足した（plan-2.md 6.2 の (a)） |
| 変更 | `README.md` | 「処理の流れ」の4に、幅の上限が自動追跡の3つのスクリプトでは 4 px、従来法では 8 px であることを1文足した。`scripts/` の3つのスクリプトの説明に、幅の上限を短く足した。「溝の自動追跡（trackGroove）」の節の末尾に「溝底区間の幅の上限」の段落を足し、理由（plan-2.md 2.1・2.2）と欠点（9章の1つ目）を書いた |
| 新規（受け渡し） | `docs/issues/35-wide-bottom-outliers/impl-report-1.md` | この報告 |

- 変えていないもの
  - `src/` の `figureVocabulary.m` 以外、従来法のスクリプト、`scripts/progress/`・`scripts/evaluation/`、`CLAUDE.md`、`archive/`、受け入れテスト、`criteria.md`、`plan-2.md`、`data/`・`experiments/`。
  - 新しい unitテストのクラスは作っていない（`src/` に新しい関数が無いため。plan-2.md 6.2）。
- コミットはしていない（実装担当の定義のとおり）。作業ブランチは `claude/wide-bottom-outliers`。

## 3. 計画との違い

インターフェース（スクリプトのパラメータの名前と値、語の名前と分類）は計画どおりである。次の3つは、計画に書かれていない細部として自分で決めた。

- `docs/rules/figures.md` の「条件の書き方」の1文を直した。
  - 直した文：「図が依存する条件は、既定の値でも省略しない（…）。例外は周数と溝底区間の幅である。周数は、1周のときは書かない。溝底区間の幅（`wTh<N>`）は、幅の上限を比べる図にだけ書く。」
  - 理由：承認された語の意味（「幅の上限を比べる図にだけ書き、比べない図には書かない」）と、「依存する条件は省略しない。例外は周数」という決まりが、そのままでは食い違って読めるため。新しい決まりは足しておらず、語の意味の列と同じことを、決まりの側にも書いた。`FigureNameTest` の表の読み取りには影響しない（「### 形」の節で、表ではない）。
- README の「溝底区間の幅の上限」の欠点に、plan-2.md 9章の3つ目（ほかの撮影条件で溝底の線そのものが幅5以上になると溝底点が大量に消え、`trackGroove:longGap` の警告が出る）も1文で書いた。計画の手順4の (3) は「9章の1つ目」だけを挙げていたが、使う人が設定の合わない場合に気づく手がかりになるため。
- 手順5（実データでの動作確認）の出力と保存の扱いは、メインの依頼文に従い、plan-2.md 5章の手順5から次のように変えた。
  - wav と図の出力先を `results/<日付>/` ではなく `temp/35-impl/out_<スクリプト名>/` にした。評価の段階で評価担当が同じ日付の `results/` に出力するので、名前がぶつからないようにするため。`results/` には何も出していないので、手順5の (2)（`results/<日付>/` の同名のファイルの確認）は要らなくなった。
  - `saveCycleResult` の呼び出しを、`temp/35-impl/check_<スクリプト名>_1117.mat` に `y_comb_cnt`・`y_comb_max`・`cond` だけを保存する行に置き換えた（criteria.md 8章の手順4の (2) と同じ形）。`experimentDir` には `Create=false` を付けた。

## 4. 確認の結果

### 4.1 直す前の受け入れテスト（手順1）

今のスクリプト（`WIDTH_THRESH = 8`）で `runtests('test/unit/WideBottomOutlierAcceptanceTest.m')` を実行した。15件中9件が通り、6件が失敗した。plan-2.md 6.1 と criteria.md 3.3 のとおりである。

- 失敗したテスト（3つのスクリプトそれぞれで2件ずつ）
  - `testWideOneSidedIntervalIsNotDetected`：幅5の区間から溝底点を作らないことの確認。重心法・局所的最大値法の両方が失敗した。
    - 重心法：「grooveTrack_1cycle.m（WIDTH_THRESH = 8）：幅5の区間（片側に薄暗い行がつながったもの）を溝底点にしている（重心法）。 列と y [px]：列100 y=46.38、列101 y=46.38、列102 y=46.38、列103 y=46.38」
    - 局所的最大値法：同じ文で、列100〜103 に y=45.00 の点がある。
    - `grooveHist_Ncycle.m`・`grooveTrack_Ncycle.m` も、ファイル名のほかは同じ値だった。
  - `testSelectionInterpolatesOverWideInterval`：溝の選択がその列の点を採らず、補間することの確認。
    - 「grooveTrack_1cycle.m（WIDTH_THRESH = 8）：溝の選択（track）が、幅5の区間の点を採っている（列 [100 101 102 103]）。 列と y [px]：列100 y=46.38、列101 y=46.38、列102 y=46.38、列103 y=46.38」
    - 「grooveTrack_1cycle.m（WIDTH_THRESH = 8）：溝の選択（track）の y が溝底の線（y = 45）からずれている。」ずれは 4列とも 1.3778 px（上限 0.1 px）。
    - `grooveHist_Ncycle.m` は「溝の選択（hist）」になり、値は同じだった。`grooveTrack_Ncycle.m` は `grooveTrack_1cycle.m` と同じだった。
- 通ったテスト：`testWidth4IntervalIsKept`・`testSelectionKeepsWidth4Interval`・`testSelectionElsewhereIsOnTheGroove`（3つのスクリプトで計9件）。

### 4.2 直した後のテストと checkcode（手順2・3・6）

- 受け入れテストを単独で実行すると、15件すべて通った（スクリプトを直した直後）。
- `FigureNameTest` を単独で実行すると、18件すべて通った（語彙を足した直後）。
- `cd test; results = runAllTests;` は、258件のうち258件が通った（失敗0、未完了0）。受け入れテストは15件中15件、`FigureNameTest` は18件中18件が通った。テストの件数は評価基準の段階と同じ258件である（`FigureNameTest` には、既存のテストの中に名前を1つ足しただけのため）。
- `checkcode` の警告は、`scripts/grooveTrack_1cycle.m`・`scripts/grooveHist_Ncycle.m`・`scripts/grooveTrack_Ncycle.m`・`src/figureVocabulary.m`・`test/unit/FigureNameTest.m` のすべてで0件だった。
- 評価スクリプトが作る形の図の名前を `checkFigureName(…,Warn=false)` で確かめ、すべて理由0件で通った。
  - 確かめた名前：`grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_715-716ms`、`waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2718-2719ms`、`waveform_wTh8VsWTh4_origD_inclBound_centroid_track_1014_715-716ms`
  - 比較に出した `wTh8VsWTh4` と同じ分類の語（`wTh4`）を条件にも書くと、「比較に出した分類（溝底区間の幅）の語を、条件にも書いています。」と返ることも確かめた。

### 4.3 差分の確認（criteria.md の D1・D2 にあたるもの）

- `git diff --name-status c557c33 -- src scripts test docs/rules README.md CLAUDE.md` に出たのは、上の7ファイルと `docs/rules/writing.md` だった。`docs/rules/writing.md` は master から取り込んだ変更（`2027600`）で、criteria.md 4.5 の D1 の補足により除かれる。
- 3つのスクリプトの差分（`git diff -U0 c557c33`）で、コメントでない変わった行は `WIDTH_THRESH` の代入の行（`-` が値 8、`+` が値 4）だけだった。

### 4.4 実データでの動作確認（手順5）

3つのスクリプトを `temp/35-impl/` にコピーし、保存したクリック位置で実行した（`ginput` なし）。`date` は `"1117"`、`SAVE_FIG`・`SAVE_TRACK_FIG` は `false` にした。`grooveTrack_Ncycle.m` の `RECLICK_IMAGES` は空、`GUIDE_RESULT_PATH` は空文字のままである。

| データ | temp のコピー | `PREV_RESULT_PATH` | 実行時間 | `cond.wTh` |
|---|---|---|---|---|
| t1014 | `temp/35-impl/grooveTrack_1cycle_impl1117.m` | `experiments/1014/cycleResult_origD_track_1014.mat` | 19.1 s | 4 |
| h1104 | `temp/35-impl/grooveHist_Ncycle_impl1117.m` | `experiments/1104/cycleResult_origD_hist5_1104.mat` | 15.9 s | 4 |
| t1104 | `temp/35-impl/grooveTrack_Ncycle_impl1117.m` | `experiments/1104/cycleResult_origD_track5_1104.mat` | 19.8 s | 4 |

ワークスペースの値（直した後）。「計画の値」は plan-2.md 7.3・criteria.md 3.1 の直した後の値である。

| 量 | t1014 | h1104 | t1104 | 計画の値 |
|---|---|---|---|---|
| 重心法の \|振幅\| > 1 のサンプル | 0 | 0 | 0 | 0・0・0 |
| 重心法の \|振幅\| > 0.8 のサンプル | 1 | 9 | 9 | 1・9・9 |
| 重心法の \|振幅\| の最大 | 0.8376 | 0.8930 | 0.8930 | — |
| 局所的最大値法の \|振幅\| > 1 のサンプル | 0 | 0 | 0 | h1104 は 0 |
| 局所的最大値法の \|振幅\| > 0.8 のサンプル | 21 | 100 | 100 | t1014 は 21（S2）、h1104 は 100 |
| 重心法の変わった列 | 7 | 106 | 106 | 7・106・106 |
| うち、直す前は点を採っていて、直した後は採らなくなった列 | 7 | 104 | 103 | 7・104・103（(i) 幅の広い点の列） |
| 局所的最大値法の変わった列 | 4 | 33 | 33 | h1104 は 33 |
| 警告 | なし | なし | なし | なし |

- 警告の確かめ方：実行の前に `lastwarn('')` で空にし、実行の後に `lastwarn` が空であることを確かめた。コマンドウィンドウにも警告は出なかった（`trackGroove:longGap`、`grooveTrack_Ncycle:sameGroove`・`grooveSkipped` などを含め、0件）。
- t1014 の補足
  - 変わった列は、写真8の x=33〜36 と x=1862・1863・1865（715 ms の外れ値）の7列だった。
  - 重心法で \|振幅\| > 0.8 として残った1サンプルは、サンプル番号 2433（写真1、振幅 −0.838）だった。issue の「両方が同じ点を選んでいる」写真1 x=2433 の点である。
  - 保存した振幅（`audio.signal`）との差の最大は 0.7216 だった。
  - 写真ごとの点を採れなかった列（重心法）は [0 7 6 0 0 4 0 7]、最も長い連続欠損は [0 7 4 0 0 3 0 4] px だった。
- h1104 の補足
  - ヒストグラムの山の中心は、両手法とも、保存したものと `isequal` だった。
  - 帯の中に2点以上ある列は、両手法とも0だった。
  - 重心法の最も長い連続欠損は 15 列だった（計画の値 15）。
  - スクリプトの表示は「fs = 41729 Hz、±1 を超えたサンプル：重心法 0、局所的最大値法 0（全 160495 サンプル）」だった。
- 直した後の h1104 と t1104 は、`y_comb_cnt`・`yAbsCnt`・`foundCnt` がすべて `isequal` だった（P7 にあたる）。
- 書いたもの・書かなかったもの
  - 書いたものは `temp/35-impl/` の中だけである（3章）。wav と、波形・FFT・スペクトログラムの図（fig・png）は `temp/35-impl/out_grooveTrack_1cycle/`・`out_grooveHist_Ncycle/`・`out_grooveTrack_Ncycle/` に、`y_comb_cnt`・`y_comb_max`・`cond` は `temp/35-impl/check_<スクリプト名>_1117.mat` にある。`temp/35-impl/scratch_hist_1117.mat` は、h1104 と t1104 を比べるために一時的に保存した h1104 の y と点を採れた列である。
  - `experiments/1117/`・`results/1117/` は作っていない。
  - `experiments/` のすべてのファイルの SHA-256 は、実行の前と後で同じだった。値は criteria.md 4.5 の D4 の一覧と一致した。

## 5. 評価担当への申し送り

- 見てほしい点
  - R5：criteria.md 8章の手順4のとおり、コミットの後に評価担当が temp のコピーで実行し直してほしい。この報告の `temp/35-impl/check_*_1117.mat` は、コミットの前（作業ツリーに未コミットの変更がある状態）で作ったので、正式な照合には使わない。ただし、値の見当には使える。
  - D2：スクリプトの新しいコメントの続きの2行は、行の頭が空白で、その後に `%` が来る。「`%` で始まらない行」を数えるときは、行の頭の空白を除いてから判定してほしい。
  - D3：`docs/rules/figures.md` では、語彙表と並び順の文のほかに、「条件の書き方」の例外の文も直した（3章）。
  - D1：`docs/rules/writing.md` が差分に出るのは、master から取り込んだ変更のためである（4.3）。
- 作ったデータの場所：`temp/35-impl/`（git管理外。消さずに残す）。`experiments/`・`results/` には何も作っていない。
- 共有の MATLAB の状態：確認のために、このセッションで `src/` を `addpath` した（保存はしていない）。作業フォルダはプロジェクトのルートに戻した。

## 6. 未決事項・仮定

- 仮定
  - `docs/rules/figures.md` の「条件の書き方」の文を直すのは、ユーザーが承認した語の意味（plan-2.md 4.3）を書き写すだけなので、承認の範囲に入るとみなした。メインまたはユーザーが不要と判断すれば、その1文は元に戻せる（語彙表とテストには影響しない）。
- 未決事項：無い。
- 気づいた点（このissueでは直していない）
  - `docs/rules/figures.md` の「条件」の並び順の文（画像 → 溝底の判定 → 溝底区間の幅 → 抽出法 → 溝の選び方 → 周数）には、もとから分類「音源」が入っていない。語彙表では「溝の選び方」と「周数」の間にある。計画の範囲外なので変えていない。
