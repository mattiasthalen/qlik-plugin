# Design: uv Devcontainer Feature & Git Identity from GitHub

**Date:** 2026-04-08
**Status:** Draft

## Summary

Two small devcontainer improvements:

1. Add uv (Astral's Python package manager/tool runner) as a commented-out devcontainer feature in the Tools section.
2. Set git `user.name` and `user.email` in `setup-git.sh` by pulling identity from the authenticated GitHub account.

## Change 1: devcontainer.json — Add uv Feature

Add Astral's official uv devcontainer feature to the **Tools** section, commented out (same opt-in pattern as other language features).

```jsonc
// --- Tools ---
"ghcr.io/devcontainers/features/node:1": {},
"ghcr.io/guiyomh/features/just:0": {},
"ghcr.io/iyaki/devcontainer-features/lefthook:2": {},
"ghcr.io/devcontainers-community/features/direnv": {},
// "ghcr.io/astral-sh/devcontainer-features/uv:1": {},
```

- **Feature source:** `ghcr.io/astral-sh/devcontainer-features/uv:1`
- **Default config:** empty `{}` — latest stable, no version pin
- **Purpose:** Python project management (venvs, deps, scripts) and tool installation (`uv tool install`)

## Change 2: setup-git.sh — Git Identity from GitHub

After `gh auth login` and before SSH signing key generation, pull user identity from the GitHub API:

```bash
# Set git identity from GitHub
GH_USER=$(gh api user --jq '.name')
GH_EMAIL=$(gh api user --jq '.email')
git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"
```

This fixes a gap where `ssh-keygen` already references `git config --global user.email` but nothing sets it. Placing it after auth (needs token) and before keygen (needs email).

## Files Changed

- `.devcontainer/devcontainer.json` — add commented-out uv feature line in Tools section
- `scripts/setup-git.sh` — add git identity block after auth, before signing key setup

## Decision

Chose minimal approach (Approach 1) over enhanced setup script integration or full direnv toolchain. Reasoning: no Python code exists yet, so automation beyond the feature itself is premature. See decision doc for details.
