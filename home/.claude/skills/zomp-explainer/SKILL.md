---
name: zomp-explainer
description: How to write and maintain a local reading guide (an explainer) that lets the owner of a repository understand work done on their behalf without reading every line - a PR, a branch, a feature, a subsystem or an unfamiliar codebase - covering what it does, how the pieces fit, why each design decision was made, where a reviewer will push back, and how to verify it. Load this whenever the user asks to understand or explain a change, branch or codebase, wants a guide, walkthrough, tour, overview or write-up of code, asks "how does X work" about work done across several sessions, asks where the explainer is, or when a change has grown past what fits in one head (several hundred lines across several files), even if they never say "guide". Also load it before updating an existing explainer after a rebase, a review round or a design change.
---

# Zomp explainers

An explainer is a private Markdown file that lets the person who commissioned a piece of work understand it well enough to defend it: in a code review, in an issue thread, in a design discussion, or to themselves six weeks later. It is not documentation for users and not a PR description; both of those are derived from it later.

The global conventions in `AGENTS.md` stay in force: ASCII punctuation, `1.` on every ordered-list item, no absolute paths in anything that could leave the machine.

## Who reads it

The owner of the repository or the branch: competent in the domain, directing the work, but not the author of every line and often not familiar with the internals of the framework the change touches. Write for that reader:

- Explain why, not what. They can read code; what they cannot read is the reasoning that led to it, the alternatives that were rejected, and the places where the design is fragile.
- Define the internals. Every framework type, pipeline stage or protocol term the change relies on gets a one-line glossary entry. The reader should never have to open a framework source file to follow the guide.
- Assume they did not watch the session. Nothing that happened in chat exists for them unless the guide says it.
- Be honest about weaknesses. The file is private, so there is no audience to impress. A weakness the guide hides is one the reader will discover from a reviewer instead.

## Where it lives

Put it in the repository it describes, under `docs-local/`, named after the topic (`docs-local/query-batching-pr-guide.md`). Keep it untracked and exclude the folder through `.git/info/exclude` (add a `/docs-local/` line), never through `.gitignore`: an ignore rule would be a change in the PR. State this in the header so a later session does not commit it by accident.

Add the path to the project memory so "where is the explainer again?" has an answer in a later session.

The header carries everything a reader needs to judge staleness: repository, branch, PR and issue links, number of commits, the base commit it was last rebased onto, the date, and the size of the change (`git diff --stat <base>..HEAD` summary). A guide whose header says 8 commits on top of a base from three weeks ago tells the reader exactly how much to trust it.

## Structure

Use this order. Each section exists for a reason; drop one only when it has nothing to say for this change.

1. **The one-paragraph version.** What the change does, in terms of what goes in and what comes out, with the one sentence that says what it does *not* reimplement. The reader should be able to describe the change to a colleague after this paragraph alone.
1. **The user-facing surface.** The API, CLI, config or protocol the change adds or alters, as real code examples lifted from tests or samples, plus a table of the public surface. Public before internal, always: the reader thinks from the outside in.
1. **Suggested reading order.** For a branch, by commit: one line per commit saying what layer it adds and any gotcha ("read commit 6 right after commit 1, it rewrites part of it"). For an unfamiliar codebase, by entry point: where execution starts and which files to open in which order. List every commit, including the mechanical ones, so the reader knows which they can skip.
1. **File map.** Each file touched, grouped by role (public API, executor, storage, provider, tests), one line each. This is the section the reader comes back to while reading the diff.
1. **Lifecycle of one operation.** Follow a single representative call from the public entry point to its result, step by step, naming the method at each step. This is where the pieces become a mechanism instead of a list. One lifecycle is enough; cover variants in the design section.
1. **Design decisions and the reasoning behind each.** The heart of the guide. For every decision a reviewer might question: the problem; the first attempt and why it failed, if there was one; the final design; the questions a reviewer is likely to ask, each with its answer; and the alternatives to keep in your pocket if the design is rejected. Flag the one decision most likely to draw pushback and say so.
1. **Limitations and what each produces.** What the change refuses to do and the exact error or behaviour the user sees for each, so the reader can answer "does it handle X?" without running anything.
1. **Tests.** What the test suite covers, where it runs, how to run one class or one case with the repo's actual command syntax, and anything about the test infrastructure that bit during the work (a test that only fails on CI, a runtime that must be installed by hand).
1. **Open items.** What must happen before the work is done: decisions pending, questions for maintainers, follow-ups deliberately left out. Keep this list current; it is the reader's to-do list.
1. **Glossary.** The internals from the "who reads it" rule above.

For an unfamiliar codebase rather than own work, the same skeleton applies with two renamings: "reading order" is by entry point rather than commit, and "design decisions" becomes "conventions and why they exist".

## Sizing

Scale the guide to the change, not to the template. A 3000-line change across 25 files earns 250 to 300 lines of guide. A 200-line fix earns 30 to 60 lines: the one-paragraph version, the lifecycle, the decisions and the open items, with the rest folded into them. A guide longer than the diff it explains has stopped being a guide.

Give the reader both depths through order rather than by asking which they want: the first three sections are the overview, the rest is the deep dive, and the file makes sense if they stop after any section.

## Grounding

Write every statement from the code as it is now, not from memory of writing it. Re-read a file before describing it, even one written an hour ago; the review fix or the rebase may have changed it. A guide that describes the first attempt as if it were the final design is worse than no guide, because the reader will repeat it to a reviewer.

Anchor claims with the file name and member name (`RelationalCommandCache.GetRelationalCommandTemplate`), not with line numbers. Line numbers rot at the first rebase and the reader has no way to tell. When a line reference genuinely helps, give it in addition to the name, and re-check all of them when updating the guide.

Captured output (SQL, logs, command output, error messages) comes from a real run, never from what the code "should" produce, and the guide says when and against what it was captured. The same rule applies to any snippet the reader might paste into a PR or issue.

Where the work turned up a fact about the toolchain that cost time (a test that silently rewrites a baseline locally and only fails on CI, a runtime that the restore script does not install), record it in the Tests section. Those are exactly the facts the reader would otherwise rediscover the hard way.

## Keeping it current

The guide is a living file for as long as the work is open:

- After new commits or a rebase, update the header (commit count, base, date), the reading order and the file map in the same turn as the git operation, before reporting the result.
- After a review round or a design change, rewrite the affected decision section rather than appending a "changed in commit 7" note. The reader wants the current design with its history, not a changelog.
- When the user asks "explain X" and X is covered, answer in chat and point to the section by heading. When X is not covered, answer and add the section, because the next question about X will come in a session that has no memory of this one.
- Keep "Open items" true. Remove what is done, add what the discussion raised.

Derive outward-facing text from the guide rather than the other way round: PR description, issue comments, docs articles and review replies are each a selection and a compression of what the guide already says. Writing them first and the guide second produces a guide that reads like marketing.

## Style

- Match repo Markdown conventions. The file is read in an editor, so use real headings, numbered sections, tables for surfaces and file maps, and fenced code for anything a reader might copy.
- Prose paragraphs are one line each unless the repo hard-wraps its Markdown.
- Name things by their real identifiers in backticks. Never invent a name for a component in the guide that does not exist in the code; if the code lacks a name for a concept, say so and describe it.
- No session links, no tool attribution. The file is private, but it will be copied from.
