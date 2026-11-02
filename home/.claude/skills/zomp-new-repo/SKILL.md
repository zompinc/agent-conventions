---
name: zomp-new-repo
description: Zomp setup for a new repository or project - first-commit files (.gitattributes, .editorconfig, .gitignore, README), pnpm, the husky pre-commit hook with Prettier and a final-newline check, and shared VS Code tasks, launch and extension recommendations. Load this before creating a repository or its first commit, and before adding hooks, formatting, editor config or .vscode files to an existing repo.
---

# New repository setup

These extend `AGENTS.md`, which stays in force (default branch `master`, versioning, CI runners, the `.gitignore` and first-commit checks). For .NET, also load `zomp-dotnet`.

Template files are in `templates/` beside this file. Copy them; do not reinvent them.

## First commit

1. `.gitattributes` and `.editorconfig` from `templates/`. Two-space indents everywhere unless a stack's formatter decides otherwise (C# 4, Rust's rustfmt). An exception gets its own section with a comment saying why.
1. `.gitignore`, scoped per the rule in `AGENTS.md`.
1. A README: what it is, how to build and run it, how to deploy.
1. No license without asking. It is the owner's call.

## pnpm and the pre-commit hook

pnpm is the package manager wherever there is a choice, including in repos whose only Node tooling is the hook. Not npm, not yarn.

1. `pnpm add -D husky prettier` and `"prepare": "husky"` in `package.json` (husky 9; `husky install` is the deprecated v8 form).
1. Copy `templates/.husky/pre-commit`, `templates/scripts/end-of-file.sh` and `templates/.prettierignore`. Add the stack's check at the end of the hook (`dotnet format --verify-no-changes ... whitespace`, `cargo fmt --check`).
1. Keep both scripts executable in git: `git update-index --chmod=+x .husky/pre-commit scripts/end-of-file.sh` (Windows does not record it otherwise).
1. Before the first commit, format what the hook checks, once: `pnpm exec prettier --write` over the JSON, Markdown and YAML files. Otherwise the first person to touch an untouched file gets a failure they did not cause.
1. Prove it: stage a tab-indented `.json` and a file without a final newline; the hook must reject both. Then `sh .husky/pre-commit all` must pass on the whole tree.

No `.prettierrc`: Prettier's defaults (2 spaces) match `.editorconfig`.

## VS Code

Track these and ignore the rest of `.vscode`:

```gitignore
/.vscode/*
!/.vscode/settings.json
!/.vscode/tasks.json
!/.vscode/launch.json
!/.vscode/extensions.json
```

Add a file when the repo has something to put in it, not as an empty placeholder. A library may need only `tasks.json`; a docs site may need only `launch.json` and `extensions.json`. Repo-specific tracked extras, such as a spelling dictionary or debug helper scripts, get their own `!` line.

### tasks.json

One task per thing a developer runs: build, test, preview, dev loop, deploy.

- `build` and `test` use exactly those labels and are the default tasks of their groups (`"group": { "kind": "build", "isDefault": true }`), so the keyboard shortcuts work in every repo and `preLaunchTask` always has the same name to point at.
- Everything else is labelled `Area: action`, such as `coverage: report` or `SD: flash image`, so related tasks sort together. Add a `detail` when the label cannot say what the task needs or does.
- Prefer `"type": "process"` with `args`. Use `shell` only for shell features. Long logic belongs in `scripts/`, and the task calls it, so it can run outside VS Code and be reviewed as code.
- Use `$msCompile` for .NET builds, with `/property:GenerateFullPaths=true` so errors are clickable, and name the solution explicitly. Tasks that compile nothing set `"problemMatcher": []`, otherwise VS Code asks which matcher to use on every run.
- Ask for parameters with `inputs` (`${input:disk}`) rather than making people edit the file.
- Tasks act on `${workspaceFolder}`, so opening a worktree and running a task uses that worktree's branch. Find tools with a script (`vswhere`, not an install path).
- Tasks can carry `//` comments. Use them for why a task exists or a non-obvious workflow.

### launch.json

Debug configurations for what the tasks run.

- `preLaunchTask` builds first, and `program` points at the build output under `artifacts/`.
- Name a configuration after what it runs and how. Add one configuration per variation, such as a second user or environment, instead of editing `env`.
- A web app uses `serverReadyAction` to open the browser when the server is ready.
- Background tasks that a configuration starts need a `problemMatcher` with a `background` section, so VS Code knows when they are ready.

### extensions.json

Only extensions the repo relies on, each for a reason: the language servers, the debugger a `launch.json` type needs (CodeLLDB for `lldb`), `esbenp.prettier-vscode`, and `EditorConfig.EditorConfig` (VS Code ignores `.editorconfig` without it). .NET repos recommend `ms-dotnettools.csharp`. A personal preference does not belong here, and a replaced extension moves to `unwantedRecommendations` rather than being listed in both.

### settings.json

Only settings every contributor needs for the repo to work, such as a toolchain configuration. Personal ones stay in user settings. Most repos need no `settings.json`.

### All of them

No personal hosts, usernames, addresses or absolute paths in any of them. A task that needs a machine or router takes it from the environment (`"env": { "ROUTER": "${env:ROUTER}" }`), and the script fails clearly when it is unset rather than quietly doing less.

Use `${workspaceFolder}` for paths.

## Existing repos

Older repos differ (yarn instead of pnpm, `husky install`, no newline check). Bring one into line when you are next working in it; do not open a sweep across repos.
