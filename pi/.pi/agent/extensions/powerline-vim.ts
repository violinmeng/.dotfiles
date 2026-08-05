import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

type SessionStartEvent = { reason?: string };
type SessionShutdownEvent = { reason?: string };
type StartHandler = (event: SessionStartEvent, ctx: ExtensionContext) => void | Promise<void>;
type ShutdownHandler = (event: SessionShutdownEvent) => void | Promise<void>;
type PiVimActivator = (pi: ExtensionAPI) => void;

const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const piVimModuleUrl = pathToFileURL(join(agentDir, "npm/node_modules/pi-vim/index.ts")).href;

/**
 * Powerline installs its editor during session_start. Activate pi-vim one tick
 * later so Vim owns input while Powerline keeps its status widgets, welcome UI,
 * footer data, and working messages.
 */
export default async function powerlineVim(pi: ExtensionAPI): Promise<void> {
	const piVimModule = await import(piVimModuleUrl);
	const activatePiVim = piVimModule.default as PiVimActivator;
	let startPiVim: StartHandler | undefined;
	let shutdownPiVim: ShutdownHandler | undefined;
	let generation = 0;

	const captureApi = new Proxy(pi, {
		get(target, property, receiver) {
			if (property === "on") {
				return (event: string, handler: StartHandler | ShutdownHandler): void => {
					if (event === "session_start") startPiVim = handler as StartHandler;
					if (event === "session_shutdown") shutdownPiVim = handler as ShutdownHandler;
				};
			}
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});

	activatePiVim(captureApi);

	pi.on("session_start", (event, ctx) => {
		const currentGeneration = ++generation;
		setTimeout(() => {
			if (currentGeneration !== generation) return;
			void Promise.resolve(startPiVim?.(event, ctx)).catch(error => {
				ctx.ui.notify(`Failed to activate pi-vim after Powerline: ${String(error)}`, "error");
			});
		}, 0);
	});

	pi.on("session_shutdown", async event => {
		generation++;
		await shutdownPiVim?.(event);
	});
}
