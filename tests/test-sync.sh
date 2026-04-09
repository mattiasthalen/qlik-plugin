#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== sync references tests ==="

CLI_REF="$REPO_ROOT/skills/sync/references/cli-commands.md"
assert_file_exists "cli-commands.md exists" "$CLI_REF"

CONTENT=$(cat "$CLI_REF")
assert_contains "documents app ls" "$CONTENT" "qlik app ls"
assert_contains "documents app unbuild" "$CONTENT" "qlik app unbuild"
assert_contains "documents space ls" "$CONTENT" "qlik space ls"
assert_contains "documents SaaS-only limitation" "$CONTENT" "SaaS"
assert_contains "documents pagination" "$CONTENT" "limit"

test_summary
