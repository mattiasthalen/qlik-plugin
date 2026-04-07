## ADR-001: Request signing scope during gh auth login

- **Date:** 2026-04-07
- **Status:** accepted

### Context
`setup-git.sh` runs `gh auth login` followed by `gh ssh-key add --type signing`, but the default login doesn't include the `admin:ssh_signing_key` scope, causing the add to fail.

### Options Considered
- **Option A: `gh auth login -h github.com -s admin:ssh_signing_key`** — requests scope upfront in a single interactive step
- **Option B: Keep `gh auth login` as-is, add `gh auth refresh -h github.com -s admin:ssh_signing_key` before the ssh-key add** — two interactive prompts instead of one

### Decision
Option A. Single login with the right scope is simpler and avoids a redundant auth prompt.

### Consequences
Users authenticate once with all required scopes. The `-h github.com` flag pins the host explicitly.

## ADR-002: Justfile default recipe

- **Date:** 2026-04-07
- **Status:** accepted

### Context
Running `just` with no arguments executes the first recipe (`setup-git`), which triggers an interactive auth flow — bad for someone just exploring.

### Options Considered
- **Option A: `@just --list`** — built-in, shows all recipes with their comments
- **Option B: Custom help message** — hand-written output with descriptions

### Decision
Option A. `just --list` is maintained automatically as recipes change. A custom message would drift.

### Consequences
Running `just` is now safe and informative. New recipes are automatically listed.

## ADR-003: Stale primer plugin as user-scope cleanup

- **Date:** 2026-04-07
- **Status:** accepted

### Context
`~/.claude/settings.json` still references primer as a marketplace plugin from before the template-repo pivot. This causes Claude Code to try resolving a non-existent plugin.

### Options Considered
- **Option A: Manual removal from `~/.claude/settings.json`** — simple, user-scope only
- **Option B: Commit a migration script or template for the cleanup** — automated but over-engineered for a one-time fix

### Decision
Option A. This is a one-time cleanup on one machine. No need to automate.

### Consequences
Only affects the current user's environment. Future users of the template won't have this entry.
