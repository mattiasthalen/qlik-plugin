# Template Repo Design

Repurpose mattiasthalen/primer from a Claude Code plugin into a GitHub template repository providing a sandboxed devcontainer, baseline Claude Code configuration, git hooks, and a self-updating sync mechanism.

## Approach

Clean break: remove all plugin machinery (`.claude-plugin/`, `hooks/`, `templates/`, `skills/status/`). The repo root becomes the template — files live at their final paths.

## Repo Structure

```
primer/
├── .devcontainer/
│   └── devcontainer.json
├── .claude/
│   ├── settings.json
│   ├── rules/
│   │   ├── .gitkeep
│   │   ├── adr.md
│   │   ├── conventional-commits.md
│   │   ├── functional-programming.md
│   │   ├── git-workflow.md
│   │   ├── repo-setup.md
│   │   ├── rule-style.md
│   │   └── superpowers.md
│   ├── skills/
│   │   ├── .gitkeep
│   │   └── lint-claude.md
│   ├── agents/
│   │   └── .gitkeep
│   └── commands/
│       └── .gitkeep
├── scripts/
│   ├── .gitkeep
│   ├── setup-git.sh
│   └── sync-template.sh
├── docs/
│   └── superpowers/
│       ├── adr/
│       │   └── .gitkeep
│       ├── plans/
│       │   └── .gitkeep
│       └── specs/
│           └── .gitkeep
├── .gitignore
├── CLAUDE.md
├── lefthook.yml
├── justfile
└── README.md
```

## Devcontainer

Image-based, no Dockerfile. CLI-only usage (no VS Code).

```jsonc
{
  "name": "${localWorkspaceFolderBasename}",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/anthropics/devcontainer-features/claude-code:1": {},
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/guiyomh/features/just:0": {},
    "ghcr.io/iyaki/devcontainer-features/lefthook:2": {},
    "ghcr.io/devcontainers-community/features/direnv": {},

    // --- Tools ---
    // "ghcr.io/devcontainers/features/docker-in-docker:1": {},
    // "ghcr.io/devcontainers-extra/features/pre-commit:2": {},

    // --- Languages ---
    // "ghcr.io/devcontainers/features/python:1": { "version": "3.12" },
    // "ghcr.io/devcontainers/features/go:1": {},
    // "ghcr.io/devcontainers/features/rust:1": {},
    // "ghcr.io/devcontainers/features/java:1": { "version": "21" },
    // "ghcr.io/devcontainers-extra/features/clojure-asdf:2": {},

    // --- CLIs ---
    // "ghcr.io/devcontainers/features/azure-cli:1": {},
    // "ghcr.io/dhoeric/features/google-cloud-cli:1": {},
    // Snowflake CLI — pip install snowflake-cli
    // Databricks CLI — curl from GitHub releases
    // Microsoft Fabric CLI — pip install ms-fabric-cli

    // --- Data ---
    // "ghcr.io/eitsupi/devcontainer-features/duckdb-cli:1": {},
    // "ghcr.io/jlaundry/devcontainer-features/mssql-odbc-driver:1": {}
  },
  "postCreateCommand": "./scripts/setup-devcontainer.sh"
}
```

Required features: Claude Code, Node, GitHub CLI, just, lefthook, direnv.

## Scripts

### scripts/setup-devcontainer.sh

Non-interactive, runs on container creation:

```bash
#!/bin/bash
set -e

lefthook install
```

Projects extend this as needed.

### scripts/setup-git.sh

Manual, run once via `just setup-git`:

```bash
#!/bin/bash
set -e

gh auth login
gh auth setup-git

ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f ~/.ssh/id_ed25519_signing
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true

echo "GitHub auth and commit signing configured"
```

### scripts/sync-template.sh

Merges upstream template changes:

```bash
#!/bin/bash
set -e

REPO="https://github.com/mattiasthalen/primer"
REMOTE="template-upstream"

if ! git remote get-url "$REMOTE" &>/dev/null; then
  git remote add "$REMOTE" "$REPO"
fi

git fetch "$REMOTE" main
git merge "$REMOTE/main" --allow-unrelated-histories --no-commit || true

echo ""
echo "Review merge with: git diff --cached"
echo "Resolve any conflicts, then commit."
```

## Justfile

```just
# Run interactive GitHub auth + SSH signing setup
setup-git:
    ./scripts/setup-git.sh

# Sync template from upstream
sync-template:
    ./scripts/sync-template.sh
```

## Lefthook

```yaml
pre-commit:
  commands:
    gitkeep-cleanup:
      glob: ".gitkeep"
      run: |
        for f in {staged_files}; do
          dir=$(dirname "$f")
          if [ -f "$dir/.gitkeep" ] && [ "$(ls -1 "$dir" | wc -l)" -gt 1 ]; then
            rm "$dir/.gitkeep"
            git add "$dir/.gitkeep"
          fi
        done

commit-msg:
  commands:
    conventional-commit:
      run: |
        msg=$(head -1 {1})
        if ! echo "$msg" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?!?: .+'; then
          echo "Commit message must follow Conventional Commits: <type>[scope]: <description>"
          exit 1
        fi
```

## CLAUDE.md

```markdown
## Rules

- DON'T commit without following the convention — DO read `.claude/rules/conventional-commits.md`
- DON'T push without a branch and PR — DO read `.claude/rules/git-workflow.md`
- DON'T set up a repo without protections — DO read `.claude/rules/repo-setup.md`
- DON'T write rules without the required pattern — DO read `.claude/rules/rule-style.md`
- DON'T use OOP patterns — DO read `.claude/rules/functional-programming.md`
- DON'T store plans or specs in the wrong place — DO read `.claude/rules/superpowers.md`
- DON'T make architectural decisions without recording them — DO read `.claude/rules/adr.md`
```

## .claude/settings.json

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true
  }
}
```

## .claude/skills/lint-claude.md

```markdown
---
name: lint-claude
description: Use when editing or creating CLAUDE.md — validates conventions
---

When editing or creating CLAUDE.md, validate:

1. **Line count:** Must be under 200 lines
2. **Constraint pattern:** Every rule must follow `.claude/rules/rule-style.md`
3. **Index only:** Flag any rule that contains detailed specs — those belong in `.claude/rules/`
4. **Worth it:** Every rule should fail the test "Would Claude actually get this wrong without it?" — flag any that wouldn't

Output a pass/fail summary with specific line numbers for violations.
```

## Rule Style Update

`rule-style.md` updated to:

```markdown
# Rule Style

- NEVER write a rule with only a negative or only a positive. Every rule must have both: what to avoid, then the alternative.
```

## .gitignore

```
# Claude Code - personal overrides
CLAUDE.local.md
.claude/settings.local.json

# Git worktrees
.worktrees/
```

## Removals

- `.claude-plugin/` — plugin metadata
- `hooks/session-start` — scaffolding hook
- `templates/` — files move to repo root
- `skills/status/` — plugin status skill
- `.mcp.json` — not needed
- `template-repo-spec.md` — consumed into this spec

## Design Principles

1. **Settings/hooks over prompts** — anything that must happen 100% of the time goes in settings or hooks, not CLAUDE.md
2. **CLAUDE.md is a routing table** — short guardrails pointing to detailed specs in `.claude/rules/`
3. **Negative + alternative** — every constraint has both halves
4. **Only prompt what Claude gets wrong** — if Claude wouldn't make the mistake without the rule, cut it
5. **Under 200 lines** — enforced by lint-claude skill
6. **Projects own their config** — the template provides the baseline, projects customize from there
7. **Self-updating** — `just sync-template` merges upstream changes, preserving project-specific additions
