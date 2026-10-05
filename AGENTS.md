# agent-conventions - instructions for editing this repo

This file is for working **in this repository**. It is not shipped anywhere. The
conventions that get symlinked into every engineer's home directory live in
[`home/AGENTS.md`](home/AGENTS.md).

## This repository is public

Nothing here may contain a client name, a client project name, an internal
hostname, an IP address, a machine path, or an agent session URL. Use
placeholders: `example.com`, `<client>`, `~/path/to/repo`.

A rule that only makes sense with a client's specifics is not a convention yet.
Generalize it or leave it out.

The danger is editing this repo from inside a private client repo and carrying
an example across. Two guards:

- `scripts/check-private-content.sh` runs from the pre-commit hook on staged
  files, and in CI over every tracked file.
- Client names belong in a private word list that is never committed:
  `~/.config/zomp/private-words.txt`, one extended regex per line. A public
  denylist of client names would itself disclose who the clients are.

Deliberate counter-examples - the rules that quote a bad path on purpose - go in
`.private-content-allow`.

## Layout

- `home/AGENTS.md` - symlinked to `~/AGENTS.md`. Loaded in every session of
  every project, so every byte is charged to work that may not need it.
- `skills/<name>/SKILL.md` - symlinked into `~/.claude/skills/`. Loaded on
  demand, so only the name and description cost context until something makes
  the skill relevant.
- `.githooks/` - enabled by the bootstrap scripts through `core.hooksPath`.
- `scripts/check-private-content.sh` - the scanner, shared by the hook and CI.

## Which file a rule goes in

If breaking the rule causes harm, it goes in `home/AGENTS.md`. A guardrail has
to be in context *before* the mistake, and a skill only loads once the agent
already knows it needs it - which is never true of the rule it is about to
break.

If it is reference you look up while doing a task you know you are doing, it
goes in that task's skill. Language-specific reference is the common case, but
it is the consequence of getting it wrong, not the language, that decides.

## Before committing

- Hooks are on if `git config core.hooksPath` prints `.githooks`. The bootstrap
  scripts set it; a fresh clone needs one bootstrap run.
- Scan everything by hand with `sh scripts/check-private-content.sh --all`.
- Commit messages carry no AI `Co-Authored-By:` trailer and no session link; the
  `commit-msg` hook rejects both. A plain "Generated with Claude Code" line is
  fine.

Keep every file here terse. Agents process every byte.
