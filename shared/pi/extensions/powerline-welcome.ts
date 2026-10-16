import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Component } from "@earendil-works/pi-tui";
import { selectLatestChatGPT } from "./latest-chatgpt.ts";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Fixed Pi brand colors from Pi 1.3's interactive/components/pi-logo renderer.
const coral = "\x1b[38;2;228;138;122m";
const blue = "\x1b[38;2;79;142;179m";
const yellow = "\x1b[38;2;234;182;93m";
const reset = "\x1b[0m";
const logoRows = [
	"██████████    ",
	"████  ████    ",
	"████  ████    ",
	"████████  ████",
	"████      ████",
	"████      ████",
];
const sgr = /\x1b\[[0-9;]*m/g;
const gradientBlock = "\\x1b\\[38;5;(?:199|171|135|99|75|51)m█\\x1b\\[0m";

// Pi's 4×4 square-pixel artwork, enlarged threefold. Half blocks retain
// equal stroke and gap widths within Powerline's existing 14×6-cell slot.
const pixels = [
	[coral, coral, coral, ""],
	[blue, "", coral, ""],
	[blue, blue, "", yellow],
	[blue, "", "", yellow],
];
const scaledPixels = pixels.flatMap(row =>
	Array.from({ length: 3 }, () => row.flatMap(color => [color, color, color])));
const welcomeLogo = Array.from({ length: 6 }, (_, row) => {
	const top = scaledPixels[row * 2]!;
	const bottom = scaledPixels[row * 2 + 1]!;
	return " " + top.map((upper, column) => {
		const lower = bottom[column]!;
		if (upper === lower) return upper ? upper + "█" + reset : " ";
		if (!lower) return upper + "▀" + reset;
		if (!upper) return lower + "▄" + reset;
		return upper + lower.replace("[38;", "[48;") + "▀" + reset;
	}).join("") + " ";
});

/** Match only Powerline 0.12.3's logo; preserve the box, text and widths. */
export function colorizeWelcomeLogo(lines: string[]): string[] {
	const plain = lines.map(line => line.replace(sgr, ""));
	const start = plain.findIndex((line, index) => {
		const column = line.indexOf(logoRows[0]!);
		return column >= 0 && logoRows.every((row, offset) =>
			plain[index + offset]?.slice(column, column + row.length) === row);
	});
	if (start < 0) return lines;

	const patterns = logoRows.map(row => new RegExp(
		[...row].map(char => char === "█" ? gradientBlock : " ").join("")));
	if (!patterns.every((pattern, row) => pattern.test(lines[start + row]!))) return lines;
	return lines.map((line, index) => {
		const row = index - start;
		return row >= 0 && row < logoRows.length
			? line.replace(patterns[row]!, () => welcomeLogo[row]!) : line;
	});
}

function colorizeComponent<T extends Component>(component: T): T {
	const render = component.render.bind(component);
	component.render = width => colorizeWelcomeLogo(render(width));
	return component;
}

function welcomeContext(ctx: ExtensionContext): ExtensionContext {
	const ui = ctx.ui;
	const styledUi = new Proxy(ui, {
		get(target, property, receiver) {
			if (property === "custom") {
				return (factory: Parameters<typeof ui.custom>[0], options: Parameters<typeof ui.custom>[1]) =>
					ui.custom(async (...args) => colorizeComponent(await factory(...args)), options);
			}
			if (property === "setHeader") {
				return (factory: Parameters<typeof ui.setHeader>[0]) =>
					ui.setHeader(factory ? (...args) => colorizeComponent(factory(...args)) : undefined);
			}
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});
	return new Proxy(ctx, {
		get(target, property, receiver) {
			if (property === "ui") return styledUi;
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});
}

/** Keep the pinned package pristine; adapt its welcome UI at registration time. */
export default async function powerlineWelcome(pi: ExtensionAPI): Promise<void> {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	const moduleUrl = pathToFileURL(join(agentDir, "npm/node_modules/pi-powerline-footer/index.ts")).href;
	const powerline = await import(moduleUrl);
	const api = new Proxy(pi, {
		get(target, property, receiver) {
			if (property === "on") {
				return (event: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => {
					if (event === "session_start") {
						return pi.on("session_start", async (event, ctx) => {
						await selectLatestChatGPT(pi, ctx);
						await handler(event, welcomeContext(ctx));
					});
					}
					return Reflect.get(target, property, receiver).call(target, event, handler);
				};
			}
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});
	await powerline.default(api);
}
