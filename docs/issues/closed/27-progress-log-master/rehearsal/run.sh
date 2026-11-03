#!/usr/bin/env bash
# run.sh - 準備した場面で、skill-after.md を claude -p に実行させ、前後を写して判定する
#
# 使い方: bash run.sh <場面> <回> --skill <skill-after.md> --rules <permission-rules-add.json>
#                    [--base <settings.local.json>] [--timeout <秒>] [--dry-run] [-- <claude に足す引数...>]
#   --dry-run: 許可設定とプロンプトを作って表示し、claude -p は実行しない（LLM を使わずに入力を確かめる）
#   例:   bash run.sh S2 1 --skill docs/issues/27-progress-log-master/skill-after.md \
#                          --rules docs/issues/27-progress-log-master/permission-rules-add.json
#   --base の既定: temp/rehearsal-27/_inputs/base-settings.local.json
#                  （メインのチェックアウトの .claude/settings.local.json の写し。README の「準備」を参照）
#   --timeout の既定: 900 秒
#   先に bash setup.sh <場面> <回> を実行しておく（同じ日に）。
#
# 書くもの（temp/rehearsal-27/<場面>-<回>.run/）:
#   inputs/        使った skill-after.md・permission-rules-add.json・base の写しと sha256
#   settings.local.json, settings-report.txt   砂場の許可設定とその作り方
#   prompt.md, prompt-report.txt               差し替えたプロンプト
#   before/, after/                            実行の前後の写し（lib.sh の sb_snapshot）
#   real-before-run.txt, real-after-run.txt    本物のリポジトリの写し（読み取りのみ）
#   stream.jsonl, stderr.txt, exit-code.txt    claude -p の出力
#   parsed.*, calls.tsv, denials.tsv, notify.txt, final.txt   出力の要約（parse-stream.js）
#   check.tsv, check.md, progress.diff, daily-*.md             判定（check.sh）

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENE=${1:?場面を指定する}
RUN=${2:?回を指定する}
shift 2
SKILL=""; RULES=""; BASE="$INPUTS_DIR/base-settings.local.json"; TMO=900; EXTRA=(); DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --skill) SKILL=$2; shift 2 ;;
    --rules) RULES=$2; shift 2 ;;
    --base) BASE=$2; shift 2 ;;
    --timeout) TMO=$2; shift 2 ;;
    --) shift; EXTRA=("$@"); break ;;
    *) die "知らない引数: $1" ;;
  esac
done
for a in "${EXTRA[@]+"${EXTRA[@]}"}"; do
  case "$a" in
    --dangerously-skip-permissions|--allow-dangerously-skip-permissions|--allowedTools*|--allowed-tools*|--permission-mode*|--settings*|--setting-sources*)
      die "この引数は付けない（許可の照合が本番と変わる）: $a" ;;
  esac
done
[ -n "$SKILL" ] && [ -f "$SKILL" ] || die "--skill のファイルが無い: $SKILL"
[ -n "$RULES" ] && [ -f "$RULES" ] || die "--rules のファイルが無い: $RULES"
[ -f "$BASE" ] || die "--base のファイルが無い: $BASE（README の「準備」を参照）"

init_paths "$SCENE" "$RUN"
[ -f "$RUNDIR/scene.env" ] || die "準備されていない（先に bash setup.sh $SCENE $RUN）"
# shellcheck disable=SC1091
source "$RUNDIR/scene.env"
[ "$TODAY" = "$(date +%F)" ] || die "準備した日（$TODAY）と今日（$(date +%F)）が違う。準備からやり直す"
[ -e "$RUNDIR/stream.jsonl" ] && die "この砂場ではもう実行した（別の回の番号で準備し直す）: $RUNDIR"
assert_sandbox

# ---- 入力の写し ----
mkdir -p "$RUNDIR/inputs"
cp "$SKILL" "$RUNDIR/inputs/skill-after.md"
cp "$RULES" "$RUNDIR/inputs/permission-rules-add.json"
cp "$BASE" "$RUNDIR/inputs/base-settings.local.json"
( cd "$RUNDIR/inputs" && sha256sum skill-after.md permission-rules-add.json base-settings.local.json > sha256.txt )

# ---- 許可設定とプロンプト ----
mkdir -p "$SB/.claude"
node "$REH_DIR/make-settings.js" "$RUNDIR/inputs/base-settings.local.json" "$RUNDIR/inputs/permission-rules-add.json" \
  "$SB" "$SB/.claude/settings.local.json" "$RUNDIR/settings-report.txt" > /dev/null
cp "$SB/.claude/settings.local.json" "$RUNDIR/settings.local.json"
sbgit check-ignore -q .claude/settings.local.json || die "砂場の .claude/settings.local.json が gitignore されていない"
node "$REH_DIR/make-prompt.js" "$RUNDIR/inputs/skill-after.md" "$SB" "$MAIN_ROOT" "$WT" \
  "$RUNDIR/prompt.md" "$RUNDIR/prompt-report.txt" > /dev/null
log "許可設定とプロンプトを作った（$RUNDIR/settings-report.txt、prompt-report.txt）"
if [ "$DRY" = 1 ]; then
  cat "$RUNDIR/settings-report.txt" "$RUNDIR/prompt-report.txt"
  log "--dry-run: claude -p は実行しない"
  exit 0
fi

# ---- 実行 ----
sb_snapshot "$RUNDIR/before"
real_snapshot "$RUNDIR/real-before-run.txt"
log "claude -p を実行する（$SCENE-$RUN: $DESC。上限 ${TMO} 秒）"
run_claude "$RUNDIR/prompt.md" "$RUNDIR" "$TMO" --disallowedTools PushNotification "${EXTRA[@]+"${EXTRA[@]}"}"
sb_snapshot "$RUNDIR/after"
real_snapshot "$RUNDIR/real-after-run.txt"
node "$REH_DIR/parse-stream.js" "$RUNDIR/stream.jsonl" "$RUNDIR"

bash "$REH_DIR/check.sh" "$SCENE" "$RUN"
