// parse-stream.js - claude -p --output-format stream-json --verbose の出力を読み、要約を書く
//
// 使い方: node parse-stream.js <stream.jsonl> <出力フォルダ> [<notify-patterns.json>]
// 書くもの（出力フォルダ）:
//   parsed.json   要約（完了したか、拒否、通知、呼び出しの一覧、init の情報）
//   parsed.env    check.sh が source する値（数と記号だけ）
//   calls.tsv     ツールの呼び出しの一覧（番号、ツール、拒否、エラー、コマンドまたはパス、結果の先頭）
//   denials.tsv   拒否された呼び出し（permission_denials）
//   notify.txt    通知（最後の応答の「NOTIFY: 」の行と、PushNotification の呼び出しの入力）と、その種類
//   final.txt     最後の応答の本文
"use strict";
const fs = require("fs");
const path = require("path");

const [, , streamPath, outDir, patternsPath] = process.argv;
if (!streamPath || !outDir) {
  console.error("使い方: node parse-stream.js <stream.jsonl> <出力フォルダ> [<notify-patterns.json>]");
  process.exit(2);
}
const patterns = JSON.parse(
  fs.readFileSync(patternsPath || path.join(__dirname, "notify-patterns.json"), "utf8").replace(/^﻿/, "")
);

const textOf = (c) => {
  if (typeof c === "string") return c;
  if (Array.isArray(c)) return c.map((b) => (b && typeof b.text === "string" ? b.text : "")).join("\n");
  return c == null ? "" : JSON.stringify(c);
};
const oneLine = (s, n) => String(s).replace(/\r?\n/g, " ⏎ ").replace(/\t/g, " ").slice(0, n);

let init = null;
let final = null;
let parseErrors = 0;
const calls = [];
const results = {};
const raw = fs.existsSync(streamPath) ? fs.readFileSync(streamPath, "utf8") : "";
for (const line of raw.split(/\r?\n/)) {
  if (!line.trim()) continue;
  let m;
  try {
    m = JSON.parse(line);
  } catch {
    parseErrors++;
    continue;
  }
  if (m.type === "system" && m.subtype === "init") init = m;
  if (m.type === "assistant" && m.message && Array.isArray(m.message.content)) {
    for (const b of m.message.content) {
      if (b.type === "tool_use") calls.push({ id: b.id, name: b.name, input: b.input || {} });
    }
  }
  if (m.type === "user" && m.message && Array.isArray(m.message.content)) {
    for (const b of m.message.content) {
      if (b.type === "tool_result") results[b.tool_use_id] = { is_error: !!b.is_error, text: textOf(b.content) };
    }
  }
  if (m.type === "result") final = m;
}

const denials = (final && Array.isArray(final.permission_denials) ? final.permission_denials : []).map((d) => ({
  tool_name: d.tool_name,
  tool_use_id: d.tool_use_id,
  tool_input: d.tool_input || {},
}));
const deniedIds = new Set(denials.map((d) => d.tool_use_id));
const isPush = (name) => /PushNotification/i.test(String(name || ""));

const summaryOf = (c) => {
  const i = c.input || {};
  if (typeof i.command === "string") return i.command;
  if (typeof i.file_path === "string") return i.file_path;
  if (typeof i.path === "string") return i.path;
  if (typeof i.pattern === "string") return i.pattern;
  return JSON.stringify(i);
};
const callRows = calls.map((c, k) => {
  const r = results[c.id] || { is_error: false, text: "" };
  // permission_denials に載らない拒否に備え、結果の文でも拒否を拾う（参考）
  const deniedByText = /permission|haven't granted|not allowed|denied/i.test(r.text) && r.is_error;
  return {
    no: k + 1,
    id: c.id,
    tool: c.name,
    denied: deniedIds.has(c.id),
    deniedByText,
    is_error: r.is_error,
    summary: summaryOf(c),
    result_head: oneLine(r.text, 160),
    input: c.input,
  };
});

// 通知: 最後の応答の「NOTIFY:」の行 + PushNotification の呼び出し（拒否されたものを含む）の入力の文字列
const finalText = final && typeof final.result === "string" ? final.result : "";
const notifies = [];
for (const line of finalText.split(/\r?\n/)) {
  const k = line.indexOf("NOTIFY:");
  if (k >= 0) {
    const t = line.slice(k + "NOTIFY:".length).trim().replace(/^[`「"']+|[`」"']+$/g, "").trim();
    if (t) notifies.push({ source: "NOTIFY", text: t });
  }
}
for (const c of calls) {
  if (!isPush(c.name)) continue;
  const strs = Object.values(c.input || {}).filter((v) => typeof v === "string");
  notifies.push({ source: "PushNotification", text: strs.join(" / ") });
}
const classify = (t) => {
  const kinds = [];
  for (const [kind, pats] of Object.entries(patterns)) {
    if (kind.startsWith("_")) continue;
    if (pats.some((p) => t.includes(p))) kinds.push(kind);
  }
  return kinds;
};
const kindSet = new Set();
let unknown = 0;
for (const n of notifies) {
  n.kinds = classify(n.text);
  if (n.kinds.length === 0) unknown++;
  n.kinds.forEach((k) => kindSet.add(k));
}
// 同じ文が NOTIFY と PushNotification の両方に出た場合も、種類は1つに数える（集合）
const notifyTypes = kindSet.size ? [...kindSet].sort().join("+") : "none";

const nonPush = denials.filter((d) => !isPush(d.tool_name));
const pushDenials = denials.filter((d) => isPush(d.tool_name));
const toolsUsed = [...new Set(calls.map((c) => c.name))].sort();

const parsed = {
  completed: !!final,
  subtype: final ? final.subtype : null,
  is_error: final ? !!final.is_error : null,
  num_turns: final ? final.num_turns : null,
  duration_ms: final ? final.duration_ms : null,
  total_cost_usd: final ? final.total_cost_usd : null,
  parse_errors: parseErrors,
  init: init
    ? {
        cwd: init.cwd,
        model: init.model,
        permissionMode: init.permissionMode,
        claude_code_version: init.claude_code_version,
        tools: init.tools,
        mcp_servers: init.mcp_servers,
        apiKeySource: init.apiKeySource,
      }
    : null,
  denials,
  non_push_denials: nonPush.length,
  push_denials: pushDenials.length,
  notifies,
  notify_types: notifyTypes,
  notify_unknown: unknown,
  tools_used: toolsUsed,
  calls: callRows,
};

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "parsed.json"), JSON.stringify(parsed, null, 2));
fs.writeFileSync(path.join(outDir, "final.txt"), finalText);
fs.writeFileSync(
  path.join(outDir, "calls.tsv"),
  ["no\ttool\tdenied\tis_error\tcommand_or_path\tresult_head"]
    .concat(callRows.map((r) => [r.no, r.tool, r.denied ? "DENIED" : "-", r.is_error ? "error" : "-", oneLine(r.summary, 300), r.result_head].join("\t")))
    .join("\n") + "\n"
);
fs.writeFileSync(
  path.join(outDir, "denials.tsv"),
  ["tool\tinput"].concat(denials.map((d) => [d.tool_name, oneLine(d.tool_input.command || JSON.stringify(d.tool_input), 300)].join("\t"))).join("\n") + "\n"
);
fs.writeFileSync(
  path.join(outDir, "notify.txt"),
  notifies.map((n) => `[${n.source}] [${n.kinds.join("+") || "不明"}] (${[...n.text].length}字) ${n.text}`).join("\n") + (notifies.length ? "\n" : "")
);
const envLines = {
  P_COMPLETED: parsed.completed ? 1 : 0,
  P_SUBTYPE: parsed.subtype || "none",
  P_IS_ERROR: parsed.is_error ? 1 : 0,
  P_NUM_CALLS: callRows.length,
  P_NON_PUSH_DENIALS: nonPush.length,
  P_PUSH_DENIALS: pushDenials.length,
  P_NOTIFY_TYPES: notifyTypes,
  P_NOTIFY_COUNT: notifies.length,
  P_NOTIFY_UNKNOWN: unknown,
  P_PARSE_ERRORS: parseErrors,
  P_TOOLS_USED: toolsUsed.join(",") || "none",
  P_MODEL: (init && init.model) || "unknown",
  P_CLI_VERSION: (init && init.claude_code_version) || "unknown",
};
fs.writeFileSync(
  path.join(outDir, "parsed.env"),
  Object.entries(envLines)
    .map(([k, v]) => `${k}='${String(v).replace(/[^A-Za-z0-9_.+,:\[\]\-]/g, "_")}'`)
    .join("\n") + "\n"
);
console.log(
  `parsed: completed=${parsed.completed} subtype=${parsed.subtype} calls=${callRows.length} ` +
    `denials(non-push)=${nonPush.length} denials(push)=${pushDenials.length} notify=${notifyTypes}`
);
