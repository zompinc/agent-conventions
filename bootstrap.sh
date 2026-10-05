#!/usr/bin/env bash
# Bootstrap Zomp agent-conventions on macOS / Linux.
#
# Symlinks ~/AGENTS.md to this repo's home/AGENTS.md so all AI coding agents
# (Claude Code, Codex, Cursor, Aider) pick it up via directory walk-up, and
# symlinks each skill under skills/ into ~/.claude/skills/ so stack- and
# activity-specific conventions load on demand instead of costing context in
# every session.
#
# Also enables this repo's own git hooks, which keep client names and machine
# paths out of a public repository.
#
# Everything of value stays in the repo; this machine holds only links.
#
# Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$REPO_ROOT/home/AGENTS.md"
TARGET="$HOME/AGENTS.md"

if [ ! -f "$SOURCE" ]; then
  echo "Source not found: $SOURCE" >&2
  exit 1
fi

# If target is already a symlink to the right place, no-op.
if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
  echo "Already linked: $TARGET -> $SOURCE"
else
  # Replace whatever's there with a symlink. -f overwrites file/link/dir.
  ln -sfn "$SOURCE" "$TARGET"
  echo "Linked: $TARGET -> $SOURCE"
fi

# Link each skill directory individually rather than the skills/ folder itself,
# so skills from other sources in ~/.claude/skills are left alone.
SKILLS_SOURCE="$REPO_ROOT/skills"
SKILLS_TARGET="$HOME/.claude/skills"

if [ -d "$SKILLS_SOURCE" ]; then
  mkdir -p "$SKILLS_TARGET"
  for skill in "$SKILLS_SOURCE"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    link="$SKILLS_TARGET/$name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "${skill%/}" ]; then
      echo "Already linked: $link"
    else
      ln -sfn "${skill%/}" "$link"
      echo "Linked: $link -> ${skill%/}"
    fi
  done
fi

# Hooks live in the repo so a clone gets them; git needs telling where.
if [ -d "$REPO_ROOT/.githooks" ]; then
  git -C "$REPO_ROOT" config core.hooksPath .githooks
  chmod +x "$REPO_ROOT"/.githooks/* 2>/dev/null || true
  echo "Hooks enabled: core.hooksPath=.githooks"
fi

echo "Conventions update with: cd $REPO_ROOT && git pull"
