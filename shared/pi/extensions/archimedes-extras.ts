import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

interface DiffConfig {
	diffTheme: string;
	diffSplitMinWidth: number;
	diffSplitMinCodeWidth: number;
}

const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const diffModuleUrl = pathToFileURL(join(agentDir, "npm/node_modules/@pi-archimedes/diff/src/index.ts")).href;
const imagePasteModuleUrl = pathToFileURL(join(agentDir, "npm/node_modules/@pi-archimedes/image-paste/src/index.ts")).href;

const DEFAULT_DIFF_CONFIG: DiffConfig = {
	diffTheme: "github-dark",
	diffSplitMinWidth: 150,
	diffSplitMinCodeWidth: 60,
};

export default function archimedesExtras(pi: ExtensionAPI): void {
	let currentContext: ExtensionContext | undefined;
	let shutdownImagePaste: (() => void) | undefined;

	pi.on("session_start", async (_event, ctx) => {
		currentContext = ctx;

		const [diff, imagePaste] = await Promise.all([
			import(diffModuleUrl),
			import(imagePasteModuleUrl),
		]);

		diff.registerDiffTools(pi, () => currentContext!.ui.theme, () => DEFAULT_DIFF_CONFIG);

		// Pi owns Alt+V for native file-path paste. Skip that one registration
		// while retaining Archimedes previews on Ctrl+V and Ctrl+Alt+V.
		const imagePasteApi = new Proxy(pi, {
			get(target, property, receiver) {
				if (property === "registerShortcut") {
					return (key: string, options: unknown): void => {
						if (key !== "alt+v") {
							pi.registerShortcut(key as Parameters<ExtensionAPI["registerShortcut"]>[0], options as Parameters<ExtensionAPI["registerShortcut"]>[1]);
						}
					};
				}
				const value = Reflect.get(target, property, receiver);
				return typeof value === "function" ? value.bind(target) : value;
			},
		});
		imagePaste.registerImagePaste(imagePasteApi);
		imagePaste.initImagePasteSession(ctx);
		shutdownImagePaste = imagePaste.shutdownImagePaste;
	});

	pi.on("session_shutdown", () => {
		shutdownImagePaste?.();
		shutdownImagePaste = undefined;
		currentContext = undefined;
	});
}
