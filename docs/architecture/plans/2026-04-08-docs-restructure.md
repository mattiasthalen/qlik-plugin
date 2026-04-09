# Documentation Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all architectural documentation under `docs/architecture/{plans,specs,decisions}/` and restore previously deleted docs.

**Architecture:** Restore old docs from git history (commit `164bb32~1`), move current docs from `docs/plans/` and `docs/decisions/`, rename ADR files to decision convention, update AGENTS.md paths.

**Tech Stack:** Git, shell commands

---

### Task 1: Restore old plans from git history

**Files:**
- Create: `docs/architecture/plans/2026-03-27-extract-rules-from-claude-md.md`
- Create: `docs/architecture/plans/2026-03-31-adr-logging.md`
- Create: `docs/architecture/plans/2026-04-01-functional-programming.md`
- Create: `docs/architecture/plans/2026-04-01-plugin-repackaging.md`
- Create: `docs/architecture/plans/2026-04-02-session-confirmation.md`
- Create: `docs/architecture/plans/2026-04-07-sandbox-improvements.md`
- Create: `docs/architecture/plans/2026-04-07-template-repo.md`

- [ ] **Step 1: Restore plan files from git history into new location**

```bash
mkdir -p docs/architecture/plans
git show 164bb32~1:docs/superpowers/plans/2026-03-27-extract-rules-from-claude-md.md > docs/architecture/plans/2026-03-27-extract-rules-from-claude-md.md
git show 164bb32~1:docs/superpowers/plans/2026-03-31-adr-logging.md > docs/architecture/plans/2026-03-31-adr-logging.md
git show 164bb32~1:docs/superpowers/plans/2026-04-01-functional-programming.md > docs/architecture/plans/2026-04-01-functional-programming.md
git show 164bb32~1:docs/superpowers/plans/2026-04-01-plugin-repackaging.md > docs/architecture/plans/2026-04-01-plugin-repackaging.md
git show 164bb32~1:docs/superpowers/plans/2026-04-02-session-confirmation.md > docs/architecture/plans/2026-04-02-session-confirmation.md
git show 164bb32~1:docs/superpowers/plans/2026-04-07-sandbox-improvements.md > docs/architecture/plans/2026-04-07-sandbox-improvements.md
git show 164bb32~1:docs/superpowers/plans/2026-04-07-template-repo.md > docs/architecture/plans/2026-04-07-template-repo.md
```

- [ ] **Step 2: Verify files restored**

```bash
ls docs/architecture/plans/
```

Expected: 7 plan files listed.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/plans/
git commit -m "docs(architecture): restore old plans from git history"
git push
```

---

### Task 2: Restore old specs from git history

**Files:**
- Create: `docs/architecture/specs/2026-03-27-extract-rules-from-claude-md-design.md`
- Create: `docs/architecture/specs/2026-03-31-adr-logging-design.md`
- Create: `docs/architecture/specs/2026-04-01-functional-programming-design.md`
- Create: `docs/architecture/specs/2026-04-01-plugin-repackaging-design.md`
- Create: `docs/architecture/specs/2026-04-02-session-confirmation-design.md`
- Create: `docs/architecture/specs/2026-04-07-sandbox-improvements-design.md`
- Create: `docs/architecture/specs/2026-04-07-template-repo-design.md`

- [ ] **Step 1: Restore spec files from git history into new location**

```bash
git show 164bb32~1:docs/superpowers/specs/2026-03-27-extract-rules-from-claude-md-design.md > docs/architecture/specs/2026-03-27-extract-rules-from-claude-md-design.md
git show 164bb32~1:docs/superpowers/specs/2026-03-31-adr-logging-design.md > docs/architecture/specs/2026-03-31-adr-logging-design.md
git show 164bb32~1:docs/superpowers/specs/2026-04-01-functional-programming-design.md > docs/architecture/specs/2026-04-01-functional-programming-design.md
git show 164bb32~1:docs/superpowers/specs/2026-04-01-plugin-repackaging-design.md > docs/architecture/specs/2026-04-01-plugin-repackaging-design.md
git show 164bb32~1:docs/superpowers/specs/2026-04-02-session-confirmation-design.md > docs/architecture/specs/2026-04-02-session-confirmation-design.md
git show 164bb32~1:docs/superpowers/specs/2026-04-07-sandbox-improvements-design.md > docs/architecture/specs/2026-04-07-sandbox-improvements-design.md
git show 164bb32~1:docs/superpowers/specs/2026-04-07-template-repo-design.md > docs/architecture/specs/2026-04-07-template-repo-design.md
```

- [ ] **Step 2: Verify files restored**

```bash
ls docs/architecture/specs/
```

Expected: 7 spec files plus the already-committed `2026-04-08-docs-restructure-design.md` (8 total).

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/specs/
git commit -m "docs(architecture): restore old specs from git history"
git push
```

---

### Task 3: Restore old decisions from git history (renamed from ADR)

**Files:**
- Create: `docs/architecture/decisions/2026-04-01-functional-programming-decision.md`
- Create: `docs/architecture/decisions/2026-04-01-plugin-repackaging-decision.md`
- Create: `docs/architecture/decisions/2026-04-07-sandbox-improvements-decision.md`
- Create: `docs/architecture/decisions/2026-04-07-template-repo-decision.md`

- [ ] **Step 1: Restore ADR files from git history, renamed to decision convention**

```bash
mkdir -p docs/architecture/decisions
git show 164bb32~1:docs/superpowers/adr/2026-04-01-functional-programming-adr.md > docs/architecture/decisions/2026-04-01-functional-programming-decision.md
git show 164bb32~1:docs/superpowers/adr/2026-04-01-plugin-repackaging-adr.md > docs/architecture/decisions/2026-04-01-plugin-repackaging-decision.md
git show 164bb32~1:docs/superpowers/adr/2026-04-07-sandbox-improvements-adr.md > docs/architecture/decisions/2026-04-07-sandbox-improvements-decision.md
git show 164bb32~1:docs/superpowers/adr/2026-04-07-template-repo-adr.md > docs/architecture/decisions/2026-04-07-template-repo-decision.md
```

- [ ] **Step 2: Verify files restored with correct names**

```bash
ls docs/architecture/decisions/
```

Expected: 4 files, all ending in `-decision.md`.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/decisions/
git commit -m "docs(architecture): restore old decisions from git history"
git push
```

---

### Task 4: Move current docs into new structure

**Files:**
- Move: `docs/plans/2026-04-08-plugins-plan.md` -> `docs/architecture/plans/2026-04-08-plugins-plan.md`
- Move: `docs/decisions/2026-04-08-plugins-setup-decision.md` -> `docs/architecture/decisions/2026-04-08-plugins-setup-decision.md`
- Delete: `docs/plans/`
- Delete: `docs/decisions/`

- [ ] **Step 1: Move current plan and decision files**

```bash
mv docs/plans/2026-04-08-plugins-plan.md docs/architecture/plans/
mv docs/decisions/2026-04-08-plugins-setup-decision.md docs/architecture/decisions/
```

- [ ] **Step 2: Remove old empty directories**

```bash
rm -rf docs/plans docs/decisions
```

- [ ] **Step 3: Verify final structure**

```bash
ls -R docs/
```

Expected:
```
docs/architecture/decisions/ — 5 files
docs/architecture/plans/ — 8 files
docs/architecture/specs/ — 8 files
```

- [ ] **Step 4: Commit**

```bash
git add -A docs/
git commit -m "docs(architecture): move current docs into new structure"
git push
```

---

### Task 5: Update AGENTS.md paths

**Files:**
- Modify: `AGENTS.md:6-9`

- [ ] **Step 1: Update AGENTS.md**

Replace lines 6-9:

```markdown
- ALWAYS save plans as YYYY-MM-DD-feature-slug-plan.md in /docs/plans/.
- ALWAYS commit and push the plan before starting any implementation work.
- ALWAYS save decisions as YYYY-MM-DD-feature-slug-decision.md in /docs/decisions/ when choosing between alternatives, including what was chosen, what was rejected, and why.
- ALWAYS capture decisions before implementing the chosen approach — if you picked one option over another, write the decision file first.
```

With:

```markdown
- ALWAYS save plans as YYYY-MM-DD-feature-slug.md in /docs/architecture/plans/.
- ALWAYS save design specs as YYYY-MM-DD-feature-slug-design.md in /docs/architecture/specs/.
- ALWAYS commit and push the plan before starting any implementation work.
- ALWAYS save decisions as YYYY-MM-DD-feature-slug-decision.md in /docs/architecture/decisions/ when choosing between alternatives, including what was chosen, what was rejected, and why.
- ALWAYS capture decisions before implementing the chosen approach — if you picked one option over another, write the decision file first.
```

- [ ] **Step 2: Verify AGENTS.md**

```bash
cat AGENTS.md
```

Expected: paths point to `docs/architecture/plans/`, `docs/architecture/specs/`, and `docs/architecture/decisions/`.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): align paths to docs/architecture/"
git push
```
