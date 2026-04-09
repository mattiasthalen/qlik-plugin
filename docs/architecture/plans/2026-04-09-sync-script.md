# Sync Script Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move mechanical sync work from skill to bash script, with tenant/space/app directory structure and duplicate name handling.

**Architecture:** `sync-tenant.sh` does the loop (list, resolve, unbuild, index). Sync SKILL.md becomes a thin orchestrator that parses user intent into flags and calls the script. Inspect SKILL.md updated to use index `path` field instead of hardcoded paths.

**Tech Stack:** Bash, jq, qlik-cli

**Working directory:** `/workspaces/qlik-plugin/.worktrees/qlik-plugin-v010/`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `skills/sync/scripts/sync-tenant.sh` | Create | Mechanical sync: list, resolve spaces, unbuild loop, build index |
| `skills/sync/SKILL.md` | Rewrite | Thin orchestrator: parse intent, call script, report results |
| `skills/inspect/SKILL.md` | Modify | Use index `path` field instead of hardcoded `.qlik-sync/apps/` paths |
| `tests/test-sync-script.sh` | Create | Test script behavior with mock binary |
| `tests/test-sync.sh` | Modify | Update SKILL.md content checks for new skill text |
| `tests/test-inspect.sh` | Modify | Add check for `path` field usage |

---

## Task 1: Sync Script

**Files:**
- Create: `skills/sync/scripts/sync-tenant.sh`
- Create: `tests/test-sync-script.sh`

- [ ] **Step 1: Write `tests/test-sync-script.sh`**

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

SYNC_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-tenant.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

# Use temp dir for each test run
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Setup: create config.json
setup_config() {
  mkdir -p "$TEST_DIR/.qlik-sync"
  cat > "$TEST_DIR/.qlik-sync/config.json" << 'CONF'
{
  "context": "test-tenant",
  "server": "https://test-tenant.us.qlikcloud.com",
  "lastSync": null,
  "version": "0.1.0"
}
CONF
}

echo "=== sync-tenant.sh tests ==="

assert_file_exists "sync-tenant.sh exists" "$SYNC_SCRIPT"

# Test: script is executable
assert_eq "sync-tenant.sh is executable" "true" "$(test -x "$SYNC_SCRIPT" && echo true || echo false)"

# Test: full sync creates correct directory structure
echo ""
echo "--- full sync test ---"
setup_config
cd "$TEST_DIR"
PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" > /dev/null 2>&1
assert_dir_exists "tenant dir created" "$TEST_DIR/.qlik-sync/test-tenant"
assert_file_exists "app-001 synced" "$TEST_DIR/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard (app-001)/config.yml"
assert_file_exists "app-002 synced" "$TEST_DIR/.qlik-sync/test-tenant/HR Dev/HR Analytics (app-002)/config.yml"
assert_file_exists "app-003 synced" "$TEST_DIR/.qlik-sync/test-tenant/Finance Prod/Sales Dashboard DEV (app-003)/config.yml"
assert_file_exists "app-004 synced" "$TEST_DIR/.qlik-sync/test-tenant/Finance Prod/Finance Extract (app-004)/config.yml"
assert_file_exists "app-005 synced" "$TEST_DIR/.qlik-sync/test-tenant/HR Dev/HR Transform (app-005)/config.yml"
assert_file_exists "index.json created" "$TEST_DIR/.qlik-sync/index.json"
assert_json_field "index has 5 apps" "$TEST_DIR/.qlik-sync/index.json" ".appCount" "5"
assert_json_field "index has tenant" "$TEST_DIR/.qlik-sync/index.json" ".tenant" "test-tenant"
assert_json_field "app-001 path correct" "$TEST_DIR/.qlik-sync/index.json" '.apps["app-001"].path' "test-tenant/Finance Prod/Sales Dashboard (app-001)/"
assert_json_field "app-001 space resolved" "$TEST_DIR/.qlik-sync/index.json" '.apps["app-001"].space' "Finance Prod"
assert_json_field "lastSync updated" "$TEST_DIR/.qlik-sync/config.json" ".lastSync" "$(jq -r '.lastSync' "$TEST_DIR/.qlik-sync/config.json")"

# Test: resume skips existing apps
echo ""
echo "--- resume test ---"
RESUME_OUTPUT=$(PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" 2>&1)
assert_contains "resume skips synced apps" "$RESUME_OUTPUT" "SKIP"

# Test: --force re-syncs
echo ""
echo "--- force test ---"
FORCE_OUTPUT=$(PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" --force 2>&1)
assert_contains "force re-syncs" "$FORCE_OUTPUT" "Syncing"

# Test: space filter
echo ""
echo "--- space filter test ---"
SPACE_TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR $SPACE_TEST_DIR" EXIT
mkdir -p "$SPACE_TEST_DIR/.qlik-sync"
cp "$TEST_DIR/.qlik-sync/config.json" "$SPACE_TEST_DIR/.qlik-sync/"
cd "$SPACE_TEST_DIR"
PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" --space "Finance Prod" > /dev/null 2>&1
SPACE_APP_COUNT=$(jq '.appCount' "$SPACE_TEST_DIR/.qlik-sync/index.json")
assert_eq "space filter syncs 3 apps" "3" "$SPACE_APP_COUNT"

cd "$REPO_ROOT"
test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-script.sh`
Expected: FAIL — sync-tenant.sh does not exist

- [ ] **Step 3: Write `skills/sync/scripts/sync-tenant.sh`**

```bash
#!/bin/bash
# Sync Qlik Cloud tenant apps to local .qlik-sync/ directory
# Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
set -euo pipefail

# Parse arguments
SPACE_FILTER=""
APP_FILTER=""
ID_FILTER=""
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --space) SPACE_FILTER="$2"; shift 2 ;;
    --app) APP_FILTER="$2"; shift 2 ;;
    --id) ID_FILTER="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# Read config
CONFIG=".qlik-sync/config.json"
if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found. Run /qlik:setup first." >&2
  exit 1
fi

CONTEXT=$(jq -r '.context' "$CONFIG")
SERVER=$(jq -r '.server' "$CONFIG")
TENANT=$(echo "$SERVER" | sed 's|https://||' | sed 's|\.qlikcloud\.com.*||')

# Check dependencies
for cmd in qlik jq; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd not found on PATH" >&2
    exit 1
  fi
done

# Sanitize name for filesystem
sanitize() {
  echo "$1" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]*$//'
}

# Fetch spaces and build lookup
SPACES_JSON=$(qlik space ls --json 2>/dev/null || echo "[]")

resolve_space() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "" ] || [ "$space_id" = "null" ]; then
    echo "Personal"
    return
  fi
  local name
  name=$(echo "$SPACES_JSON" | jq -r --arg sid "$space_id" '.[] | select(.id == $sid) | .name')
  if [ -z "$name" ]; then
    echo "Unknown (${space_id:0:8})"
  else
    echo "$name"
  fi
}

# Fetch apps
if [ -n "$ID_FILTER" ]; then
  # Single app by ID — create minimal JSON array
  APPS_JSON="[{\"name\":\"single-app\",\"resourceId\":\"$ID_FILTER\",\"resourceAttributes\":{\"spaceId\":\"\",\"ownerId\":\"\",\"description\":\"\",\"published\":false,\"lastReloadTime\":\"\"},\"meta\":{\"tags\":[]}}]"
elif [ -n "$SPACE_FILTER" ]; then
  # Resolve space name to ID
  SPACE_ID=$(echo "$SPACES_JSON" | jq -r --arg name "$SPACE_FILTER" '.[] | select(.name == $name) | .id')
  if [ -z "$SPACE_ID" ]; then
    echo "Error: Space '$SPACE_FILTER' not found" >&2
    exit 1
  fi
  APPS_JSON=$(qlik app ls --json --limit 1000 --spaceId "$SPACE_ID")
elif [ -n "$APP_FILTER" ]; then
  APPS_JSON=$(qlik app ls --json --limit 1000 | jq --arg pat "$APP_FILTER" '[.[] | select(.name | test($pat; "i"))]')
else
  APPS_JSON=$(qlik app ls --json --limit 1000)
fi

TOTAL=$(echo "$APPS_JSON" | jq length)
echo "Found $TOTAL apps to sync."

# Sync loop
SYNCED=0
SKIPPED=0
FAILED=0
COUNT=0

echo "$APPS_JSON" | jq -c '.[]' | while IFS= read -r app; do
  COUNT=$((COUNT + 1))

  RESOURCE_ID=$(echo "$app" | jq -r '.resourceId')
  APP_NAME=$(echo "$app" | jq -r '.name')
  SPACE_ID=$(echo "$app" | jq -r '.resourceAttributes.spaceId // ""')
  SHORT_ID="${RESOURCE_ID:0:8}"

  SPACE_NAME=$(resolve_space "$SPACE_ID")
  SAFE_SPACE=$(sanitize "$SPACE_NAME")
  SAFE_APP=$(sanitize "$APP_NAME")
  APP_DIR=".qlik-sync/$TENANT/$SAFE_SPACE/$SAFE_APP ($SHORT_ID)"

  # Resume check
  if [ -f "$APP_DIR/config.yml" ] && [ "$FORCE" = "false" ]; then
    echo "[$COUNT/$TOTAL] SKIP: $SPACE_NAME / $APP_NAME"
    continue
  fi

  echo "[$COUNT/$TOTAL] Syncing: $SPACE_NAME / $APP_NAME..."
  mkdir -p "$APP_DIR"
  if qlik app unbuild --app "$RESOURCE_ID" --dir "$APP_DIR/" 2>/dev/null; then
    true
  else
    echo "  WARNING: Failed to unbuild $APP_NAME ($RESOURCE_ID)" >&2
    rmdir "$APP_DIR" 2>/dev/null || true
  fi
done

# Build index
echo "Building index..."

# Merge with existing index if partial sync
EXISTING_INDEX="{}"
if [ -f ".qlik-sync/index.json" ] && { [ -n "$SPACE_FILTER" ] || [ -n "$APP_FILTER" ] || [ -n "$ID_FILTER" ]; }; then
  EXISTING_INDEX=$(cat ".qlik-sync/index.json")
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build new app entries from the synced apps
NEW_APPS=$(echo "$APPS_JSON" | jq --arg tenant "$TENANT" --argjson spaces "$SPACES_JSON" '
  [.[] | {
    key: .resourceId,
    value: {
      name: .name,
      space: (
        if (.resourceAttributes.spaceId // "") == "" or (.resourceAttributes.spaceId // "") == "null" then "Personal"
        else (. as $app | $spaces | map(select(.id == $app.resourceAttributes.spaceId)) | .[0].name // ("Unknown (" + ($app.resourceAttributes.spaceId | .[0:8]) + ")"))
        end
      ),
      spaceId: (.resourceAttributes.spaceId // ""),
      owner: (.resourceAttributes.ownerId // ""),
      description: (.resourceAttributes.description // ""),
      tags: [(.meta.tags // [])[] | .name],
      published: (.resourceAttributes.published // false),
      lastReloadTime: (.resourceAttributes.lastReloadTime // ""),
      path: (
        $tenant + "/" +
        (
          if (.resourceAttributes.spaceId // "") == "" or (.resourceAttributes.spaceId // "") == "null" then "Personal"
          else (. as $app | $spaces | map(select(.id == $app.resourceAttributes.spaceId)) | .[0].name // ("Unknown (" + ($app.resourceAttributes.spaceId | .[0:8]) + ")"))
          end
        ) + "/" +
        (.name | gsub("[/\\\\:*?\"<>|]"; "_") | gsub("\\s+$"; "")) +
        " (" + (.resourceId | .[0:8]) + ")/"
      )
    }
  }] | from_entries
')

# Count synced apps (those with config.yml present)
SYNCED_COUNT=$(echo "$APPS_JSON" | jq -c '.[]' | while IFS= read -r app; do
  RID=$(echo "$app" | jq -r '.resourceId')
  ANAME=$(echo "$app" | jq -r '.name')
  SID=$(echo "$app" | jq -r '.resourceAttributes.spaceId // ""')
  SNAME=$(resolve_space "$SID")
  SSPACE=$(sanitize "$SNAME")
  SAPP=$(sanitize "$ANAME")
  DIR=".qlik-sync/$TENANT/$SSPACE/$SAPP (${RID:0:8})"
  if [ -f "$DIR/config.yml" ]; then echo "1"; fi
done | wc -l)

# Merge existing apps with new apps
MERGED_APPS=$(echo "$EXISTING_INDEX" | jq --argjson new "$NEW_APPS" '(.apps // {}) + $new')

jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT" \
  --argjson appCount "$SYNCED_COUNT" \
  --argjson apps "$MERGED_APPS" \
  '{
    lastSync: $lastSync,
    context: $context,
    server: $server,
    tenant: $tenant,
    appCount: $appCount,
    apps: $apps
  }' > .qlik-sync/index.json

# Update config
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "Sync complete. $SYNCED_COUNT synced to .qlik-sync/$TENANT/"
```

- [ ] **Step 4: Make script executable**

Run: `chmod +x skills/sync/scripts/sync-tenant.sh`

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test-sync-script.sh`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add skills/sync/scripts/sync-tenant.sh tests/test-sync-script.sh
git commit -m "feat(qlik): add sync-tenant.sh script"
git push
```

---

## Task 2: Rewrite Sync SKILL.md

**Files:**
- Modify: `skills/sync/SKILL.md`
- Modify: `tests/test-sync.sh`

- [ ] **Step 1: Update tests in `tests/test-sync.sh`**

Replace the `=== sync SKILL.md tests ===` section (lines 22-42) with:

```bash
echo ""
echo "=== sync SKILL.md tests ==="

SYNC_SKILL="$REPO_ROOT/skills/sync/SKILL.md"

assert_file_exists "sync SKILL.md exists" "$SYNC_SKILL"

FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SYNC_SKILL")
assert_contains "frontmatter has name" "$FRONTMATTER" "name: sync"
assert_contains "frontmatter has description" "$FRONTMATTER" "description:"

CONTENT=$(cat "$SYNC_SKILL")
assert_contains "mentions config.json check" "$CONTENT" "config.json"
assert_contains "mentions sync-tenant.sh" "$CONTENT" "sync-tenant.sh"
assert_contains "mentions index.json" "$CONTENT" "index.json"
assert_contains "mentions space filtering" "$CONTENT" "space"
assert_contains "mentions force flag" "$CONTENT" "force"
assert_contains "references cli-commands.md" "$CONTENT" "cli-commands.md"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync.sh`
Expected: FAIL on "mentions sync-tenant.sh"

- [ ] **Step 3: Rewrite `skills/sync/SKILL.md`**

Replace entire file with:

```markdown
---
name: sync
description: >
  Pull Qlik Sense apps from cloud tenant to local working copy. Use
  when the user says "sync qlik", "pull qlik apps", "download qlik
  environment", "extract all apps", "sync this space", or wants to
  refresh the local copy of their Qlik apps. Supports filtering by
  space name, app name pattern, or single app ID. Handles large
  tenants (200-800 apps) with resume-on-failure.
---

# Qlik Sync

Pull apps from a Qlik Cloud tenant to a local `.qlik-sync/` working copy. Each app is extracted into its own directory organized by tenant, space, and app name.

For detailed CLI command syntax, load the reference: `references/cli-commands.md`

## Prerequisites

Check that `.qlik-sync/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

## Step 1: Parse User Intent

Translate the user's request into script flags:

| User says | Script flags |
|-----------|-------------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |

Flags can be combined: `--space "Finance Prod" --force`

## Step 2: Warn on Scale (Optional)

If syncing all apps without filters, check the app count first:

```bash
qlik app ls --json --limit 1 | jq length
```

If the tenant has more than 50 apps, warn the user:
> Found a large number of apps. Consider filtering by space with `--space "SpaceName"`. Continue with full sync?

Wait for confirmation before proceeding.

## Step 3: Run Sync Script

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh [flags]
```

The script handles:
- Listing apps (with optional space/name/ID filter)
- Resolving space names from space IDs
- Unbuilding each app to `.qlik-sync/<tenant>/<space>/<app-name> (<short-id>)/`
- Skipping already-synced apps (resume on failure) unless `--force`
- Building `.qlik-sync/index.json` with all app metadata
- Updating `.qlik-sync/config.json` with `lastSync` timestamp

Progress is reported to stdout: `[3/47] Syncing: Finance Prod / Sales Dashboard...`

## Step 4: Report Results

Read the script's stdout output and report to the user. The last line contains the summary.

If the script exits with an error, help diagnose:
- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors in output** → suggest `qlik context login` to re-authenticate, then re-run sync (resume will skip already-synced apps)
- **Network errors** → suggest checking VPN/proxy and tenant URL

## Output Structure

After sync, apps are organized as:

```
.qlik-sync/
├── config.json
├── index.json
└── <tenant>/
    ├── <space>/
    │   ├── <app-name> (<short-id>)/
    │   │   ├── script.qvs
    │   │   ├── measures.json
    │   │   ├── dimensions.json
    │   │   ├── variables.json
    │   │   ├── connections.yml
    │   │   ├── app-properties.json
    │   │   ├── config.yml
    │   │   └── objects/
    │   └── ...
    ├── Personal/
    │   └── ...
    └── Unknown (<short-id>)/
        └── ...
```

## Done

Report to the user:
> Sync complete. Run `/qlik:inspect` to explore your apps.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add skills/sync/SKILL.md tests/test-sync.sh
git commit -m "refactor(qlik): rewrite sync skill to call sync-tenant.sh script"
git push
```

---

## Task 3: Update Inspect SKILL.md

**Files:**
- Modify: `skills/inspect/SKILL.md`
- Modify: `tests/test-inspect.sh`

- [ ] **Step 1: Add test for path field usage**

In `tests/test-inspect.sh`, find the line:

```bash
assert_contains "teaches offline usage" "$CONTENT" "no API\|offline\|local"
```

Add before it:

```bash
assert_contains "uses index path field" "$CONTENT" "path"
```

- [ ] **Step 2: Run test to verify it passes (or already passes)**

Run: `bash tests/test-inspect.sh`
Expected: Check if "path" already appears in the skill

- [ ] **Step 3: Update grep paths in `skills/inspect/SKILL.md`**

Read the file first. Make these replacements:

Find: `grep for the measure name in `.qlik-sync/apps/*/measures.json``
Replace: `grep for the measure name across all `measures.json` files under `.qlik-sync/`

Find: `Read `.qlik-sync/apps/<app-id>/script.qvs``
Replace: `Read `.qlik-sync/<path>/script.qvs` where `<path>` is from the app's `path` field in `index.json``

Find: `Read `.qlik-sync/apps/<app-id>/measures.json``
Replace: `Read `.qlik-sync/<path>/measures.json` where `<path>` is from `index.json``

Find: `Read `.qlik-sync/apps/<app-id>/dimensions.json``
Replace: `Read `.qlik-sync/<path>/dimensions.json` where `<path>` is from `index.json``

Find: `Read `.qlik-sync/apps/<app-id>/variables.json``
Replace: `Read `.qlik-sync/<path>/variables.json` where `<path>` is from `index.json``

Find: `Read `.qlik-sync/apps/<app-id>/connections.yml``
Replace: `Read `.qlik-sync/<path>/connections.yml` where `<path>` is from `index.json``

Find: `List files in `.qlik-sync/apps/<app-id>/objects/``
Replace: `List files in `.qlik-sync/<path>/objects/` where `<path>` is from `index.json``

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-inspect.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add skills/inspect/SKILL.md tests/test-inspect.sh
git commit -m "fix(qlik): update inspect skill to use index path field"
git push
```

---

## Task 4: Run Full Test Suite and Verify

- [ ] **Step 1: Run all tests**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-sync-script.sh && bash tests/test-inspect.sh && bash tests/test-project.sh`
Expected: All pass

- [ ] **Step 2: Update justfile with new test**

In `justfile`, add `test-sync-script.sh` to the test recipe:

```justfile
# Run all tests
test:
	@bash tests/test-setup.sh
	@bash tests/test-sync.sh
	@bash tests/test-sync-script.sh
	@bash tests/test-inspect.sh
	@bash tests/test-project.sh
```

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "chore(qlik): add sync script test to justfile"
git push
```

- [ ] **Step 4: Verify git log**

Run: `git log --oneline -6`
Expected: Clean conventional commits.
