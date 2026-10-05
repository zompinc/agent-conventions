# Zomp Dev Conventions

Cross-project conventions for Zomp engineers - git workflow, documentation style, CI, versioning, branding. The shipped file is [`home/AGENTS.md`](home/AGENTS.md). It's named `AGENTS.md` because that's the cross-tool convention all major AI coding agents (Claude Code, Codex, Cursor, Aider) walk up the directory tree to find.

These are one company's opinions, published because they may be useful to others setting up the same thing. Fork and adapt; nothing here needs to be agreed with.

Conventions that apply to only one stack, or only to one kind of task, live in [`skills/`](./skills) instead. `home/AGENTS.md` is loaded into every session regardless of language, so putting .NET rules there charged a Rust session roughly 2,000 tokens for advice it could not use - and, worse, stated rules like "never WPF" as if they were unconditional. A skill loads on demand: only its name and one-line description sit in context until something makes it relevant.

## Setup (one command)

This repo is meant to be cloned to a stable location and **symlinked into your home directory** so every project's AI agent picks it up automatically. Updates flow with `git pull`.

### Windows (PowerShell)

```powershell
# Run from any directory. Requires Developer Mode enabled (Settings -> Privacy & Security -> For developers -> Developer Mode), OR run as admin.
git clone git@github.com:zompinc/agent-conventions.git $HOME\agent-conventions
& $HOME\agent-conventions\bootstrap.ps1
```

### macOS / Linux

```bash
git clone git@github.com:zompinc/agent-conventions.git ~/agent-conventions
~/agent-conventions/bootstrap.sh
```

No SSH key set up? Swap either clone URL for `https://github.com/zompinc/agent-conventions.git`. Everything below works the same; you only need SSH, or a credential helper, to push a change back.

That's it. Verify with `cat ~/AGENTS.md` - it should show this repo's content - and `ls ~/.claude/skills`, which should list a link per skill in this repo.

Both scripts are idempotent, so re-run them any time. They only ever create links; nothing is copied into your home directory unless symlink creation fails. Everything of value stays in this repo, so a dead machine costs you a `git clone` and one bootstrap run.

## Updating

```bash
cd ~/agent-conventions && git pull
```

If you symlinked, the change is live immediately. If you copied (no Dev Mode on Windows), re-run the bootstrap to refresh the copy.

## What's in scope

- `home/AGENTS.md` - always-resident conventions (git, docs and prose style, versioning principle, branding), symlinked to `~/AGENTS.md`
- `skills/<name>/SKILL.md` - stack- or activity-specific conventions, loaded on demand
  - `zomp-dotnet` - .NET/C# stack defaults, architecture, packaging, build quality
  - `zomp-new-repo` - first-commit files, pnpm, the husky pre-commit hook (templates included), shared `.vscode` files
  - `zomp-ci` - GitHub Actions runners, local `act` runs, artifact retention, build version stamping
- `AGENTS.md` - instructions for editing this repo, not shipped anywhere
- `bootstrap.ps1` / `bootstrap.sh` - create the symlinks and enable this repo's hooks
- `.githooks/` and `scripts/check-private-content.sh` - keep client names and machine paths out of a public repo

Future additions worth seeding here:

- Shared `.gitignore` global (`git config --global core.excludesfile`)
- Prettier / ESLint base configs
- VSCode `settings.json` defaults

## Editing conventions

Edit the file, commit, push. Everyone picks up the change on their next `git pull`; symlinks mean there is nothing to re-run unless you added a new skill.

This repo is public and gets edited while working inside private repos, so a pre-commit hook scans for client names, machine paths, IP addresses and session links before anything is committed. Client names go in `~/.config/zomp/private-words.txt`, which is never committed - see [`AGENTS.md`](AGENTS.md).

Which file: if violating the rule causes harm, it goes in `home/AGENTS.md`. Guardrails have to be in context *before* the mistake, and a skill only loads once the model already knows it needs it - which is never the case for the rule you are about to break. If the rule is something you look up while doing a task you know you are doing, it goes in that task's skill. Language-specific reference is the common case of the second, but it is the consequence of getting it wrong, not the language, that decides.

`home/AGENTS.md` is charged to every session of every language, so keep it to rules that earn that. Everything else is a skill.

Keep both terse. Agents process every byte of context.
