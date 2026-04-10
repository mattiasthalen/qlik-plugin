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

echo "--- read_tenant_config ---"

TMPDIR_LIB="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LIB"' EXIT

# Test: v0.1.0 config migrates to array with type detection
cat > "$TMPDIR_LIB/config-v1.json" <<'JSON'
{
  "context": "my-ctx",
  "server": "https://my-tenant.qlikcloud.com",
  "lastSync": "2026-04-01T00:00:00Z"
}
JSON

V1_RESULT="$(read_tenant_config "$TMPDIR_LIB/config-v1.json" "")"
V1_LEN="$(echo "$V1_RESULT" | jq 'length')"
assert_eq "v0.1.0 returns array of length 1" "1" "$V1_LEN"

V1_CTX="$(echo "$V1_RESULT" | jq -r '.[0].context')"
assert_eq "v0.1.0 context preserved" "my-ctx" "$V1_CTX"

V1_TYPE="$(echo "$V1_RESULT" | jq -r '.[0].type')"
assert_eq "v0.1.0 detects cloud type" "cloud" "$V1_TYPE"

V1_SERVER="$(echo "$V1_RESULT" | jq -r '.[0].server')"
assert_eq "v0.1.0 server preserved" "https://my-tenant.qlikcloud.com" "$V1_SERVER"

V1_SYNC="$(echo "$V1_RESULT" | jq -r '.[0].lastSync')"
assert_eq "v0.1.0 lastSync preserved" "2026-04-01T00:00:00Z" "$V1_SYNC"

# Test: v0.2.0 config returns tenants array
cat > "$TMPDIR_LIB/config-v2.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "cloud-ctx",
      "server": "https://cloud.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    },
    {
      "context": "onprem-ctx",
      "server": "https://onprem.example.com",
      "type": "on-prem",
      "lastSync": null
    }
  ]
}
JSON

V2_RESULT="$(read_tenant_config "$TMPDIR_LIB/config-v2.json" "")"
V2_LEN="$(echo "$V2_RESULT" | jq 'length')"
assert_eq "v0.2.0 returns 2 tenants" "2" "$V2_LEN"

V2_CTX1="$(echo "$V2_RESULT" | jq -r '.[0].context')"
assert_eq "v0.2.0 first tenant context" "cloud-ctx" "$V2_CTX1"

V2_CTX2="$(echo "$V2_RESULT" | jq -r '.[1].context')"
assert_eq "v0.2.0 second tenant context" "onprem-ctx" "$V2_CTX2"

# Test: filter returns only matching tenant
V2_FILTERED="$(read_tenant_config "$TMPDIR_LIB/config-v2.json" "onprem-ctx")"
V2_FLEN="$(echo "$V2_FILTERED" | jq 'length')"
assert_eq "filter returns 1 tenant" "1" "$V2_FLEN"

V2_FCTX="$(echo "$V2_FILTERED" | jq -r '.[0].context')"
assert_eq "filter returns correct tenant" "onprem-ctx" "$V2_FCTX"

echo "--- detect_tenant_type ---"

assert_eq "detect_tenant_type cloud" "cloud" "$(detect_tenant_type "https://my.qlikcloud.com")"
assert_eq "detect_tenant_type on-prem" "on-prem" "$(detect_tenant_type "https://onprem.example.com")"

# Test: check_cache returns cached content when fresh
echo ""
echo "--- Test: check_cache hit ---"
CACHE_DIR="$(mktemp -d)"
CACHE_FILE="$CACHE_DIR/qlik-sync-prep-test-ctx.json"
echo '{"cached":true}' > "$CACHE_FILE"
TESTS_RUN=$((TESTS_RUN + 1))
CACHE_RESULT="$(check_cache "$CACHE_FILE" false)"
CACHE_EXIT=$?
if [ "$CACHE_EXIT" -eq 0 ] && [ "$CACHE_RESULT" = '{"cached":true}' ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: cache hit returns content"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: cache hit expected content, got exit=$CACHE_EXIT output=$CACHE_RESULT"
fi
rm -rf "$CACHE_DIR"

# Test: check_cache returns non-zero for stale cache
echo ""
echo "--- Test: check_cache miss (stale) ---"
CACHE_DIR2="$(mktemp -d)"
CACHE_FILE2="$CACHE_DIR2/qlik-sync-prep-old.json"
echo '{"cached":true}' > "$CACHE_FILE2"
touch -t 200001010000 "$CACHE_FILE2"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "$CACHE_FILE2" false >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: stale cache should miss"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: stale cache returns non-zero"
fi
rm -rf "$CACHE_DIR2"

# Test: check_cache bypassed when force=true
echo ""
echo "--- Test: check_cache bypass with force ---"
CACHE_DIR3="$(mktemp -d)"
CACHE_FILE3="$CACHE_DIR3/qlik-sync-prep-force.json"
echo '{"cached":true}' > "$CACHE_FILE3"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "$CACHE_FILE3" true >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: force should bypass cache"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: force bypasses cache"
fi
rm -rf "$CACHE_DIR3"

# Test: check_cache returns non-zero when no file exists
echo ""
echo "--- Test: check_cache miss (no file) ---"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "/tmp/nonexistent-cache-file.json" false >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: missing file should miss"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: missing file returns non-zero"
fi

test_summary
