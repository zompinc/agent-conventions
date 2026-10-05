#!/bin/sh
# Pull the latest conventions and relink them. Safe to run from a Claude
# SessionStart hook or a scheduler: it never touches local work and never
# blocks on anything interactive.
#
# It gives up quietly when:
#   - the working tree is dirty          (you are editing the conventions)
#   - the branch is ahead of its remote  (you have unpushed commits)
#   - the branch is not master
#   - it ran recently                    (default 6 hours; ZOMP_UPDATE_MAX_AGE_HOURS)
#   - the network is unavailable
#
# Force a check with --now. Log: .git/zomp-update.log, which can never be
# committed because .git is not part of the work tree.

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

[ -d .git ] || exit 0

log_file="$repo_root/.git/zomp-update.log"
stamp_file="$repo_root/.git/zomp-update.stamp"
max_age_hours="${ZOMP_UPDATE_MAX_AGE_HOURS:-6}"

log() {
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$log_file"
}

if [ "${1:-}" != "--now" ] && [ -f "$stamp_file" ]; then
  last=$(cat "$stamp_file" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now - last)) -lt $((max_age_hours * 3600)) ]; then
    exit 0
  fi
fi

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$branch" != "master" ]; then
  log "skipped: on branch $branch"
  exit 0
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  log "skipped: working tree has local changes"
  exit 0
fi

if ! git fetch --quiet origin master 2>/dev/null; then
  log "skipped: fetch failed (offline?)"
  exit 0
fi

# Record the attempt even when nothing changes, so an unreachable remote does
# not cause a fetch on every session.
date +%s > "$stamp_file"

ahead=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo 0)
if [ "$ahead" != "0" ]; then
  log "skipped: $ahead local commit(s) not pushed"
  exit 0
fi

behind=$(git rev-list --count HEAD..origin/master 2>/dev/null || echo 0)
if [ "$behind" = "0" ]; then
  exit 0
fi

if git merge --ff-only --quiet origin/master 2>/dev/null; then
  log "updated: fast-forwarded $behind commit(s)"
  # Relink, so a new file or skill added upstream exists on this machine.
  if [ -x "$repo_root/bootstrap.sh" ] || [ -f "$repo_root/bootstrap.sh" ]; then
    ZOMP_NO_SCHEDULE=1 sh "$repo_root/bootstrap.sh" >> "$log_file" 2>&1 || log "bootstrap failed"
  fi
else
  log "skipped: cannot fast-forward"
fi
