# 生データの扱い

Claude（メインセッション・サブエージェントとも）がデータを扱うときのルール。

## 生データの範囲

`data/` と `experiments/` 配下の**すべてのファイル**を生データとして扱う（元の写真、cycleResult、wav、比較用の音など、種類を問わない）。

## 既存のファイル

- 読み取りのみ。**変更・上書き・削除・移動・改名はしない。**
- 必要に見えても、自分では行わない。ユーザーに質問する（[`communication.md`](communication.md)）。

## 新しいファイル

- `data/`・`experiments/` に新しいファイルを作るのは、タスク（issue）で指示された場合に限る。
- cycleResultは `saveCycleResult(..., Overwrite=false)` で保存する。同名のファイルがあってもエラーにはならず、`_2` などを付けた別名で保存して警告（`saveCycleResult:fileExists`）を出す。既存のファイルは消えないが、意図しない別名のファイルができていないかを確かめる。
- 図など、生データ以外の出力は `results/<日付>/`（`mkdirFromDate(rootFolder, "MMDD")`）に置く。

## worktree

worktreeの `data/`・`experiments/` は、メインのチェックアウトへのジャンクション（共有）。worktree側で消すと、メインからも消える。詳しくは [`../git-rules.md`](../git-rules.md) の「worktreeでの並行作業」を参照。

## git

生データはgitにコミットしない（`data/`・`experiments/` は `.gitignore` 済み）。

## 重いデータ

- `DarknessMap.dMat` は、高解像度化した後で最大で約2GBになる。
- `loadCycleResult` の `LoadDarknessValues` は、`dMat` が本当に必要なときだけ `true` にする。

## MATLABの実行

- MATLABは1つを全セッションで共有している。複数のセッションやエージェントから、同時にスクリプトを実行しない。
- `ginput` が要るスクリプトは、無人で実行しない。保存した選択（cycleResultの `grooveSelection`）を再現して `ginput` を使わずに済む場合だけ実行する。
