# Skill Orchestration Fixes — Decision

**Date:** 2026-04-10

## Context

Four issues surfaced during real-world sync sessions: setup→sync handoff requiring re-invocation, prep scripts getting auto-backgrounded by the harness, no recovery guidance for backgrounded commands, and redundant API calls on retry. Needed to decide how much to fix in skill instructions vs. scripts.

## Options Considered

### A. Skill-only fixes (rejected)

All fixes in SKILL.md instructions only — auto-resume note, timeout guidance, troubleshooting section, and instruction to reuse cached temp file.

- **Pro:** Fastest to implement, no script testing needed.
- **Con:** Caching is agent-discipline-dependent — agent must remember to check temp file. Fragile.

### B. Skill + script changes (chosen)

Same skill fixes as A, plus TTL-based caching in prep scripts themselves. Cache keyed by tenant context to prevent cross-tenant collisions.

- **Pro:** Robust caching regardless of agent behavior. Small script change. Testable.
- **Con:** Requires TDD cycle for script changes and test updates.

### C. Skill + script + setup skill chaining (rejected)

Everything from B, plus a formal "caller context" mechanism where setup outputs a structured "next action" hint for sync to read.

- **Pro:** Most robust handoff mechanism.
- **Con:** Over-engineered — skills don't have shared state, so the hint is just a temp file convention. A simple instruction in sync SKILL.md achieves the same result.

## Decision

**Approach B.** Skill instructions handle issues 1-3 cleanly. Script-side caching (issue 4) is worth the small additional effort — deterministic behavior regardless of agent discipline. Setup→sync handoff solved with instruction, not infrastructure.

Additionally: developer e2e verification checklist (not user-facing) for validating changes against a real Qlik Cloud tenant.
