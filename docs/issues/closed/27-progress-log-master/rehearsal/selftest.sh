#!/usr/bin/env bash
# selftest.sh - 予行の仕組みの自己確認（claude -p を使わない。LLM の使用量はかからない）
#
# 使い方: bash selftest.sh [--keep]
#   1. すべての場面を回 0 で準備し、場面が前提にする gitの事実を確かめる（例: S11b の last_commit は祖先だが鎖の上に無い）。
#   2. 判定（check.sh）が、正しい動きを通し、誤った動きを落とすことを、手で再現した動きで確かめる。
#        S13-90: 何もしない（正しい）              → すべて OK
#        S2-90 : 計画どおりに master へコミットして戻る（正しい） → すべて OK
#        S2-91 : 作業ブランチにコミットする（今のタスクの動き）    → C2・C3 が NG
#        S7-91 : -- docs/progress/ を付けずにコミットする          → C3p・C5 が NG
#        S3a-91: 未コミットの変更があるのに切り替えて戻る           → C9 が NG
#   最後に、作った砂場を消す（--keep で残す）。消すのは、この自己確認が作った回（0・90・91）だけ。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
KEEP=0; [ "${1:-}" = --keep ] && KEEP=1

fails=0
expect() { # expect <説明> <コマンド...>
  local d=$1; shift
  if "$@"; then echo "  ok   $d"; else echo "  FAIL $d"; fails=$((fails + 1)); fi
}
created=()
prep() { # prep <場面> <回>
  mkdir -p "$REH_ROOT"
  if ! bash "$REH_DIR/setup.sh" "$1" "$2" > "$REH_ROOT/selftest-$1-$2.log" 2>&1; then
    cat "$REH_ROOT/selftest-$1-$2.log"; die "準備に失敗した: $1-$2"
  fi
  created+=("$1-$2")
  init_paths "$1" "$2"
  # shellcheck disable=SC1091
  source "$RUNDIR/scene.env"
}
lc_of() { sbgit show master:docs/progress/.state.json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).last_commit))'; }
first_line_parent() { sbgit log "$1..master" --first-parent --reverse --format=%P | head -1 | cut -d' ' -f1; }

echo "== 1. 場面の準備と、前提の事実"
for s in S1 S2 S3a S3b S4 S5 S6 S7 S8 S9 S10 S11 S11b S12 S12b S13 S14 S15 S16; do
  prep "$s" 0
  echo "-- $s: $DESC"
  head=$(sbgit symbolic-ref -q --short HEAD || echo detached)
  expect "HEAD が $EXP_HEAD" test "$head" = "$EXP_HEAD"
  lc=$(lc_of)
  case "$s" in
    S11)
      expect "last_commit は master の祖先でない" test "$(sbgit merge-base "$lc" master)" != "$lc" ;;
    S11b)
      expect "last_commit は master の祖先" test "$(sbgit merge-base "$lc" master)" = "$lc"
      expect "最初の行の第1親は last_commit でない（鎖の上に無い）" test "$(first_line_parent "$lc")" != "$lc" ;;
    *)
      expect "last_commit は master の祖先" test "$(sbgit merge-base "$lc" master)" = "$lc"
      expect "最初の行の第1親が last_commit（鎖の上）" test "$(first_line_parent "$lc")" = "$lc" ;;
  esac
  nl=$(sbgit log "$lc..master" --first-parent --format=%s | wc -l | tr -d ' ')
  nown=$(sbgit log "$lc..master" --first-parent --format=%s | grep -c -e '^進捗ログ自動更新（' -e '^進捗期間を区切り、新しい期間ファイルを開始（' || true)
  case "$s" in
    S13|S16) expect "新しいコミットはタスク自身のものだけ（$nl 件）" test "$nl" = "$nown" ;;
    S9)      expect "first-parent の新しいコミットが3件（T、PRのmerge、古い日付）" test "$nl" = 3
             m=$(sbgit log "$lc..master" --first-parent --merges --format=%H)
             expect "PR のmergeの中身が3件" test "$(sbgit rev-list --count "$m^1..$m^2")" = 3
             expect "最後のコミットの Author Date が TODAY-4" test "$(sbgit log -1 --date=short --format=%ad master)" = "$(dplus -4)" ;;
    S15)     m=$(sbgit log "$lc..master" --first-parent --merges --format=%H)
             expect "取り込みのmergeの件名" test "$(sbgit log -1 --format=%s "$m")" = "Merge branch 'master' of https://github.com/MiwaHiroki/myResearch"
             expect "第2親の側に PR のmergeが1件と中身が2件" test "$(sbgit rev-list --count "$m^1..$m^2")" = 3 ;;
    S11|S11b) ;;
    *)       expect "載せるコミットがある（$nl 件中 タスク自身 $nown 件）" test "$nl" -gt "$nown" ;;
  esac
  case "$s" in
    S3a) expect "未ステージの変更がある" test -n "$(sbgit diff --name-only)" ;;
    S3b) expect "ステージ済みの変更がある" test -n "$(sbgit diff --cached --name-only)" ;;
    S4)  expect "追跡されていない notes.txt" test "$(sbgit status --porcelain)" = "?? notes.txt" ;;
    S7)  expect "README.md がステージ済みで rehearsal-x.txt が未ステージ" test "$(sbgit status --porcelain | tr '\n' ';')" = "M  README.md; M rehearsal-x.txt;" ;;
    S12|S12b) expect "記録に claude/test" test "$(sbgit config --get progress-report.return-branch)" = claude/test ;;
    S6|S14)
      before=$(sbgit rev-parse HEAD); bstat=$(sbgit status --porcelain)
      expect "git switch master が失敗する" bash -c "! git -C '$SB' switch -q master 2>/dev/null"
      expect "失敗の後も HEAD と status が同じ" test "$(sbgit rev-parse HEAD)|$(sbgit status --porcelain)" = "$before|$bstat"
      expect "失敗の後も claude/test のまま" test "$(sbgit symbolic-ref -q --short HEAD)" = claude/test ;;
    S8|S16)
      sbgit show master:docs/progress/.state.json > "$RUNDIR/state-now.json"
      nrd=$(json_get "$RUNDIR/state-now.json" next_report_date); la=$(json_get "$RUNDIR/state-now.json" next_report_date_last_asked)
      if [ "$s" = S8 ]; then
        expect "next_report_date が TODAY-1、期間ファイルが $CF" test "$nrd|$(json_get "$RUNDIR/state-now.json" current_file)" = "$(dplus -1)|$CF"
      else
        expect "next_report_date が null で last_asked が TODAY-3" test "$nrd|$la" = "null|$(dplus -3)"
      fi ;;
  esac
  [ -z "$(sbgit status --porcelain -- docs/progress/)" ] || { echo "  FAIL docs/progress に変更が残っている"; fails=$((fails + 1)); }
done

# ---- 2. 判定の確かめ（手で再現した動き） ----
fake_result() { # fake_result <NOTIFY の文（空なら無し）>
  local txt="完了した。"
  [ -n "$1" ] && txt="$txt\\nNOTIFY: $1"
  {
    printf '{"type":"system","subtype":"init","cwd":"selftest","model":"selftest","permissionMode":"default","claude_code_version":"selftest","tools":[],"mcp_servers":[]}\n'
    printf '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"result":"%s","permission_denials":[]}\n' "$txt"
  } > "$RUNDIR/stream.jsonl"
  echo 0 > "$RUNDIR/exit-code.txt"
  node "$REH_DIR/parse-stream.js" "$RUNDIR/stream.jsonl" "$RUNDIR" > /dev/null
}
begin() { sb_snapshot "$RUNDIR/before"; real_snapshot "$RUNDIR/real-before-run.txt"; }
finish() { sb_snapshot "$RUNDIR/after"; real_snapshot "$RUNDIR/real-after-run.txt"; fake_result "$1"; bash "$REH_DIR/check.sh" "$SCENE" "$RUN" > "$RUNDIR/check-stdout.txt"; }
ng_items() { awk -F'\t' 'NR > 1 && $5 == "NG" {print $1}' "$RUNDIR/check.tsv" | paste -sd, -; }
# 計画どおりの動き（作業ブランチ → master へコミット → 戻る）。$1: コミットに付けるパス指定（"-- docs/progress/" か ""）
emulate_task() {
  local pathspec=$1 cur tip
  cur=$(sbgit symbolic-ref -q --short HEAD)
  if [ "$cur" != master ]; then sbgit config progress-report.return-branch "$cur"; sbgit switch -q master; fi
  tip=$(sbgit rev-parse master)
  printf '\n### %s\n- 機能Aの説明ファイルを追加（予行用）\n' "$TODAY" >> "$SB/docs/progress/$CF"
  sed -i "s/\"last_commit\": \"[0-9a-f]*\"/\"last_commit\": \"$tip\"/" "$SB/docs/progress/.state.json"
  sbgit add "docs/progress/$CF" docs/progress/.state.json
  # shellcheck disable=SC2086
  sbgit commit -q -m "進捗ログ自動更新（${TODAY}分）" -m "masterに直接コミット（チェックアウト中: $cur）。" $pathspec
  if [ "$cur" != master ]; then sbgit switch -q -; sbgit config --unset progress-report.return-branch; fi
}

echo "== 2. 判定の確かめ"
prep S13 90; begin; finish ""
expect "S13-90（何もしない）: NG なし（$(ng_items)）" test -z "$(ng_items)"
prep S2 90; begin; emulate_task "-- docs/progress/"; finish ""
expect "S2-90（計画どおり）: NG なし（$(ng_items)）" test -z "$(ng_items)"
expect "S2-90: C10a・C10b・C10c が参考OK" test "$(awk -F'\t' '$1 ~ /^C10[abc]$/ {print $5}' "$RUNDIR/check.tsv" | sort -u)" = "参考OK"
prep S2 91; begin
printf '\n### %s\n- 機能Aの説明ファイルを追加（予行用）\n' "$TODAY" >> "$SB/docs/progress/$CF"
sbgit add "docs/progress/$CF"; sbgit commit -q -m "進捗ログ自動更新（${TODAY}分）" -- docs/progress/
finish ""
expect "S2-91（作業ブランチにコミット）: C2・C3 が NG（$(ng_items)）" bash -c "[[ ',$(ng_items),' == *,C2,* && ',$(ng_items),' == *,C3,* ]]"
prep S7 91; begin; emulate_task ""; finish ""
expect "S7-91（パス指定なしのコミット）: C3p・C5 が NG（$(ng_items)）" bash -c "[[ ',$(ng_items),' == *,C3p,* && ',$(ng_items),' == *,C5,* ]]"
prep S3a 91; begin
sbgit switch -q master; sbgit switch -q -     # 未ステージの変更は持ち越される（gitは止めない）
finish "進捗ログ自動更新: 未コミットの変更があるため、今回は見送りました（チェックアウト中: claude/test）。"
expect "S3a-91（変更があるのに切り替える）: C9 が NG（$(ng_items)）" bash -c "[[ ',$(ng_items),' == *,C9,* ]]"

if [ "$KEEP" = 0 ]; then
  for c in "${created[@]}"; do
    case "$c" in *-0|*-90|*-91) ;; *) continue ;; esac
    if [ -d "$REH_ROOT/$c.wt" ]; then git -C "$REH_ROOT/$c" worktree remove --force "$REH_ROOT/$c.wt" 2>/dev/null || rm -rf "$REH_ROOT/$c.wt"; fi
    rm -rf "${REH_ROOT:?}/$c" "${REH_ROOT:?}/$c.run" "${REH_ROOT:?}/selftest-$c.log"
  done
  echo "自己確認の砂場を消した（${#created[@]} 個）"
fi
echo "== selftest: 失敗 $fails 件"
[ "$fails" = 0 ]
