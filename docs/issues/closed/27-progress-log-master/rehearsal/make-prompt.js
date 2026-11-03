// make-prompt.js - skill-after.md から予行のプロンプトを作る
//
// 使い方: node make-prompt.js <skill-after.md> <砂場の絶対パス> <メインのチェックアウトの絶対パス> <worktreeの絶対パス> <出力> <報告>
//
// plan.md 7.1:
//   - skill-after.md の1行目だけを、砂場のパスに差し替える（1行目にある本物のリポジトリのパスを、砂場のパスに替える）。
//   - 先頭に予行の注意書き（PushNotification を使わず、送るはずの文を NOTIFY: で書く）を足す。
//   - 差し替えの後に、本物のリポジトリのパス（メインのチェックアウト、worktree）が残っていたら、出力を書かずに止める。
"use strict";
const fs = require("fs");

const [, , skillPath, sandbox, mainRoot, wtRoot, outPath, reportPath] = process.argv;
if (!reportPath) {
  console.error("使い方: node make-prompt.js <skill-after.md> <砂場> <メイン> <worktree> <出力> <報告>");
  process.exit(2);
}
const fail = (msg) => {
  console.error("ERROR: " + msg);
  process.exit(1);
};

const NOTE =
  "（予行）PushNotification は使わず、送るはずだった文を、最後の応答に「NOTIFY: <文>」の形で書くこと（1件につき1行。送る通知が無ければ、NOTIFY の行は書かない）。";

// パスの書き方の違い（C:\a\b、C:/a/b、/c/a/b、//c/a/b、大文字と小文字）を吸収して探すための正規表現
const forms = (p) => {
  const mm = /^([A-Za-z]):[\\/](.*)$/.exec(p);
  if (!mm) fail("絶対パスが C:/... の形でない: " + p);
  const rest = mm[2].replace(/[\\/]+$/, "").split(/[\\/]+/);
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const body = rest.map(esc).join("[\\\\/]");
  return new RegExp(`(?:${mm[1]}:[\\\\/]|/{1,2}${mm[1]}/)${body}`, "gi");
};
const toWin = (p) => p.replace(/\//g, "\\");

let text = fs.readFileSync(skillPath, "utf8").replace(/^\uFEFF/, "").replace(/\r\n/g, "\n");
if (/^---\n/.test(text)) fail("skill-after.md に frontmatter がある（plan.md 4.2: frontmatter は付けない）");
const lines = text.split("\n");
const line1 = lines[0];
const reMain = forms(mainRoot);
const hits = line1.match(reMain) || [];
if (hits.length !== 1) fail(`1行目に本物のリポジトリのパスがちょうど1つあるはずが、${hits.length} 個だった: ${line1}`);
const sbWin = toWin(sandbox);
const newLine1 = line1.replace(forms(mainRoot), () => sbWin);
const outText = NOTE + "\n\n" + [newLine1, ...lines.slice(1)].join("\n");

// 砂場のパスを伏せてから、本物のパスが残っていないかを調べる
const masked = outText.replace(forms(sandbox), "<SANDBOX>");
const leftovers = [];
masked.split("\n").forEach((l, k) => {
  for (const re of [forms(mainRoot), forms(wtRoot)]) {
    if (re.test(l)) leftovers.push(`${k + 1}行目: ${l}`);
  }
  if (/Users[\\/]owner[\\/]Documents[\\/]HirokiMiwa/i.test(l)) leftovers.push(`${k + 1}行目（ローカルの絶対パス）: ${l}`);
});
if (leftovers.length) fail("差し替えの後に、本物のリポジトリのパスが残っている（実行しない）:\n" + [...new Set(leftovers)].join("\n"));

// 1行目のほかは skill-after.md と同じであることを確かめる
const outLines = outText.split("\n");
if (outLines.slice(3).join("\n") !== lines.slice(1).join("\n")) fail("1行目のほかに違いがある（差し替えの誤り）");

fs.writeFileSync(outPath, outText);
const report = [
  `skill-after.md: ${lines.length} 行`,
  `1行目（前）: ${line1}`,
  `1行目（後）: ${newLine1}`,
  `先頭に足した注意書き: ${NOTE}`,
  "本物のリポジトリのパスは残っていない",
];
fs.writeFileSync(reportPath, report.join("\n") + "\n");
console.log(report.join("\n"));
