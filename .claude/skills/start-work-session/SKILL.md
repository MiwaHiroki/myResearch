---
name: start-work-session
description: 作業を、git worktree の新しい作業セッション（デスクトップアプリのセッション）で始める手順。変える予定のファイルを見積もり、作業中のほかのセッションとの重なりを確かめてから、台帳への登録・ロック・終わり方の決まりを書いた指示文でセッションを始める。ユーザーが `/start-work-session <作業の説明>` と打ったときや、「この作業を別のセッションで」「並行で進めたい」と頼んだときに使う。複数の作業を箇条書きで渡されたら、1作業につき1セッションを始める。master をチェックアウトしているメインのセッション（司令塔）で使う。
---

# 作業セッションを始める

並行作業のルールは [`docs/parallel-sessions.md`](../../../docs/parallel-sessions.md) が正である。言葉（司令塔、作業セッション、台帳、共有ファイル、`coord`）は skill [`coordinate-sessions`](../coordinate-sessions/SKILL.md) の「言葉」と同じ意味で使う。始めた後の状況確認・マージの判断・片付けは、`coordinate-sessions` の手順で行う。

## 引数

`/start-work-session` の後に、作業の説明を書く。複数の作業は箇条書きで並べてよい。issue があれば番号（`#41` など）を添える。説明が無いときは、ユーザーに作業の内容を尋ねる。

## 手順

1. `git branch --show-current` を実行し、master にいることを確かめる。master でなければ、何もせずにユーザーに伝える。作業セッションを始めるのは司令塔だけだからである。
2. 作業ごとに、変える予定のファイルを見積もる。
   - (a) issue のときは、`gh issue view <番号>` の本文と、受け渡しフォルダ `docs/issues/<番号>-<slug>/` を読み、関係するファイルを挙げる。
   - (b) issue でないときは、説明から関係するファイルを `grep` などで探して挙げる。
   - 挙げたファイルのうち、共有ファイル（[`hotspots.txt`](../coordinate-sessions/hotspots.txt)）に当たるものに印を付ける。そのセッションがロックを取る必要があるからである。
3. `coord status` を実行し、重なりを確かめる。今回始める作業どうしの重なりも見る。
   - (a) 予定のファイルが、ほかのセッションの宣言・変更や、今回のほかの作業と重なるときは、後回しにするか範囲を分けるかをユーザーに尋ねる。答えを聞くまで、その作業のセッションは始めない。
   - (b) 重ならなくても、気をつける点があれば、始める前にユーザーに伝える。たとえば、外から見える操作（GitHub のラベルや issue を作る）、master にだけ追記され続けるファイル（`docs/progress/`）を材料にする作業、すでにある似たもの（意味の近いラベルなど）である。
   - (c) 重なりも気をつける点も無いときは、そのまま進める。
4. 作業ごとに、ブランチ名に使う短い英語の slug（`progress-slides-1208` など）を決める。
5. `mcp__ccd_session__start_session` で、作業ごとにセッションを始める。2つ以上始めるときは、先に `mcp__ccd_session__mark_chapter` で区切りを付ける。
   - 引数は `initiation: "user_asked"`、`use_worktree: true`、`context: "fresh"`、`branch_name: "claude/<slug>"` とする。
   - 指示文は、下の「指示文のひな型」の `<…>` を埋めて渡す。
6. ユーザーに、始めたセッションを表で報告する。列は、セッション（リンク）、ブランチ、宣言するファイル、共有ファイル、気をつける点とする。セッションが `register` を済ませたかは、次の `coord status` で確かめる（`coordinate-sessions` の「2. 状況を確かめる」）。

## 指示文のひな型

````markdown
# <作業のタイトル>

<作業の内容。issue なら番号と、受け渡しフォルダのパス。>

## 終わりの条件

<何ができたら終わりか。確かめ方も書く。>

## 並行作業の決まり

このセッションは worktree のブランチ `claude/<slug>` で動く。ほかのセッションも並行して動いているので、`docs/parallel-sessions.md` のルールに従う。下の `coord` は、`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/coordinate-sessions/scripts/coord.ps1` の略である。

1. 最初に、`coord register -Theme "<テーマ>" -Issue <番号> -Files "<パターン>,<パターン>"` を実行し、台帳に載る（issue が無いときは `-Issue` を省く）。
2. 共有ファイル（<共有ファイルの一覧。無ければ「今回は無い見込み」>）を変える前に、`coord lock -Paths "<パス>"` を実行する。断られたら変えずに、司令塔のセッションに相談する。共有ファイルは Bash・PowerShell のコマンドで書き換えない。
3. 宣言にないファイルを変える必要が出たら、`coord register -Files "<追加>"` で足す。
4. `docs/progress/` は変えない（毎日の進捗ログのタスクが master にだけ書くため）。
5. push・PR の作成はユーザーに尋ねてから行う。マージはユーザーが行う。
6. 作業が終わったら、コミットして `coord set-status -Status merge-ready` を実行し、司令塔のセッションに知らせる。

## 気をつける点

<手順3の (b) で挙げたこと。無ければこの節を消す。>
````
