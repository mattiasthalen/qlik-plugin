#!/bin/bash
# Tests for sync-tenant.sh script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SYNC_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-tenant.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

# Create temp dir and clean up on exit
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "context": "test-ctx",
  "server": "https://test-tenant.us.qlikcloud.com"
}
JSON
  echo "$workdir"
}

run_sync() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" "$@" 2>&1)
}

echo "=== sync-tenant.sh tests ==="

# Test 1: Script exists and is executable
echo ""
echo "--- Test 1: Script exists and is executable ---"
assert_file_exists "sync-tenant.sh exists" "$SYNC_SCRIPT"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -x "$SYNC_SCRIPT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: sync-tenant.sh is executable"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: sync-tenant.sh is not executable"
fi

# Test 2: Full sync creates correct directory structure
echo ""
echo "--- Test 2: Full sync directory structure ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_sync "$WORKDIR")"

assert_file_exists "Sales Dashboard config.yml" \
  "$WORKDIR/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard (app-001)/config.yml"
assert_file_exists "HR Analytics config.yml" \
  "$WORKDIR/.qlik-sync/test-tenant/HR Dev/HR Analytics (app-002)/config.yml"
assert_file_exists "Sales Dashboard DEV config.yml" \
  "$WORKDIR/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard DEV (app-003)/config.yml"
assert_file_exists "Finance Extract config.yml" \
  "$WORKDIR/.qlik-sync/test-tenant/Finance Prod/Finance Extract (app-004)/config.yml"
assert_file_exists "HR Transform config.yml" \
  "$WORKDIR/.qlik-sync/test-tenant/HR Dev/HR Transform (app-005)/config.yml"

# Test 3: Index built with correct fields
echo ""
echo "--- Test 3: Index file ---"
INDEX="$WORKDIR/.qlik-sync/index.json"
assert_file_exists "index.json exists" "$INDEX"
assert_json_field "appCount is 5" "$INDEX" ".appCount" "5"
assert_json_field "tenant is test-tenant" "$INDEX" ".tenant" "test-tenant"
assert_json_field "context is test-ctx" "$INDEX" ".context" "test-ctx"
assert_json_field "server is correct" "$INDEX" ".server" "https://test-tenant.us.qlikcloud.com"

# Check app entries in index
assert_json_field "app-001 space is Finance Prod" "$INDEX" '.apps["app-001"].space' "Finance Prod"
assert_json_field "app-002 space is HR Dev" "$INDEX" '.apps["app-002"].space' "HR Dev"
assert_json_field "app-001 name" "$INDEX" '.apps["app-001"].name' "Sales Dashboard"
assert_json_field "app-001 path" "$INDEX" '.apps["app-001"].path' "test-tenant/Finance Prod/Sales Dashboard (app-001)/"
assert_json_field "app-001 owner" "$INDEX" '.apps["app-001"].owner' "user-001"
assert_json_field "app-001 published" "$INDEX" '.apps["app-001"].published' "true"
assert_json_field "app-001 description" "$INDEX" '.apps["app-001"].description' "Monthly sales KPIs"

# Test 4: Resume skips existing apps
echo ""
echo "--- Test 4: Resume (skip existing) ---"
OUTPUT2="$(run_sync "$WORKDIR")"
assert_contains "output contains SKIP" "$OUTPUT2" "SKIP"

# Test 5: Force re-syncs all apps
echo ""
echo "--- Test 5: Force re-sync ---"
OUTPUT3="$(run_sync "$WORKDIR" --force)"
assert_contains "force output contains Syncing" "$OUTPUT3" "Syncing"

# Count that no SKIP appears in force output
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$OUTPUT3" | grep -q "SKIP"; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: force output should not contain SKIP"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: force output does not contain SKIP"
fi

# Test 6: Space filter
echo ""
echo "--- Test 6: Space filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT4="$(run_sync "$WORKDIR2" --space "Finance Prod")"

assert_file_exists "Filtered: Sales Dashboard exists" \
  "$WORKDIR2/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard (app-001)/config.yml"
assert_file_exists "Filtered: Sales Dashboard DEV exists" \
  "$WORKDIR2/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard DEV (app-003)/config.yml"
assert_file_exists "Filtered: Finance Extract exists" \
  "$WORKDIR2/.qlik-sync/test-tenant/Finance Prod/Finance Extract (app-004)/config.yml"

# HR apps should NOT exist
assert_file_not_exists "Filtered: HR Analytics not synced" \
  "$WORKDIR2/.qlik-sync/test-tenant/HR Dev/HR Analytics (app-002)/config.yml"
assert_file_not_exists "Filtered: HR Transform not synced" \
  "$WORKDIR2/.qlik-sync/test-tenant/HR Dev/HR Transform (app-005)/config.yml"

# Space-filtered index should have 3 apps
assert_json_field "filtered appCount is 3" "$WORKDIR2/.qlik-sync/index.json" ".appCount" "3"

# Test 7: Config.json lastSync updated
echo ""
echo "--- Test 7: lastSync updated ---"
LASTSYNC="$(jq -r '.lastSync' "$WORKDIR/.qlik-sync/config.json")"
TESTS_RUN=$((TESTS_RUN + 1))
if [ "$LASTSYNC" != "null" ] && [ -n "$LASTSYNC" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: config.json lastSync is set ($LASTSYNC)"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: config.json lastSync not set"
fi

test_summary
