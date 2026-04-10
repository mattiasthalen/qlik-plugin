#!/bin/bash
# Tests for sync-onprem-prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-onprem-prep.sh"
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
      "context": "onprem-ctx",
      "server": "https://qseow.corp.local/jwt",
      "type": "on-prem",
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

echo "=== sync-onprem-prep.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-onprem-prep.sh exists" "$PREP_SCRIPT"

# Test 2: Full listing — valid JSON with 3 apps and correct fields
echo ""
echo "--- Test 2: Full listing ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_prep "$WORKDIR")"

PREP_JSON="$TMPDIR_BASE/prep-output.json"
echo "$OUTPUT" > "$PREP_JSON"

assert_json_field "tenant is qseow.corp.local" "$PREP_JSON" ".tenant" "qseow.corp.local"
assert_json_field "tenantId is empty" "$PREP_JSON" ".tenantId" ""
assert_json_field "context correct" "$PREP_JSON" ".context" "onprem-ctx"
assert_json_field "server correct" "$PREP_JSON" ".server" "https://qseow.corp.local/jwt"
assert_json_field "totalApps is 3" "$PREP_JSON" ".totalApps" "3"

# Check published app in Finance Stream
assert_json_field "app-001 name" "$PREP_JSON" '.apps[0].name' "Finance Report"
assert_json_field "app-001 resourceId" "$PREP_JSON" '.apps[0].resourceId' "qrs-app-001"
assert_json_field "app-001 spaceName" "$PREP_JSON" '.apps[0].spaceName' "Finance Stream"
assert_json_field "app-001 spaceType is stream" "$PREP_JSON" '.apps[0].spaceType' "stream"
assert_json_field "app-001 appType is null" "$PREP_JSON" '.apps[0].appType' "null"
assert_json_field "app-001 ownerName" "$PREP_JSON" '.apps[0].ownerName' "Jane Doe"
assert_json_field "app-001 targetPath" "$PREP_JSON" '.apps[0].targetPath' \
  "qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"

# Check published app in HR Stream
assert_json_field "app-002 spaceType is stream" "$PREP_JSON" '.apps[1].spaceType' "stream"
assert_json_field "app-002 targetPath" "$PREP_JSON" '.apps[1].targetPath' \
  "qseow.corp.local/stream/HR Stream (stream-002)/HR Dashboard (qrs-app-002)"

# Check unpublished personal app
assert_json_field "app-003 spaceType is personal" "$PREP_JSON" '.apps[2].spaceType' "personal"
assert_json_field "app-003 ownerName" "$PREP_JSON" '.apps[2].ownerName' "Jane Doe"
assert_json_field "app-003 targetPath" "$PREP_JSON" '.apps[2].targetPath' \
  "qseow.corp.local/personal/Jane Doe (user-qrs-001)/Personal Scratch (qrs-app-003)"

# Test 3: Stream filter
echo ""
echo "--- Test 3: Stream filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT2="$(run_prep "$WORKDIR2" --stream "Finance Stream")"
PREP_JSON2="$TMPDIR_BASE/prep-stream.json"
echo "$OUTPUT2" > "$PREP_JSON2"
assert_json_field "stream filter totalApps is 1" "$PREP_JSON2" ".totalApps" "1"
assert_json_field "stream filter correct app" "$PREP_JSON2" '.apps[0].name' "Finance Report"

# Test 4: App name filter
echo ""
echo "--- Test 4: App name filter ---"
WORKDIR3="$(setup_workdir)"
OUTPUT3="$(run_prep "$WORKDIR3" --app "Dashboard")"
PREP_JSON3="$TMPDIR_BASE/prep-app.json"
echo "$OUTPUT3" > "$PREP_JSON3"
assert_json_field "app filter totalApps is 1" "$PREP_JSON3" ".totalApps" "1"
assert_json_field "app filter correct app" "$PREP_JSON3" '.apps[0].name' "HR Dashboard"

# Test 5: Skip detection — pre-create script.qvs
echo ""
echo "--- Test 5: Skip detection ---"
WORKDIR4="$(setup_workdir)"
# Pre-create script.qvs for app-001
SKIP_PATH="$WORKDIR4/.qlik-sync/qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"
mkdir -p "$SKIP_PATH"
touch "$SKIP_PATH/script.qvs"
OUTPUT4="$(run_prep "$WORKDIR4")"
PREP_JSON4="$TMPDIR_BASE/prep-skip.json"
echo "$OUTPUT4" > "$PREP_JSON4"

# app-001 should be skipped
TESTS_RUN=$((TESTS_RUN + 1))
SKIP_VAL="$(jq -r '.apps[] | select(.resourceId == "qrs-app-001") | .skip' "$PREP_JSON4")"
if [ "$SKIP_VAL" = "true" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: app-001 marked skip"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: app-001 should be skip=true, got $SKIP_VAL"
fi

# Other apps should not be skipped
TESTS_RUN=$((TESTS_RUN + 1))
NOSKIP_COUNT="$(jq '[.apps[] | select(.skip == false)] | length' "$PREP_JSON4")"
if [ "$NOSKIP_COUNT" = "2" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: 2 apps not skipped"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 2 non-skipped apps, got $NOSKIP_COUNT"
fi

test_summary
