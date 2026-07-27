import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { lstat, mkdir, readFile, realpath, rm } from "node:fs/promises";
import { isAbsolute, join, relative, sep } from "node:path";
import { BorderedLoader, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Container, Image, matchesKey, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const CODEX_TIMEOUT_MS = 10 * 60 * 1000;
const KILL_GRACE_MS = 5_000;
const KILL_SETTLE_MS = 2_000;
const MAX_CAPTURE_CHARS = 128_000;
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

interface CodexCommandResult {
	stdout: string;
	stderr: string;
	code: number;
}

interface CodexImageDetails {
	path: string;
	bytes: number;
	codexMessage: string;
}

interface GeneratedImage {
	path: string;
	image: Buffer;
	codexMessage: string;
}

function isWithin(root: string, target: string): boolean {
	const rel = relative(root, target);
	return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
}

function tail(text: string, maxLength = 8_000): string {
	return text.length <= maxLength ? text : `[...truncated...]\n${text.slice(-maxLength)}`;
}

function appendTail(current: string, chunk: Buffer | string): string {
	const combined = current + chunk.toString();
	return combined.length <= MAX_CAPTURE_CHARS ? combined : combined.slice(-MAX_CAPTURE_CHARS);
}

function createFilename(): string {
	const stamp = new Date().toISOString().replace(/[:.]/g, "-");
	return `codex-image-${stamp}-${randomUUID().slice(0, 8)}.png`;
}

async function ensureContainedChildDirectory(root: string, parent: string, name: string): Promise<string> {
	const candidate = join(parent, name);
	try {
		await mkdir(candidate);
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
	}

	const resolved = await realpath(candidate);
	if (!isWithin(root, resolved)) {
		throw new Error(`Refusing to write through a directory outside the current workspace: ${resolved}`);
	}
	const info = await lstat(resolved);
	if (!info.isDirectory()) {
		throw new Error(`Expected an output directory but found a non-directory: ${resolved}`);
	}
	return resolved;
}

async function prepareOutput(cwd: string): Promise<{ workspaceRoot: string; outputDir: string; outputPath: string }> {
	const workspaceRoot = await realpath(cwd);
	const outputRoot = await ensureContainedChildDirectory(workspaceRoot, workspaceRoot, "output");
	const outputDir = await ensureContainedChildDirectory(workspaceRoot, outputRoot, "imagegen");

	return {
		workspaceRoot,
		outputDir,
		outputPath: join(outputDir, createFilename()),
	};
}

function pngCrc32(data: Buffer, start: number, end: number): number {
	let crc = 0xffffffff;
	for (let index = start; index < end; index += 1) {
		crc ^= data[index] ?? 0;
		for (let bit = 0; bit < 8; bit += 1) {
			crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
		}
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function validatePngStructure(data: Buffer, path: string): void {
	if (data.length <= PNG_SIGNATURE.length || !data.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)) {
		throw new Error(`Codex output is not a PNG: ${path}`);
	}

	let offset = PNG_SIGNATURE.length;
	let chunkIndex = 0;
	let foundData = false;
	let foundEnd = false;
	while (offset + 12 <= data.length) {
		const length = data.readUInt32BE(offset);
		const type = data.toString("ascii", offset + 4, offset + 8);
		const nextOffset = offset + 12 + length;
		if (nextOffset > data.length) {
			throw new Error(`Codex output contains a truncated PNG chunk: ${path}`);
		}
		const expectedCrc = data.readUInt32BE(offset + 8 + length);
		const actualCrc = pngCrc32(data, offset + 4, offset + 8 + length);
		if (actualCrc !== expectedCrc) {
			throw new Error(`Codex output contains a corrupt PNG chunk (${type}): ${path}`);
		}
		if (chunkIndex === 0) {
			if (type !== "IHDR" || length !== 13) {
				throw new Error(`Codex output has an invalid PNG header: ${path}`);
			}
			const width = data.readUInt32BE(offset + 8);
			const height = data.readUInt32BE(offset + 12);
			if (width === 0 || height === 0) {
				throw new Error(`Codex output has invalid PNG dimensions: ${path}`);
			}
		}
		if (type === "IDAT") foundData = true;
		if (type === "IEND") {
			if (!foundData || length !== 0 || nextOffset !== data.length) {
				throw new Error(`Codex output has an invalid PNG end chunk: ${path}`);
			}
			foundEnd = true;
			break;
		}
		offset = nextOffset;
		chunkIndex += 1;
	}
	if (!foundEnd) {
		throw new Error(`Codex output is missing the PNG end chunk: ${path}`);
	}
}

async function readVerifiedPng(path: string, workspaceRoot: string): Promise<Buffer> {
	const info = await lstat(path);
	if (!info.isFile()) {
		throw new Error(`Codex did not create a regular image file at ${path}`);
	}
	const resolved = await realpath(path);
	if (!isWithin(workspaceRoot, resolved)) {
		throw new Error(`Codex created the image outside the current workspace: ${resolved}`);
	}

	const data = await readFile(resolved);
	validatePngStructure(data, path);
	return data;
}

async function runCodex(args: string[], cwd: string, signal?: AbortSignal): Promise<CodexCommandResult> {
	if (signal?.aborted) throw new Error("Codex image generation was cancelled");

	return new Promise((resolve, reject) => {
		const detached = process.platform !== "win32";
		const child = spawn("codex", args, {
			cwd,
			detached,
			shell: false,
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stdout = "";
		let stderr = "";
		let settled = false;
		let terminationReason: "cancelled" | "timed out" | undefined;
		let timeoutId: ReturnType<typeof setTimeout> | undefined;
		let forceKillId: ReturnType<typeof setTimeout> | undefined;
		let settleId: ReturnType<typeof setTimeout> | undefined;

		const killProcessGroup = (killSignal: NodeJS.Signals) => {
			if (detached && child.pid !== undefined) {
				try {
					process.kill(-child.pid, killSignal);
					return;
				} catch {
					// Fall back to the direct child if the process group has already gone away.
				}
			}
			try {
				child.kill(killSignal);
			} catch {
				// The process may already have exited.
			}
		};

		const cleanup = () => {
			if (timeoutId) clearTimeout(timeoutId);
			// After cancellation/timeout, keep the delayed SIGKILL armed even if the
			// direct child exits first; a descendant may still be alive in the group.
			if (!terminationReason && forceKillId) clearTimeout(forceKillId);
			if (!terminationReason && settleId) clearTimeout(settleId);
			signal?.removeEventListener("abort", onAbort);
		};

		const fail = (error: Error) => {
			if (settled) return;
			settled = true;
			cleanup();
			reject(error);
		};

		const terminate = (reason: "cancelled" | "timed out") => {
			if (terminationReason || settled) return;
			terminationReason = reason;
			killProcessGroup("SIGTERM");
			forceKillId = setTimeout(() => {
				killProcessGroup("SIGKILL");
				if (!settled) {
					settleId = setTimeout(() => {
						fail(new Error(`Codex image generation ${reason}; the process group did not settle after SIGKILL`));
					}, KILL_SETTLE_MS);
				}
			}, KILL_GRACE_MS);
			forceKillId.unref();
		};

		const onAbort = () => terminate("cancelled");
		signal?.addEventListener("abort", onAbort, { once: true });
		timeoutId = setTimeout(() => terminate("timed out"), CODEX_TIMEOUT_MS);

		child.stdout?.on("data", (chunk: Buffer) => {
			stdout = appendTail(stdout, chunk);
		});
		child.stderr?.on("data", (chunk: Buffer) => {
			stderr = appendTail(stderr, chunk);
		});
		child.once("error", (error) => fail(new Error(`Failed to start Codex: ${error.message}`)));
		child.once("close", (code, closeSignal) => {
			if (settled) return;
			if (terminationReason) {
				fail(new Error(`Codex image generation ${terminationReason}`));
				return;
			}
			if (code === null) {
				fail(new Error(`Codex exited without a status code${closeSignal ? ` (${closeSignal})` : ""}`));
				return;
			}
			settled = true;
			cleanup();
			resolve({ stdout, stderr, code });
		});
	});
}

function buildCodexPrompt(prompt: string, outputPath: string, exact = false): string {
	return [
		"Use $imagegen and its preferred built-in image_gen tool.",
		"Generate exactly one new raster image from the request below.",
		...(exact
			? [
					"The image request is already the final prompt.",
					"Pass it to image_gen exactly as written: do not rewrite, normalize, expand, augment, or otherwise prompt-engineer it.",
				]
			: []),
		"Do not use the Python/API/CLI fallback and do not ask follow-up questions.",
		"Do not edit source files or inspect unrelated project files.",
		`Copy the selected final image to this exact absolute PNG path: ${outputPath}`,
		"Do not overwrite any other file. Verify that the final path exists before finishing.",
		"If the built-in image tool is unavailable, fail clearly without attempting a fallback.",
		"In the final response, report the exact saved path.",
		"",
		"Image request:",
		prompt,
	].join("\n");
}

async function generateCodexImage(
	prompt: string,
	cwd: string,
	signal?: AbortSignal,
	onStart?: (outputPath: string) => void,
	exact = false,
): Promise<GeneratedImage> {
	if (!prompt.trim()) throw new Error("Image prompt must not be empty");

	const { workspaceRoot, outputDir, outputPath } = await prepareOutput(cwd);
	onStart?.(outputPath);

	try {
		const result = await runCodex(
			[
				"exec",
				"--ephemeral",
				"--skip-git-repo-check",
				"--sandbox",
				"workspace-write",
				"--color",
				"never",
				"-C",
				outputDir,
				buildCodexPrompt(prompt, outputPath, exact),
			],
			outputDir,
			signal,
		);

		if (result.code !== 0) {
			const diagnostic = tail([result.stderr, result.stdout].filter(Boolean).join("\n").trim());
			throw new Error(`Codex image generation failed with exit code ${result.code}${diagnostic ? `:\n${diagnostic}` : ""}`);
		}

		return {
			path: outputPath,
			image: await readVerifiedPng(outputPath, workspaceRoot),
			codexMessage: tail(result.stdout.trim(), 2_000),
		};
	} catch (error) {
		await rm(outputPath, { force: true }).catch(() => undefined);
		throw error;
	}
}

export default function codexImageGenExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "codex_image_generate",
		label: "Codex Image Gen",
		description:
			"Generate one PNG by running Codex headlessly with its $imagegen skill and built-in image_gen tool. Accepts a text prompt, saves the result under output/imagegen/ in the current workspace, and returns both the absolute path and image attachment. This can take several minutes.",
		promptSnippet: "Generate a PNG through Codex's $imagegen skill",
		promptGuidelines: [
			"Use codex_image_generate when the user asks for an AI-generated raster image and specifically wants Codex image generation.",
			"After codex_image_generate succeeds, show the saved image in the response with inline Markdown using the returned absolute path.",
		],
		parameters: Type.Object({
			prompt: Type.String({
				minLength: 1,
				description: "A complete description of the image to generate, including composition, style, text, and constraints when relevant.",
			}),
		}),
		renderCall(args, theme) {
			const prompt = typeof args.prompt === "string" ? args.prompt : "";
			const container = new Container();
			container.addChild(new Text(theme.fg("toolTitle", theme.bold("Codex Image Gen")), 0, 0));
			container.addChild(new Text(theme.fg("accent", theme.bold("PROMPT")), 0, 0));
			container.addChild(
				new Text(prompt ? theme.fg("text", prompt) : theme.fg("dim", theme.italic("Waiting for prompt…")), 1, 0),
			);
			return container;
		},
		renderResult(result, { isPartial }, theme, context) {
			const details = result.details as CodexImageDetails | undefined;
			const container = new Container();

			if (isPartial) {
				container.addChild(new Text(theme.fg("accent", theme.bold("STATUS")), 0, 0));
				container.addChild(new Text(theme.fg("warning", "◌ Generating image…"), 1, 0));
				if (details?.path) {
					container.addChild(new Text(theme.fg("muted", "Planned output"), 1, 0));
					container.addChild(new Text(theme.fg("dim", details.path), 2, 0));
				}
				return container;
			}

			if (context.isError) {
				const errorText = result.content
					.filter((item) => item.type === "text")
					.map((item) => item.text)
					.join("\n");
				container.addChild(new Text(theme.fg("error", theme.bold("ERROR")), 0, 0));
				container.addChild(new Text(theme.fg("error", errorText || "Image generation failed"), 1, 0));
				return container;
			}

			container.addChild(new Text(theme.fg("success", theme.bold("RESULT")), 0, 0));
			container.addChild(new Text(theme.fg("success", "✓ Image generated"), 1, 0));
			if (details?.path) {
				container.addChild(new Text(theme.fg("muted", "Saved to"), 1, 0));
				container.addChild(new Text(theme.fg("accent", details.path), 2, 0));
			}
			return container;
		},
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			// Preserve the existing LLM-mediated behavior for normal tool calls.
			const prompt = params.prompt.trim();
			const generated = await generateCodexImage(prompt, ctx.cwd, signal, (outputPath) => {
				onUpdate?.({
					content: [{ type: "text", text: `Running Codex image generation for ${outputPath}...` }],
					details: { path: outputPath, bytes: 0, codexMessage: "" } satisfies CodexImageDetails,
				});
			});
			const markdown = `![generated image](${generated.path})`;

			return {
				content: [
					{
						type: "text",
						text: `Generated image saved to ${generated.path}\n\nShow it to the user with:\n${markdown}`,
					},
					{ type: "image", data: generated.image.toString("base64"), mimeType: "image/png" },
				],
				details: {
					path: generated.path,
					bytes: generated.image.length,
					codexMessage: generated.codexMessage,
				} satisfies CodexImageDetails,
			};
		},
	});

	pi.registerCommand("codex-image-exact", {
		description: "Generate an image with Codex from the exact command argument, bypassing Pi's LLM",
		handler: async (args, ctx) => {
			let prompt = args;
			if (!prompt.trim()) {
				if (!ctx.hasUI) {
					if (ctx.mode === "print") console.log("Usage: /codex-image-exact <image prompt>");
					return;
				}

				const entered = await ctx.ui.editor("Exact Codex image prompt", "");
				if (entered === undefined || !entered.trim()) return;
				prompt = entered;
			}

			// Commands can be entered while an agent is running. Wait for it to settle so
			// this direct path never overlaps with or steers a Pi model turn.
			await ctx.waitForIdle();

			let generated: GeneratedImage | undefined;
			let errorMessage: string | undefined;

			if (ctx.mode === "tui") {
				const result = await ctx.ui.custom<GeneratedImage | { error: string } | null>((tui, theme, _keybindings, done) => {
					const loader = new BorderedLoader(tui, theme, "Generating image with exact prompt...");
					loader.onAbort = () => done(null);
					generateCodexImage(prompt, ctx.cwd, loader.signal, undefined, true)
						.then(done)
						.catch((error) => done({ error: error instanceof Error ? error.message : String(error) }));
					return loader;
				});

				if (result === null) {
					ctx.ui.notify("Codex image generation cancelled", "info");
					return;
				}
				if ("error" in result) errorMessage = result.error;
				else generated = result;
			} else {
				try {
					generated = await generateCodexImage(prompt, ctx.cwd, ctx.signal, undefined, true);
				} catch (error) {
					errorMessage = error instanceof Error ? error.message : String(error);
				}
			}

			if (errorMessage) {
				ctx.ui.notify(`Codex image generation failed: ${errorMessage}`, "error");
				if (ctx.mode === "print") console.error(`Codex image generation failed: ${errorMessage}`);
				return;
			}

			if (!generated) return;
			if (ctx.mode === "tui") {
				await ctx.ui.custom<void>((_tui, theme, _keybindings, done) => {
					const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
					box.addChild(new Text(theme.fg("success", `Generated image: ${generated.path}`), 0, 0));
					box.addChild(
						new Image(generated.image.toString("base64"), "image/png", theme, {
							maxWidthCells: 80,
							maxHeightCells: 30,
							filename: generated.path,
						}),
					);
					box.addChild(new Text(theme.fg("dim", "Press Enter or Escape to close"), 0, 0));
					return {
						render: (width) => box.render(width),
						invalidate: () => box.invalidate(),
						handleInput: (data) => {
							if (matchesKey(data, "enter") || matchesKey(data, "escape")) done(undefined);
						},
					};
				});
			}
			ctx.ui.notify(`Generated image: ${generated.path}`, "info");
			if (ctx.mode === "print") console.log(`Generated image: ${generated.path}`);
		},
	});
}
