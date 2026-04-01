# Primer Development

This repo is the **primer** Claude Code plugin. It bootstraps projects with an opinionated `.claude/` structure.

## Structure

- `templates/` — files that get scaffolded into projects (1:1 path mapping)
- `hooks/` — session-start hook that runs the scaffolding logic
- `.claude-plugin/` — plugin marketplace metadata

## Adding a new template file

1. Add the file under `templates/` at the exact path it should appear in the project
2. Bump the version in `.claude-plugin/plugin.json`

## Testing

Install primer in a test project and start a new session. The hook should scaffold missing files and report what it did.
