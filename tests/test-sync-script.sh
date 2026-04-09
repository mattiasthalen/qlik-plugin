#!/bin/bash
# Tests for sync-tenant.sh script — deep hierarchy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SYNC_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-tenant.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com"
}
JSON
  echo "$workdir"
}

run_sync() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" "$@" 2>&1)
}

echo "=== sync-tenant.sh tests (deep hierarchy) ==="

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

# Test 2: Full sync — 5-level directory structure
echo ""
echo "--- Test 2: Deep directory structure ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_sync "$WORKDIR")"

# Tenant level: test-tenant (test-tenant-id)
TENANT_DIR="$WORKDIR/.qlik-sync/test-tenant (test-tenant-id)"
assert_dir_exists "tenant dir with ID" "$TENANT_DIR"

# Space type level
assert_dir_exists "managed type dir" "$TENANT_DIR/managed"
assert_dir_exists "shared type dir" "$TENANT_DIR/shared"
assert_dir_exists "personal type dir" "$TENANT_DIR/personal"

# Space level with full ID
assert_dir_exists "Finance Prod space dir" "$TENANT_DIR/managed/Finance Prod (space-001)"
assert_dir_exists "HR Dev space dir" "$TENANT_DIR/shared/HR Dev (space-002)"

# App type level
assert_dir_exists "analytics app type in Finance Prod" "$TENANT_DIR/managed/Finance Prod (space-001)/analytics"
assert_dir_exists "dataflow-prep app type in Finance Prod" "$TENANT_DIR/managed/Finance Prod (space-001)/dataflow-prep"

# App level with full resourceId
assert_file_exists "app-001 Sales Dashboard" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/config.yml"
assert_file_exists "app-002 HR Analytics" \
  "$TENANT_DIR/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)/config.yml"
assert_file_exists "app-003 Sales Dashboard DEV" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/analytics/Sales Dashboard DEV (app-003)/config.yml"
assert_file_exists "app-004 Finance Extract (dataflow-prep)" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/dataflow-prep/Finance Extract (app-004)/config.yml"
assert_file_exists "app-005 HR Transform" \
  "$TENANT_DIR/shared/HR Dev (space-002)/analytics/HR Transform (app-005)/config.yml"
assert_file_exists "app-006 Personal ETL (personal space, data-preparation)" \
  "$TENANT_DIR/personal/testuser (user-001)/data-preparation/Personal ETL (app-006)/config.yml"

# Test 3: Index file
echo ""
echo "--- Test 3: Index file ---"
INDEX="$WORKDIR/.qlik-sync/index.json"
assert_file_exists "index.json exists" "$INDEX"
assert_json_field "appCount is 6" "$INDEX" ".appCount" "6"
assert_json_field "tenant is test-tenant" "$INDEX" ".tenant" "test-tenant"
assert_json_field "tenantId present" "$INDEX" ".tenantId" "test-tenant-id"

# Check new index fields
assert_json_field "app-001 spaceType" "$INDEX" '.apps["app-001"].spaceType' "managed"
assert_json_field "app-002 spaceType" "$INDEX" '.apps["app-002"].spaceType' "shared"
assert_json_field "app-006 spaceType" "$INDEX" '.apps["app-006"].spaceType' "personal"
assert_json_field "app-001 appType" "$INDEX" '.apps["app-001"].appType' "analytics"
assert_json_field "app-004 appType" "$INDEX" '.apps["app-004"].appType' "dataflow-prep"
assert_json_field "app-006 appType" "$INDEX" '.apps["app-006"].appType' "data-preparation"
assert_json_field "app-006 ownerName" "$INDEX" '.apps["app-006"].ownerName' "testuser"

# Check path reflects deep hierarchy
assert_json_field "app-001 path" "$INDEX" '.apps["app-001"].path' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/"

# Test 4: Resume
echo ""
echo "--- Test 4: Resume (skip existing) ---"
OUTPUT2="$(run_sync "$WORKDIR")"
assert_contains "resume has SKIP" "$OUTPUT2" "SKIP"

# Test 5: Force
echo ""
echo "--- Test 5: Force re-sync ---"
OUTPUT3="$(run_sync "$WORKDIR" --force)"
assert_contains "force has Syncing" "$OUTPUT3" "Syncing"
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$OUTPUT3" | grep -q "SKIP"; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: force should not have SKIP"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: force has no SKIP"
fi

# Test 6: Space filter
echo ""
echo "--- Test 6: Space filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT4="$(run_sync "$WORKDIR2" --space "Finance Prod")"
assert_json_field "filtered appCount is 3" "$WORKDIR2/.qlik-sync/index.json" ".appCount" "3"

# Test 7: lastSync
echo ""
echo "--- Test 7: lastSync updated ---"
LASTSYNC="$(jq -r '.lastSync' "$WORKDIR/.qlik-sync/config.json")"
TESTS_RUN=$((TESTS_RUN + 1))
if [ "$LASTSYNC" != "null" ] && [ -n "$LASTSYNC" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: lastSync is set ($LASTSYNC)"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: lastSync not set"
fi

test_summary
