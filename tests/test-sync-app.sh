#!/bin/bash
# Tests for sync-app.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

APP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-app.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-app.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-app.sh exists" "$APP_SCRIPT"

# Test 2: Syncs single app successfully
echo ""
echo "--- Test 2: Successful sync ---"
WORKDIR="$TMPDIR_BASE/test-sync-app"
mkdir -p "$WORKDIR/.qlik-sync"
TARGET="test-tenant (tid)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR" && PATH="$MOCK_DIR:$PATH" bash "$APP_SCRIPT" "app-001" "$TARGET" 2>/dev/null); then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits 0 on success"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit 0 on success"
fi

# Verify directory and files created
assert_dir_exists "target dir created" "$WORKDIR/.qlik-sync/$TARGET"
assert_file_exists "config.yml created" "$WORKDIR/.qlik-sync/$TARGET/config.yml"
assert_file_exists "script.qvs created" "$WORKDIR/.qlik-sync/$TARGET/script.qvs"

# Test 3: No stdout output
echo ""
echo "--- Test 3: No stdout output ---"
WORKDIR2="$TMPDIR_BASE/test-sync-app-stdout"
mkdir -p "$WORKDIR2/.qlik-sync"
TARGET2="test-tenant (tid)/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)"
STDOUT="$(cd "$WORKDIR2" && PATH="$MOCK_DIR:$PATH" bash "$APP_SCRIPT" "app-002" "$TARGET2" 2>/dev/null)"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -z "$STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: no stdout output"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: unexpected stdout: $STDOUT"
fi

# Test 4: Fails gracefully on bad app ID
echo ""
echo "--- Test 4: Fails on unbuild error ---"
WORKDIR3="$TMPDIR_BASE/test-sync-app-fail"
mkdir -p "$WORKDIR3/.qlik-sync"
# Use a mock that will fail
FAIL_MOCK="$TMPDIR_BASE/fail-mock"
mkdir -p "$FAIL_MOCK"
cat > "$FAIL_MOCK/qlik" <<'MOCK'
#!/bin/bash
echo "Error: app not found" >&2
exit 1
MOCK
chmod +x "$FAIL_MOCK/qlik"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR3" && PATH="$FAIL_MOCK:$PATH" bash "$APP_SCRIPT" "bad-id" "some/path" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero on unbuild failure"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero on unbuild failure"
fi

test_summary
