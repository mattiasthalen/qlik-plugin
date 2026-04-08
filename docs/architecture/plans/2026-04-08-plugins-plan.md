# Plan: Add Codex and Caveman Plugins

## Context

The primer template needs AI agent plugins configured so they're automatically available when anyone creates a devcontainer from this template.

Plugins:
1. **Codex plugin for Claude Code** (`openai/codex-plugin-cc`) — use Codex from within Claude Code for reviews and task delegation
2. **Caveman for Claude Code** (`JuliusBrussee/caveman`) — compressed communication, ~75% token savings
3. **Caveman for Codex** (`JuliusBrussee/caveman`) — same but for Codex CLI

## Approach

Create `scripts/setup-plugins.sh` (idempotent), wire it into `scripts/setup-devcontainer.sh`, and add a `just setup-plugins` target.

## Files

- `scripts/setup-plugins.sh` (new) — core plugin installation logic
- `scripts/setup-devcontainer.sh` (modify) — call setup-plugins.sh
- `justfile` (modify) — add setup-plugins target
