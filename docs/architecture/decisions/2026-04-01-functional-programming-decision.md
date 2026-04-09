## ADR-001: Rule Strictness Level

- **Date:** 2026-04-01
- **Status:** accepted

### Context
Deciding how strict the functional programming rule should be — hard ban on all OOP, strong preference with escape hatch, or soft guideline.

### Options Considered
- **Hard ban** — NEVER use classes/mutation/inheritance under any circumstances. Maximum discipline but fights framework requirements (Python dataclass, ORMs, test fixtures).
- **Strong preference with escape hatch** — NEVER use OOP patterns as first choice, but allow thin class wrappers when a framework demands it. 95% FP discipline without unwinnable battles.
- **Soft guideline** — Prefer FP when convenient. Too weak to change behavior meaningfully.

### Decision
Strong preference with escape hatch. Framework-required classes are allowed only as thin wrappers with all logic extracted into pure functions.

### Consequences
Code will be overwhelmingly functional. Rare framework-mandated classes will exist but won't contain business logic.

## ADR-002: Rule File Structure

- **Date:** 2026-04-01
- **Status:** accepted

### Context
Deciding how to organize the FP rules within the rule file.

### Options Considered
- **Single broad rule** — One file with a few NEVER statements. Simple but may be too vague.
- **Categorized rules** — Group by concern (data, control flow, architecture). More granular but heavy for a single concept.
- **Layered rules** — Focused set of NEVER rules covering key FP principles, plus one explicit escape hatch. Strict yet pragmatic in one file.

### Decision
Layered rules in a single file. Each rule targets a specific OOP pattern to avoid, phrased as NEVER per rule-style.md conventions.

### Consequences
One concise file covers all FP concerns. Easy to scan and maintain, consistent with other rule files in the repo.
