---
name: coordinate-sessions
description: 複数の Claude Code セッションを git worktree で並行して動かすときの司令塔の手順。全セッションの変更ファイルと重なりを確かめる、ブランチをマージしてよいかを判断する、終わった worktree を片付ける、のどれかをするときに使う。作業セッションを新しく始めるのは skill start-work-session。ユーザーが「今どのセッションが何をしているか」「このブランチをマージしてよいか」「worktree を片付けたい」と言ったときに使う。master をチェックアウトしているメインのセッションで使う。
---

# 並行セッションの司令塔

並行作業のルール（1セッションの範囲、共有ファイル、MATLAB、`data/` の扱い）は [`docs/parallel-sessions.md`](../../../docs/parallel-sessions.md) が正である。この skill には手順だけを書く。

## 言葉

- **司令塔**：この skill を使う、master をチェックアウトしたメインのセッション。
- **作業セッション**：worktree の中で1つの作業をするセッション。ブランチ名 `claude/<slug>` で呼ぶ。
- **台帳**：メインのチェックアウトの `.claude/coordination/ledger.json`。作業セッションのブランチ、テーマ、issue、変える予定のファイル、状態、ロックを記録する。git の管理外なので、台帳そのものが衝突することはない。
- **共有ファイル**：`hotspots.txt` に挙げたファイル。並行作業中は、ロックを持つセッションだけが変えられる。
- **`coord`**：`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/coordinate-sessions/scripts/coord.ps1` の略。どの worktree から実行しても同じ台帳を使う。`-Branch` を省くと、実行した場所のブランチを使う。

## 1. 作業を割り当てる

作業セッションを始める手順（変えるファイルの見積もり、重なりの確認、指示文のひな型）は、skill [`start-work-session`](../start-work-session/SKILL.md) に書く。ユーザーは `/start-work-session <作業の説明>` で呼べる。ユーザーが並行作業を頼んだときも、その手順に従う。

## 2. 状況を確かめる

1. `coord status` を実行する。各ブランチについて、状態、変更ファイルの数、ロックと、次の印の付いたファイルが出る。
   - `重なり:<ブランチ>`：別のブランチも同じファイルを変えている。
   - `宣言外`：台帳に宣言していないファイルを変えている。
   - `共有ファイル・ロックなし`：ロックを取らずに共有ファイルを変えている。
2. `mcp__ccd_session_mgmt__list_sessions` で、各セッションが動いているか、ユーザーの返事を待っているかを見る。
3. ユーザーには、ブランチ・テーマ・状態・問題のあるファイルを表にして報告する。印の付いたファイルには、どう直すか（範囲を分ける、片方を待つ、宣言を足す）の案を添える。
4. 作業セッションに直してもらうことがあれば、`SendMessage` でそのセッションに伝える。

## 3. マージしてよいかを判断する

1. 作業セッションが `merge-ready` になったら、`coord check-merge -Branch <ブランチ>` を実行する。
2. [`docs/git-rules.md`](../../../docs/git-rules.md) の「作業ブランチの取り込み方」で、PR にするか、ローカルの master にマージするかを決める。`git diff --stat master...<ブランチ>` で `.m` を変えていないかを見る。
3. PR にするときは、作業セッションに push と PR の作成を頼む（ユーザーの了承を得てから）。PR ができたら、`gh pr checks <番号>` で CI が通っていることを確かめる。
4. 判定に合わせて進める。
   - (a) すべて OK のときは、ユーザーに「マージしてよい」と伝え、取り込み方と差分の一覧を見せる。PR のマージはユーザーが行う。ローカルの master にマージするときは、ユーザーの指示を受けてから、司令塔が `git merge --no-ff <ブランチ>` を実行する。
   - (b) master の最新を取り込んでいないときは、作業セッションに、master を merge してテストをやり直すよう伝える（rebase はしない）。
   - (c) ほかのブランチと重なるときは、どちらを先にマージするかを決める。決め方は `docs/parallel-sessions.md` の「マージの順番」に従う。
5. マージが済んだら、`coord set-status -Branch <ブランチ> -Status merged` を実行する。これで、そのブランチのロックも外れる。ローカルの master にマージしたときは、master の push をユーザーに尋ねる。
6. ほかの作業中のセッションに、master を merge するよう `SendMessage` で伝える。とくに、マージしたブランチとファイルが重なっていたセッションには必ず伝える。

## 4. 片付ける

1. `coord status` と `git worktree list` で、状態が `merged` のブランチと、台帳に載っていない worktree を挙げる。
2. ユーザーに一覧を見せ、消してよいかを尋ねる。消すのは、ユーザーが「消してよい」と言ったものだけにする。
3. 消してよいものについて、次を行う。
   - (1) `git worktree remove <パス>` で worktree を消す。`data/`・`experiments/` はリンクが消えるだけで、中身は残る。
   - (2) `coord release -Branch <ブランチ>` で台帳から消す。
   - (3) ブランチを消すかは、別にユーザーに尋ねる。

## 困ったとき

- ロックを持ったセッションが止まった・消えたときは、ユーザーに確かめてから `coord unlock -Branch <ブランチ>` でロックを外す。
- フックが誤って編集を止めるときは、`coord status` で台帳を確かめる。台帳が壊れていたら、ユーザーに確かめてから `.claude/coordination/ledger.json` を直す。
