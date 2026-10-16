import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Component } from "@earendil-works/pi-tui";
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
const gradientBlock = /\x1b\[38;5;(?:199|171|135|99|75|51)m█\x1b\[0m/g;

/** Recolor only Powerline 0.12.3's logo; leave the box, text and widths intact. */
export function colorizeWelcomeLogo(lines: string[]): string[] {
	const plain = lines.map(line => line.replace(sgr, ""));
	const start = plain.findIndex((line, index) => {
		const column = line.indexOf(logoRows[0]!);
		return column >= 0 && logoRows.every((row, offset) =>
			plain[index + offset]?.slice(column, column + row.length) === row);
	});
	if (start < 0) return lines;

	return lines.map((line, index) => {
		const row = index - start;
		if (row < 0 || row >= logoRows.length) return line;
		let block = 0;
		const blockCount = logoRows[row]!.replaceAll(" ", "").length;
		return line.replace(gradientBlock, original => {
			if (block >= blockCount) return original;
			const color = row === 0 ? coral
				: row < 3 ? (block < 4 ? blue : coral)
				: block < (row === 3 ? 8 : 4) ? blue : yellow;
			block++;
			return color + "█" + reset;
		});
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
						return pi.on("session_start", (event, ctx) => handler(event, welcomeContext(ctx)) as void | Promise<void>);
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
