#!/bin/bash
set -euo pipefail
input=$(cat)

model_id=$(echo "$input" | jq -r '.model.id')

# Derive display name from model ID
# claude-opus-4-6 → Opus 4.6
# claude-sonnet-4-6 → Sonnet 4.6
# claude-haiku-4-5-20251001 → Haiku 4.5
model_name=$(echo "$model_id" | sed -E 's/^claude-//; s/-[0-9]{8,}$//; s/-/ /g' | awk '{
  in_version=0
  for (i=1; i<=NF; i++) {
    if ($i ~ /^[0-9]+$/) {
      if (in_version == 0) {
        printf " %s", $i
        in_version=1
      } else {
        printf ".%s", $i
      }
    } else {
      if (i == 1) {
        printf "%s%s", toupper(substr($i,1,1)), substr($i,2)
      } else {
        printf " %s%s", toupper(substr($i,1,1)), substr($i,2)
      }
      in_version=0
    }
  }
  print ""
}')

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

echo -e "${model_name} | ${ctx_display} | ${cost_fmt}"
