#!/bin/bash
# Tests for sync-prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-prep.sh"
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

run_prep() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" "$@" 2>/dev/null)
}

run_prep_stderr() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" "$@" 2>&1 1>/dev/null)
}

echo "=== sync-prep.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-prep.sh exists" "$PREP_SCRIPT"

# Test 2: Fails without config
echo ""
echo "--- Test 2: Fails without config ---"
NO_CONFIG_DIR="$TMPDIR_BASE/no-config-$$"
mkdir -p "$NO_CONFIG_DIR"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$NO_CONFIG_DIR" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero without config"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero without config"
fi

# Test 3: Full sync outputs valid JSON with all apps
echo ""
echo "--- Test 3: Full sync JSON output ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_prep "$WORKDIR")"

# Validate JSON structure
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$OUTPUT" | jq -e '.tenant' >/dev/null 2>&1; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: output is valid JSON with tenant field"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: output is not valid JSON or missing tenant"
fi

# Save to temp for field checks
PREP_JSON="$TMPDIR_BASE/prep-output.json"
echo "$OUTPUT" > "$PREP_JSON"

assert_json_field "tenant is test-tenant" "$PREP_JSON" ".tenant" "test-tenant"
assert_json_field "tenantId is test-tenant-id" "$PREP_JSON" ".tenantId" "test-tenant-id"
assert_json_field "totalApps is 6" "$PREP_JSON" ".totalApps" "6"
assert_json_field "server correct" "$PREP_JSON" ".server" "https://test-tenant.qlikcloud.com"
assert_json_field "context correct" "$PREP_JSON" ".context" "test-ctx"

# Check first app has required fields
assert_json_field "app-001 name" "$PREP_JSON" '.apps[0].name' "Sales Dashboard"
assert_json_field "app-001 resourceId" "$PREP_JSON" '.apps[0].resourceId' "app-001"
assert_json_field "app-001 spaceName" "$PREP_JSON" '.apps[0].spaceName' "Finance Prod"
assert_json_field "app-001 spaceType" "$PREP_JSON" '.apps[0].spaceType' "managed"
assert_json_field "app-001 appType" "$PREP_JSON" '.apps[0].appType' "analytics"
assert_json_field "app-001 skip is false" "$PREP_JSON" '.apps[0].skip' "false"
assert_json_field "app-001 targetPath" "$PREP_JSON" '.apps[0].targetPath' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)"

# Check personal space app
PERSONAL_APP="$(echo "$OUTPUT" | jq -r '.apps[] | select(.resourceId == "app-006")')"
PERSONAL_JSON="$TMPDIR_BASE/personal-app.json"
echo "$PERSONAL_APP" > "$PERSONAL_JSON"
assert_json_field "app-006 spaceType is personal" "$PERSONAL_JSON" ".spaceType" "personal"
assert_json_field "app-006 appType is data-preparation" "$PERSONAL_JSON" ".appType" "data-preparation"
assert_json_field "app-006 ownerName" "$PERSONAL_JSON" ".ownerName" "testuser"

test_summary
