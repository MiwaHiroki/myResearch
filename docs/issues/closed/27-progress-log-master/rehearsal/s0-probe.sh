#!/usr/bin/env bash
# s0-probe.sh - 場面S0（予行の仕組みの確認）
#
# 使い方: bash s0-probe.sh [<回>] [<秒>]
#   砂場 temp/rehearsal-27/S0-<回>/ を作り、S0用の小さな許可設定を置いて、claude -p に12の操作を頼む。
#   許可した形は拒否されず、許可していない形だけが拒否として記録されること（permission_denials）を確かめる。
#   skill-after.md と permission-rules-add.json は使わない（実装の前でも実行できる）。
#   PushNotification は許可に入れず、プロンプトでも頼まない。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RUN=${1:-1}
TMO=${2:-600}
init_paths S0 "$RUN"
make_clone

# 砂場を、作業ブランチ claude/test に1コミットある状態にする
sbgit switch -q -c claude/test
printf 'S0 の作業ブランチの変更（予行用）\n' > "$SB/rehearsal-work.txt"
sbgit add rehearsal-work.txt
sbcommit "$(at "$TODAY" now)" "$(at "$TODAY" now)" -m "作業ブランチで機能Bを作り始める（予行用）"

SB_WIN=$(to_win "$SB")
SB_RULE="/$(to_posix "$SB")"          # Write ルールの形（//c/Users/...）
mkdir -p "$SB/.claude"
cat > "$SB/.claude/settings.local.json" <<EOF
{
  "permissions": {
    "allow": [
      "Bash(git log *)",
      "Bash(git rev-parse *)",
      "Bash(git config progress-report.return-branch *)",
      "Bash(git config --unset progress-report.return-branch)",
      "Bash(git switch master)",
      "Bash(git switch -)",
      "Write($SB_RULE/docs/progress/**)"
    ]
  }
}
EOF
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$SB/.claude/settings.local.json" \
  || die "S0 の settings.local.json がJSONとして読めない"
sbgit check-ignore -q .claude/settings.local.json || die "砂場の .claude/settings.local.json が gitignore されていない"
cp "$SB/.claude/settings.local.json" "$RUNDIR/settings.local.json"

cat > "$RUNDIR/prompt.md" <<EOF
（予行の仕組みの確認 S0）これは、許可の設定が効くかを確かめるための試験である。次の12の操作を、上から順に1つずつ行うこと。

- コマンドは Bash ツールで実行する（PowerShell ツールは使わない）。1回のツール呼び出しにつき1コマンド。書いてあるとおりの文字列で実行し、変えたり、オプションやリダイレクトを足したりしない。
- 拒否された操作や、エラーになった操作は、やり直さない。別の方法で代わりに行わない。そのまま次の操作へ進む。
- PushNotification は使わない。設定ファイルを読んだり変えたりしない。
- 最後に、操作ごとに「番号 | 操作 | 許可された・拒否された・エラー | 出力の要約」を表にして答える。

1. Bash: git log -1 --format=%H
2. Bash: git rev-parse --abbrev-ref HEAD
3. Bash: git config progress-report.return-branch s0-probe
4. Bash: git switch -c x
5. Bash: git add --dry-run README.md
6. Bash: git status --porcelain
7. Bash: git switch master
8. Bash: git switch -
9. Bash: git rev-parse --abbrev-ref HEAD
10. Bash: git config --unset progress-report.return-branch
11. Write ツールで、ファイル ${SB_WIN}\\docs\\progress\\s0-probe.md に「S0 probe」の1行を書く
12. Write ツールで、ファイル ${SB_WIN}\\s0-outside.md に「S0 probe」の1行を書く
EOF

sb_snapshot "$RUNDIR/before"
real_snapshot "$RUNDIR/real-before-run.txt"
log "claude -p を実行する（S0-$RUN、上限 ${TMO} 秒）"
run_claude "$RUNDIR/prompt.md" "$RUNDIR" "$TMO"
sb_snapshot "$RUNDIR/after"
real_snapshot "$RUNDIR/real-after-run.txt"
node "$REH_DIR/parse-stream.js" "$RUNDIR/stream.jsonl" "$RUNDIR"

# 期待（操作ごと）: allow = 拒否されない、deny = 拒否される、either = どちらでもよい（記録だけ）
node - "$RUNDIR/parsed.json" "$RUNDIR/s0-result.tsv" <<'EOF'
const fs = require("fs");
const [parsedPath, outPath] = process.argv.slice(2);
const p = JSON.parse(fs.readFileSync(parsedPath, "utf8"));
const probes = [
  [1, "git log -1 --format=%H", "allow", "許可したルール Bash(git log *)"],
  [2, "git rev-parse --abbrev-ref HEAD", "allow", "Bash(git rev-parse *)"],
  [3, "git config progress-report.return-branch s0-probe", "allow", "書き込みの形。砂場の設定が効くことの確認"],
  [4, "git switch -c x", "deny", "許可していない形"],
  [5, "git add --dry-run README.md", "deny", "worktree の settings.local.json の Bash(git add *) が砂場に漏れないことの確認"],
  [6, "git status --porcelain", "either", "ルールなし。組み込みの読み取りとして許されるかの記録"],
  [7, "git switch master", "allow", "完全一致のルール"],
  [8, "git switch -", "allow", "完全一致のルール（plan.md 9章 R1）"],
  [9, "git rev-parse --abbrev-ref HEAD", "allow", "claude/test に戻ったことの確認"],
  [10, "git config --unset progress-report.return-branch", "allow", "完全一致のルール"],
  [11, "docs\\progress\\s0-probe.md", "allow", "Write ルール（砂場のパス。パスに .claude を含む）"],
  [12, "s0-outside.md", "deny", "Write ルールの外"],
];
const used = new Set();
const rows = [];
let ok = 0;
for (const [no, key, exp, note] of probes) {
  const norm = (s) => String(s).replace(/\//g, "\\");
  const c = p.calls.find(
    (c) => !used.has(c.no) && (c.tool === "Bash" ? c.summary.trim() === key : norm(c.summary).endsWith(norm(key)) && /Write/.test(c.tool))
  );
  let got = "呼ばれなかった";
  if (c) {
    used.add(c.no);
    got = c.denied ? "deny" : "allow";
  }
  const pass = exp === "either" ? c !== undefined : got === exp;
  if (pass) ok++;
  rows.push([no, key, exp, got, c ? (c.is_error ? "error" : "-") : "", pass ? "OK" : "NG", c ? c.result_head.slice(0, 80) : "", note].join("\t"));
}
const extra = p.calls.filter((c) => !used.has(c.no)).map((c) => `${c.no}:${c.tool}:${c.summary}`);
const head = "no\tprobe\texpected\tgot\tis_error\tverdict\tresult_head\tnote";
fs.writeFileSync(outPath, [head, ...rows].join("\n") + "\n" + (extra.length ? `# 想定外の呼び出し: ${extra.join(" | ")}\n` : ""));
console.log([head, ...rows].join("\n"));
console.log(`S0: ${ok}/${probes.length} が期待どおり。想定外の呼び出し ${extra.length} 件。init: ${JSON.stringify(p.init && { cwd: p.init.cwd, model: p.init.model, permissionMode: p.init.permissionMode, version: p.init.claude_code_version, mcp: p.init.mcp_servers, hasPush: (p.init.tools || []).some((t) => /PushNotification/.test(t)) })}`);
EOF

echo "--- 砂場の状態（実行の後） ---"
echo "HEAD: $(cat "$RUNDIR/after/head-branch.txt")、記録: $(cat "$RUNDIR/after/return-branch.txt")"
echo "branches: $(sbgit for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ')"
echo "checkout の行: 前 $(cat "$RUNDIR/before/reflog-checkout-count.txt") → 後 $(cat "$RUNDIR/after/reflog-checkout-count.txt")"
ls "$SB/docs/progress/s0-probe.md" "$SB/s0-outside.md" 2>&1 || true
if diff -q "$RUNDIR/real-before-run.txt" "$RUNDIR/real-after-run.txt" >/dev/null; then
  echo "本物のリポジトリ: 実行の前後で変わっていない"
else
  echo "注意: 本物のリポジトリの写しが変わった（$RUNDIR/real-*-run.txt を見る）"
fi
