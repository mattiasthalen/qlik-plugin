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

# --- Path display ---
echo "Path display:"

# Normal repo — just basename of CLAUDE_PROJECT_DIR
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "normal repo shows basename" "primer (" "$result"

# Worktree — project > worktree
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer/.claude/worktrees/feat+my-feature" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "worktree shows project > worktree" "primer > feat+my-feature (" "$result"

# Non-git directory — script still runs, shows path with fallback branch
result=$(CLAUDE_PROJECT_DIR="/tmp/myproject" GIT_TOPLEVEL="/tmp/myproject" GIT_BRANCH="" GIT_SHA="unknown" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "non-git dir shows path" "myproject (" "$result"

# --- Branch display ---
echo "Branch display:"

# Branch name from GIT_BRANCH override
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "shows branch name" "(main)" "$result"

# Feature branch
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="feat/my-feature" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "shows feature branch" "(feat/my-feature)" "$result"

# Detached HEAD — GIT_BRANCH empty, GIT_SHA provided
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="" GIT_SHA="abc1234" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "detached HEAD shows short SHA" "(abc1234)" "$result"

# --- Git status indicators ---
echo "Git status indicators:"

# Clean — no indicators
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="" GIT_BEHIND="" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "clean repo has no indicators" "(main)" "$result"
# Verify no * or ! in branch parens
if echo "$result" | grep -qP '\(main [*!]'; then
  echo "  FAIL: clean repo should have no indicators"
  ((++FAIL))
else
  echo "  PASS: clean repo has no stray indicators"
  ((++PASS))
fi

# Dirty only
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="1" GIT_UNTRACKED="" GIT_AHEAD="" GIT_BEHIND="" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "dirty shows *" "(main *)" "$result"

# Untracked only
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="1" GIT_AHEAD="" GIT_BEHIND="" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "untracked shows !" "(main !)" "$result"

# Both dirty and untracked
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="1" GIT_UNTRACKED="1" GIT_AHEAD="" GIT_BEHIND="" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "dirty+untracked shows *!" "(main *!)" "$result"

# --- Ahead/behind indicators ---
echo "Ahead/behind indicators:"

# Ahead only
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="3" GIT_BEHIND="" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "ahead shows arrow up" "(main ↑3)" "$result"

# Behind only
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="" GIT_BEHIND="2" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "behind shows arrow down" "(main ↓2)" "$result"

# Ahead and behind
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="5" GIT_BEHIND="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "ahead+behind shows both arrows" "(main ↑5 ↓1)" "$result"

# All indicators combined
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="feat/x" GIT_DIRTY="1" GIT_UNTRACKED="1" GIT_AHEAD="2" GIT_BEHIND="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "all indicators combined" "(feat/x *! ↑2 ↓1)" "$result"

# No upstream — no arrows
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "no upstream shows clean branch" "(main)" "$result"

# --- Model name derivation ---
echo "Model name derivation:"

result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}')
assert_contains "opus 4.6" "Opus 4.6" "$result"

result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}')
assert_contains "sonnet 4.6" "Sonnet 4.6" "$result"

result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":10,"context_window_size":200000},"cost":{"total_cost_usd":0.5}}')
assert_contains "haiku 4.5" "Haiku 4.5" "$result"

# Model IDs with context-window suffix (e.g. [1m])
result=$(echo '{"model":{"id":"claude-opus-4-6[1m]","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "opus 4.6 with [1m] suffix" "Opus 4.6" "$result"

result=$(echo '{"model":{"id":"claude-sonnet-4-6[1m]","display_name":"Sonnet"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0.5}}' | bash "$SCRIPT")
assert_contains "sonnet 4.6 with [1m] suffix" "Sonnet 4.6" "$result"

# --- Context display + color thresholds ---
echo "Context display and color thresholds:"

# Under 80k — no color
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0}}')
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
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":8,"context_window_size":1000000},"cost":{"total_cost_usd":0}}')
assert_contains "at 80k shows percentage" "8% (80k)" "$result"
if echo "$result" | grep -qP '\033\[33m'; then
  echo "  PASS: at 80k has amber color"
  ((++PASS))
else
  echo "  FAIL: at 80k should have amber color"
  ((++FAIL))
fi

# At 160k — red (160k tokens on 1M window = 16%)
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":16,"context_window_size":1000000},"cost":{"total_cost_usd":0}}')
assert_contains "at 160k shows percentage" "16% (160k)" "$result"
if echo "$result" | grep -qP '\033\[31m'; then
  echo "  PASS: at 160k has red color"
  ((++PASS))
else
  echo "  FAIL: at 160k should have red color"
  ((++FAIL))
fi

# Haiku 200k at 50% = 100k — amber
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":50,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
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

result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":1.234}}')
assert_contains "cost formatted" '$1.23' "$result"

result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0}}')
assert_contains "zero cost" '$0.00' "$result"

# --- Full output format ---
echo "Full output format:"

# Strip ANSI codes for format check
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="" GIT_BEHIND="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":1.5}}' | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format: path (branch) | model | context | cost" "primer (main) | Opus 4.6 | 5% (50k) | \$1.50" "$result"

# Full format with worktree and all indicators
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer/.claude/worktrees/feat+thing" GIT_BRANCH="feat/thing" GIT_DIRTY="1" GIT_UNTRACKED="1" GIT_AHEAD="2" GIT_BEHIND="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-sonnet-4-6"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0.75}}' | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format with worktree and indicators" "primer > feat+thing (feat/thing *! ↑2 ↓1) | Sonnet 4.6 | 10% (100k) | \$0.75" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
