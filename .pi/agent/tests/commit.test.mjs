// Run with Node 24+: node .pi/agent/tests/commit.test.mjs
// COMMIT_EXTENSION may point to a candidate extension outside the repository.
// Executes the actual handler with only the model/UI replaced. Git runs solely in disposable repos.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
	mkdir,
	mkdtemp,
	readFile,
	writeFile,
	rm,
	readdir,
	chmod,
	copyFile,
} from "node:fs/promises";
import { execFile, spawn } from "node:child_process";
import { once } from "node:events";
import { promisify } from "node:util";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { stripTypeScriptTypes } from "node:module";
const exec = promisify(execFile);
const source = await readFile(
	process.env.COMMIT_EXTENSION ||
		new URL("../extensions/commit.ts", import.meta.url),
	"utf8",
);
const start = source.indexOf("import { complete }");
const end = source.indexOf("interface CommitGroup");
const isolated =
	source.slice(0, start) +
	"const complete = (...args) => globalThis.commitTestComplete(...args);\n" +
	source.slice(end) +
	`
export { parseStagedEntries, generateCommitPlan, renderPlanMarkdown };`;
const {
	default: register,
	parseStagedEntries,
	generateCommitPlan,
	renderPlanMarkdown,
} = await import(
	"data:text/javascript;base64," +
		Buffer.from(stripTypeScriptTypes(isolated)).toString("base64")
);
const plan = {
	commits: ["item-1", "item-2"].map((item) => ({
		message: `test: ${item}`,
		items: [item],
		description: "",
	})),
};
async function fixture(fn, { unborn = false } = {}) {
	const cwd = await mkdtemp(join(tmpdir(), "pi-commit-test-"));
	// Isolate global hooks, signing, identity, and Git environment inherited by the test runner.
	const env = Object.fromEntries(
		Object.entries(process.env).filter(([k]) => !k.startsWith("GIT_")),
	);
	Object.assign(env, {
		GIT_CONFIG_NOSYSTEM: "1",
		GIT_CONFIG_GLOBAL: "/dev/null",
		GIT_TERMINAL_PROMPT: "0",
	});
	const run = async (command, args, options = {}) => {
		try {
			const r = await exec(command, args, { cwd, env, ...options });
			return { ...r, code: 0 };
		} catch (e) {
			if (typeof e.code !== "number") throw e;
			return { stdout: e.stdout, stderr: e.stderr, code: e.code };
		}
	};
	const git = async (...args) => {
		const r = await run("git", args);
		assert.equal(r.code, 0, r.stderr);
		return r.stdout.trim();
	};
	const put = (name, value) => writeFile(join(cwd, name), value);
	await git("init", "-q");
	await git("config", "user.name", "Fixture");
	await git("config", "user.email", "fixture@example.invalid");
	if (!unborn) {
		await put("A", "base A\n");
		await put("B", "base B\n");
		await git("add", "-A");
		await git("commit", "-qm", "base");
	}
	await put("A", "staged A\n");
	await put("B", "staged B\n");
	await git("add", "-A");
	await put("A", "working A\n");
	await put("B", "working B\n");
	const original = await readFile(join(cwd, ".git/index"));
	const notes = [];
	let attempts = 0;
	const invoke = async (opts = {}) => {
		let handler;
		const pi = {
			registerCommand: (_, spec) => {
				handler = spec.handler;
			},
			exec: async (command, args, options) => {
				const gitArgs =
					command === "env" ? args.slice(args.indexOf("git") + 3) : args;
				if (gitArgs[0] === "commit") attempts++;
				const replacement = await opts.intercept?.({
					command,
					args,
					gitArgs,
					options,
					attempts,
					run,
					git,
					put,
				});
				return replacement ?? run(command, args, options);
			},
		};
		register(pi);
		let uiCalls = 0;
		await handler(opts.all ? "all" : "", {
			cwd: opts.cwd ?? cwd,
			hasUI: true,
			ui: {
				notify: (message, level) => notes.push({ message, level }),
				input: async () => {
					await opts.input?.();
					return opts.cancelInput ? undefined : "";
				},
				custom: async () => {
					if (++uiCalls === 1)
						return opts.cancelPlan ? null : (opts.plan ?? plan);
					await opts.confirm?.();
					return !opts.cancelConfirm;
				},
			},
		});
	};
	const backups = async () =>
		(await readdir(join(cwd, ".git"))).filter((n) =>
			n.startsWith("pi-commit-"),
		);
	const sameIndex = async () =>
		assert.deepEqual(await readFile(join(cwd, ".git/index")), original);
	const sameWorktree = async () => {
		assert.equal(await readFile(join(cwd, "A"), "utf8"), "working A\n");
		assert.equal(await readFile(join(cwd, "B"), "utf8"), "working B\n");
	};
	try {
		await fn({
			cwd,
			git,
			put,
			run,
			invoke,
			notes,
			backups,
			sameIndex,
			sameWorktree,
			original,
			attempts: () => attempts,
		});
	} finally {
		await rm(cwd, { recursive: true, force: true });
	}
}
const fail = { code: 1, stdout: "", stderr: "simulated signing failure" };
for (const all of [false, true]) {
	test(`initial signing failure, all=${all}`, () =>
		fixture(async (f) => {
			await f.invoke({
				all,
				intercept: ({ gitArgs }) =>
					gitArgs[0] === "commit" ? fail : undefined,
			});
			await f.sameIndex();
			await f.sameWorktree();
			assert.equal(f.attempts(), 1);
			const dirs = await f.backups();
			assert.equal(dirs.length, 1);
			assert.equal(
				await readFile(
					join(f.cwd, ".git", dirs[0], "original.patch"),
					"utf8",
				).then((s) => s.includes("+staged B")),
				true,
			);
		}));
	test(`failure after first success preserves pending staging, all=${all}`, () =>
		fixture(async (f) => {
			await f.invoke({
				all,
				intercept: ({ gitArgs, attempts }) =>
					gitArgs[0] === "commit" && attempts === 2 ? fail : undefined,
			});
			assert.equal(
				await f.git("show", "HEAD:A"),
				all ? "working A" : "staged A",
			);
			assert.equal(await f.git("show", ":B"), all ? "working B" : "staged B");
			assert.equal(await f.git("diff", "--cached", "--name-only"), "B");
			await f.sameWorktree();
			assert.equal((await f.backups()).length, 1);
			if (!all) await f.sameIndex();
		}));
	test(`successful split preserves unstaged edits, all=${all}`, () =>
		fixture(async (f) => {
			await f.invoke({ all });
			assert.equal(await f.git("diff", "--cached", "--name-only"), "");
			assert.equal(
				await f.git("show", "HEAD:B"),
				all ? "working B" : "staged B",
			);
			await f.sameWorktree();
			assert.deepEqual(await f.backups(), []);
			assert(
				f.notes.some((n) => n.message === "Committed 2 commit(s)"),
				JSON.stringify(f.notes),
			);
		}));
}
for (const stage of ["cancelInput", "cancelPlan", "cancelConfirm"]) {
	test(`/all cancellation at ${stage}`, () =>
		fixture(async (f) => {
			await f.invoke({ all: true, [stage]: true });
			await f.sameIndex();
			await f.sameWorktree();
			assert.equal(f.attempts(), 0);
			assert.deepEqual(await f.backups(), []);
		}));
}
for (const all of [false, true]) {
	test(`running from a subdirectory commits root-relative paths, all=${all}`, () =>
		fixture(async (f) => {
			// A and B sit at the repository root, outside the directory Pi runs in.
			await mkdir(join(f.cwd, "sub"));
			await f.invoke({ all, cwd: join(f.cwd, "sub") });
			assert.equal(await f.git("diff", "--cached", "--name-only"), "");
			assert.equal(
				await f.git("show", "HEAD:B"),
				all ? "working B" : "staged B",
			);
			await f.sameWorktree();
			assert.deepEqual(await f.backups(), []);
			assert(
				f.notes.some((n) => n.message === "Committed 2 commit(s)"),
				JSON.stringify(f.notes),
			);
		}));
}
test("/all git add failure stops before planning", () =>
	fixture(async (f) => {
		await f.invoke({
			all: true,
			intercept: ({ gitArgs }) => (gitArgs[0] === "add" ? fail : undefined),
		});
		await f.sameIndex();
		await f.sameWorktree();
		assert.equal(f.attempts(), 0);
		assert(f.notes.some((n) => n.level === "error"));
	}));
for (const change of ["index", "HEAD", "branch"]) {
	test(`planning rejects concurrent ${change}`, () =>
		fixture(async (f) => {
			let changed;
			await f.invoke({
				all: true,
				confirm: async () => {
					if (change === "index") {
						await f.git("add", "B");
						changed = await readFile(join(f.cwd, ".git/index"));
					}
					if (change === "HEAD")
						await f.git("commit", "--allow-empty", "-m", "concurrent");
					if (change === "branch") await f.git("checkout", "-b", "other");
				},
			});
			assert.equal(f.attempts(), 0);
			assert(f.notes.some((n) => n.message.includes("changed concurrently")));
			if (changed)
				assert.deepEqual(await readFile(join(f.cwd, ".git/index")), changed);
			if (change === "branch")
				assert.equal(await f.git("branch", "--show-current"), "other");
			await f.sameWorktree();
		}));
}
for (const phase of ["pre-commit", "post-commit"]) {
	test(`${phase} index edits retained and execution stops`, () =>
		fixture(async (f) => {
			const hook = join(f.cwd, ".git/hooks", phase);
			await writeFile(hook, '#!/bin/sh\nprintf "hook B\\n" > B\ngit add B\n');
			await chmod(hook, 0o700);
			await f.invoke({ all: true });
			await f.sameIndex();
			assert.equal(f.attempts(), 1);
			const dirs = await f.backups();
			assert.equal(dirs.length, 1);
			const result = await f.run("env", [
				`GIT_INDEX_FILE=${join(f.cwd, ".git", dirs[0], "commit.index")}`,
				"git",
				"show",
				":B",
			]);
			assert.equal(result.stdout, "hook B\n");
			assert(
				f.notes.some((n) => n.message.includes("hook or another process")),
			);
		}));
}
test("failing hook preserves original staging and hook index", () =>
	fixture(async (f) => {
		const hook = join(f.cwd, ".git/hooks/pre-commit");
		await writeFile(
			hook,
			'#!/bin/sh\nprintf "hook B\\n" > B\ngit add B\nexit 1\n',
		);
		await chmod(hook, 0o700);
		await f.invoke();
		await f.sameIndex();
		assert.equal(f.attempts(), 1);
		assert.equal((await f.backups()).length, 1);
	}));
test("real index lock blocks another ordinary git add during execution", () =>
	fixture(async (f) => {
		let checked = false;
		await f.invoke({
			intercept: async ({ gitArgs }) => {
				if (gitArgs[0] === "commit" && !checked) {
					checked = true;
					const r = await f.run("git", ["add", "B"]);
					assert.notEqual(r.code, 0);
					assert(r.stderr.includes("index.lock"));
				}
			},
		});
		assert(checked);
		assert(f.notes.some((n) => n.message === "Committed 2 commit(s)"));
	}));
test("out-of-band index modification is never overwritten", () =>
	fixture(async (f) => {
		let changed;
		await f.invoke({
			all: true,
			intercept: async ({ gitArgs, attempts }) => {
				if (gitArgs[0] === "commit" && attempts === 2) {
					const alternate = join(f.cwd, ".git/other.index");
					await copyFile(join(f.cwd, ".git/index"), alternate);
					const r = await f.run("env", [
						`GIT_INDEX_FILE=${alternate}`,
						"git",
						"add",
						"B",
					]);
					assert.equal(r.code, 0);
					changed = await readFile(alternate);
					await writeFile(join(f.cwd, ".git/index"), changed);
					return fail;
				}
			},
		});
		assert.deepEqual(await readFile(join(f.cwd, ".git/index")), changed);
		assert(f.notes.some((n) => n.message.includes("changed concurrently")));
	}));
test("branch switch during execution is not rolled back", () =>
	fixture(async (f) => {
		await f.invoke({
			all: true,
			intercept: async ({ gitArgs, attempts }) => {
				if (gitArgs[0] === "commit" && attempts === 2) {
					await f.git("branch", "other");
					await f.git("symbolic-ref", "HEAD", "refs/heads/other");
					return fail;
				}
			},
		});
		await f.sameIndex();
		assert.equal(await f.git("branch", "--show-current"), "other");
	}));
test("exception after Git updates HEAD retains staging and recovery", () =>
	fixture(async (f) => {
		await f.invoke({
			all: true,
			intercept: async ({ command, args, options, gitArgs, run }) => {
				if (gitArgs[0] === "commit") {
					const r = await run(command, args, options);
					assert.equal(r.code, 0);
					throw new Error("adapter interrupted");
				}
			},
		});
		await f.sameIndex();
		assert.equal((await f.backups()).length, 1);
		assert.equal(await f.git("show", "HEAD:A"), "working A");
	}));
test("unborn repository is supported", () =>
	fixture(
		async (f) => {
			await f.invoke();
			assert.equal(await f.git("rev-list", "--count", "HEAD"), "2");
			assert.equal(await f.git("diff", "--cached", "--name-only"), "");
			await f.sameWorktree();
		},
		{ unborn: true },
	));
test("split index is preserved and recovery snapshot is standalone", () =>
	fixture(async (f) => {
		await f.git("update-index", "--split-index");
		const original = await readFile(join(f.cwd, ".git/index"));
		await f.invoke({
			intercept: ({ gitArgs }) => (gitArgs[0] === "commit" ? fail : undefined),
		});
		assert.deepEqual(await readFile(join(f.cwd, ".git/index")), original);
		const [dir] = await f.backups();
		const standalone = join(f.cwd, ".git", dir, "original-standalone.index");
		for (const name of await readdir(join(f.cwd, ".git")))
			if (name.startsWith("sharedindex.")) await rm(join(f.cwd, ".git", name));
		const r = await f.run("env", [
			`GIT_INDEX_FILE=${standalone}`,
			"git",
			"show",
			":B",
		]);
		assert.equal(r.code, 0, r.stderr);
		assert.equal(r.stdout, "staged B\n");
	}));
test("SIGKILL after first /all commit preserves original index and durable recovery", () =>
	fixture(async (f) => {
		const childPath = join(f.cwd, ".git/crash-test.mjs");
		const childSource = `import {writeFile} from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec = promisify(execFile);
const {default: register} = await import(${JSON.stringify("data:text/javascript;base64," + Buffer.from(stripTypeScriptTypes(isolated)).toString("base64"))});
let handler;
register({registerCommand: (_, c) => handler = c.handler, exec: async (cmd,args,opts) => {
  const result = await exec(cmd,args,opts);
  if (args.includes('commit')) {
    await writeFile('.git/commit-finished', 'ready');
    await new Promise(() => setInterval(() => {}, 1000));
  }
  return {...result,code:0};
}});
let calls=0;
await handler('all',{cwd:process.cwd(),hasUI:true,ui:{notify:()=>{},input:async()=>'',custom:async()=>++calls===1?${JSON.stringify(plan)}:true}});
`;
		await writeFile(childPath, childSource);
		const env = Object.fromEntries(
			Object.entries(process.env).filter(([k]) => !k.startsWith("GIT_")),
		);
		Object.assign(env, {
			GIT_CONFIG_NOSYSTEM: "1",
			GIT_CONFIG_GLOBAL: "/dev/null",
		});
		const child = spawn(process.execPath, [childPath], {
			cwd: f.cwd,
			env,
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stderr = "";
		child.stderr.on("data", (chunk) => (stderr += chunk));
		let timer;
		try {
			await Promise.race([
				(async () => {
					while (child.exitCode === null && child.signalCode === null) {
						try {
							await readFile(join(f.cwd, ".git/commit-finished"));
							return;
						} catch (e) {
							if (e.code !== "ENOENT") throw e;
						}
						await new Promise((resolve) => setTimeout(resolve, 20));
					}
					throw new Error(`Child exited: ${stderr}`);
				})(),
				new Promise((_, reject) => {
					timer = setTimeout(
						() => reject(new Error("Crash fixture timed out: " + stderr)),
						10000,
					);
				}),
			]);
			const exited = once(child, "exit");
			child.kill("SIGKILL");
			await exited;
			await f.sameIndex();
			assert.equal(await f.git("show", "HEAD:A"), "working A");
			const [dir] = await f.backups();
			assert(dir);
			const planned = join(f.cwd, ".git", dir, "planned.index");
			const r = await f.run("env", [
				`GIT_INDEX_FILE=${planned}`,
				"git",
				"show",
				":B",
			]);
			assert.equal(r.stdout, "working B\n");
			assert(
				(
					await readFile(join(f.cwd, ".git", dir, "planned.patch"), "utf8")
				).includes("+working B"),
			);
			// Only this fixture's killed process owned the lock; no child Git remains.
			await rm(join(f.cwd, ".git/index.lock"));
		} finally {
			clearTimeout(timer);
			if (child.exitCode === null && child.signalCode === null) {
				const exited = once(child, "exit");
				child.kill("SIGKILL");
				await exited;
			}
		}
	}));
test("merge in progress is refused without touching the index", () =>
	fixture(async (f) => {
		await writeFile(
			join(f.cwd, ".git/MERGE_HEAD"),
			await f.git("rev-parse", "HEAD"),
		);
		await f.invoke({ all: true });
		await f.sameIndex();
		assert.equal(f.attempts(), 0);
		assert(f.notes.some((n) => n.message.includes("Finish the merge")));
	}));
test("existing index lock is respected", () =>
	fixture(async (f) => {
		await writeFile(join(f.cwd, ".git/index.lock"), "another process");
		await f.invoke({ all: true });
		await f.sameIndex();
		assert.equal(f.attempts(), 0);
		assert.equal(
			await readFile(join(f.cwd, ".git/index.lock"), "utf8"),
			"another process",
		);
	}));

test("binary staged contents bypass display-only text conversion", () =>
	fixture(async (f) => {
		const converter = join(f.cwd, ".git/preview");
		await writeFile(converter, '#!/bin/sh\nprintf "display only\\n"\n');
		await chmod(converter, 0o700);
		await f.put(".gitattributes", "B diff=preview\n");
		await f.git("config", "diff.preview.textconv", converter);
		await f.put("B", Buffer.from("staged\0binary\n"));
		await f.git("add", "B");
		await f.put("B", Buffer.from("working\0binary\n"));
		await f.invoke();
		assert.equal(await f.git("show", "HEAD:B"), "staged\0binary");
		assert.deepEqual(
			await readFile(join(f.cwd, "B")),
			Buffer.from("working\0binary\n"),
		);
		assert(
			f.notes.some((n) => n.message === "Committed 2 commit(s)"),
			JSON.stringify(f.notes),
		);
	}));

const unusualNames = [
	" leading",
	"trailing ",
	"   ",
	"tab\tname",
	"line\nbreak\n",
	"å.txt",
	"日本語.txt",
	'a"quote',
	"a'quote",
	"back\\slash",
	"`ticks`",
	"a*.txt",
	"a?.txt",
	"a[bc].txt",
	"a.txt",
	"ab.txt",
	"abc.txt",
	"-dash",
	":(glob)*",
	":(top)a.txt",
	":",
	"old -> new",
	"item-1",
	"x -> y -> z",
	"replacement-�",
	"\uFEFFbom",
];
const renames = [
	["old", "new"],
	["x -> y", "z"],
	["x", "y -> z"],
	[" old\t*", " new\n? "],
];
for (const all of [false, true]) {
	test(`literal filenames and ambiguous rename labels produce exact commits, all=${all}`, () =>
		fixture(async (f) => {
			await f.git("add", "-A");
			await f.git("commit", "-qm", "setup");
			for (const [i, name] of unusualNames.entries())
				await f.put(name, `base ${i}\n`);
			for (const [i, [old]] of renames.entries())
				await f.put(old, `rename content ${i}\n`);
			await f.put("deleted\t? ", "delete me\n");
			await f.git("add", "-A");
			await f.git("commit", "-qm", "filename base");
			const base = await f.git("rev-parse", "HEAD");
			const contents = new Map();
			for (const [i, name] of unusualNames.entries())
				contents.set(name, `staged ${i}\n`);
			for (const [i, [old, target]] of renames.entries()) {
				await rm(join(f.cwd, old));
				contents.set(target, `rename content ${i}\n`);
			}
			for (const name of [" new\tfile\n ", "-new", ":new", 'new"*.txt'])
				contents.set(name, "added content\n");
			await rm(join(f.cwd, "deleted\t? "));
			for (const [name, content] of contents) await f.put(name, content);
			await f.git("add", "-A");
			const expectedTree = await f.git("write-tree");
			const { stdout } = await f.run("git", [
				"diff",
				"--cached",
				"--name-status",
				"-z",
				"--find-renames",
			]);
			const entries = parseStagedEntries(stdout);
			const assigned = [
				...unusualNames.map((name) => [name]),
				...renames,
				["deleted\t? "],
				...[" new\tfile\n ", "-new", ":new", 'new"*.txt'].map((name) => [name]),
			];
			assert.deepEqual(
				entries.map((e) => JSON.stringify(e.patchPaths)).sort(),
				assigned.map((p) => JSON.stringify(p)).sort(),
			);
			assert.equal(new Set(entries.map((e) => e.key)).size, assigned.length);
			const ordered = entries.toReversed();
			const customPlan = {
				commits: ordered.map((entry, i) => ({
					message: `test: literal item ${i}`,
					items: [entry.key],
					description: "",
				})),
			};
			if (!all)
				for (const name of contents.keys())
					await f.put(name, `unstaged ${name}\n`);
			await f.invoke({ all, plan: customPlan });
			assert(
				f.notes.some(
					(n) => n.message === `Committed ${entries.length} commit(s)`,
				),
				JSON.stringify(f.notes),
			);
			const commits = (
				await f.git("rev-list", "--reverse", `${base}..HEAD`)
			).split("\n");
			assert.equal(commits.length, ordered.length);
			for (const [i, hash] of commits.entries()) {
				const result = await f.run("git", [
					"diff-tree",
					"--no-commit-id",
					"--name-only",
					"--no-renames",
					"-r",
					"-z",
					hash,
				]);
				assert.equal(result.code, 0, result.stderr);
				assert.deepEqual(
					result.stdout.split("\0").slice(0, -1).sort(),
					[...ordered[i].patchPaths].sort(),
				);
				for (const path of ordered[i].patchPaths) {
					if (!contents.has(path)) continue;
					const blob = await f.run("git", ["show", `${hash}:${path}`]);
					assert.equal(blob.code, 0, blob.stderr);
					assert.equal(blob.stdout, contents.get(path));
				}
			}
			assert.equal(await f.git("rev-parse", "HEAD^{tree}"), expectedTree);
			assert.equal(await f.git("diff", "--cached", "--name-only"), "");
			for (const [name, content] of contents)
				assert.equal(
					await readFile(join(f.cwd, name), "utf8"),
					all ? content : `unstaged ${name}\n`,
				);
			assert.deepEqual(await f.backups(), []);
		}));
}

test("NUL parser preserves fields and consumes rename/copy records", () => {
	const entries = parseStagedEntries(
		"R100\0 old\t\n\0new \0C075\0source\0copy\0A\0   \0D\0gone\0",
	);
	assert.deepEqual(
		entries.map((e) => e.patchPaths),
		[[" old\t\n", "new "], ["source", "copy"], ["   "], ["gone"]],
	);
	assert.deepEqual(
		entries.map((e) => e.key),
		["item-1", "item-2", "item-3", "item-4"],
	);
	assert.equal(entries[3].contentPath, undefined);
	for (const invalid of [
		"A\0path",
		"R100\0old\0",
		"A\0\0",
		"U\0conflict\0",
		"\0",
	])
		assert.throws(() => parseStagedEntries(invalid));
	assert.deepEqual(parseStagedEntries(""), []);
});

for (const items of [
	[" item-1 ", "item-2"],
	["A", "B"],
	["item-1", "item-1"],
	["item-1", "unknown"],
]) {
	test(`invalid item IDs are rejected literally: ${JSON.stringify(items)}`, () =>
		fixture(async (f) => {
			await f.invoke({
				plan: {
					commits: [{ message: "test: invalid", items, description: "" }],
				},
			});
			assert.equal(f.attempts(), 0);
			assert(f.notes.some((n) => n.message.includes("Commit plan is invalid")));
			await f.sameIndex();
		}));
}

test("review shows escaped paths alongside opaque IDs", () => {
	const entries = parseStagedEntries(
		"R100\0old\0new\0A\0old -> new\0A\0a\n`*[x]\\\0",
	);
	const preview = renderPlanMarkdown(
		{
			commits: [
				{
					message: "test: preview",
					items: entries.map((e) => e.key),
					description: "",
				},
			],
		},
		new Map(entries.map((e) => [e.key, e])),
	);
	assert(preview.includes('item-1: R100 \\["old","new"\\]'));
	assert(preview.includes('item-2: A \\["old \\-\\> new"\\]'));
	assert(!preview.includes("a\n"));
	assert(preview.includes("a\\\\n\\`\\*\\[x\\]"));
});

for (const all of [false, true]) {
	test(`non-UTF-8 names fail safely before planning, all=${all}`, () =>
		fixture(async (f) => {
			// A valid replacement-character filename must not alias a raw invalid byte.
			await f.put("bad-�", "valid name\n");
			const rawPath = Buffer.concat([
				Buffer.from(f.cwd + "/bad-"),
				Buffer.from([0xff]),
			]);
			await writeFile(rawPath, "invalid name\n");
			if (!all) await f.git("add", "-A");
			const beforeIndex = await readFile(join(f.cwd, ".git/index"));
			const beforeHead = await f.git("rev-parse", "HEAD");
			let prompted = false;
			await f.invoke({
				all,
				input: () => {
					prompted = true;
				},
			});
			assert.equal(prompted, false);
			assert.equal(f.attempts(), 0);
			assert(
				f.notes.some((n) => n.message.includes("invalid UTF-8")),
				JSON.stringify(f.notes),
			);
			assert.deepEqual(await readFile(join(f.cwd, ".git/index")), beforeIndex);
			assert.equal(await f.git("rev-parse", "HEAD"), beforeHead);
			assert.equal(await readFile(rawPath, "utf8"), "invalid name\n");
			assert.deepEqual(await f.backups(), []);
		}));
}

test("model prompt maps exact IDs to JSON paths and response retains IDs", async () => {
	const entries = parseStagedEntries(
		"R100\0old\0new\0A\0old -> new\0A\0 white\t\nspace \0",
	);
	const responsePlan = {
		commits: [
			{
				message: "test: paths",
				items: entries.map((e) => e.key),
				description: "",
			},
		],
	};
	globalThis.commitTestComplete = async (_model, request) => {
		const prompt = request.messages[0].content[0].text;
		assert(prompt.includes('item-1: R100 ["old","new"]'));
		assert(prompt.includes('item-2: A ["old -> new"]'));
		assert(prompt.includes('item-3: A [" white\\t\\nspace "]'));
		assert(!prompt.includes("\0"));
		assert(request.systemPrompt.includes("never filenames or display labels"));
		return { content: [{ type: "text", text: JSON.stringify(responsePlan) }] };
	};
	try {
		const result = await generateCommitPlan(
			{
				model: { provider: "fixture" },
				modelRegistry: {
					getApiKeyAndHeaders: async () => ({ ok: true, apiKey: "fixture" }),
				},
			},
			"diff fixture",
			entries,
			"",
			"",
			new AbortController().signal,
		);
		assert.deepEqual(result, responsePlan);
	} finally {
		delete globalThis.commitTestComplete;
	}
});
