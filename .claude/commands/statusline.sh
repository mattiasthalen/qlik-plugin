#!/bin/bash
set -euo pipefail
input=$(cat)

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

model_id=$(echo "$input" | jq -r '.model.id')

# Derive display name from model ID
# claude-opus-4-6 → Opus 4.6
# claude-sonnet-4-6 → Sonnet 4.6
# claude-haiku-4-5-20251001 → Haiku 4.5
model_name=$(echo "$model_id" \
  | sed -E 's/\[.*\]$//' \
  | sed -E 's/^claude-//' \
  | sed -E 's/-[0-9]{8,}$//' \
  | sed -E 's/-([0-9]+)-([0-9]+)$/ \1.\2/' \
  | sed -E 's/^(.)/\u\1/')

pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

used_tokens=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) * (.context_window.context_window_size // 200000) / 100 | round')
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

# Git branch — current branch or short SHA for detached HEAD
# Use GIT_BRANCH if set in env (even empty), otherwise ask git
if [ -n "${GIT_BRANCH+isset}" ]; then
  branch="$GIT_BRANCH"
else
  branch="$(git branch --show-current 2>/dev/null || true)"
fi
if [ -z "$branch" ]; then
  branch="${GIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"
fi

# Git status indicators — use ${VAR+isset} to distinguish empty (clean) from unset (run git)
dirty=""
if [ -n "${GIT_DIRTY+isset}" ]; then
  [ -n "$GIT_DIRTY" ] && dirty="*"
else
  git diff --quiet HEAD 2>/dev/null || dirty="*"
fi

untracked=""
if [ -n "${GIT_UNTRACKED+isset}" ]; then
  [ -n "$GIT_UNTRACKED" ] && untracked="!"
else
  [ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)" ] && untracked="!"
fi

indicators="${dirty}${untracked}"

# Ahead/behind remote — use ${VAR+isset} to distinguish empty (no ahead/behind) from unset (run git)
ahead=""
behind=""
if [ -z "${GIT_NO_UPSTREAM:-}" ]; then
  if [ -n "${GIT_AHEAD+isset}" ] || [ -n "${GIT_BEHIND+isset}" ]; then
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

# Assemble branch info: branch [*!] [↑N] [↓N]
branch_info="${branch}"
[ -n "$indicators" ] && branch_info="${branch_info} ${indicators}"
[ -n "$ahead_str" ] && branch_info="${branch_info} ${ahead_str}"
[ -n "$behind_str" ] && branch_info="${branch_info} ${behind_str}"

printf '%b\n' "${path_display} (${branch_info}) | ${model_name} | ${ctx_display} | ${cost_fmt}"
