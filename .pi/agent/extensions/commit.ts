/**
 * Commit Extension — Smart structured git commits
 *
 * Plans commits from the git index, not the working tree, so `/commit`
 * respects staged hunks exactly as the user staged them.
 *
 * `/commit all` is the convenience mode: it stages everything temporarily,
 * generates the commit plan from that staged snapshot, and restores the
 * original index if the flow is cancelled before execution.
 *
 * Usage:
 *   /commit      — commit only the currently staged changes
 *   /commit all  — stage everything, then commit
 */

import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { complete } from "@mariozechner/pi-ai";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
} from "@mariozechner/pi-coding-agent";
import {
	BorderedLoader,
	getMarkdownTheme,
} from "@mariozechner/pi-coding-agent";
import { Container, Markdown, matchesKey, Text } from "@mariozechner/pi-tui";

interface CommitGroup {
	message: string;
	items: string[];
	description: string;
}

interface CommitPlan {
	commits: CommitGroup[];
}

interface CommitPlanValidation {
	emptyCommitIndices: number[];
	missingFiles: string[];
	extraFiles: string[];
	duplicateFiles: string[];
}

/**
 * A single atomic staged item the model is allowed to assign to a commit.
 *
 * Most entries map to one path. Renames/copies map to both old and new paths,
 * but are presented to the model as one item so they stay together.
 */
interface StagedEntry {
	key: string;
	patchPaths: string[];
	contentPath?: string;
	isNew: boolean;
}

const SYSTEM_PROMPT = `You are a git commit structuring assistant. Given staged git changes and optional user intent, your job is to group the changes into logical, isolated commits with clear conventional commit messages.

Rules:
- Each commit should be a single logical unit of work.
- Use conventional commit format: type(scope): description.
- Common types: feat, fix, refactor, style, docs, chore, test, perf.
- Keep messages concise (max 72 chars for the subject line).
- Group related file changes together.
- If all changes are closely related, a single commit is fine — don't over-split.
- Order commits so each one builds on the previous (dependencies first).
- Only use entries that appear in the staged item list.
- Every staged item must appear in exactly one commit.
- Do not invent items, omit items, or duplicate items across commits.
- This tool commits whole staged items, so never split one staged item across multiple commits.
- Renames appear as "old/path -> new/path" and must be kept together in a single commit.
- The commit type must match the items in that commit.
- Use test only for test-only changes.
- Use docs only for docs-only changes.
- Use the optional user intent to understand priorities and choose a better commit message when helpful.
- The commit subject must describe WHAT the commit does, not just WHY it was done.
- Prefer concrete action over vague motivation. Good: "feat(commit): preserve staged hunks". Bad: "feat(commit): improve workflow".
- Do not overclaim behavior. For example, if a command still has an /all mode, do not say it works only on staged changes.

Respond with ONLY a valid JSON object matching this schema, no markdown fencing:
{
  "commits": [
    {
      "message": "type(scope): description",
      "items": ["path/to/file1", "old/path -> new/path"],
      "description": "Brief explanation of what this commit does"
    }
  ]
}`;

async function getGitStatus(pi: ExtensionAPI, cwd: string): Promise<string> {
	const { stdout, code } = await pi.exec("git", ["status", "--porcelain"], {
		cwd,
	});
	if (code !== 0) throw new Error("Not a git repository or git error");
	return stdout.trim();
}

async function getStagedStatus(pi: ExtensionAPI, cwd: string): Promise<string> {
	const { stdout, code } = await pi.exec(
		"git",
		["diff", "--cached", "--name-status", "--find-renames"],
		{ cwd },
	);
	if (code !== 0) throw new Error("Failed to read staged file status");
	return stdout.trim();
}

async function getStagedDiff(pi: ExtensionAPI, cwd: string): Promise<string> {
	const { stdout, code } = await pi.exec("git", ["diff", "--cached"], {
		cwd,
	});
	if (code !== 0) throw new Error("Failed to read staged diff");
	return stdout.trim();
}

async function getStagedPatchForPaths(
	pi: ExtensionAPI,
	cwd: string,
	paths: string[],
): Promise<string> {
	const { stdout, code } = await pi.exec(
		"git",
		["diff", "--cached", "--binary", "--full-index", "--", ...paths],
		{ cwd },
	);
	if (code !== 0) {
		throw new Error(`Failed to read staged patch for paths: ${paths.join(", ")}`);
	}
	return stdout;
}

async function createIndexSnapshot(
	pi: ExtensionAPI,
	cwd: string,
): Promise<string> {
	const { stdout, code } = await pi.exec(
		"git",
		["diff", "--cached", "--binary", "--full-index"],
		{ cwd },
	);
	if (code !== 0) throw new Error("Failed to snapshot staged changes");
	return stdout;
}

/**
 * Rebuild the index from a cached patch.
 *
 * This is the key trick that lets the command preserve partially staged hunks
 * while still executing multiple commits: each planned commit gets replayed
 * back into the index from its original staged patch.
 */
async function applyCachedPatch(
	pi: ExtensionAPI,
	cwd: string,
	patch: string,
): Promise<void> {
	if (!patch.trim()) {
		return;
	}

	const tempDir = await mkdtemp(join(tmpdir(), "pi-commit-"));
	const patchPath = join(tempDir, "index.patch");

	try {
		await writeFile(patchPath, patch, "utf8");
		const { code, stderr } = await pi.exec(
			"git",
			[
				"apply",
				"--cached",
				"--binary",
				"--whitespace=nowarn",
				patchPath,
			],
			{ cwd },
		);
		if (code !== 0) {
			throw new Error(stderr.trim() || "git apply failed");
		}
	} finally {
		await rm(tempDir, { recursive: true, force: true });
	}
}

async function restoreIndexSnapshot(
	pi: ExtensionAPI,
	cwd: string,
	patch: string,
): Promise<void> {
	const { code: resetCode, stderr: resetStderr } = await pi.exec(
		"git",
		["reset"],
		{ cwd },
	);
	if (resetCode !== 0) {
		throw new Error(
			`Failed to restore staged changes: ${resetStderr.trim() || "git reset failed"}`,
		);
	}

	try {
		await applyCachedPatch(pi, cwd, patch);
	} catch (error) {
		const message =
			error instanceof Error ? error.message : "git apply failed";
		throw new Error(`Failed to restore staged changes: ${message}`);
	}
}

async function getNewFileContent(
	pi: ExtensionAPI,
	cwd: string,
	paths: string[],
): Promise<string> {
	const parts: string[] = [];

	for (const path of paths.slice(0, 20)) {
		const { stdout, code } = await pi.exec("git", ["show", `:${path}`], {
			cwd,
		});
		if (code !== 0) {
			const { stdout: content } = await pi.exec("head", ["-100", path], {
				cwd,
			});
			if (content.trim()) {
				parts.push(`=== New file: ${path} ===\n${content.trim()}`);
			}
		} else if (stdout.trim()) {
			parts.push(`=== New file: ${path} ===\n${stdout.trim()}`);
		}
	}

	return parts.join("\n\n");
}

function parseStatus(status: string): {
	staged: string[];
	unstaged: string[];
	untracked: string[];
} {
	const staged: string[] = [];
	const unstaged: string[] = [];
	const untracked: string[] = [];

	for (const line of status.split("\n")) {
		if (!line.trim()) continue;
		const indexStatus = line[0];
		const workTreeStatus = line[1];
		const filePath = line.slice(3).trim();

		const actualPath = filePath.includes(" -> ")
			? filePath.split(" -> ")[1]
			: filePath;

		if (indexStatus === "?") {
			untracked.push(actualPath);
		} else {
			if (indexStatus !== " " && indexStatus !== "?") {
				staged.push(actualPath);
			}
			if (workTreeStatus !== " " && workTreeStatus !== "?") {
				unstaged.push(actualPath);
			}
		}
	}

	return { staged, unstaged, untracked };
}

function parseStagedEntries(stagedStatusText: string): StagedEntry[] {
	const entries: StagedEntry[] = [];

	for (const line of stagedStatusText.split("\n")) {
		if (!line.trim()) continue;

		const parts = line.split("\t");
		const statusCode = parts[0] ?? "";

		if ((statusCode.startsWith("R") || statusCode.startsWith("C")) && parts.length >= 3) {
			const oldPath = parts[1]?.trim();
			const newPath = parts[2]?.trim();
			if (!oldPath || !newPath) continue;
			entries.push({
				key: `${oldPath} -> ${newPath}`,
				patchPaths: [oldPath, newPath],
				contentPath: newPath,
				isNew: false,
			});
			continue;
		}

		const path = parts[1]?.trim();
		if (!path) continue;
		entries.push({
			key: path,
			patchPaths: [path],
			contentPath: statusCode.startsWith("D") ? undefined : path,
			isNew: statusCode.startsWith("A"),
		});
	}

	return entries;
}

function validateCommitPlan(
	plan: CommitPlan,
	expectedItems: string[],
): CommitPlanValidation {
	const expectedItemSet = new Set(expectedItems);
	const seenCounts = new Map<string, number>();
	const emptyCommitIndices: number[] = [];

	for (const [index, commit] of plan.commits.entries()) {
		const normalizedItems = commit.items
			.map((item) => item.trim())
			.filter(Boolean);

		if (normalizedItems.length === 0) {
			emptyCommitIndices.push(index + 1);
		}

		for (const item of normalizedItems) {
			seenCounts.set(item, (seenCounts.get(item) ?? 0) + 1);
		}
	}

	const missingItems = expectedItems.filter((item) => !seenCounts.has(item));
	const extraItems = [...seenCounts.keys()].filter(
		(item) => !expectedItemSet.has(item),
	);
	const duplicateItems = [...seenCounts.entries()]
		.filter(([, count]) => count > 1)
		.map(([item]) => item)
		.sort();

	return {
		emptyCommitIndices,
		missingFiles: missingItems,
		extraFiles: extraItems,
		duplicateFiles: duplicateItems,
	};
}

function formatValidationError(validation: CommitPlanValidation): string {
	const parts: string[] = [];

	if (validation.emptyCommitIndices.length > 0) {
		parts.push(`empty commits: ${validation.emptyCommitIndices.join(", ")}`);
	}

	if (validation.missingFiles.length > 0) {
		parts.push(`missing: ${validation.missingFiles.join(", ")}`);
	}

	if (validation.extraFiles.length > 0) {
		parts.push(`unexpected: ${validation.extraFiles.join(", ")}`);
	}

	if (validation.duplicateFiles.length > 0) {
		parts.push(`duplicated: ${validation.duplicateFiles.join(", ")}`);
	}

	return parts.join(" • ");
}

async function generateCommitPlan(
	ctx: ExtensionCommandContext,
	diff: string,
	stagedStatusText: string,
	stagedEntries: StagedEntry[],
	newFileContent: string,
	userIntent: string,
	signal: AbortSignal,
): Promise<CommitPlan | null> {
	const model = ctx.model;
	if (!model) throw new Error("No model selected");

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (!auth.ok || !auth.apiKey) {
		throw new Error(auth.ok ? `No API key for ${model.provider}` : auth.error);
	}

	let userContent = `## Staged Items\n\n${stagedEntries.map((entry) => `- ${entry.key}`).join("\n")}`;
	if (userIntent.trim()) {
		userContent += `\n\n## User Intent (optional)\n${userIntent.trim()}`;
	}
	userContent += `\n\n## Staged File Status\n\`\`\`\n${stagedStatusText}\n\`\`\`\n\n## Staged Diff\n\`\`\`diff\n${diff}\n\`\`\``;
	if (newFileContent) {
		userContent += `\n\n## New File Contents\n${newFileContent}`;
	}

	if (userContent.length > 80000) {
		userContent =
			userContent.slice(0, 80000) + "\n\n[... truncated due to size]";
	}

	const response = await complete(
		model,
		{
			systemPrompt: SYSTEM_PROMPT,
			messages: [
				{
					role: "user",
					content: [{ type: "text", text: userContent }],
					timestamp: Date.now(),
				},
			],
		},
		{ apiKey: auth.apiKey, headers: auth.headers, signal },
	);

	if (response.stopReason === "aborted") return null;

	const text = response.content
		.filter((c): c is { type: "text"; text: string } => c.type === "text")
		.map((c) => c.text)
		.join("\n")
		.trim();

	const cleaned = text
		.replace(/^```(?:json)?\n?/m, "")
		.replace(/\n?```$/m, "")
		.trim();

	try {
		return JSON.parse(cleaned) as CommitPlan;
	} catch {
		throw new Error(`Failed to parse commit plan: ${cleaned.slice(0, 200)}`);
	}
}

function renderPlanMarkdown(plan: CommitPlan): string {
	const lines: string[] = ["## Commit Plan\n"];
	for (let i = 0; i < plan.commits.length; i++) {
		const commit = plan.commits[i];
		lines.push(`### ${i + 1}. \`${commit.message}\``);
		lines.push(commit.description);
		lines.push("");
		lines.push("Items:");
		for (const item of commit.items) {
			lines.push(`- \`${item}\``);
		}
		lines.push("");
	}
	return lines.join("\n");
}

async function showPlanAndConfirm(
	plan: CommitPlan,
	ctx: ExtensionCommandContext,
): Promise<boolean> {
	const markdown = renderPlanMarkdown(plan);

	return ctx.ui.custom<boolean>((_tui, theme, _kb, done) => {
		const container = new Container();
		const mdTheme = getMarkdownTheme();

		container.addChild(new Text("", 0, 0));
		container.addChild(new Markdown(markdown, 1, 1, mdTheme));
		container.addChild(
			new Text(
				theme.fg("dim", "  Enter = execute  •  Esc = cancel"),
				1,
				1,
			),
		);

		return {
			render: (width: number) => container.render(width),
			invalidate: () => container.invalidate(),
			handleInput: (data: string) => {
				if (matchesKey(data, "enter") || data === "y") done(true);
				else if (matchesKey(data, "escape") || data === "n") done(false);
			},
		};
	});
}

async function executeCommits(
	pi: ExtensionAPI,
	plan: CommitPlan,
	cwd: string,
	ctx: ExtensionCommandContext,
	stagedEntryMap: Map<string, StagedEntry>,
): Promise<{ success: number; failed: number }> {
	let success = 0;
	const patches = await Promise.all(
		plan.commits.map((commit) => {
			const patchPaths = [
				...new Set(
					commit.items.flatMap((item) => stagedEntryMap.get(item)?.patchPaths ?? []),
				),
			];
			return getStagedPatchForPaths(pi, cwd, patchPaths);
		}),
	);

	for (const [index, commit] of plan.commits.entries()) {
		const { code: resetCode, stderr: resetStderr } = await pi.exec(
			"git",
			["reset"],
			{ cwd },
		);
		if (resetCode !== 0) {
			ctx.ui.notify(
				`Failed to prepare commit: ${resetStderr.trim() || commit.message}`,
				"error",
			);
			return { success, failed: 1 };
		}

		try {
			await applyCachedPatch(pi, cwd, patches[index] ?? "");
		} catch (error) {
			const message = error instanceof Error ? error.message : "git apply failed";
			ctx.ui.notify(`Failed to stage ${commit.message} — ${message}`, "error");
			return { success, failed: 1 };
		}

		const { stdout: staged } = await pi.exec(
			"git",
			["diff", "--cached", "--name-only"],
			{ cwd },
		);
		if (!staged.trim()) {
			ctx.ui.notify(`Skipped empty commit: ${commit.message}`, "warning");
			continue;
		}

		const commitArgs = ["commit", "-m", commit.message];
		if (commit.description.trim()) {
			commitArgs.push("-m", commit.description.trim());
		}

		const { code: commitCode, stderr } = await pi.exec("git", commitArgs, {
			cwd,
		});
		if (commitCode !== 0) {
			ctx.ui.notify(`Failed: ${commit.message} — ${stderr.trim()}`, "error");
			return { success, failed: 1 };
		}

		success++;
	}

	return { success, failed: 0 };
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("commit", {
		description: "Smart structured git commit (/commit or /commit all)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("commit requires interactive mode", "error");
				return;
			}

			const normalizedArgs = args.trim().toLowerCase();
			if (normalizedArgs !== "" && normalizedArgs !== "all") {
				ctx.ui.notify("Usage: /commit or /commit all", "warning");
				return;
			}

			const stageAll = normalizedArgs === "all";
			const cwd = ctx.cwd;

			let restoreIndexOnExit = false;
			let originalIndexSnapshot = "";

			try {
				const initialStatusText = await getGitStatus(pi, cwd);
				if (!initialStatusText) {
					ctx.ui.notify("Working tree clean — nothing to commit", "info");
					return;
				}

				const initialParsed = parseStatus(initialStatusText);

				if (!stageAll) {
					if (initialParsed.staged.length === 0) {
						ctx.ui.notify(
							"Nothing staged — stage changes first or use /commit all",
							"warning",
						);
						return;
					}
				} else {
					originalIndexSnapshot = await createIndexSnapshot(pi, cwd);
					restoreIndexOnExit = true;
					await pi.exec("git", ["add", "-A"], { cwd });
				}

				const statusText = await getGitStatus(pi, cwd);
				const parsed = parseStatus(statusText);
				if (parsed.staged.length === 0) {
					ctx.ui.notify("Nothing staged — nothing to commit", "info");
					return;
				}

				const stagedStatusText = await getStagedStatus(pi, cwd);
				const stagedEntries = parseStagedEntries(stagedStatusText);
				if (stagedEntries.length === 0) {
					ctx.ui.notify("Nothing staged — nothing to commit", "info");
					return;
				}

				const userIntent = await ctx.ui.input(
					"Why? (optional)",
					"Press Enter to skip",
				);
				if (userIntent === undefined) {
					ctx.ui.notify("Cancelled", "info");
					return;
				}

				ctx.ui.notify(
					`Found ${stagedEntries.length} staged item(s), analyzing...`,
					"info",
				);

				const stagedDiff = await getStagedDiff(pi, cwd);
				const newFileContent = await getNewFileContent(
					pi,
					cwd,
					stagedEntries
						.filter((entry) => entry.isNew)
						.map((entry) => entry.contentPath)
						.filter((path): path is string => Boolean(path)),
				);

				const plan = await ctx.ui.custom<CommitPlan | null>(
					(tui, theme, _kb, done) => {
						const loader = new BorderedLoader(
							tui,
							theme,
							"Analyzing staged changes and generating commit plan...",
						);
						loader.onAbort = () => done(null);

						generateCommitPlan(
							ctx,
							stagedDiff,
							stagedStatusText,
							stagedEntries,
							newFileContent,
							userIntent,
							loader.signal,
						)
							.then(done)
							.catch((err) => {
								console.error("commit plan generation failed:", err);
								done(null);
							});

						return loader;
					},
				);

				if (!plan || plan.commits.length === 0) {
					ctx.ui.notify("Cancelled or failed to generate plan", "info");
					return;
				}

				const stagedEntryKeys = stagedEntries.map((entry) => entry.key);
				const stagedEntryMap = new Map(
					stagedEntries.map((entry) => [entry.key, entry] as const),
				);
				const validation = validateCommitPlan(plan, stagedEntryKeys);
				if (
					validation.emptyCommitIndices.length > 0 ||
					validation.missingFiles.length > 0 ||
					validation.extraFiles.length > 0 ||
					validation.duplicateFiles.length > 0
				) {
					ctx.ui.notify(
						`Commit plan is invalid — ${formatValidationError(validation)}`,
						"error",
					);
					return;
				}

				const confirmed = await showPlanAndConfirm(plan, ctx);
				if (!confirmed) {
					ctx.ui.notify("Cancelled", "info");
					return;
				}

				restoreIndexOnExit = false;
				const { success, failed } = await executeCommits(
					pi,
					plan,
					cwd,
					ctx,
					stagedEntryMap,
				);

				if (failed > 0) {
					ctx.ui.notify(`Done: ${success} committed, ${failed} failed`, "warning");
				} else {
					ctx.ui.notify(`Committed ${success} commit(s)`, "info");
				}
			} catch (error) {
				const message =
					error instanceof Error ? error.message : "Unknown commit error";
				ctx.ui.notify(message, "error");
			} finally {
				if (restoreIndexOnExit) {
					try {
						await restoreIndexSnapshot(pi, cwd, originalIndexSnapshot);
					} catch (restoreError) {
						const message =
							restoreError instanceof Error
								? restoreError.message
								: "Failed to restore staged changes";
						ctx.ui.notify(message, "error");
					}
				}
			}
		},
	});
}
