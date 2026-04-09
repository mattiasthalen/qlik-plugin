#!/bin/bash
set -euo pipefail

SCRIPT=".claude/commands/statusline.sh"
PASS=0
FAIL=0

assert_contains() {
  local test_name="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    echo "  PASS: $test_name"
    ((++PASS))
  else
    echo "  FAIL: $test_name"
    echo "    expected to contain: $expected"
    echo "    actual: $actual"
    ((++FAIL))
  fi
}

# --- Model name derivation ---
echo "Model name derivation:"

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "opus 4.6" "Opus 4.6" "$result"

result=$(echo '{"model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "sonnet 4.6" "Sonnet 4.6" "$result"

result=$(echo '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":10,"context_window_size":200000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "haiku 4.5" "Haiku 4.5" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
