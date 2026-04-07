# Template Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform primer from a Claude Code plugin into a GitHub template repository with devcontainer sandboxing, opinionated Claude Code config, and a git-based sync mechanism.

**Architecture:** The repo becomes the template itself (no more `templates/` indirection). Projects scaffold via GitHub's "Use this template" button. Updates are pulled via `just sync-template` which uses git merge to preserve project-specific changes. A devcontainer provides a sandboxed environment with network firewall isolation adapted from Anthropic's reference.

**Tech Stack:** Bash (scripts), devcontainers, iptables/ipset (firewall), just (command runner), GitHub CLI

---

## File Structure

### Files to create

| File | Responsibility |
|------|---------------|
| `.devcontainer/devcontainer.json` | Devcontainer config: base image, features, sandboxing caps |
| `.devcontainer/init-firewall.sh` | Network firewall (adapted from `anthropics/claude-code`) |
| `scripts/setup-devcontainer.sh` | First-run: gh auth + SSH commit signing |
| `scripts/sync-template.sh` | Git merge-based template sync from upstream |
| `.claude/skills/lint-claude.md` | Auto-validates CLAUDE.md conventions |
| `justfile` | Command runner recipes (`sync-template`) |

### Files to rewrite

| File | Change |
|------|--------|
| `CLAUDE.md` | Rewrite from plugin description to DON'T/DO guardrails |
| `README.md` | Rewrite for template repo usage |
| `.gitignore` | Expand for general project use |

### Files that already exist (no changes needed)

These files live in `.claude/rules/` and `.claude/settings.json`. They were the primer plugin's own config and are identical to what was in `templates/.claude/rules/`. After removing `templates/`, these become the template files directly.

- `.claude/settings.json` — superpowers plugin enabled
- `.claude/rules/conventional-commits.md`
- `.claude/rules/rule-style.md`
- `.claude/rules/repo-setup.md`
- `.claude/rules/superpowers.md`
- `.claude/rules/adr.md`
- `.claude/rules/git-workflow.md`
- `.claude/rules/functional-programming.md`
- `docs/superpowers/adr/.gitkeep`
- `docs/superpowers/plans/.gitkeep`
- `docs/superpowers/specs/.gitkeep`

### Files/directories to remove

| Path | Reason |
|------|--------|
| `templates/` | Repo IS the template now |
| `hooks/` | Plugin hook no longer needed |
| `.claude-plugin/` | No longer a plugin |
| `skills/` | Plugin skills no longer needed |
| `.mcp.json` | Plugin MCP config |
| `template-repo-spec.md` | Move to `docs/superpowers/specs/` |

### Parallelization

After Task 1 (strip plugin infra), Tasks 2-6 are independent and can run in parallel — they touch completely separate files. Task 7 depends on all prior tasks completing.

---

### Task 1: Strip plugin infrastructure

**Files:**
- Remove: `templates/` (entire directory)
- Remove: `hooks/` (entire directory)
- Remove: `.claude-plugin/` (entire directory)
- Remove: `skills/` (entire directory)
- Remove: `.mcp.json`
- Move: `template-repo-spec.md` to `docs/superpowers/specs/2026-04-07-template-repo-design.md`

- [ ] **Step 1: Move spec before deleting anything**

```bash
mv template-repo-spec.md docs/superpowers/specs/2026-04-07-template-repo-design.md
```

- [ ] **Step 2: Remove plugin directories and files**

```bash
rm -rf templates/ hooks/ .claude-plugin/ skills/ .mcp.json
```

- [ ] **Step 3: Verify removal**

Run: `ls -la`

Expected: No `templates/`, `hooks/`, `.claude-plugin/`, `skills/`, or `.mcp.json` in listing. `docs/superpowers/specs/2026-04-07-template-repo-design.md` exists.

- [ ] **Step 4: Verify existing `.claude/` files survived**

Run: `find .claude -type f | sort`

Expected output:
```
.claude/rules/adr.md
.claude/rules/conventional-commits.md
.claude/rules/functional-programming.md
.claude/rules/git-workflow.md
.claude/rules/repo-setup.md
.claude/rules/rule-style.md
.claude/rules/superpowers.md
.claude/settings.json
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor!: remove plugin infrastructure

BREAKING CHANGE: primer is no longer a Claude Code plugin.
It is now a GitHub template repository."
git push
```

---

### Task 2: Devcontainer with firewall sandboxing

> **Parallelizable** — can run alongside Tasks 3-6 after Task 1 completes.

**Files:**
- Create: `.devcontainer/devcontainer.json`
- Create: `.devcontainer/init-firewall.sh`

- [ ] **Step 1: Create `.devcontainer/devcontainer.json`**

Note: devcontainer.json supports JSONC (JSON with comments) natively. Comments are intentional — they serve as a menu of features for projects to uncomment.

```jsonc
{
  "name": "${localWorkspaceFolderBasename}",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/anthropics/devcontainer-features/claude-code:1": {},
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:1": {},
    "ghcr.io/jsburckhardt/devcontainer-features/just:1": {}

    // Uncomment as needed per project:

    // --- Languages ---
    // "ghcr.io/devcontainers/features/python:1": { "version": "3.12" },
    // "ghcr.io/devcontainers/features/go:1": {},
    // "ghcr.io/devcontainers/features/rust:1": {},
    // "ghcr.io/devcontainers/features/java:1": { "version": "21" }

    // --- CLIs ---
    // "ghcr.io/devcontainers/features/azure-cli:1": {}

    // --- Data ---
    // "ghcr.io/eitsupi/devcontainer-features/duckdb-cli:1": {}
  },
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW"
  ],
  "postCreateCommand": "./scripts/setup-devcontainer.sh",
  "postStartCommand": "sudo .devcontainer/init-firewall.sh"
}
```

- [ ] **Step 2: Create `.devcontainer/init-firewall.sh`**

Adapted from `anthropics/claude-code/.devcontainer/init-firewall.sh`. Key differences from the reference:
- Installs its own deps (no Dockerfile to pre-install them)
- Uses `sort -u` instead of `aggregate` (not commonly available)
- Uses `WARNING` + `continue` instead of `exit 1` for DNS failures (non-critical domains may be temporarily unresolvable)

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Install firewall dependencies if missing
if ! command -v iptables >/dev/null 2>&1 || ! command -v ipset >/dev/null 2>&1 || ! command -v dig >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq iptables ipset dnsutils curl jq
fi

# Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# Restore Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# Allow DNS, SSH, and localhost before restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ] || ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

# Add GitHub CIDRs (deduplicated via sort -u)
while read -r cidr; do
    ipset add allowed-domains "$cidr" 2>/dev/null || true
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | sort -u)

# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain — skipping"
        continue
    fi
    while read -r ip; do
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done < <(echo "$ips")
done

# Allow host network (required for Docker host communication)
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -n "$HOST_IP" ]; then
    HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
    echo "Host network: $HOST_NETWORK"
    iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow only whitelisted outbound
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Reject everything else with immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configured successfully"
```

- [ ] **Step 3: Make firewall script executable**

```bash
chmod +x .devcontainer/init-firewall.sh
```

- [ ] **Step 4: Verify devcontainer.json is valid JSONC**

Run: `node -e "const fs=require('fs'); const s=fs.readFileSync('.devcontainer/devcontainer.json','utf8'); const clean=s.replace(/\/\/.*/g,'').replace(/,(\s*[}\]])/g,'\$1'); JSON.parse(clean); console.log('PASS: valid JSONC')"`

Expected: `PASS: valid JSONC`

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/
git commit -m "feat: add devcontainer with network firewall sandboxing"
git push
```

---

### Task 3: Devcontainer setup script

> **Parallelizable** — can run alongside Tasks 2, 4-6 after Task 1 completes.

**Files:**
- Create: `scripts/setup-devcontainer.sh`

- [ ] **Step 1: Create `scripts/setup-devcontainer.sh`**

This runs once via `postCreateCommand` when the devcontainer is first built. It handles GitHub CLI authentication and SSH commit signing setup.

```bash
#!/bin/bash
set -e

# Authenticate with GitHub
gh auth login
gh auth setup-git

# Setup SSH commit signing
ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f ~/.ssh/id_ed25519_signing
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true

echo "GitHub auth and commit signing configured"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/setup-devcontainer.sh
```

- [ ] **Step 3: Lint with shellcheck**

Run: `shellcheck scripts/setup-devcontainer.sh`

Expected: No errors. SC2086 warnings about word splitting on `$(git config ...)` are acceptable since the email value won't contain spaces that matter for ssh-keygen's `-C` flag.

- [ ] **Step 4: Commit**

```bash
git add scripts/setup-devcontainer.sh
git commit -m "feat: add devcontainer setup script for gh auth and SSH signing"
git push
```

---

### Task 4: CLAUDE.md and lint-claude skill

> **Parallelizable** — can run alongside Tasks 2, 3, 5, 6 after Task 1 completes.

**Files:**
- Rewrite: `CLAUDE.md`
- Create: `.claude/skills/lint-claude.md`
- Create: `.claude/agents/.gitkeep`
- Create: `.claude/commands/.gitkeep`

- [ ] **Step 1: Create placeholder directories**

```bash
mkdir -p .claude/agents .claude/commands .claude/skills
touch .claude/agents/.gitkeep .claude/commands/.gitkeep
```

- [ ] **Step 2: Create `.claude/skills/lint-claude.md`**

```markdown
---
name: lint-claude
description: Validates CLAUDE.md conventions when editing or creating it
autoTrigger: When editing or creating CLAUDE.md
---

When editing or creating CLAUDE.md, validate the following conventions:

1. **Line count:** Must be under 200 lines
2. **Constraint pattern:** Every constraint must follow "DON'T do x — DO y" pattern (both a negative and a positive)
3. **No misplaced rules:** No rules that belong in settings.json or hooks instead (like attribution, formatting, permissions)
4. **Necessity test:** Every rule should fail the test: "Would Claude actually get this wrong without it?" — flag any that would not

Output a pass/fail summary with specific line numbers for violations.
```

- [ ] **Step 3: Rewrite `CLAUDE.md`**

Replace the entire file. Follow the spec's design principles:
- Under 200 lines
- Every constraint uses "DON'T x — DO y"
- Only rules Claude would actually get wrong
- High-level guardrails pointing to `.claude/rules/`

```markdown
# Project

<!-- Describe your project here -->

## Constraints

- DON'T use object-oriented programming (no classes, no `this`, no inheritance, no mutation) — DO use functional, immutable patterns. See `.claude/rules/functional-programming.md`.
- DON'T create worktrees outside of `.worktrees/` — DO always use that directory.
- DON'T just commit — DO follow `.claude/rules/conventional-commits.md` and `.claude/rules/git-workflow.md`.
- DON'T write rules as "do X" — DO follow `.claude/rules/rule-style.md`.
- DON'T skip architecture decisions — DO follow `.claude/rules/adr.md`.
```

- [ ] **Step 4: Verify CLAUDE.md line count**

Run: `wc -l CLAUDE.md`

Expected: Under 200 lines (should be ~13 lines).

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md .claude/skills/lint-claude.md .claude/agents/.gitkeep .claude/commands/.gitkeep
git commit -m "feat: add CLAUDE.md guardrails and lint-claude skill"
git push
```

---

### Task 5: Sync mechanism

> **Parallelizable** — can run alongside Tasks 2-4, 6 after Task 1 completes.

**Files:**
- Create: `scripts/sync-template.sh`
- Create: `justfile`

- [ ] **Step 1: Create `scripts/sync-template.sh`**

```bash
#!/bin/bash
set -e

REPO="https://github.com/mattiasthalen/primer"
REMOTE="template-upstream"

# Add template as a remote if not already there
if ! git remote get-url "$REMOTE" &>/dev/null; then
    git remote add "$REMOTE" "$REPO"
fi

git fetch "$REMOTE" main

# Merge with --allow-unrelated-histories for first sync
git merge "$REMOTE/main" --allow-unrelated-histories --no-commit || true

echo ""
echo "Review merge with: git diff --cached"
echo "Resolve any conflicts, then commit."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/sync-template.sh
```

- [ ] **Step 3: Lint with shellcheck**

Run: `shellcheck scripts/sync-template.sh`

Expected: No errors.

- [ ] **Step 4: Create `justfile`**

```just
# Sync template from upstream
sync-template:
    ./scripts/sync-template.sh
```

- [ ] **Step 5: Verify just parses the justfile**

Run: `just --list`

Expected output:
```
Available recipes:
    sync-template # Sync template from upstream
```

Note: This step requires `just` to be installed. If not available locally, skip — it will work inside the devcontainer.

- [ ] **Step 6: Commit**

```bash
git add scripts/sync-template.sh justfile
git commit -m "feat: add git-based template sync mechanism"
git push
```

---

### Task 6: Update .gitignore and README

> **Parallelizable** — can run alongside Tasks 2-5 after Task 1 completes.

**Files:**
- Rewrite: `.gitignore`
- Rewrite: `README.md`

- [ ] **Step 1: Rewrite `.gitignore`**

Replace the entire file:

```gitignore
# Claude Code - personal overrides
CLAUDE.local.md
.claude/settings.local.json

# Git worktrees
.worktrees/

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo

# Environment
.env
.env.*
!.env.example
```

- [ ] **Step 2: Rewrite `README.md`**

Replace the entire file:

```markdown
# Primer

GitHub template repository for bootstrapping projects with an opinionated devcontainer, Claude Code configuration, and self-updating sync mechanism.

## Usage

1. Click **"Use this template"** on GitHub to create a new repo
2. Open in a devcontainer (VS Code, Codespaces, etc.)
3. The `postCreateCommand` handles GitHub auth and SSH commit signing
4. Edit `CLAUDE.md` to describe your project and add constraints

## Customizing

- Add language features to `.devcontainer/devcontainer.json` (Python, Go, Rust, etc. — commented-out examples included)
- Add project-specific constraints to `CLAUDE.md` using the "DON'T x — DO y" pattern
- Add detailed rules to `.claude/rules/`

## Syncing with upstream

Pull template updates into your project:

```bash
just sync-template
```

This uses git merge, so your project-specific changes are preserved and conflicts surface naturally.

## What's included

- **Devcontainer** with network firewall sandboxing (adapted from [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/.devcontainer))
- **Claude Code config** with [superpowers](https://github.com/claude-plugins-official/superpowers) plugin, rules, and lint skill
- **Conventional commits** enforced via `.claude/rules/conventional-commits.md`
- **Functional programming** conventions via `.claude/rules/functional-programming.md`
- **Git workflow** rules (PRs, draft-first, no squash) via `.claude/rules/git-workflow.md`
- **Architecture Decision Records** via `.claude/rules/adr.md`
- **Sync mechanism** to pull upstream template updates via `just sync-template`
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore README.md
git commit -m "docs: rewrite gitignore and README for template repo"
git push
```

---

### Task 7: Configure GitHub template repository

> **Sequential** — run after all other tasks are merged to main.

- [ ] **Step 1: Enable template repo setting**

```bash
gh repo edit mattiasthalen/primer --template
```

- [ ] **Step 2: Verify template flag**

Run: `gh repo view mattiasthalen/primer --json isTemplate`

Expected: `{"isTemplate": true}`

- [ ] **Step 3: Final verification — check repo structure**

Run: `find . -not -path './.git/*' -not -path './.git' -not -path './.worktrees/*' -not -path './docs/superpowers/plans/*' -not -path './docs/superpowers/specs/*' | sort`

Expected structure:
```
.
./.claude
./.claude/agents
./.claude/agents/.gitkeep
./.claude/commands
./.claude/commands/.gitkeep
./.claude/rules
./.claude/rules/adr.md
./.claude/rules/conventional-commits.md
./.claude/rules/functional-programming.md
./.claude/rules/git-workflow.md
./.claude/rules/repo-setup.md
./.claude/rules/rule-style.md
./.claude/rules/superpowers.md
./.claude/settings.json
./.claude/skills
./.claude/skills/lint-claude.md
./.devcontainer
./.devcontainer/devcontainer.json
./.devcontainer/init-firewall.sh
./.gitignore
./CLAUDE.md
./README.md
./docs
./docs/superpowers
./docs/superpowers/adr
./docs/superpowers/adr/.gitkeep
./docs/superpowers/plans
./docs/superpowers/specs
./justfile
./scripts
./scripts/setup-devcontainer.sh
./scripts/sync-template.sh
```
