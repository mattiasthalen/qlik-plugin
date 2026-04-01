# Plugin Repackaging Design Spec

## Overview

Repackage claude-template as **primer**, a Claude Code plugin that bootstraps projects with an opinionated `.claude/` structure and conventions via a session-start hook.

## Plugin Structure

```
primer/                          # repo root = self-hosted marketplace
├── .claude-plugin/
│   ├── marketplace.json         # marketplace: name, owner, plugin list
│   └── plugin.json              # plugin: name, version, description, keywords
├── hooks/
│   ├── hooks.json               # registers SessionStart hook
│   ├── run-hook.cmd             # cross-platform polyglot wrapper
│   └── session-start            # main hook script
├── templates/                   # 1:1 mirror of what gets scaffolded
│   ├── .claude/
│   │   ├── settings.json        # enables superpowers plugin
│   │   ├── rules/
│   │   │   ├── conventional-commits.md
│   │   │   ├── git-workflow.md
│   │   │   ├── repo-setup.md
│   │   │   ├── rule-style.md
│   │   │   ├── superpowers.md
│   │   │   └── adr.md
│   │   ├── skills/.gitkeep
│   │   ├── agents/.gitkeep
│   │   └── commands/.gitkeep
│   ├── .gitignore               # template for smart-append
│   ├── CLAUDE.md
│   └── docs/
│       └── superpowers/
│           ├── plans/.gitkeep
│           ├── specs/.gitkeep
│           └── adr/.gitkeep
├── .claude/                     # primer's own dev config
│   └── settings.json
├── .gitignore
├── CLAUDE.md
├── README.md
└── docs/superpowers/            # primer's own dev history
    ├── plans/
    ├── specs/
    └── adr/
```

## Session-Start Hook Flow

Executed on every session start. Early exit if nothing has changed.

### Phase 0: Version Check (Early Exit)

Check `.claude/.primer-version` in the project. If it matches the current plugin version, exit immediately — nothing to do. This avoids unnecessary file walks and checksums on the 99% of sessions where nothing changed.

### Phase 1: Install Missing Plugins

Check if required plugins (superpowers) are installed for the current project. Auto-install any that are missing.

### Phase 2: Scaffold Missing Files

Walk `templates/` directory. For each file, map the template path to the project path (e.g. `templates/.claude/rules/x.md` -> `.claude/rules/x.md`). If the project file doesn't exist, create parent directories and copy it. Track what was created.

### Phase 3: Smart-Append .gitignore

Special case for `.gitignore`:
- If no `.gitignore` exists, create from template
- If `.gitignore` exists, check for each required entry and append missing ones under a `# primer` comment block:

```gitignore
# primer
CLAUDE.local.md
.claude/settings.local.json
.worktrees/
```

### Phase 4: Detect Stale Files

For each template file that exists in the project, compare checksums. If different, flag as potentially stale. Output list of stale files.

User can set `PRIMER_UPDATE=1` env var to overwrite stale files, then review changes with `git diff`.

### Phase 5: Write Version Marker and Output Summary

Write current plugin version to `.claude/.primer-version` (committed to repo, shared across team).

Report:
- Files scaffolded (if any)
- .gitignore entries appended (if any)
- Stale files detected (if any)
- If plugins were installed: "Please restart your session"

## Repo Transformation

### Files to move into templates/
- `.claude/settings.json`
- `.claude/rules/*.md` (all 6 rule files)
- `.claude/skills/.gitkeep`
- `.claude/agents/.gitkeep`
- `.claude/commands/.gitkeep`
- `CLAUDE.md`

### Files to create
- `.claude-plugin/marketplace.json`
- `.claude-plugin/plugin.json`
- `hooks/hooks.json`
- `hooks/run-hook.cmd`
- `hooks/session-start`
- `templates/.gitignore`
- `templates/docs/superpowers/{plans,specs,adr}/.gitkeep`
- `docs/superpowers/adr/` (missing directory)

### Files to keep as-is
- `.claude/settings.json` (primer's own, enables superpowers)
- `.claude/settings.local.json` (gitignored)
- `.gitignore` (updated for plugin dev)
- `docs/superpowers/plans/*.md` (primer's dev history)
- `docs/superpowers/specs/*.md` (primer's dev history)

### Files to remove
- Device files: `.bash_profile`, `.bashrc`, `.profile`, `.zprofile`, `.zshrc`, `.gitconfig`, `.gitmodules`, `.idea`, `.mcp.json`, `.ripgreprc`, `.vscode`

### Files to rewrite
- `README.md` (from template docs to plugin installation/usage docs)
- `CLAUDE.md` (primer dev instructions)

## Plugin Dependencies

Primer requires the **superpowers** plugin (`superpowers@claude-plugins-official`). The session-start hook auto-installs it if missing, then requests a session restart so superpowers' own hooks register.

## Stale File Strategy

Simple diff comparison (checksum template vs project). No manifest tracking for v1. User opts in to overwrite with `PRIMER_UPDATE=1`, reviews `git diff`. If this proves too noisy (users constantly warned about intentional customizations), manifest tracking can be added later.
