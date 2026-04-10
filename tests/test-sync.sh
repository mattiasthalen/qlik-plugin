#!/bin/bash
# Tests for sync SKILL.md — validates skill definition and references
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SKILL_FILE="$REPO_ROOT/skills/sync/SKILL.md"
CLI_REF="$REPO_ROOT/skills/sync/references/cli-commands.md"

echo "=== sync references tests ==="
assert_file_exists "cli-commands.md exists" "$CLI_REF"
assert_contains "documents app ls" "$(cat "$CLI_REF")" "app ls"
assert_contains "documents app unbuild" "$(cat "$CLI_REF")" "app unbuild"
assert_contains "documents space ls" "$(cat "$CLI_REF")" "space ls"
assert_contains "documents SaaS-only limitation" "$(cat "$CLI_REF")" "SaaS"
assert_contains "documents pagination" "$(cat "$CLI_REF")" "limit"
assert_contains "documents resourceId" "$(cat "$CLI_REF")" "resourceId"
assert_contains "documents resourceAttributes" "$(cat "$CLI_REF")" "resourceAttributes"

echo ""
echo "=== sync SKILL.md tests ==="
SKILL_CONTENT="$(cat "$SKILL_FILE")"
assert_file_exists "sync SKILL.md exists" "$SKILL_FILE"
assert_contains "frontmatter has name" "$SKILL_CONTENT" "name: sync"
assert_contains "frontmatter has description" "$SKILL_CONTENT" "description:"
assert_contains "mentions config.json check" "$SKILL_CONTENT" "config.json"
assert_contains "mentions sync-cloud-prep.sh" "$SKILL_CONTENT" "sync-cloud-prep.sh"
assert_contains "mentions sync-cloud-app.sh" "$SKILL_CONTENT" "sync-cloud-app.sh"
assert_contains "mentions sync-finalize.sh" "$SKILL_CONTENT" "sync-finalize.sh"
assert_contains "mentions index.json" "$SKILL_CONTENT" "index.json"
assert_contains "mentions space filtering" "$SKILL_CONTENT" "space"
assert_contains "mentions force flag" "$SKILL_CONTENT" "force"
assert_contains "mentions ETA" "$SKILL_CONTENT" "ETA"
assert_contains "mentions progress" "$SKILL_CONTENT" "progress"
assert_contains "references cli-commands.md" "$SKILL_CONTENT" "cli-commands.md"

echo ""
echo "=== parallel sync tests ==="
assert_contains "mentions Agent in allowed-tools" "$SKILL_CONTENT" "Agent"
assert_contains "mentions batch splitting" "$SKILL_CONTENT" "min(nonSkipApps, 5)"
assert_contains "mentions distribution rule" "$SKILL_CONTENT" "floor"
assert_contains "mentions progressive reporting" "$SKILL_CONTENT" "Batch"
assert_contains "mentions zero non-skip handling" "$SKILL_CONTENT" "0 non-skip"
assert_contains "mentions results concatenation" "$SKILL_CONTENT" "concatenate"
assert_contains "mentions agent failure handling" "$SKILL_CONTENT" "agent failed"
assert_contains "mentions cloud app script in agent prompt" "$SKILL_CONTENT" "sync-cloud-app.sh"
assert_contains "mentions onprem app script in agent prompt" "$SKILL_CONTENT" "sync-onprem-app.sh"

test_summary
