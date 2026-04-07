# Primer

GitHub template repository for bootstrapping projects with an opinionated devcontainer, Claude Code configuration, and self-updating sync mechanism.

## Usage

1. Click **"Use this template"** on GitHub to create a new repo
2. Open in a devcontainer (VS Code, Codespaces, etc.)
3. Run `just setup-git` for GitHub auth and SSH commit signing
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

- **Devcontainer** with Claude Code, Node, GitHub CLI, just, lefthook, and direnv
- **Claude Code config** with [superpowers](https://github.com/claude-plugins-official/superpowers) plugin, rules, and lint skill
- **Conventional commits** enforced via `.claude/rules/conventional-commits.md`
- **Functional programming** conventions via `.claude/rules/functional-programming.md`
- **Git workflow** rules (PRs, draft-first, no squash) via `.claude/rules/git-workflow.md`
- **Architecture Decision Records** via `.claude/rules/adr.md`
- **Sync mechanism** to pull upstream template updates via `just sync-template`
