#!/usr/bin/env bash
set -euo pipefail

# A safe helper to sync local main with origin/main and push.
# It performs:
# - repo checks
# - optional stash of uncommitted changes
# - fetch
# - rebase onto origin/main
# - push
#
# Read before use. Use at your own risk. Tested for simple flows.

# Ensure we are inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not inside a git repository." >&2
  exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "main" ]]; then
  echo "Warning: You are on branch '$current_branch', not 'main'." >&2
  read -p "Continue on this branch? [y/N]: " ans
  if [[ ! ${ans:-N} =~ ^[Yy]$ ]]; then
    echo "Aborting." >&2
    exit 1
  fi
fi

# Check remote
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Error: No 'origin' remote configured." >&2
  exit 1
fi

# Show status and optionally stash
echo "== Git status before sync =="
git status --short --branch

if [[ -n "$(git status --porcelain)" ]]; then
  echo "You have uncommitted changes."
  read -p "Stash changes before rebasing? [Y/n]: " ans
  if [[ ${ans:-Y} =~ ^[Yy]$ ]]; then
    git stash push -u -m "git_sync.sh auto-stash $(date +%Y%m%d-%H%M%S)"
    stashed=1
  else
    stashed=0
  fi
else
  stashed=0
fi

# Fetch and rebase
echo "Fetching from origin..."
git fetch origin

echo "Rebasing $current_branch onto origin/$current_branch ..."
if ! git rebase "origin/$current_branch"; then
  echo "Rebase encountered conflicts. Resolve them, then run:"
  echo "  git add <fixed-files> && git rebase --continue"
  echo "After successful rebase, re-run this script to push."
  exit 1
fi

# Re-apply stash if any
if [[ ${stashed} -eq 1 ]]; then
  echo "Re-applying stashed changes..."
  if ! git stash pop; then
    echo "Conflicts occurred while applying stash. Resolve them, commit, then push manually." >&2
    exit 1
  fi
fi

# Push
echo "Pushing to origin/$current_branch ..."
git push -u origin "$current_branch"

echo "Done. Your branch is up to date with origin/$current_branch."