#!/bin/sh
# Block private content from reaching this public repository.
#
# This repo is public, but it gets edited while working inside private client
# repos - which is exactly how a client name or a machine path ends up in a
# commit. Runs from the pre-commit hook over staged files, and from CI with
# --all over every tracked file.
#
# Usage: check-private-content.sh [--all]
#
# Patterns come from two places:
#   1. The generic list below, shipped with the repo.
#   2. An optional private word list, NEVER committed:
#        ~/.config/zomp/private-words.txt   (override with ZOMP_PRIVATE_WORDS)
#      One extended regex per line; # starts a comment. Client names belong
#      there, not here: a public denylist of client names would itself disclose
#      who the clients are.
#
# Deliberate counter-examples go in .private-content-allow, one regex per line.

set -eu

mode="${1:-}"

if [ "$mode" = "--all" ]; then
  files=$(git ls-files)
else
  files=$(git diff --cached --name-only --diff-filter=ACM)
fi

[ -n "$files" ] || exit 0

allow_file=".private-content-allow"
words_file="${ZOMP_PRIVATE_WORDS:-$HOME/.config/zomp/private-words.txt}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Absolute paths, IPv4 addresses, session links, AI co-author addresses.
cat > "$tmp/patterns" <<'PATTERNS'
[A-Za-z]:\\
[A-Za-z]:/Users/
(^|[[:space:]"'`(=])/home/[A-Za-z0-9._-]+
(^|[[:space:]"'`(=])/c/Users/
(^|[[:space:]"'`(=])/Users/[A-Za-z0-9._-]+
([0-9]{1,3}\.){3}[0-9]{1,3}
claude\.ai/code/session
noreply@anthropic\.com
PATTERNS

if [ -f "$words_file" ]; then
  grep -vE '^[[:space:]]*(#|$)' "$words_file" >> "$tmp/patterns" || true
fi

: > "$tmp/allow"
if [ -f "$allow_file" ]; then
  grep -vE '^[[:space:]]*(#|$)' "$allow_file" > "$tmp/allow" || true
fi

: > "$tmp/report"

printf '%s\n' "$files" | while IFS= read -r file; do
  [ -n "$file" ] && [ -f "$file" ] || continue

  # The scanner, the hooks that call it, and the allow list all contain the
  # patterns by necessity.
  case "$file" in
    scripts/check-private-content.sh | .githooks/* | "$allow_file") continue ;;
  esac

  hits=$(grep -nIEi -f "$tmp/patterns" "$file" 2>/dev/null || true)
  [ -n "$hits" ] || continue

  if [ -s "$tmp/allow" ]; then
    hits=$(printf '%s\n' "$hits" | grep -vEi -f "$tmp/allow" || true)
  fi
  [ -n "$hits" ] || continue

  printf '%s\n' "$hits" | sed "s|^|  $file:|" >> "$tmp/report"
done

if [ -s "$tmp/report" ]; then
  echo "Private content check FAILED. This repository is public." >&2
  echo "" >&2
  cat "$tmp/report" >&2
  echo "" >&2
  echo "Replace client names, machine paths and hostnames with placeholders." >&2
  echo "A deliberate example belongs in $allow_file." >&2
  exit 1
fi
