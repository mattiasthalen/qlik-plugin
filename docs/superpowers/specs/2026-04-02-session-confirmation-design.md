# Session Confirmation & Plugin Check

## Problem

The session-start hook silently exits when the primer version matches, giving no feedback that it ran. Additionally, the plugin check only verifies global installation, not project-scoped installation.

## Design

### Hook Flow

```
session-start
├── Read plugin version
├── Plugin check (ALWAYS runs)
│   ├── Parse enabledPlugins from templates/.claude/settings.json
│   ├── For each plugin, check installed_plugins.json for a
│   │   project-scoped entry matching PROJECT_ROOT
│   └── Collect missing plugins list
├── Version match?
│   ├── YES → skip to output
│   └── NO → run phases 2-4 (scaffold, gitignore, stale check)
├── Write version marker
└── Output (ALWAYS emits)
    ├── Happy path: "primer v1.0.0 — up to date"
    ├── With changes: scaffolded/appended/stale details + status line
    └── Missing plugins: actionable install command per plugin
```

### Key Changes

- Early exit on version match replaced with skip-to-output — plugin check and status output always run.
- Plugin check reads `enabledPlugins` keys from the template dynamically instead of hardcoding `superpowers`.
- Plugin check requires a `scope: "project"` entry with matching `projectPath` — user/global scope does not count.
- Status line always emitted as additional context.

### Output Format

**Happy path (version match, all plugins installed):**

```
primer v1.0.0 — up to date
```

**Version mismatch with changes:**

```
primer v1.0.0

Scaffolded files:
  + .claude/rules/adr.md
  + .claude/settings.json

Appended to .gitignore:
  + .claude/settings.local.json

Stale files (template differs from project):
  ~ .claude/rules/git-workflow.md
Run with PRIMER_UPDATE=1 to overwrite, then review with git diff.
```

**Missing plugins (can appear with either path):**

```
primer v1.0.0 — up to date

Missing plugins (not installed for this project):
  - superpowers@claude-plugins-official
    Install: claude plugins install superpowers@claude-plugins-official
```

The JSON wrapping for Claude Code / Cursor / Copilot stays the same — this is the `summary` content that gets escaped into the appropriate format.

### Plugin Check Implementation

For each key in `templates/.claude/settings.json` → `enabledPlugins`:

1. Look up the key in `~/.claude/plugins/installed_plugins.json` → `plugins`.
2. Filter entries to `scope: "project"` AND `projectPath` matching `PROJECT_ROOT`.
3. If no matching entry → add to `missing_plugins` list.

**Edge cases:**

- `installed_plugins.json` doesn't exist → all plugins are missing.
- `templates/.claude/settings.json` has no `enabledPlugins` → skip check entirely.
- Plugin installed at user scope but not project scope → still counts as missing.

Parsing uses `grep`/`sed` to stay dependency-free (no `jq` requirement), consistent with the existing hook style.
