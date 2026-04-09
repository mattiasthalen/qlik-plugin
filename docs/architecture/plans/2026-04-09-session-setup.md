# Session Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-activate caveman + using-superpowers skills on session start/clear, and display model/context/spend in the statusline.

**Architecture:** CLAUDE.md rule for skill invocation. Bash script for statusline fed JSON via stdin. Settings.json wires the script into Claude Code's statusline system.

**Tech Stack:** Bash, jq, ANSI escape codes

---

### Task 1: Add skill auto-invocation rule to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:20` (add after last ALWAYS rule)

- [ ] **Step 1: Write the test — verify rule exists**

```bash
grep -q "ALWAYS invoke /caveman:caveman and /superpowers:using-superpowers" CLAUDE.md
```

Run: `grep -q "ALWAYS invoke /caveman:caveman and /superpowers:using-superpowers" CLAUDE.md && echo "PASS" || echo "FAIL"`
Expected: FAIL

- [ ] **Step 2: Add the rule to CLAUDE.md**

Add after line 20 (`- ALWAYS treat the repo as the only durable state...`):

```
- ALWAYS invoke /caveman:caveman and /superpowers:using-superpowers skills on session start and after /clear before responding to user.
```

- [ ] **Step 3: Verify test passes**

Run: `grep -q "ALWAYS invoke /caveman:caveman and /superpowers:using-superpowers" CLAUDE.md && echo "PASS" || echo "FAIL"`
Expected: PASS

- [ ] **Step 4: Commit and push**

```bash
git add CLAUDE.md
git commit -m "feat(agents): add skill auto-invocation rule on session start and clear"
git push
```

---

### Task 2: Create statusline script — model name derivation

**Files:**
- Create: `.claude/commands/statusline.sh`
- Create: `tests/statusline/test_statusline.sh`

- [ ] **Step 1: Create test directory and test script**

Create `tests/statusline/test_statusline.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT=".claude/commands/statusline.sh"
PASS=0
FAIL=0

assert_contains() {
  local test_name="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    echo "  PASS: $test_name"
    ((PASS++))
  else
    echo "  FAIL: $test_name"
    echo "    expected to contain: $expected"
    echo "    actual: $actual"
    ((FAIL++))
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/statusline/test_statusline.sh`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Create minimal statusline script**

Create `.claude/commands/statusline.sh`:

```bash
#!/bin/bash
input=$(cat)

model_id=$(echo "$input" | jq -r '.model.id')

# Derive display name from model ID
# claude-opus-4-6 → Opus 4.6
# claude-sonnet-4-6 → Sonnet 4.6
# claude-haiku-4-5-20251001 → Haiku 4.5
model_name=$(echo "$model_id" | sed -E 's/^claude-//; s/-[0-9]{8,}$//; s/-/ /g' | awk '{
  for (i=1; i<=NF; i++) {
    if (i == 1) {
      printf "%s%s", toupper(substr($i,1,1)), substr($i,2)
    } else if ($i ~ /^[0-9]+$/) {
      printf ".%s", $i
    } else {
      printf " %s%s", toupper(substr($i,1,1)), substr($i,2)
    }
  }
  print ""
}')

pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
window=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

used_tokens=$(( window * pct / 100 ))
used_k=$(( (used_tokens + 500) / 1000 ))

cost_fmt=$(printf '$%.2f' "$cost")

AMBER='\033[33m'
RED='\033[31m'
RESET='\033[0m'

ctx_text="${pct}% (${used_k}k)"

if [ "$used_tokens" -ge 160000 ]; then
  ctx_display="${RED}${ctx_text}${RESET}"
elif [ "$used_tokens" -ge 80000 ]; then
  ctx_display="${AMBER}${ctx_text}${RESET}"
else
  ctx_display="${ctx_text}"
fi

echo -e "${model_name} | ${ctx_display} | ${cost_fmt}"
```

Make executable:
```bash
chmod +x .claude/commands/statusline.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/statusline/test_statusline.sh`
Expected: 3 passed, 0 failed

- [ ] **Step 5: Commit and push**

```bash
git add .claude/commands/statusline.sh tests/statusline/test_statusline.sh
git commit -m "feat(statusline): add script with model name derivation"
git push
```

---

### Task 3: Add context display with color thresholds

**Files:**
- Modify: `tests/statusline/test_statusline.sh`
- Verify: `.claude/commands/statusline.sh` (already has logic from Task 2)

- [ ] **Step 1: Add context and color tests**

Append to `tests/statusline/test_statusline.sh` (before the results summary):

```bash
# --- Context display + color thresholds ---
echo "Context display and color thresholds:"

# Under 80k — no color
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "under 80k shows percentage" "5% (50k)" "$result"
# Verify no ANSI codes present
if echo "$result" | grep -qP '\033\[3[13]m'; then
  echo "  FAIL: under 80k should have no color"
  ((FAIL++))
else
  echo "  PASS: under 80k has no color"
  ((PASS++))
fi

# At 80k — amber (80k tokens on 1M window = 8%)
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":8,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "at 80k shows percentage" "8% (80k)" "$result"
if echo "$result" | grep -qP '\033\[33m'; then
  echo "  PASS: at 80k has amber color"
  ((PASS++))
else
  echo "  FAIL: at 80k should have amber color"
  ((FAIL++))
fi

# At 160k — red (160k tokens on 1M window = 16%)
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":16,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "at 160k shows percentage" "16% (160k)" "$result"
if echo "$result" | grep -qP '\033\[31m'; then
  echo "  PASS: at 160k has red color"
  ((PASS++))
else
  echo "  FAIL: at 160k should have red color"
  ((FAIL++))
fi

# Haiku 200k at 50% = 100k — amber
result=$(echo '{"model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"used_percentage":50,"context_window_size":200000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "haiku 50% shows 100k" "50% (100k)" "$result"
if echo "$result" | grep -qP '\033\[33m'; then
  echo "  PASS: haiku at 100k has amber color"
  ((PASS++))
else
  echo "  FAIL: haiku at 100k should have amber color"
  ((FAIL++))
fi
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bash tests/statusline/test_statusline.sh`
Expected: All passed (implementation already in place from Task 2)

- [ ] **Step 3: Commit and push**

```bash
git add tests/statusline/test_statusline.sh
git commit -m "test(statusline): add context display and color threshold tests"
git push
```

---

### Task 4: Add spend display

**Files:**
- Modify: `tests/statusline/test_statusline.sh`
- Verify: `.claude/commands/statusline.sh` (already has logic from Task 2)

- [ ] **Step 1: Add spend format tests**

Append to `tests/statusline/test_statusline.sh` (before the results summary):

```bash
# --- Spend display ---
echo "Spend display:"

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":1.234}}' | bash "$SCRIPT")
assert_contains "cost formatted" '$1.23' "$result"

result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0}}' | bash "$SCRIPT")
assert_contains "zero cost" '$0.00' "$result"
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bash tests/statusline/test_statusline.sh`
Expected: All passed (implementation already in place from Task 2)

- [ ] **Step 3: Commit and push**

```bash
git add tests/statusline/test_statusline.sh
git commit -m "test(statusline): add spend display tests"
git push
```

---

### Task 5: Add full output format test

**Files:**
- Modify: `tests/statusline/test_statusline.sh`

- [ ] **Step 1: Add end-to-end format test**

Append to `tests/statusline/test_statusline.sh` (before the results summary):

```bash
# --- Full output format ---
echo "Full output format:"

# Strip ANSI codes for format check
result=$(echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":1.5}}' | bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format: model | context | cost" "Opus 4.6 | 10% (100k) | \$1.50" "$result"
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bash tests/statusline/test_statusline.sh`
Expected: All passed

- [ ] **Step 3: Commit and push**

```bash
git add tests/statusline/test_statusline.sh
git commit -m "test(statusline): add full output format test"
git push
```

---

### Task 6: Add statusLine config to settings.json

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Write the test — verify statusLine key exists**

```bash
jq -e '.statusLine.command' .claude/settings.json
```

Run: `jq -e '.statusLine.command' .claude/settings.json && echo "PASS" || echo "FAIL"`
Expected: FAIL

- [ ] **Step 2: Update settings.json**

Add `statusLine` block to `.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "$CLAUDE_PROJECT_DIR/.claude/commands/statusline.sh",
    "refreshInterval": 10
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "codex@openai-codex": true,
    "caveman@caveman": true
  },
  "extraKnownMarketplaces": {
    "openai-codex": {
      "source": {
        "source": "github",
        "repo": "openai/codex-plugin-cc"
      }
    },
    "caveman": {
      "source": {
        "source": "github",
        "repo": "JuliusBrussee/caveman"
      }
    }
  }
}
```

- [ ] **Step 3: Verify test passes**

Run: `jq -e '.statusLine.command' .claude/settings.json && echo "PASS" || echo "FAIL"`
Expected: PASS — outputs `$CLAUDE_PROJECT_DIR/.claude/commands/statusline.sh`

- [ ] **Step 4: Commit and push**

```bash
git add .claude/settings.json
git commit -m "feat(statusline): add statusLine config to project settings"
git push
```
