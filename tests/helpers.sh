#!/bin/bash
# Minimal test assertion library

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
  local description="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_contains() {
  local description="$1" haystack="$2" needle="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    '$needle' not found in output"
  fi
}

assert_file_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$filepath" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    file not found: $filepath"
  fi
}

assert_file_not_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -f "$filepath" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    file should not exist: $filepath"
  fi
}

assert_dir_exists() {
  local description="$1" dirpath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -d "$dirpath" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    directory not found: $dirpath"
  fi
}

assert_json_field() {
  local description="$1" filepath="$2" field="$3" expected="$4"
  local actual
  actual=$(jq -r "$field" "$filepath" 2>/dev/null)
  assert_eq "$description" "$expected" "$actual"
}

test_summary() {
  echo ""
  echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed"
  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
}
