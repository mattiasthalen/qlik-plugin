# Documentation Restructure Design

## Goal

Consolidate all architectural documentation under `docs/architecture/` with three subdirectories: `plans/`, `specs/`, and `decisions/`. Restore previously deleted documentation and align AGENTS.md with the new paths.

## Context

The superpowers plugin defaults to `docs/superpowers/{plans,specs,adr}/` but notes that user preferences override this. The project previously stored docs there but they were bulk-deleted in commit `164bb32`. Current docs live in `docs/plans/` and `docs/decisions/`.

- `superpowers` is too plugin-specific for a folder name
- `docs/` alone is too generic and flat
- `docs/architecture/` accurately describes what these documents are: architectural artifacts

## Structure

```
docs/
  architecture/
    plans/         YYYY-MM-DD-slug.md
    specs/         YYYY-MM-DD-slug-design.md
    decisions/     YYYY-MM-DD-slug-decision.md
```

## Changes

### 1. Restore old documentation from git history

Restore all files from before commit `164bb32` (the bulk deletion):

- **7 plans** from `docs/superpowers/plans/` -> `docs/architecture/plans/`
- **7 specs** from `docs/superpowers/specs/` -> `docs/architecture/specs/`
- **4 ADRs** from `docs/superpowers/adr/` -> `docs/architecture/decisions/`, renamed from `*-adr.md` to `*-decision.md`

### 2. Move current documentation

- `docs/plans/2026-04-08-plugins-plan.md` -> `docs/architecture/plans/`
- `docs/decisions/2026-04-08-plugins-setup-decision.md` -> `docs/architecture/decisions/`

### 3. Remove old directories

- Remove `docs/plans/`
- Remove `docs/decisions/`

### 4. Update AGENTS.md

Align all path references:

- Plans: `docs/architecture/plans/`
- Specs: `docs/architecture/specs/`
- Decisions: `docs/architecture/decisions/`

Add a line for design specs (previously missing from AGENTS.md).

## File Renames (ADR -> Decision)

| Old name | New name |
|----------|----------|
| `2026-04-01-functional-programming-adr.md` | `2026-04-01-functional-programming-decision.md` |
| `2026-04-01-plugin-repackaging-adr.md` | `2026-04-01-plugin-repackaging-decision.md` |
| `2026-04-07-sandbox-improvements-adr.md` | `2026-04-07-sandbox-improvements-decision.md` |
| `2026-04-07-template-repo-adr.md` | `2026-04-07-template-repo-decision.md` |
