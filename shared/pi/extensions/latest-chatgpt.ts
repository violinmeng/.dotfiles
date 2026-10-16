import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Compare release numbers numerically: 6.10 must sort after 6.9. Exclude
// specialist, preview, mini, and Pro variants from the general-purpose default.
export function latestChatGPT<T extends { provider: string; id: string }>(models: readonly T[]): T | undefined {
  return models
    .filter((model) => model.provider === "openai" && /^gpt-\d+(?:\.\d+)?(?:-sol)?$/.test(model.id))
    .sort((a, b) => b.id.localeCompare(a.id, "en", { numeric: true }))[0];
}

export default function latestChatGPTExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (event, ctx) => {
    // Keep resumed conversations and explicit command-line model choices.
    const args = process.argv.slice(2);
    const end = args.indexOf("--");
    const options = end < 0 ? args : args.slice(0, end);
    if (event.reason !== "startup" && event.reason !== "new") return;
    if (options.some((arg) => /^(?:--(?:model|models|provider|session|session-id|resume|continue)|-[cr])(?:=|$)/.test(arg))) return;
    if (ctx.sessionManager.getBranch().some((entry) => entry.type === "message")) return;

    const model = latestChatGPT(ctx.modelRegistry.getAvailable());
    if (model && !(await pi.setModel(model))) {
      ctx.ui.notify(`Could not select latest ChatGPT model: ${model.id}`, "warning");
    }
  });
}
