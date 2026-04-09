# Decision: Plugin Setup Approach

## Context

Need to install Codex plugin (for Claude Code) and Caveman plugin (for Claude Code and Codex) as part of the primer template.

## Options considered

### A. Add plugin install commands to existing setup-devcontainer.sh (rejected)

Inline all plugin commands directly in the post-create script.

- Simpler (one file), but mixes concerns (git hooks vs plugin setup).
- No way to re-run plugin setup independently.

### B. Separate setup-plugins.sh script + justfile target (chosen)

Extract plugin installation into its own script, call it from setup-devcontainer.sh, and expose it as `just setup-plugins`.

- Separation of concerns — each script has one job.
- Users can re-run plugin setup without rebuilding the container.
- Consistent with existing pattern (`setup-git.sh` + `just setup-git`).

### C. Use devcontainer postStartCommand or lifecycle hooks (rejected)

Configure plugins via devcontainer lifecycle events rather than a shell script.

- Harder to run manually outside the container.
- Less visible — buried in JSON config rather than explicit scripts.

### D. Use `npx skills` for all plugins (rejected)

The `npx skills` CLI supports 40+ agents including Claude Code and Codex. Could use it as a single install mechanism for everything.

- Claude Code has its own native plugin system (`claude plugin marketplace add` / `claude plugin install`) which is the recommended path.
- `npx skills` is the recommended path for Codex.
- Using each tool's native mechanism is more robust and forward-compatible.

## Decisions

**Setup approach**: Option B — separate script with justfile target. Follows the existing setup-git pattern and keeps concerns cleanly separated.

**Plugin install mechanism**: Use each tool's native system — Claude Code's plugin CLI for Claude plugins, `npx skills` for Codex plugins. Most robust and follows each tool's recommended path.

**Codex CLI fallback**: Install via `npm install -g @openai/codex` when the devcontainer feature doesn't provide it. The devcontainer feature was unreliable, and Node.js is already available.
