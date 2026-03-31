# ADR Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add ADR logging rules so superpowers captures implementation decisions during brainstorming and development.

**Architecture:** Two new/modified rule files — one defining ADR format and conventions, one extending superpowers rules with ADR triggers.

**Tech Stack:** Markdown rule files only. No code, no tests.

---

### Task 1: Create ADR rules file

**Files:**
- Create: `.claude/rules/adr.md`

**Step 1: Create the ADR rules file**

```markdown
# Architecture Decision Records (ADR)

## Format

Each feature gets one ADR file in `docs/superpowers/adr/`, named `<date>-<feature-slug>-adr.md` (matching the spec/plan naming convention). Decisions are appended as numbered entries:

### Template

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

## Conventions

- Numbering is sequential within the feature file (ADR-001, ADR-002, ...). There is no global numbering.
- Discovery is convention-based: use the `*-adr.md` naming pattern and search. There is no index file.

## Rules

- NEVER modify an existing ADR entry. Append a new entry that supersedes it.
- NEVER create an ADR file without following the naming convention `<date>-<feature-slug>-adr.md`.
- NEVER omit "Options Considered" — if there were no alternatives, it is not a decision worth recording.
- NEVER log trivial implementation details (variable names, formatting). Only log choices between meaningful alternatives.
```

**Step 2: Commit**

```bash
git add .claude/rules/adr.md
git commit -m "docs: add ADR rules file defining format and conventions"
git push
```

---

### Task 2: Add ADR rules to superpowers rules

**Files:**
- Modify: `.claude/rules/superpowers.md` (append two rules after line 7)

**Step 1: Append ADR rules to superpowers.md**

Add these two lines at the end of the existing rules:

```markdown
- NEVER finish brainstorming without logging design decisions (approach chosen, alternatives rejected) to the feature's `*-adr.md` file in `docs/superpowers/adr/`.
- NEVER make an implementation decision between competing alternatives (libraries, patterns, architectures) without logging it to the feature's `*-adr.md` file in `docs/superpowers/adr/`.
```

**Step 2: Commit**

```bash
git add .claude/rules/superpowers.md
git commit -m "docs: add ADR logging rules to superpowers"
git push
```
