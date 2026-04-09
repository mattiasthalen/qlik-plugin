#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== project config tests ==="

# .gitignore includes .qlik-sync/
GITIGNORE=$(cat "$REPO_ROOT/.gitignore")
assert_contains ".gitignore has .qlik-sync/" "$GITIGNORE" ".qlik-sync/"

# justfile has test recipe
JUSTFILE=$(cat "$REPO_ROOT/justfile")
assert_contains "justfile has test recipe" "$JUSTFILE" "test"

# devcontainer setup script has qlik-cli install
SETUP=$(cat "$REPO_ROOT/scripts/setup-devcontainer.sh")
assert_contains "devcontainer installs qlik-cli" "$SETUP" "qlik"
assert_contains "devcontainer installs jq or jq already available" "$SETUP" "jq"

test_summary
