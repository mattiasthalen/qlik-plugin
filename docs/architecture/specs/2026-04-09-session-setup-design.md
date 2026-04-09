# Session Setup Design Spec

## Problem

Each new session (and after `/clear`) requires manually invoking `/caveman:caveman` and `/superpowers:using-superpowers`. There is also no visibility into model, context usage, or spend during a session.

## Solution

Two changes:

1. **Auto-activate skills** — Add a CLAUDE.md rule that instructs Claude to invoke caveman and using-superpowers skills on session start and after `/clear`, before responding.
2. **Statusline** — A bash script at `.claude/commands/statusline.sh` that displays model, context usage, and spend. Referenced from `.claude/settings.json`.

## Feature 1: CLAUDE.md Skill Auto-Invocation

**File:** `CLAUDE.md`

**Add rule:**
```
- ALWAYS invoke /caveman:caveman and /superpowers:using-superpowers skills on session start and after /clear before responding to user.
```

This goes in the Agents section alongside existing "ALWAYS" rules.

**Why not hooks?** SessionStart hooks can only run shell commands — they cannot invoke slash commands or skills directly. A CLAUDE.md instruction is simpler and reliable.

## Feature 2: Statusline

### Script: `.claude/commands/statusline.sh`

**Input:** JSON via stdin from Claude Code containing session metadata.

**Output format:**
```
Opus 4.6 | 35% (70k) | $1.23     ← no color (under 80k)
Opus 4.6 | 45% (90k) | $1.23     ← amber context (80k–160k)
Opus 4.6 | 85% (170k) | $1.23    ← red context (above 160k)
```

**Fields used:**
- `model.id` — Parse to derive display name (e.g. `claude-opus-4-6` → `Opus 4.6`)
- `context_window.used_percentage` — True percentage of model's context window
- `context_window.context_window_size` — Total window size in tokens
- `cost.total_cost_usd` — Session spend in USD

**Model name derivation:**
- Extract from `model.id` (e.g. `claude-opus-4-6` → `Opus 4.6`, `claude-sonnet-4-6` → `Sonnet 4.6`, `claude-haiku-4-5-20251001` → `Haiku 4.5`)

**Absolute token calculation:**
- `used_tokens = context_window_size * used_percentage / 100`
- Display as `Xk` (divide by 1000, round to nearest integer)

**Color thresholds (absolute, applied only to context portion):**
- Below 80k tokens: no color (default terminal text)
- 80k–160k tokens: amber (`\033[33m`)
- Above 160k tokens: red (`\033[31m`)
- Reset after context portion (`\033[0m`)

**Rationale for absolute thresholds:** Context quality degrades around 200k tokens regardless of model window size. 80k (amber) and 160k (red) provide early warning before degradation begins.

### Settings: `.claude/settings.json`

**Add `statusLine` block:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "$CLAUDE_PROJECT_DIR/.claude/commands/statusline.sh",
    "refreshInterval": 10
  }
}
```

Merged into existing settings alongside `enabledPlugins` and `extraKnownMarketplaces`.

## Files Changed

| File | Change |
|------|--------|
| `CLAUDE.md` | Add skill auto-invocation rule |
| `.claude/settings.json` | Add `statusLine` config block |
| `.claude/commands/statusline.sh` | New file — statusline script |
