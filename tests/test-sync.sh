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
assert_contains "documents resourceId" "$CONTENT" "resourceId"
assert_contains "documents resourceAttributes" "$CONTENT" "resourceAttributes"

echo ""
echo "=== sync SKILL.md tests ==="

SYNC_SKILL="$REPO_ROOT/skills/sync/SKILL.md"

assert_file_exists "sync SKILL.md exists" "$SYNC_SKILL"

FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SYNC_SKILL")
assert_contains "frontmatter has name" "$FRONTMATTER" "name: sync"
assert_contains "frontmatter has description" "$FRONTMATTER" "description:"

CONTENT=$(cat "$SYNC_SKILL")
assert_contains "mentions config.json check" "$CONTENT" "config.json"
assert_contains "mentions qlik app ls" "$CONTENT" "qlik app ls"
assert_contains "mentions qlik app unbuild" "$CONTENT" "qlik app unbuild"
assert_contains "mentions index.json" "$CONTENT" "index.json"
assert_contains "mentions space filtering" "$CONTENT" "space"
assert_contains "mentions resume logic" "$CONTENT" "config.yml"
assert_contains "mentions progress reporting" "$CONTENT" "progress"
assert_contains "mentions lastSync" "$CONTENT" "lastSync"
assert_contains "references cli-commands.md" "$CONTENT" "cli-commands.md"

test_summary
