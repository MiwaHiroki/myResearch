---
name: make-progress-slides
description: 進捗報告のスライドを Typst で作る・直す・PDF にするときに使う。報告のフォルダ（slides/progress/<YYYY-MMDD>/）の作り方、進捗ログと進捗報告用の図からの下書き、図のコピーと配置、強調の図形、過去のスライドのコピー、コンパイルと全ページの目視確認までの手順。
---

# 進捗報告のスライドを作る

ルールの中身は [`docs/rules/slides.md`](../../../docs/rules/slides.md) が正で、フォルダの構成・分担・Typst の書き方は [`docs/progress-slides.md`](../../../docs/progress-slides.md) にある。このskillは、それに沿ってスライドを作る手順だけを書く。ルールを書き写さない。

## 1. ルールと前回のスライドを読む

1. `docs/rules/slides.md` と `docs/progress-slides.md` を読む。前に読んでいても、文言の指針が足されていることがあるので読み直す。
2. `slides/progress/` の中で一番新しい回の `.typ` を読み、書き方と流れを合わせる。

## 2. 報告の日付を決める

1. 今回の報告日を、ユーザーの言葉から決める。分からなければ尋ねる。
2. 前回の報告日を、`docs/progress/.state.json` と `docs/progress/` の期間ファイルの名前から決める。
3. どの期間ファイルを材料にするかを決める。期間ファイルの最新は、常に `master` にある（作業ブランチの `docs/progress/` は古いことがある）。

## 3. 報告のフォルダを作る

1. `slides/progress/<YYYY-MMDD>/` を作る（`<YYYY-MMDD>` は今回の報告日）。
2. 本体を `<YYYYMMDD>.typ` という名前で作る。先頭で、テンプレートを読み込む。

   ```typst
   #import "../../template/progress.typ": *
   #show: progress-slides
   ```

3. 図を載せるなら `figures/` を、ユーザーが過去のスライドの画像を置くなら `copied/` を、音声や `.fig` を見せるなら `extras/` を作る。

## 4. 下書きを書く

材料は、進捗ログの期間ファイル、`results/figures/progress/` の図、関係する issue の受け渡しフォルダ（`docs/issues/`）である。スライドは、次の順に並べる。

1. 表紙：`#title-slide(date: "YYYY/MM/DD")`
2. 前回からの進捗のまとめ：タイトルは「前回の日付 → 今回の日付」。内容は箇条書きにする。
3. 詳細：実装した内容と考察を、図と説明で示す。

下書きを書くときは、次のことに気を付ける。

- 実装に関係しない事項（論文の共有、学会の申し込みなど）は、ユーザーが書く。Claude は、頼まれない限り書かない。
- 進捗ログには、開発の環境やルールの整備（CI、エージェント、文書）も載っている。研究の内容と関係しないものをスライドに入れるかは、ユーザーに尋ねる。
- 文言の指針が `docs/rules/slides.md` にあれば、それに従う。

## 5. 図を置く

1. 載せる図を、`figures/` にコピーする。元のファイル名を変えない（図の下に出るファイル名が、元の図を探す手がかりになるため）。
2. 図は `fig-at` と配置の型（`cell-left`・`cell-right`・`cell-full`・`cell-side`）で置く。
3. 強調の図形が要るときは、図の PNG を見て位置を割合で決め、`marks:` に書く。図と図の間の矢印は `#draw` で描く。図形の位置は仮のものとして、報告で伝える。

## 6. 過去のスライドを入れる

コピーするスライドは、ユーザーが決める。

- (a) ユーザーが `copied/` に画像を置いたときは、`#copied-slide(image("copied/<MMDD>_p<N>.png"))` で入れる。ファイル名が `<MMDD>_p<N>` の形でなければ、ユーザーに確かめる。
- (b) Typst で作った回のスライドを指定されたときは、その回の `.typ` から `#slide(...)` をコピーし、`copied-from: "MM/DD"` を足す。使っている図も、今回の `figures/` にコピーする。

## 7. PDF を作り、確かめる

1. リポジトリの直下で、PDF を作る。

   ```bash
   typst compile --root slides slides/progress/<YYYY-MMDD>/<YYYYMMDD>.typ
   ```

2. ページ数が、作ったスライドの数と同じかを確かめる。違えば、本文がはみ出したページがある。
3. すべてのページを PNG にして（PyMuPDF の `get_pixmap` など）、目視で確かめる。見る点は `docs/rules/slides.md` の「確かめること」にある。画像はスクラッチパッドに書き出し、報告のフォルダには置かない。

## 8. コミットと報告

1. `git branch --show-current` でブランチを確かめる。
2. 報告のフォルダ（`.typ`、PDF、`figures/`、`copied/`、`extras/`）をコミットする。push はユーザーに確かめてからにする。
3. 報告には、次のことを書く。
   - 作ったスライドの一覧（ページ番号とタイトル）
   - 仮の位置に置いた強調の図形
   - ユーザーに決めてもらうこと（載せるかどうか迷った項目、文言）
   - アップロードするファイル（報告のフォルダのうち `.typ` 以外）
