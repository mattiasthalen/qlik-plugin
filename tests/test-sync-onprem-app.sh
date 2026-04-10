#!/bin/bash
# Tests for sync-onprem-app.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

APP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-onprem-app.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"
MOCK_PARSER_DIR="$SCRIPT_DIR/mock-qlik-parser"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-onprem-app.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-onprem-app.sh exists" "$APP_SCRIPT"

# Test 2: Successful export + parse
echo ""
echo "--- Test 2: Successful export + parse ---"
WORKDIR="$TMPDIR_BASE/test-onprem-app"
mkdir -p "$WORKDIR/.qlik-sync"
TARGET="qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR" && PATH="$MOCK_DIR:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "qrs-app-001" "$TARGET" 2>/dev/null); then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits 0 on success"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit 0 on success"
fi

# Verify directory and files created
assert_dir_exists "target dir created" "$WORKDIR/.qlik-sync/$TARGET"
assert_file_exists "script.qvs created" "$WORKDIR/.qlik-sync/$TARGET/script.qvs"
assert_file_exists "measures.json created" "$WORKDIR/.qlik-sync/$TARGET/measures.json"
assert_file_exists "dimensions.json created" "$WORKDIR/.qlik-sync/$TARGET/dimensions.json"
assert_file_exists "variables.json created" "$WORKDIR/.qlik-sync/$TARGET/variables.json"

# Verify QVF cleaned up
assert_file_not_exists "QVF cleaned up" "/tmp/qrs-app-001.qvf"

# Test 3: No stdout output
echo ""
echo "--- Test 3: No stdout output ---"
WORKDIR2="$TMPDIR_BASE/test-onprem-app-stdout"
mkdir -p "$WORKDIR2/.qlik-sync"
TARGET2="qseow.corp.local/stream/HR Stream (stream-002)/HR Dashboard (qrs-app-002)"
STDOUT="$(cd "$WORKDIR2" && PATH="$MOCK_DIR:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "qrs-app-002" "$TARGET2" 2>/dev/null)"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -z "$STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: no stdout output"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: unexpected stdout: $STDOUT"
fi

# Test 4: Fails on export error
echo ""
echo "--- Test 4: Fails on export error ---"
WORKDIR3="$TMPDIR_BASE/test-onprem-app-fail"
mkdir -p "$WORKDIR3/.qlik-sync"
FAIL_MOCK="$TMPDIR_BASE/fail-mock"
mkdir -p "$FAIL_MOCK"
cat > "$FAIL_MOCK/qlik" <<'MOCK'
#!/bin/bash
echo "Error: export failed" >&2
exit 1
MOCK
chmod +x "$FAIL_MOCK/qlik"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR3" && PATH="$FAIL_MOCK:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "bad-id" "some/path" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero on export failure"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero on export failure"
fi

test_summary
