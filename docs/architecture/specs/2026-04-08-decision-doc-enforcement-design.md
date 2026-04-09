# Decision Doc Enforcement Design Spec

## Problem

AGENTS.md has two rules about decision docs (save decisions, capture before implementing) but agents skip them. Rules are too abstract — they say what to do but not when to trigger, what structure to use, or where in the commit sequence decisions belong.

## Solution

Replace the two existing decision rules in AGENTS.md with three specific rules covering: file-per-feature accumulation, entry trigger and structure, and commit ordering.

## Changes

**File:** `AGENTS.md`

**Remove:**
```
- ALWAYS save decisions as YYYY-MM-DD-feature-slug-decision.md in /docs/architecture/decisions/ when choosing between alternatives, including what was chosen, what was rejected, and why.
- ALWAYS capture decisions before implementing the chosen approach — if you picked one option over another, write the decision file first.
```

**Replace with:**
```
- ALWAYS write decisions to a single YYYY-MM-DD-feature-slug-decision.md in /docs/architecture/decisions/ — one file per feature, accumulating all decisions for that slug.
- ALWAYS add a decision entry when brainstorming produces 2+ approaches, structured as: Context (why the decision arose), Options considered (each with trade-offs, marked chosen/rejected), and Decision (what was chosen and why).
- ALWAYS commit and push the decision doc before writing the spec or plan for that feature.
```

## Rationale

- Three rules instead of two: separates file strategy, entry trigger/structure, and commit ordering.
- One file per feature accumulates all decisions rather than scattering across files.
- Explicit trigger (2+ approaches from brainstorming) makes it clear when a decision doc is needed.
- Structure matches existing decision doc format already used in the repo.
- Commit ordering (decision → spec → plan → impl) creates natural checkpoints.
- All rules use positive guidance per AGENTS.md convention.
