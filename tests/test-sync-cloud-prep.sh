#!/bin/bash
# Tests for sync-prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-cloud-prep.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
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

# Test 4: Space filter
echo ""
echo "--- Test 4: Space filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT2="$(run_prep "$WORKDIR2" --space "Finance Prod")"
PREP_JSON2="$TMPDIR_BASE/prep-space.json"
echo "$OUTPUT2" > "$PREP_JSON2"
assert_json_field "space filter totalApps is 3" "$PREP_JSON2" ".totalApps" "3"

# All apps should be in Finance Prod
TESTS_RUN=$((TESTS_RUN + 1))
ALL_FINANCE="$(jq '[.apps[] | select(.spaceName == "Finance Prod")] | length' "$PREP_JSON2")"
if [ "$ALL_FINANCE" = "3" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: all 3 apps are in Finance Prod"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 3 Finance Prod apps, got $ALL_FINANCE"
fi

# Test 5: App name filter
echo ""
echo "--- Test 5: App name filter ---"
WORKDIR3="$(setup_workdir)"
OUTPUT3="$(run_prep "$WORKDIR3" --app "Sales")"
PREP_JSON3="$TMPDIR_BASE/prep-app.json"
echo "$OUTPUT3" > "$PREP_JSON3"
assert_json_field "app filter totalApps is 2" "$PREP_JSON3" ".totalApps" "2"

# Test 6: ID filter
echo ""
echo "--- Test 6: ID filter ---"
WORKDIR4="$(setup_workdir)"
OUTPUT4="$(run_prep "$WORKDIR4" --id "app-003")"
PREP_JSON4="$TMPDIR_BASE/prep-id.json"
echo "$OUTPUT4" > "$PREP_JSON4"
assert_json_field "id filter totalApps is 1" "$PREP_JSON4" ".totalApps" "1"
assert_json_field "id filter correct app" "$PREP_JSON4" '.apps[0].resourceId' "app-003"

# Test 7: Resume skip
echo ""
echo "--- Test 7: Resume marks skip ---"
WORKDIR5="$(setup_workdir)"
WORKDIR5_HASH="$(echo "$WORKDIR5" | md5sum | cut -c1-8)"
# First run to create files
(cd "$WORKDIR5" && PATH="$MOCK_DIR:$PATH" bash "$REPO_ROOT/skills/sync/scripts/sync-tenant.sh" 2>/dev/null) >/dev/null
# Clear any stale cache so skip detection runs fresh
rm -f "/tmp/qlik-sync-prep-test-ctx-${WORKDIR5_HASH}.json"
# Now prep should mark all as skip
OUTPUT5="$(run_prep "$WORKDIR5")"
PREP_JSON5="$TMPDIR_BASE/prep-skip.json"
echo "$OUTPUT5" > "$PREP_JSON5"
SKIP_COUNT="$(jq '[.apps[] | select(.skip == true)] | length' "$PREP_JSON5")"
assert_eq "all 6 apps marked skip" "6" "$SKIP_COUNT"

# Test 8: Force overrides skip
echo ""
echo "--- Test 8: Force overrides skip ---"
OUTPUT6="$(run_prep "$WORKDIR5" --force)"
PREP_JSON6="$TMPDIR_BASE/prep-force.json"
echo "$OUTPUT6" > "$PREP_JSON6"
SKIP_COUNT2="$(jq '[.apps[] | select(.skip == true)] | length' "$PREP_JSON6")"
assert_eq "force: 0 apps marked skip" "0" "$SKIP_COUNT2"

# Test 9: Cache hit — fresh cache file skips API calls
echo ""
echo "--- Test 9: Cache hit ---"
WORKDIR7="$(setup_workdir)"
WORKDIR7_HASH="$(echo "$WORKDIR7" | md5sum | cut -c1-8)"
CACHE_FILE="/tmp/qlik-sync-prep-test-ctx-${WORKDIR7_HASH}.json"
rm -f "$CACHE_FILE"
# Run once to populate cache
FIRST_OUTPUT="$(run_prep "$WORKDIR7")"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -f "$CACHE_FILE" ]; then
  # Run again — should return cached output
  SECOND_OUTPUT="$(run_prep "$WORKDIR7")"
  if [ "$FIRST_OUTPUT" = "$SECOND_OUTPUT" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: second run returns cached output"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: cached output differs from first run"
  fi
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: cache file not created at $CACHE_FILE"
fi

# Test 10: Cache bypass with --force
echo ""
echo "--- Test 10: Cache bypass with --force ---"
# Cache file should still exist from Test 9
TESTS_RUN=$((TESTS_RUN + 1))
FORCE_OUTPUT="$(run_prep "$WORKDIR7" --force)"
FORCE_APPS="$(echo "$FORCE_OUTPUT" | jq '.totalApps')"
if [ "$FORCE_APPS" = "6" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: --force bypasses cache and fetches fresh data"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 6 apps with --force, got $FORCE_APPS"
fi

test_summary
