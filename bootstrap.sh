#!/usr/bin/env bash
# Bootstrap Zomp agent-conventions on macOS / Linux.
#
# Everything under home/ mirrors your home directory: home/AGENTS.md becomes
# ~/AGENTS.md, home/.claude/skills/<name>/ becomes ~/.claude/skills/<name>/,
# and anything added there later lands in the matching place with no change to
# this script.
#
# Files are linked individually rather than whole directories, so linking
# ~/.claude/skills never replaces a directory holding skills from other
# sources. New files appear on the next bootstrap run, which the updater does
# after every pull.
#
# Also enables this repo's git hooks and installs a daily update job.
#
# Everything of value stays in the repo; this machine holds only links.
#
# Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SOURCE="$REPO_ROOT/home"

if [ ! -d "$HOME_SOURCE" ]; then
  echo "Source not found: $HOME_SOURCE" >&2
  exit 1
fi

# Drop links that point into this repo but no longer resolve - a file renamed
# or moved upstream leaves one behind. This runs before linking, because a
# dangling directory link would break creating files beneath it.
prune() {
  [ -d "$1" ] || return 0
  find "$1" -maxdepth "${2:-99}" -type l 2>/dev/null | while IFS= read -r link; do
    case "$(readlink "$link")" in
      "$REPO_ROOT"/*)
        [ -e "$link" ] || { rm -f "$link"; echo "Removed stale link: $link"; }
        ;;
    esac
  done
}

prune "$HOME/.claude/skills"
prune "$HOME" 1

linked=0
kept=0

while IFS= read -r src; do
  rel="${src#"$HOME_SOURCE"/}"
  dest="$HOME/$rel"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    kept=$((kept + 1))
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "Linked: $dest"
  linked=$((linked + 1))
done <<EOF
$(find "$HOME_SOURCE" -type f)
EOF

echo "Links: $linked new, $kept already correct."

# Hooks live in the repo so a clone gets them; git needs telling where.
if [ -d "$REPO_ROOT/.githooks" ]; then
  git -C "$REPO_ROOT" config core.hooksPath .githooks
  chmod +x "$REPO_ROOT"/.githooks/* "$REPO_ROOT"/scripts/*.sh 2>/dev/null || true
  echo "Hooks enabled: core.hooksPath=.githooks"
fi

# Global gitignore. Git reads only one excludes file, so never replace one
# already in use - its patterns would silently stop applying.
current=$(git config --global core.excludesfile 2>/dev/null || true)
xdg_ignore="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
if [ -z "$current" ] && [ ! -f "$xdg_ignore" ]; then
  git config --global core.excludesfile '~/.gitignore'
  echo "Configured: core.excludesfile=~/.gitignore"
elif [ "$current" != '~/.gitignore' ] && [ "$current" != "$HOME/.gitignore" ]; then
  echo "Skipped core.excludesfile: already using ${current:-$xdg_ignore}. Merge ~/.gitignore into it by hand."
fi

# Daily update, for machines where a Claude session may not start for a while.
# Skipped where cron is unavailable; set ZOMP_NO_SCHEDULE=1 to opt out.
if [ "${ZOMP_NO_SCHEDULE:-0}" != "1" ] && command -v crontab >/dev/null 2>&1; then
  if crontab -l 2>/dev/null | grep -Fq "update-conventions.sh"; then
    echo "Update job already scheduled."
  else
    {
      crontab -l 2>/dev/null || true
      echo "0 9 * * * $REPO_ROOT/scripts/update-conventions.sh >/dev/null 2>&1"
    } | crontab -
    echo "Scheduled: daily update at 09:00."
  fi
fi

echo "Conventions update with: cd $REPO_ROOT && git pull"
