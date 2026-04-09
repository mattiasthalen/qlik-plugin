# Session Setup Decisions

## Decision 1: Skill Auto-Invocation Mechanism

**Context:** Need caveman and using-superpowers skills to fire automatically on session start and after `/clear`. SessionStart hooks can only run shell commands, not invoke slash commands.

**Options considered:**
- **A) SessionStart hook with additionalContext** — Hook outputs text instructing Claude to invoke skills. Mechanical but indirect; relies on Claude interpreting hook output as instruction. *Rejected.*
- **B) CLAUDE.md instruction** *(chosen)* — Add "ALWAYS invoke" rule to CLAUDE.md. Simple, reliable, already how CLAUDE.md drives agent behavior. No extra moving parts.
- **Combined A+B** — Belt and suspenders. Unnecessary complexity given CLAUDE.md reliability. *Rejected.*

**Decision:** CLAUDE.md instruction. Simpler, project-level, and consistent with existing rule patterns. Hooks add complexity without benefit since they can't directly invoke skills.

## Decision 2: Statusline Script Location

**Context:** Statusline needs color threshold logic (conditionals, math) that's too complex for an inline jq one-liner.

**Options considered:**
- **A) Inline jq in settings.json** — Compact but unreadable with threshold logic. *Rejected.*
- **B) External script in repo at `.claude/commands/statusline.sh`** *(chosen)* — Clean separation. Checked into git, travels with project, survives sandbox rebuilds.
- **C) External script in home dir (`~/.claude/`)** — Wiped on sandbox rebuild per CLAUDE.md ("home directory is wiped on rebuild"). *Rejected.*

**Decision:** `.claude/commands/statusline.sh` in repo. User specified this location. Survives rebuilds, portable, version-controlled.

## Decision 3: Context Color Thresholds — Absolute vs Percentage

**Context:** Context window varies by model (Haiku 200k, Opus/Sonnet 1M), but context quality degrades around 200k regardless of window size.

**Options considered:**
- **Percentage-based (e.g. 40%/80% of window)** — Simple but misleading on 1M models: 40% = 400k tokens, well past degradation point. *Rejected.*
- **Absolute token thresholds (80k/160k)** *(chosen)* — Amber at 80k, red at 160k. Maps to real degradation boundary (~200k) regardless of model. Percentage display still shows true % of model window.

**Decision:** Absolute thresholds. 80k amber, 160k red. Percentage shown is still true model %, but colors reflect actual quality degradation risk.
