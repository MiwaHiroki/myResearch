#!/usr/bin/env bash
# setup.sh - 予行の場面を1つ準備する（砂場の clone を作り、gitの状態を場面どおりにする）
#
# 使い方: bash setup.sh <場面> [<回>]
#   例:   bash setup.sh S2 1
#   作るもの: temp/rehearsal-27/<場面>-<回>/       砂場（clone。origin は外す）
#             temp/rehearsal-27/<場面>-<回>.run/   記録（scene.env に準備の事実と期待値）
#   場面: S1 S2 S3a S3b S4 S5 S6 S7 S8 S9 S10 S11 S11b S12 S12b S13 S14 S15 S16
#   （S0 は s0-probe.sh。場面の中身は README.md と criteria.md の表を参照）
#
# 共通の土台（どの場面も同じ）
#   P  : clone した master の先端（本物の master の写し）
#   B1 : 「予行の準備：…」docs/progress を予行用の期間ファイルと .state.json に置き換える（last_commit = P）
#   T  : 「進捗ログ自動更新（<LASTH>分）」前回のタスク自身のコミットの代わり（last_commit = B1）
#   X1 : 「機能Aの説明ファイルを追加（予行用）」載せるコミット（TODAY の日付）
#   W1 : 作業ブランチ claude/test の作業のコミット
# 日付は date +%F（TODAY）を基準にする。準備と実行は同じ日に行う（run.sh が確かめる）。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENE=${1:?場面を指定する（例: S2）}
RUN=${2:-1}
case "$SCENE" in
  S1|S2|S3a|S3b|S4|S5|S6|S7|S8|S9|S10|S11|S11b|S12|S12b|S13|S14|S15|S16) ;;
  *) die "知らない場面: $SCENE" ;;
esac
init_paths "$SCENE" "$RUN"

# ---- 場面ごとの土台の値（既定） ----
PSTART=$(dplus -7)          # 期間の開始日
NRD=$(dplus 10)             # 次回予定日（未来 → 7b・7c に当たらない）
LAST_ASKED=$PSTART          # 次回予定日を最後に尋ねた日
LASTH=$(dplus -1)           # 日次ログの末尾の見出しの日付
case "$SCENE" in
  S8)  NRD=$(dplus -1) ;;                       # TODAY >= next_report_date → 期間の区切り（7b）
  S9)  LASTH=$(dplus -2) ;;
  S10) LASTH=$TODAY ;;
  S16) NRD=null; LAST_ASKED=$(dplus -3) ;;      # 3日たった → 通知の記録（7c）
esac

period_name() { # period_name <開始日> <次回予定日|null>
  if [ "$2" = null ]; then echo "$(ymmdd "$1")_MMDD.md"; else echo "$(ymmdd "$1")_$(mmdd "$2").md"; fi
}
write_period() { # write_period <パス> <開始日> <次回予定日|null>
  local title_end
  if [ "$3" = null ]; then title_end=""; else title_end="$3予定"; fi
  printf '# 進捗ログ（%s 〜 %s）\n\n## まとめ\n- 予行用の期間ファイル（issue #27 の予行のための架空の内容）\n\n## 日次ログ\n' \
    "$2" "$title_end" > "$1"
}
write_state() { # write_state <current_file> <period_start> <next_report_date|null> <last_commit> <last_asked|null>
  local q3 q5
  if [ "$3" = null ]; then q3=null; else q3="\"$3\""; fi
  if [ "$5" = null ]; then q5=null; else q5="\"$5\""; fi
  printf '{\n  "current_file": "%s",\n  "period_start": "%s",\n  "next_report_date": %s,\n  "last_commit": "%s",\n  "next_report_date_last_asked": %s\n}\n' \
    "$1" "$2" "$q3" "$4" "$q5" > "$SB/docs/progress/.state.json"
}

CF=$(period_name "$PSTART" "$NRD")
TASK_BODY="深夜バッチ（scheduled task: progress-report-daily）による自動commit。docs/git-rules.mdの自動commit例外規定に基づく。"
COAUTHOR="Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

commit_B1() {
  P=$(sbgit rev-parse HEAD)
  sbgit rm -q -r docs/progress
  mkdir -p "$SB/docs/progress"
  write_period "$SB/docs/progress/$CF" "$PSTART" "$NRD"
  write_state "$CF" "$PSTART" "$NRD" "$P" "$LAST_ASKED"
  printf '予行用のファイル（場面S7・S14で使う）\n' > "$SB/rehearsal-x.txt"
  sbgit add docs/progress rehearsal-x.txt
  sbcommit "$(at "$LASTH" 09:00:00)" "$(at "$LASTH" 09:00:00)" -m "予行の準備：進捗ログを予行用の内容に置き換える（issue #27）"
  B1=$(sbgit rev-parse HEAD)
}
commit_T() { # commit_T [<last_commit>]（既定は B1）
  local lc=${1:-$B1} d
  printf '\n### %s\n- 予行の準備として、進捗ログを予行用の内容に置き換えた\n' "$LASTH" >> "$SB/docs/progress/$CF"
  write_state "$CF" "$PSTART" "$NRD" "$lc" "$LAST_ASKED"
  sbgit add "docs/progress/$CF" docs/progress/.state.json
  d=$(dadd "$LASTH" 1); [[ "$d" > "$TODAY" ]] && d=$TODAY
  sbcommit "$(at "$d" 03:08:00)" "$(at "$d" 03:08:00)" -m "進捗ログ自動更新（${LASTH}分）" -m "$TASK_BODY" -m "$COAUTHOR"
  T=$(sbgit rev-parse HEAD)
}
commit_X1() {
  printf '機能Aの説明（予行用）\n' > "$SB/rehearsal-feature.txt"
  sbgit add rehearsal-feature.txt
  sbcommit "$(at "$TODAY" now)" "$(at "$TODAY" now)" -m "機能Aの説明ファイルを追加（予行用）"
  X1=$(sbgit rev-parse HEAD)
}
make_work_branch() { # master の今の先端から claude/test を作り、W1 を足して master に戻る
  sbgit switch -q -c claude/test
  printf '作業ブランチの変更（予行用）\n' > "$SB/rehearsal-work.txt"
  sbgit add rehearsal-work.txt
  sbcommit "$(at "$TODAY" now)" "$(at "$TODAY" now)" -m "作業ブランチで機能Bを作り始める（予行用）"
  W1=$(sbgit rev-parse HEAD)
  sbgit switch -q master
}
# feature_branch <ブランチ名> <日付...>: B1 から枝を作り、日付ごとに1コミットずつ足して master に戻る
feature_branch() {
  local br=$1; shift
  local i=0 d
  sbgit switch -q -c "$br" "$B1"
  for d in "$@"; do
    i=$((i + 1))
    printf '%s の変更 %d（予行用）\n' "$br" "$i" > "$SB/rehearsal-${br//\//-}-$i.txt"
    sbgit add "rehearsal-${br//\//-}-$i.txt"
    sbcommit "$(at "$d" 11:00:00)" "$(at "$d" 11:00:00)" -m "${br}の作業${i}（予行用）"
  done
  sbgit switch -q master
}

# ---- 期待値の既定（scene.env に書く） ----
EXP_HEAD=master        # 実行の前後のHEAD（master / claude/test / detached）
EXP_NEW=0              # masterに増えるコミットの数
EXP_SWITCH=0           # git reflog HEAD の checkout の行の増え方（0 = 切り替えない、2 = 行って戻る）
EXP_REFLOG_SAME=0      # 1 なら git reflog HEAD の件数が変わらない（何もしない場面）
EXP_NOTIFY=none        # 通知の種類（none / N1 / N2 / N3 / N4 / N5 / ASK。複数は + でつなぐ）
EXP_RB=none            # 実行の後の progress-report.return-branch
EXP_BODY=""            # 新しいコミットの本文に含まれるはずの文字列（チェックアウト中のブランチ）
EXP_NEW_HEADINGS=""    # 日次ログに増えるはずの見出しの日付（空白区切り。C10の補助）
EXP_TEXT=""            # 追記された行に含まれるはずの文字列（| 区切り。C10の補助）
EXP_PERIOD=0           # 1 なら期間の区切り（S8）を確かめる
EXP_LAST_ASKED=""      # 実行の後の next_report_date_last_asked（空なら確かめない）
DESC=""

make_clone
log "砂場を作った: $SB"

case "$SCENE" in
  S1)
    DESC="master、きれい、載せるコミットが1件"
    commit_B1; commit_T; commit_X1
    EXP_NEW=1; EXP_BODY=master; EXP_NEW_HEADINGS=$TODAY ;;
  S2|S4|S12b)
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_NEW=1; EXP_SWITCH=2; EXP_BODY=claude/test; EXP_NEW_HEADINGS=$TODAY
    case "$SCENE" in
      S2)   DESC="作業ブランチ claude/test、きれい、masterに載せるコミットが1件" ;;
      S4)   DESC="作業ブランチ、追跡されていないファイル notes.txt だけがある"
            printf '追跡されていないメモ（予行用）\n' > "$SB/notes.txt" ;;
      S12b) DESC="claude/test で、記録に claude/test が残っている、載せるコミットが1件"
            sbgit config progress-report.return-branch claude/test ;;
    esac ;;
  S3a|S3b)
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q claude/test
    printf '追跡されているファイルへの未コミットの変更（予行用）\n' >> "$SB/rehearsal-x.txt"
    if [ "$SCENE" = S3b ]; then
      sbgit add rehearsal-x.txt
      DESC="作業ブランチ、追跡されているファイルにステージ済みの変更"
    else
      DESC="作業ブランチ、追跡されているファイルに未ステージの変更"
    fi
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1; EXP_NOTIFY=N1 ;;
  S5)
    DESC="detached HEAD（claude/test の先端）、masterに載せるコミットが1件"
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q --detach claude/test
    EXP_HEAD=detached; EXP_REFLOG_SAME=1; EXP_NOTIFY=N1 ;;
  S6)
    DESC="作業ブランチ、きれい、masterを砂場の別のworktreeでチェックアウト中"
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q claude/test
    sbgit worktree add -q "$REH_ROOT/$SCENE-$RUN.wt" master
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1; EXP_NOTIFY=N1 ;;
  S7)
    DESC="master、README.md をステージ済み、rehearsal-x.txt を未ステージで変更、載せるコミットが1件"
    commit_B1; commit_T; commit_X1
    printf '\n予行用の変更（ステージ済み）\n' >> "$SB/README.md"
    sbgit add README.md
    printf '予行用の変更（未ステージ）\n' >> "$SB/rehearsal-x.txt"
    EXP_NEW=1; EXP_BODY=master; EXP_NEW_HEADINGS=$TODAY ;;
  S8)
    DESC="作業ブランチ、きれい、next_report_date（TODAY-1）<= TODAY、載せるコミットが1件"
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_NEW=2; EXP_SWITCH=2; EXP_NOTIFY=ASK; EXP_BODY=claude/test
    EXP_NEW_HEADINGS=$TODAY; EXP_PERIOD=1; EXP_LAST_ASKED=$TODAY ;;
  S9)
    DESC="master、過去の日付の3件をPRとしてTODAY-1に--no-ffマージ、その後にAuthor DateがTODAY-4のコミット、末尾の見出しはTODAY-2"
    commit_B1
    feature_branch claude/feat "$(dplus -5)" "$(dplus -4)" "$(dplus -3)"
    commit_T
    GIT_AUTHOR_DATE="$(at "$(dplus -1)" 12:00:00)" GIT_COMMITTER_DATE="$(at "$(dplus -1)" 12:00:00)" \
      sbgit merge -q --no-ff -m "Merge pull request #99 from MiwaHiroki/claude/feat" -m "予行用の機能（issue #99）" claude/feat
    sbgit branch -q -D claude/feat
    printf '古い日付のコミット（予行用）\n' > "$SB/rehearsal-old.txt"
    sbgit add rehearsal-old.txt
    sbcommit "$(at "$(dplus -4)" 16:00:00)" "$(at "$(dplus -1)" 13:00:00)" -m "古い日付のコミットを取り込む（予行用、cherry-pickの代わり）"
    EXP_NEW=1; EXP_BODY=master; EXP_NEW_HEADINGS=$(dplus -1)
    EXP_TEXT="PR #99|（$(md "$(dplus -5)")）|（$(md "$(dplus -4)")）|（$(md "$(dplus -3)")）|（$(md "$(dplus -4)")のコミット）" ;;
  S10)
    DESC="master、末尾の見出しがTODAY、TODAYの日付のコミットが1件"
    commit_B1; commit_T; commit_X1
    EXP_NEW=1; EXP_BODY=master; EXP_NEW_HEADINGS="" ;;
  S11)
    DESC="claude/test、last_commit が master に入っていない側（claude/test）のコミット"
    commit_B1
    sbgit switch -q -c claude/test
    printf '作業ブランチの変更（予行用）\n' > "$SB/rehearsal-work.txt"
    sbgit add rehearsal-work.txt
    sbcommit "$(at "$TODAY" now)" "$(at "$TODAY" now)" -m "作業ブランチで機能Bを作り始める（予行用）"
    W1=$(sbgit rev-parse HEAD)
    sbgit switch -q master
    commit_T "$W1"; commit_X1
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1; EXP_NOTIFY=N4 ;;
  S11b)
    DESC="claude/test、last_commit が master の祖先だが first-parent の鎖に無いコミット（マージされたブランチの先端）"
    commit_B1
    feature_branch claude/feat98 "$(dplus -4)" "$(dplus -3)"
    F2=$(sbgit rev-parse claude/feat98)
    GIT_AUTHOR_DATE="$(at "$(dplus -2)" 12:00:00)" GIT_COMMITTER_DATE="$(at "$(dplus -2)" 12:00:00)" \
      sbgit merge -q --no-ff -m "Merge pull request #98 from MiwaHiroki/claude/feat98" -m "予行用の機能（issue #98）" claude/feat98
    sbgit branch -q -D claude/feat98
    commit_T "$F2"; make_work_branch; commit_X1
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1; EXP_NOTIFY=N4 ;;
  S12)
    DESC="master、progress-report.return-branch に claude/test が残っている、載せるコミットが1件"
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit config progress-report.return-branch claude/test
    EXP_REFLOG_SAME=1; EXP_NOTIFY=N2; EXP_RB=claude/test ;;
  S13)
    DESC="作業ブランチ、きれい、masterの新しいコミットはタスク自身のコミットだけ、next_report_date は未来"
    commit_B1; commit_T; make_work_branch
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1 ;;
  S14)
    DESC="作業ブランチで rehearsal-x.txt を削除してコミットし、同じ名前の追跡されていないファイルを置く"
    commit_B1; commit_T; make_work_branch; commit_X1
    sbgit switch -q claude/test
    sbgit rm -q rehearsal-x.txt
    sbcommit "$(at "$TODAY" now)" "$(at "$TODAY" now)" -m "作業ブランチで rehearsal-x.txt を削除（予行用）"
    printf '同じ名前の、追跡されていないファイル（予行用）\n' > "$SB/rehearsal-x.txt"
    EXP_HEAD=claude/test; EXP_REFLOG_SAME=1; EXP_NOTIFY=N1 ;;
  S15)
    DESC="master、「Merge branch 'master' of https://github.com/…」の第2親の側に PR #97 のmergeがある"
    commit_B1
    feature_branch claude/x "$(dplus -3)" "$(dplus -2)"
    sbgit switch -q -c gh-master "$B1"
    GIT_AUTHOR_DATE="$(at "$(dplus -1)" 12:00:00)" GIT_COMMITTER_DATE="$(at "$(dplus -1)" 12:00:00)" \
      sbgit merge -q --no-ff -m "Merge pull request #97 from MiwaHiroki/claude/x" -m "予行用の機能（issue #97）" claude/x
    sbgit switch -q master
    commit_T
    GIT_AUTHOR_DATE="$(at "$TODAY" now)" GIT_COMMITTER_DATE="$(at "$TODAY" now)" \
      sbgit merge -q --no-ff -m "Merge branch 'master' of https://github.com/MiwaHiroki/myResearch" gh-master
    sbgit branch -q -D claude/x gh-master
    EXP_NEW=1; EXP_BODY=master; EXP_NEW_HEADINGS=$TODAY; EXP_TEXT="PR #97|GitHubのmasterを取り込み" ;;
  S16)
    DESC="作業ブランチ、きれい、next_report_date は null で最後に尋ねたのが3日前、載せるコミットは無い（7c: 通知の記録だけをコミット）"
    commit_B1; commit_T; make_work_branch
    sbgit switch -q claude/test
    EXP_HEAD=claude/test; EXP_NEW=1; EXP_SWITCH=2; EXP_NOTIFY=ASK; EXP_BODY=claude/test
    EXP_NEW_HEADINGS=""; EXP_LAST_ASKED=$TODAY; EXP_TEXT="" ;;
esac

# 期間の区切り（S8）で期待するファイル名
RENAMED=""; NEWF=""
if [ "$EXP_PERIOD" = 1 ]; then
  RENAMED="$(ymmdd "$PSTART")_$(mmdd "$TODAY").md"
  NEWF="$(ymmdd "$TODAY")_MMDD.md"
fi

# ---- scene.env（準備の事実と期待値。check.sh と run.sh が source する） ----
kv() { printf "%s='%s'\n" "$1" "${2//\'/\'\\\'\'}"; }
{
  kv SCENE "$SCENE"; kv RUN "$RUN"; kv TODAY "$TODAY"; kv SB "$SB"; kv RUNDIR "$RUNDIR"; kv SETUP_AT "$(date +%FT%T%z)"
  kv DESC "$DESC"; kv PSTART "$PSTART"; kv NRD "$NRD"; kv LASTH "$LASTH"; kv LAST_ASKED "$LAST_ASKED"; kv CF "$CF"
  kv P "${P:-}"; kv B1 "${B1:-}"; kv T "${T:-}"; kv X1 "${X1:-}"; kv W1 "${W1:-}"
  kv EXP_HEAD "$EXP_HEAD"; kv EXP_NEW "$EXP_NEW"; kv EXP_SWITCH "$EXP_SWITCH"; kv EXP_REFLOG_SAME "$EXP_REFLOG_SAME"
  kv EXP_NOTIFY "$EXP_NOTIFY"; kv EXP_RB "$EXP_RB"; kv EXP_BODY "$EXP_BODY"
  kv EXP_NEW_HEADINGS "$EXP_NEW_HEADINGS"; kv EXP_TEXT "$EXP_TEXT"; kv EXP_PERIOD "$EXP_PERIOD"
  kv EXP_LAST_ASKED "$EXP_LAST_ASKED"; kv RENAMED "$RENAMED"; kv NEWF "$NEWF"
} > "$RUNDIR/scene.env"

# ---- 準備できた状態を表示する ----
log "準備した場面: $SCENE-$RUN（$DESC）"
echo "  HEAD: $(sbgit symbolic-ref -q --short HEAD || echo "detached $(sbgit rev-parse --short HEAD)")"
echo "  記録（return-branch）: $(sbgit config --get --default none progress-report.return-branch)"
echo "  master の .state.json:"; sbgit show master:docs/progress/.state.json | sed 's/^/    /'
echo "  master の first-parent（新しい順に5件）:"
sbgit log master --first-parent -5 --date=short --pretty=format:'    %h %ad %P | %s' ; echo
echo "  git status --porcelain:"; sbgit status --porcelain | sed 's/^/    /'
echo "  期待: 新しいコミット=$EXP_NEW、切り替え=$EXP_SWITCH、通知=$EXP_NOTIFY、記録=$EXP_RB"
