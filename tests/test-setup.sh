#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== plugin.json tests ==="

assert_file_exists "plugin.json exists" "$REPO_ROOT/.claude-plugin/plugin.json"
assert_json_field "plugin name is qlik" "$REPO_ROOT/.claude-plugin/plugin.json" ".name" "qlik"
assert_json_field "plugin version is 0.5.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.5.0"
assert_json_field "plugin license is MIT" "$REPO_ROOT/.claude-plugin/plugin.json" ".license" "MIT"

# Description should mention key capabilities
DESCRIPTION=$(jq -r '.description' "$REPO_ROOT/.claude-plugin/plugin.json")
assert_contains "description mentions Qlik Sense" "$DESCRIPTION" "Qlik Sense"
assert_contains "description mentions load scripts" "$DESCRIPTION" "load scripts"

echo ""
echo "=== setup SKILL.md tests ==="

SETUP_SKILL="$REPO_ROOT/skills/setup/SKILL.md"

assert_file_exists "setup SKILL.md exists" "$SETUP_SKILL"

# Frontmatter checks
FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SETUP_SKILL")
assert_contains "frontmatter has name" "$FRONTMATTER" "name: setup"
assert_contains "frontmatter has description" "$FRONTMATTER" "description:"

# Content checks — skill delegates to qs setup and keeps only prereqs + .gitignore + hand-off
CONTENT=$(cat "$SETUP_SKILL")
assert_contains "probes local qs.exe" "$CONTENT" "./qs.exe"
assert_contains "probes local qs" "$CONTENT" "./qs"
assert_contains "falls back to PATH" "$CONTENT" "command -v qs"
assert_contains "prepends PWD to PATH" "$CONTENT" 'PATH="$PWD:$PATH"'
assert_contains "delegates to qs setup" "$CONTENT" "qs setup"
assert_contains "mentions qlik directory" "$CONTENT" "qlik/"
assert_contains "mentions config.json" "$CONTENT" "config.json"
assert_contains "mentions .gitignore" "$CONTENT" ".gitignore"
assert_contains "mentions auto-resume to sync" "$CONTENT" "sync"

# Negative assertions — old manual flow must be gone
if echo "$CONTENT" | grep -q "qlik context create"; then
  echo "  FAIL: should not drive qlik context create manually"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not drive qlik context create manually"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$CONTENT" | grep -q "qlik context login"; then
  echo "  FAIL: should not mention qlik context login"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention qlik context login"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$CONTENT" | grep -q "qlik app ls"; then
  echo "  FAIL: should not run qlik app ls directly"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not run qlik app ls directly"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

test_summary
