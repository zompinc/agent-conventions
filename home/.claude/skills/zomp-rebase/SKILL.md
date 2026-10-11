---
name: zomp-rebase
description: Rebasing without losing work - finding and moving every branch stacked on the one being rebased (the whole tree, not just one branch), why `--update-refs` skips branches checked out in worktrees, resolving conflicts from both sides' intent, and checking the result before force-pushing. Load this before any rebase, `rebase --onto` or cherry-pick that rewrites a branch, and before resolving a rebase or cherry-pick conflict.
---

# Rebasing

These extend `AGENTS.md`, which stays in force: history is linear, never merge, push rewritten branches with `--force-with-lease`.

## Move the whole tree

A branch is rarely alone. Other branches may be built on it, directly or on an older version of it. Rebasing only the branch you were asked about leaves those on the old commits: they still carry the pre-rebase copies, and the next rebase of each one replays duplicates or conflicts with itself. Treat the branch and everything built on it as one tree and move all of it.

1. **List the tree before touching anything.** Any branch that contains the oldest commit unique to `<branch>` is built on some version of it:

   ```sh
   oldest=$(git rev-list --reverse <upstream>..<branch> | head -1)
   git branch -a --contains "$oldest"
   ```

   Run it again for each branch it finds, until no new ones appear.
1. **Record every old tip**, so each child can be moved with `--onto` and so the result can be compared later:

   ```sh
   for b in <branch> <child> ...; do echo "$b $(git rev-parse "$b")"; done > "$(git rev-parse --git-dir)/rebase-tips.txt"
   ```

1. **Turn on rerere** (`git config rerere.enabled true`) before rebasing a tree. The same conflict often comes back in each child, and rerere replays the resolution recorded the first time.
1. **Rebase top-down.** First the root onto its new base, then each child onto its new parent:

   ```sh
   git rebase --onto <new-parent> <old-parent-tip> <child>
   ```

   `<old-parent-tip>` comes from the recorded tips. Never take it from the parent branch after the parent has been rebased.

`git rebase --update-refs` does all of this in one go for a linear stack, but **it skips every branch checked out in another worktree**, without an error. In a repo with one worktree per branch, that is all of them. Either rebase each branch in its own worktree with `--onto` as above, or confirm with `git worktree list` that nothing in the stack is checked out elsewhere before relying on `--update-refs`.

A branch that exists only on a remote, or that someone else is working on, is not yours to rewrite. List it and tell the user; don't rebase it.

## Resolve conflicts from both intents

A conflict is two changes to the same lines. Before editing, look at what each side meant to do:

- **The commit being replayed:** `git show REBASE_HEAD -- <file>` (`CHERRY_PICK_HEAD` during a cherry-pick).
- **What the target did since the two diverged:** `git diff $(git merge-base REBASE_HEAD HEAD) HEAD -- <file>`. If the file was renamed on either side, find its old path with `git log --follow --name-status -- <file>` and diff that.

Then write a version that does both. Taking one side wholesale (`git checkout --ours/--theirs`) is only right when the other side's change is already contained in it. During a rebase, "ours" is the branch being built on and "theirs" is your commit - the reverse of a merge.

After resolving, build and run the tests before `git rebase --continue`, or add `--exec "<build-and-test>"` to the rebase so every replayed commit is checked.

## Check before pushing

- `git range-diff <old-tip>...<new-tip>` for each branch. Only the conflict resolutions should differ; anything else means a resolution changed more than it should.
- `git log --graph --oneline <upstream>..<leaf>` shows the tree has the same shape as before.
- Push every branch that moved, each with `--force-with-lease`, and say which ones moved.
