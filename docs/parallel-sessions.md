# 並行セッションのルール

複数の Claude Code セッションを git worktree で並行して動かすときのルール。たとえば、あるセッションで issue を解き、別のセッションで文書を整える。目的は、マージのときの衝突を、編集する前に防ぐことである。

作業セッションを始める手順は skill [`start-work-session`](../.claude/skills/start-work-session/SKILL.md)（`/start-work-session` で呼べる）に、状況の確認・マージの判断・片付けの手順は skill [`coordinate-sessions`](../.claude/skills/coordinate-sessions/SKILL.md) に書く。worktree の作り方と初期化は [`git-rules.md`](git-rules.md) の「worktreeでの並行作業」に書く。

## 言葉

- **司令塔**：master をチェックアウトしたメインのセッション。skill `start-work-session` で作業セッションを始め、skill `coordinate-sessions` で状況の確認とマージの判断をする。
- **作業セッション**：worktree の中で1つの作業をするセッション。
- **台帳**：メインのチェックアウトの `.claude/coordination/ledger.json`。どの作業セッションが、どのブランチ・worktree で、何の作業をし、どのファイルを変える予定かを記録する。git の管理外に置くので、台帳そのものは衝突しない。
- **共有ファイル**：多くの作業が変えるため、衝突しやすいファイル。一覧は [`hotspots.txt`](../.claude/skills/coordinate-sessions/hotspots.txt) にある。
- **ロック**：共有ファイルを、1つのブランチだけが変えられるようにする台帳の記録。
- **`coord`**：台帳を操作するコマンド `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/coordinate-sessions/scripts/coord.ps1` の略。

## 1つの作業セッションの範囲

- 1つの作業セッションには、worktree・ブランチ・テーマを1つずつ割り当てる。テーマは、issue 1つか、文書の整備1つにする。
- 作業セッションは、始めたらすぐに `coord register` で台帳に載る。そのとき、変える予定のファイルを宣言する。予定が増えたら、`coord register -Files` で足す。
- 作業が終わったら、作業セッションはコミットして `coord set-status -Status merge-ready` を実行し、司令塔に知らせる。
- メインのチェックアウトは master のままにする。master をチェックアウトするのは司令塔だけにする。

## 共有ファイル

- 並行して作業しているあいだ、共有ファイルを変えられるのは、そのロックを持つブランチだけである。ロックは `coord lock -Paths <パス>` で取る。別のブランチが持っていれば断られる。
- 共有ファイルを変える前に、Edit・Write・NotebookEdit のフック（`lockHook.ps1`）がロックを確かめる。次のときは、編集を止める。
  - 別のブランチがロックしているとき。
  - ほかに作業中のセッションが台帳にあり、自分がロックを持っていないとき。台帳に自分しかいないときは、共有ファイルでも止めない。並行作業をしていないときに手間を増やさないためである。
- ロックは、1つのファイルか、狭いパターン（`docs/rules/figures.md`、`src/trackGroove.m`）で取る。`src/*` のような広いパターンは、ほかのセッションを長く止めるので使わない。
- 共有ファイルへの変更は小さくし、作業の終わりにまとめて行う。ロックを持つ時間を短くするためである。
- 共有ファイルを決める考え方は次のとおりである。
  - 多くの作業が書き足すファイル（`CLAUDE.md`、`README.md`、`docs/rules/*`、`docs/issues/README.md` など）。git の履歴でよく変わっているもの。
  - 全体の動きを決める設定（`.claude/settings.json`、`.claude/agents/*`、`.claude/skills/*`、`.githooks/*`、`.github/*`）。
  - MATLAB プロジェクトの定義（`Research.prj`、`resources/project/*`）と、多くのスクリプトが使う `src/`。
  - 進捗ログ `docs/progress/` は、毎日3時のタスクが master にだけ書くので、共有ファイルにしない。作業セッションは `docs/progress/` を変えない。

## マージの順番

- マージは1本ずつ行う。マージはユーザーが行い、Claude はしない（[`git-rules.md`](git-rules.md)）。
- 司令塔は、`coord check-merge` で次の3つを確かめてから、ユーザーに「マージしてよい」と伝える。CI の結果も別に確かめる。
  - worktree に未コミットの変更が無い。
  - master の最新を取り込んでいる。
  - ほかの作業中のブランチと、同じファイルを変えていない。
- 2つのブランチが同じファイルを変えているときは、次の順で先にマージするほうを決める。
  - (a) 共有ファイルのロックを持っているほうを先にする。
  - (b) 変更が小さいほうを先にする。後のブランチが取り込む量を減らすためである。
- マージの後、ほかの作業中のブランチは master を merge し、テストをやり直す。rebase はしない（[`git-rules.md`](git-rules.md) の「ブランチ運用」）。

## MATLAB

- MATLAB は、セッションごとに別々に起動する。MCP サーバーの設定 `--matlab-session-mode=auto` は、共有されている MATLAB があればそれにつなぎ、無ければ新しく起動する。いまの MATLAB は共有の設定をしていないので、セッションごとに別の MATLAB が立つ（2026-11-26 に確かめた）。
  - 変数、カレントフォルダ、開いているプロジェクトは、セッションのあいだで共有されない。
  - 同時に計算を流しても、互いに待たされない。
  - worktree のセッションは、その worktree の `Research.prj` を開いて `scripts/` を実行してよい。ほかのセッションには影響しない。
- 同じセッションの中のサブエージェントは、そのセッションの MATLAB を共有する。サブエージェントを並行して動かすときは、同時に MATLAB を使わせない。
- MATLAB の設定（`matlab.engine.shareEngine` など）で MATLAB を共有にしない。共有にすると、すべてのセッションが1つの MATLAB につながる。
- MATLAB は1つあたり約 1.8 GB のメモリを使う。
- `ginput` でクリックを待つスクリプトを実行するのは、一度に1つのセッションだけにする。ユーザーが、どの MATLAB の画面をクリックすればよいか迷わないためである。

## 共有されるデータ

- `data/`・`experiments/` は、すべての worktree でメインと同じものを指す（ジャンクション）。新しいファイルを足すのはよいが、上書きと削除はしない（[`rules/data.md`](rules/data.md)）。
- `results/` は worktree ごとに別である。残したい出力は、マージの前にメインへ移す。

## 限界

- フックが止めるのは、Claude の Edit・Write・NotebookEdit だけである。Bash・PowerShell のコマンドでファイルを書き換えると止められない。作業セッションは、共有ファイルをコマンドで書き換えない。
- 宣言していないファイルの変更は止めない。`coord status` が「宣言外」として見つけ、司令塔が報告する。
- フックは `.claude/settings.json` にあるので、この設定を取り込む前に作った worktree では働かない。
