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

test_summary
