#!/usr/bin/env bash
# manual.sh - 予行の (b)（claude -p が使えないとき、評価担当が skill-after.md を文字どおりに実行する）の前後の写しと判定
#
# 使い方:
#   bash manual.sh <場面> <回> begin --skill <skill-after.md> --rules <permission-rules-add.json>
#       → 実行の前の写しを取り、砂場のパスを差し替えたプロンプト（prompt.md）を作る
#   （評価担当が、砂場をカレントディレクトリにして、prompt.md の手順を文字どおりに行う。README の「(b) の手順」）
#     - 実行したコマンドを1行に1つ、<記録>/manual-commands.txt に書く（Bash で実行した文字列そのまま）
#     - 書いたファイルを1行に1つ、<記録>/manual-writes.txt に書く（絶対パス）
#     - 送るはずだった通知の文を1行に1つ、<記録>/manual-notify.txt に書く（無ければ空のファイル）
#   bash manual.sh <場面> <回> end
#       → 実行の後の写しを取り、記録から stream.jsonl の代わりを作って、check.sh で判定する
#   (b) では許可の照合が起きないので、C7 は「確かめられない」とする（check.md の C7 は OK と出るが、使わない）。
#   C7n（狭いルールとの照合）は、manual-commands.txt から計算する。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCENE=${1:?場面}; RUN=${2:?回}; STEP=${3:?begin か end}
shift 3
SKILL=""; RULES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL=$2; shift 2 ;;
    --rules) RULES=$2; shift 2 ;;
    *) die "知らない引数: $1" ;;
  esac
done
init_paths "$SCENE" "$RUN"
[ -f "$RUNDIR/scene.env" ] || die "準備されていない（先に bash setup.sh $SCENE $RUN）"
# shellcheck disable=SC1091
source "$RUNDIR/scene.env"
assert_sandbox

case "$STEP" in
  begin)
    [ -f "$SKILL" ] && [ -f "$RULES" ] || die "--skill と --rules を指定する"
    [ "$TODAY" = "$(date +%F)" ] || die "準備した日と今日が違う"
    mkdir -p "$RUNDIR/inputs"
    cp "$SKILL" "$RUNDIR/inputs/skill-after.md"; cp "$RULES" "$RUNDIR/inputs/permission-rules-add.json"
    node "$REH_DIR/make-prompt.js" "$RUNDIR/inputs/skill-after.md" "$SB" "$MAIN_ROOT" "$WT" "$RUNDIR/prompt.md" "$RUNDIR/prompt-report.txt" > /dev/null
    : > "$RUNDIR/manual-commands.txt"; : > "$RUNDIR/manual-writes.txt"; : > "$RUNDIR/manual-notify.txt"
    sb_snapshot "$RUNDIR/before"
    real_snapshot "$RUNDIR/real-before-run.txt"
    echo "砂場: $SB"
    echo "プロンプト: $RUNDIR/prompt.md"
    echo "記録: $RUNDIR/manual-commands.txt, manual-writes.txt, manual-notify.txt"
    ;;
  end)
    sb_snapshot "$RUNDIR/after"
    real_snapshot "$RUNDIR/real-after-run.txt"
    node - "$RUNDIR" <<'EOF'
const fs = require("fs"); const path = require("path");
const dir = process.argv[2];
const lines = (f) => fs.readFileSync(path.join(dir, f), "utf8").split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
const out = [];
out.push(JSON.stringify({ type: "system", subtype: "init", cwd: "manual", model: "manual(b)", permissionMode: "manual", claude_code_version: "manual", tools: [], mcp_servers: [] }));
let k = 0;
const content = [];
for (const c of lines("manual-commands.txt")) content.push({ type: "tool_use", id: `m${++k}`, name: "Bash", input: { command: c } });
for (const w of lines("manual-writes.txt")) content.push({ type: "tool_use", id: `m${++k}`, name: "Write", input: { file_path: w } });
out.push(JSON.stringify({ type: "assistant", message: { content } }));
const result = ["（b）評価担当が手で実行した", ...lines("manual-notify.txt").map((t) => "NOTIFY: " + t)].join("\n");
out.push(JSON.stringify({ type: "result", subtype: "success", is_error: false, num_turns: 0, result, permission_denials: [] }));
fs.writeFileSync(path.join(dir, "stream.jsonl"), out.join("\n") + "\n");
EOF
    echo 0 > "$RUNDIR/exit-code.txt"
    node "$REH_DIR/parse-stream.js" "$RUNDIR/stream.jsonl" "$RUNDIR"
    bash "$REH_DIR/check.sh" "$SCENE" "$RUN"
    echo "注意: (b) では C7（許可の照合）は確かめられない。check.md の C7 は使わない"
    ;;
  *) die "begin か end を指定する" ;;
esac
