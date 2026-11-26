- 段階: 続きのissueの案
- 作成者: main
- 作成日: 2026-11-25
- 入力: issue #28、[`./impl-report-1a.md`](./impl-report-1a.md)（6章の Q1）、[`./impl-report-1b.md`](./impl-report-1b.md)（6章の「気づいた点」）、[`./retrospective.md`](./retrospective.md)（4章の6）、[`./README.md`](./README.md)（作業履歴の決定）
- 状態: 下書き

# #28 から続くissueの案

#28 では、結果の保存先を `results/<実験名>/<YYYY-MMDD_説明>/` にし、実行フォルダごとに実行記録 `runInfo.json` を残すようにした。このファイルの案は、#28 では行わない作業で、issueを作るときの本文の材料にする。作業中に出た案は、仕上げまでこのファイルに書き足していく。

## 案A：`runConditions` に、使われない高解像度化のパラメータを渡したらエラーにする — 未作成

- ラベル: `refactor`（ユーザーが選ぶ）
- ゴール: `runConditions` に、`Upsampling` の種類に無い高解像度化のパラメータを渡すと、エラーで止まる。例えば、`Upsampling="origD"` なのに内挿の間隔 `QueryStep` を渡したときである。スクリプトの書き間違いに、実行したときすぐ気づける。
- 背景: #28 の実装の前半で、計画の表がこの場合の扱いを決めていないことが分かった（`impl-report-1a.md` 6章の Q1）。承認A（2026-11-25）で、ユーザーは #28 では (a)「渡せば書く」とし、(c)「エラーにする」を今後の実装の案として残すと決めた。(a) は、渡した値が実行記録から消えない。一方で、使われない値が記録に入るので、記録を読む人が、その値が実際に効いたと誤解するおそれがある。
- 未決事項の候補
  - エラーの識別子の名前（例：`runConditions:unusedArgument`）。
  - 高解像度化のほかのグループ（溝の選び方、デトレンドなど）にも、同じ確かめ方を広げるか。
  - 今ある `runInfo.json` に、使われない値が書かれていないかを確かめるか。
- 作るタイミング: #28 をマージした後。#28 で書き換えたスクリプト55本には、この場合は無いので、急がない。

## 案B：書き換えの範囲の外に残った、古い置き場所と危ない動きを直す — 未作成

- ラベル: `refactor`（ユーザーが選ぶ）
- ゴール: 次の4つが直り、スクリプトを実行しても `data/` に書き込まず、無いフォルダを読まない。
  - `scripts/evaluation/stylus/sound_from_stylus.m` は、`data/stylus_playback/`（27行）と `data/stylus playback/`（74行）に wav を書き出す。`data/` は生データの置き場所なので、実行すると生データのフォルダが変わる。
  - `scripts/pkCentroidAndLocalMax_resample_1cycle.m` は、`results\0615\` という無いフォルダの音声を読む。区切りが `\` なので、Linux では動かず、#28 の古い書き方の検索にも当たらなかった。
  - `src/loadCycleResult.m` の説明の使い方の例に、古い形の日付 `"0731"` が残っている。
  - 1周分のスクリプトのいくつかに、`% dir = "C:\Users\owner\...\data\"+date+"\";` という古い絶対パスのコメントが残っている。
- 背景: #28 の実装の後半で、実装担当が見つけた（`impl-report-1b.md` 6章の「気づいた点」、`impl-report-1a.md` の「気づいた点」）。どれも #28 の計画で変えるファイル・行の外だったので、変えていない。
- 未決事項の候補
  - `sound_from_stylus.m` の wav の出力先を、実行フォルダ（`results/stylus/<日付>_<説明>/`）にするか。`data/stylus_playback/` にある今の wav を、生データとして扱うか。
  - `pkCentroidAndLocalMax_resample_1cycle.m` が読む 0615 の音声は、どの実行の出力か。見つからなければ、スクリプトを `scripts/archive/` に移すか。
- 作るタイミング: #28 をマージした後。急がないが、`sound_from_stylus.m` を実行する前に直すほうがよい。
