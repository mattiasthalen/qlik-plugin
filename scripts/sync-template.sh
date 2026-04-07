#!/bin/bash
set -e

REPO="https://github.com/mattiasthalen/primer"
REMOTE="template-upstream"

# Add template as a remote if not already there
if ! git remote get-url "$REMOTE" &>/dev/null; then
    git remote add "$REMOTE" "$REPO"
fi

git fetch "$REMOTE" main

# Merge with --allow-unrelated-histories for first sync
git merge "$REMOTE/main" --allow-unrelated-histories --no-commit || true

echo ""
echo "Review merge with: git diff --cached"
echo "Resolve any conflicts, then commit."
