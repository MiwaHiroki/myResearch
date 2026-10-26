// c10.js - 日次ログの確かめの補助（C10 は目で見る項目。ここでは目で見る前の機械的な確かめだけを行う）
//
// 使い方: node c10.js <実行の前の期間ファイル> <実行の後の期間ファイル> <増えるはずの見出し（空白区切り）> <含むはずの文字列（| 区切り）> <追記分の出力>
// 出力（標準出力、タブ区切り）: 項目 期待 実際 判定（参考OK / 参考NG）
//   C10a 実行の前の「## 日次ログ」以降が、実行の後の同じ部分の先頭にそのまま残っている（既存の行を変えていない）
//   C10b 実行の後の日次ログの見出し（### YYYY-MM-DD）が、重複なく日付順に並んでいる
//   C10c 増えた見出しが期待どおり
//   C10d 追記された部分に、期待する文字列がすべて含まれる
"use strict";
const fs = require("fs");
const [, , beforePath, afterPath, expHeadings, expText, addedOut] = process.argv;
const read = (p) => fs.readFileSync(p, "utf8").replace(/^﻿/, "").replace(/\r\n/g, "\n");
const daily = (t) => {
  const k = t.indexOf("## 日次ログ");
  return k < 0 ? null : t.slice(k);
};
const headings = (t) => (t.match(/^### (\d{4}-\d{2}-\d{2})\s*$/gm) || []).map((h) => h.slice(4).trim());
const out = [];
const row = (item, exp, act, ok) => out.push([item, exp, act, ok ? "参考OK" : "参考NG"].join("\t"));

const b = daily(read(beforePath));
const a = daily(read(afterPath));
if (b === null || a === null) {
  row("C10a", "「## 日次ログ」がある", `前:${b !== null} 後:${a !== null}`, false);
  console.log(out.join("\n"));
  process.exit(0);
}
const bTrim = b.replace(/\s+$/, "");
const kept = a.startsWith(bTrim);
row("C10a", "既存の日次ログが先頭にそのまま残る", kept ? "残っている" : "変わっている", kept);
const added = kept ? a.slice(bTrim.length) : a;
fs.writeFileSync(addedOut, added.replace(/^\n+/, ""));

const ha = headings(a);
let sorted = true;
for (let i = 1; i < ha.length; i++) if (!(ha[i - 1] < ha[i])) sorted = false;
row("C10b", "見出しが重複なく日付順", `${ha.join(",")}`, sorted);

const hb = new Set(headings(b));
const newH = ha.filter((h) => !hb.has(h));
const expH = (expHeadings || "").split(/\s+/).filter(Boolean);
const sameH = newH.length === expH.length && newH.every((h, i) => h === expH[i]);
row("C10c", expH.join(",") || "(増えない)", newH.join(",") || "(増えない)", sameH);

const expT = (expText || "").split("|").filter(Boolean);
if (expT.length) {
  const missing = expT.filter((s) => !added.includes(s));
  row("C10d", expT.join(" / "), missing.length ? "無い: " + missing.join(" / ") : "すべてある", missing.length === 0);
}
console.log(out.join("\n"));
