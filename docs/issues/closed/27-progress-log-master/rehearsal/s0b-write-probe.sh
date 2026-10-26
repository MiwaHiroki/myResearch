#!/usr/bin/env bash
# s0b-write-probe.sh - 場面S0b（Write・Edit のルールが砂場で効くかの確認）
#
# 使い方: bash s0b-write-probe.sh [<回>] [<秒>] [<砂場の外の書き込み先フォルダ>]
#   S0 で、砂場の docs/progress/ への Write が、ルールがあるのに拒否された。原因を切り分けるため、
#   ルールの書き方を変えた Write・Edit を1回の claude -p で試す。
#     A: Write  絶対パスのルール //c/.../<砂場>/docs/progress/**（本番と同じ書き方）
#     F: Edit   同上（既存のファイルを Read してから Edit）
#     B: Write  設定ファイルからの相対のルール /notes-b/**
#     C: Write  カレントディレクトリからの相対のルール notes-c/**
#     E: Write  絶対パスのルールで、パスに .claude を含まない場所（第3引数。省略すると E は行わない）
#   A・F・B・C が拒否され E だけが許されれば、「パスに .claude を含む場所への書き込みは、ルールがあっても承認が要る」と分かる。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RUN=${1:-1}
TMO=${2:-600}
OUTSIDE=${3:-}
init_paths S0b "$RUN"
make_clone

mkdir -p "$SB/docs/progress"
printf 'old\n' > "$SB/docs/progress/existing.md"     # F で Edit する（追跡しないファイル。docs/progress は .gitignore の対象外）

SB_WIN=$(to_win "$SB")
SB_RULE="/$(to_posix "$SB")"
E_RULE=""; E_STEP=""
if [ -n "$OUTSIDE" ]; then
  case "$OUTSIDE" in *.claude*) die "E の場所に .claude を含めない: $OUTSIDE" ;; esac
  mkdir -p "$OUTSIDE"
  E_RULE=",
      \"Write(/$(to_posix "$OUTSIDE")/**)\""
  E_STEP="5. Write ツールで、ファイル $(to_win "$OUTSIDE")\\e.md に「S0b probe E」の1行を書く"
fi
mkdir -p "$SB/.claude"
cat > "$SB/.claude/settings.local.json" <<EOF
{
  "permissions": {
    "allow": [
      "Write($SB_RULE/docs/progress/**)",
      "Edit($SB_RULE/docs/progress/**)",
      "Write(/notes-b/**)",
      "Write(notes-c/**)"$E_RULE
    ]
  }
}
EOF
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$SB/.claude/settings.local.json" \
  || die "S0b の settings.local.json がJSONとして読めない"
cp "$SB/.claude/settings.local.json" "$RUNDIR/settings.local.json"

cat > "$RUNDIR/prompt.md" <<EOF
（予行の仕組みの確認 S0b）これは、ファイルの書き込みの許可の設定が効くかを確かめるための試験である。次の操作を、上から順に1つずつ行うこと。

- 拒否された操作や、エラーになった操作は、やり直さない。別の方法（Bash など）で代わりに行わない。そのまま次の操作へ進む。
- PushNotification は使わない。設定ファイルを読んだり変えたりしない。
- 最後に、操作ごとに「番号 | 操作 | 許可された・拒否された・エラー」を表にして答える。

1. Write ツールで、ファイル ${SB_WIN}\\docs\\progress\\a.md に「S0b probe A」の1行を書く
2. Read ツールで ${SB_WIN}\\docs\\progress\\existing.md を読み、Edit ツールで、その中の old を new に置き換える
3. Write ツールで、ファイル ${SB_WIN}\\notes-b\\b.md に「S0b probe B」の1行を書く
4. Write ツールで、ファイル ${SB_WIN}\\notes-c\\c.md に「S0b probe C」の1行を書く
${E_STEP}
EOF

real_snapshot "$RUNDIR/real-before-run.txt"
log "claude -p を実行する（S0b-$RUN、上限 ${TMO} 秒）"
run_claude "$RUNDIR/prompt.md" "$RUNDIR" "$TMO"
real_snapshot "$RUNDIR/real-after-run.txt"
node "$REH_DIR/parse-stream.js" "$RUNDIR/stream.jsonl" "$RUNDIR"
cut -f1-5 "$RUNDIR/calls.tsv"
echo "--- できたファイル ---"
for f in docs/progress/a.md notes-b/b.md notes-c/c.md; do
  if [ -e "$SB/$f" ]; then echo "あり: $f"; else echo "なし: $f"; fi
done
echo "existing.md: $(cat "$SB/docs/progress/existing.md")"
if [ -n "$OUTSIDE" ]; then if [ -e "$OUTSIDE/e.md" ]; then echo "あり: $OUTSIDE/e.md"; else echo "なし: $OUTSIDE/e.md"; fi; fi
if diff -q "$RUNDIR/real-before-run.txt" "$RUNDIR/real-after-run.txt" >/dev/null; then
  echo "本物のリポジトリ: 実行の前後で変わっていない"
else
  echo "注意: 本物のリポジトリの写しが変わった（$RUNDIR/real-*-run.txt を見る）"
fi
