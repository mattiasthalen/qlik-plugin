#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== inspect SKILL.md tests ==="

INSPECT_SKILL="$REPO_ROOT/skills/inspect/SKILL.md"

assert_file_exists "inspect SKILL.md exists" "$INSPECT_SKILL"

FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$INSPECT_SKILL")
assert_contains "frontmatter has name" "$FRONTMATTER" "name: inspect"
assert_contains "frontmatter has description" "$FRONTMATTER" "description:"

CONTENT=$(cat "$INSPECT_SKILL")
assert_contains "mentions index.json" "$CONTENT" "index.json"
assert_contains "mentions measures.json" "$CONTENT" "measures.json"
assert_contains "mentions dimensions.json" "$CONTENT" "dimensions.json"
assert_contains "mentions script.qvs" "$CONTENT" "script.qvs"
assert_contains "mentions connections" "$CONTENT" "connections"
assert_contains "mentions grep or search" "$CONTENT" "grep\|Grep\|search"
assert_contains "mentions compare or diff" "$CONTENT" "compare\|diff"
assert_contains "mentions space filter" "$CONTENT" "space"
assert_contains "uses index path field" "$CONTENT" "path"
assert_contains "teaches offline usage" "$CONTENT" "no API\|offline\|local"

# Directory references should use qlik/ not .qlik-sync/
assert_contains "uses qlik/ directory" "$CONTENT" "qlik/"

if echo "$CONTENT" | grep -q '\.qlik-sync'; then
  echo "  FAIL: should not mention .qlik-sync"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention .qlik-sync"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

test_summary
