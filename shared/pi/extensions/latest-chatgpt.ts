import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Compare release numbers numerically: 6.10 must sort after 6.9. Exclude
// specialist, preview, mini, and Pro variants from the general-purpose default.
export function latestChatGPT<T extends { provider: string; id: string }>(models: readonly T[]): T | undefined {
  return models
    .filter((model) => model.provider === "openai" && /^gpt-\d+(?:\.\d+)?(?:-sol)?$/.test(model.id))
    .sort((a, b) => b.id.localeCompare(a.id, "en", { numeric: true }))[0];
}

// Also called before Powerline captures its welcome-screen model label.
export async function selectLatestChatGPT(pi: ExtensionAPI, ctx: ExtensionContext) {
  // Explicit model choices win; saved models in resumed sessions do not pin
  // the automatic default to an older release.
  const args = process.argv.slice(2);
  const end = args.indexOf("--");
  const options = end < 0 ? args : args.slice(0, end);
  if (options.some((arg) => /^(?:--(?:model|models|provider))(?:=|$)/.test(arg))) return;

  const model = latestChatGPT(ctx.modelRegistry.getAvailable());
  if (model && (ctx.model?.provider !== model.provider || ctx.model?.id !== model.id)
    && !(await pi.setModel(model))) {
    ctx.ui.notify(`Could not select latest ChatGPT model: ${model.id}`, "warning");
  }
}

export default function latestChatGPTExtension(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => selectLatestChatGPT(pi, ctx));
}
