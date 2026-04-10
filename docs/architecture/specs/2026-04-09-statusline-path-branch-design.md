# Statusline Path + Branch Design Spec

## Problem

Statusline shows model, context, and cost — but not where Claude is working or what branch it's on. When working in worktrees across repos, there's no at-a-glance orientation. Additionally, the script has portability bugs: `echo -e` and awk behavior differs across systems, producing garbled output like `Opus 4 6[1m]`.

## Solution

Extend `statusline.sh` to prepend a path + git branch segment, and fix portability issues.

### Output Format

```
primer (main) | Opus 4.6 | 5% (50k) | $0.50
primer (main *!) | Opus 4.6 | 5% (50k) | $0.50
primer (main ↑2 ↓1) | Opus 4.6 | 5% (50k) | $0.50
primer > my-feature (feat/thing *! ↑2 ↓1) | Opus 4.6 | 5% (50k) | $0.50
```

## Feature 1: Path Display

**Detection:** Compare `git rev-parse --show-toplevel` with `$CLAUDE_PROJECT_DIR` (or parent of `.claude/worktrees/`).

- **Normal repo:** `basename` of current directory → `primer`
- **Worktree:** `project-basename > worktree-basename` → `primer > my-feature`

**Logic:**
```bash
toplevel=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
project_base=$(basename "$CLAUDE_PROJECT_DIR")
current_base=$(basename "$toplevel")

if [ "$toplevel" = "$CLAUDE_PROJECT_DIR" ]; then
  path_display="$project_base"
else
  path_display="$project_base > $current_base"
fi
```

## Feature 2: Git Branch + Status Indicators

**Branch:** `git branch --show-current` — empty on detached HEAD, fall back to short SHA via `git rev-parse --short HEAD`.

**Indicators (each omitted when clean/zero):**
| Indicator | Meaning | Command |
|-----------|---------|---------|
| `*` | Dirty (uncommitted changes) | `git diff --quiet HEAD 2>/dev/null` (exit code) |
| `!` | Untracked files | `git ls-files --others --exclude-standard` (any output) |
| `↑N` | Commits ahead of remote | `git rev-list --left-right --count @{u}...HEAD` |
| `↓N` | Commits behind remote | Same command, second column |

**Format:** `(branch *! ↑2 ↓1)` — space-separated, indicators only when present. Parentheses always wrap the branch info.

**Edge cases:**
- No upstream tracking: skip `↑N`/`↓N` entirely
- Detached HEAD: show short SHA instead of branch name
- Not a git repo: skip entire branch segment, show path only

## Feature 3: Portability Fixes

### `echo -e` → `printf '%b\n'`

`echo -e` is not portable — some shells print literal `-e`. `printf '%b\n'` is POSIX-compliant for interpreting backslash escapes.

**Before:** `echo -e "${model_name} | ${ctx_display} | ${cost_fmt}"`
**After:** `printf '%b\n' "${path_branch} | ${model_name} | ${ctx_display} | ${cost_fmt}"`

### Model name parsing: awk → sed

Current awk block fails on `mawk` (common on Debian/Ubuntu). Replace with sed chain:

```bash
model_name=$(echo "$model_id" \
  | sed -E 's/^claude-//; s/-[0-9]{8,}$//' \
  | sed -E 's/-([0-9]+)-([0-9]+)/\n\1.\2/' \
  | sed -E '1s/-/ /g; 1s/\b([a-z])/\u\1/g' \
  | tr -d '\n')
```

This handles: `claude-opus-4-6` → `Opus 4.6`, `claude-haiku-4-5-20251001` → `Haiku 4.5`.

## Testing

### New Tests

- **Path display:** Normal repo basename, worktree `project > worktree` format
- **Branch name:** Current branch, detached HEAD fallback
- **Git indicators:** Each indicator individually and combined
- **No upstream:** Ahead/behind omitted gracefully
- **Portability:** `printf` output matches expected (no literal escape codes)

### Updated Tests

All existing tests need updated expected output — new path+branch segment prepended to every assertion.

### Test Strategy

- Git status tests use temp repos created in test setup
- Path/worktree tests mock `CLAUDE_PROJECT_DIR` and `git rev-parse` output
- Model/context/cost tests remain unit-style with JSON stdin

## Files Changed

| File | Change |
|------|--------|
| `.claude/commands/statusline.sh` | Add path+branch segment, fix `echo -e` → `printf`, fix model name parsing |
| `tests/statusline/test_statusline.sh` | Add path/branch/indicator tests, update existing assertions for new format |
