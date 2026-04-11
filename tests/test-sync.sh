#!/bin/bash
# Tests for sync SKILL.md — validates skill definition and references
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SKILL_FILE="$REPO_ROOT/skills/sync/SKILL.md"

echo "=== sync SKILL.md tests ==="
SKILL_CONTENT="$(cat "$SKILL_FILE")"
assert_file_exists "sync SKILL.md exists" "$SKILL_FILE"
assert_contains "frontmatter has name" "$SKILL_CONTENT" "name: sync"
assert_contains "frontmatter has description" "$SKILL_CONTENT" "description:"

# qs CLI integration
assert_contains "mentions qs sync command" "$SKILL_CONTENT" "qs sync"
assert_contains "mentions space filter" "$SKILL_CONTENT" "\-\-space"
assert_contains "mentions app filter" "$SKILL_CONTENT" "\-\-app"
assert_contains "mentions id filter" "$SKILL_CONTENT" "\-\-id"
assert_contains "mentions tenant filter" "$SKILL_CONTENT" "\-\-tenant"
assert_contains "mentions force flag" "$SKILL_CONTENT" "\-\-force"

# Exit code handling
assert_contains "mentions exit code 0" "$SKILL_CONTENT" "exit.*0\|Exit code 0\|exit 0"
assert_contains "mentions exit code 2 partial" "$SKILL_CONTENT" "exit.*2\|Exit code 2\|partial"

# Output directory
assert_contains "mentions qlik/ directory" "$SKILL_CONTENT" "qlik/"
assert_contains "mentions config.json" "$SKILL_CONTENT" "config.json"
assert_contains "mentions index.json" "$SKILL_CONTENT" "index.json"

# Should NOT contain old bash script references
SKILL_CONTENT_NEGATIVE="$SKILL_CONTENT"
if echo "$SKILL_CONTENT_NEGATIVE" | grep -q "sync-cloud-prep.sh"; then
  echo "  FAIL: should not mention sync-cloud-prep.sh"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention sync-cloud-prep.sh"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$SKILL_CONTENT_NEGATIVE" | grep -q "Agent"; then
  echo "  FAIL: should not mention Agent tool"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention Agent tool"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Verify scripts directory removed
if [ -d "$REPO_ROOT/skills/sync/scripts" ]; then
  echo "  FAIL: skills/sync/scripts/ directory should not exist"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: skills/sync/scripts/ directory removed"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

test_summary
