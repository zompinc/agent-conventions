# Zomp - Global Agent Conventions

Zomp (zomp.com) builds software for clients. These conventions apply to all Zomp projects unless a repo-level AGENTS.md overrides them.

## Skills

Load the skill before the task it covers:

- **.NET / C#**: `zomp-dotnet` before stack, architecture, packaging, testing, versioning, or build-configuration decisions in a C#/.NET repository.
- **New repository**: `zomp-new-repo` before creating a repository or its first commit, or adding hooks, formatting, editor config or `.vscode` files to one.
- **CI and build versioning**: `zomp-ci` before creating or editing anything under `.github/workflows`, adding an `actions/upload-artifact` step, or wiring build-time version stamping.
- **GitHub posting**: `zomp-github` before writing or posting any PR, issue, comment or review, and before merging a PR.
- **Rebasing**: `zomp-rebase` before any rebase or cherry-pick that rewrites a branch, and before resolving a conflict in one. Branches built on the one being rebased move with it.

## Versioning

Every deployable project derives its version from git, never hardcoded, and surfaces it in a fixed location: window title or About dialog for desktop, a `<meta>` tag plus `/build-info.json` for web, an image label plus a `/version` endpoint for services. Mechanics are in `zomp-ci` and `zomp-dotnet`.

## Git

- Default branch is **`master`** on Zomp repos; never assume `main`. For non-Zomp repos, check `git symbolic-ref refs/remotes/origin/HEAD`.
- Create the topic branch (`fix/foo`, `feature/bar`) *before* the first commit of PR-bound work. Only trivial standalone changes (a dev-utility script, a comment typo) may go straight to the default branch; anything touching product code or build config needs a PR.
- **Never push to `master`/`main` unless specifically instructed.** The instruction covers that one change only; the next one goes back to a topic branch.
- Never open a PR from your fork's default branch.
- **Commit early, commit often**: each coherent change that compiles and passes tests is its own commit. Commit before any risky multi-file transformation (mass renames, `sed`/regex over the tree, dependency refactors) so `git restore` can undo it.
- **Keep commit messages short.** The subject says what changed. Add a body only for a *why* the diff can't show, usually one or two lines.
- Never run `git checkout HEAD -- <broad-glob>` while uncommitted work exists in those paths: it destroys the changes irreversibly. Scope the path tightly, or use `git stash`.
- **History is linear; never create a merge commit.** Bring branches up to date with `git rebase` or `git pull --rebase`, never `git merge`. Flatten an existing merge commit with `git rebase <base>` before pushing.
- **Worktrees go in a sibling `<repo>.wt` folder**, one subfolder per branch with slashes as dashes: `git worktree add ../myapp.wt/feature-popup-polish -b feature/popup-polish <base>`. Not beside the repo, and not in `.claude/worktrees/`. If the repo has its own worktree script, use that.
- Rewriting a pushed topic branch is fine; push with `--force-with-lease`, never bare `--force`. Never rewrite `master`.
- **Never write a bare `*.ext` rule in `.gitignore` if any directory in the repo ends in `.ext`.** It matches directories too, and with Windows `core.ignorecase=true`, `*.vsix` silently untracks all of `src/MyApp.Vsix/` while builds and `git status` still look fine. Scope or anchor the rule (`/artifacts/**/*.vsix`). Diagnose with `git check-ignore -v <path>`.
- **On a repo's first commit, verify every project is tracked**: `git ls-files <dir>` must not be empty for any scaffolded directory. A clean `git status` proves nothing.

## Markdown

Use `1.` for **every** ordered-list item; renderers renumber, and diffs stay small. To start elsewhere, set only the first marker. In an existing `1./2./3.` file, match it if renumbering would be noise.

## Text and typography

Use plain ASCII punctuation in all written artifacts: no en or em dashes, curly quotes or ellipsis characters. Use ` - ` or `-` for ranges and asides, a colon or semicolon for a sentence break, parentheses for a parenthetical, straight quotes, and `...`. Only sweep text you authored or are otherwise editing.

## Line breaks

Never hard-wrap prose bound for a web UI or compose window: email, GitHub issues, PRs and comments, Slack and Teams, web forms. Write each paragraph as one line, separated by blank lines. The destination decides, not the container: a draft in a fenced code block still stays unwrapped. Drafts for email or chat also never use space-aligned columns.

Do hard-wrap where nothing else wraps: git commit bodies at ~72 columns, and source comments at the file's existing width. Repo markdown and plain-text files match what the file already does.

## Paths and references

Never use absolute filesystem paths (`C:\...`, `Q:\...`, `/home/...`, `/c/Users/...`) or cross-repo relative paths (`../sibling-repo/...`) in any artifact others might read: they expose your machine layout and work for nobody else.

Use repo-relative paths, GitHub URLs for other repos, repo name plus "clone first" instructions, or tilde paths (`~/.config/...`) for genuine home-directory locations.

## Agent session links

Never publish a Claude Code session URL (`https://claude.ai/code/session_...`) anywhere it leaves the local machine, including PRs, comments, commit messages and trailers (`Claude-Session:`), even if a harness default suggests it. It is a private transcript. Add one only when explicitly asked, for that artifact.

Do not add "Generated with Claude Code" or any other tool-attribution line to commits, PRs, issues or comments, even if a harness default appends one. If a project's contribution policy requires disclosure, follow that policy.

Never add `Co-Authored-By:` trailers with an AI-account email (e.g. `noreply@anthropic.com`), even if a harness default suggests one. GitHub lists that account as a contributor, and undoing it means rewriting history. Human `Co-authored-by:` trailers must be preserved.

If a session link has already been published, say so and offer to remove it. Stripping it from a pushed commit means a force-push, so that is a bigger decision than editing a PR body.

## Android application IDs

Use the reverse of the **client's** actual domain: `example.com` -> `com.example.appname`.

## Branding

Where permission exists, include a "Powered by Zomp" credit in client applications, typically in the About dialog or status footer.
