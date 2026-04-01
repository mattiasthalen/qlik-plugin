# Primer

A Claude Code plugin that bootstraps projects with an opinionated `.claude/` structure and conventions.

## What You Get

- **Rules:** Conventional commits, git workflow, repo setup, rule style, superpowers, ADR conventions
- **Structure:** `.claude/` with skills, agents, and commands directories
- **Docs:** `docs/superpowers/` with plans, specs, and ADR directories
- **Plugin dependencies:** Superpowers plugin auto-installed
- **`.gitignore` entries:** Personal overrides and worktrees excluded

## Install

```bash
claude plugins add mattiasthalen/primer
```

Then enable it in your project's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "primer@primer": true
  }
}
```

Start a new Claude Code session. Primer will scaffold missing files and report what it did.

## Updating Files

When primer updates its templates, the session-start hook will warn about stale files. To update:

```bash
PRIMER_UPDATE=1 claude
```

Then review changes with `git diff`.
