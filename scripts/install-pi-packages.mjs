#!/usr/bin/env node
// Install only the sources already declared by the dotfiles. No settings rewrite,
// provider requests, sessions, or project-local extensions are involved.
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

const install = process.argv.includes("--install");
const entry = realpathSync(process.env.DOTFILES_PI_ENTRYPOINT);
let root = dirname(entry);
while (true) {
  const manifest = join(root, "package.json");
  if (existsSync(manifest) && JSON.parse(readFileSync(manifest, "utf8")).name === "@earendil-works/pi-coding-agent") break;
  const parent = dirname(root);
  assert.notEqual(parent, root, "Cannot locate Pi's package root");
  root = parent;
}
const { DefaultPackageManager, DefaultResourceLoader, SettingsManager } = await import(pathToFileURL(join(root, "dist/index.js")).href);
const agentDir = realpathSync(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi/agent"));
const settingsFile = join(agentDir, "settings.json");
const original = readFileSync(settingsFile, "utf8");
const settings = JSON.parse(original);
assert(Array.isArray(settings.packages), "Pi configuration has no packages manifest");
const settingsManager = SettingsManager.inMemory(settings, { projectTrusted: false });
const manager = new DefaultPackageManager({ cwd: process.cwd(), agentDir, settingsManager });
await manager.resolve(install ? undefined : async source => { throw new Error(`Missing configured package: ${source}`); });
for (const entry of manager.listConfiguredPackages()) {
  assert(entry.installedPath && existsSync(entry.installedPath), `Package missing: ${entry.source}`);
  const pin = entry.source.slice(entry.source.lastIndexOf("@") + 1);
  if (entry.source.startsWith("git:")) {
    const commit = execFileSync("git", ["-C", entry.installedPath, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
    assert.equal(commit, pin, `Wrong Git commit: ${entry.source}`);
  } else if (entry.source.startsWith("npm:")) {
    const installed = JSON.parse(readFileSync(join(entry.installedPath, "package.json"), "utf8"));
    assert.equal(installed.version, pin, `Wrong npm version: ${entry.source}`);
  }
}
// A second resolve must not download anything on the next startup.
await manager.resolve(async source => { throw new Error(`Startup would reinstall ${source}`); });
const resources = new DefaultResourceLoader({ cwd: process.cwd(), agentDir, settingsManager });
await resources.reload();
const extensions = resources.getExtensions();
for (const { path, error } of extensions.errors) console.error(`Extension failed: ${path}\n${error}`);
assert.equal(extensions.errors.length, 0, "Pi extension loading failed");
assert(resources.getThemes().themes.some(theme => theme.name === settings.theme),
  `Configured theme was not loaded: ${settings.theme}`);
// The bundled and modular loaders differ. Verify the actual launcher too,
// without a prompt, credentials request, persisted session, or provider call.
await new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [entry, "--mode", "rpc", "--no-session"], {
    cwd: process.cwd(), env: { ...process.env, PI_SKIP_VERSION_CHECK: "1" }, stdio: ["pipe", "pipe", "pipe"],
  });
  let output = "", errors = "", settled = false;
  const timeout = setTimeout(() => finish(new Error("Pi RPC startup timed out")), 30000);
  function finish(error) {
    if (settled) return;
    settled = true;
    clearTimeout(timeout);
    child.kill("SIGTERM");
    if (error) reject(error); else resolve();
  }
  child.on("error", finish);
  child.on("exit", code => { if (!settled) finish(new Error(`Pi exited before startup: ${code} ${errors}`)); });
  child.stderr.on("data", chunk => { errors += chunk; });
  child.stdout.on("data", chunk => {
    output += chunk;
    let end;
    while ((end = output.indexOf("\n")) >= 0) {
      const line = output.slice(0, end); output = output.slice(end + 1);
      let response;
      try { response = JSON.parse(line); } catch { continue; }
      if (response.type === "extension_error") finish(new Error(JSON.stringify(response)));
      if (response.type === "response" && response.id === "dotfiles-startup-check") {
        if (!response.success) finish(new Error("Pi rejected the startup check"));
        else child.stdin.write(JSON.stringify({ id: "dotfiles-native-mcp-check", type: "get_commands" }) + "\n");
      }
      if (response.type === "response" && response.id === "dotfiles-native-mcp-check") {
        const mcpCommands = response.data?.commands?.filter(command => command.name === "mcp") ?? [];
        if (!response.success || mcpCommands.length !== 1 || mcpCommands[0].sourceInfo?.path !== "builtin:mcp") {
          finish(new Error("Pi's /mcp command must be provided by builtin:mcp, not an adapter"));
        } else setTimeout(() => finish(/Failed to load extension|Error in extension/i.test(errors)
          ? new Error(errors) : undefined), 750);
      }
    }
  });
  child.stdin.write(JSON.stringify({ id: "dotfiles-startup-check", type: "get_state" }) + "\n");
});
assert.equal(readFileSync(settingsFile, "utf8"), original, "Package setup changed the configuration");
console.log(`Verified ${settings.packages.length} configured packages, ${extensions.extensions.length} extensions; theme=${settings.theme}; RPC startup OK; native MCP OK; startup-installs=0`);
