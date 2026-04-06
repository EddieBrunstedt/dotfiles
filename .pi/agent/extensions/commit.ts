/**
 * Commit Extension — Smart structured git commits
 *
 * Analyzes uncommitted changes, groups them into logical commits with
 * conventional messages, previews the plan, and executes on approval.
 *
 * Usage:
 *   /commit         — commit with structured splits (asks to stage if needed)
 *   /commit push    — commit and push
 *   /commit all     — stage everything automatically, then commit
 *   /commit all push — stage everything, commit, and push
 */

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
	files: string[];
	description: string;
}

interface CommitPlan {
	commits: CommitGroup[];
}

const SYSTEM_PROMPT = `You are a git commit structuring assistant. Given a git diff and file status, your job is to group the changes into logical, isolated commits with clear conventional commit messages.

Rules:
- Each commit should be a single logical unit of work
- Use conventional commit format: type(scope): description
- Common types: feat, fix, refactor, style, docs, chore, test, perf
- Keep messages concise (max 72 chars for the subject line)
- Group related file changes together
- If all changes are closely related, a single commit is fine — don't over-split
- Order commits so each one builds on the previous (dependencies first)

Respond with ONLY a valid JSON object matching this schema, no markdown fencing:
{
  "commits": [
    {
      "message": "type(scope): description",
      "files": ["path/to/file1", "path/to/file2"],
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

async function getGitDiff(
	pi: ExtensionAPI,
	cwd: string,
	staged: boolean,
): Promise<string> {
	const args = staged ? ["diff", "--cached"] : ["diff"];
	const { stdout } = await pi.exec("git", args, { cwd });
	return stdout.trim();
}

async function getUntrackedContent(
	pi: ExtensionAPI,
	cwd: string,
	files: string[],
): Promise<string> {
	const parts: string[] = [];
	for (const file of files.slice(0, 20)) {
		const { stdout, code } = await pi.exec("git", ["show", `:${file}`], {
			cwd,
		});
		if (code !== 0) {
			// Fallback: read from working tree for untracked
			const { stdout: content } = await pi.exec("head", ["-100", file], {
				cwd,
			});
			if (content.trim()) {
				parts.push(`=== New file: ${file} ===\n${content.trim()}`);
			}
		} else {
			parts.push(`=== New file: ${file} ===\n${stdout.trim()}`);
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

		// Handle renames: "R  old -> new"
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

async function generateCommitPlan(
	ctx: ExtensionCommandContext,
	diff: string,
	statusText: string,
	untrackedContent: string,
	signal: AbortSignal,
): Promise<CommitPlan | null> {
	const model = ctx.model;
	if (!model) throw new Error("No model selected");

	const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
	if (!auth.ok || !auth.apiKey) {
		throw new Error(auth.ok ? `No API key for ${model.provider}` : auth.error);
	}

	let userContent = `## Git Status\n\`\`\`\n${statusText}\n\`\`\`\n\n## Diff\n\`\`\`diff\n${diff}\n\`\`\``;
	if (untrackedContent) {
		userContent += `\n\n## New/Untracked File Contents\n${untrackedContent}`;
	}

	// Truncate if very large to stay within context
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

	// Strip markdown code fences if present
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
		const c = plan.commits[i];
		lines.push(`### ${i + 1}. \`${c.message}\``);
		lines.push(c.description);
		lines.push("");
		lines.push("Files:");
		for (const f of c.files) {
			lines.push(`- \`${f}\``);
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
				theme.fg(
					"dim",
					"  Enter = execute  •  e = edit in editor  •  Esc = cancel",
				),
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
): Promise<{ success: number; failed: number }> {
	let success = 0;
	let failed = 0;

	for (const commit of plan.commits) {
		// Reset index first so we can stage exactly the files for this commit
		await pi.exec("git", ["reset", "HEAD"], { cwd });

		// Stage the specific files
		for (const file of commit.files) {
			const { code } = await pi.exec("git", ["add", "--", file], { cwd });
			if (code !== 0) {
				// File might have been deleted
				await pi.exec("git", ["add", "-A", "--", file], { cwd });
			}
		}

		// Check if anything was staged
		const { stdout: staged } = await pi.exec(
			"git",
			["diff", "--cached", "--name-only"],
			{ cwd },
		);
		if (!staged.trim()) {
			ctx.ui.notify(`Skipped empty commit: ${commit.message}`, "warning");
			continue;
		}

		// Commit
		const { code: commitCode, stderr } = await pi.exec(
			"git",
			["commit", "-m", commit.message],
			{ cwd },
		);
		if (commitCode === 0) {
			success++;
		} else {
			ctx.ui.notify(`Failed: ${commit.message} — ${stderr.trim()}`, "error");
			failed++;
		}
	}

	return { success, failed };
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("commit", {
		description:
			"Smart structured git commit (add 'push' to also push, 'all' to stage everything)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("commit requires interactive mode", "error");
				return;
			}

			const flags = args.trim().toLowerCase().split(/\s+/).filter(Boolean);
			const shouldPush = flags.includes("push");
			const stageAll = flags.includes("all");

			const cwd = ctx.cwd;

			// Step 1: Check git status
			let statusText: string;
			try {
				statusText = await getGitStatus(pi, cwd);
			} catch (e: any) {
				ctx.ui.notify(e.message, "error");
				return;
			}

			if (!statusText) {
				ctx.ui.notify("Working tree clean — nothing to commit", "info");
				return;
			}

			const { staged, unstaged, untracked } = parseStatus(statusText);
			const totalChanges = staged.length + unstaged.length + untracked.length;
			ctx.ui.notify(
				`Found ${totalChanges} changed file(s), analyzing...`,
				"info",
			);

			// Step 2: Stage everything if 'all', or ask if nothing is staged
			if (
				stageAll ||
				(staged.length === 0 && (unstaged.length > 0 || untracked.length > 0))
			) {
				if (!stageAll) {
					const shouldStageAll = await ctx.ui.confirm(
						"Nothing staged",
						"No files are staged. Stage all changes?",
					);
					if (!shouldStageAll) {
						ctx.ui.notify("Cancelled", "info");
						return;
					}
				}
				await pi.exec("git", ["add", "-A"], { cwd });
			}

			// Re-read status after staging
			statusText = await getGitStatus(pi, cwd);
			const parsed = parseStatus(statusText);

			// Step 3: Gather diff info
			const stagedDiff = await getGitDiff(pi, cwd, true);
			const untrackedContent = await getUntrackedContent(
				pi,
				cwd,
				parsed.staged.filter((f) => !stagedDiff.includes(f)),
			);

			// Step 4: Generate commit plan via LLM
			const plan = await ctx.ui.custom<CommitPlan | null>(
				(tui, theme, _kb, done) => {
					const loader = new BorderedLoader(
						tui,
						theme,
						"Analyzing changes and generating commit plan...",
					);
					loader.onAbort = () => done(null);

					generateCommitPlan(
						ctx,
						stagedDiff,
						statusText,
						untrackedContent,
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
				// Unstage if we staged everything
				await pi.exec("git", ["reset", "HEAD"], { cwd });
				return;
			}

			// Verify all changed files are accounted for in the plan
			const plannedFiles = new Set(plan.commits.flatMap((c) => c.files));
			const allStaged = parsed.staged;
			const missingFiles = allStaged.filter((f) => !plannedFiles.has(f));
			if (missingFiles.length > 0) {
				// Add missing files to the last commit
				const lastCommit = plan.commits[plan.commits.length - 1];
				lastCommit.files.push(...missingFiles);
			}

			// Step 5: Preview and confirm
			const confirmed = await showPlanAndConfirm(plan, ctx);
			if (!confirmed) {
				ctx.ui.notify("Cancelled", "info");
				await pi.exec("git", ["reset", "HEAD"], { cwd });
				return;
			}

			// Step 6: Execute commits
			const { success, failed } = await executeCommits(pi, plan, cwd, ctx);

			// Check for any remaining uncommitted changes (leftovers)
			const { stdout: remaining } = await pi.exec(
				"git",
				["status", "--porcelain"],
				{ cwd },
			);
			if (remaining.trim()) {
				const stageLeftovers = await ctx.ui.confirm(
					"Leftover changes",
					"Some changes weren't included in the plan. Stage and commit them?",
				);
				if (stageLeftovers) {
					await pi.exec("git", ["add", "-A"], { cwd });
					await pi.exec("git", ["commit", "-m", "chore: remaining changes"], {
						cwd,
					});
				}
			}

			if (failed > 0) {
				ctx.ui.notify(
					`Done: ${success} committed, ${failed} failed`,
					"warning",
				);
			} else {
				ctx.ui.notify(`Committed ${success} commit(s)`, "info");
			}

			// Step 7: Push if requested
			if (shouldPush) {
				ctx.ui.notify("Pushing...", "info");
				const { code, stderr } = await pi.exec("git", ["push"], { cwd });
				if (code === 0) {
					ctx.ui.notify("Pushed successfully", "info");
				} else {
					// Try push with upstream
					const { stdout: branch } = await pi.exec(
						"git",
						["branch", "--show-current"],
						{ cwd },
					);
					const { code: code2, stderr: stderr2 } = await pi.exec(
						"git",
						["push", "--set-upstream", "origin", branch.trim()],
						{ cwd },
					);
					if (code2 === 0) {
						ctx.ui.notify("Pushed (set upstream)", "info");
					} else {
						ctx.ui.notify(
							`Push failed: ${stderr2.trim() || stderr.trim()}`,
							"error",
						);
					}
				}
			}
		},
	});
}
