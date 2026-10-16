#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { latestChatGPT } from "../shared/pi/extensions/latest-chatgpt.ts";

const models = ["gpt-5.5", "gpt-6-sol", "gpt-6.1-sol", "gpt-6.9-sol", "gpt-6.10-sol",
  "gpt-7-mini", "gpt-7-pro", "gpt-7-preview", "gpt-7-astra"].map((id) => ({ provider: "openai", id }));
assert.equal(latestChatGPT(models)?.id, "gpt-6.10-sol");
assert.equal(latestChatGPT([...models, { provider: "openai", id: "gpt-7" }])?.id, "gpt-7");
assert.equal(latestChatGPT([{ provider: "other", id: "gpt-99-sol" }]), undefined);
assert.equal(latestChatGPT([]), undefined);
console.log("PASS: numeric release ordering, new releases, variant and provider filtering");

if (process.argv.includes("--live")) {
  const result = spawnSync("pi", ["--offline", "--no-mcp", "--no-skills", "--no-prompt-templates",
    "--no-context-files", "--no-tools", "--no-session", "--thinking", "off", "--mode", "json",
    "-p", "Reply with exactly PI_CONNECTION_OK."], { encoding: "utf8", timeout: 60000 });
  if (result.stderr) process.stderr.write(result.stderr);
  assert.equal(result.status, 0, result.error?.message ?? result.stdout);
  const events = result.stdout.split("\n").filter((line) => line.startsWith("{")).map((line) => JSON.parse(line));
  const reply = events.findLast((event) => event.type === "message_end" && event.message.role === "assistant")?.message;
  assert.ok(reply, "No assistant reply");
  assert.ok(reply.content.some((part) => part.type === "text" && part.text.trim() === "PI_CONNECTION_OK"));
  console.log(`PASS: live reply from ${reply.provider}/${reply.model} with configured extensions`);
}
