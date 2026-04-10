#!/bin/bash
# Tests for sync-finalize.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

FINALIZE_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-finalize.sh"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-finalize.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-finalize.sh exists" "$FINALIZE_SCRIPT"

# Test 2: Builds index.json from prep + results
echo ""
echo "--- Test 2: Builds index.json ---"
WORKDIR="$TMPDIR_BASE/test-finalize"
mkdir -p "$WORKDIR/.qlik-sync"
cat > "$WORKDIR/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "test-ctx",
      "server": "https://test-tenant.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    }
  ]
}
JSON

PREP_FILE="$TMPDIR_BASE/prep.json"
cat > "$PREP_FILE" <<'JSON'
{
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "totalApps": 3,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "Monthly sales KPIs",
      "tags": ["finance", "monthly"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    },
    {
      "resourceId": "app-002",
      "name": "HR Analytics",
      "spaceId": "space-002",
      "spaceName": "HR Dev",
      "spaceType": "shared",
      "appType": "analytics",
      "ownerId": "user-002",
      "ownerName": "hradmin",
      "description": "Employee metrics",
      "tags": ["hr"],
      "published": true,
      "lastReloadTime": "2026-04-07T12:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)",
      "skip": true,
      "skipReason": "already synced"
    },
    {
      "resourceId": "app-003",
      "name": "Bad App",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "",
      "tags": [],
      "published": false,
      "lastReloadTime": "",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Bad App (app-003)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_FILE="$TMPDIR_BASE/results.json"
cat > "$RESULTS_FILE" <<'JSON'
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "skipped"},
  {"resourceId": "app-003", "status": "error", "error": "unbuild failed"}
]
JSON

OUTPUT="$(cd "$WORKDIR" && bash "$FINALIZE_SCRIPT" "$PREP_FILE" "$RESULTS_FILE")"

INDEX="$WORKDIR/.qlik-sync/index.json"
assert_file_exists "index.json created" "$INDEX"
assert_json_field "appCount is 3" "$INDEX" ".appCount" "3"
assert_json_field "tenant correct" "$INDEX" ".tenant" "test-tenant"
assert_json_field "tenantId correct" "$INDEX" ".tenantId" "test-tenant-id"
assert_json_field "app-001 name" "$INDEX" '.apps["app-001"].name' "Sales Dashboard"
assert_json_field "app-001 path" "$INDEX" '.apps["app-001"].path' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/"
assert_json_field "app-002 present" "$INDEX" '.apps["app-002"].name' "HR Analytics"

# Check lastSync updated in config
CONFIG="$WORKDIR/.qlik-sync/config.json"
TESTS_RUN=$((TESTS_RUN + 1))
LAST_SYNC="$(jq -r '.tenants[0].lastSync' "$CONFIG")"
if [ "$LAST_SYNC" != "null" ] && [ -n "$LAST_SYNC" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: config.json lastSync updated"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: config.json lastSync not updated"
fi

# Check summary output
assert_contains "summary has synced count" "$OUTPUT" "1 synced"
assert_contains "summary has skipped count" "$OUTPUT" "1 skipped"
assert_contains "summary has error count" "$OUTPUT" "1 error"

# Test 3: Partial sync merges with existing index
echo ""
echo "--- Test 3: Partial sync merges ---"
WORKDIR2="$TMPDIR_BASE/test-finalize-merge"
mkdir -p "$WORKDIR2/.qlik-sync"
cat > "$WORKDIR2/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "test-ctx",
      "server": "https://test-tenant.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    }
  ]
}
JSON

# Pre-existing index with app-099
cat > "$WORKDIR2/.qlik-sync/index.json" <<'JSON'
{
  "lastSync": "2026-04-09T00:00:00Z",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "appCount": 1,
  "apps": {
    "app-099": {
      "name": "Old App",
      "space": "Other Space",
      "spaceId": "space-099",
      "spaceType": "shared",
      "appType": "analytics",
      "owner": "user-099",
      "ownerName": "olduser",
      "description": "",
      "tags": [],
      "published": false,
      "lastReloadTime": "",
      "path": "test-tenant (test-tenant-id)/shared/Other Space (space-099)/analytics/Old App (app-099)/"
    }
  }
}
JSON

PREP_PARTIAL="$TMPDIR_BASE/prep-partial.json"
cat > "$PREP_PARTIAL" <<'JSON'
{
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "totalApps": 1,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "Monthly sales KPIs",
      "tags": ["finance"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_PARTIAL="$TMPDIR_BASE/results-partial.json"
cat > "$RESULTS_PARTIAL" <<'JSON'
[{"resourceId": "app-001", "status": "synced"}]
JSON

(cd "$WORKDIR2" && bash "$FINALIZE_SCRIPT" "$PREP_PARTIAL" "$RESULTS_PARTIAL") >/dev/null

INDEX2="$WORKDIR2/.qlik-sync/index.json"
assert_json_field "merged appCount is 2" "$INDEX2" ".appCount" "2"
assert_json_field "old app-099 preserved" "$INDEX2" '.apps["app-099"].name' "Old App"
assert_json_field "new app-001 added" "$INDEX2" '.apps["app-001"].name' "Sales Dashboard"

# Test 4: Index includes tenant metadata
echo ""
echo "--- Test 4: Tenant metadata in index ---"
WORKDIR3="$TMPDIR_BASE/test-finalize-tenant"
mkdir -p "$WORKDIR3/.qlik-sync"
cat > "$WORKDIR3/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {"context": "test-ctx", "server": "https://test-tenant.qlikcloud.com", "type": "cloud", "lastSync": null}
  ]
}
JSON

PREP_TENANT="$TMPDIR_BASE/prep-tenant.json"
cat > "$PREP_TENANT" <<'JSON'
{
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "totalApps": 1,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "",
      "tags": [],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_TENANT="$TMPDIR_BASE/results-tenant.json"
echo '[{"resourceId": "app-001", "status": "synced"}]' > "$RESULTS_TENANT"

OUTPUT3="$(cd "$WORKDIR3" && bash "$FINALIZE_SCRIPT" "$PREP_TENANT" "$RESULTS_TENANT")"

INDEX3="$WORKDIR3/.qlik-sync/index.json"
assert_json_field "app-001 has tenant field" "$INDEX3" '.apps["app-001"].tenant' "test-tenant (test-tenant-id)"

test_summary
