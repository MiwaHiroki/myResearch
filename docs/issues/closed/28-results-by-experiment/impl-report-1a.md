- 段階: 実装（1回目の前半）
- 作成者: implementer
- 作成日: 2026-11-24
- 入力: issue #28（本文。コメントなし）、[`./README.md`](./README.md)（作業履歴の決定）、[`./plan.md`](./plan.md)（承認済み）、[`./criteria.md`](./criteria.md)（承認済み）、[`./mapping-draft.md`](./mapping-draft.md)、`test/unit/ResultLayoutAcceptanceTest.m`、`scripts/evaluation/resultsLayout/checkResultsLayout.m`、main の依頼文
- 状態: 下書き

# #28 実装の報告（1回目の前半）

## 言葉

- **前半・後半**：`plan.md` の「言葉」と同じ。前半は `plan.md` 5.1 の手順1〜11（関数・テスト・README の表）、後半は 5.2 の手順12〜20（スクリプト55本・文書・`.gitignore`・対応表の CSV）である。
- **承認A**：README の「`runInfo.json` の項目」の表と「実験名の一覧」を、スクリプトを書き換える前にユーザーが承認すること。
- **受け入れテスト**：評価担当が作った `test/unit/ResultLayoutAcceptanceTest.m`（42件）。

## 1. 結論

- `plan.md` 5.1 の手順1〜10 を終え、この報告（手順11）で止めた。後半（5.2）には手を付けていない。
- `cd test; results = runAllTests;` は 346 件すべて通った。内訳は、今までのテスト 258 件、受け入れテスト 42 件、今回足した unit テスト 46 件である。
  - 受け入れテストは 42 件すべて通った。後半に当たるもので通らないものは無い（前半で `scripts/migration/migrateResults.m` を作ったので、移行のテスト9件も通る）。
- 書いた・変えた `.m` 19 個は、どれも `checkcode` の警告が 0 件である。
- 承認A で見せる README の節は、「結果の置き場所と実行記録」（README.md の 289〜479 行）である。「実験名の一覧」は 317〜330 行、「`runInfo.json` の項目」の表は 393〜433 行、版の表は 472〜478 行にある。
- インターフェース（シグネチャ、引数、既定値、戻り値、エラー・警告の識別子）は `plan.md` 4.2 のとおりにした。計画と違う点は、細部の5つである（3章）。識別子を1つ足した（`migrateResults:moveFailed`）。
- `results/`・`experiments/`・`data/` には何も作らず、動かさず、消していない。`temp/` も使っていない（前半には実データでの確認が無い）。

## 2. 変更したファイル

| 区分 | パス | 要点 |
|---|---|---|
| 新規 | `src/gitState.m` | `saveCycleResult` のローカル関数を切り出した。3つ目の出力（ブランチ）を求めたときだけ `git rev-parse --abbrev-ref HEAD` を呼ぶ。git が無い場所では `""`・`false`・`""` を返す |
| 新規 | `src/collectMeta.m` | 同じく切り出した。フィールドの名前と順は切り出す前と同じ8つで、`IncludeBranch=true` のときだけ `gitBranch` を最後に足す |
| 新規 | `src/runConditions.m` | 冒頭の定数を `plan.md` 4.3 のグループ・キーの順の struct にまとめる。キーの順は引数の順によらない。一覧のキーは cell の行にする |
| 新規 | `src/resultDir.m` | 日付・実験名・説明を確かめ、`_<N>` を決め、`runInfo.json` を JSON にしてからフォルダを作って書く。ルートの下のパスを `/` 区切りの相対パスにする |
| 新規 | `src/figureDir.m` | 進捗報告用・スライド用・原稿用の置き場所を作って返す（末尾に区切り文字を付けない） |
| 新規 | `scripts/migration/migrateResults.m` | 対応表の CSV を読み、全部の行を先に確かめてから、試し（既定）か実行をする |
| 新規 | `test/unit/ResultDirTest.m`、`RunConditionsTest.m`、`CycleConditionsTest.m`、`FigureDirTest.m`、`CollectMetaTest.m`、`MigrateResultsTest.m` | unit テスト 46 件（4章） |
| 変更 | `src/cycleConditions.m` | 省略できる位置引数 `runCond` を足した。`runCond` にフィールドがあれば、そこから今の name-value の並びを作り、自分を呼び直して今と同じ組み立てを通す。`NumImages`・`NumSegments`・`PolyDegree`・`Rpm` の既定値を `arguments` からコードの中へ移した（今の呼び方の出力は変わらない） |
| 変更 | `src/saveCycleResult.m` | ローカル関数 `collectMeta`・`gitState` を消し、`src/` の関数を呼ぶ。説明の `results/<日付>/` を「図・音声の出力先」に直した |
| 変更（説明だけ） | `src/mkdirFromDate.m` | 「新しいコードでは `resultDir` を使う」と、残している理由を書いた |
| 変更（説明だけ） | `src/experimentDir.m`、`src/cycleResultPath.m`、`src/cycleResultFileName.m`、`src/saveFigure.m` | 使い方の例の日付を `"2026-0731"` の形にした。`saveFigure` の例を `resultDir` の戻り値にし、`experimentDir` の「関連」を `resultDir` にした |
| 変更 | `README.md` | 「`src/` の主なクラス・関数」に5つを足し、`mkdirFromDate`・`cycleConditions` の説明を直した（70〜77 行）。「`scripts/` の主なスクリプト」に `migration/migrateResults.m` を足した（102 行）。「結果の置き場所と実行記録」の節を新しく作った（289〜479 行） |

自分で決めた細部のうち、後の作業に影響するもの：

- `cycleConditions` の新しい呼び方では、`grooveSelection.manual` の4つのキー、`grooveSelection.histogram` の `bandTol`・`binWidth`、`segmentation.lMask`、`grooveBottom.dThresh`・`widthThresh` のどれかが無ければ `cycleConditions:missingArgument` で止める。
- `resultDir` の `meta.git` は、`collectMeta` の仕様のとおり、MATLAB プロジェクトのルート（開いていなければ今のフォルダ）で調べる。引数の `rootFolder` では調べない。スクリプトから呼ぶときは同じフォルダになる。
- `resultDir` は、`runInfo.json` を書けなかったときは、作ったばかりのフォルダを消してからエラーを出し直す。
- `migrateResults` は、エラーを全部の行について集め、最初のエラーの識別子で、すべての理由を並べたメッセージを出す。

## 3. 計画との違い

どれも、出力の数値と cycleResult の形には影響しない。

1. **`runConditions` は、高解像度化のパラメータを `kind` によらず、渡せば書く。**
   - `plan.md` 4.3 の表は、`p`・`q` を書く条件を「`kind` に `rsmplD` があるとき（必須）」、`queryStep`・`interpMethod` を「`kind` に `intpD` があるとき（必須）」としている。`kind` に無いのに渡したときのことは書かれていない。
   - 黙って捨てると、渡した値が記録に残らない。そのため、渡したら書くことにした。`kind` にあるときに必須なのは計画のとおりである。
   - README の表の「書く条件」の3つの欄には「ほかのときも、渡せば書く」を足した。計画の55本の書き換えでは、`kind` に無いパラメータを渡すスクリプトは無い。
   - 6章の未決事項 Q1 で、この扱いでよいかを尋ねる。
2. **`runConditions` は、`ReplayFrom=""` を渡さなかったのと同じに扱う。** 計画は「`ReplayFrom` が `""` のときは、`replayFrom` のキーを作らない」としている。そのうえで、`grooveSelection` のほかの引数が無ければ、グループも作らない。空のグループ（`"grooveSelection": {}`）を書かないためである。
3. **`migrateResults` に、計画に無い確かめ方と識別子を足した。**
   - `movefile`・`rmdir` が失敗したときの識別子を `migrateResults:moveFailed` にした。計画は「そこでエラーで止まる」とだけ書き、識別子を決めていない（`docs/rules/coding.md` は識別子を求める）。
   - 対応表の確かめ方を、計画より厳しくした。`source`・`destination` は、その行の `phase` の名前（`results/` か `experiments/`）で始まる相対パスに限り、`..` や絶対パスを `migrateResults:invalidMapping` にする。各行の列の数が見出しと違うときも同じエラーにする。`note` の列は省いてよい。`mapping-draft.md` の案の行は、すべてこの条件を満たす。
   - 前の行で移すことに決めたファイルやフォルダ（とその中）は、後の行では元に無いものとして扱う。同じファイルを2つの行で移そうとしないためである。`files` の行のパターンが重なったときは、CSV で先の行が取る。
   - `deleteEmpty` は、ファイルが残っていないことを確かめたうえで、空のサブフォルダごと消す（例：`results/0820/` の行だけでも、空の `bilateral/` ごと消える）。
   - パターン（`*` だけ）は、`dir` のワイルドカードを使わず、正規表現に直して大文字・小文字を区別せずに照らす。`(` `)` などはそのままの文字として扱う。Windows と Linux で同じ結果にするためで、`criteria.md` 2.2 の「移し先」の求め方と同じになる。
4. **README の節に、計画の3つの項目のほかの小節を足した。** 計画（5.1 の手順9）は「実験名の一覧」「実行フォルダの名前の決め方」「`runInfo.json` の項目」と版の表を挙げている。読み手が一度で使い方を分かるように、「言葉」「置き場所」「実験名の決め方」「スクリプトでの使い方」と、`runInfo.json` の例を足した。
   - 節は「1周分の実験結果の保存」と「基本的な使用方法」の間に置いた。
   - 「実験名の決め方」には、issue の規則と、Q6 の決定の1行（`plan.md` 5.1 の手順9のとおりの文）を書いた。
   - 「対応表」の小節は、後半（手順17）で足す。
   - `runInfo.json` の例は、`grooveHist_Ncycle.m` の定数で実際に `resultDir` を実行した出力と同じ値にした（`meta` を除く。一時フォルダで確かめた）。
5. **`resultDir` の説明から `mkdirFromDate` への言及を外した。** 評価の検索4（`criteria.md` 5章）で「要確認」の行を増やさないためである。

## 4. 確認の結果

### checkcode

書いた・変えた `.m` 19 個に `checkcode` をかけ、すべて警告 0 件だった（`mcp__matlab__check_matlab_code` でも、実装の8つが 0 件）。

- `src/`：`gitState.m`、`collectMeta.m`、`runConditions.m`、`resultDir.m`、`figureDir.m`（以上新規）、`saveCycleResult.m`、`cycleConditions.m`、`mkdirFromDate.m`、`experimentDir.m`、`cycleResultPath.m`、`cycleResultFileName.m`、`saveFigure.m`（以上変更）
- `scripts/migration/migrateResults.m`
- `test/unit/` の新しい6つ

### runAllTests

- 346 件すべて通った（失敗 0、未完了 0。約 51 秒）。
- 受け入れテスト 42 件の内訳は、`resultDir` 13、`runConditions` 8、`cycleConditions` 7、`figureDir` 2、`collectMeta`・`gitState`・`saveCycleResult` 3、`migrateResults` 9 で、すべて通った。
- 新しい unit テスト 46 件の内訳は、`ResultDirTest` 11、`RunConditionsTest` 8、`CycleConditionsTest` 12（今の呼び方と新しい呼び方の比較5件を含む）、`FigureDirTest` 3、`CollectMetaTest` 4、`MigrateResultsTest` 8 である。
- 実行の記録に出た警告は、`CycleResultTest` がわざと出す `saveCycleResult:segmentCount`（「allImg の要素数(2)が conditions.totalSegments(4)と異なります」）の1つだけだった。今回の変更の前からあるものである。
- 手順1の確認として、`saveCycleResult` を書き換えた直後に `CycleResultTest` を実行し、28 件すべて通った。

### そのほかの確認

- `src/mkdirFromDate.m`・`experimentDir.m`・`cycleResultPath.m`・`cycleResultFileName.m`・`saveFigure.m` の差分は、コメントの行だけである（`git diff` で、コメントでも空行でもない行の変更が 0 行。`criteria.md` の D2）。
- README の新しい節について、評価スクリプトの P6 と同じ探し方で確かめた。実験名8つと、評価スクリプトが探す `runInfo.json` のキー59個が、すべて節の中にあり、実験名の決め方の1行もある。「対応表」の節と、スクリプトと図とで階層の順が逆になることの記述は、後半で足すので、まだ無い。
- `results/`・`experiments/` の中に、評価基準の文書より新しいファイル・フォルダが無いことを確かめた。
- 実データでの動作確認は、`plan.md` 5.1 に無いので行っていない（5.2 の手順18で行う）。

## 5. 評価担当への申し送り

- 変えたファイルの範囲（P4）
  - `src/` は、追加が5つ（`resultDir`・`runConditions`・`figureDir`・`collectMeta`・`gitState`）、変更が7つ（`cycleConditions`・`saveCycleResult`・`mkdirFromDate`・`experimentDir`・`cycleResultPath`・`cycleResultFileName`・`saveFigure`）である。
  - `test/` は、`test/unit/*Test.m` の追加6つだけである。既存のテストと受け入れテストは変えていない。
  - `scripts/` は、`scripts/migration/migrateResults.m` の追加だけである。対応表の CSV は後半で作る。
- 古い書き方の検索（Q6）に当たる、今回足した行
  - README 74 行（`mkdirFromDate` の説明。「新しいコードでは `resultDir` を使う」と書いた）と `src/mkdirFromDate.m` の説明は、`criteria.md` 5章の「残ってよい」「許される場所」に当たる。
  - `test/unit/MigrateResultsTest.m` は、合成の古い名前（`results/1014/...` など）を使う。`criteria.md` 5章の (a) の許される場所に、この名前で挙がっている。
- `migrateResults` の動きで、試しの表を見るときに知っておくとよいこと（3章の3）
  - `files` の行のパターンが重なれば、CSV で先の行が取る。
  - `deleteEmpty` は空のサブフォルダごと消す。
  - 元も行き先も無い行は `missing` になり、警告を出す。
- データは作っていない。後半の手順18で、`temp/` のコピーで実データを確かめる。

## 6. 未決事項・仮定

### 未決事項

- **Q1 `runConditions` に、`kind` に無い高解像度化のパラメータを渡したときの扱い**（3章の1）
  - 背景：計画の表は、`p`・`q`（`queryStep`・`interpMethod`）を「`kind` に `rsmplD`（`intpD`）があるとき」に書くとし、それ以外のときを決めていない。今の実装は渡せば書き、README の表もそう直した。この表は承認A で見てもらうので、ここで決めたい。
  - (a) 渡せば書く（今の実装、推奨）。渡した値が記録から消えない。55本の書き換えでは、この場合は起きない。
  - (b) `kind` に無ければ書かない（計画の表の字面どおり）。渡した値が黙って記録から落ちる。
  - (c) `kind` に無ければエラーにする。誤りにすぐ気づけるが、新しい識別子（例 `runConditions:unusedArgument`）が要り、計画のインターフェースが変わる。
  - 推奨：(a)。実行記録の目的（どの条件で作ったかを後からたどれる）に、いちばん合うため。

### 仮定

- 仮定：`resultDir` の `meta.git` は、MATLAB プロジェクトのルートで調べてよい（`collectMeta` の仕様のまま。2章）。
- 仮定：README の節に足した小節（3章の4）は、承認A でまとめて見てもらう。

### 気づいた点

- 承認A では、表と実験名の一覧のほかに、足した小節（「言葉」「置き場所」「実験名の決め方」「スクリプトでの使い方」、`runInfo.json` の例）も見てもらうとよい。
- 前半を終えた時点では、README のほかの節（ディレクトリ構成、「1周分の実験結果の保存」の例、「基本的な使用方法」）と、スクリプト55本は、まだ古い置き場所（`mkdirFromDate`）のままである。後半（手順12〜16）で直す。前半だけを master にマージすると、README の新しい節と、スクリプトの動きが食い違う。
- `src/loadCycleResult.m` の説明の使い方の例に、古い形の日付（`"0731"`）が残っている。`plan.md` 4.5 の変えるファイルに入っておらず、変えると P4 の外になるので、変えていない。評価の検索（Q6）の式には当たらない。
- Linux（CI）では、環境変数 `COMPUTERNAME` が無いので、`meta.computerName` は `""` になる。切り出す前の `saveCycleResult` と同じ動きである。
- `git diff` で「LF will be replaced by CRLF」の警告が出るが、`core.autocrlf=true` による表示で、作業ツリーの改行（LF）は変えていない。
