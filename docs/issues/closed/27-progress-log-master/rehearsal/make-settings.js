// make-settings.js - 砂場の .claude/settings.local.json を作る
//
// 使い方: node make-settings.js <base settings.local.json> <permission-rules-add.json> <砂場の絶対パス> <出力> <報告>
//
// 中身（plan.md 7.1）: メインのチェックアウトの今の許可ルール（base）に permission-rules-add.json を足したもの。ただし
//   - Write(…/docs/progress/**)・Edit(…/docs/progress/**) は、砂場の docs/progress/** に書き換える。
//     ほかの Write・Edit のルールは落とす（本物のリポジトリに書けないようにする）。
//   - PushNotification は allow から落とし、deny に入れる（通知を本当に送らないため）。
//   - mcp__* は落とす（予行では MCP サーバーを起動しない）。
//   - permissions の allow・deny・ask・defaultMode のほかの項目（hooks、additionalDirectories など）は落とす。
// permission-rules-add.json は「permissions.allow に足す文字列の配列」（JSON の配列そのもの）とする。
// 各要素は Bash(…) か PowerShell(…) の形でなければ止める。
"use strict";
const fs = require("fs");

const [, , basePath, addPath, sandbox, outPath, reportPath] = process.argv;
if (!reportPath) {
  console.error("使い方: node make-settings.js <base> <permission-rules-add.json> <砂場> <出力> <報告>");
  process.exit(2);
}
const readJson = (p) => JSON.parse(fs.readFileSync(p, "utf8").replace(/^\uFEFF/, ""));
const fail = (msg) => {
  console.error("ERROR: " + msg);
  process.exit(1);
};

const base = readJson(basePath);
const add = readJson(addPath);
if (!Array.isArray(add)) fail("permission-rules-add.json が JSON の配列でない");
for (const r of add) {
  if (typeof r !== "string") fail("permission-rules-add.json に文字列でない要素がある: " + JSON.stringify(r));
  if (!/^(Bash|PowerShell)\(.+\)$/.test(r)) fail("permission-rules-add.json に Bash(…)・PowerShell(…) でない要素がある: " + r);
}

// 砂場のパス C:/Users/... → ルールの形 //c/Users/...
const m = /^([A-Za-z]):[\\/](.*)$/.exec(sandbox);
if (!m) fail("砂場のパスが C:/... の形でない: " + sandbox);
const sbRule = "//" + m[1].toLowerCase() + "/" + m[2].replace(/\\/g, "/").replace(/\/+$/, "");

const perms = base.permissions || {};
const report = [];
const allow = [];
for (const r of perms.allow || []) {
  if (/^PushNotification(\(|$)/.test(r)) {
    report.push("落とした（通知を送らないため）: " + r);
    continue;
  }
  if (/^mcp__/.test(r)) {
    report.push("落とした（MCPを起動しないため）: " + r);
    continue;
  }
  const fm = /^(Write|Edit)\((.*)\)$/.exec(r);
  if (fm) {
    if (/\/docs\/progress\/\*\*$/.test(fm[2])) {
      const nr = `${fm[1]}(${sbRule}/docs/progress/**)`;
      report.push(`書き換えた: ${r} → ${nr}`);
      allow.push(nr);
    } else {
      report.push("落とした（砂場の外を指す書き込みのルール）: " + r);
    }
    continue;
  }
  allow.push(r);
}
for (const r of add) {
  if (allow.includes(r)) report.push("足す前からある（重複を省いた）: " + r);
  else allow.push(r);
}
const deny = [...new Set([...(perms.deny || []), "PushNotification"])];
const out = { permissions: { allow, deny } };
if (Array.isArray(perms.ask) && perms.ask.length) out.permissions.ask = perms.ask;
if (perms.defaultMode) out.permissions.defaultMode = perms.defaultMode;
for (const k of Object.keys(perms)) {
  if (!["allow", "deny", "ask", "defaultMode"].includes(k)) report.push("落とした permissions の項目: " + k);
}
for (const k of Object.keys(base)) {
  if (k !== "permissions") report.push("落とした最上位の項目: " + k);
}
// 本物のリポジトリを指す書き込みのルールが残っていないこと
for (const r of [...allow]) {
  if (/^(Write|Edit)\(/.test(r) && !r.startsWith(`${r.split("(")[0]}(${sbRule}/`)) fail("砂場の外を指す書き込みのルールが残った: " + r);
}
// 広いルール（形が崩れても許してしまい、C7 で崩れが見えなくなる）を報告する。C7n はこれに影響されない
const broad = allow.filter((r) =>
  /^(Bash|PowerShell)\((\*|git \*|git (add|commit|switch|checkout|config|stash|reset|push|worktree) \*)\)$/.test(r)
);
if (broad.length) report.push("注意: 広いルールがある（C7 では形の崩れが隠れる。C7n で確かめる）: " + broad.join(" , "));
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + "\n");
JSON.parse(fs.readFileSync(outPath, "utf8")); // 読み直して JSON として正しいことを確かめる
report.push(`allow ${allow.length} 件（うち permission-rules-add.json から ${add.length} 件）、deny ${deny.length} 件`);
fs.writeFileSync(reportPath, report.join("\n") + "\n");
console.log(report.join("\n"));
