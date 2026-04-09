#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== plugin.json tests ==="

assert_file_exists "plugin.json exists" "$REPO_ROOT/.claude-plugin/plugin.json"
assert_json_field "plugin name is qlik" "$REPO_ROOT/.claude-plugin/plugin.json" ".name" "qlik"
assert_json_field "plugin version is 0.1.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.1.0"
assert_json_field "plugin license is MIT" "$REPO_ROOT/.claude-plugin/plugin.json" ".license" "MIT"

# Description should mention key capabilities
DESCRIPTION=$(jq -r '.description' "$REPO_ROOT/.claude-plugin/plugin.json")
assert_contains "description mentions Qlik Sense" "$DESCRIPTION" "Qlik Sense"
assert_contains "description mentions load scripts" "$DESCRIPTION" "load scripts"

test_summary
