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

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "opus 4.6" "Opus 4.6" "$result"

result=$(echo '{"model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "sonnet 4.6" "Sonnet 4.6" "$result"

result=$(echo '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":10,"context_window_size":200000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "haiku 4.5" "Haiku 4.5" "$result"

# --- Context display + color thresholds ---
echo "Context display and color thresholds:"

# Under 80k — no color
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "under 80k shows percentage" "5% (50k)" "$result"
# Verify no ANSI codes present
if echo "$result" | grep -qP '\033\[3[13]m'; then
  echo "  FAIL: under 80k should have no color"
  ((++FAIL))
else
  echo "  PASS: under 80k has no color"
  ((++PASS))
fi

# At 80k — amber (80k tokens on 1M window = 8%)
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":8,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "at 80k shows percentage" "8% (80k)" "$result"
if echo "$result" | grep -qP '\033\[33m'; then
  echo "  PASS: at 80k has amber color"
  ((++PASS))
else
  echo "  FAIL: at 80k should have amber color"
  ((++FAIL))
fi

# At 160k — red (160k tokens on 1M window = 16%)
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":16,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "at 160k shows percentage" "16% (160k)" "$result"
if echo "$result" | grep -qP '\033\[31m'; then
  echo "  PASS: at 160k has red color"
  ((++PASS))
else
  echo "  FAIL: at 160k should have red color"
  ((++FAIL))
fi

# Haiku 200k at 50% = 100k — amber
result=$(echo '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":50,"context_window_size":200000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "haiku 50% shows 100k" "50% (100k)" "$result"
if echo "$result" | grep -qP '\033\[33m'; then
  echo "  PASS: haiku at 100k has amber color"
  ((++PASS))
else
  echo "  FAIL: haiku at 100k should have amber color"
  ((++FAIL))
fi

# --- Spend display ---
echo "Spend display:"

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":1.234}}' | bash "$SCRIPT")
assert_contains "cost formatted" '$1.23' "$result"

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "zero cost" '$0.00' "$result"

# --- Full output format ---
echo "Full output format:"

# Strip ANSI codes for format check
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":1.5}}' | bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format: model | context | cost" "Opus 4.6 | 5% (50k) | \$1.50" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
