# Zomp - Global Agent Conventions

Zomp (zomp.com) builds software for clients.
These conventions apply to all Zomp projects unless a repo-level AGENTS.md overrides them.

## Skills

Conventions that only apply to one stack or one task live in skills, so they load when relevant instead of costing context in every session. The rules below this line apply everywhere.

- **.NET / C#**: load the `zomp-dotnet` skill before making stack, architecture, packaging, testing, versioning, or build-configuration decisions in a C#/.NET repository.
- **New repository**: load the `zomp-new-repo` skill before creating a repository or its first commit, or adding hooks, formatting, editor config or `.vscode` files to one (pnpm, the husky pre-commit hook, shared VS Code tasks, launch and extensions).
- **CI and build versioning**: load the `zomp-ci` skill before creating or editing any file under `.github/workflows`, before adding an `actions/upload-artifact` step, and before wiring build-time version stamping into a project.

## Versioning

Every deployable project derives its version from git, never hardcoded, and surfaces that version in a fixed, well-known location so any deployed environment can answer "which version is this?" without source access. Which location depends on the stack: a window title or About dialog for desktop, a `<meta>` tag plus `/build-info.json` for web, an image label plus a `/version` endpoint for services.

The mechanics live in skills: `zomp-ci` for git SHA capture in CI and the per-stack surfacing recipes, `zomp-dotnet` for the Nerdbank.GitVersioning setup.

## Git

- Default branch is **`master`** on all Zomp repos. Target `master` for PRs and never assume `main`. For non-Zomp repos, check the upstream default (`git symbolic-ref refs/remotes/origin/HEAD`).
- Never commit PR-bound work to `master`/`main`. Create the topic branch (`fix/foo`, `feature/bar`) *before* the first commit. Discovering after the fact that you committed to the default branch forces a history rewrite (`git branch <topic>; git reset --hard origin/<default>`) and is easy to get wrong - start on a branch.
- Exception: trivial standalone changes that don't warrant PR review - a single dev-utility script, a typo fix in a comment, etc. - can be committed straight to the default branch. If the change touches product code, build config, or anything a reviewer would reasonably want to see, it's PR-bound and needs a topic branch.
- **Never push to `master`/`main` unless specifically instructed.** An instruction to commit or push directly to the default branch covers that one change only; it is not a standing mode for the rest of the session. The next change goes back to a topic branch and a PR unless the user says otherwise again.
- Never open a PR from your fork's `master`/`main` branch. PRs from the default branch can't be updated cleanly once upstream moves and leave your fork unable to sync without rewriting history.
- **Commit early, commit often.** Every coherent change that compiles and passes its tests should be its own commit on the topic branch - don't batch a half-day of work into one giant working-tree state waiting for a final "all done" commit. The branch is the work-in-progress space; rebase/squash before the PR if a tidy history matters. Specifically: **before any risky multi-file transformation** (mass renames, scripted rewrites across many files, anything driven by `sed`/`awk`/regex over the tree, dependency-graph refactors), commit the current state first. If the transformation goes sideways, `git restore` brings the tree back instantly - hours of uncommitted work clobbered by a wide `git checkout HEAD -- <glob>` are unrecoverable.
- **Keep commit messages short.** The subject says what changed. Add a body only for the *why* a reviewer can't get from the diff, its comments, or the PR - usually one or two lines, often none. Don't restate the diff, narrate the debugging, or list edge cases the code already documents. A body that runs longer than the change it describes reads as machine-generated.
- Never run `git checkout HEAD -- <broad-glob>` (e.g. `'*.cs'`, `.`) while uncommitted work exists in those paths - it permanently destroys the working-tree changes. If the goal is "revert a specific accidental edit," scope the path tightly and verify `git status` first. When in doubt, `git stash` is reversible; `git checkout HEAD --` is not.
- **Squash-merge PRs** (`gh pr merge --squash`) unless the PR is a single commit or the user explicitly asks for a different merge strategy. Topic-branch fix-up commits ("address review", "fix typo") are noise on the default branch; one commit per PR keeps history linear and revertable. A single-commit PR can merge as-is since there is nothing to squash.
- **History is linear - never create a merge commit.** To pick up another branch's work, or to bring a branch up to date, rebase: `git rebase <base>`, `git rebase --onto <newbase> <upstream>`, `git pull --rebase`. Never `git merge` one topic branch into another, and never resolve a stale branch with a merge. If a merge commit already exists, flatten it with `git rebase <base>` before pushing - rebase drops merges and replays the real commits in order.
- **Worktrees go in a sibling folder named after the repo plus `.wt`**, one subfolder per branch, named after the branch with slashes replaced by dashes: a repo `myapp` on `feature/popup-polish` gets `../myapp.wt/feature-popup-polish`, via `git worktree add ../myapp.wt/feature-popup-polish -b feature/popup-polish <base>`. Don't put them directly beside the repo (`../myapp-popup-polish`), and prefer this over the harness's `.claude/worktrees/` inside the checkout. If the repo has its own worktree script, use that instead - it may wire up things a bare `git worktree add` does not, such as local secrets or agent memory. Why: each repo gets one `.wt` folder that sorts right next to its checkout, a directory full of repos stays readable, and the worktrees stay out of the main checkout's file watchers, searches and solution explorer.
- Rewriting a topic branch that is already pushed is fine and expected. Push it back with `git push --force-with-lease`, never a bare `--force`: `--force-with-lease` refuses the push if someone else moved the branch meanwhile, which a bare force would silently discard. Never rewrite `master`.
- **Never write a bare `*.ext` rule in `.gitignore` if any directory in the repo ends in `.ext`.** Patterns without a slash match directory components as well as file names, and Windows sets `core.ignorecase=true` by default, so `*.vsix` also matches `src/MyApp.Vsix/` and silently untracks every file beneath it. This fails in the worst possible way: the solution still builds and runs from disk, `git status` stays clean because ignored files are not reported, and nothing surfaces until someone clones fresh or the machine dies. Scope the rule to where the output actually lands - usually `artifacts/`, which is ignored wholesale anyway, making the rule redundant as well as harmful - or anchor it: `/artifacts/**/*.vsix`. Diagnose a suspect path with `git check-ignore -v <path>`, which names the rule and line number responsible.
- **On a repo's first commit, verify every project is actually tracked.** `git ls-files <dir>` should not be empty for any directory you just scaffolded. An ignored directory never announces itself, so "the build works" and "the tests pass" are both true of a repo missing a whole project, and a clean `git status` is not evidence of anything.

## Markdown

Use `1.` for **every** item in an ordered list rather than `1.`/`2.`/`3.`. CommonMark and GFM ignore the marker numbers after the first one and renumber sequentially when rendered, so `1.`/`1.`/`1.` displays identically to `1.`/`2.`/`3.` but keeps diffs small and lets items be reordered or inserted without manual renumbering.

```markdown
1. First item
1. Second item
1. Third item
```

If a list must start at a value other than 1, set the first marker to that value and use `1.` for the rest - only the first marker controls the start. When editing existing files that follow `1./2./3.`, prefer matching the file's existing style if the renumber diff would be unrelated noise.

## Text and typography

Use plain ASCII punctuation in all written artifacts (code, comments, commit messages, READMEs, estimates, contracts, docs, AGENTS files). Avoid Unicode dashes (en-dash `-`, em-dash `-`) and other typographic substitutes (curly quotes `' ' " "`, ellipsis `...`).

Use instead:

- ASCII hyphen `-` for ranges (`4"-22"`, `pages 1-10`) and parenthetical asides (` - like this - `).
- A colon or semicolon for a sentence break that would otherwise call for an em-dash.
- Parentheses for a parenthetical that would otherwise call for paired em-dashes.
- Straight quotes `"` and `'`. Three periods `...` for ellipsis.

Why: ASCII punctuation survives copy-paste between tools (Word, Sheets, terminals, OCR, search), is greppable, types in one keystroke, and renders identically on every platform. Typographic dashes look slightly nicer in a polished PDF but their cost in tooling friction and inconsistency across documents is real.

When fixing existing files, only sweep dashes you authored or are otherwise editing. Don't make sweeping typography-only commits across someone else's work - surface the rule and let them sweep on their next pass.

## Line breaks

Never hard-wrap prose that is going into a web UI: GitHub issue and PR bodies, review and issue comments, Slack messages, web forms, anything with a textarea. Write each paragraph as one continuous line and separate paragraphs with a blank line. Let the renderer wrap it.

Hard-wrapping in those places is a reliable tell that text was machine-generated, because nobody typing into a browser inserts a newline every 76 columns. It also reflows badly: a fixed wrap that looks tidy at the author's width turns ragged in a narrow sidebar, on a phone, or inside a quoted reply, and it breaks grep and copy-paste of any sentence that straddles a break.

Hard wrapping is still correct in these places, so do not sweep them:

- **Git commit messages** - wrap the body at ~72 columns, per the long-standing convention. `git log` does not reflow.
- **Source comments** - follow the file's existing width.
- **Repo markdown and plain-text files** - match whatever the file already does. A repo that hand-wraps its docs at 80 stays hand-wrapped; a repo that writes one line per paragraph stays that way. Check before adding to an existing file.

The distinction is whether something else does the wrapping. A renderer wraps for you, so give it unbroken text; a terminal or a diff does not, so wrap it yourself.

## PRs and issues

Keep PR descriptions, PR and review comments, and issue bodies as short as possible: what changed or what is broken, one line of cause, one line of fix. Leave out thanks and sign-offs, restatements of the diff, background the reader can get from the linked code, and offers to change things.

Why: every sentence is something the reader has to process, and padded text reads as machine-generated. Draft, then cut until removing anything more would lose a fact the reader needs. A code snippet plus two sentences usually beats prose; use a table only when it replaces more text than it adds.

When a PR fully resolves an issue, link it with a closing keyword (`Fixes #123`) so the issue closes on merge; use whichever keyword the repo's merged PRs already use. For partial work write `Part of #123`, without a keyword. Words like "Addresses" or "Relates to" create no link, so the issue stays open after merge and has to be closed by hand. Keywords only take effect when the PR targets the default branch.

## Paths and references

Never use absolute filesystem paths (`C:\...`, `Q:\...`, `/home/...`, `/c/Users/...`) in any artifact a collaborator, client, or future contributor might read - READMEs, slide decks, code comments, commit messages, AGENTS files, anything. They reveal the author's personal machine layout, don't work for anyone else, and look amateurish in client-facing material.

Cross-repo relative paths (`../sibling-repo/...`) carry the same problem - they assume a local clone directory layout and break for anyone who organises their checkouts differently.

Use instead:

- **Repo-relative paths** for references within the same repo (`docs/setup.md`).
- **GitHub URLs** for cross-repo references (`https://github.com/<org>/<repo>`, optionally with `/blob/<branch>/<path>`).
- **Repo-name plus a "clone first" instruction** when the reader needs to check out another repo ("Clone `device-firmware`, then `cd device-firmware/simulator`").
- **Tilde-relative paths** (`~/.config/...`) when documenting a genuine home-directory location - these are portable.

Heuristic: if a path contains a drive letter or starts with `/`, it's wrong.

## Agent session links

Never publish a Claude Code session URL (`https://claude.ai/code/session_...`) anywhere it leaves the local machine - PR bodies and titles, issue and review comments, commit messages and trailers (`Claude-Session:`), code comments, docs, client-facing material. This holds even when a default template or harness convention suggests including one. Add it only when explicitly asked to, for that specific artifact.

Why: the link is a private transcript of the working session. It can carry absolute paths, credentials seen in passing, unrelated client work, and half-formed reasoning that was never meant for an audience. It is useless to anyone without access, and its presence in a public repo invites people to ask what is behind it.

Do not add "Generated with Claude Code" or any other tool-attribution line to commit messages, PR bodies, issues or comments, even when a harness default appends one. It tells the reader nothing they act on, and on projects with an AI contribution policy it reads as the metadata those policies ask contributors to strip. If a project's contribution policy requires disclosure, disclose in the form that policy prescribes, and only there.

Never add `Co-Authored-By:` trailers with an AI-account email (e.g. `noreply@anthropic.com`), even when a harness default suggests one. GitHub maps the email to the AI's account and lists it in the repo's Contributors sidebar; contributor lists should stay limited to the humans, even when they work with agents. There is no GitHub setting to delist a contributor after the fact - removing one means rewriting every commit that carries the trailer and force-pushing, so prevention is the only cheap option. Human `Co-authored-by:` trailers are fine and must be preserved.

If a session link has already been published, say so plainly and offer to remove it. Note that stripping one from an already-pushed commit message means rewriting history and force-pushing, which is a bigger decision than editing a PR body.

## Android application IDs

Use the reverse domain of the **client's** actual domain, not a generic placeholder.
Example: client domain `example.com` -> `com.example.appname`.

## Branding

Where permission exists, include a "Powered by Zomp" credit in client applications.
Placement is project-specific - About dialog or status footer are the natural locations.
