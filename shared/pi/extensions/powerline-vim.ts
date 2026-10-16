import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

type SessionStartEvent = { reason?: string };
type SessionShutdownEvent = { reason?: string };
type StartHandler = (event: SessionStartEvent, ctx: ExtensionContext) => void | Promise<void>;
type ShutdownHandler = (event: SessionShutdownEvent) => void | Promise<void>;
type PiVimActivator = (pi: ExtensionAPI) => void;
type ThemeLike = { bg?: (token: string, text: string) => string };
type LayoutLine = { text: string; hasCursor?: boolean; cursorPos?: number };
type VisualPosition = { line: number; col: number };
type VisualEditor = {
	render(width: number): string[];
	getMode(): string;
	getLines(): string[];
	getCursor(): VisualPosition;
	visualAnchor?: VisualPosition | null;
	layoutText?(width: number): LayoutLine[];
	lastWidth?: number;
	scrollOffset?: number;
	paddingX?: number;
	tui?: { terminal?: { rows?: number } };
};
type EditorFactory = (tui: unknown, theme: unknown, keybindings: unknown) => VisualEditor;

const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const piVimModuleUrl = pathToFileURL(join(agentDir, "npm/node_modules/pi-vim/index.ts")).href;
const cursorMarker = "\x1b_pi:c\x07";
const csiPattern = /^\x1b\[[0-?]*[ -/]*[@-~]/;
const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

function backgroundCodes(theme: ThemeLike): { open: string; close: string } | undefined {
	if (typeof theme.bg !== "function") return undefined;
	const marker = "\uE000";
	const painted = theme.bg("selectedBg", marker);
	const markerIndex = painted.indexOf(marker);
	if (markerIndex < 0) return undefined;
	return {
		open: painted.slice(0, markerIndex),
		close: painted.slice(markerIndex + marker.length),
	};
}

function sgrMayResetBackground(code: string): boolean {
	if (!code.endsWith("m")) return false;
	const body = code.slice(2, -1);
	if (body === "" || body === "0") return true;
	const params = body.split(";").map(Number);
	return params.includes(0) || params.includes(49) || params.includes(48) ||
		params.some(value => (value >= 40 && value <= 47) || (value >= 100 && value <= 107));
}

/** Paint a terminal-column range while preserving Pi's cursor/style escapes. */
function paintColumns(
	line: string,
	startColumn: number,
	endColumn: number,
	codes: { open: string; close: string },
): string {
	if (endColumn <= startColumn) return line;

	let output = "";
	let column = 0;
	let index = 0;
	let painting = false;

	const setPainting = (next: boolean): void => {
		if (painting === next) return;
		output += next ? codes.open : codes.close;
		painting = next;
	};

	while (index < line.length) {
		if (line.startsWith(cursorMarker, index)) {
			output += cursorMarker;
			index += cursorMarker.length;
			continue;
		}

		if (line[index] === "\x1b") {
			const match = csiPattern.exec(line.slice(index));
			if (match) {
				output += match[0];
				index += match[0].length;
				if (painting && sgrMayResetBackground(match[0])) output += codes.open;
				continue;
			}
		}

		const nextEscape = line.indexOf("\x1b", index);
		const end = nextEscape < 0 ? line.length : nextEscape;
		const plain = line.slice(index, end);
		for (const { segment } of graphemeSegmenter.segment(plain)) {
			const width = visibleWidth(segment);
			const selected = column < endColumn && column + Math.max(width, 1) > startColumn;
			setPainting(selected);
			output += segment;
			column += width;
			if (painting && column >= endColumn) setPainting(false);
		}
		index = end;
	}

	setPainting(false);
	return output;
}

function inclusiveEndColumn(line: string, column: number): number {
	if (column >= line.length) return line.length;
	for (const segment of graphemeSegmenter.segment(line)) {
		if (column < segment.index + segment.segment.length) {
			return segment.index + segment.segment.length;
		}
	}
	return line.length;
}

function mapLayoutLines(layout: LayoutLine[], sourceLines: string[]): Array<{
	logicalLine: number;
	startCol: number;
	endCol: number;
	text: string;
}> {
	const mapped: Array<{ logicalLine: number; startCol: number; endCol: number; text: string }> = [];
	let logicalLine = 0;
	let sourceColumn = 0;

	for (const item of layout) {
		const source = sourceLines[logicalLine] ?? "";
		const startCol = sourceColumn;
		const endCol = Math.min(source.length, startCol + item.text.length);
		mapped.push({ logicalLine, startCol, endCol, text: item.text });

		if (source.length === 0 || endCol >= source.length) {
			logicalLine++;
			sourceColumn = 0;
		} else {
			sourceColumn = endCol;
		}
	}
	return mapped;
}

function installVisualSelectionHighlight(editor: VisualEditor, theme: ThemeLike): void {
	if (typeof editor.render !== "function" || typeof editor.layoutText !== "function") return;
	const codes = backgroundCodes(theme);
	if (!codes) return;

	const baseRender = editor.render.bind(editor);
	editor.render = (width: number): string[] => {
		const rendered = baseRender(width);
		const mode = editor.getMode?.();
		if (mode !== "visual" && mode !== "visual-line") return rendered;

		const sourceLines = editor.getLines?.() ?? [];
		const anchor = editor.visualAnchor;
		const cursor = editor.getCursor?.();
		const layoutWidth = editor.lastWidth;
		if (!anchor || !cursor || !layoutWidth || sourceLines.length === 0) return rendered;

		const layout = editor.layoutText?.(layoutWidth) ?? [];
		const mapped = mapLayoutLines(layout, sourceLines);
		const scrollOffset = Math.max(0, editor.scrollOffset ?? 0);
		const terminalRows = editor.tui?.terminal?.rows ?? 24;
		const visibleCount = Math.min(mapped.length - scrollOffset, Math.max(5, Math.floor(terminalRows * 0.3)));
		const maxPadding = Math.max(0, Math.floor((width - 1) / 2));
		const padding = Math.min(editor.paddingX ?? 0, maxPadding);

		const start = anchor.line < cursor.line || (anchor.line === cursor.line && anchor.col <= cursor.col)
			? anchor
			: cursor;
		const end = start === anchor ? cursor : anchor;

		for (let visibleIndex = 0; visibleIndex < visibleCount; visibleIndex++) {
			const item = mapped[scrollOffset + visibleIndex];
			const outputIndex = visibleIndex + 1; // top border occupies row zero
			if (!item || rendered[outputIndex] === undefined) continue;
			if (item.logicalLine < start.line || item.logicalLine > end.line) continue;

			const sourceLine = sourceLines[item.logicalLine] ?? "";
			const selectionStart = mode === "visual-line"
				? 0
				: item.logicalLine === start.line ? start.col : 0;
			const selectionEnd = mode === "visual-line"
				? sourceLine.length
				: item.logicalLine === end.line ? inclusiveEndColumn(sourceLine, end.col) : sourceLine.length;
			const intersectionStart = Math.max(item.startCol, selectionStart);
			const intersectionEnd = Math.min(item.endCol, selectionEnd);

			let startColumn: number;
			let endColumn: number;
			if (intersectionEnd > intersectionStart) {
				startColumn = padding + visibleWidth(item.text.slice(0, intersectionStart - item.startCol));
				endColumn = startColumn + visibleWidth(item.text.slice(
					intersectionStart - item.startCol,
					intersectionEnd - item.startCol,
				));
			} else if (mode === "visual-line" && sourceLine.length === 0) {
				startColumn = padding;
				endColumn = padding + 1;
			} else {
				continue;
			}

			rendered[outputIndex] = paintColumns(rendered[outputIndex]!, startColumn, endColumn, codes);
		}
		return rendered;
	};
}

function contextWithEnhancedEditor(ctx: ExtensionContext): ExtensionContext {
	const ui = ctx.ui;
	const piTheme = ui.theme as ThemeLike;
	const enhancedUi = new Proxy(ui, {
		get(target, property, receiver) {
			if (property === "setEditorComponent") {
				return (factory: EditorFactory): void => {
					ui.setEditorComponent(((tui: unknown, editorTheme: unknown, keybindings: unknown) => {
						const editor = factory(tui, editorTheme, keybindings);
						installVisualSelectionHighlight(editor, piTheme);
						return editor;
					}) as Parameters<typeof ui.setEditorComponent>[0]);
				};
			}
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});
	return new Proxy(ctx, {
		get(target, property, receiver) {
			if (property === "ui") return enhancedUi;
			const value = Reflect.get(target, property, receiver);
			return typeof value === "function" ? value.bind(target) : value;
		},
	});
}

/**
 * Powerline installs its editor during session_start. Activate pi-vim one tick
 * later so Vim owns input while Powerline keeps its status widgets, welcome UI,
 * footer data, and working messages. The editor wrapper adds the visual
 * selection paint layer that pi-vim 0.14.1 intentionally leaves unimplemented.
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
			void Promise.resolve(startPiVim?.(event, contextWithEnhancedEditor(ctx))).catch(error => {
				ctx.ui.notify(`Failed to activate pi-vim after Powerline: ${String(error)}`, "error");
			});
		}, 0);
	});

	pi.on("session_shutdown", async event => {
		generation++;
		await shutdownPiVim?.(event);
	});
}
