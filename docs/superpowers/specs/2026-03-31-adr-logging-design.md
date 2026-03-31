# Design: ADR Logging for Superpowers

## Problem

When Claude (or developers) make technology and implementation decisions during feature work, the reasoning behind those choices is lost. Six months later, nobody remembers why pyodbc was chosen over mssql-python, leading to repeated investigations and rabbit holes.

## Goals

- Capture the *why* behind implementation decisions (library choices, architectural patterns, design trade-offs)
- Prevent future sessions from re-investigating already-decided questions
- Enable cross-feature decision discovery via search

## Non-Goals

- Modifying superpowers skills
- Creating a new skill
- Maintaining a global decision index
- Logging trivial implementation details

## Approach

Use two project-controlled files — no skill modifications needed:

1. **`.claude/rules/adr.md`** — Reference doc defining ADR format, naming conventions, immutability rules. Loaded into context automatically as a rules file.
2. **`.claude/rules/superpowers.md`** — Add rules tying brainstorming and implementation to ADR logging.

### ADR Format

Each feature gets one ADR file in `docs/superpowers/adr/`, named `<date>-<feature-slug>-adr.md`. Decisions are appended as numbered entries:

```markdown
## ADR-NNN: <Title>

- **Date:** YYYY-MM-DD
- **Status:** accepted | superseded by ADR-NNN

### Context
What prompted the decision.

### Options Considered
- **Option A** — trade-offs
- **Option B** — trade-offs

### Decision
What was chosen and why.

### Consequences
What this means going forward.
```

### Key Conventions

- **Immutable:** Entries are never edited. Superseded decisions get a new entry referencing the old one.
- **Numbering:** Sequential within the feature file (ADR-001, ADR-002, ...). No global numbering.
- **Discovery:** No index file. Use `*-adr.md` naming convention and grep/search.
- **Trigger points:** Brainstorming (design decisions) and implementation (tactical decisions).
- **Threshold:** Only log choices between meaningful alternatives. If there were no alternatives considered, it's not worth an ADR entry.

### File Layout

```
docs/superpowers/
├── plans/
│   └── 2026-03-26-feature-name.md
├── specs/
│   └── 2026-03-26-feature-name-design.md
└── adr/
    └── 2026-03-26-feature-name-adr.md
```

### Rules to Add

**`.claude/rules/adr.md`** — format definition and behavioral rules:
- NEVER modify an existing ADR entry
- NEVER create an ADR file without the naming convention
- NEVER omit "Options Considered"
- NEVER log trivial implementation details

**`.claude/rules/superpowers.md`** — integration rules:
- NEVER finish brainstorming without logging design decisions to the feature's ADR file
- NEVER make an implementation decision between competing alternatives without logging it to the feature's ADR file

## Rejected Approaches

### Standalone ADR skill
Simple but opt-in — relies on remembering to invoke it. Decisions would be missed, defeating the purpose.

### ADR as a rule only (no reference doc)
Rules are too blunt to define the full format and conventions. A reference doc in rules gives both the behavioral triggers and the structural guidance.

### Global sequential numbering
Would cause conflicts between parallel sessions on different features. Per-feature numbering avoids this entirely.

### Generated index file
Added complexity with no clear benefit over grep/search. Can be added later if needed.
