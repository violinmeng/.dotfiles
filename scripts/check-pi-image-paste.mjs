#!/usr/bin/env node
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { pathToFileURL } from "node:url";

const entry = realpathSync(process.env.DOTFILES_PI_ENTRYPOINT ?? join(homedir(), ".local/bin/pi"));
let root = dirname(entry);
while (!existsSync(join(root, "package.json")) || JSON.parse(readFileSync(join(root, "package.json"), "utf8")).name !== "@earendil-works/pi-coding-agent") {
  const parent = dirname(root);
  assert.notEqual(parent, root, "Cannot locate Pi's package root");
  root = parent;
}
const require = createRequire(join(root, "package.json"));
const { createEventBus } = await import(pathToFileURL(join(root, "dist/core/event-bus.js")).href);
const { createExtensionRuntime, loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")).href);
const { loadThemeFromPath, setThemeInstance, theme } = await import(pathToFileURL(join(root, "dist/modes/interactive/theme/theme.js")).href);
const { setCapabilities } = await import(pathToFileURL(require.resolve("@earendil-works/pi-tui")).href);
setCapabilities({ images: null, trueColor: true, hyperlinks: false });
setThemeInstance(loadThemeFromPath(resolve("shared/pi/themes/omp-titanium.json"), "truecolor"));
const runtime = createExtensionRuntime();
const messages = [];
runtime.sendMessage = message => messages.push(message);
const loaded = await loadExtensions([resolve("shared/pi/extensions/archimedes-extras.ts")], process.cwd(), createEventBus(), runtime);
assert.deepEqual(loaded.errors, []);
const extension = loaded.extensions[0];
let draft = "";
const notices = [];
const context = { hasUI: true, ui: { theme,
  pasteToEditor: text => { draft += text; },
  notify: text => notices.push(text),
} };
for (const handler of extension.handlers.get("session_start") ?? []) await handler({ type: "session_start", reason: "startup" }, context);
try {
  const renderer = extension.messageRenderers.get("hephaestus-image-preview");
  assert.ok(renderer, "Image preview renderer was not registered");
  assert.ok(extension.shortcuts.has("ctrl+v"), "Ctrl+V image shortcut was not registered");
  const data = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ZkAAAAASUVORK5CYII=";
  const component = renderer({ customType: "hephaestus-image-preview", content: [{ type: "image", data, mimeType: "image/png" }], display: true, timestamp: Date.now() }, { expanded: false }, theme);
  assert.ok(component, "Image preview did not produce a component");
  if (process.argv.includes("--expect-crash")) {
    assert.throws(() => component.render(80), /tokenAnsi/);
    console.log("REPRODUCED: unbound Theme.fg crashes deferred image preview rendering");
  } else {
    const lines = component.render(80);
    assert.ok(lines.some(line => line.includes("image/png")), "Fallback image preview was not rendered");
    component.invalidate();
    assert.doesNotThrow(() => component.render(40));
    console.log("PASS: real image-paste extension registers Ctrl+V and renders image fallback across redraws");
    if (process.argv.includes("--clipboard")) {
      const types = execFileSync("wl-paste", ["--list-types"], { encoding: "utf8", timeout: 5000 }).trim().split("\n");
      const mime = types.find(type => type.startsWith("image/")) ?? types.find(type => type.startsWith("text/plain")) ?? types[0];
      const original = mime ? execFileSync("wl-paste", ["--no-newline", "--type", mime], { timeout: 5000 }) : undefined;
      try {
        execFileSync("wl-copy", ["--type", "image/png"], { input: Buffer.from(data, "base64"), stdio: ["pipe", "ignore", "ignore"], timeout: 5000 });
        await extension.shortcuts.get("ctrl+v").handler(context);
        assert.ok(draft.includes("[Image #1]"), notices.join("; "));
        const results = [];
        for (const handler of extension.handlers.get("input") ?? []) {
          results.push(await handler({ type: "input", source: "interactive", text: draft, images: [] }, context));
        }
        const submission = results.find(result => result?.action === "transform");
        assert.equal(submission?.images[0]?.data, data, "Clipboard image did not reach the outgoing input");
        assert.equal(submission.images[0].mimeType, "image/png");
        assert.equal(messages.length, 1, "Image preview message was not emitted");
        const preview = renderer(messages[0], { expanded: false }, theme);
        assert.ok(preview);
        assert.doesNotThrow(() => preview.render(80));
        console.log("PASS: Wayland clipboard -> Ctrl+V -> draft -> input image -> preview; no model request");
      } finally {
        if (mime) execFileSync("wl-copy", ["--type", mime], { input: original, stdio: ["pipe", "ignore", "ignore"], timeout: 5000 });
        else execFileSync("wl-copy", ["--clear"], { stdio: "ignore", timeout: 5000 });
      }
    }
  }
} finally {
  for (const handler of extension.handlers.get("session_shutdown") ?? []) await handler({ type: "session_shutdown" }, context);
}
