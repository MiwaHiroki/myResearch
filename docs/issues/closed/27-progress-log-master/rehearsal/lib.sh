#!/usr/bin/env bash
# lib.sh - 予行（issue #27）のスクリプトが共通に使う変数と関数。source して使う。
#
# 安全のための約束（このファイルの関数はすべてこれを守る）
#   - gitの書き込みは、砂場（temp/rehearsal-27/<場面>-<回>/）の中だけで行う。必ず sbgit を通す。
#   - sbgit は、毎回「砂場が砂場自身の .git を持ち、remote が無い」ことを確かめてから git を呼ぶ。
#   - GIT_CEILING_DIRECTORIES を temp/rehearsal-27 にして、砂場の .git が無いときに
#     gitが上のフォルダ（worktree）のリポジトリを見つけてしまうことを防ぐ。
#   - 本物のリポジトリ（worktree と メインのチェックアウト）には、読み取りのコマンドだけを使う。

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[$(date +%T)] $*"; }

# ---- 場所 ----
REH_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WT=$(git -C "$REH_DIR" rev-parse --show-toplevel)                    # 例: C:/Users/.../worktrees/progress-log-master
MAIN_ROOT=$(dirname "$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)")  # メインのチェックアウト
REH_ROOT="$WT/temp/rehearsal-27"
INPUTS_DIR="$REH_ROOT/_inputs"
export GIT_CEILING_DIRECTORIES="$REH_ROOT"

# ---- 日付（plan.md 7.1: date +%F を基準にする） ----
TODAY=$(date +%F)
TZOFF=$(date +%z)
dplus() { date -d "$TODAY $1 days" +%F; }            # dplus -5 → TODAY-5（YYYY-MM-DD）
dadd()  { date -d "$1 $2 days" +%F; }                # dadd 2026-10-20 1 → 2026-10-21
mmdd()  { date -d "$1" +%m%d; }                      # 1022
md()    { date -d "$1" +%m-%d; }                     # 10-22
ymmdd() { date -d "$1" +%Y-%m%d; }                   # 2026-1022
# at <YYYY-MM-DD> <HH:MM:SS>: gitの日時。TODAY の日付は、未来にならないよう現在時刻にする
at() { if [ "$1" = "$TODAY" ]; then date +%FT%T%z; else echo "$1T$2$TZOFF"; fi; }

# ---- 砂場 ----
# init_paths <場面> <回>: SB（砂場）と RUNDIR（記録のフォルダ）を決める
init_paths() {
  SCENE=$1; RUN=$2
  [[ "$RUN" =~ ^[0-9]+$ ]] || die "回は数字で指定する: $RUN"
  SB="$REH_ROOT/$SCENE-$RUN"
  RUNDIR="$REH_ROOT/$SCENE-$RUN.run"
}

assert_sandbox() {
  case "$SB" in "$REH_ROOT"/?*) ;; *) die "砂場の場所が temp/rehearsal-27/ の下でない: $SB" ;; esac
  local gd
  gd=$(git -C "$SB" rev-parse --absolute-git-dir 2>/dev/null) || die "砂場がgitのリポジトリでない: $SB"
  [ "$gd" = "$SB/.git" ] || die "砂場のgitのフォルダが砂場の中にない: $gd"
  [ -z "$(git -C "$SB" remote)" ] || die "砂場に remote が残っている: $SB"
}
sbgit() { assert_sandbox; git -C "$SB" "$@"; }

# make_clone: worktree から砂場を clone し、origin を外す（plan.md 7.1）
make_clone() {
  [ -e "$SB" ] && die "砂場がすでにある: $SB（別の回の番号を使う）"
  [ -e "$RUNDIR" ] && die "記録のフォルダがすでにある: $RUNDIR"
  mkdir -p "$REH_ROOT" "$RUNDIR"
  real_snapshot "$RUNDIR/real-before-clone.txt"
  git clone -q --no-hardlinks --branch master "$WT" "$SB"
  git -C "$SB" remote remove origin
  assert_sandbox
  real_snapshot "$RUNDIR/real-after-clone.txt"
  if ! diff -q "$RUNDIR/real-before-clone.txt" "$RUNDIR/real-after-clone.txt" >/dev/null; then
    die "clone の前後で本物のリポジトリの状態が変わった（$RUNDIR/real-*.txt を見る）"
  fi
}

# sbcommit <author日時> <committer日時> <git commit の引数...>
sbcommit() {
  local ad=$1 cd=$2; shift 2
  GIT_AUTHOR_DATE="$ad" GIT_COMMITTER_DATE="$cd" sbgit commit -q "$@"
}

# ---- 本物のリポジトリの写し（読み取りのみ） ----
# real_snapshot <ファイル>: worktree の作業ツリー、共有のref、worktreeの一覧、記録のキー
real_snapshot() {
  {
    echo "## worktree: git status --porcelain"
    git -C "$WT" status --porcelain
    echo "## refs/heads（共有）"
    git -C "$WT" for-each-ref --format='%(refname) %(objectname)' refs/heads
    echo "## worktree list"
    git -C "$WT" worktree list --porcelain
    echo "## progress-report.return-branch（共有の .git/config）"
    git -C "$WT" config --get --default none progress-report.return-branch
  } > "$1"
}

# ---- 砂場の写し（実行の前後） ----
# sb_snapshot <フォルダ>
sb_snapshot() {
  local d=$1; mkdir -p "$d"
  ( set +e
    sbgit symbolic-ref -q --short HEAD > "$d/head-branch.txt" || echo "detached" > "$d/head-branch.txt"
    sbgit rev-parse HEAD > "$d/head-commit.txt"
    sbgit for-each-ref --format='%(refname) %(objectname)' > "$d/refs.txt"
    sbgit status --porcelain > "$d/status.txt"
    sbgit diff --cached --name-only > "$d/cached.txt"
    sbgit diff | git hash-object --stdin > "$d/diff-worktree.sha"
    sbgit diff --cached | git hash-object --stdin > "$d/diff-index.sha"
    : > "$d/untracked.sha"
    sbgit ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
      printf '%s %s\n' "$(git hash-object --no-filters "$SB/$f")" "$f" >> "$d/untracked.sha"
    done
    sbgit config --get --default none progress-report.return-branch > "$d/return-branch.txt"
    sbgit reflog HEAD --format='%gs' > "$d/reflog-head.txt"
    wc -l < "$d/reflog-head.txt" | tr -d ' ' > "$d/reflog-count.txt"
    { grep -c '^checkout:' "$d/reflog-head.txt" || true; } > "$d/reflog-checkout-count.txt"
    sbgit rev-parse master > "$d/master.txt"
    sbgit show master:docs/progress/.state.json > "$d/state.json"
    sbgit worktree list --porcelain > "$d/worktrees.txt"
  )
}

# ---- JSON（node で読む） ----
# json_get <ファイル> <キー>: トップレベルのキーの値を出す（null は "null"、読めなければ "(読めない)"）
json_get() {
  node -e '
    const fs = require("fs");
    let v;
    try {
      const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8").replace(/^\uFEFF/, ""));
      v = j[process.argv[2]];
      v = v === null || v === undefined ? "null" : String(v);
    } catch (e) {
      v = "(\u8AAD\u3081\u306A\u3044)";
    }
    process.stdout.write(v);
  ' "$1" "$2"
}

# to_win / to_posix: パスの書き方を変える（Git Bash の cygpath）
to_win()   { cygpath -w "$1"; }
to_posix() { cygpath -u "$1"; }

# ---- claude -p の実行 ----
# run_claude <プロンプトのファイル> <記録のフォルダ> <秒> [claude に足す引数...]
#   - カレントディレクトリは砂場。プロンプトは標準入力から渡す。
#   - --dangerously-skip-permissions・--allowedTools は付けない（許可は砂場の settings.local.json だけから来る）。
#   - --permission-prompts none: 承認が要る呼び出しは、待たずに拒否する（拒否は result の permission_denials に残る）。
#   - --no-session-persistence: ~/.claude/projects に会話の記録を残さない。
#   - --strict-mcp-config と空の --mcp-config: MCPサーバー（共有のMATLABなど）を起動しない。
#   - 親のセッション（デスクトップアプリ）の環境変数 CLAUDE* を外して、独立したセッションとして動かす。
run_claude() {
  local prompt=$1 out=$2 tmo=$3 rc=0
  shift 3
  assert_sandbox
  printf '{"mcpServers":{}}\n' > "$out/empty-mcp.json"
  date +%FT%T%z > "$out/claude-start.txt"
  (
    cd "$SB"
    for v in $(compgen -e); do case "$v" in CLAUDE*) unset "$v" ;; esac; done
    exec timeout "$tmo" claude -p --output-format stream-json --verbose \
      --permission-prompts none --no-session-persistence \
      --strict-mcp-config --mcp-config "$out/empty-mcp.json" \
      "$@" < "$prompt" > "$out/stream.jsonl" 2> "$out/stderr.txt"
  ) || rc=$?
  echo "$rc" > "$out/exit-code.txt"
  date +%FT%T%z > "$out/claude-end.txt"
  log "claude -p が終わった（終了コード $rc。124 は時間切れ）"
}
