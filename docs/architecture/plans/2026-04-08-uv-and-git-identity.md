# uv & Git Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add commented-out uv devcontainer feature and set git identity from GitHub in setup-git.sh.

**Architecture:** Two independent edits — one to devcontainer.json (add feature line), one to setup-git.sh (add gh api calls). No new files.

**Tech Stack:** Devcontainer features, bash, gh CLI

---

### Task 1: Add uv devcontainer feature

**Files:**
- Modify: `.devcontainer/devcontainer.json:4-11` (Tools section)

**Spec:** [2026-04-08-uv-and-git-identity-design.md — Change 1](../specs/2026-04-08-uv-and-git-identity-design.md)

- [ ] **Step 1: Add commented-out uv feature line in Tools section**

Add after the direnv line (line 9), before the commented-out docker-in-docker line (line 10):

```jsonc
    // "ghcr.io/astral-sh/devcontainer-features/uv:1": {},
```

Result — Tools section should read:

```jsonc
    // --- Tools ---
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/guiyomh/features/just:0": {},
    "ghcr.io/iyaki/devcontainer-features/lefthook:2": {},
    "ghcr.io/devcontainers-community/features/direnv": {},
    // "ghcr.io/astral-sh/devcontainer-features/uv:1": {},
    // "ghcr.io/devcontainers/features/docker-in-docker:1": {},
```

- [ ] **Step 2: Verify JSON is valid**

Run: `cat .devcontainer/devcontainer.json`

Confirm: uv line present in Tools section, no syntax errors, commented-out lines intact.

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat(devcontainer): add commented-out uv feature in tools section"
git push
```

---

### Task 2: Set git identity from GitHub in setup-git.sh

**Files:**
- Modify: `scripts/setup-git.sh:1-13`

**Spec:** [2026-04-08-uv-and-git-identity-design.md — Change 2](../specs/2026-04-08-uv-and-git-identity-design.md)

- [ ] **Step 1: Add git identity block after auth, before signing key**

Insert after line 5 (`gh auth setup-git`) and before line 7 (`ssh-keygen`):

```bash
# Set git identity from GitHub
GH_USER=$(gh api user --jq '.name')
GH_EMAIL=$(gh api user --jq '.email')
git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"
```

Result — full script should read:

```bash
#!/bin/bash
set -e

gh auth login -h github.com -s admin:ssh_signing_key
gh auth setup-git

# Set git identity from GitHub
GH_USER=$(gh api user --jq '.name')
GH_EMAIL=$(gh api user --jq '.email')
git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"

ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f ~/.ssh/id_ed25519_signing
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true

echo "GitHub auth and commit signing configured"
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n scripts/setup-git.sh`

Expected: no output (clean parse).

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-git.sh
git commit -m "feat(git): set user name and email from GitHub account"
git push
```
