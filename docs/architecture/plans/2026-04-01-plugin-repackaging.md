# Plugin Repackaging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform claude-template into primer, a Claude Code plugin that bootstraps projects with opinionated `.claude/` structure via a session-start hook.

**Architecture:** Self-hosted marketplace plugin with a SessionStart hook that scaffolds template files, smart-appends `.gitignore` entries, auto-installs plugin dependencies, and detects stale files. Template files are stored in `templates/` and copied into projects on first run.

**Tech Stack:** Bash (session-start hook), JSON (plugin metadata), Markdown (rules/templates)

**Design Spec:** `docs/superpowers/specs/2026-04-01-plugin-repackaging-design.md`
**ADR:** `docs/superpowers/adr/2026-04-01-plugin-repackaging-adr.md`

---

## Parallelization Map

```
Task 1 (plugin metadata)     ─┐
Task 2 (move to templates)   ─┤
Task 3 (hook infrastructure) ─┼─► Task 5 (session-start hook) ─► Task 7 (manual test) ─► Task 8 (commit + push)
Task 4 (template-only files) ─┤
Task 6 (primer own config)   ─┘
```

Tasks 1-4 and 6 are fully independent — run in parallel.
Task 5 depends on all of them (needs templates/ populated and hooks/ created).
Task 7 depends on 5. Task 8 depends on 7.

---

### Task 1: Create Plugin Metadata

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`

**Step 1: Create marketplace.json**

```json
{
  "name": "primer",
  "owner": {
    "name": "Mattias Thalén"
  },
  "plugins": [
    {
      "name": "primer",
      "source": "./"
    }
  ]
}
```

**Step 2: Create plugin.json**

```json
{
  "name": "primer",
  "description": "Bootstraps projects with opinionated .claude/ structure, conventions, and plugin dependencies",
  "version": "1.0.0",
  "author": {
    "name": "Mattias Thalén"
  },
  "repository": "https://github.com/mattiasthalen/primer",
  "license": "MIT",
  "keywords": ["bootstrap", "scaffold", "conventions", "template"]
}
```

**Step 3: Commit**

```bash
git add .claude-plugin/
git commit -m "feat: add plugin metadata (marketplace.json, plugin.json)"
```

---

### Task 2: Move Existing Files Into Templates

**Files:**
- Create: `templates/.claude/settings.json` (copy from `.claude/settings.json`)
- Create: `templates/.claude/rules/conventional-commits.md` (move from `.claude/rules/`)
- Create: `templates/.claude/rules/git-workflow.md` (move)
- Create: `templates/.claude/rules/repo-setup.md` (move)
- Create: `templates/.claude/rules/rule-style.md` (move)
- Create: `templates/.claude/rules/superpowers.md` (move)
- Create: `templates/.claude/rules/adr.md` (move)
- Create: `templates/.claude/skills/.gitkeep` (move)
- Create: `templates/.claude/agents/.gitkeep` (move)
- Create: `templates/.claude/commands/.gitkeep` (move)

Note: `.claude/settings.json` is **copied** (not moved) because primer's own dev config also needs it. The template version and primer's own version have the same content (enabling superpowers).

**Step 1: Create templates directory structure**

```bash
mkdir -p templates/.claude/rules
```

**Step 2: Copy settings.json**

```bash
cp .claude/settings.json templates/.claude/settings.json
```

**Step 3: Move rule files**

```bash
mv .claude/rules/conventional-commits.md templates/.claude/rules/
mv .claude/rules/git-workflow.md templates/.claude/rules/
mv .claude/rules/repo-setup.md templates/.claude/rules/
mv .claude/rules/rule-style.md templates/.claude/rules/
mv .claude/rules/superpowers.md templates/.claude/rules/
mv .claude/rules/adr.md templates/.claude/rules/
```

**Step 4: Move gitkeep files**

```bash
mkdir -p templates/.claude/{skills,agents,commands}
mv .claude/skills/.gitkeep templates/.claude/skills/
mv .claude/agents/.gitkeep templates/.claude/agents/
mv .claude/commands/.gitkeep templates/.claude/commands/
```

**Step 5: Remove now-empty directories**

```bash
rmdir .claude/rules .claude/skills .claude/agents .claude/commands
```

**Step 6: Commit**

```bash
git add templates/.claude/ .claude/rules/ .claude/skills/ .claude/agents/ .claude/commands/
git commit -m "refactor: move scaffolding files into templates/"
```

---

### Task 3: Create Hook Infrastructure

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/run-hook.cmd`

**Step 1: Create hooks.json**

Register the SessionStart hook, same pattern as superpowers:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

**Step 2: Create run-hook.cmd**

Copy the cross-platform polyglot wrapper from superpowers verbatim. Reference file: `/home/mattiasthalen/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/hooks/run-hook.cmd`

This is a proven pattern — no need to reinvent it.

**Step 3: Commit**

```bash
git add hooks/
git commit -m "feat: add hook infrastructure (hooks.json, run-hook.cmd)"
```

---

### Task 4: Create Template-Only Files

**Files:**
- Create: `templates/CLAUDE.md` (empty, same as current)
- Create: `templates/.gitignore`
- Create: `templates/docs/superpowers/plans/.gitkeep`
- Create: `templates/docs/superpowers/specs/.gitkeep`
- Create: `templates/docs/superpowers/adr/.gitkeep`

**Step 1: Create empty CLAUDE.md**

```bash
touch templates/CLAUDE.md
```

**Step 2: Create template .gitignore**

Content — the entries that primer will smart-append:

```gitignore
# Claude Code - personal overrides
CLAUDE.local.md
.claude/settings.local.json

# Git worktrees
.worktrees/
```

**Step 3: Create docs gitkeeps**

```bash
mkdir -p templates/docs/superpowers/{plans,specs,adr}
touch templates/docs/superpowers/plans/.gitkeep
touch templates/docs/superpowers/specs/.gitkeep
touch templates/docs/superpowers/adr/.gitkeep
```

**Step 4: Commit**

```bash
git add templates/CLAUDE.md templates/.gitignore templates/docs/
git commit -m "feat: add template-only files (CLAUDE.md, .gitignore, docs structure)"
```

---

### Task 5: Write Session-Start Hook

**Files:**
- Create: `hooks/session-start`

**Depends on:** Tasks 1-4 (needs templates/ populated and hooks/ created)

**Step 1: Write the session-start script**

The script implements the 6-phase flow from the design spec:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Detect project root (where Claude Code is running)
PROJECT_ROOT="$(pwd)"

# Read plugin version from plugin.json
PLUGIN_VERSION=$(grep -o '"version": *"[^"]*"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" | head -1 | cut -d'"' -f4)

# --- Phase 0: Version check (early exit) ---
VERSION_FILE="${PROJECT_ROOT}/.claude/.primer-version"
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
        exit 0
    fi
fi

# --- Tracking variables ---
scaffolded_files=()
appended_entries=()
stale_files=()
plugins_installed=false

# --- Phase 1: Install missing plugins ---
# Check if superpowers is enabled for this project
if ! grep -q '"superpowers@claude-plugins-official"' "${PROJECT_ROOT}/.claude/settings.json" 2>/dev/null; then
    # settings.json doesn't reference superpowers — likely not scaffolded yet, Phase 2 will handle it
    :
else
    # Check if superpowers is actually installed
    INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"
    if [ -f "$INSTALLED_PLUGINS" ]; then
        if ! grep -q '"superpowers@claude-plugins-official"' "$INSTALLED_PLUGINS" 2>/dev/null; then
            # TODO: auto-install command TBD — depends on Claude Code plugin CLI
            plugins_installed=true
        fi
    fi
fi

# --- Phase 2: Scaffold missing files ---
TEMPLATES_DIR="${PLUGIN_ROOT}/templates"
if [ -d "$TEMPLATES_DIR" ]; then
    while IFS= read -r -d '' template_file; do
        relative_path="${template_file#${TEMPLATES_DIR}/}"
        target_file="${PROJECT_ROOT}/${relative_path}"

        # Skip .gitignore — handled in Phase 3
        if [ "$relative_path" = ".gitignore" ]; then
            continue
        fi

        if [ ! -f "$target_file" ]; then
            mkdir -p "$(dirname "$target_file")"
            cp "$template_file" "$target_file"
            scaffolded_files+=("$relative_path")
        fi
    done < <(find "$TEMPLATES_DIR" -type f -print0)
fi

# --- Phase 3: Smart-append .gitignore ---
GITIGNORE_TEMPLATE="${TEMPLATES_DIR}/.gitignore"
GITIGNORE_TARGET="${PROJECT_ROOT}/.gitignore"
if [ -f "$GITIGNORE_TEMPLATE" ]; then
    if [ ! -f "$GITIGNORE_TARGET" ]; then
        cp "$GITIGNORE_TEMPLATE" "$GITIGNORE_TARGET"
        scaffolded_files+=(".gitignore")
    else
        # Read required entries from template (skip comments and blank lines)
        while IFS= read -r entry; do
            [[ -z "$entry" || "$entry" =~ ^# ]] && continue
            if ! grep -qxF "$entry" "$GITIGNORE_TARGET" 2>/dev/null; then
                appended_entries+=("$entry")
            fi
        done < "$GITIGNORE_TEMPLATE"

        if [ ${#appended_entries[@]} -gt 0 ]; then
            # Append under # primer block
            printf '\n# primer\n' >> "$GITIGNORE_TARGET"
            for entry in "${appended_entries[@]}"; do
                printf '%s\n' "$entry" >> "$GITIGNORE_TARGET"
            done
        fi
    fi
fi

# --- Phase 4: Detect stale files ---
if [ -d "$TEMPLATES_DIR" ] && [ "${PRIMER_UPDATE:-}" != "1" ]; then
    while IFS= read -r -d '' template_file; do
        relative_path="${template_file#${TEMPLATES_DIR}/}"
        target_file="${PROJECT_ROOT}/${relative_path}"

        [[ "$relative_path" = ".gitignore" ]] && continue

        if [ -f "$target_file" ]; then
            template_sum=$(md5sum "$template_file" 2>/dev/null | cut -d' ' -f1)
            target_sum=$(md5sum "$target_file" 2>/dev/null | cut -d' ' -f1)
            if [ "$template_sum" != "$target_sum" ]; then
                stale_files+=("$relative_path")
            fi
        fi
    done < <(find "$TEMPLATES_DIR" -type f -print0)
fi

# --- Phase 4b: Overwrite stale files if PRIMER_UPDATE=1 ---
if [ "${PRIMER_UPDATE:-}" = "1" ] && [ -d "$TEMPLATES_DIR" ]; then
    while IFS= read -r -d '' template_file; do
        relative_path="${template_file#${TEMPLATES_DIR}/}"
        target_file="${PROJECT_ROOT}/${relative_path}"

        [[ "$relative_path" = ".gitignore" ]] && continue

        if [ -f "$target_file" ]; then
            template_sum=$(md5sum "$template_file" 2>/dev/null | cut -d' ' -f1)
            target_sum=$(md5sum "$target_file" 2>/dev/null | cut -d' ' -f1)
            if [ "$template_sum" != "$target_sum" ]; then
                cp "$template_file" "$target_file"
                stale_files+=("$relative_path (updated)")
            fi
        fi
    done < <(find "$TEMPLATES_DIR" -type f -print0)
fi

# --- Phase 5: Write version marker ---
mkdir -p "${PROJECT_ROOT}/.claude"
printf '%s' "$PLUGIN_VERSION" > "$VERSION_FILE"

# --- Phase 5b: Output summary ---
summary=""

if [ ${#scaffolded_files[@]} -gt 0 ]; then
    summary+="Scaffolded files:\\n"
    for f in "${scaffolded_files[@]}"; do
        summary+="  + ${f}\\n"
    done
fi

if [ ${#appended_entries[@]} -gt 0 ]; then
    summary+="Appended to .gitignore:\\n"
    for e in "${appended_entries[@]}"; do
        summary+="  + ${e}\\n"
    done
fi

if [ ${#stale_files[@]} -gt 0 ]; then
    summary+="Stale files (template differs from project):\\n"
    for f in "${stale_files[@]}"; do
        summary+="  ~ ${f}\\n"
    done
    summary+="Run with PRIMER_UPDATE=1 to overwrite, then review with git diff.\\n"
fi

if [ "$plugins_installed" = true ]; then
    summary+="\\nPlugins were installed. Please restart your session.\\n"
fi

# Output as JSON for Claude Code hook system
if [ -n "$summary" ]; then
    escape_for_json() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        s="${s//$'\n'/\\n}"
        s="${s//$'\r'/\\r}"
        s="${s//$'\t'/\\t}"
        printf '%s' "$s"
    }

    escaped=$(escape_for_json "$summary")

    if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
        printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
    elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
        printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
    else
        printf '{\n  "additionalContext": "%s"\n}\n' "$escaped"
    fi
fi

exit 0
```

**Step 2: Make executable**

```bash
chmod +x hooks/session-start
```

**Step 3: Commit**

```bash
git add hooks/session-start
git commit -m "feat: add session-start hook with scaffold, append, stale detection"
```

---

### Task 6: Update Primer's Own Config

**Files:**
- Modify: `.gitignore` (add plugin dev entries)
- Modify: `CLAUDE.md` (add primer dev instructions)
- Modify: `README.md` (rewrite as plugin docs)
- Remove: device files (`.bash_profile`, `.bashrc`, `.profile`, `.zprofile`, `.zshrc`, `.gitconfig`, `.gitmodules`, `.idea`, `.mcp.json`, `.ripgreprc`, `.vscode`)

**Step 1: Remove device files**

These are character device files (not real files) that shouldn't be in the repo. Check which are tracked:

```bash
git ls-files .bash_profile .bashrc .profile .zprofile .zshrc .gitconfig .gitmodules .idea .mcp.json .ripgreprc .vscode
```

For any that are tracked, remove from git:

```bash
git rm .bash_profile .bashrc .profile .zprofile .zshrc .gitconfig .gitmodules .idea .mcp.json .ripgreprc .vscode
```

For any that are untracked, just leave them — they're local artifacts.

**Step 2: Update .gitignore**

Primer's own `.gitignore` should cover:
- Personal Claude overrides (already there)
- Worktrees (already there)
- Device file artifacts (add)

```gitignore
# Claude Code - personal overrides
CLAUDE.local.md
.claude/settings.local.json

# Git worktrees
.worktrees/
```

**Step 3: Rewrite CLAUDE.md**

Brief primer dev instructions:

```markdown
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
```

**Step 4: Rewrite README.md**

Plugin installation and usage docs:

```markdown
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
```

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: update primer own config, remove device files, rewrite docs"
```

---

### Task 7: Manual Smoke Test

**Depends on:** Tasks 1-6

**Step 1: Verify plugin structure**

```bash
# From worktree root, check all expected files exist
ls -la .claude-plugin/marketplace.json .claude-plugin/plugin.json
ls -la hooks/hooks.json hooks/run-hook.cmd hooks/session-start
ls -la templates/.claude/settings.json templates/.claude/rules/*.md
ls -la templates/.claude/skills/.gitkeep templates/.claude/agents/.gitkeep templates/.claude/commands/.gitkeep
ls -la templates/CLAUDE.md templates/.gitignore
ls -la templates/docs/superpowers/plans/.gitkeep templates/docs/superpowers/specs/.gitkeep templates/docs/superpowers/adr/.gitkeep
```

**Step 2: Test session-start hook against empty project**

```bash
# Create temp test directory
mkdir -p /tmp/primer-test
cd /tmp/primer-test
git init

# Simulate hook execution
CLAUDE_PLUGIN_ROOT="<worktree-path>" bash "<worktree-path>/hooks/session-start"

# Verify files were scaffolded
ls -la .claude/rules/
ls -la .claude/settings.json
ls -la .gitignore
ls -la docs/superpowers/
cat .claude/.primer-version
```

**Step 3: Test idempotency (second run should early-exit)**

```bash
CLAUDE_PLUGIN_ROOT="<worktree-path>" bash "<worktree-path>/hooks/session-start"
# Should produce no output (early exit via version check)
```

**Step 4: Test stale detection**

```bash
echo "# modified" >> .claude/rules/git-workflow.md
CLAUDE_PLUGIN_ROOT="<worktree-path>" bash "<worktree-path>/hooks/session-start"
# Should warn about stale file
```

---

### Task 8: Final Commit and Push

**Depends on:** Task 7

**Step 1: Verify clean state**

```bash
git status
git log --oneline
```

**Step 2: Push**

```bash
git push
```
