#!/usr/bin/env bash
# summarize.sh - temp/rehearsal-27/ にある予行の判定（*.run/check.tsv）を1つの表にまとめる
#
# 使い方: bash summarize.sh [<出力の Markdown>]
#   既定の出力: temp/rehearsal-27/summary-<日時>.md（標準出力にも出す）
#   S0・S0b（仕組みの確認）は s0-result.tsv・calls.tsv を見る（この表には入れない）。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OUTMD=${1:-"$REH_ROOT/summary-$(date +%Y%m%d-%H%M%S).md"}
ITEMS="R0 Rreal C1 C2 C3 C3p C3b C4 C5 C6 C7 C7n C8 C9 C10a C10b C10c C10d"

{
  echo "# 予行の一覧（$(date +%F) 作成）"
  echo
  echo "判定: OK / NG（参考は 参考OK / 参考NG）。空欄はその場面では確かめない項目。"
  echo "種類: R0・Rreal は前提、C3p・C4・C5・C7 は品質の基準、C1・C2・C3・C3b・C6・C7n・C8・C9 は計画どおりかの確認、C10a〜d は C10 の補助。"
  echo
  printf '| 回 |'; for i in $ITEMS; do printf ' %s |' "$i"; done; echo
  printf '|---|'; for _ in $ITEMS; do printf '%s' '---|'; done; echo
  for f in "$REH_ROOT"/*.run/check.tsv; do
    [ -f "$f" ] || continue
    name=$(basename "$(dirname "$f")" .run)
    printf '| %s |' "$name"
    for i in $ITEMS; do
      v=$(awk -F'\t' -v k="$i" '$1 == k {print $5}' "$f")
      printf ' %s |' "${v:-}"
    done
    echo
  done
  echo
  echo "## NG の詳細"
  echo
  found=0
  for f in "$REH_ROOT"/*.run/check.tsv; do
    [ -f "$f" ] || continue
    name=$(basename "$(dirname "$f")" .run)
    while IFS=$'\t' read -r item cls e a v; do
      echo "- $name $item（$cls）: 期待「$e」、実際「$a」"
      found=1
    done < <(awk -F'\t' 'NR > 1 && $5 ~ /NG/' "$f")
  done
  [ "$found" = 0 ] && echo "- なし"
  echo
  echo "## 通知の文（目で見る）"
  echo
  for f in "$REH_ROOT"/*.run/notify.txt; do
    [ -s "$f" ] || continue
    case "$(basename "$(dirname "$f")")" in S0*) continue ;; esac
    echo "- $(basename "$(dirname "$f")" .run):"
    sed 's/^/  - /' "$f"
  done
} > "$OUTMD"
cat "$OUTMD"
log "一覧を書いた: $OUTMD"
