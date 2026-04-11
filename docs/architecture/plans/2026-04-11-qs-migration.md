# qs Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace bash sync scripts and agent parallelism with the `qs` Go CLI, making the plugin a thin UX layer over `qs`.

**Architecture:** Plugin keeps guided setup and AI-powered inspect as native skills. Sync becomes a thin wrapper around `qs sync`. All `.qlik-sync/` references change to `qlik/`. Bash scripts and agent orchestration are deleted.

**Tech Stack:** Shell (bash tests), Markdown (SKILL.md files), `qs` CLI (Go binary)

---

### Task 1: Update Setup Skill — Prerequisites

**Files:**
- Modify: `skills/setup/SKILL.md`
- Test: `tests/test-setup.sh`

- [ ] **Step 1: Write failing test — qs prereq replaces jq**

In `tests/test-setup.sh`, replace the `jq` prereq assertion with `qs` prereq assertion, and remove the `qlik-parser` assertion:

```bash
# Replace this line:
assert_contains "mentions jq prerequisite" "$CONTENT" "which jq"
# With:
assert_contains "mentions qs prerequisite" "$CONTENT" "which qs"

# Remove this line:
assert_contains "mentions qlik-parser" "$CONTENT" "qlik-parser"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-setup.sh`
Expected: FAIL — "which qs" not found in SKILL.md, "qlik-parser" still found

- [ ] **Step 3: Update SKILL.md — change prereqs**

In `skills/setup/SKILL.md` Step 1, replace `jq` check with `qs` check:

```markdown
## Step 1: Check Prerequisites

Verify both tools are installed:

\`\`\`bash
which qlik
which qs
\`\`\`

If `qlik` is missing, tell the user:
> Install qlik-cli from https://qlik.dev/toolkits/qlik-cli/ and make sure `qlik` is on your PATH.

If `qs` is missing, tell the user:
> Install qs from https://github.com/mattiasthalen/qlik-sync/releases and make sure `qs` is on your PATH.

Stop and wait for the user to install missing tools before continuing.
```

Remove the entire on-prem qlik-parser section from Step 2.5 (lines about `which qlik-parser` and the "On-prem sync requires qlik-parser" message).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-setup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md tests/test-setup.sh
git commit -m "feat(setup): replace jq prereq with qs CLI prereq"
git push
```

---

### Task 2: Update Setup Skill — Directory References

**Files:**
- Modify: `skills/setup/SKILL.md`
- Test: `tests/test-setup.sh`

- [ ] **Step 1: Write failing test — qlik/ directory replaces .qlik-sync/**

In `tests/test-setup.sh`, replace the `.qlik-sync` assertion:

```bash
# Replace this line:
assert_contains "mentions .qlik-sync directory" "$CONTENT" ".qlik-sync"
# With:
assert_contains "mentions qlik directory" "$CONTENT" "qlik/"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-setup.sh`
Expected: FAIL — "qlik/" not matched (SKILL.md still says `.qlik-sync`)

- [ ] **Step 3: Update SKILL.md — replace all .qlik-sync/ with qlik/**

In `skills/setup/SKILL.md`:
- Step 5 heading: `mkdir -p qlik` (was `mkdir -p .qlik-sync`)
- All `config.json` references: `qlik/config.json` (was `.qlik-sync/config.json`)
- Step 6: check for `qlik/` in `.gitignore` (was `.qlik-sync/`)
- Done message: "workspace is ready at `qlik/`"

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-setup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md tests/test-setup.sh
git commit -m "feat(setup): change workspace directory from .qlik-sync/ to qlik/"
git push
```

---

### Task 3: Update Setup Skill — Remove On-Prem Details

**Files:**
- Modify: `skills/setup/SKILL.md`
- Test: `tests/test-setup.sh`

- [ ] **Step 1: Write failing test — remove on-prem-specific assertions**

In `tests/test-setup.sh`, remove these lines that test on-prem setup specifics:

```bash
# Remove these lines:
assert_contains "mentions on-prem detection" "$CONTENT" "qlikcloud.com"
assert_contains "mentions qlik-parser" "$CONTENT" "qlik-parser"
assert_contains "mentions server-type Windows" "$CONTENT" "server-type Windows"
```

Keep the multi-tenant assertion — multi-tenant config is still relevant.

- [ ] **Step 2: Run test to verify it passes**

Run: `bash tests/test-setup.sh`
Expected: PASS (removing assertions doesn't break, but validates the reduced scope)

- [ ] **Step 3: Update SKILL.md — simplify for cloud-only**

In `skills/setup/SKILL.md`:
- Remove Step 2.5 entirely (tenant type detection, on-prem context flags, qlik-parser check)
- Remove "Alternative: OAuth Login (on-prem / QSEoW only)" section from Step 3
- Remove `--server-type Windows --insecure` references
- Remove on-prem connectivity test option (`qlik qrs app ls`)
- Keep API Key Auth and cloud connectivity test

- [ ] **Step 4: Run test to verify it still passes**

Run: `bash tests/test-setup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md tests/test-setup.sh
git commit -m "feat(setup): remove on-prem setup flow, cloud-only via qs"
git push
```

---

### Task 4: Rewrite Sync Skill

**Files:**
- Modify: `skills/sync/SKILL.md`
- Test: `tests/test-sync.sh`

- [ ] **Step 1: Write failing test — new sync skill structure**

Replace `tests/test-sync.sh` entirely:

```bash
#!/bin/bash
# Tests for sync SKILL.md — validates skill definition and references
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SKILL_FILE="$REPO_ROOT/skills/sync/SKILL.md"

echo "=== sync SKILL.md tests ==="
SKILL_CONTENT="$(cat "$SKILL_FILE")"
assert_file_exists "sync SKILL.md exists" "$SKILL_FILE"
assert_contains "frontmatter has name" "$SKILL_CONTENT" "name: sync"
assert_contains "frontmatter has description" "$SKILL_CONTENT" "description:"

# qs CLI integration
assert_contains "mentions qs sync command" "$SKILL_CONTENT" "qs sync"
assert_contains "mentions space filter" "$SKILL_CONTENT" "\-\-space"
assert_contains "mentions app filter" "$SKILL_CONTENT" "\-\-app"
assert_contains "mentions id filter" "$SKILL_CONTENT" "\-\-id"
assert_contains "mentions tenant filter" "$SKILL_CONTENT" "\-\-tenant"
assert_contains "mentions force flag" "$SKILL_CONTENT" "\-\-force"

# Exit code handling
assert_contains "mentions exit code 0" "$SKILL_CONTENT" "exit.*0\|Exit code 0\|exit 0"
assert_contains "mentions exit code 2 partial" "$SKILL_CONTENT" "exit.*2\|Exit code 2\|partial"

# Output directory
assert_contains "mentions qlik/ directory" "$SKILL_CONTENT" "qlik/"
assert_contains "mentions config.json" "$SKILL_CONTENT" "config.json"
assert_contains "mentions index.json" "$SKILL_CONTENT" "index.json"

# Should NOT contain old bash script references
SKILL_CONTENT_NEGATIVE="$SKILL_CONTENT"
if echo "$SKILL_CONTENT_NEGATIVE" | grep -q "sync-cloud-prep.sh"; then
  echo "  FAIL: should not mention sync-cloud-prep.sh"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention sync-cloud-prep.sh"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$SKILL_CONTENT_NEGATIVE" | grep -q "Agent"; then
  echo "  FAIL: should not mention Agent tool"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention Agent tool"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync.sh`
Expected: FAIL — old SKILL.md doesn't mention `qs sync`, still mentions bash scripts and Agent

- [ ] **Step 3: Rewrite SKILL.md**

Replace `skills/sync/SKILL.md` entirely:

```markdown
---
name: sync
description: >
  Use when the user says "sync qlik", "pull qlik apps", "download
  qlik environment", "extract all apps", "sync this space", or wants
  to refresh the local copy of their Qlik apps. Also use when sync
  failed partway and needs to resume, or when apps need re-syncing
  after changes on the tenant.
allowed-tools:
  - Bash(qs sync:*)
  - Bash(qs version:*)
  - Bash(which:*)
  - Read
---

# Qlik Sync

Pull apps from Qlik Cloud tenants to a local `qlik/` working copy using the `qs` CLI. Each app is extracted into its own directory organized by tenant, space, and app name.

## Prerequisites

Check that `qlik/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

**Auto-resume after setup:** If setup was triggered as a prerequisite for sync (i.e., the user's original intent was to sync), resume the sync automatically after setup completes. Do not ask the user to re-invoke `/qlik:sync`.

## Step 1: Parse User Intent

Translate the user's request into `qs sync` flags:

| User says | Flags |
|-----------|-------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |
| "sync my-cloud tenant" | `--tenant "context-name"` |

Flags can be combined: `--space "Finance Prod" --force`

## Step 2: Run qs sync

```bash
qs sync [--space "..."] [--app "..."] [--id "..."] [--tenant "..."] [--force]
```

The `qs` CLI handles:
- API calls and filtering
- Concurrent app downloads (Go goroutines)
- 5-minute prep cache (bypass with `--force`)
- Resume detection (skips already-synced apps)
- Exponential backoff retries on failure
- Building and merging `qlik/index.json`

## Step 3: Handle Results

Check the exit code:
- **Exit code 0:** All apps synced successfully
- **Exit code 1:** Fatal error (auth failure, config missing, network error)
- **Exit code 2:** Partial sync — some apps failed

Report to the user:
> Sync complete. Run `/qlik:inspect` to explore your apps.

If exit code 2, list which apps failed from the output and suggest:
> Some apps failed to sync. Retry specific apps with `/qlik:sync --id <app-id> --force`.

### Troubleshooting

- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors** → suggest re-authenticating: `qlik context login`
- **"Skipping on-prem tenant"** → `qs` does not yet support on-prem sync. Cloud tenants work normally.
- **Network errors** → check VPN/proxy and tenant URL

## Output Structure

```
qlik/
├── config.json
├── index.json
└── <tenant-domain> (<tenantId>)/
    ├── shared/
    │   └── <space-name> (<spaceId>)/
    │       └── analytics/
    │           └── <app-name> (<resourceId>)/
    │               ├── script.qvs
    │               ├── measures.json
    │               ├── dimensions.json
    │               ├── variables.json
    │               ├── connections.yml
    │               ├── app-properties.json
    │               └── objects/
    ├── managed/
    └── personal/
```
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/sync/SKILL.md tests/test-sync.sh
git commit -m "feat(sync): rewrite sync skill as thin wrapper around qs CLI"
git push
```

---

### Task 5: Delete Bash Sync Scripts

**Files:**
- Delete: `skills/sync/scripts/sync-cloud-prep.sh`
- Delete: `skills/sync/scripts/sync-cloud-app.sh`
- Delete: `skills/sync/scripts/sync-onprem-prep.sh`
- Delete: `skills/sync/scripts/sync-onprem-app.sh`
- Delete: `skills/sync/scripts/sync-finalize.sh`
- Delete: `skills/sync/scripts/sync-lib.sh`
- Delete: `skills/sync/scripts/sync-tenant.sh`
- Modify: `justfile`

- [ ] **Step 1: Write failing test — verify scripts directory is gone**

The existing tests for deleted scripts (`test-sync-lib.sh`, `test-sync-cloud-prep.sh`, `test-sync-onprem-prep.sh`, `test-sync-cloud-app.sh`, `test-sync-onprem-app.sh`, `test-sync-finalize.sh`, `test-sync-script.sh`) will be deleted. No replacement tests needed — the scripts are gone.

Add a negative assertion to `tests/test-sync.sh` to verify no scripts directory:

```bash
# Add before test_summary in tests/test-sync.sh:
if [ -d "$REPO_ROOT/skills/sync/scripts" ]; then
  echo "  FAIL: skills/sync/scripts/ directory should not exist"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: skills/sync/scripts/ directory removed"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync.sh`
Expected: FAIL — `skills/sync/scripts/` still exists

- [ ] **Step 3: Delete scripts and old tests**

```bash
rm -rf skills/sync/scripts/
rm tests/test-sync-lib.sh
rm tests/test-sync-cloud-prep.sh
rm tests/test-sync-onprem-prep.sh
rm tests/test-sync-cloud-app.sh
rm tests/test-sync-onprem-app.sh
rm tests/test-sync-finalize.sh
rm tests/test-sync-script.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync.sh`
Expected: PASS

- [ ] **Step 5: Update justfile — remove deleted test references**

Replace the `test` recipe in `justfile`:

```just
# Run all tests
test:
	@bash tests/test-setup.sh
	@bash tests/test-sync.sh
	@bash tests/test-inspect.sh
	@bash tests/test-project.sh
```

- [ ] **Step 6: Run full test suite**

Run: `just test`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(sync): delete bash sync scripts and related tests"
git push
```

---

### Task 6: Update Inspect Skill

**Files:**
- Modify: `skills/inspect/SKILL.md`
- Test: `tests/test-inspect.sh`

- [ ] **Step 1: Write failing test — qlik/ directory references**

Replace `tests/test-inspect.sh`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== inspect SKILL.md tests ==="

INSPECT_SKILL="$REPO_ROOT/skills/inspect/SKILL.md"

assert_file_exists "inspect SKILL.md exists" "$INSPECT_SKILL"

FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$INSPECT_SKILL")
assert_contains "frontmatter has name" "$FRONTMATTER" "name: inspect"
assert_contains "frontmatter has description" "$FRONTMATTER" "description:"

CONTENT=$(cat "$INSPECT_SKILL")
assert_contains "mentions index.json" "$CONTENT" "index.json"
assert_contains "mentions measures.json" "$CONTENT" "measures.json"
assert_contains "mentions dimensions.json" "$CONTENT" "dimensions.json"
assert_contains "mentions script.qvs" "$CONTENT" "script.qvs"
assert_contains "mentions connections" "$CONTENT" "connections"
assert_contains "mentions grep or search" "$CONTENT" "grep\|Grep\|search"
assert_contains "mentions compare or diff" "$CONTENT" "compare\|diff"
assert_contains "mentions space filter" "$CONTENT" "space"
assert_contains "uses index path field" "$CONTENT" "path"
assert_contains "teaches offline usage" "$CONTENT" "no API\|offline\|local"

# Directory references should use qlik/ not .qlik-sync/
assert_contains "uses qlik/ directory" "$CONTENT" "qlik/"

if echo "$CONTENT" | grep -q '\.qlik-sync'; then
  echo "  FAIL: should not mention .qlik-sync"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention .qlik-sync"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-inspect.sh`
Expected: FAIL — `.qlik-sync` still present, `qlik/` not found

- [ ] **Step 3: Update SKILL.md — replace .qlik-sync/ with qlik/**

In `skills/inspect/SKILL.md`:
- Frontmatter description: change `.qlik-sync/` to `qlik/`
- All path references: `.qlik-sync/` → `qlik/`
- `qlik/index.json` (was `.qlik-sync/index.json`)
- `qlik/<path>/script.qvs` (was `.qlik-sync/<path>/script.qvs`)
- Same for `measures.json`, `dimensions.json`, `variables.json`, `connections.yml`, `objects/`
- `qlik/config.json` (was `.qlik-sync/config.json`)
- Error messages: "Run `/qlik:sync` to pull apps" (keep same)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-inspect.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add skills/inspect/SKILL.md tests/test-inspect.sh
git commit -m "feat(inspect): update directory references from .qlik-sync/ to qlik/"
git push
```

---

### Task 7: Update Project Config

**Files:**
- Modify: `.gitignore`
- Modify: `scripts/setup-devcontainer.sh`
- Modify: `tests/test-project.sh`
- Modify: `tests/e2e/sync-e2e-checklist.md`

- [ ] **Step 1: Write failing test — qlik/ in .gitignore, qs in devcontainer**

Update `tests/test-project.sh`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== project config tests ==="

# .gitignore includes qlik/
GITIGNORE=$(cat "$REPO_ROOT/.gitignore")
assert_contains ".gitignore has qlik/" "$GITIGNORE" "qlik/"

# justfile has test recipe
JUSTFILE=$(cat "$REPO_ROOT/justfile")
assert_contains "justfile has test recipe" "$JUSTFILE" "test"

# devcontainer setup script has qlik-cli and qs install
SETUP=$(cat "$REPO_ROOT/scripts/setup-devcontainer.sh")
assert_contains "devcontainer installs qlik-cli" "$SETUP" "qlik"
assert_contains "devcontainer installs qs" "$SETUP" "qs"

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-project.sh`
Expected: FAIL — `.gitignore` has `.qlik-sync/` not `qlik/`, devcontainer doesn't install `qs`

- [ ] **Step 3: Update .gitignore**

Replace `.qlik-sync/` with `qlik/`:

```
# Git worktrees
.worktrees/
.claude/worktrees/
qlik/
```

- [ ] **Step 4: Update devcontainer setup**

Add `qs` install to `scripts/setup-devcontainer.sh`:

```bash
#!/bin/bash
set -e

lefthook install

# Install qlik-cli for integration testing
if ! command -v qlik &> /dev/null; then
  echo "Installing qlik-cli..."
  curl -sL https://github.com/qlik-oss/qlik-cli/releases/latest/download/qlik-Linux-x86_64.tar.gz | sudo tar xz -C /usr/local/bin qlik
  echo "qlik-cli installed: $(qlik version)"
fi

# Install qs for syncing Qlik apps
if ! command -v qs &> /dev/null; then
  echo "Installing qs..."
  curl -sL https://github.com/mattiasthalen/qlik-sync/releases/latest/download/qs-Linux-x86_64.tar.gz | sudo tar xz -C /usr/local/bin qs
  echo "qs installed: $(qs version)"
fi

# Verify jq is available (installed by base devcontainer image)
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update -qq && sudo apt-get install -y -qq jq
  echo "jq installed: $(jq --version)"
fi
```

Note: The `qs` download URL follows the same pattern as `qlik-cli`. Verify the actual release asset name at https://github.com/mattiasthalen/qlik-sync/releases before finalizing.

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test-project.sh`
Expected: PASS

- [ ] **Step 6: Update e2e checklist**

Replace `tests/e2e/sync-e2e-checklist.md` to reflect `qs`-based sync flow. Remove bash script references, update directory paths from `.qlik-sync/` to `qlik/`, reference `qs sync` commands instead of script calls.

- [ ] **Step 7: Commit**

```bash
git add .gitignore scripts/setup-devcontainer.sh tests/test-project.sh tests/e2e/sync-e2e-checklist.md
git commit -m "feat(project): update config for qs migration (gitignore, devcontainer, e2e)"
git push
```

---

### Task 8: Delete Sync References File

**Files:**
- Delete: `skills/sync/references/cli-commands.md`

- [ ] **Step 1: Check if sync SKILL.md still references cli-commands.md**

Read `skills/sync/SKILL.md` to confirm the reference to `references/cli-commands.md` was removed in Task 4. The new SKILL.md should not reference it.

- [ ] **Step 2: Delete the file**

```bash
rm skills/sync/references/cli-commands.md
rmdir skills/sync/references/
```

- [ ] **Step 3: Run full test suite**

Run: `just test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(sync): remove cli-commands.md reference doc (replaced by qs)"
git push
```

---

### Task 9: Bump Plugin Version

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Test: `tests/test-setup.sh`

- [ ] **Step 1: Write failing test — version 0.4.0**

In `tests/test-setup.sh`, update the version assertion:

```bash
# Replace:
assert_json_field "plugin version is 0.3.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.3.0"
# With:
assert_json_field "plugin version is 0.4.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.4.0"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-setup.sh`
Expected: FAIL — version is still 0.3.0

- [ ] **Step 3: Update plugin.json**

In `.claude-plugin/plugin.json`, change version to `"0.4.0"`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-setup.sh`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `just test`
Expected: All tests pass — this is the final validation of the entire migration.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json tests/test-setup.sh
git commit -m "chore(plugin): bump version to 0.4.0"
git push
```
