#!/usr/bin/env bash
# run-all.sh - 必須の場面をすべて、準備 → 実行 → 判定の順に1つずつ行い、最後に一覧を作る
#
# 使い方: bash run-all.sh --skill <skill-after.md> --rules <permission-rules-add.json>
#                        [--base <settings.local.json>] [--run <最初の回>] [--timeout <秒>] [--with-optional] [--only "S2 S8"]
#   --run の既定は 1。S2・S8 は <最初の回> と <最初の回>+1 の2回、ほかは <最初の回> の1回。
#   --with-optional: 任意の場面 S15 も行う。
#   --only: 指定した場面だけを行う（空白区切り。S2・S8 の2回の扱いは同じ）。
#   1回の claude -p は数分かかる。全体で1時間以上かかるので、バックグラウンドで実行する（README）。
#   途中で止まっても、終わった場面の記録は残る。続きは --only で指定する。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL=""; RULES=""; BASE="$INPUTS_DIR/base-settings.local.json"; FIRST=1; TMO=900; OPTIONAL=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL=$2; shift 2 ;;
    --rules) RULES=$2; shift 2 ;;
    --base) BASE=$2; shift 2 ;;
    --run) FIRST=$2; shift 2 ;;
    --timeout) TMO=$2; shift 2 ;;
    --with-optional) OPTIONAL=1; shift ;;
    --only) ONLY=$2; shift 2 ;;
    *) die "知らない引数: $1" ;;
  esac
done
[ -f "$SKILL" ] || die "--skill のファイルが無い: $SKILL"
[ -f "$RULES" ] || die "--rules のファイルが無い: $RULES"
[ -f "$BASE" ] || die "--base のファイルが無い: $BASE"

REQUIRED="S1 S2 S3a S3b S4 S5 S6 S7 S8 S9 S10 S11 S11b S12 S12b S13 S14 S16"
SCENES=$REQUIRED
[ "$OPTIONAL" = 1 ] && SCENES="$SCENES S15"
[ -n "$ONLY" ] && SCENES=$ONLY

do_one() { # do_one <場面> <回>
  log "=== $1-$2: 準備"
  bash "$REH_DIR/setup.sh" "$1" "$2" 2>&1 | grep -v 'LF will be replaced' || true
  if [ ! -f "$REH_ROOT/$1-$2.run/scene.env" ]; then
    log "$1-$2: 準備に失敗した。次へ進む"
    return 0
  fi
  log "=== $1-$2: 実行と判定"
  bash "$REH_DIR/run.sh" "$1" "$2" --skill "$SKILL" --rules "$RULES" --base "$BASE" --timeout "$TMO" 2>&1 \
    | grep -v 'LF will be replaced' || log "$1-$2: run.sh がエラーで終わった"
}

LOGF="$REH_ROOT/run-all-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$REH_ROOT"
log "run-all: $SCENES（最初の回 $FIRST）。ログ: $LOGF" | tee -a "$LOGF"
for s in $SCENES; do
  runs=$FIRST
  case "$s" in S2|S8) runs="$FIRST $((FIRST + 1))" ;; esac
  for r in $runs; do
    do_one "$s" "$r" 2>&1 | tee -a "$LOGF" || true
  done
done
bash "$REH_DIR/summarize.sh" 2>&1 | tee -a "$LOGF"
