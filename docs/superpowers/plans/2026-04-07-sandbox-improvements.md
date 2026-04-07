# Sandbox Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve primer template repo DX — safer justfile defaults, working git signing setup, and stale plugin cleanup.

**Architecture:** Three independent changes to existing files. No new modules or dependencies.

**Tech Stack:** Bash, just, Claude Code CLI

---

## File Map

- Modify: `justfile` — add default help recipe and claude recipe
- Modify: `scripts/setup-git.sh` — fix auth scope
- Modify: `~/.claude/settings.json` — remove stale primer marketplace entry (user-scope, not committed)

---

### Task 1: Justfile — default help and claude recipe

All three tasks are independent and can be executed in parallel.

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Update justfile**

Replace the entire `justfile` with:

```justfile
# Show available tasks
default:
    @just --list

# Run interactive GitHub auth + SSH signing setup
setup-git:
    ./scripts/setup-git.sh

# Launch Claude Code with all permissions
claude:
    claude --dangerously-skip-permissions

# Sync template from upstream
sync-template:
    ./scripts/sync-template.sh
```

- [ ] **Step 2: Verify `just` shows help**

Run: `just`

Expected output (approximately):
```
Available recipes:
    claude        # Launch Claude Code with all permissions
    setup-git     # Run interactive GitHub auth + SSH signing setup
    sync-template # Sync template from upstream
```

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "feat: add default help listing and claude recipe to justfile"
```

---

### Task 2: Fix git signing setup script

**Files:**
- Modify: `scripts/setup-git.sh:4` — replace `gh auth login` line

- [ ] **Step 1: Update setup-git.sh**

In `scripts/setup-git.sh`, replace line 4:

```bash
gh auth login
```

With:

```bash
gh auth login -h github.com -s admin:ssh_signing_key
```

The rest of the script remains unchanged.

- [ ] **Step 2: Verify script syntax**

Run: `bash -n scripts/setup-git.sh`

Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-git.sh
git commit -m "fix: request signing key scope during gh auth login"
```

---

### Task 3: Remove stale primer plugin reference

**Files:**
- Modify: `~/.claude/settings.json` — remove `primer` entry from `extraKnownMarketplaces`

**Note:** This is a user-scope file, not committed to the repo.

- [ ] **Step 1: Remove primer from extraKnownMarketplaces**

In `~/.claude/settings.json`, remove the `primer` entry from `extraKnownMarketplaces`:

```json
"primer": {
  "source": {
    "source": "github",
    "repo": "mattiasthalen/primer"
  },
  "autoUpdate": true
}
```

Keep the other entries (`daana-modeler`, `starship-claude`) intact.

- [ ] **Step 2: Verify JSON is valid**

Run: `python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))"`

Expected: no output (valid JSON)

- [ ] **Step 3: No commit**

This is a user-scope change — not part of the repo.
