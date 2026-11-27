---
name: zomp-github
description: Zomp conventions for writing on GitHub - PR descriptions, issue bodies, PR, issue and review comments, and merging PRs. Covers length, closing keywords, re-reading the thread and testing claims before posting, reproducing on the latest version, searching existing issues and PRs, and cutting a patch to what the fix needs before reporting upstream, cross-repo references and squash-merge. Load this before writing or posting any GitHub PR, issue, comment or review, and before merging a PR.
---

# Zomp GitHub conventions

These extend the global conventions in `AGENTS.md`, which stay in force: no hard-wrapping in web UIs (Line breaks), and no session links, AI `Co-Authored-By:` trailers or tool-attribution lines (Agent session links).

## Before posting

Re-read the whole thread right before drafting a comment, and again right before posting it: issue comments, reviews and inline review comments, all of them rather than the last few (`gh api repos/<owner>/<repo>/issues/<n>/comments?per_page=100`, plus `pulls/<n>/reviews` and `pulls/<n>/comments` on a PR). A read from earlier in the session is stale. Posting past a reply you have not seen answers a question nobody is asking now and ignores the one they are.

If a comment claims something works or would work, and an experiment within reach can check it (a build, a test run, a repro), run it first and post the result. If it is too expensive, say the claim is untested. A prediction posted as fact gets tested by the reviewer instead, and costs credibility when it fails.

## Reporting upstream

Before filing a bug, a feature request or a PR against someone else's project, do these yourself, without asking the user first:

1. **Reproduce it on the latest release**, and on the default branch too when building it is practical. Maintainers waste time on reports against versions where the problem may already be fixed. If upgrading would disturb the user's setup, install the newer version alongside (a separate toolchain or virtualenv, a scratch directory) rather than skipping the check. State the exact versions tested in the report.
1. **Search existing issues and PRs, open and closed**, in that repo and in the closely related ones (the library a tool wraps, the fork it builds on), with several phrasings: the error text, the function or option name, the symptom. Comment on or link a match instead of opening a duplicate, and mention near misses that turned out unrelated only if a reader would otherwise wonder.
1. **Before proposing a patch, cut it to what the fix needs.** Run unmodified upstream with only the trigger removed, then drop each part of the patch in turn and retest. A change that works can carry parts that do nothing, and the real cause can lie outside the patch: a "missing feature" can turn out to be a latency problem in the caller.
1. **Read the project's own contributor and agent rules** (`AGENTS.md`, `CONTRIBUTING.md`, the PR template) before writing anything. Some forbid agents from opening issues, or require a line disclosing AI help; where a project requires disclosure, its rule overrides the no-attribution rule above.

Only ask the user when one of the first two is impossible (no access to the latest version, a download or install they must approve), and say which.

## Length

Keep PR descriptions, PR and review comments, and issue bodies as short as possible: what changed or what is broken, one line of cause, one line of fix. Leave out thanks and sign-offs, restatements of the diff, background the reader can get from the linked code, and offers to change things.

Why: every sentence is something the reader has to process, and padded text reads as machine-generated. Draft, then cut until removing anything more would lose a fact the reader needs. A code snippet plus two sentences usually beats prose; use a table only when it replaces more text than it adds.

## Links

When a PR fully resolves an issue, link it with a closing keyword (`Fixes #123`) so the issue closes on merge; use whichever keyword the repo's merged PRs already use. For partial work write `Part of #123`, without a keyword. Words like "Addresses" or "Relates to" create no link, so the issue stays open after merge and has to be closed by hand. Keywords only take effect when the PR targets the default branch.

In a comment on one repo, refer to another repo's issue or PR as `owner/repo#123`. A bare `#123` always links to the current repo, so it silently points at the wrong thread.

## Merging

Squash-merge PRs (`gh pr merge --squash`) unless the PR is a single commit or the user explicitly asks for a different merge strategy. Topic-branch fix-up commits ("address review", "fix typo") are noise on the default branch; one commit per PR keeps history linear and revertable. A single-commit PR can merge as-is since there is nothing to squash.
