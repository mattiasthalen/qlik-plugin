# Session Confirmation & Plugin Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the session-start hook always confirm it ran and check that required plugins are installed at project scope.

**Architecture:** Restructure the single `hooks/session-start` bash script. Replace the early exit with a version-match flag. Extract plugin checking into a dedicated function. Always emit output.

**Tech Stack:** Bash (no external dependencies)

**Spec:** `docs/superpowers/specs/2026-04-02-session-confirmation-design.md`

---

### Task 1: Replace early exit with version-match flag

**Files:**
- Modify: `hooks/session-start:13-20`

Replace the `exit 0` on version match with a flag that controls whether scaffolding phases run, while allowing plugin check and output to always execute.

- [ ] **Step 1: Replace the early exit block**

Change lines 13-20 from:

```bash
# --- Phase 0: Version check (early exit) ---
VERSION_FILE="${PROJECT_ROOT}/.claude/.primer-version"
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
        exit 0
    fi
fi
```

To:

```bash
# --- Phase 0: Version check ---
VERSION_FILE="${PROJECT_ROOT}/.claude/.primer-version"
version_match=false
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
        version_match=true
    fi
fi
```

- [ ] **Step 2: Wrap phases 2-4b in a version_match guard**

Wrap the existing Phase 2, Phase 3, Phase 4, and Phase 4b blocks (lines 54-135) in a single conditional:

```bash
if [ "$version_match" = false ]; then
    # --- Phase 2: Scaffold missing files ---
    # ... (existing Phase 2 code, unchanged)

    # --- Phase 3: Smart-append .gitignore ---
    # ... (existing Phase 3 code, unchanged)

    # --- Phase 4: Detect stale files ---
    # ... (existing Phase 4 code, unchanged)

    # --- Phase 4b: Overwrite stale files if PRIMER_UPDATE=1 ---
    # ... (existing Phase 4b code, unchanged)
fi
```

- [ ] **Step 3: Verify the hook still runs without errors**

Run from the worktree directory:

```bash
cd /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation && bash hooks/session-start
```

Expected: no output (plugin check not yet rewritten, summary logic not yet updated).

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "refactor: replace early exit with version-match flag"
```

---

### Task 2: Rewrite plugin check to use project-scoped lookup

**Files:**
- Modify: `hooks/session-start:22-26` (tracking variables)
- Modify: `hooks/session-start:40-52` (Phase 1)

Replace the hardcoded, global-only plugin check with a dynamic, project-scoped check that reads plugin names from the template `settings.json`.

- [ ] **Step 1: Replace the tracking variable**

Change line 26 from:

```bash
plugins_missing=false
```

To:

```bash
missing_plugins=()
```

- [ ] **Step 2: Replace Phase 1 with project-scoped plugin check**

Replace lines 40-52 (the entire Phase 1 block) with:

```bash
# --- Phase 1: Check required plugins are installed for this project ---
TEMPLATE_SETTINGS="${PLUGIN_ROOT}/templates/.claude/settings.json"
INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"

if [ -f "$TEMPLATE_SETTINGS" ]; then
    # Extract plugin names from enabledPlugins keys
    required_plugins=()
    while IFS= read -r plugin_name; do
        [ -n "$plugin_name" ] && required_plugins+=("$plugin_name")
    done < <(grep -o '"[^"]*"[[:space:]]*:[[:space:]]*true' "$TEMPLATE_SETTINGS" | grep -v '"enabledPlugins"' | cut -d'"' -f2)

    if [ ${#required_plugins[@]} -gt 0 ] && [ -f "$INSTALLED_PLUGINS" ]; then
        for plugin in "${required_plugins[@]}"; do
            # Check for a project-scoped entry matching PROJECT_ROOT
            # Look for the plugin key, then scan its entries for scope+projectPath match
            if ! awk -v plugin="\"$plugin\"" -v proj="\"$PROJECT_ROOT\"" '
                BEGIN { in_plugin=0; in_entry=0; found=0 }
                $0 ~ plugin":" { in_plugin=1; next }
                in_plugin && /^\s*\]/ { in_plugin=0 }
                in_plugin && /\{/ { in_entry=1; scope_match=0; path_match=0 }
                in_plugin && in_entry && /"scope".*"project"/ { scope_match=1 }
                in_plugin && in_entry && /"projectPath"/ && $0 ~ proj { path_match=1 }
                in_plugin && in_entry && /\}/ {
                    if (scope_match && path_match) { found=1; exit }
                    in_entry=0
                }
                END { exit !found }
            ' "$INSTALLED_PLUGINS" 2>/dev/null; then
                missing_plugins+=("$plugin")
            fi
        done
    elif [ ${#required_plugins[@]} -gt 0 ] && [ ! -f "$INSTALLED_PLUGINS" ]; then
        # No installed_plugins.json at all — all plugins are missing
        missing_plugins=("${required_plugins[@]}")
    fi
fi
```

- [ ] **Step 3: Verify plugin check detects project-scoped installs**

Run from the primer repo itself (where superpowers IS installed at project scope):

```bash
cd /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation && bash hooks/session-start
```

Expected: no "missing plugins" output (superpowers is installed for this project).

- [ ] **Step 4: Verify plugin check detects missing project-scoped installs**

Run from a directory that does NOT have superpowers installed at project scope:

```bash
cd /tmp && bash /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation/hooks/session-start
```

Expected: should detect missing plugins (since `/tmp` has no project-scoped install).

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start
git commit -m "feat: rewrite plugin check to require project-scoped installation"
```

---

### Task 3: Always emit status output

**Files:**
- Modify: `hooks/session-start` (Phase 5b output section, lines 141-191)

Rewrite the output section to always emit a status line, prepend it to any detail output, and use the new `missing_plugins` array.

- [ ] **Step 1: Rewrite the summary and output section**

Replace the entire Phase 5b and JSON output section (lines 141-191) with:

```bash
# --- Phase 5b: Output summary ---
summary="primer v${PLUGIN_VERSION}"

has_details=false

detail=""
if [ ${#scaffolded_files[@]} -gt 0 ]; then
    has_details=true
    detail+=$'Scaffolded files:\n'
    for f in "${scaffolded_files[@]}"; do
        detail+=$'  + '"${f}"$'\n'
    done
fi

if [ ${#appended_entries[@]} -gt 0 ]; then
    has_details=true
    detail+=$'Appended to .gitignore:\n'
    for e in "${appended_entries[@]}"; do
        detail+=$'  + '"${e}"$'\n'
    done
fi

if [ ${#stale_files[@]} -gt 0 ]; then
    has_details=true
    detail+=$'Stale files (template differs from project):\n'
    for f in "${stale_files[@]}"; do
        detail+=$'  ~ '"${f}"$'\n'
    done
    detail+=$'Run with PRIMER_UPDATE=1 to overwrite, then review with git diff.\n'
fi

if [ ${#missing_plugins[@]} -gt 0 ]; then
    has_details=true
    detail+=$'Missing plugins (not installed for this project):\n'
    for p in "${missing_plugins[@]}"; do
        detail+=$'  - '"${p}"$'\n'
        detail+=$'    Install: claude plugins install '"${p}"$'\n'
    done
fi

if [ "$has_details" = true ]; then
    summary+=$'\n\n'"${detail}"
else
    summary+=" — up to date"
fi

# Output as JSON for Claude Code hook system
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
elif [ -n "${COPILOT_CLI:-}" ]; then
    printf '{\n  "additionalContext": "%s"\n}\n' "$escaped"
else
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
fi
```

- [ ] **Step 2: Remove the conditional around JSON output**

The old code had `if [ -n "$summary" ]; then ... fi` around the JSON output. The new code always outputs — verify there is no leftover conditional wrapping.

- [ ] **Step 3: Verify happy path output**

Run from the primer worktree (version matches, plugins installed):

```bash
cd /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation && bash hooks/session-start
```

Expected output (JSON with `primer v1.0.0 — up to date` in additionalContext).

- [ ] **Step 4: Verify missing plugin output**

```bash
cd /tmp && bash /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation/hooks/session-start
```

Expected: JSON output containing `primer v1.0.0` with missing plugins detail.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start
git commit -m "feat: always emit session confirmation status"
```

---

### Task 4: Final verification

**Files:**
- Read: `hooks/session-start` (full file review)

- [ ] **Step 1: Read the final hook file**

Read the complete `hooks/session-start` to verify all changes are coherent.

- [ ] **Step 2: Test happy path (version match, plugins installed)**

```bash
cd /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation && bash hooks/session-start
```

Expected: JSON containing `primer v1.0.0 — up to date`

- [ ] **Step 3: Test version mismatch (delete version file)**

```bash
cd /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation && rm -f .claude/.primer-version && bash hooks/session-start
```

Expected: JSON containing `primer v1.0.0` with scaffolding/stale details. Restore the version file after:

```bash
printf '1.0.0' > .claude/.primer-version
```

- [ ] **Step 4: Test missing plugins from /tmp**

```bash
cd /tmp && bash /home/mattiasthalen/repos/primer/.worktrees/feat/session-confirmation/hooks/session-start
```

Expected: JSON with missing plugins section listing `superpowers@claude-plugins-official`.

- [ ] **Step 5: Push branch**

```bash
git push
```
