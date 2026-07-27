/**
 * Vim Reply Example
 *
 * Opens the last assistant response (or all assistant responses on the active branch)
 * in an external markdown editor with a prompt area at the bottom. When the editor
 * exits, only the text below the marker is copied back into pi's input editor, or
 * sent immediately with --send.
 *
 * Usage:
 *   /vim-reply                       - Open last assistant response, load prompt into editor
 *   /vim-reply --send                - Open last assistant response, send prompt on save/quit
 *   /vim-reply all                   - Include all assistant responses on the active branch
 *   /vim-reply --all --send Draft... - Include all responses and prefill the prompt area
 */

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
	SessionEntry,
	SessionMessageEntry,
} from "@earendil-works/pi-coding-agent";
import { Container, Text, type TUI } from "@earendil-works/pi-tui";

interface CommandOptions {
	includeAll: boolean;
	sendImmediately: boolean;
	initialPrompt: string;
}

interface EditorCommand {
	display: string;
	command: string;
	args: string[];
}

interface ReferenceDocument {
	content: string;
	marker: string;
}

function parseCommandOptions(args: string): CommandOptions {
	const parts = args.trim().length > 0 ? args.trim().split(/\s+/) : [];
	let includeAll = false;
	let sendImmediately = false;
	let index = 0;

	for (; index < parts.length; index++) {
		const part = parts[index];
		if (part === undefined) break;
		if (part === "--") {
			index += 1;
			break;
		}
		if (part === "all" || part === "--all") {
			includeAll = true;
			continue;
		}
		if (part === "last" || part === "--last") {
			includeAll = false;
			continue;
		}
		if (part === "--send") {
			sendImmediately = true;
			continue;
		}
		break;
	}

	return {
		includeAll,
		sendImmediately,
		initialPrompt: parts.slice(index).join(" "),
	};
}

function isMessageEntry(entry: SessionEntry): entry is SessionMessageEntry {
	return entry.type === "message";
}

function extractAssistantText(entry: SessionMessageEntry): string {
	const message = entry.message;
	if (message.role !== "assistant") return "";

	const parts: string[] = [];
	for (const block of message.content) {
		if (block.type === "text") {
			parts.push(block.text);
		}
	}
	return parts.join("\n\n").trim();
}

function getAssistantResponseEntries(branch: readonly SessionEntry[], includeAll: boolean): SessionMessageEntry[] {
	const assistantEntries = branch.filter(isMessageEntry).filter((entry) => entry.message.role === "assistant");
	if (includeAll) return assistantEntries;
	const last = assistantEntries.at(-1);
	return last ? [last] : [];
}

function buildReferenceMarkdown(entries: readonly SessionMessageEntry[], includeAll: boolean): string {
	const sections = entries
		.map((entry) => {
			const text = extractAssistantText(entry);
			if (!text) return undefined;
			return text;
		})
		.filter((section): section is string => section !== undefined);

	return sections.join(includeAll ? "\n\n---\n\n" : "\n\n");
}

function buildEditorDocument(referenceMarkdown: string, initialPrompt: string): ReferenceDocument {
	const marker = `<!-- PI_VIM_REPLY_PROMPT_BELOW:${randomUUID()} -->`;
	const content = [
		referenceMarkdown,
		"",
		"## Next prompt",
		marker,
		"",
		initialPrompt,
		"",
	].join("\n");

	return { content, marker };
}

function extractPromptAfterMarker(content: string, marker: string): string | undefined {
	const markerIndex = content.indexOf(marker);
	if (markerIndex === -1) return undefined;
	return content.slice(markerIndex + marker.length).trim();
}

function getEditorCommand(): EditorCommand {
	const display = process.env.VISUAL?.trim() || process.env.EDITOR?.trim() || "nvim";
	const [command, ...args] = display.split(/\s+/);
	return {
		display,
		command: command || "nvim",
		args,
	};
}

async function waitForEditor(command: EditorCommand, filePath: string): Promise<number | null> {
	return new Promise((resolve) => {
		const child = spawn(command.command, [...command.args, filePath], {
			stdio: "inherit",
			shell: process.platform === "win32",
		});
		child.on("error", () => resolve(null));
		child.on("close", (code) => resolve(code));
	});
}

async function openExternalEditor(tui: TUI, document: ReferenceDocument): Promise<string | undefined> {
	const tempDir = await mkdtemp(join(tmpdir(), "pi-vim-reply-"));
	const tempFile = join(tempDir, "reply.md");
	const editor = getEditorCommand();

	try {
		await writeFile(tempFile, document.content, "utf8");

		tui.stop();
		try {
			process.stdout.write(`Launching external editor: ${editor.display}\nPi will resume when the editor exits.\n`);
			const status = await waitForEditor(editor, tempFile);
			if (status !== 0) return undefined;
			const edited = await readFile(tempFile, "utf8");
			return extractPromptAfterMarker(edited, document.marker);
		} finally {
			tui.start();
			tui.requestRender(true);
		}
	} finally {
		await rm(tempDir, { recursive: true, force: true });
	}
}

async function editPromptInExternalEditor(
	ctx: ExtensionCommandContext,
	document: ReferenceDocument,
): Promise<string | undefined> {
	if (ctx.mode !== "tui") return undefined;

	return ctx.ui.custom<string | undefined>((tui, theme, _keybindings, done) => {
		const container = new Container();
		container.addChild(new Text(theme.fg("accent", "Opening external editor..."), 1, 0));

		setTimeout(() => {
			void openExternalEditor(tui, document)
				.then(done)
				.catch((error: unknown) => {
					const message = error instanceof Error ? error.message : String(error);
					process.stderr.write(`Failed to open external editor: ${message}\n`);
					done(undefined);
				});
		}, 0);

		return container;
	});
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("vim-reply", {
		description: "Open assistant response(s) in an external markdown editor and draft the next prompt",
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/vim-reply requires interactive TUI mode", "warning");
				return;
			}

			if (!ctx.isIdle()) {
				ctx.ui.notify("Wait for the agent to finish before opening /vim-reply", "warning");
				return;
			}

			const options = parseCommandOptions(args);
			const responseEntries = getAssistantResponseEntries(ctx.sessionManager.getBranch(), options.includeAll);
			const referenceMarkdown = buildReferenceMarkdown(responseEntries, options.includeAll);
			if (!referenceMarkdown.trim()) {
				ctx.ui.notify("No assistant response text found", "warning");
				return;
			}

			const document = buildEditorDocument(referenceMarkdown, options.initialPrompt);
			const prompt = await editPromptInExternalEditor(ctx, document);
			if (prompt === undefined) {
				ctx.ui.notify("Editor cancelled or failed", "info");
				return;
			}

			if (!prompt.trim()) {
				ctx.ui.notify("No prompt entered below the marker", "info");
				return;
			}

			if (options.sendImmediately) {
				ctx.ui.setEditorText("");
				pi.sendUserMessage(prompt);
				return;
			}

			ctx.ui.setEditorText(prompt);
			ctx.ui.notify("Prompt loaded into editor. Press Enter to submit.", "info");
		},
	});
}
