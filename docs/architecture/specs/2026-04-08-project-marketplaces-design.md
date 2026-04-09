# Project-Level Marketplace Registration

## Problem

The `extraKnownMarketplaces` config for the `codex` and `caveman` plugins lives only in the user-level `~/.claude/settings.json`. Since the devcontainer home directory is wiped on rebuild, Claude Code cannot locate these plugins after a fresh clone.

## Solution

Add `extraKnownMarketplaces` to the project-level `/workspaces/primer/.claude/settings.json`, which is checked into the repo and survives rebuilds.

### Marketplaces to register

| Key | GitHub repo |
|-----|-------------|
| `openai-codex` | `openai/codex-plugin-cc` |
| `caveman` | `JuliusBrussee/caveman` |

## Scope

Single edit to `.claude/settings.json` — no new files, no scripts, no hooks.
