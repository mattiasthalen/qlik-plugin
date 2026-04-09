# Extract Rules from CLAUDE.md Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move all rules from CLAUDE.md into topic-specific files under `.claude/rules/` and empty CLAUDE.md.

**Architecture:** Create 4 new rule files mirroring the current CLAUDE.md sections. Each file gets a heading and the NEVER-phrased bullet list. CLAUDE.md is emptied.

**Tech Stack:** Markdown files, git, gh CLI

---

### Task 1: Create rule-style.md

**Files:**
- Create: `.claude/rules/rule-style.md`

**Step 1: Create the rule file**

```markdown
# Rule Style

- NEVER write rules as "do X". Always phrase rules as "NEVER do Y" to clearly define what to avoid.
```

**Step 2: Commit**

```bash
git add .claude/rules/rule-style.md
git commit -m "docs: add rule-style rules file"
```

---

### Task 2: Create git-workflow.md

**Files:**
- Create: `.claude/rules/git-workflow.md`

**Step 1: Create the rule file**

```markdown
# Git Workflow

- NEVER commit directly to main.
- NEVER use non-conventional commit formats. See .claude/rules/conventional-commits.md
- NEVER leave commits unpushed.
- NEVER use raw git for remote operations when a CLI is available for the remote platform (e.g., `gh` for GitHub, `az repos` for Azure DevOps).
- NEVER rely on global git email. Before committing, check `git config --local user.email`. If not set, prompt the user.
- NEVER open PRs as ready. Always open as draft (e.g., `gh pr create --draft`).
- NEVER enable auto-merge on draft PRs. Enable auto-merge only after the PR is marked as ready (e.g., `gh pr ready` then `gh pr merge --auto --merge`).
- NEVER enable auto-merge on PRs from external contributors. Only repo admins/owners may use auto-merge.
- NEVER use squash or rebase merges. Always use regular merge commits (`--merge`).
```

**Step 2: Commit**

```bash
git add .claude/rules/git-workflow.md
git commit -m "docs: add git-workflow rules file"
```

---

### Task 3: Create repo-setup.md

**Files:**
- Create: `.claude/rules/repo-setup.md`

**Step 1: Create the rule file**

```markdown
# Repo Setup

- NEVER leave the default branch unprotected. Require PRs (no direct pushes) with at least one approving review. Admins may bypass.
- NEVER leave auto-merge disabled on a new repo.
- NEVER leave auto-delete of merged branches disabled on a new repo.
```

**Step 2: Commit**

```bash
git add .claude/rules/repo-setup.md
git commit -m "docs: add repo-setup rules file"
```

---

### Task 4: Create superpowers.md

**Files:**
- Create: `.claude/rules/superpowers.md`

**Step 1: Create the rule file**

```markdown
# Superpowers

- NEVER store plans and design specs in `docs/plans/`. Store plans in `docs/superpowers/plans/` and design specs in `docs/superpowers/specs/`.
- NEVER default plans to sequential execution. Optimize for parallelization.
- NEVER dispatch parallel subagents into the same worktree. Each subagent MUST work in its own isolated worktree (via `using-git-worktrees`).
- NEVER use `isolation: "worktree"` when the parent is on a non-main branch — it branches from main, not the parent branch. Create worktrees manually from the current branch (via `using-git-worktrees`) instead.
- NEVER write plans, specs, or implementation files before setting up an isolated worktree.
```

**Step 2: Commit**

```bash
git add .claude/rules/superpowers.md
git commit -m "docs: add superpowers rules file"
```

---

### Task 5: Empty CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Empty the file**

Replace all content with an empty file.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: move all rules to .claude/rules/ files"
```

---

**Note:** Tasks 1-4 are independent and can be parallelized. Task 5 depends on all of them completing first.
