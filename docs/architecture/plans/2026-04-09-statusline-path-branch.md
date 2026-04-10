# Statusline Path + Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add current path and git branch with status indicators to the statusline, and fix portability bugs.

**Architecture:** Extend the existing `.claude/commands/statusline.sh` to prepend a path+branch segment. Fix `echo -e` → `printf '%b\n'` and replace awk model name parser with sed-only chain. All tests in `tests/statusline/test_statusline.sh`.

**Tech Stack:** Bash, jq, git, sed, printf

---

## File Structure

| File | Responsibility |
|------|---------------|
| `.claude/commands/statusline.sh` | Statusline script — path, branch, model, context, cost |
| `tests/statusline/test_statusline.sh` | All statusline tests |

---

### Task 1: Fix portability — replace `echo -e` with `printf` and simplify model name parsing

**Files:**
- Modify: `.claude/commands/statusline.sh:11-31` (model name parsing)
- Modify: `.claude/commands/statusline.sh:55` (echo -e → printf)
- Test: `tests/statusline/test_statusline.sh`

- [ ] **Step 1: Update existing tests to use `printf` output verification**

No test code changes needed — existing tests already verify output content. Run them to confirm current baseline.

- [ ] **Step 2: Run tests to verify current baseline passes**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS (all existing tests pass)

- [ ] **Step 3: Replace awk model parser with sed chain and echo -e with printf**

In `.claude/commands/statusline.sh`, replace lines 11-31 (the awk block) with:

```bash
# Derive display name from model ID
# claude-opus-4-6 → Opus 4.6
# claude-sonnet-4-6 → Sonnet 4.6
# claude-haiku-4-5-20251001 → Haiku 4.5
model_name=$(echo "$model_id" \
  | sed -E 's/^claude-//' \
  | sed -E 's/-[0-9]{8,}$//' \
  | sed -E 's/-([0-9]+)-([0-9]+)$/ \1.\2/' \
  | sed -E 's/^(.)/\u\1/')
```

And replace line 55:

```bash
echo -e "${model_name} | ${ctx_display} | ${cost_fmt}"
```

with:

```bash
printf '%b\n' "${model_name} | ${ctx_display} | ${cost_fmt}"
```

- [ ] **Step 4: Run tests to verify portability fix passes**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS (all tests still pass with new parsing and printf)

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/statusline.sh
git commit -m "fix(statusline): replace echo -e with printf and simplify model parser

Use printf '%b\n' for POSIX-portable escape handling.
Replace awk model name derivation with sed chain to avoid mawk/gawk differences.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

### Task 2: Add path display — normal repo and worktree detection

**Files:**
- Modify: `.claude/commands/statusline.sh` (add path detection before output)
- Modify: `tests/statusline/test_statusline.sh` (add path tests, update all existing assertions)

- [ ] **Step 1: Write failing tests for path display**

Add to `tests/statusline/test_statusline.sh`, after the `assert_contains` helper and before the model name tests:

```bash
# --- Path display ---
echo "Path display:"

# Normal repo — just basename of CLAUDE_PROJECT_DIR
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "normal repo shows basename" "primer (" "$result"

# Worktree — project > worktree
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer/.claude/worktrees/feat+my-feature" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "worktree shows project > worktree" "primer > feat+my-feature (" "$result"
```

- [ ] **Step 2: Run tests to verify path tests fail**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: FAIL — path tests fail (script doesn't output path yet)

- [ ] **Step 3: Implement path display**

In `.claude/commands/statusline.sh`, add after `input=$(cat)` and before the model parsing:

```bash
# Path display — detect worktree vs normal repo
toplevel="${GIT_TOPLEVEL:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
project_dir="${CLAUDE_PROJECT_DIR:-$toplevel}"
project_base=$(basename "$project_dir")
current_base=$(basename "$toplevel")

if [ "$toplevel" = "$project_dir" ]; then
  path_display="$project_base"
else
  path_display="$project_base > $current_base"
fi
```

And update the final `printf` to prepend the path:

```bash
printf '%b\n' "${path_display} (${branch_info}) | ${model_name} | ${ctx_display} | ${cost_fmt}"
```

Note: `branch_info` doesn't exist yet — use a placeholder for now. Add a temporary line before the printf:

```bash
branch_info=$(git branch --show-current 2>/dev/null || echo "unknown")
```

- [ ] **Step 4: Update all existing test assertions to include path prefix**

Every existing test calls the script without `CLAUDE_PROJECT_DIR` or `GIT_TOPLEVEL` set. The script will derive path from actual `git rev-parse --show-toplevel`. To make tests deterministic, set `CLAUDE_PROJECT_DIR` and `GIT_TOPLEVEL` in all existing test invocations.

Update every `bash "$SCRIPT"` call in existing tests to use:
```bash
CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" bash "$SCRIPT"
```

Update the full output format assertion (last section) to include the path prefix:

```bash
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" bash "$SCRIPT" <<< '...' | sed 's/\x1b\[[0-9;]*m//g')
```

The full format check changes from:
```
"Opus 4.6 | 5% (50k) | \$1.50"
```
to matching the path prefix and branch segment too. Since branch comes from real git, strip the `path (branch) | ` prefix for model/context/cost assertions — or assert just the parts we care about. Existing assertions using `assert_contains` (substring match) still work as long as the old substrings remain in output.

- [ ] **Step 5: Run tests to verify all pass**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/statusline.sh tests/statusline/test_statusline.sh
git commit -m "feat(statusline): add path display with worktree detection

Show project basename in normal repos, 'project > worktree' in worktrees.
Path detected via GIT_TOPLEVEL vs CLAUDE_PROJECT_DIR comparison.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

### Task 3: Add git branch display

**Files:**
- Modify: `.claude/commands/statusline.sh` (replace temp branch line with proper branch detection)
- Modify: `tests/statusline/test_statusline.sh` (add branch tests)

- [ ] **Step 1: Write failing tests for branch display**

Add to `tests/statusline/test_statusline.sh`, after the path display section:

```bash
# --- Branch display ---
echo "Branch display:"

# Branch name from GIT_BRANCH override
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "shows branch name" "(main)" "$result"

# Feature branch
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="feat/my-feature" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "shows feature branch" "(feat/my-feature)" "$result"

# Detached HEAD — GIT_BRANCH empty, GIT_SHA provided
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="" GIT_SHA="abc1234" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "detached HEAD shows short SHA" "(abc1234)" "$result"
```

- [ ] **Step 2: Run tests to verify branch tests fail**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: FAIL — branch tests fail (script doesn't read GIT_BRANCH)

- [ ] **Step 3: Implement branch display**

In `.claude/commands/statusline.sh`, replace the temporary branch line with:

```bash
# Git branch — current branch or short SHA for detached HEAD
branch="${GIT_BRANCH:-$(git branch --show-current 2>/dev/null)}"
if [ -z "$branch" ]; then
  branch="${GIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"
fi
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/statusline.sh tests/statusline/test_statusline.sh
git commit -m "feat(statusline): add git branch display

Show current branch name or short SHA on detached HEAD.
Supports GIT_BRANCH/GIT_SHA env overrides for testing.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

### Task 4: Add git status indicators (dirty, untracked)

**Files:**
- Modify: `.claude/commands/statusline.sh` (add dirty/untracked detection)
- Modify: `tests/statusline/test_statusline.sh` (add indicator tests)

- [ ] **Step 1: Write failing tests for dirty and untracked indicators**

Add to `tests/statusline/test_statusline.sh`, after the branch display section:

```bash
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
```

- [ ] **Step 2: Run tests to verify indicator tests fail**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: FAIL — indicator tests fail

- [ ] **Step 3: Implement dirty and untracked detection**

In `.claude/commands/statusline.sh`, after the branch detection, add:

```bash
# Git status indicators
dirty=""
if [ -n "${GIT_DIRTY:-$(git diff --quiet HEAD 2>/dev/null || echo 1)}" ]; then
  dirty="*"
fi

untracked=""
if [ -n "${GIT_UNTRACKED:-$(git ls-files --others --exclude-standard 2>/dev/null | head -1)}" ]; then
  untracked="!"
fi

indicators="${dirty}${untracked}"
```

Update the branch_info assembly to include indicators:

```bash
if [ -n "$indicators" ]; then
  branch_info="${branch} ${indicators}"
else
  branch_info="${branch}"
fi
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/statusline.sh tests/statusline/test_statusline.sh
git commit -m "feat(statusline): add dirty and untracked indicators

Show * for uncommitted changes, ! for untracked files.
Supports GIT_DIRTY/GIT_UNTRACKED env overrides for testing.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

### Task 5: Add ahead/behind indicators

**Files:**
- Modify: `.claude/commands/statusline.sh` (add ahead/behind detection)
- Modify: `tests/statusline/test_statusline.sh` (add ahead/behind tests)

- [ ] **Step 1: Write failing tests for ahead/behind indicators**

Add to `tests/statusline/test_statusline.sh`, continuing the git status indicators section:

```bash
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

# No upstream — no arrows (GIT_AHEAD and GIT_BEHIND not set, no real upstream)
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":0,"context_window_size":200000},"cost":{"total_cost_usd":0}}')
assert_contains "no upstream shows clean branch" "(main)" "$result"
```

- [ ] **Step 2: Run tests to verify ahead/behind tests fail**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: FAIL — ahead/behind tests fail

- [ ] **Step 3: Implement ahead/behind detection**

In `.claude/commands/statusline.sh`, after the dirty/untracked detection, add:

```bash
ahead=""
behind=""
if [ -z "${GIT_NO_UPSTREAM:-}" ]; then
  if [ -n "${GIT_AHEAD:-}" ] || [ -n "${GIT_BEHIND:-}" ]; then
    ahead="${GIT_AHEAD:-}"
    behind="${GIT_BEHIND:-}"
  else
    upstream_counts=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null || echo "")
    if [ -n "$upstream_counts" ]; then
      behind=$(echo "$upstream_counts" | cut -f1)
      ahead=$(echo "$upstream_counts" | cut -f2)
    fi
  fi
fi

ahead_str=""
behind_str=""
[ -n "$ahead" ] && [ "$ahead" != "0" ] && ahead_str="↑${ahead}"
[ -n "$behind" ] && [ "$behind" != "0" ] && behind_str="↓${behind}"
```

Update the branch_info assembly to include all indicators:

```bash
# Assemble branch info: branch [*!] [↑N] [↓N]
branch_info="${branch}"
[ -n "$indicators" ] && branch_info="${branch_info} ${indicators}"
[ -n "$ahead_str" ] && branch_info="${branch_info} ${ahead_str}"
[ -n "$behind_str" ] && branch_info="${branch_info} ${behind_str}"
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/statusline.sh tests/statusline/test_statusline.sh
git commit -m "feat(statusline): add ahead/behind remote indicators

Show ↑N for commits ahead, ↓N for commits behind remote.
Omitted when no upstream or count is zero.
Supports GIT_AHEAD/GIT_BEHIND/GIT_NO_UPSTREAM env overrides for testing.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

### Task 6: Update full output format test and final integration

**Files:**
- Modify: `tests/statusline/test_statusline.sh` (update full format assertion)

- [ ] **Step 1: Update the full output format test**

Replace the existing "Full output format" section at the bottom of the test file with:

```bash
# --- Full output format ---
echo "Full output format:"

# Strip ANSI codes for format check
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer" GIT_BRANCH="main" GIT_DIRTY="" GIT_UNTRACKED="" GIT_AHEAD="" GIT_BEHIND="" GIT_NO_UPSTREAM="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-opus-4-6"},"context_window":{"used_percentage":5,"context_window_size":1000000},"cost":{"total_cost_usd":1.5}}' | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format: path (branch) | model | context | cost" "primer (main) | Opus 4.6 | 5% (50k) | \$1.50" "$result"

# Full format with worktree and all indicators
result=$(CLAUDE_PROJECT_DIR="/workspaces/primer" GIT_TOPLEVEL="/workspaces/primer/.claude/worktrees/feat+thing" GIT_BRANCH="feat/thing" GIT_DIRTY="1" GIT_UNTRACKED="1" GIT_AHEAD="2" GIT_BEHIND="1" bash "$SCRIPT" <<< '{"model":{"id":"claude-sonnet-4-6"},"context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0.75}}' | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "full format with worktree and indicators" "primer > feat+thing (feat/thing *! ↑2 ↓1) | Sonnet 4.6 | 10% (100k) | \$0.75" "$result"
```

- [ ] **Step 2: Run full test suite**

Run: `cd /workspaces/primer/.claude/worktrees/feat+statusline-path-branch && bash tests/statusline/test_statusline.sh`
Expected: PASS (all tests pass)

- [ ] **Step 3: Commit**

```bash
git add tests/statusline/test_statusline.sh
git commit -m "test(statusline): update full output format assertions

Integration tests verify complete output with path, branch, indicators,
model, context, and cost segments.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```
