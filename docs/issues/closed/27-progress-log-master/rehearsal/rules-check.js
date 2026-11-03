// rules-check.js - コマンドの形と許可ルールの対応を、狭いルールの集まりで確かめる
//
// 狭いルールの集まり = task-rules-existing.json（plan.md 2.1 の、タスクに関係する既存のルール）
//                    + permission-rules-add.json（足すルール）
// 本番の settings.local.json にある広いルール（Bash(git config *)・Bash(git commit *) など）は使わない。
// 広いルールで隠れてしまう形の崩れ（plan.md 9章 R7）を見つけるため。
//
// 照合の規則（README.md の決定事項。Claude Code の文書による。ここでの再現は近似）:
//   - * の無いルールは完全一致。末尾が「 *」のルールは、その前までと完全一致するコマンドにも一致する（git status * は git status にも一致）。
//   - &&・||・;・| でつないだコマンドは、引用符の外で区切って、サブコマンドごとに照合する。
//   - Bash ツールのコマンドは Bash(…) だけ、PowerShell ツールのコマンドは PowerShell(…) だけに照合する。
//
// 使い方:
//   動き:  node rules-check.js run <parsed.json> <permission-rules-add.json> <task-rules-existing.json> <砂場> <出力tsv>
//          → 標準出力に C7n の1行（項目、種類、期待、実際、判定。タブ区切り）
//   静的:  node rules-check.js static <skill-after.md> <permission-rules-add.json> <task-rules-existing.json>
//          → skill-after.md の `git …`（バッククォートの中）を抜き出し、<…> を例の値にして、一致するルールを表にする
"use strict";
const fs = require("fs");
const readJson = (p) => JSON.parse(fs.readFileSync(p, "utf8").replace(/^﻿/, ""));

function splitCommand(cmd) {
  const parts = [];
  let cur = "";
  let q = null;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (q) {
      cur += c;
      if (c === q) q = null;
      else if (c === "\\" && q === '"' && i + 1 < cmd.length) cur += cmd[++i];
      continue;
    }
    if (c === '"' || c === "'") {
      q = c;
      cur += c;
      continue;
    }
    const two = cmd.slice(i, i + 2);
    if (two === "&&" || two === "||") {
      parts.push(cur);
      cur = "";
      i++;
      continue;
    }
    if (c === ";" || c === "|" || c === "\n") {
      parts.push(cur);
      cur = "";
      continue;
    }
    cur += c;
  }
  parts.push(cur);
  return parts.map((s) => s.trim()).filter(Boolean);
}
function ruleMatches(rule, tool, sub) {
  const m = /^(\w+)\((.*)\)$/.exec(rule);
  if (!m || m[1] !== tool) return false;
  let pat = m[2].replace(/:\*$/, " *");
  if (!pat.includes("*")) return sub === pat;
  if (pat.endsWith(" *") && sub === pat.slice(0, -2)) return true;
  const re = new RegExp("^" + pat.split("*").map((s) => s.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*") + "$", "s");
  return re.test(sub);
}
const matching = (rules, tool, sub) => rules.filter((r) => ruleMatches(r, tool, sub));

const mode = process.argv[2];
if (mode === "run") {
  const [parsedPath, addPath, existPath, sandbox, outPath] = process.argv.slice(3);
  const rules = [...readJson(existPath), ...readJson(addPath)];
  const p = readJson(parsedPath);
  const norm = (s) => String(s).replace(/\\/g, "/").toLowerCase();
  const progressDir = norm(sandbox).replace(/\/+$/, "") + "/docs/progress/";
  const rows = [];
  let bad = 0;
  let compound = 0;
  let badWrites = 0;
  for (const c of p.calls) {
    if (c.tool === "Bash" || c.tool === "PowerShell") {
      const subs = splitCommand(c.input.command || "");
      if (subs.length > 1) compound++;
      for (const s of subs) {
        const hit = matching(rules, c.tool, s);
        if (!hit.length) bad++;
        rows.push([c.no, c.tool, s, hit.join(" , ") || "（一致なし）", c.denied ? "DENIED" : "-"].join("\t"));
      }
    } else if (/^(Write|Edit|MultiEdit|NotebookEdit)$/.test(c.tool)) {
      const fp = c.input.file_path || c.input.notebook_path || "";
      const ok = norm(fp).startsWith(progressDir);
      if (!ok) badWrites++;
      rows.push([c.no, c.tool, fp, ok ? "docs/progress の中" : "（docs/progress の外）", c.denied ? "DENIED" : "-"].join("\t"));
    }
  }
  fs.writeFileSync(outPath, ["no\ttool\tcommand_or_path\tmatching_rules\tdenied", ...rows].join("\n") + "\n");
  const ok = bad === 0 && compound === 0 && badWrites === 0;
  console.log(
    [
      "C7n",
      "計画",
      "実行したコマンドがすべて狭いルールに一致、つないだコマンド無し、書き込みは docs/progress の中だけ",
      `一致しないサブコマンド ${bad}、つないだコマンド ${compound}、docs/progress の外への書き込み ${badWrites}（commands-vs-rules.tsv）`,
      ok ? "OK" : "NG",
    ].join("\t")
  );
} else if (mode === "static") {
  const [skillPath, addPath, existPath] = process.argv.slice(3);
  const rules = [...readJson(existPath), ...readJson(addPath)];
  const text = fs.readFileSync(skillPath, "utf8").replace(/\r\n/g, "\n");
  const sample = (s) =>
    s
      .replace(/<last_commit>|<親1>|<親2>|<[^>]*SHA[^>]*>|<[^>]*ハッシュ[^>]*>/gi, "0123456789abcdef0123456789abcdef01234567")
      .replace(/<ブランチ名>|<B>|<CUR>|<R>/g, "claude/test")
      .replace(/<旧>/g, "x_old.md")
      .replace(/<新>/g, "x_new.md")
      .replace(/<ファイル>/g, "x.md")
      .replace(/\s*\[docs\/progress\/x\.md \.\.\.\]/g, "")
      .replace(/<件名>/g, "進捗ログ自動更新（2026-10-22分）")
      .replace(/<本文>/g, "本文")
      .replace(/<[^>]+>/g, "X");
  const seen = new Set();
  const lines = text.split("\n");
  console.log("line\tcommand（skill-after.md）\t例の値にした形\tBash のルール\tPowerShell のルール");
  lines.forEach((l, k) => {
    for (const m of l.matchAll(/`(git [^`]+)`/g)) {
      const cmd = m[1].replace(/\\\|/g, "|");
      if (seen.has(cmd)) continue;
      seen.add(cmd);
      const s = sample(cmd);
      const subs = splitCommand(s);
      const b = subs.map((x) => matching(rules, "Bash", x).join(" , ") || "（一致なし）").join(" ／ ");
      const ps = subs.map((x) => matching(rules, "PowerShell", x).join(" , ") || "（一致なし）").join(" ／ ");
      console.log([k + 1, cmd, s, b, ps].join("\t"));
    }
  });
} else {
  console.error("使い方: node rules-check.js run|static ...");
  process.exit(2);
}
