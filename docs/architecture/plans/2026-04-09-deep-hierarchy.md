# Deep Hierarchy + CLI Whitelist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SKILL:** Use superpowers:writing-skills when modifying SKILL.md files — run RED/GREEN/REFACTOR on skill changes.

**Goal:** Update sync script to 5-level directory structure with full UUIDs, space/app types, personal user resolution, and add CLI whitelists to all skills.

**Architecture:** Rewrite `sync-tenant.sh` for new path format, add `qlik user get` to mock binary, update fixtures for personal/app-type test coverage, add `allowed-tools` frontmatter to all three skills.

**Tech Stack:** Bash, jq, qlik-cli

**Working directory:** `/workspaces/qlik-plugin/.worktrees/qlik-plugin-v010/`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `tests/fixtures/app-ls-response.json` | Modify | Add personal-space app, add `usage` variations |
| `tests/fixtures/space-ls-response.json` | Verify | Already has `type` field (managed, shared) |
| `tests/fixtures/user-get-response.json` | Create | Canned `qlik user get` response |
| `tests/mock-qlik/qlik` | Modify | Add `user get` subcommand |
| `tests/test-sync-script.sh` | Rewrite | Test new 5-level directory structure |
| `skills/sync/scripts/sync-tenant.sh` | Rewrite | Deep hierarchy, full IDs, user resolution, app types |
| `skills/setup/SKILL.md` | Modify | Add `allowed-tools` frontmatter |
| `skills/sync/SKILL.md` | Modify | Add `allowed-tools` frontmatter, update output structure docs |
| `skills/inspect/SKILL.md` | Modify | Add `allowed-tools` frontmatter |

---

## Task 1: Update Fixtures and Mock Binary

**Files:**
- Modify: `tests/fixtures/app-ls-response.json`
- Create: `tests/fixtures/user-get-response.json`
- Modify: `tests/mock-qlik/qlik`

- [ ] **Step 1: Add a personal-space app to `tests/fixtures/app-ls-response.json`**

Read the existing file. Add a 6th app at the end of the array with empty `spaceId` and `usage: "DATA_PREPARATION"` to test both personal space and a different app type:

```json
  {
    "name": "Personal ETL",
    "resourceId": "app-006",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-006",
      "name": "Personal ETL",
      "spaceId": "",
      "owner": "auth0|user001hash",
      "ownerId": "user-001",
      "description": "Personal data prep app",
      "published": false,
      "lastReloadTime": "2026-04-09T10:00:00Z",
      "createdDate": "2025-07-01T12:00:00Z",
      "modifiedDate": "2026-04-09T10:30:00Z",
      "usage": "DATA_PREPARATION",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-07-01T12:00:00Z",
    "resourceUpdatedAt": "2026-04-09T10:30:00Z",
    "ownerId": "user-001",
    "creatorId": "user-001",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-006" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-006" }
    },
    "collectionIds": [],
    "id": "item-006",
    "createdAt": "2025-07-01T12:00:00Z",
    "updatedAt": "2026-04-09T10:30:00Z"
  }
```

Also update app-004 (Finance Extract) to have `"usage": "DATAFLOW_PREP"` instead of `"ANALYTICS"` to test a third app type. Find `"usage": "ANALYTICS"` in the app-004 block and change it.

- [ ] **Step 2: Create `tests/fixtures/user-get-response.json`**

```json
{
  "id": "user-001",
  "name": "testuser",
  "email": "testuser@company.com",
  "status": "active",
  "tenantId": "test-tenant-id"
}
```

- [ ] **Step 3: Add `user get` subcommand to `tests/mock-qlik/qlik`**

Read the existing mock binary. Add a new `user)` case block before the final `*)` catch-all:

```bash
  user)
    case "$2" in
      get)
        # Parse user ID from positional arg or --id flag
        USER_ID=""
        shift 2
        while [ $# -gt 0 ]; do
          case "$1" in
            --id) USER_ID="$2"; shift 2 ;;
            --json) shift ;;
            *) USER_ID="$1"; shift ;;
          esac
        done
        cat "$FIXTURES_DIR/user-get-response.json"
        ;;
      me)
        cat "$FIXTURES_DIR/user-get-response.json"
        ;;
      *)
        echo "Unknown user subcommand: $2" >&2
        exit 1
        ;;
    esac
    ;;
```

- [ ] **Step 4: Verify mock works**

Run: `PATH="tests/mock-qlik:$PATH" qlik user get user-001 --json | jq -r '.name'`
Expected: `testuser`

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json | jq length`
Expected: `6`

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json | jq '.[5].resourceAttributes.usage' -r`
Expected: `DATA_PREPARATION`

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/app-ls-response.json tests/fixtures/user-get-response.json tests/mock-qlik/qlik
git commit -m "test(qlik): add personal app fixture, user-get mock, and dataflow-prep app type"
git push
```

---

## Task 2: Rewrite Sync Script

**Files:**
- Modify: `skills/sync/scripts/sync-tenant.sh`

- [ ] **Step 1: Rewrite `skills/sync/scripts/sync-tenant.sh`**

Replace the entire file. Key changes from current version:

1. **Domain extraction**: `sed -E 's|https?://(.+)\.qlikcloud\.com.*|\1|'` (keeps region like `two.eu`)
2. **Tenant ID**: extracted from first app's `tenantId` field
3. **Tenant folder**: `<domain> (<tenantId>)`
4. **Space type folders**: `shared/`, `managed/`, `data/`, `personal/`, `unknown/`
5. **Space folders**: `<name> (<spaceId>)`
6. **Personal spaces**: resolve `ownerId` to username via `qlik user get <id> --json | jq -r '.name'`, cached in temp file
7. **App type folders**: normalize `usage` field: lowercase, underscores→hyphens
8. **App folders**: `<name> (<full-resourceId>)`
9. **Unknown spaces**: `unknown/<full-spaceId>/`
10. **Index**: new fields `spaceType`, `appType`, `ownerName`; path reflects full hierarchy

Full script:

```bash
#!/bin/bash
# sync-tenant.sh — Sync Qlik Cloud apps to local filesystem
# Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
set -euo pipefail

# --- Parse flags ---
SPACE_FILTER=""
APP_FILTER=""
ID_FILTER=""
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --space) SPACE_FILTER="$2"; shift 2 ;;
    --app)   APP_FILTER="$2"; shift 2 ;;
    --id)    ID_FILTER="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: sync-tenant.sh [--space \"Name\"] [--app \"Pattern\"] [--id <GUID>] [--force]" >&2
      exit 1
      ;;
  esac
done

# --- Read config ---
CONFIG_FILE=".qlik-sync/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. Run setup first." >&2
  exit 1
fi

CONTEXT="$(jq -r '.context // empty' "$CONFIG_FILE")"
SERVER="$(jq -r '.server // empty' "$CONFIG_FILE")"

if [ -z "$CONTEXT" ] || [ -z "$SERVER" ]; then
  echo "Error: config.json missing context or server." >&2
  exit 1
fi

# Extract tenant domain — keep region (e.g., two.eu from https://two.eu.qlikcloud.com)
TENANT_DOMAIN="$(echo "$SERVER" | sed -E 's|https?://(.+)\.qlikcloud\.com.*|\1|')"

# --- Check dependencies ---
for cmd in qlik jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found on PATH." >&2
    exit 1
  fi
done

# --- Fetch spaces and build lookup ---
SPACES_JSON="$(qlik space ls --json)"

SPACE_LOOKUP="$(mktemp)"
USER_CACHE="$(mktemp)"
INDEX_ENTRIES="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$INDEX_ENTRIES"' EXIT

# Build space lookup: id -> name\ttype
echo "$SPACES_JSON" | jq -r '.[] | "\(.id)\t\(.name)\t\(.type)"' > "$SPACE_LOOKUP"

resolve_space_name() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo ""
    return
  fi
  grep "^${space_id}	" "$SPACE_LOOKUP" | cut -f2
}

resolve_space_type() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo "personal"
    return
  fi
  local stype
  stype="$(grep "^${space_id}	" "$SPACE_LOOKUP" | cut -f3)"
  if [ -n "$stype" ]; then
    echo "$stype"
  else
    echo "unknown"
  fi
}

resolve_username() {
  local user_id="$1"
  # Check cache first
  local cached
  cached="$(grep "^${user_id}	" "$USER_CACHE" 2>/dev/null | cut -f2)"
  if [ -n "$cached" ]; then
    echo "$cached"
    return
  fi
  # Fetch from API
  local uname
  uname="$(qlik user get "$user_id" --json 2>/dev/null | jq -r '.name // .email // empty')"
  if [ -z "$uname" ]; then
    uname="$user_id"
  fi
  echo -e "${user_id}\t${uname}" >> "$USER_CACHE"
  echo "$uname"
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# --- Resolve space ID for space filter ---
SPACE_ID_FILTER=""
if [ -n "$SPACE_FILTER" ]; then
  SPACE_ID_FILTER="$(grep "	${SPACE_FILTER}	" "$SPACE_LOOKUP" | cut -f1)"
  if [ -z "$SPACE_ID_FILTER" ]; then
    echo "Error: space '$SPACE_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
if [ -n "$ID_FILTER" ]; then
  APPS_JSON="$(qlik app ls --json --limit 1000 | jq "[.[] | select(.resourceId == \"$ID_FILTER\")]")"
elif [ -n "$SPACE_ID_FILTER" ]; then
  APPS_JSON="$(qlik app ls --json --limit 1000 --spaceId "$SPACE_ID_FILTER")"
else
  APPS_JSON="$(qlik app ls --json --limit 1000)"
fi

if [ -n "$APP_FILTER" ]; then
  APPS_JSON="$(echo "$APPS_JSON" | jq "[.[] | select(.name | test(\"$APP_FILTER\"))]")"
fi

APP_COUNT="$(echo "$APPS_JSON" | jq 'length')"

if [ "$APP_COUNT" -eq 0 ]; then
  echo "No apps found matching filters."
  exit 0
fi

# Get tenant ID from first app
TENANT_ID="$(echo "$APPS_JSON" | jq -r '.[0].tenantId // empty')"
TENANT_DIR="$TENANT_DOMAIN ($TENANT_ID)"

PARTIAL=false
if [ -n "$SPACE_FILTER" ] || [ -n "$APP_FILTER" ] || [ -n "$ID_FILTER" ]; then
  PARTIAL=true
fi

# --- Sanitize folder name ---
sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

# --- Sync loop ---
SYNCED=0
SKIPPED=0
ERRORS=0
IDX=0

while IFS= read -r app_line; do
  IDX=$((IDX + 1))

  resource_id="$(echo "$app_line" | jq -r '.resourceId')"
  app_name="$(echo "$app_line" | jq -r '.name')"
  space_id="$(echo "$app_line" | jq -r '.resourceAttributes.spaceId // empty')"
  owner_id="$(echo "$app_line" | jq -r '.resourceAttributes.ownerId // empty')"
  description="$(echo "$app_line" | jq -r '.resourceAttributes.description // empty')"
  published="$(echo "$app_line" | jq -r '.resourceAttributes.published // false')"
  last_reload="$(echo "$app_line" | jq -r '.resourceAttributes.lastReloadTime // empty')"
  usage="$(echo "$app_line" | jq -r '.resourceAttributes.usage // "ANALYTICS"')"
  tags="$(echo "$app_line" | jq -c '[.meta.tags[]?.name]')"

  # Resolve space
  space_type="$(resolve_space_type "$space_id")"
  space_name="$(resolve_space_name "$space_id")"
  app_type="$(normalize_app_type "$usage")"

  # Build space folder name
  if [ "$space_type" = "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
    space_folder="$(sanitize "$owner_name") ($owner_id)"
  elif [ "$space_type" = "unknown" ]; then
    space_folder="$space_id"
    space_name="$space_id"
  else
    space_folder="$(sanitize "$space_name") ($space_id)"
  fi

  safe_app="$(sanitize "$app_name")"
  app_folder="$safe_app ($resource_id)"

  # Full path: tenant/space-type/space/app-type/app/
  rel_path="$TENANT_DIR/$space_type/$space_folder/$app_type/$app_folder/"
  full_path=".qlik-sync/$rel_path"

  # Display space name for progress
  if [ "$space_type" = "personal" ]; then
    display_space="personal/$owner_name"
  elif [ "$space_type" = "unknown" ]; then
    display_space="unknown/$space_id"
  else
    display_space="$space_type/$space_name"
  fi

  # Resume check
  if [ "$FORCE" = false ] && [ -f "$full_path/config.yml" ]; then
    SKIPPED=$((SKIPPED + 1))
    echo "[$IDX/$APP_COUNT] SKIP: $display_space / $app_name"
  else
    echo "[$IDX/$APP_COUNT] Syncing: $display_space / $app_name..."
    mkdir -p "$full_path"
    if qlik app unbuild --app "$resource_id" --dir "$full_path" >/dev/null 2>&1; then
      SYNCED=$((SYNCED + 1))
    else
      ERRORS=$((ERRORS + 1))
      echo "  WARNING: Failed to unbuild $app_name ($resource_id)" >&2
    fi
  fi

  # Resolve owner name for index (cache hit if already resolved for personal)
  if [ "$space_type" != "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
  fi

  # Build index entry
  cat >> "$INDEX_ENTRIES" <<ENTRY
$(jq -n \
  --arg id "$resource_id" \
  --arg name "$app_name" \
  --arg space "$space_name" \
  --arg spaceId "$space_id" \
  --arg spaceType "$space_type" \
  --arg appType "$app_type" \
  --arg owner "$owner_id" \
  --arg ownerName "$owner_name" \
  --arg desc "$description" \
  --argjson tags "$tags" \
  --argjson published "$published" \
  --arg reload "$last_reload" \
  --arg path "$rel_path" \
  '{($id): {name: $name, space: $space, spaceId: $spaceId, spaceType: $spaceType, appType: $appType, owner: $owner, ownerName: $ownerName, description: $desc, tags: $tags, published: $published, lastReloadTime: $reload, path: $path}}')
ENTRY

done < <(echo "$APPS_JSON" | jq -c '.[]')

# --- Build index.json ---
INDEX_FILE=".qlik-sync/index.json"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

APPS_OBJ="$(jq -s 'add // {}' "$INDEX_ENTRIES")"

if [ "$PARTIAL" = true ] && [ -f "$INDEX_FILE" ]; then
  EXISTING_APPS="$(jq '.apps // {}' "$INDEX_FILE")"
  APPS_OBJ="$(echo "$EXISTING_APPS" "$APPS_OBJ" | jq -s '.[0] * .[1]')"
fi

FINAL_COUNT="$(echo "$APPS_OBJ" | jq 'length')"

jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "$TENANT_ID" \
  --argjson appCount "$FINAL_COUNT" \
  --argjson apps "$APPS_OBJ" \
  '{lastSync: $lastSync, context: $context, server: $server, tenant: $tenant, tenantId: $tenantId, appCount: $appCount, apps: $apps}' \
  > "$INDEX_FILE"

# --- Update config.json ---
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# --- Summary ---
echo ""
echo "Sync complete: $SYNCED synced, $SKIPPED skipped, $ERRORS errors (${FINAL_COUNT} apps in index)"

exit 0
```

- [ ] **Step 2: Verify script is executable**

Run: `chmod +x skills/sync/scripts/sync-tenant.sh` (should already be)

- [ ] **Step 3: Commit**

```bash
git add skills/sync/scripts/sync-tenant.sh
git commit -m "feat(qlik): rewrite sync script for deep hierarchy with full IDs"
git push
```

---

## Task 3: Rewrite Sync Script Tests

**Files:**
- Modify: `tests/test-sync-script.sh`

- [ ] **Step 1: Rewrite `tests/test-sync-script.sh`**

Replace entire file. Tests verify 5-level structure, full IDs, space types, app types, personal user resolution.

```bash
#!/bin/bash
# Tests for sync-tenant.sh script — deep hierarchy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SYNC_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-tenant.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "context": "test-ctx",
  "server": "https://test-tenant.us.qlikcloud.com"
}
JSON
  echo "$workdir"
}

run_sync() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$SYNC_SCRIPT" "$@" 2>&1)
}

echo "=== sync-tenant.sh tests (deep hierarchy) ==="

# Test 1: Script exists and is executable
echo ""
echo "--- Test 1: Script exists and is executable ---"
assert_file_exists "sync-tenant.sh exists" "$SYNC_SCRIPT"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -x "$SYNC_SCRIPT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: sync-tenant.sh is executable"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: sync-tenant.sh is not executable"
fi

# Test 2: Full sync — 5-level directory structure
echo ""
echo "--- Test 2: Deep directory structure ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_sync "$WORKDIR")"

# Tenant level: test-tenant (test-tenant-id)
TENANT_DIR="$WORKDIR/.qlik-sync/test-tenant (test-tenant-id)"
assert_dir_exists "tenant dir with ID" "$TENANT_DIR"

# Space type level
assert_dir_exists "managed type dir" "$TENANT_DIR/managed"
assert_dir_exists "shared type dir" "$TENANT_DIR/shared"
assert_dir_exists "personal type dir" "$TENANT_DIR/personal"

# Space level with full ID: Finance Prod is managed (space-001)
assert_dir_exists "Finance Prod space dir" "$TENANT_DIR/managed/Finance Prod (space-001)"

# HR Dev is shared (space-002)
assert_dir_exists "HR Dev space dir" "$TENANT_DIR/shared/HR Dev (space-002)"

# App type level
assert_dir_exists "analytics app type" "$TENANT_DIR/managed/Finance Prod (space-001)/analytics"

# App level with full resourceId
assert_file_exists "app-001 Sales Dashboard" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/config.yml"
assert_file_exists "app-002 HR Analytics" \
  "$TENANT_DIR/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)/config.yml"
assert_file_exists "app-003 Sales Dashboard DEV" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/analytics/Sales Dashboard DEV (app-003)/config.yml"

# app-004 should be dataflow-prep type
assert_file_exists "app-004 Finance Extract (dataflow-prep)" \
  "$TENANT_DIR/managed/Finance Prod (space-001)/dataflow-prep/Finance Extract (app-004)/config.yml"

assert_file_exists "app-005 HR Transform" \
  "$TENANT_DIR/shared/HR Dev (space-002)/analytics/HR Transform (app-005)/config.yml"

# app-006 personal space, data-preparation type
assert_file_exists "app-006 Personal ETL (personal space)" \
  "$TENANT_DIR/personal/testuser (user-001)/data-preparation/Personal ETL (app-006)/config.yml"

# Test 3: Index file
echo ""
echo "--- Test 3: Index file ---"
INDEX="$WORKDIR/.qlik-sync/index.json"
assert_file_exists "index.json exists" "$INDEX"
assert_json_field "appCount is 6" "$INDEX" ".appCount" "6"
assert_json_field "tenant is test-tenant" "$INDEX" ".tenant" "test-tenant"
assert_json_field "tenantId present" "$INDEX" ".tenantId" "test-tenant-id"

# Check new index fields
assert_json_field "app-001 spaceType" "$INDEX" '.apps["app-001"].spaceType' "managed"
assert_json_field "app-002 spaceType" "$INDEX" '.apps["app-002"].spaceType' "shared"
assert_json_field "app-006 spaceType" "$INDEX" '.apps["app-006"].spaceType' "personal"
assert_json_field "app-001 appType" "$INDEX" '.apps["app-001"].appType' "analytics"
assert_json_field "app-004 appType" "$INDEX" '.apps["app-004"].appType' "dataflow-prep"
assert_json_field "app-006 appType" "$INDEX" '.apps["app-006"].appType' "data-preparation"
assert_json_field "app-006 ownerName" "$INDEX" '.apps["app-006"].ownerName' "testuser"

# Check path reflects deep hierarchy
assert_json_field "app-001 path" "$INDEX" '.apps["app-001"].path' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/"

# Test 4: Resume
echo ""
echo "--- Test 4: Resume (skip existing) ---"
OUTPUT2="$(run_sync "$WORKDIR")"
assert_contains "resume has SKIP" "$OUTPUT2" "SKIP"

# Test 5: Force
echo ""
echo "--- Test 5: Force re-sync ---"
OUTPUT3="$(run_sync "$WORKDIR" --force)"
assert_contains "force has Syncing" "$OUTPUT3" "Syncing"
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$OUTPUT3" | grep -q "SKIP"; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: force should not have SKIP"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: force has no SKIP"
fi

# Test 6: Space filter
echo ""
echo "--- Test 6: Space filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT4="$(run_sync "$WORKDIR2" --space "Finance Prod")"
assert_json_field "filtered appCount is 3" "$WORKDIR2/.qlik-sync/index.json" ".appCount" "3"

# Test 7: lastSync
echo ""
echo "--- Test 7: lastSync updated ---"
LASTSYNC="$(jq -r '.lastSync' "$WORKDIR/.qlik-sync/config.json")"
TESTS_RUN=$((TESTS_RUN + 1))
if [ "$LASTSYNC" != "null" ] && [ -n "$LASTSYNC" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: lastSync is set ($LASTSYNC)"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: lastSync not set"
fi

test_summary
```

- [ ] **Step 2: Run tests**

Run: `bash tests/test-sync-script.sh`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test-sync-script.sh
git commit -m "test(qlik): rewrite sync script tests for deep hierarchy"
git push
```

---

## Task 4: Add CLI Whitelist to All Skills

**Files:**
- Modify: `skills/setup/SKILL.md`
- Modify: `skills/sync/SKILL.md`
- Modify: `skills/inspect/SKILL.md`

- [ ] **Step 1: Add `allowed-tools` to `skills/setup/SKILL.md`**

Read the file. Add `allowed-tools` to the YAML frontmatter between `description:` and the closing `---`:

```yaml
allowed-tools:
  - Bash(which:*)
  - Bash(qlik context:*)
  - Bash(qlik app ls:*)
  - Bash(qlik version:*)
  - Bash(mkdir:*)
  - Bash(grep:*)
  - Read
  - Write
```

- [ ] **Step 2: Add `allowed-tools` to `skills/sync/SKILL.md`**

Read the file. Add to frontmatter:

```yaml
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh:*)"
  - Bash(qlik app ls:*)
  - Read
```

- [ ] **Step 3: Update output structure docs in `skills/sync/SKILL.md`**

Find the "Output Structure" section and replace the directory tree with:

```
.qlik-sync/
├── config.json
├── index.json
└── <tenant-domain> (<tenantId>)/
    ├── shared/
    │   └── <space-name> (<spaceId>)/
    │       └── analytics/
    │           └── <app-name> (<full-resourceId>)/
    │               ├── script.qvs
    │               └── ...
    ├── managed/
    │   └── ...
    ├── data/
    │   └── ...
    ├── personal/
    │   └── <username> (<ownerId>)/
    │       └── analytics/
    │           └── ...
    └── unknown/
        └── <spaceId>/
            └── ...
```

- [ ] **Step 4: Add `allowed-tools` to `skills/inspect/SKILL.md`**

Read the file. Add to frontmatter:

```yaml
allowed-tools:
  - Read
  - Glob
  - Grep
```

- [ ] **Step 5: Run all skill tests**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-inspect.sh`
Expected: All PASS (grep-based tests check content, frontmatter additions don't break them)

- [ ] **Step 6: Commit**

```bash
git add skills/setup/SKILL.md skills/sync/SKILL.md skills/inspect/SKILL.md
git commit -m "feat(qlik): add CLI whitelist via allowed-tools to all skills"
git push
```

---

## Task 5: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-sync-script.sh && bash tests/test-inspect.sh && bash tests/test-project.sh`
Expected: All pass

- [ ] **Step 2: Verify git log**

Run: `git log --oneline -6`
Expected: Clean conventional commits.

- [ ] **Step 3: Update PR description**

Update mattiasthalen/qlik-plugin#1 with final status including deep hierarchy and CLI whitelist.
