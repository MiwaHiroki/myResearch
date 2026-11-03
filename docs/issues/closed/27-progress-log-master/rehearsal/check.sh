#!/usr/bin/env bash
# check.sh - 1回の予行の結果を、自動の項目（R0・Rreal・C1〜C9）と C10 の補助で判定する
#
# 使い方: bash check.sh <場面> <回>
#   run.sh が最後に呼ぶ。記録（<場面>-<回>.run/）から何度でも計算し直せる（砂場は読むだけ）。
# 書くもの: check.tsv（項目、種類、期待、実際、判定）、check.md（人が読む形）、
#           new-commits.txt、progress.diff、daily-before.md、daily-after.md、daily-added.md
# 種類: 前提（成り立たなければ、その回は無効。新しい回でやり直す）
#       品質（plan.md 7.1 の品質の基準 C4・C5・C7 と、評価担当が足した C3p。1つでも NG なら不合格）
#       計画（計画どおりかの確認）
#       参考（C10 の機械的な補助。C10 の合否は評価担当が目で見て決める）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENE=${1:?場面を指定する}
RUN=${2:?回を指定する}
init_paths "$SCENE" "$RUN"
[ -f "$RUNDIR/scene.env" ] || die "scene.env が無い: $RUNDIR"
[ -f "$RUNDIR/parsed.env" ] || die "parsed.env が無い（run.sh を実行していない）: $RUNDIR"
# shellcheck disable=SC1091
source "$RUNDIR/scene.env"
# shellcheck disable=SC1091
source "$RUNDIR/parsed.env"
assert_sandbox

BD="$RUNDIR/before"; AD="$RUNDIR/after"
OUT="$RUNDIR/check.tsv"
printf 'item\tclass\texpected\tactual\tverdict\n' > "$OUT"
add() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$OUT"; }
verdict() { if "$@"; then echo OK; else echo NG; fi; }
norm_set() { tr '+' '\n' <<< "$1" | sed '/^$/d' | sort -u | paste -sd+ -; }

# ---- R0: 実行が最後まで終わった ----
rc=$(cat "$RUNDIR/exit-code.txt")
v=$(verdict test "$rc" = 0 -a "$P_COMPLETED" = 1 -a "$P_SUBTYPE" = success -a "$P_IS_ERROR" = 0)
add R0 前提 "終了コード0、result が success" "終了コード$rc、completed=$P_COMPLETED、subtype=$P_SUBTYPE、is_error=$P_IS_ERROR" "$v"

# ---- Rreal: 本物のリポジトリが変わっていない ----
if diff -q "$RUNDIR/real-before-run.txt" "$RUNDIR/real-after-run.txt" > /dev/null; then
  add Rreal 前提 "worktreeの作業ツリー・共有のref・worktreeの一覧・記録のキーが同じ" "同じ" OK
else
  add Rreal 前提 "worktreeの作業ツリー・共有のref・worktreeの一覧・記録のキーが同じ" \
    "違う（$(diff "$RUNDIR/real-before-run.txt" "$RUNDIR/real-after-run.txt" | grep -c '^[<>]') 行。real-*-run.txt を見る）" NG
fi

# ---- C1: HEAD のブランチが前後で同じ ----
hb=$(cat "$BD/head-branch.txt"); ha=$(cat "$AD/head-branch.txt")
[ "$hb" = detached ] && hb="detached@$(cut -c1-7 "$BD/head-commit.txt")"
[ "$ha" = detached ] && ha="detached@$(cut -c1-7 "$AD/head-commit.txt")"
exph=$EXP_HEAD; [ "$EXP_HEAD" = detached ] && exph=$hb
add C1 計画 "前=後=$exph" "前=$hb、後=$ha" "$(verdict test "$hb" = "$ha" -a "$hb" = "$exph")"

# ---- C2: 変わった ref ----
changed=$(comm -3 <(sort "$BD/refs.txt") <(sort "$AD/refs.txt") | awk '{print $1}' | sort -u | paste -sd, -)
expref=""; [ "$EXP_NEW" -gt 0 ] && expref="refs/heads/master"
add C2 計画 "${expref:-(なし)}" "${changed:-(なし)}" "$(verdict test "$changed" = "$expref")"

# ---- C3: master に増えたコミット ----
Bm=$(cat "$BD/master.txt"); Am=$(cat "$AD/master.txt")
n=$(sbgit rev-list --count "$Bm..$Am")
anc=no; sbgit merge-base --is-ancestor "$Bm" "$Am" && anc=yes
merges=$(sbgit rev-list --min-parents=2 --count "$Bm..$Am")
outside=0; badsubj=0; bodyok=0
: > "$RUNDIR/new-commits.txt"
for c in $(sbgit rev-list --reverse "$Bm..$Am"); do
  while IFS=$'\t' read -r _st p1 p2; do
    for p in "$p1" "${p2:-}"; do
      [ -z "$p" ] && continue
      case "$p" in docs/progress/*) ;; *) outside=$((outside + 1)) ;; esac
    done
  done < <(sbgit diff-tree --no-commit-id -r -M --name-status "$c")
  subj=$(sbgit log -1 --format=%s "$c")
  case "$subj" in "進捗ログ自動更新（"*|"進捗期間を区切り、新しい期間ファイルを開始（"*) ;; *) badsubj=$((badsubj + 1)) ;; esac
  if [ -n "$EXP_BODY" ] && sbgit log -1 --format=%B "$c" | grep -qF "$EXP_BODY"; then bodyok=$((bodyok + 1)); fi
  { sbgit log -1 --date=iso --format='%H%n  author %ad / committer %cd%n  parents %P%n  件名: %s%n  本文:%n%b' "$c" | sed 's/^/  /'
    sbgit diff-tree --no-commit-id -r -M --name-status "$c" | sed 's/^/    /'; echo; } >> "$RUNDIR/new-commits.txt"
done
c3ok=true
[ "$n" = "$EXP_NEW" ] || c3ok=false
[ "$badsubj" = 0 ] || c3ok=false
[ -z "$EXP_BODY" ] || [ "$n" = 0 ] || [ "$bodyok" = "$n" ] || c3ok=false
c3act="増えた $n 件、件名の形が違う=$badsubj"
[ -n "$EXP_BODY" ] && c3act="$c3act、本文に「$EXP_BODY」=$bodyok/$n"
add C3 計画 "$EXP_NEW 件。件名はタスク自身の形${EXP_BODY:+、本文に「$EXP_BODY」}" "$c3act" "$(verdict $c3ok)"
# C3p: master を書き換えていない（前の先端の子孫）、merge を作っていない、docs/progress のほかを変えていない
c3pok=true
[ "$anc" = yes ] && [ "$merges" = 0 ] && [ "$outside" = 0 ] || c3pok=false
add C3p 品質 "前の先端の子孫、merge 0、docs/progress 以外の変更 0" \
  "前の先端の子孫=$anc、merge=$merges、docs/progress 以外の変更=$outside" "$(verdict $c3pok)"

# ---- C3b: 状態ファイルと期間ファイルの中身（S8 の期間の区切り、S8・S16 の最後に尋ねた日、S16 の件名） ----
if [ "$EXP_PERIOD" = 1 ] || [ -n "$EXP_LAST_ASKED" ]; then
  ok=true; act=()
  cfa=$(json_get "$AD/state.json" current_file); psa=$(json_get "$AD/state.json" period_start)
  nra=$(json_get "$AD/state.json" next_report_date); laa=$(json_get "$AD/state.json" next_report_date_last_asked)
  if [ "$EXP_PERIOD" = 1 ]; then
    has() { sbgit cat-file -e "$Am:docs/progress/$1" 2>/dev/null; }
    has "$RENAMED" && act+=("$RENAMED あり") || { act+=("$RENAMED 無し"); ok=false; }
    if [ "$CF" != "$RENAMED" ]; then has "$CF" && { act+=("$CF が残る"); ok=false; } || act+=("$CF 無し"); fi
    has "$NEWF" && act+=("$NEWF あり") || { act+=("$NEWF 無し"); ok=false; }
    t1=$(sbgit show "$Am:docs/progress/$RENAMED" 2>/dev/null | head -1 | tr -d '\r' || true)
    [ "$t1" = "# 進捗ログ（$PSTART 〜 $TODAY）" ] && act+=("見出しOK") || { act+=("見出し「$t1」"); ok=false; }
    [ "$cfa" = "$NEWF" ] && [ "$psa" = "$TODAY" ] && [ "$nra" = null ] || ok=false
    act+=("state: current_file=$cfa period_start=$psa next_report_date=$nra")
    last=$(sbgit log -1 --format=%s "$Am")
    case "$last" in "進捗期間を区切り、新しい期間ファイルを開始（$TODAY）"*) ;; *) ok=false; act+=("最後の件名「$last」") ;; esac
  fi
  if [ -n "$EXP_LAST_ASKED" ]; then
    [ "$laa" = "$EXP_LAST_ASKED" ] || ok=false
    act+=("last_asked=$laa")
  fi
  if [ "$SCENE" = S16 ]; then
    s16=$(sbgit log -1 --format=%s "$Am")
    case "$s16" in "進捗ログ自動更新（$TODAY、通知の記録）"*) ;; *) ok=false ;; esac
    act+=("件名「$s16」")
  fi
  exp3b="last_asked=${EXP_LAST_ASKED:-（確かめない）}"
  [ "$EXP_PERIOD" = 1 ] && exp3b="$RENAMED と $NEWF があり $CF が無い、見出し「# 進捗ログ（$PSTART 〜 $TODAY）」、current_file=$NEWF、period_start=$TODAY、next_report_date=null、$exp3b"
  [ "$SCENE" = S16 ] && exp3b="$exp3b、件名「進捗ログ自動更新（$TODAY、通知の記録）」"
  add C3b 計画 "$exp3b" "$(IFS='、'; echo "${act[*]}")" "$(verdict $ok)"
fi

# ---- C4: last_commit ----
if [ "$n" -gt 0 ]; then
  lc=$(json_get "$AD/state.json" last_commit)
  first=$(sbgit rev-list --reverse "$Bm..$Am" | head -1)
  fp=$(sbgit rev-parse "$first^1")
  onchain=$(sbgit rev-list --first-parent "$Am" | grep -cx "$lc" || true)
  add C4 品質 "last_commit = 最初の新しいコミットの第1親（${Bm:0:7}）、masterの first-parent の鎖の上" \
    "last_commit=${lc:0:7}、第1親=${fp:0:7}、鎖の上=$onchain" "$(verdict test "$lc" = "$Bm" -a "$fp" = "$Bm" -a "$onchain" = 1)"
else
  if cmp -s "$BD/state.json" "$AD/state.json"; then
    add C4 品質 "（コミットが無い）master の .state.json が変わらない" "変わらない" OK
  else
    add C4 品質 "（コミットが無い）master の .state.json が変わらない" "変わった" NG
  fi
fi

# ---- C5: 作業ツリーとインデックス ----
diffs=()
for f in status.txt cached.txt diff-worktree.sha diff-index.sha untracked.sha; do
  cmp -s "$BD/$f" "$AD/$f" || diffs+=("$f")
done
st=$(tr '\n' ';' < "$AD/status.txt")
if [ ${#diffs[@]} -eq 0 ]; then
  add C5 品質 "status・インデックス・差分・追跡されていないファイルの中身が同じ" "同じ（status: ${st:-空}）" OK
else
  add C5 品質 "status・インデックス・差分・追跡されていないファイルの中身が同じ" "違う: ${diffs[*]}（後の status: ${st:-空}）" NG
fi

# ---- C6: 中断の記録 ----
rba=$(cat "$AD/return-branch.txt")
add C6 計画 "$EXP_RB" "$rba" "$(verdict test "$rba" = "$EXP_RB")"

# ---- C7: PushNotification のほかに拒否が無い ----
den=$(awk -F'\t' 'NR > 1 && $1 !~ /PushNotification/ {print $1 ": " $2}' "$RUNDIR/denials.tsv" | head -5 | paste -sd'|' -)
add C7 品質 "0 件" "$P_NON_PUSH_DENIALS 件${den:+（$den）}" "$(verdict test "$P_NON_PUSH_DENIALS" = 0)"

# ---- C7n: 実行したコマンドの形が、狭いルール（既存のタスクのルール + 足すルール）に一致する ----
if [ -f "$RUNDIR/inputs/permission-rules-add.json" ]; then
  node "$REH_DIR/rules-check.js" run "$RUNDIR/parsed.json" "$RUNDIR/inputs/permission-rules-add.json" \
    "$REH_DIR/task-rules-existing.json" "$SB" "$RUNDIR/commands-vs-rules.tsv" >> "$OUT"
fi

# ---- C8: 通知 ----
en=$(norm_set "$EXP_NOTIFY"); an=$(norm_set "$P_NOTIFY_TYPES")
add C8 計画 "$en" "$an（$P_NOTIFY_COUNT 件、種類の分からない文 $P_NOTIFY_UNKNOWN 件。notify.txt）" \
  "$(verdict test "$en" = "$an" -a "$P_NOTIFY_UNKNOWN" = 0)"

# ---- C9: 切り替え（git reflog HEAD） ----
cb=$(cat "$BD/reflog-checkout-count.txt"); ca=$(cat "$AD/reflog-checkout-count.txt")
tb=$(cat "$BD/reflog-count.txt"); ta=$(cat "$AD/reflog-count.txt")
c9ok=true
[ $((ca - cb)) = "$EXP_SWITCH" ] || c9ok=false
[ "$EXP_REFLOG_SAME" = 1 ] && [ "$ta" != "$tb" ] && c9ok=false
c9exp="checkout の行 +$EXP_SWITCH"; [ "$EXP_REFLOG_SAME" = 1 ] && c9exp="$c9exp、全体の件数も変わらない"
add C9 計画 "$c9exp" "checkout の行 +$((ca - cb))、全体 +$((ta - tb))" "$(verdict $c9ok)"

# ---- C10 の補助（参考） ----
if [ "$n" -gt 0 ] || [ "$EXP_NEW" -gt 0 ]; then
  af=$CF; [ "$EXP_PERIOD" = 1 ] && af=$RENAMED
  sbgit diff -M "$Bm" "$Am" -- docs/progress/ > "$RUNDIR/progress.diff" || true
  if sbgit show "$Bm:docs/progress/$CF" > "$RUNDIR/daily-before.md" 2>/dev/null &&
     sbgit show "$Am:docs/progress/$af" > "$RUNDIR/daily-after.md" 2>/dev/null; then
    while IFS=$'\t' read -r item e a vv; do add "$item" 参考 "$e" "$a" "$vv"; done < <(
      node "$REH_DIR/c10.js" "$RUNDIR/daily-before.md" "$RUNDIR/daily-after.md" "$EXP_NEW_HEADINGS" "$EXP_TEXT" "$RUNDIR/daily-added.md")
  else
    add C10a 参考 "期間ファイル $af が実行の後にある" "読めない" 参考NG
  fi
fi

# ---- 表示と check.md ----
{
  echo "# 予行の判定 $SCENE-$RUN（$TODAY）"
  echo
  echo "- 場面: $DESC"
  echo "- 砂場: \`$SB\`"
  echo "- モデル: $P_MODEL、CLI: $P_CLI_VERSION、ツールの呼び出し: $P_NUM_CALLS 回（$P_TOOLS_USED）"
  echo
  echo "| 項目 | 種類 | 期待 | 実際 | 判定 |"
  echo "|---|---|---|---|---|"
  tail -n +2 "$OUT" | awk -F'\t' '{gsub(/\|/, "\\|"); print "| " $1 " | " $2 " | " $3 " | " $4 " | " $5 " |"}'
  echo
  echo "## 通知（notify.txt）"; echo; echo '```'; cat "$RUNDIR/notify.txt"; echo '```'
  echo; echo "## 拒否（denials.tsv）"; echo; echo '```'; cat "$RUNDIR/denials.tsv"; echo '```'
  echo; echo "## 新しいコミット（new-commits.txt）"; echo; echo '```'; cat "$RUNDIR/new-commits.txt"; echo '```'
  if [ -f "$RUNDIR/daily-added.md" ]; then
    echo; echo "## 日次ログに追記された部分（daily-added.md。C10 は目で見て判定する）"; echo; echo '```markdown'; cat "$RUNDIR/daily-added.md"; echo '```'
  fi
} > "$RUNDIR/check.md"

column -t -s $'\t' "$OUT" 2>/dev/null || cat "$OUT"
cnt() { awk -F'\t' -v c="$1" 'NR > 1 && $2 == c && $5 ~ /NG/' "$OUT" | wc -l | tr -d ' '; }
echo "== $SCENE-$RUN: 前提NG $(cnt 前提)、品質NG $(cnt 品質)、計画NG $(cnt 計画)、参考NG $(cnt 参考)（$RUNDIR/check.md）"
