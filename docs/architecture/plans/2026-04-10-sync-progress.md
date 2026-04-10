# Sync Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure sync from monolithic script into skill-driven loop with three phases (prep/app/finalize), giving users real-time progress and ETA during sync.

**Architecture:** Split `sync-tenant.sh` into `sync-prep.sh` (fetch + resolve → JSON), `sync-app.sh` (unbuild one app), and `sync-finalize.sh` (build index + update config). Update `sync-tenant.sh` as convenience wrapper calling all three. Update `SKILL.md` so Claude drives the loop and reports progress between each app.

**Tech Stack:** Bash, jq, qlik-cli. Tests use existing `helpers.sh` assertion library and `mock-qlik/` fixtures.

**Spec:** `docs/architecture/specs/2026-04-10-sync-progress-design.md`
**Decision doc:** `docs/architecture/decisions/2026-04-10-sync-progress-decision.md`
**Worktree:** `.worktrees/fix/sync-progress` (branch: `fix/sync-progress`)
**Draft PR:** #8

---

### Task 1: sync-prep.sh — config reading and dependency checks

Extract config reading and dependency checking from `sync-tenant.sh` into `sync-prep.sh`.

**Files:**
- Create: `skills/sync/scripts/sync-prep.sh`
- Create: `tests/test-sync-prep.sh`

- [ ] **Step 1: Write failing test — config not found**

Create `tests/test-sync-prep.sh`:

```bash
#!/bin/bash
# Tests for sync-prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-prep.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com"
}
JSON
  echo "$workdir"
}

run_prep() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" "$@" 2>/dev/null)
}

run_prep_stderr() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" "$@" 2>&1 1>/dev/null)
}

echo "=== sync-prep.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-prep.sh exists" "$PREP_SCRIPT"

# Test 2: Fails without config
echo ""
echo "--- Test 2: Fails without config ---"
NO_CONFIG_DIR="$TMPDIR_BASE/no-config-$$"
mkdir -p "$NO_CONFIG_DIR"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$NO_CONFIG_DIR" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero without config"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero without config"
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-prep.sh`
Expected: FAIL — `sync-prep.sh exists` fails (file not found)

- [ ] **Step 3: Write minimal sync-prep.sh — config reading**

Create `skills/sync/scripts/sync-prep.sh`:

```bash
#!/bin/bash
# sync-prep.sh — Fetch and resolve Qlik app list for sync
# Usage: sync-prep.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
# Outputs JSON to stdout with app list and resolved metadata
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
      echo "Usage: sync-prep.sh [--space \"Name\"] [--app \"Pattern\"] [--id <GUID>] [--force]" >&2
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

TENANT_DOMAIN="$(echo "$SERVER" | sed -E 's|https?://(.+)\.qlikcloud\.com.*|\1|')"

# --- Check dependencies ---
for cmd in qlik jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found on PATH." >&2
    exit 1
  fi
done

# Placeholder — will output JSON in next tasks
echo "{}"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-prep.sh`
Expected: 3/3 passed, 0 failed

- [ ] **Step 5: Commit**

```bash
chmod +x skills/sync/scripts/sync-prep.sh
git add skills/sync/scripts/sync-prep.sh tests/test-sync-prep.sh
git commit -m "feat(sync): add sync-prep.sh with config reading and tests"
git push
```

---

### Task 2: sync-prep.sh — space resolution and app fetching

Add space lookup, app fetching with filters, and space resolution.

**Files:**
- Modify: `skills/sync/scripts/sync-prep.sh`
- Modify: `tests/test-sync-prep.sh`

- [ ] **Step 1: Write failing test — full JSON output**

Append to `tests/test-sync-prep.sh` (before `test_summary`):

```bash
# Test 3: Full sync outputs valid JSON with all apps
echo ""
echo "--- Test 3: Full sync JSON output ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_prep "$WORKDIR")"

# Validate JSON structure
TESTS_RUN=$((TESTS_RUN + 1))
if echo "$OUTPUT" | jq -e '.tenant' >/dev/null 2>&1; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: output is valid JSON with tenant field"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: output is not valid JSON or missing tenant"
fi

# Save to temp for field checks
PREP_JSON="$TMPDIR_BASE/prep-output.json"
echo "$OUTPUT" > "$PREP_JSON"

assert_json_field "tenant is test-tenant" "$PREP_JSON" ".tenant" "test-tenant"
assert_json_field "tenantId is test-tenant-id" "$PREP_JSON" ".tenantId" "test-tenant-id"
assert_json_field "totalApps is 6" "$PREP_JSON" ".totalApps" "6"
assert_json_field "server correct" "$PREP_JSON" ".server" "https://test-tenant.qlikcloud.com"
assert_json_field "context correct" "$PREP_JSON" ".context" "test-ctx"

# Check first app has required fields
assert_json_field "app-001 name" "$PREP_JSON" '.apps[0].name' "Sales Dashboard"
assert_json_field "app-001 resourceId" "$PREP_JSON" '.apps[0].resourceId' "app-001"
assert_json_field "app-001 spaceName" "$PREP_JSON" '.apps[0].spaceName' "Finance Prod"
assert_json_field "app-001 spaceType" "$PREP_JSON" '.apps[0].spaceType' "managed"
assert_json_field "app-001 appType" "$PREP_JSON" '.apps[0].appType' "analytics"
assert_json_field "app-001 skip is false" "$PREP_JSON" '.apps[0].skip' "false"
assert_json_field "app-001 targetPath" "$PREP_JSON" '.apps[0].targetPath' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)"

# Check personal space app
PERSONAL_APP="$(echo "$OUTPUT" | jq -r '.apps[] | select(.resourceId == "app-006")')"
PERSONAL_JSON="$TMPDIR_BASE/personal-app.json"
echo "$PERSONAL_APP" > "$PERSONAL_JSON"
assert_json_field "app-006 spaceType is personal" "$PERSONAL_JSON" ".spaceType" "personal"
assert_json_field "app-006 appType is data-preparation" "$PERSONAL_JSON" ".appType" "data-preparation"
assert_json_field "app-006 ownerName" "$PERSONAL_JSON" ".ownerName" "testuser"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-prep.sh`
Expected: FAIL — output is `{}`, not valid JSON with tenant field

- [ ] **Step 3: Implement full prep logic**

Replace the placeholder `echo "{}"` at end of `sync-prep.sh` with the full space resolution, app fetching, and JSON output logic:

```bash
# --- Fetch spaces and build lookup ---
SPACES_JSON="$(qlik space ls --json)"

SPACE_LOOKUP="$(mktemp)"
USER_CACHE="$(mktemp)"
APPS_FILE="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$APPS_FILE"' EXIT

echo "$SPACES_JSON" | jq -r '.[] | "\(.id)\t\(.name)\t\(.type)"' > "$SPACE_LOOKUP"

resolve_space_name() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo ""
    return
  fi
  grep "^${space_id}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f2 || true
}

resolve_space_type() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo "personal"
    return
  fi
  local stype
  stype="$(grep "^${space_id}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f3 || true)"
  if [ -n "$stype" ]; then
    echo "$stype"
  else
    echo "unknown"
  fi
}

resolve_username() {
  local user_id="$1"
  local cached
  cached="$(grep "^${user_id}	" "$USER_CACHE" 2>/dev/null | cut -f2 || true)"
  if [ -n "$cached" ]; then
    echo "$cached"
    return
  fi
  local uname
  uname="$(qlik user get "$user_id" --json < /dev/null 2>/dev/null | jq -r '.name // .email // empty')"
  if [ -z "$uname" ]; then
    uname="$user_id"
  fi
  printf '%s\t%s\n' "$user_id" "$uname" >> "$USER_CACHE"
  echo "$uname"
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

# --- Resolve space ID for space filter ---
SPACE_ID_FILTER=""
if [ -n "$SPACE_FILTER" ]; then
  SPACE_ID_FILTER="$(grep "	${SPACE_FILTER}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f1 || true)"
  if [ -z "$SPACE_ID_FILTER" ]; then
    echo "Error: space '$SPACE_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
if [ -n "$ID_FILTER" ]; then
  qlik app ls --json --limit 1000 | jq "[.[] | select(.resourceId == \"$ID_FILTER\")]" > "$APPS_FILE"
elif [ -n "$SPACE_ID_FILTER" ]; then
  qlik app ls --json --limit 1000 --spaceId "$SPACE_ID_FILTER" > "$APPS_FILE"
else
  qlik app ls --json --limit 1000 > "$APPS_FILE"
fi

if [ -n "$APP_FILTER" ]; then
  jq "[.[] | select(.name | test(\"$APP_FILTER\"))]" "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

APP_COUNT="$(jq 'length' "$APPS_FILE")"

if [ "$APP_COUNT" -eq 0 ]; then
  echo '{"tenant":"","tenantId":"","context":"'"$CONTEXT"'","server":"'"$SERVER"'","totalApps":0,"apps":[]}'
  exit 0
fi

TENANT_ID="$(jq -r '.[0].tenantId // empty' "$APPS_FILE")"
TENANT_DIR="$TENANT_DOMAIN ($TENANT_ID)"

# --- Build app entries ---
APP_ENTRIES="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$APPS_FILE" "$APP_ENTRIES"' EXIT

while IFS= read -r app_line; do
  resource_id="$(jq -r '.resourceId' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  space_id="$(jq -r '.resourceAttributes.spaceId // empty' <<< "$app_line")"
  owner_id="$(jq -r '.resourceAttributes.ownerId // empty' <<< "$app_line")"
  description="$(jq -r '.resourceAttributes.description // empty' <<< "$app_line")"
  published="$(jq -r '.resourceAttributes.published // false' <<< "$app_line")"
  last_reload="$(jq -r '.resourceAttributes.lastReloadTime // empty' <<< "$app_line")"
  usage="$(jq -r '.resourceAttributes.usage // "ANALYTICS"' <<< "$app_line")"
  tags="$(jq -c '[.meta.tags[]?.name]' <<< "$app_line")"

  space_type="$(resolve_space_type "$space_id")"
  space_name="$(resolve_space_name "$space_id")"
  app_type="$(normalize_app_type "$usage")"

  if [ "$space_type" = "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
    space_folder="$(sanitize "$owner_name") ($owner_id)"
  elif [ "$space_type" = "unknown" ]; then
    space_folder="$space_id"
    space_name="$space_id"
    owner_name="$(resolve_username "$owner_id")"
  else
    space_folder="$(sanitize "$space_name") ($space_id)"
    owner_name="$(resolve_username "$owner_id")"
  fi

  safe_app="$(sanitize "$app_name")"
  app_folder="$safe_app ($resource_id)"

  target_path="$TENANT_DIR/$space_type/$space_folder/$app_type/$app_folder"
  full_path=".qlik-sync/$target_path"

  # Resume check
  skip=false
  skip_reason=""
  if [ "$FORCE" = false ] && [ -f "$full_path/config.yml" ]; then
    skip=true
    skip_reason="already synced (use --force to re-sync)"
  fi

  jq -n \
    --arg resourceId "$resource_id" \
    --arg name "$app_name" \
    --arg spaceId "$space_id" \
    --arg spaceName "$space_name" \
    --arg spaceType "$space_type" \
    --arg appType "$app_type" \
    --arg ownerId "$owner_id" \
    --arg ownerName "$owner_name" \
    --arg description "$description" \
    --argjson tags "$tags" \
    --argjson published "$published" \
    --arg lastReloadTime "$last_reload" \
    --arg targetPath "$target_path" \
    --argjson skip "$skip" \
    --arg skipReason "$skip_reason" \
    '{resourceId: $resourceId, name: $name, spaceId: $spaceId, spaceName: $spaceName, spaceType: $spaceType, appType: $appType, ownerId: $ownerId, ownerName: $ownerName, description: $description, tags: $tags, published: $published, lastReloadTime: $lastReloadTime, targetPath: $targetPath, skip: $skip, skipReason: $skipReason}' \
    >> "$APP_ENTRIES"

done < <(jq -c '.[]' "$APPS_FILE")

# --- Output final JSON ---
jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "$TENANT_ID" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}' \
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-prep.sh`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add skills/sync/scripts/sync-prep.sh tests/test-sync-prep.sh
git commit -m "feat(sync): add space resolution and app fetching to sync-prep.sh"
git push
```

---

### Task 3: sync-prep.sh — filters and skip logic

Test space, app, ID filters and the `--force` flag.

**Files:**
- Modify: `tests/test-sync-prep.sh`

- [ ] **Step 1: Write failing tests — filters**

Append to `tests/test-sync-prep.sh` (before `test_summary`):

```bash
# Test 4: Space filter
echo ""
echo "--- Test 4: Space filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT2="$(run_prep "$WORKDIR2" --space "Finance Prod")"
PREP_JSON2="$TMPDIR_BASE/prep-space.json"
echo "$OUTPUT2" > "$PREP_JSON2"
assert_json_field "space filter totalApps is 3" "$PREP_JSON2" ".totalApps" "3"

# All apps should be in Finance Prod
TESTS_RUN=$((TESTS_RUN + 1))
ALL_FINANCE="$(jq '[.apps[] | select(.spaceName == "Finance Prod")] | length' "$PREP_JSON2")"
if [ "$ALL_FINANCE" = "3" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: all 3 apps are in Finance Prod"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 3 Finance Prod apps, got $ALL_FINANCE"
fi

# Test 5: App name filter
echo ""
echo "--- Test 5: App name filter ---"
WORKDIR3="$(setup_workdir)"
OUTPUT3="$(run_prep "$WORKDIR3" --app "Sales")"
PREP_JSON3="$TMPDIR_BASE/prep-app.json"
echo "$OUTPUT3" > "$PREP_JSON3"
assert_json_field "app filter totalApps is 2" "$PREP_JSON3" ".totalApps" "2"

# Test 6: ID filter
echo ""
echo "--- Test 6: ID filter ---"
WORKDIR4="$(setup_workdir)"
OUTPUT4="$(run_prep "$WORKDIR4" --id "app-003")"
PREP_JSON4="$TMPDIR_BASE/prep-id.json"
echo "$OUTPUT4" > "$PREP_JSON4"
assert_json_field "id filter totalApps is 1" "$PREP_JSON4" ".totalApps" "1"
assert_json_field "id filter correct app" "$PREP_JSON4" '.apps[0].resourceId' "app-003"

# Test 7: Resume skip
echo ""
echo "--- Test 7: Resume marks skip ---"
WORKDIR5="$(setup_workdir)"
# First run to create files
(cd "$WORKDIR5" && PATH="$MOCK_DIR:$PATH" bash "$REPO_ROOT/skills/sync/scripts/sync-tenant.sh" 2>/dev/null) >/dev/null
# Now prep should mark all as skip
OUTPUT5="$(run_prep "$WORKDIR5")"
PREP_JSON5="$TMPDIR_BASE/prep-skip.json"
echo "$OUTPUT5" > "$PREP_JSON5"
SKIP_COUNT="$(jq '[.apps[] | select(.skip == true)] | length' "$PREP_JSON5")"
assert_eq "all 6 apps marked skip" "6" "$SKIP_COUNT"

# Test 8: Force overrides skip
echo ""
echo "--- Test 8: Force overrides skip ---"
OUTPUT6="$(run_prep "$WORKDIR5" --force)"
PREP_JSON6="$TMPDIR_BASE/prep-force.json"
echo "$OUTPUT6" > "$PREP_JSON6"
SKIP_COUNT2="$(jq '[.apps[] | select(.skip == true)] | length' "$PREP_JSON6")"
assert_eq "force: 0 apps marked skip" "0" "$SKIP_COUNT2"
```

- [ ] **Step 2: Run test to verify new tests pass**

Run: `bash tests/test-sync-prep.sh`
Expected: All tests pass (filters already implemented in Task 2)

- [ ] **Step 3: Commit**

```bash
git add tests/test-sync-prep.sh
git commit -m "test(sync): add filter and skip tests for sync-prep.sh"
git push
```

---

### Task 4: sync-app.sh

Create the single-app sync script.

**Files:**
- Create: `skills/sync/scripts/sync-app.sh`
- Create: `tests/test-sync-app.sh`

- [ ] **Step 1: Write failing tests**

Create `tests/test-sync-app.sh`:

```bash
#!/bin/bash
# Tests for sync-app.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

APP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-app.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-app.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-app.sh exists" "$APP_SCRIPT"

# Test 2: Syncs single app successfully
echo ""
echo "--- Test 2: Successful sync ---"
WORKDIR="$TMPDIR_BASE/test-sync-app"
mkdir -p "$WORKDIR/.qlik-sync"
TARGET="test-tenant (tid)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR" && PATH="$MOCK_DIR:$PATH" bash "$APP_SCRIPT" "app-001" "$TARGET" 2>/dev/null); then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits 0 on success"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit 0 on success"
fi

# Verify directory and files created
assert_dir_exists "target dir created" "$WORKDIR/.qlik-sync/$TARGET"
assert_file_exists "config.yml created" "$WORKDIR/.qlik-sync/$TARGET/config.yml"
assert_file_exists "script.qvs created" "$WORKDIR/.qlik-sync/$TARGET/script.qvs"

# Test 3: No stdout output
echo ""
echo "--- Test 3: No stdout output ---"
WORKDIR2="$TMPDIR_BASE/test-sync-app-stdout"
mkdir -p "$WORKDIR2/.qlik-sync"
TARGET2="test-tenant (tid)/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)"
STDOUT="$(cd "$WORKDIR2" && PATH="$MOCK_DIR:$PATH" bash "$APP_SCRIPT" "app-002" "$TARGET2" 2>/dev/null)"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -z "$STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: no stdout output"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: unexpected stdout: $STDOUT"
fi

# Test 4: Fails gracefully on bad app ID
echo ""
echo "--- Test 4: Fails on unbuild error ---"
WORKDIR3="$TMPDIR_BASE/test-sync-app-fail"
mkdir -p "$WORKDIR3/.qlik-sync"
# Use a mock that will fail — we need to create a failing mock
FAIL_MOCK="$TMPDIR_BASE/fail-mock"
mkdir -p "$FAIL_MOCK"
cat > "$FAIL_MOCK/qlik" <<'MOCK'
#!/bin/bash
echo "Error: app not found" >&2
exit 1
MOCK
chmod +x "$FAIL_MOCK/qlik"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR3" && PATH="$FAIL_MOCK:$PATH" bash "$APP_SCRIPT" "bad-id" "some/path" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero on unbuild failure"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero on unbuild failure"
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-app.sh`
Expected: FAIL — `sync-app.sh exists` fails

- [ ] **Step 3: Implement sync-app.sh**

Create `skills/sync/scripts/sync-app.sh`:

```bash
#!/bin/bash
# sync-app.sh — Sync a single Qlik app (mkdir + unbuild)
# Usage: sync-app.sh <resourceId> <targetPath>
# stdout: nothing (skill handles all user-facing output)
# stderr: error details if unbuild fails
# exit 0: success, exit 1: failure
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-app.sh <resourceId> <targetPath>" >&2
  exit 1
fi

RESOURCE_ID="$1"
TARGET_PATH="$2"
FULL_PATH=".qlik-sync/$TARGET_PATH"

mkdir -p "$FULL_PATH"
qlik app unbuild --app "$RESOURCE_ID" --dir "$FULL_PATH" < /dev/null >/dev/null 2>&1
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-app.sh`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
chmod +x skills/sync/scripts/sync-app.sh
git add skills/sync/scripts/sync-app.sh tests/test-sync-app.sh
git commit -m "feat(sync): add sync-app.sh for single-app sync"
git push
```

---

### Task 5: sync-finalize.sh

Create the finalization script that builds index.json and updates config.

**Files:**
- Create: `skills/sync/scripts/sync-finalize.sh`
- Create: `tests/test-sync-finalize.sh`

- [ ] **Step 1: Write failing tests**

Create `tests/test-sync-finalize.sh`:

```bash
#!/bin/bash
# Tests for sync-finalize.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

FINALIZE_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-finalize.sh"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-finalize.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-finalize.sh exists" "$FINALIZE_SCRIPT"

# Test 2: Builds index.json from prep + results
echo ""
echo "--- Test 2: Builds index.json ---"
WORKDIR="$TMPDIR_BASE/test-finalize"
mkdir -p "$WORKDIR/.qlik-sync"
cat > "$WORKDIR/.qlik-sync/config.json" <<'JSON'
{
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com"
}
JSON

PREP_FILE="$TMPDIR_BASE/prep.json"
cat > "$PREP_FILE" <<'JSON'
{
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "totalApps": 3,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "Monthly sales KPIs",
      "tags": ["finance", "monthly"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    },
    {
      "resourceId": "app-002",
      "name": "HR Analytics",
      "spaceId": "space-002",
      "spaceName": "HR Dev",
      "spaceType": "shared",
      "appType": "analytics",
      "ownerId": "user-002",
      "ownerName": "hradmin",
      "description": "Employee metrics",
      "tags": ["hr"],
      "published": true,
      "lastReloadTime": "2026-04-07T12:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/shared/HR Dev (space-002)/analytics/HR Analytics (app-002)",
      "skip": true,
      "skipReason": "already synced"
    },
    {
      "resourceId": "app-003",
      "name": "Bad App",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "",
      "tags": [],
      "published": false,
      "lastReloadTime": "",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Bad App (app-003)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_FILE="$TMPDIR_BASE/results.json"
cat > "$RESULTS_FILE" <<'JSON'
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "skipped"},
  {"resourceId": "app-003", "status": "error", "error": "unbuild failed"}
]
JSON

OUTPUT="$(cd "$WORKDIR" && bash "$FINALIZE_SCRIPT" "$PREP_FILE" "$RESULTS_FILE")"

INDEX="$WORKDIR/.qlik-sync/index.json"
assert_file_exists "index.json created" "$INDEX"
assert_json_field "appCount is 3" "$INDEX" ".appCount" "3"
assert_json_field "tenant correct" "$INDEX" ".tenant" "test-tenant"
assert_json_field "tenantId correct" "$INDEX" ".tenantId" "test-tenant-id"
assert_json_field "app-001 name" "$INDEX" '.apps["app-001"].name' "Sales Dashboard"
assert_json_field "app-001 path" "$INDEX" '.apps["app-001"].path' \
  "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/"
assert_json_field "app-002 present" "$INDEX" '.apps["app-002"].name' "HR Analytics"

# Check lastSync updated in config
CONFIG="$WORKDIR/.qlik-sync/config.json"
TESTS_RUN=$((TESTS_RUN + 1))
LAST_SYNC="$(jq -r '.lastSync' "$CONFIG")"
if [ "$LAST_SYNC" != "null" ] && [ -n "$LAST_SYNC" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: config.json lastSync updated"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: config.json lastSync not updated"
fi

# Check summary output
assert_contains "summary has synced count" "$OUTPUT" "1 synced"
assert_contains "summary has skipped count" "$OUTPUT" "1 skipped"
assert_contains "summary has error count" "$OUTPUT" "1 error"

# Test 3: Partial sync merges with existing index
echo ""
echo "--- Test 3: Partial sync merges ---"
WORKDIR2="$TMPDIR_BASE/test-finalize-merge"
mkdir -p "$WORKDIR2/.qlik-sync"
cat > "$WORKDIR2/.qlik-sync/config.json" <<'JSON'
{"context": "test-ctx", "server": "https://test-tenant.qlikcloud.com"}
JSON

# Pre-existing index with app-099
cat > "$WORKDIR2/.qlik-sync/index.json" <<'JSON'
{
  "lastSync": "2026-04-09T00:00:00Z",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "appCount": 1,
  "apps": {
    "app-099": {
      "name": "Old App",
      "space": "Other Space",
      "spaceId": "space-099",
      "spaceType": "shared",
      "appType": "analytics",
      "owner": "user-099",
      "ownerName": "olduser",
      "description": "",
      "tags": [],
      "published": false,
      "lastReloadTime": "",
      "path": "test-tenant (test-tenant-id)/shared/Other Space (space-099)/analytics/Old App (app-099)/"
    }
  }
}
JSON

PREP_PARTIAL="$TMPDIR_BASE/prep-partial.json"
cat > "$PREP_PARTIAL" <<'JSON'
{
  "tenant": "test-tenant",
  "tenantId": "test-tenant-id",
  "context": "test-ctx",
  "server": "https://test-tenant.qlikcloud.com",
  "totalApps": 1,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "testuser",
      "description": "Monthly sales KPIs",
      "tags": ["finance"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_PARTIAL="$TMPDIR_BASE/results-partial.json"
cat > "$RESULTS_PARTIAL" <<'JSON'
[{"resourceId": "app-001", "status": "synced"}]
JSON

(cd "$WORKDIR2" && bash "$FINALIZE_SCRIPT" "$PREP_PARTIAL" "$RESULTS_PARTIAL") >/dev/null

INDEX2="$WORKDIR2/.qlik-sync/index.json"
assert_json_field "merged appCount is 2" "$INDEX2" ".appCount" "2"
assert_json_field "old app-099 preserved" "$INDEX2" '.apps["app-099"].name' "Old App"
assert_json_field "new app-001 added" "$INDEX2" '.apps["app-001"].name' "Sales Dashboard"

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-finalize.sh`
Expected: FAIL — `sync-finalize.sh exists` fails

- [ ] **Step 3: Implement sync-finalize.sh**

Create `skills/sync/scripts/sync-finalize.sh`:

```bash
#!/bin/bash
# sync-finalize.sh — Build/merge index.json and update config
# Usage: sync-finalize.sh <prep-json-file> <results-json-file>
# stdout: summary line
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-finalize.sh <prep-json-file> <results-json-file>" >&2
  exit 1
fi

PREP_FILE="$1"
RESULTS_FILE="$2"
CONFIG_FILE=".qlik-sync/config.json"
INDEX_FILE=".qlik-sync/index.json"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Read prep metadata
TENANT="$(jq -r '.tenant' "$PREP_FILE")"
TENANT_ID="$(jq -r '.tenantId' "$PREP_FILE")"
CONTEXT="$(jq -r '.context' "$PREP_FILE")"
SERVER="$(jq -r '.server' "$PREP_FILE")"
TOTAL_APPS="$(jq -r '.totalApps' "$PREP_FILE")"

# Build apps object from prep data
# Each app entry keyed by resourceId, with trailing slash on path
APPS_OBJ="$(jq '
  [.apps[] | {
    key: .resourceId,
    value: {
      name: .name,
      space: .spaceName,
      spaceId: .spaceId,
      spaceType: .spaceType,
      appType: .appType,
      owner: .ownerId,
      ownerName: .ownerName,
      description: .description,
      tags: .tags,
      published: .published,
      lastReloadTime: .lastReloadTime,
      path: (.targetPath + "/")
    }
  }] | from_entries
' "$PREP_FILE")"

# Merge with existing index if partial sync
if [ "$TOTAL_APPS" -lt "$(jq '.appCount // 0' "$INDEX_FILE" 2>/dev/null || echo 0)" ] && [ -f "$INDEX_FILE" ]; then
  EXISTING_APPS="$(jq '.apps // {}' "$INDEX_FILE")"
  APPS_OBJ="$(jq -n --argjson existing "$EXISTING_APPS" --argjson new "$APPS_OBJ" '$existing + $new')"
fi

FINAL_COUNT="$(echo "$APPS_OBJ" | jq 'length')"

# Write index.json
jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT" \
  --arg tenantId "$TENANT_ID" \
  --argjson appCount "$FINAL_COUNT" \
  --argjson apps "$APPS_OBJ" \
  '{lastSync: $lastSync, context: $context, server: $server, tenant: $tenant, tenantId: $tenantId, appCount: $appCount, apps: $apps}' \
  > "$INDEX_FILE"

# Update config.json
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Summary from results
SYNCED="$(jq '[.[] | select(.status == "synced")] | length' "$RESULTS_FILE")"
SKIPPED="$(jq '[.[] | select(.status == "skipped")] | length' "$RESULTS_FILE")"
ERRORS="$(jq '[.[] | select(.status == "error")] | length' "$RESULTS_FILE")"

echo "Sync complete: $SYNCED synced, $SKIPPED skipped, $ERRORS errors (${FINAL_COUNT} apps in index)"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-finalize.sh`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
chmod +x skills/sync/scripts/sync-finalize.sh
git add skills/sync/scripts/sync-finalize.sh tests/test-sync-finalize.sh
git commit -m "feat(sync): add sync-finalize.sh for index building"
git push
```

---

### Task 6: Update sync-tenant.sh as wrapper

Refactor `sync-tenant.sh` to call the three phase scripts.

**Files:**
- Modify: `skills/sync/scripts/sync-tenant.sh`
- Modify: `tests/test-sync-script.sh` (existing tests must still pass)

- [ ] **Step 1: Run existing tests to confirm baseline**

Run: `bash tests/test-sync-script.sh`
Expected: 33/33 passed, 0 failed

- [ ] **Step 2: Rewrite sync-tenant.sh as wrapper**

Replace entire `skills/sync/scripts/sync-tenant.sh` with:

```bash
#!/bin/bash
# sync-tenant.sh — Sync Qlik Cloud apps to local filesystem
# Convenience wrapper that calls sync-prep.sh, sync-app.sh, sync-finalize.sh
# Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Run prep phase ---
PREP_FILE="$(mktemp)"
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$PREP_FILE" "$RESULTS_FILE"' EXIT

bash "$SCRIPT_DIR/sync-prep.sh" "$@" > "$PREP_FILE"

TOTAL_APPS="$(jq '.totalApps' "$PREP_FILE")"

if [ "$TOTAL_APPS" -eq 0 ]; then
  echo "No apps found matching filters."
  exit 0
fi

# --- Sync loop ---
IDX=0
echo "[]" > "$RESULTS_FILE"

while IFS= read -r app_line; do
  IDX=$((IDX + 1))

  resource_id="$(jq -r '.resourceId' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  space_name="$(jq -r '.spaceName' <<< "$app_line")"
  space_type="$(jq -r '.spaceType' <<< "$app_line")"
  owner_name="$(jq -r '.ownerName' <<< "$app_line")"
  target_path="$(jq -r '.targetPath' <<< "$app_line")"
  skip="$(jq -r '.skip' <<< "$app_line")"

  # Display space
  if [ "$space_type" = "personal" ]; then
    display_space="personal/$owner_name"
  elif [ "$space_type" = "unknown" ]; then
    display_space="unknown/$(jq -r '.spaceId' <<< "$app_line")"
  else
    display_space="$space_type/$space_name"
  fi

  if [ "$skip" = "true" ]; then
    echo "[$IDX/$TOTAL_APPS] SKIP: $display_space / $app_name"
    jq --arg id "$resource_id" '. + [{resourceId: $id, status: "skipped"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
  else
    echo "[$IDX/$TOTAL_APPS] Syncing: $display_space / $app_name..."
    if bash "$SCRIPT_DIR/sync-app.sh" "$resource_id" "$target_path" 2>/dev/null; then
      jq --arg id "$resource_id" '. + [{resourceId: $id, status: "synced"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    else
      echo "  WARNING: Failed to unbuild $app_name ($resource_id)" >&2
      jq --arg id "$resource_id" --arg err "unbuild failed" '. + [{resourceId: $id, status: "error", error: $err}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    fi
  fi

done < <(jq -c '.apps[]' "$PREP_FILE")

# --- Finalize ---
echo ""
bash "$SCRIPT_DIR/sync-finalize.sh" "$PREP_FILE" "$RESULTS_FILE"
```

- [ ] **Step 3: Run existing tests to verify wrapper works**

Run: `bash tests/test-sync-script.sh`
Expected: 33/33 passed, 0 failed

- [ ] **Step 4: Commit**

```bash
git add skills/sync/scripts/sync-tenant.sh
git commit -m "refactor(sync): rewrite sync-tenant.sh as wrapper over prep/app/finalize"
git push
```

---

### Task 7: Update SKILL.md

Update the sync skill to use the new three-phase approach with progress reporting.

**Files:**
- Modify: `skills/sync/SKILL.md`
- Modify: `tests/test-sync.sh`

- [ ] **Step 1: Run existing sync SKILL.md tests**

Run: `bash tests/test-sync.sh`
Expected: 17/17 passed, 0 failed

- [ ] **Step 2: Update SKILL.md**

Replace entire `skills/sync/SKILL.md` with:

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
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep.json:*)"
  - "Bash(cat /tmp/qlik-sync-results.json:*)"
  - "Bash(echo:*)"
  - Bash(qlik app ls:*)
  - Bash(date:*)
  - Read
  - Write
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

## Step 3: Run Prep

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh [flags] > /tmp/qlik-sync-prep.json
cat /tmp/qlik-sync-prep.json
```

Read the JSON output. Report to the user:
> Found **N** apps (**X** to sync, **Y** already synced)

## Step 4: Sync Loop with Progress

Loop through each app in the prep JSON. Track timing for ETA.

Initialize a results array. For each app:

1. If `skip` is `true`: report `[N/Total] SKIP: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "skipped"}` to results.

2. If `skip` is `false`: run sync and report progress:
   ```bash
   bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh "<resourceId>" "<targetPath>"
   ```
   - On success (exit 0): report `[N/Total] Synced: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "synced"}` to results.
   - On failure (exit 1): report `[N/Total] ERROR: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "error", "error": "unbuild failed"}` to results. Continue to next app.

3. **ETA:** After 3+ non-skipped apps, track average time per app and report estimated remaining time: `(~Xm remaining)` or `(~Xs remaining)`.

After the loop, write results to `/tmp/qlik-sync-results.json`.

## Step 5: Finalize

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh /tmp/qlik-sync-prep.json /tmp/qlik-sync-results.json
```

## Step 6: Report Results

Read the finalize stdout for the summary line. Report to the user:
> Sync complete. **X** synced, **Y** skipped, **Z** errors (**N** apps in index).
> Run `/qlik:inspect` to explore your apps.

If there were errors, list the failed apps and suggest re-running with `--force` for those specific apps.

If the script exits with an error, help diagnose:
- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors** → suggest `qlik context login` to re-authenticate
- **Network errors** → suggest checking VPN/proxy and tenant URL

## Output Structure

After sync, apps are organized as:

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
```

- [ ] **Step 3: Update test-sync.sh**

Replace `tests/test-sync.sh` with:

```bash
#!/bin/bash
# Tests for sync SKILL.md — validates skill definition and references
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

SKILL_FILE="$REPO_ROOT/skills/sync/SKILL.md"
CLI_REF="$REPO_ROOT/skills/sync/references/cli-commands.md"

echo "=== sync references tests ==="
assert_file_exists "cli-commands.md exists" "$CLI_REF"
assert_contains "documents app ls" "$(cat "$CLI_REF")" "app ls"
assert_contains "documents app unbuild" "$(cat "$CLI_REF")" "app unbuild"
assert_contains "documents space ls" "$(cat "$CLI_REF")" "space ls"
assert_contains "documents SaaS-only limitation" "$(cat "$CLI_REF")" "SaaS"
assert_contains "documents pagination" "$(cat "$CLI_REF")" "limit"
assert_contains "documents resourceId" "$(cat "$CLI_REF")" "resourceId"
assert_contains "documents resourceAttributes" "$(cat "$CLI_REF")" "resourceAttributes"

echo ""
echo "=== sync SKILL.md tests ==="
SKILL_CONTENT="$(cat "$SKILL_FILE")"
assert_file_exists "sync SKILL.md exists" "$SKILL_FILE"
assert_contains "frontmatter has name" "$SKILL_CONTENT" "name: sync"
assert_contains "frontmatter has description" "$SKILL_CONTENT" "description:"
assert_contains "mentions config.json check" "$SKILL_CONTENT" "config.json"
assert_contains "mentions sync-prep.sh" "$SKILL_CONTENT" "sync-prep.sh"
assert_contains "mentions sync-app.sh" "$SKILL_CONTENT" "sync-app.sh"
assert_contains "mentions sync-finalize.sh" "$SKILL_CONTENT" "sync-finalize.sh"
assert_contains "mentions index.json" "$SKILL_CONTENT" "index.json"
assert_contains "mentions space filtering" "$SKILL_CONTENT" "space"
assert_contains "mentions force flag" "$SKILL_CONTENT" "force"
assert_contains "mentions ETA" "$SKILL_CONTENT" "ETA"
assert_contains "mentions progress" "$SKILL_CONTENT" "progress"
assert_contains "references cli-commands.md" "$SKILL_CONTENT" "cli-commands.md"

test_summary
```

- [ ] **Step 4: Run updated tests**

Run: `bash tests/test-sync.sh`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add skills/sync/SKILL.md tests/test-sync.sh
git commit -m "feat(sync): update SKILL.md for skill-driven loop with progress and ETA"
git push
```

---

### Task 8: Update justfile and run full test suite

Add new test files to the test runner and verify everything works together.

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Update justfile**

Add new test files to the `test` recipe in `justfile`:

```just
# Run all tests
test:
	@bash tests/test-setup.sh
	@bash tests/test-sync.sh
	@bash tests/test-sync-prep.sh
	@bash tests/test-sync-app.sh
	@bash tests/test-sync-finalize.sh
	@bash tests/test-sync-script.sh
	@bash tests/test-inspect.sh
	@bash tests/test-project.sh
```

- [ ] **Step 2: Run full test suite**

Run: `just test`
Expected: All tests pass across all test files

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "chore(sync): add new sync test files to justfile"
git push
```

