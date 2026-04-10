#!/bin/bash
# Tests for sync-lib.sh — shared helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

LIB_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-lib.sh"

echo "=== sync-lib.sh tests ==="

# Source the library
source "$LIB_SCRIPT"

echo "--- sanitize ---"
assert_eq "sanitize replaces special chars with underscores" \
  "hello_world_test" \
  "$(sanitize 'hello/world:test')"

assert_eq "sanitize preserves hyphens" \
  "normal-name" \
  "$(sanitize 'normal-name')"

assert_eq "sanitize replaces backslash" \
  "a_b" \
  "$(sanitize 'a\b')"

assert_eq "sanitize replaces pipe" \
  "a_b" \
  "$(sanitize 'a|b')"

assert_eq "sanitize replaces angle brackets" \
  "a_b_c" \
  "$(sanitize 'a<b>c')"

echo "--- normalize_app_type ---"
assert_eq "normalize_app_type lowercases and replaces underscores" \
  "dataflow-prep" \
  "$(normalize_app_type 'DATAFLOW_PREP')"

assert_eq "normalize_app_type handles already lowercase" \
  "analytics" \
  "$(normalize_app_type 'analytics')"

assert_eq "normalize_app_type handles mixed case with underscores" \
  "data-prep" \
  "$(normalize_app_type 'Data_Prep')"

test_summary
