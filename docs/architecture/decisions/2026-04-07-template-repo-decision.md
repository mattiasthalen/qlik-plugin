## ADR-001: Replace plugin with GitHub template repo

- **Date:** 2026-04-07
- **Status:** accepted

### Context
Primer was a Claude Code plugin that scaffolded `.claude/` structure into projects via a session-start hook. The goal shifted to providing a full project starting point including devcontainer, git hooks, and sync mechanism — which doesn't fit the plugin model.

### Options Considered
- **A) Clean break** — remove all plugin machinery, repo root becomes the template
- **B) Gradual migration** — keep plugin alongside template for a transition period
- **C) Subtree split** — separate branch preserves plugin identity

### Decision
Option A. The plugin is fully replaced. Git history preserves the old structure if ever needed. No dual identity, no cleanup debt.

### Consequences
- `.claude-plugin/`, `hooks/`, `templates/`, `skills/status/` are removed
- Rules and settings move from `templates/` to repo root
- Distribution changes from "install plugin" to "clone template + sync upstream"

---

## ADR-002: Lefthook over pre-commit for git hooks

- **Date:** 2026-04-07
- **Status:** accepted

### Context
Need git hooks for `.gitkeep` cleanup and conventional commit validation. Pre-commit (Python-based) and lefthook (Go binary) are the main options.

### Options Considered
- **pre-commit** — Python-based, large ecosystem, but requires Python runtime in every devcontainer
- **lefthook** — single Go binary, no runtime deps, YAML config
- **husky** — Node-based, adds a runtime dependency

### Decision
Lefthook. No runtime dependency, available as a devcontainer feature (`ghcr.io/iyaki/devcontainer-features/lefthook:2`). Keeps the devcontainer lean.

### Consequences
- `lefthook.yml` at repo root configures hooks
- `postCreateCommand` runs `lefthook install` to wire into `.git/hooks`
- Projects don't need Python installed just for git hooks

---

## ADR-003: CLAUDE.md as routing table, not rule dump

- **Date:** 2026-04-07
- **Status:** accepted

### Context
CLAUDE.md tends to grow into a dumping ground. Need a pattern that keeps it small and loads rules on-demand.

### Options Considered
- **Inline all rules** — everything in CLAUDE.md, simple but bloats quickly
- **Routing table** — short entries pointing to `.claude/rules/`, rules loaded only when relevant

### Decision
Routing table. Each entry has a negative and a positive pointing to the detailed rule file. Enforced by `lint-claude.md` skill (under 200 lines, both halves present, no inline specs).

### Consequences
- CLAUDE.md stays small and scannable
- Rules are only loaded when Claude is doing the relevant activity
- `lint-claude.md` skill validates conventions when CLAUDE.md is edited

---

## ADR-004: Skip devcontainer firewall sandboxing

- **Date:** 2026-04-07
- **Status:** accepted

### Context
Anthropic's reference devcontainer includes iptables-based network isolation (default-deny egress with IP allowlist). This requires a Dockerfile, `NET_ADMIN`/`NET_RAW` capabilities, and additional packages.

### Options Considered
- **Include by default** — every project gets sandboxing, but adds complexity (Dockerfile, capabilities)
- **Skip for now** — keep the simpler image-based devcontainer

### Decision
Skip for now. The image-based approach is simpler and sufficient. Sandboxing can be added later per-project or as a future template enhancement.

### Consequences
- Devcontainer uses `image` directly, no Dockerfile needed
- No network isolation out of the box
