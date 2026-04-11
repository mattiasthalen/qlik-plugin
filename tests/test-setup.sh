#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== plugin.json tests ==="

assert_file_exists "plugin.json exists" "$REPO_ROOT/.claude-plugin/plugin.json"
assert_json_field "plugin name is qlik" "$REPO_ROOT/.claude-plugin/plugin.json" ".name" "qlik"
assert_json_field "plugin version is 0.4.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.4.0"
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

# Content checks — skill should teach these key behaviors
CONTENT=$(cat "$SETUP_SKILL")
assert_contains "mentions qlik prerequisite" "$CONTENT" "which qlik"
assert_contains "mentions qs prerequisite" "$CONTENT" "which qs"
assert_contains "mentions context create" "$CONTENT" "qlik context create"
assert_contains "mentions context login" "$CONTENT" "qlik context login"
assert_contains "mentions connectivity test" "$CONTENT" "qlik app ls"
assert_contains "mentions qlik directory" "$CONTENT" "qlik/"
assert_contains "mentions config.json" "$CONTENT" "config.json"
assert_contains "mentions .gitignore" "$CONTENT" ".gitignore"

# Multi-tenant config check (cloud-only)
assert_contains "mentions multi-tenant config" "$CONTENT" "tenants"

# v0.1.0 migration must set type field
assert_contains "migration sets type cloud" "$CONTENT" 'type.*cloud'

# v0.2.0 append must not modify existing tenants
assert_contains "append preserves existing tenants" "$CONTENT" "do not modify existing tenants"

test_summary
