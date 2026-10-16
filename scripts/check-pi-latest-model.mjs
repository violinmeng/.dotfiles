#!/usr/bin/env node
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { latestChatGPT, selectLatestChatGPT } from "../shared/pi/extensions/latest-chatgpt.ts";

const models = ["gpt-5.5", "gpt-6-sol", "gpt-6.1-sol", "gpt-6.9-sol", "gpt-6.10-sol",
  "gpt-7-mini", "gpt-7-pro", "gpt-7-preview", "gpt-7-astra"].map((id) => ({ provider: "openai", id }));
assert.equal(latestChatGPT(models)?.id, "gpt-6.10-sol");
assert.equal(latestChatGPT([...models, { provider: "openai", id: "gpt-7" }])?.id, "gpt-7");
assert.equal(latestChatGPT([{ provider: "other", id: "gpt-99-sol" }]), undefined);
assert.equal(latestChatGPT([]), undefined);
console.log("PASS: numeric release ordering, new releases, variant and provider filtering");

// The welcome handler and standalone selector can both run at startup.
// Select before the welcome captures the model, without selecting twice.
let current = { provider: "openai", id: "gpt-5.5" };
let selections = 0;
let history = [];
const ctx = {
  get model() { return current; },
  modelRegistry: { getAvailable: () => models },
  sessionManager: { getBranch: () => history },
  ui: { notify: message => assert.fail(message) },
};
const pi = { setModel: async model => { current = model; selections++; return true; } };
await selectLatestChatGPT(pi, ctx);
const welcomeLabel = ctx.model.id;
await selectLatestChatGPT(pi, ctx);
assert.equal(welcomeLabel, "gpt-6.10-sol");
assert.equal(selections, 1);
history = [{ type: "message" }];
current = { provider: "openai", id: "gpt-5.5" };
await selectLatestChatGPT(pi, ctx);
assert.equal(current.id, "gpt-6.10-sol", "Existing conversations must also use the latest model");
const originalArgs = process.argv;
try {
  for (const args of [["--resume"], ["--continue"], ["-r"], ["--session", "saved.jsonl"]]) {
    process.argv = [...originalArgs.slice(0, 2), ...args];
    current = { provider: "openai", id: "gpt-5.5" };
    await selectLatestChatGPT(pi, ctx);
    assert.equal(current.id, "gpt-6.10-sol");
  }
  process.argv = [...originalArgs.slice(0, 2), "--model", "gpt-5.5"];
  current = { provider: "openai", id: "gpt-5.5" };
  await selectLatestChatGPT(pi, ctx);
  assert.equal(current.id, "gpt-5.5", "Explicit model choices remain respected");
} finally { process.argv = originalArgs; }
console.log("PASS: selection before welcome, repeat startup, resumed sessions upgraded, explicit model preserved");

if (process.argv.includes("--live")) {
  const directory = mkdtempSync(join(tmpdir(), "pi-model-resume-"));
  try {
    const session = join(directory, "old-model.jsonl");
    const timestamp = new Date().toISOString();
    writeFileSync(session, [
      { type: "session", version: 3, id: "model-resume-check", timestamp, cwd: process.cwd() },
      { type: "model_change", id: "11111111", parentId: null, timestamp, provider: "openai", modelId: "gpt-5.5" },
      { type: "message", id: "22222222", parentId: "11111111", timestamp,
        message: { role: "user", content: [{ type: "text", text: "Reply briefly." }], timestamp: Date.now() } },
    ].map(entry => JSON.stringify(entry)).join("\n") + "\n");
    for (const [label, sessionArgs] of [["fresh", ["--no-session"]], ["resumed GPT-5.5", ["--session", session]]]) {
      const result = spawnSync("pi", ["--offline", "--no-mcp", "--no-skills", "--no-prompt-templates",
        "--no-context-files", "--no-tools", ...sessionArgs, "--thinking", "off", "--mode", "json",
        "-p", "Reply with exactly PI_CONNECTION_OK."], { encoding: "utf8", timeout: 60000 });
      if (result.stderr) process.stderr.write(result.stderr);
      assert.equal(result.status, 0, result.error?.message ?? result.stdout);
      const events = result.stdout.split("\n").filter(line => line.startsWith("{")).map(line => JSON.parse(line));
      const reply = events.findLast(event => event.type === "message_end" && event.message.role === "assistant")?.message;
      assert.ok(reply, "No assistant reply");
      assert.ok(reply.content.some(part => part.type === "text" && part.text.trim() === "PI_CONNECTION_OK"));
      assert.notEqual(reply.model, "gpt-5.5", "A saved unsupported model must be replaced");
      console.log(`PASS: ${label} session live reply from ${reply.provider}/${reply.model}`);
    }
  } finally { rmSync(directory, { recursive: true, force: true }); }
}
