# プログラムの書き方

Claude（メインセッション・サブエージェントとも）がMATLABのコードを書くときのルール。既存コードの慣習を明文化したもの。迷ったら、近くの既存コード（例: [`src/extractGrooveShape.m`](../../src/extractGrooveShape.m)）に合わせる。

## 命名

- 関数名は必要以上に長くしない。
- 変数名は簡潔で、意味がよく伝わるものにする。
- 新しく書くコードの変数・関数はcamelCase、定数は大文字のスネークケース（`D_THRESH`、`TOTAL_SEGMENTS`）。
- 既存の名前（`pks_cnt` など）は、リファクタリングのタスク以外では改名しない。

## 構造

- `src/` のクラスは値クラスで、継承はしない。変換するメソッドは変更したコピーを返す。呼び出し側では必ず代入し直す（`obj = obj.setDiffTF(D_THRESH)`）。
- コンストラクタは引数なしでも呼べるようにする（`allImg(N,1) = ImageData()` のような配列の事前確保のため）。
- 大きなデータ（`DarknessMap.dMat`、高解像度化後は最大で約2GB）はコピーしない。`GrooveExtractor` のように、使うたびに引数で渡す。
- `src/` には再利用する処理を置き、`scripts/` には実行の手順とパラメータを置く。

## 引数

- `arguments` ブロックで、型・サイズ・値を検証する。
- name-value引数は `opts.Name` の形にし、既定値を書く。既定値が無い場合は、必須であることがコメントから分かるようにする。

## エラーと警告

- `error`・`warning` には識別子を付ける。形は `"<関数名>:<理由>"`（例: `findGrooveCenter:noPeaksFound`、`saveCycleResult:fileExists`）。理由はcamelCaseで短く書く。
- テストでは、`verifyError`・`verifyWarning` でこの識別子を確かめる。

## コメント

- 関数の先頭に日本語で、何をするかと、なぜそうするかを書く。
- 量は既存コードと同じくらいにする。コードを読めば分かることは書かない。

## パスと座標

- パスは `currentProject().RootFolder` を基準に作る。絶対パスを直接書かない。
- 高解像度化（`dResample`/`dInterp`）した後の行インデックスは、`(idx - 1) / scaleFactor.row + 1` で元の画像の座標に戻す。新しい検出方法を作るときも同じように戻す。

## スクリプト

既存のスクリプト（例: [`scripts/pkCentroid_1cycle.m`](../../scripts/pkCentroid_1cycle.m)）の書き方に合わせる。

- 冒頭のコメントに、ファイル名、何をするか、作成日を書く。
- `setDefaultIntrpr();` と `proj = currentProject();` から始める。
- パラメータは冒頭にまとめる。名前は大文字のスネークケースにし、行末に意味と単位をコメントで書く。
- 実行日 `date`、出力先（`mkdirFromDate`・`experimentDir`）、以前の結果を再現するためのパス（`PREV_RESULT_PATH`）も冒頭に置き、実行する人が書き換える場所を1か所にまとめる。
- 繰り返し使う処理や、テストで確かめたい処理は `src/` の関数にする。スクリプトには手順とパラメータだけを置く。
- 出力の上書きに注意する（[`data.md`](data.md) の「出力の上書き」）。

## テスト

- `test/unit/<名前>Test.m` に、`matlab.unittest` のクラスとして書く。受け入れテスト（`<名前>AcceptanceTest.m`）の扱いは [`evaluation.md`](evaluation.md) を参照。
- 合成データを使い、実画像や `data/`・`experiments/` は読まない。
- `TestClassSetup` で、`PathFixture` を使って `src/` をパスに追加する。
- 図は `figure('Visible','off')` で作り、`addTeardown` で閉じる。
- ファイルを出力するテストは、`TemporaryFolderFixture` の一時フォルダに書く。
- CI（GitHub Actions、Linux・R2024b）でも動くように書く。ファイル名と呼び出しの大文字・小文字を一致させ、Windows固有のパスや関数を使わない。
- Signal Processing Toolbox 以外のツールボックスをテストで使うときは、[`.github/workflows/matlab-tests.yml`](../../.github/workflows/matlab-tests.yml) の `products` に足す。

## 確認

- 書いた・変えた `.m` ファイルは、`checkcode`（`mcp__matlab__check_matlab_code`）で警告が出ないことを確かめる。
- `cd test; results = runAllTests;` がすべて通ることを確かめる。
- PRでは、CI（MATLAB tests）が通っていることを確かめる。

## ドキュメント

`README.md` は処理の流れ・`src/`・`scripts/` の説明の一次情報源なので、コードと一緒に更新する。

- `src/` に関数・クラスを足したら、READMEの「`src/` の主なクラス・関数」に追記する。
- `scripts/` にスクリプトを足したら、READMEの「`scripts/` の主なスクリプト」に追記する。
- 処理の流れや保存形式を変えたら、READMEの該当する節（「処理の流れ」「1周分の実験結果の保存」など）も直す。
- `CLAUDE.md` の「Architecture notes」がクラス構成や関数のつながりに触れている場合は、そこも直す。

## 触らないもの

- `archive/` 配下（`src/archive/`、`scripts/archive/`、`test/archive/`）は、明示的に頼まれない限り触らない。
