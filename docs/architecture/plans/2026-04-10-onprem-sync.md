# On-Prem Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add on-prem Qlik Sense support via export + qlik-parser, with multi-tenant config.

**Architecture:** Rename existing cloud scripts (`sync-prep.sh` → `sync-cloud-prep.sh`, `sync-app.sh` → `sync-cloud-app.sh`), add on-prem equivalents (`sync-onprem-prep.sh`, `sync-onprem-app.sh`), extract shared helpers to `sync-lib.sh`. Finalize script stays shared. Multi-tenant config.json (v0.2.0) replaces single-tenant format.

**Tech Stack:** Bash, jq, qlik-cli (`qlik qrs` commands), qlik-parser

**Spec:** `docs/architecture/specs/2026-04-10-onprem-sync-design.md`

---

### Task 1: Extract sync-lib.sh with shared helpers

Extract `sanitize()` and `resolve_username()` from `sync-prep.sh` into a shared library, then source it.

**Files:**
- Create: `skills/sync/scripts/sync-lib.sh`
- Modify: `skills/sync/scripts/sync-prep.sh`
- Create: `tests/test-sync-lib.sh`
- Modify: `justfile`

- [ ] **Step 1: Write failing test for sync-lib.sh**

Create `tests/test-sync-lib.sh`:

```bash
#!/bin/bash
# Tests for sync-lib.sh shared helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

LIB_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-lib.sh"

echo "=== sync-lib.sh tests ==="

# Test 1: Library exists and can be sourced
echo ""
echo "--- Test 1: Library exists ---"
assert_file_exists "sync-lib.sh exists" "$LIB_SCRIPT"

# Test 2: sanitize function
echo ""
echo "--- Test 2: sanitize ---"
source "$LIB_SCRIPT"

TESTS_RUN=$((TESTS_RUN + 1))
RESULT="$(sanitize 'hello/world:test')"
if [ "$RESULT" = "hello_world_test" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: sanitize replaces special chars"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 'hello_world_test', got '$RESULT'"
fi

TESTS_RUN=$((TESTS_RUN + 1))
RESULT2="$(sanitize 'normal-name')"
if [ "$RESULT2" = "normal-name" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: sanitize leaves clean names alone"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 'normal-name', got '$RESULT2'"
fi

# Test 3: normalize_app_type function
echo ""
echo "--- Test 3: normalize_app_type ---"
TESTS_RUN=$((TESTS_RUN + 1))
RESULT3="$(normalize_app_type 'DATAFLOW_PREP')"
if [ "$RESULT3" = "dataflow-prep" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: normalize_app_type lowercases and replaces underscores"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 'dataflow-prep', got '$RESULT3'"
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-lib.sh`
Expected: FAIL — `sync-lib.sh` does not exist

- [ ] **Step 3: Create sync-lib.sh**

Create `skills/sync/scripts/sync-lib.sh`:

```bash
#!/bin/bash
# sync-lib.sh — Shared helpers for sync scripts

sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-lib.sh`
Expected: 4/4 PASS

- [ ] **Step 5: Update sync-prep.sh to source sync-lib.sh**

In `skills/sync/scripts/sync-prep.sh`, replace the inline `sanitize()` and `normalize_app_type()` functions with:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"
```

Remove lines 103-109 (inline `sanitize` function) and lines 103-105 (inline `normalize_app_type` function).

- [ ] **Step 6: Run existing tests to verify no regressions**

Run: `just test`
Expected: All tests pass

- [ ] **Step 7: Add test-sync-lib.sh to justfile**

Add `@bash tests/test-sync-lib.sh` to the test recipe in `justfile`.

- [ ] **Step 8: Commit and push**

```bash
git add skills/sync/scripts/sync-lib.sh skills/sync/scripts/sync-prep.sh tests/test-sync-lib.sh justfile
git commit -m "refactor(sync): extract shared helpers to sync-lib.sh"
git push
```

---

### Task 2: Rename cloud scripts

Rename existing scripts to `sync-cloud-*` prefix. Update all references.

**Files:**
- Rename: `skills/sync/scripts/sync-prep.sh` → `skills/sync/scripts/sync-cloud-prep.sh`
- Rename: `skills/sync/scripts/sync-app.sh` → `skills/sync/scripts/sync-cloud-app.sh`
- Modify: `skills/sync/scripts/sync-tenant.sh` (update paths)
- Rename: `tests/test-sync-prep.sh` → `tests/test-sync-cloud-prep.sh`
- Rename: `tests/test-sync-app.sh` → `tests/test-sync-cloud-app.sh`
- Modify: `skills/sync/SKILL.md` (update script references)
- Modify: `justfile` (update test references)

- [ ] **Step 1: Rename scripts**

```bash
git mv skills/sync/scripts/sync-prep.sh skills/sync/scripts/sync-cloud-prep.sh
git mv skills/sync/scripts/sync-app.sh skills/sync/scripts/sync-cloud-app.sh
```

- [ ] **Step 2: Rename test files**

```bash
git mv tests/test-sync-prep.sh tests/test-sync-cloud-prep.sh
git mv tests/test-sync-app.sh tests/test-sync-cloud-app.sh
```

- [ ] **Step 3: Update sync-tenant.sh references**

In `skills/sync/scripts/sync-tenant.sh`, update the script paths from `sync-prep.sh` / `sync-app.sh` to `sync-cloud-prep.sh` / `sync-cloud-app.sh`. Also update `sync-finalize.sh` if it references the old names.

Find every occurrence of `sync-prep.sh` and replace with `sync-cloud-prep.sh`. Find every occurrence of `sync-app.sh` and replace with `sync-cloud-app.sh`.

- [ ] **Step 4: Update test file internal references**

In `tests/test-sync-cloud-prep.sh`, update `PREP_SCRIPT` variable:
```bash
PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-cloud-prep.sh"
```

In `tests/test-sync-cloud-app.sh`, update `APP_SCRIPT` variable:
```bash
APP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-cloud-app.sh"
```

In `tests/test-sync-cloud-prep.sh`, update the reference to `sync-tenant.sh` in the resume test (Test 7) — it calls `sync-tenant.sh` to create files, which is fine since that wrapper still works.

- [ ] **Step 5: Update SKILL.md allowed-tools and script references**

In `skills/sync/SKILL.md`, replace:
- `sync-prep.sh` → `sync-cloud-prep.sh`
- `sync-app.sh` → `sync-cloud-app.sh`

In the allowed-tools frontmatter and in Steps 3-4.

- [ ] **Step 6: Update justfile**

Replace `test-sync-prep.sh` with `test-sync-cloud-prep.sh` and `test-sync-app.sh` with `test-sync-cloud-app.sh`.

- [ ] **Step 7: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "refactor(sync): rename cloud scripts to sync-cloud-* prefix"
git push
```

---

### Task 3: Multi-tenant config.json (v0.2.0)

Update config reading in cloud prep and finalize to support multi-tenant config format. Add migration from v0.1.0.

**Files:**
- Modify: `skills/sync/scripts/sync-lib.sh` (add config helpers)
- Modify: `skills/sync/scripts/sync-cloud-prep.sh` (use new config reader)
- Modify: `skills/sync/scripts/sync-finalize.sh` (update lastSync per tenant)
- Modify: `tests/test-sync-lib.sh` (add config migration test)
- Modify: `tests/test-sync-cloud-prep.sh` (update config fixtures)
- Modify: `tests/test-sync-finalize.sh` (update config fixtures)

- [ ] **Step 1: Write failing test for config migration**

Add to `tests/test-sync-lib.sh`:

```bash
# Test 4: read_tenant_config — v0.1.0 migration
echo ""
echo "--- Test 4: read_tenant_config v0.1.0 ---"
TMPDIR_LIB="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LIB"' EXIT
mkdir -p "$TMPDIR_LIB/.qlik-sync"
cat > "$TMPDIR_LIB/.qlik-sync/config.json" <<'JSON'
{"context": "old-ctx", "server": "https://old.qlikcloud.com", "lastSync": null, "version": "0.1.0"}
JSON

RESULT4="$(read_tenant_config "$TMPDIR_LIB/.qlik-sync/config.json" "")"
RESULT4_FILE="$TMPDIR_LIB/result4.json"
echo "$RESULT4" > "$RESULT4_FILE"

assert_json_field "migrated context" "$RESULT4_FILE" '.[0].context' "old-ctx"
assert_json_field "migrated server" "$RESULT4_FILE" '.[0].server' "https://old.qlikcloud.com"
assert_json_field "migrated type is cloud" "$RESULT4_FILE" '.[0].type' "cloud"

# Test 5: read_tenant_config — v0.2.0 format
echo ""
echo "--- Test 5: read_tenant_config v0.2.0 ---"
cat > "$TMPDIR_LIB/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {"context": "cloud-ctx", "server": "https://cloud.qlikcloud.com", "type": "cloud", "lastSync": null},
    {"context": "onprem-ctx", "server": "https://qseow.corp.local/jwt", "type": "on-prem", "lastSync": null}
  ]
}
JSON

RESULT5="$(read_tenant_config "$TMPDIR_LIB/.qlik-sync/config.json" "")"
RESULT5_FILE="$TMPDIR_LIB/result5.json"
echo "$RESULT5" > "$RESULT5_FILE"

TENANT_COUNT="$(jq 'length' "$RESULT5_FILE")"
assert_eq "v0.2.0 returns 2 tenants" "2" "$TENANT_COUNT"

# Test 6: read_tenant_config — filter by name
echo ""
echo "--- Test 6: read_tenant_config filter ---"
RESULT6="$(read_tenant_config "$TMPDIR_LIB/.qlik-sync/config.json" "onprem-ctx")"
RESULT6_FILE="$TMPDIR_LIB/result6.json"
echo "$RESULT6" > "$RESULT6_FILE"

FILTERED_COUNT="$(jq 'length' "$RESULT6_FILE")"
assert_eq "filter returns 1 tenant" "1" "$FILTERED_COUNT"
assert_json_field "filtered tenant is on-prem" "$RESULT6_FILE" '.[0].type' "on-prem"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-lib.sh`
Expected: FAIL — `read_tenant_config` not defined

- [ ] **Step 3: Implement read_tenant_config in sync-lib.sh**

Add to `skills/sync/scripts/sync-lib.sh`:

```bash
# read_tenant_config <config-file> <tenant-filter>
# Outputs JSON array of tenant objects
# Handles v0.1.0 (single-tenant) and v0.2.0 (multi-tenant) formats
# If tenant-filter is non-empty, returns only matching tenant by context name
read_tenant_config() {
  local config_file="$1"
  local tenant_filter="$2"

  local version
  version="$(jq -r '.version // "0.1.0"' "$config_file")"

  local tenants
  if [ "$version" = "0.2.0" ]; then
    tenants="$(jq '.tenants' "$config_file")"
  else
    # Migrate v0.1.0: wrap single tenant, detect type from server URL
    tenants="$(jq '[{
      context: .context,
      server: .server,
      lastSync: .lastSync,
      type: (if (.server // "" | test("qlikcloud\\.com")) then "cloud" else "on-prem" end)
    }]' "$config_file")"
  fi

  if [ -n "$tenant_filter" ]; then
    echo "$tenants" | jq --arg name "$tenant_filter" '[.[] | select(.context == $name)]'
  else
    echo "$tenants"
  fi
}

# detect_tenant_type <server-url>
# Returns "cloud" or "on-prem" based on URL pattern
detect_tenant_type() {
  local server="$1"
  if echo "$server" | grep -q 'qlikcloud\.com'; then
    echo "cloud"
  else
    echo "on-prem"
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-lib.sh`
Expected: All tests pass

- [ ] **Step 5: Update sync-cloud-prep.sh to use read_tenant_config**

In `skills/sync/scripts/sync-cloud-prep.sh`, add `--tenant` flag parsing:

```bash
TENANT_FILTER=""
```

Add to the while loop:
```bash
--tenant) TENANT_FILTER="$2"; shift 2 ;;
```

Replace the config reading block (lines 27-39) with:

```bash
CONFIG_FILE=".qlik-sync/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. Run setup first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

TENANTS_JSON="$(read_tenant_config "$CONFIG_FILE" "$TENANT_FILTER")"
TENANT_COUNT="$(echo "$TENANTS_JSON" | jq 'length')"

if [ "$TENANT_COUNT" -eq 0 ]; then
  echo "Error: no matching tenant found." >&2
  exit 1
fi

# Use first cloud tenant (on-prem tenants handled by sync-onprem-prep.sh)
TENANT_JSON="$(echo "$TENANTS_JSON" | jq '.[0]')"
CONTEXT="$(echo "$TENANT_JSON" | jq -r '.context')"
SERVER="$(echo "$TENANT_JSON" | jq -r '.server')"
```

Keep the rest of the script unchanged — `CONTEXT` and `SERVER` are used the same way.

- [ ] **Step 6: Update sync-finalize.sh to write lastSync per tenant**

In `skills/sync/scripts/sync-finalize.sh`, replace the config update block (line 72) with:

```bash
# Update config.json — write lastSync to matching tenant or top-level for v0.1.0
VERSION="$(jq -r '.version // "0.1.0"' "$CONFIG_FILE")"
if [ "$VERSION" = "0.2.0" ]; then
  jq --arg ts "$NOW" --arg ctx "$CONTEXT" \
    '(.tenants[] | select(.context == $ctx)).lastSync = $ts' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
  jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi
```

- [ ] **Step 7: Update test fixtures for multi-tenant config**

In `tests/test-sync-cloud-prep.sh`, update `setup_workdir` to use v0.2.0 format:

```bash
setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "test-ctx",
      "server": "https://test-tenant.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    }
  ]
}
JSON
  echo "$workdir"
}
```

In `tests/test-sync-finalize.sh`, update all config.json fixtures similarly.

In `tests/test-sync-script.sh`, update `setup_workdir` similarly.

- [ ] **Step 8: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 9: Commit and push**

```bash
git add skills/sync/scripts/sync-lib.sh skills/sync/scripts/sync-cloud-prep.sh skills/sync/scripts/sync-finalize.sh tests/test-sync-lib.sh tests/test-sync-cloud-prep.sh tests/test-sync-finalize.sh tests/test-sync-script.sh
git commit -m "feat(sync): add multi-tenant config v0.2.0 with migration"
git push
```

---

### Task 4: On-prem QRS mock and fixtures

Create mock handlers for `qlik qrs` commands and `qlik-parser`, plus fixtures.

**Files:**
- Modify: `tests/mock-qlik/qlik` (add qrs command handling)
- Create: `tests/mock-qlik-parser/qlik-parser`
- Create: `tests/fixtures/qrs-app-full-response.json`
- Create: `tests/fixtures/qrs-stream-ls-response.json`
- Create: `tests/fixtures/qrs-export-response.json`
- Create: `tests/fixtures/qlik-parser-output/script.qvs`
- Create: `tests/fixtures/qlik-parser-output/measures.json`
- Create: `tests/fixtures/qlik-parser-output/dimensions.json`
- Create: `tests/fixtures/qlik-parser-output/variables.json`

- [ ] **Step 1: Create QRS app full fixture**

Create `tests/fixtures/qrs-app-full-response.json`:

```json
[
  {
    "id": "qrs-app-001",
    "name": "Finance Report",
    "description": "Quarterly finance report",
    "published": true,
    "lastReloadTime": "2026-04-08T02:00:00Z",
    "stream": {
      "id": "stream-001",
      "name": "Finance Stream"
    },
    "owner": {
      "id": "user-qrs-001",
      "userId": "CORP\\jdoe",
      "name": "Jane Doe",
      "userDirectory": "CORP"
    },
    "createdDate": "2025-01-15T10:00:00Z",
    "modifiedDate": "2026-04-08T14:30:00Z",
    "fileSize": 5242880,
    "tags": [],
    "customProperties": []
  },
  {
    "id": "qrs-app-002",
    "name": "HR Dashboard",
    "description": "Employee headcount",
    "published": true,
    "lastReloadTime": "2026-04-07T12:00:00Z",
    "stream": {
      "id": "stream-002",
      "name": "HR Stream"
    },
    "owner": {
      "id": "user-qrs-002",
      "userId": "CORP\\hruser",
      "name": "HR Admin",
      "userDirectory": "CORP"
    },
    "createdDate": "2025-03-01T09:00:00Z",
    "modifiedDate": "2026-04-07T12:30:00Z",
    "fileSize": 3145728,
    "tags": [],
    "customProperties": []
  },
  {
    "id": "qrs-app-003",
    "name": "Personal Scratch",
    "description": "Dev sandbox",
    "published": false,
    "lastReloadTime": "2026-04-09T09:00:00Z",
    "stream": null,
    "owner": {
      "id": "user-qrs-001",
      "userId": "CORP\\jdoe",
      "name": "Jane Doe",
      "userDirectory": "CORP"
    },
    "createdDate": "2025-06-01T08:00:00Z",
    "modifiedDate": "2026-04-09T09:30:00Z",
    "fileSize": 1048576,
    "tags": [],
    "customProperties": []
  }
]
```

- [ ] **Step 2: Create QRS stream fixture**

Create `tests/fixtures/qrs-stream-ls-response.json`:

```json
[
  {
    "id": "stream-001",
    "name": "Finance Stream",
    "createdDate": "2024-06-01T10:00:00Z",
    "modifiedDate": "2024-06-01T10:00:00Z",
    "tags": [],
    "customProperties": []
  },
  {
    "id": "stream-002",
    "name": "HR Stream",
    "createdDate": "2024-08-15T14:00:00Z",
    "modifiedDate": "2024-08-15T14:00:00Z",
    "tags": [],
    "customProperties": []
  }
]
```

- [ ] **Step 3: Create QRS export response fixture**

Create `tests/fixtures/qrs-export-response.json`:

```json
{
  "exportTicketId": "mock-ticket-123",
  "appId": "placeholder",
  "downloadPath": "/tempcontent/mock-ticket-123/app.qvf"
}
```

- [ ] **Step 4: Create qlik-parser output fixtures**

Create `tests/fixtures/qlik-parser-output/script.qvs`:
```
// Mock load script
LET vToday = Today();

Sales:
LOAD * FROM [lib://DataFiles/sales.qvd] (qvd);
```

Create `tests/fixtures/qlik-parser-output/measures.json`:
```json
[{"qInfo":{"qId":"measure-001"},"qMeasure":{"qDef":"Sum(Amount)"},"qMetaDef":{"title":"Total Amount","description":"Sum of all amounts"}}]
```

Create `tests/fixtures/qlik-parser-output/dimensions.json`:
```json
[{"qInfo":{"qId":"dim-001"},"qDim":{"qFieldDefs":["Region"]},"qMetaDef":{"title":"Region","description":"Sales region"}}]
```

Create `tests/fixtures/qlik-parser-output/variables.json`:
```json
[{"qInfo":{"qId":"var-001"},"qName":"vToday","qDefinition":"=Today()","qComment":"Current date"}]
```

- [ ] **Step 5: Add QRS commands to mock qlik binary**

In `tests/mock-qlik/qlik`, add a `qrs` case before the final `*` case:

```bash
  qrs)
    case "$2" in
      app)
        case "$3" in
          full)
            # Check for --filter
            FILTER=""
            for arg in "$@"; do
              case "$arg" in
                --filter) FILTER="next" ;;
                *)
                  if [ "$FILTER" = "next" ]; then
                    FILTER="$arg"
                  fi
                  ;;
              esac
            done
            cat "$FIXTURES_DIR/qrs-app-full-response.json"
            ;;
          ls)
            cat "$FIXTURES_DIR/qrs-app-full-response.json"
            ;;
          export)
            case "$4" in
              create)
                APP_ID="$5"
                # Return export ticket
                jq --arg id "$APP_ID" '.appId = $id' "$FIXTURES_DIR/qrs-export-response.json"
                ;;
              *) echo "Unknown qrs app export subcommand: $4" >&2; exit 1 ;;
            esac
            ;;
          *) echo "Unknown qrs app subcommand: $3" >&2; exit 1 ;;
        esac
        ;;
      stream)
        case "$3" in
          ls)
            cat "$FIXTURES_DIR/qrs-stream-ls-response.json"
            ;;
          *) echo "Unknown qrs stream subcommand: $3" >&2; exit 1 ;;
        esac
        ;;
      download)
        case "$3" in
          app)
            case "$4" in
              get)
                # Parse --output-file flag
                OUTPUT_FILE=""
                for arg in "$@"; do
                  case "$arg" in
                    --output-file) OUTPUT_FILE="next" ;;
                    *)
                      if [ "$OUTPUT_FILE" = "next" ]; then
                        OUTPUT_FILE="$arg"
                      fi
                      ;;
                  esac
                done
                if [ -n "$OUTPUT_FILE" ]; then
                  touch "$OUTPUT_FILE"
                fi
                ;;
              *) echo "Unknown qrs download app subcommand: $4" >&2; exit 1 ;;
            esac
            ;;
          *) echo "Unknown qrs download subcommand: $3" >&2; exit 1 ;;
        esac
        ;;
      *) echo "Unknown qrs subcommand: $2" >&2; exit 1 ;;
    esac
    ;;
```

- [ ] **Step 6: Create mock qlik-parser binary**

Create `tests/mock-qlik-parser/qlik-parser`:

```bash
#!/bin/bash
# Mock qlik-parser for testing

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/../fixtures/qlik-parser-output"

case "$1" in
  extract)
    # Parse flags
    SOURCE=""
    OUT=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --source) SOURCE="$2"; shift 2 ;;
        --out)    OUT="$2"; shift 2 ;;
        --script|--measures|--dimensions|--variables) shift ;;
        *) shift ;;
      esac
    done
    if [ -z "$OUT" ]; then
      echo "Error: --out required" >&2
      exit 1
    fi
    mkdir -p "$OUT"
    cp "$FIXTURES_DIR/script.qvs" "$OUT/"
    cp "$FIXTURES_DIR/measures.json" "$OUT/"
    cp "$FIXTURES_DIR/dimensions.json" "$OUT/"
    cp "$FIXTURES_DIR/variables.json" "$OUT/"
    ;;
  version)
    echo "qlik-parser 0.1.0 (mock)"
    ;;
  *)
    echo "Unknown command: $1" >&2
    exit 1
    ;;
esac
```

Make executable: `chmod +x tests/mock-qlik-parser/qlik-parser`

- [ ] **Step 7: Run existing tests to check no regressions**

Run: `just test`
Expected: All tests pass (new fixtures/mocks are inert until used)

- [ ] **Step 8: Commit and push**

```bash
git add tests/mock-qlik/qlik tests/mock-qlik-parser/qlik-parser tests/fixtures/qrs-app-full-response.json tests/fixtures/qrs-stream-ls-response.json tests/fixtures/qrs-export-response.json tests/fixtures/qlik-parser-output/
git commit -m "test(sync): add QRS mock commands, qlik-parser mock, and on-prem fixtures"
git push
```

---

### Task 5: Implement sync-onprem-prep.sh

On-prem prep script: list apps via QRS, resolve streams, output same JSON format as cloud prep.

**Files:**
- Create: `skills/sync/scripts/sync-onprem-prep.sh`
- Create: `tests/test-sync-onprem-prep.sh`
- Modify: `justfile`

- [ ] **Step 1: Write failing test**

Create `tests/test-sync-onprem-prep.sh`:

```bash
#!/bin/bash
# Tests for sync-onprem-prep.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

PREP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-onprem-prep.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "onprem-ctx",
      "server": "https://qseow.corp.local/jwt",
      "type": "on-prem",
      "lastSync": null
    }
  ]
}
JSON
  echo "$workdir"
}

run_prep() {
  local workdir="$1"
  shift
  (cd "$workdir" && PATH="$MOCK_DIR:$PATH" bash "$PREP_SCRIPT" "$@" 2>/dev/null)
}

echo "=== sync-onprem-prep.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-onprem-prep.sh exists" "$PREP_SCRIPT"

# Test 2: Outputs valid JSON with all apps
echo ""
echo "--- Test 2: Full listing JSON output ---"
WORKDIR="$(setup_workdir)"
OUTPUT="$(run_prep "$WORKDIR")"
PREP_JSON="$TMPDIR_BASE/prep-output.json"
echo "$OUTPUT" > "$PREP_JSON"

assert_json_field "totalApps is 3" "$PREP_JSON" ".totalApps" "3"
assert_json_field "tenant is qseow.corp.local" "$PREP_JSON" ".tenant" "qseow.corp.local"
assert_json_field "context correct" "$PREP_JSON" ".context" "onprem-ctx"

# Check published app (has stream)
PUBLISHED_APP="$TMPDIR_BASE/published-app.json"
echo "$OUTPUT" | jq '.apps[] | select(.resourceId == "qrs-app-001")' > "$PUBLISHED_APP"
assert_json_field "app-001 name" "$PUBLISHED_APP" ".name" "Finance Report"
assert_json_field "app-001 spaceName is stream name" "$PUBLISHED_APP" ".spaceName" "Finance Stream"
assert_json_field "app-001 spaceType is stream" "$PUBLISHED_APP" ".spaceType" "stream"
assert_json_field "app-001 appType is null" "$PUBLISHED_APP" ".appType" "null"
assert_json_field "app-001 ownerName" "$PUBLISHED_APP" ".ownerName" "Jane Doe"

# Check targetPath: tenant/stream/stream-name (id)/app-name (id)
assert_json_field "app-001 targetPath" "$PUBLISHED_APP" ".targetPath" \
  "qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"

# Check unpublished app (no stream → personal)
PERSONAL_APP="$TMPDIR_BASE/personal-app.json"
echo "$OUTPUT" | jq '.apps[] | select(.resourceId == "qrs-app-003")' > "$PERSONAL_APP"
assert_json_field "app-003 spaceType is personal" "$PERSONAL_APP" ".spaceType" "personal"
assert_json_field "app-003 targetPath" "$PERSONAL_APP" ".targetPath" \
  "qseow.corp.local/personal/Jane Doe (user-qrs-001)/Personal Scratch (qrs-app-003)"

# Test 3: Stream filter
echo ""
echo "--- Test 3: Stream filter ---"
WORKDIR2="$(setup_workdir)"
OUTPUT2="$(run_prep "$WORKDIR2" --stream "Finance Stream")"
PREP_JSON2="$TMPDIR_BASE/prep-stream.json"
echo "$OUTPUT2" > "$PREP_JSON2"
assert_json_field "stream filter totalApps is 1" "$PREP_JSON2" ".totalApps" "1"
assert_json_field "filtered app is Finance Report" "$PREP_JSON2" '.apps[0].name' "Finance Report"

# Test 4: App name filter
echo ""
echo "--- Test 4: App name filter ---"
WORKDIR3="$(setup_workdir)"
OUTPUT3="$(run_prep "$WORKDIR3" --app "Dashboard")"
PREP_JSON3="$TMPDIR_BASE/prep-app.json"
echo "$OUTPUT3" > "$PREP_JSON3"
assert_json_field "app filter totalApps is 1" "$PREP_JSON3" ".totalApps" "1"

# Test 5: Skip detection
echo ""
echo "--- Test 5: Skip detection ---"
WORKDIR4="$(setup_workdir)"
# Create a pre-existing synced app
mkdir -p "$WORKDIR4/.qlik-sync/qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"
echo "dummy" > "$WORKDIR4/.qlik-sync/qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)/script.qvs"
OUTPUT4="$(run_prep "$WORKDIR4")"
PREP_JSON4="$TMPDIR_BASE/prep-skip.json"
echo "$OUTPUT4" > "$PREP_JSON4"
SKIP_COUNT="$(jq '[.apps[] | select(.skip == true)] | length' "$PREP_JSON4")"
assert_eq "1 app marked skip" "1" "$SKIP_COUNT"

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-onprem-prep.sh`
Expected: FAIL — script does not exist

- [ ] **Step 3: Implement sync-onprem-prep.sh**

Create `skills/sync/scripts/sync-onprem-prep.sh`:

```bash
#!/bin/bash
# sync-onprem-prep.sh — Fetch and resolve on-prem Qlik apps for sync
# Usage: sync-onprem-prep.sh [--stream "Name"] [--app "Pattern"] [--id <GUID>] [--force] [--tenant "ctx"]
# Outputs JSON to stdout with app list and resolved metadata
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

# --- Parse flags ---
STREAM_FILTER=""
APP_FILTER=""
ID_FILTER=""
FORCE=false
TENANT_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --stream) STREAM_FILTER="$2"; shift 2 ;;
    --app)    APP_FILTER="$2"; shift 2 ;;
    --id)     ID_FILTER="$2"; shift 2 ;;
    --force)  FORCE=true; shift ;;
    --tenant) TENANT_FILTER="$2"; shift 2 ;;
    *)
      echo "Unknown flag: $1" >&2
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

TENANTS_JSON="$(read_tenant_config "$CONFIG_FILE" "$TENANT_FILTER")"
# Filter to on-prem tenants only
TENANT_JSON="$(echo "$TENANTS_JSON" | jq '[.[] | select(.type == "on-prem")] | .[0]')"

if [ "$TENANT_JSON" = "null" ]; then
  echo "Error: no on-prem tenant found in config." >&2
  exit 1
fi

CONTEXT="$(echo "$TENANT_JSON" | jq -r '.context')"
SERVER="$(echo "$TENANT_JSON" | jq -r '.server')"

# Extract hostname from server URL
TENANT_DOMAIN="$(echo "$SERVER" | sed -E 's|https?://([^/:]+).*|\1|')"

# --- Check dependencies ---
for cmd in qlik jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found on PATH." >&2
    exit 1
  fi
done

# --- Fetch streams and build lookup ---
STREAM_LOOKUP="$(mktemp)"
APPS_FILE="$(mktemp)"
trap 'rm -f "$STREAM_LOOKUP" "$APPS_FILE"' EXIT

qlik qrs stream ls --json < /dev/null | jq -r '.[] | "\(.id)\t\(.name)"' > "$STREAM_LOOKUP"

# --- Resolve stream ID for stream filter ---
STREAM_ID_FILTER=""
if [ -n "$STREAM_FILTER" ]; then
  STREAM_ID_FILTER="$(grep "	${STREAM_FILTER}$" "$STREAM_LOOKUP" 2>/dev/null | cut -f1 || true)"
  if [ -z "$STREAM_ID_FILTER" ]; then
    echo "Error: stream '$STREAM_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
qlik qrs app full --json < /dev/null > "$APPS_FILE"

# Apply filters
if [ -n "$ID_FILTER" ]; then
  jq --arg id "$ID_FILTER" '[.[] | select(.id == $id)]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

if [ -n "$STREAM_ID_FILTER" ]; then
  jq --arg sid "$STREAM_ID_FILTER" '[.[] | select(.stream != null and .stream.id == $sid)]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

if [ -n "$APP_FILTER" ]; then
  jq --arg pat "$APP_FILTER" '[.[] | select(.name | test($pat))]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

APP_COUNT="$(jq 'length' "$APPS_FILE")"

if [ "$APP_COUNT" -eq 0 ]; then
  echo '{"tenant":"'"$TENANT_DOMAIN"'","tenantId":"","context":"'"$CONTEXT"'","server":"'"$SERVER"'","totalApps":0,"apps":[]}'
  exit 0
fi

# --- Build app entries ---
APP_ENTRIES="$(mktemp)"
trap 'rm -f "$STREAM_LOOKUP" "$APPS_FILE" "$APP_ENTRIES"' EXIT

while IFS= read -r app_line; do
  app_id="$(jq -r '.id' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  description="$(jq -r '.description // empty' <<< "$app_line")"
  published="$(jq -r '.published // false' <<< "$app_line")"
  last_reload="$(jq -r '.lastReloadTime // empty' <<< "$app_line")"

  stream_id="$(jq -r '.stream.id // empty' <<< "$app_line")"
  stream_name="$(jq -r '.stream.name // empty' <<< "$app_line")"
  owner_id="$(jq -r '.owner.id // empty' <<< "$app_line")"
  owner_name="$(jq -r '.owner.name // empty' <<< "$app_line")"

  # Determine space type and path
  if [ -n "$stream_id" ] && [ "$stream_id" != "null" ]; then
    space_type="stream"
    space_name="$stream_name"
    space_folder="$(sanitize "$stream_name") ($stream_id)"
    target_path="$TENANT_DOMAIN/$space_type/$space_folder/$(sanitize "$app_name") ($app_id)"
  else
    space_type="personal"
    space_name="$owner_name"
    space_folder="$(sanitize "$owner_name") ($owner_id)"
    target_path="$TENANT_DOMAIN/$space_type/$space_folder/$(sanitize "$app_name") ($app_id)"
  fi

  full_path=".qlik-sync/$target_path"

  # Resume check — on-prem uses script.qvs instead of config.yml
  skip=false
  skip_reason=""
  if [ "$FORCE" = false ] && [ -f "$full_path/script.qvs" ]; then
    skip=true
    skip_reason="already synced (use --force to re-sync)"
  fi

  jq -n \
    --arg resourceId "$app_id" \
    --arg name "$app_name" \
    --arg spaceId "$stream_id" \
    --arg spaceName "$space_name" \
    --arg spaceType "$space_type" \
    --arg ownerId "$owner_id" \
    --arg ownerName "$owner_name" \
    --arg description "$description" \
    --argjson published "$published" \
    --arg lastReloadTime "$last_reload" \
    --arg targetPath "$target_path" \
    --argjson skip "$skip" \
    --arg skipReason "$skip_reason" \
    '{resourceId: $resourceId, name: $name, spaceId: $spaceId, spaceName: $spaceName, spaceType: $spaceType, appType: null, ownerId: $ownerId, ownerName: $ownerName, description: $description, tags: [], published: $published, lastReloadTime: $lastReloadTime, targetPath: $targetPath, skip: $skip, skipReason: $skipReason}' \
    >> "$APP_ENTRIES"

done < <(jq -c '.[]' "$APPS_FILE")

# --- Output final JSON ---
jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}'
```

Make executable: `chmod +x skills/sync/scripts/sync-onprem-prep.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-onprem-prep.sh`
Expected: All tests pass

- [ ] **Step 5: Add to justfile**

Add `@bash tests/test-sync-onprem-prep.sh` to the test recipe.

- [ ] **Step 6: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 7: Commit and push**

```bash
git add skills/sync/scripts/sync-onprem-prep.sh tests/test-sync-onprem-prep.sh justfile
git commit -m "feat(sync): add on-prem prep script with QRS app listing"
git push
```

---

### Task 6: Implement sync-onprem-app.sh

Export + download + parse chain for one on-prem app.

**Files:**
- Create: `skills/sync/scripts/sync-onprem-app.sh`
- Create: `tests/test-sync-onprem-app.sh`
- Modify: `justfile`

- [ ] **Step 1: Write failing test**

Create `tests/test-sync-onprem-app.sh`:

```bash
#!/bin/bash
# Tests for sync-onprem-app.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/helpers.sh"

APP_SCRIPT="$REPO_ROOT/skills/sync/scripts/sync-onprem-app.sh"
MOCK_DIR="$SCRIPT_DIR/mock-qlik"
MOCK_PARSER_DIR="$SCRIPT_DIR/mock-qlik-parser"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== sync-onprem-app.sh tests ==="

# Test 1: Script exists
echo ""
echo "--- Test 1: Script exists ---"
assert_file_exists "sync-onprem-app.sh exists" "$APP_SCRIPT"

# Test 2: Successful export + parse
echo ""
echo "--- Test 2: Successful sync ---"
WORKDIR="$TMPDIR_BASE/test-onprem-app"
mkdir -p "$WORKDIR/.qlik-sync"
TARGET="qseow.corp.local/stream/Finance Stream (stream-001)/Finance Report (qrs-app-001)"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR" && PATH="$MOCK_DIR:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "qrs-app-001" "$TARGET" 2>/dev/null); then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits 0 on success"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit 0 on success"
fi

# Verify extracted files
assert_dir_exists "target dir created" "$WORKDIR/.qlik-sync/$TARGET"
assert_file_exists "script.qvs extracted" "$WORKDIR/.qlik-sync/$TARGET/script.qvs"
assert_file_exists "measures.json extracted" "$WORKDIR/.qlik-sync/$TARGET/measures.json"
assert_file_exists "dimensions.json extracted" "$WORKDIR/.qlik-sync/$TARGET/dimensions.json"
assert_file_exists "variables.json extracted" "$WORKDIR/.qlik-sync/$TARGET/variables.json"

# Verify no leftover QVF
TESTS_RUN=$((TESTS_RUN + 1))
if ls /tmp/qrs-app-001*.qvf 2>/dev/null; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: QVF not cleaned up"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: QVF cleaned up"
fi

# Test 3: No stdout output
echo ""
echo "--- Test 3: No stdout output ---"
WORKDIR2="$TMPDIR_BASE/test-onprem-app-stdout"
mkdir -p "$WORKDIR2/.qlik-sync"
TARGET2="qseow.corp.local/stream/HR Stream (stream-002)/HR Dashboard (qrs-app-002)"
STDOUT="$(cd "$WORKDIR2" && PATH="$MOCK_DIR:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "qrs-app-002" "$TARGET2" 2>/dev/null)"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -z "$STDOUT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: no stdout output"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: unexpected stdout: $STDOUT"
fi

# Test 4: Fails on export error
echo ""
echo "--- Test 4: Fails on export error ---"
WORKDIR3="$TMPDIR_BASE/test-onprem-app-fail"
mkdir -p "$WORKDIR3/.qlik-sync"
FAIL_MOCK="$TMPDIR_BASE/fail-mock"
mkdir -p "$FAIL_MOCK"
cat > "$FAIL_MOCK/qlik" <<'MOCK'
#!/bin/bash
echo "Error: export failed" >&2
exit 1
MOCK
chmod +x "$FAIL_MOCK/qlik"
TESTS_RUN=$((TESTS_RUN + 1))
if (cd "$WORKDIR3" && PATH="$FAIL_MOCK:$MOCK_PARSER_DIR:$PATH" bash "$APP_SCRIPT" "bad-id" "some/path" 2>/dev/null); then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: should exit non-zero on export failure"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: exits non-zero on export failure"
fi

test_summary
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-onprem-app.sh`
Expected: FAIL — script does not exist

- [ ] **Step 3: Implement sync-onprem-app.sh**

Create `skills/sync/scripts/sync-onprem-app.sh`:

```bash
#!/bin/bash
# sync-onprem-app.sh — Export, download, and parse a single on-prem Qlik app
# Usage: sync-onprem-app.sh <appId> <targetPath>
# stdout: nothing (skill handles all user-facing output)
# stderr: error details on failure
# exit 0: success, exit 1: failure
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-onprem-app.sh <appId> <targetPath>" >&2
  exit 1
fi

APP_ID="$1"
TARGET_PATH="$2"
FULL_PATH=".qlik-sync/$TARGET_PATH"
QVF_PATH="/tmp/${APP_ID}.qvf"

# Cleanup QVF on exit (success or failure)
trap 'rm -f "$QVF_PATH"' EXIT

# Step 1: Create export ticket
TICKET="$(qlik qrs app export create "$APP_ID" --skipdata --json < /dev/null | jq -r '.exportTicketId')"

if [ -z "$TICKET" ] || [ "$TICKET" = "null" ]; then
  echo "Error: failed to get export ticket for $APP_ID" >&2
  exit 1
fi

# Step 2: Download QVF
qlik qrs download app get "${APP_ID}.qvf" --appId "$APP_ID" --exportticketid "$TICKET" --output-file "$QVF_PATH" < /dev/null >/dev/null

if [ ! -f "$QVF_PATH" ]; then
  echo "Error: QVF download failed for $APP_ID" >&2
  exit 1
fi

# Step 3: Parse with qlik-parser
mkdir -p "$FULL_PATH"
qlik-parser extract --source "$QVF_PATH" --out "$FULL_PATH" --script --measures --dimensions --variables >/dev/null
```

Make executable: `chmod +x skills/sync/scripts/sync-onprem-app.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-onprem-app.sh`
Expected: All tests pass

- [ ] **Step 5: Add to justfile**

Add `@bash tests/test-sync-onprem-app.sh` to the test recipe.

- [ ] **Step 6: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 7: Commit and push**

```bash
git add skills/sync/scripts/sync-onprem-app.sh tests/test-sync-onprem-app.sh justfile
git commit -m "feat(sync): add on-prem app script with export+download+parse chain"
git push
```

---

### Task 7: Update SKILL.md for multi-tenant dispatch

Update the sync skill to support both cloud and on-prem tenants.

**Files:**
- Modify: `skills/sync/SKILL.md`
- Modify: `skills/sync/references/cli-commands.md`

- [ ] **Step 1: Update SKILL.md frontmatter**

Replace the allowed-tools section with:

```yaml
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep.json:*)"
  - "Bash(cat /tmp/qlik-sync-results.json:*)"
  - "Bash(echo:*)"
  - Bash(qlik app ls:*)
  - Bash(qlik qrs app:*)
  - Bash(qlik qrs stream:*)
  - Bash(date:*)
  - Read
  - Write
```

- [ ] **Step 2: Update SKILL.md description and title**

Update the opening to mention on-prem:

```markdown
# Qlik Sync

Pull apps from Qlik Cloud or on-prem Qlik Sense Enterprise tenants to a local `.qlik-sync/` working copy. Each app is extracted into its own directory organized by tenant, space/stream, and app name.

Supports:
- **Cloud:** Uses `qlik app unbuild` to extract app contents
- **On-prem:** Uses `qlik qrs` to export apps, then `qlik-parser` to extract contents
```

- [ ] **Step 3: Update Step 1 (Parse User Intent)**

Add `--tenant` and `--stream` to the intent table:

```markdown
| User says | Script flags |
|-----------|-------------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` (cloud) or `--stream "Finance Prod"` (on-prem) |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |
| "sync my-cloud tenant" / "sync just on-prem" | `--tenant "context-name"` |
```

- [ ] **Step 4: Update Steps 3-5 for multi-tenant dispatch**

Replace Steps 3-5 with:

```markdown
## Step 3: Read Config and Dispatch

Read `.qlik-sync/config.json` to get tenant list. If `--tenant` flag specified, filter to that tenant.

For each tenant:

### Cloud Tenant

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh [flags] > /tmp/qlik-sync-prep.json
cat /tmp/qlik-sync-prep.json
```

Then loop with `sync-cloud-app.sh` per Step 4.

### On-Prem Tenant

First check `qlik-parser` is available:
```bash
which qlik-parser
```
If missing, stop and tell the user:
> On-prem sync requires qlik-parser. Download from https://github.com/mattiasthalen/qlik-parser/releases and add to PATH.

Then:
```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-prep.sh [flags] > /tmp/qlik-sync-prep.json
cat /tmp/qlik-sync-prep.json
```

Then loop with `sync-onprem-app.sh` per Step 4.

Note: For on-prem, map `--space` to `--stream` when calling the prep script.
```

- [ ] **Step 5: Update Step 4 sync loop**

Update the sync-app call to be tenant-type-aware:

```markdown
## Step 4: Sync Loop with Progress

Loop through each app in the prep JSON. Track timing for ETA.

For each non-skipped app, call the appropriate script based on tenant type:
- **Cloud:** `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-app.sh "<resourceId>" "<targetPath>"`
- **On-prem:** `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-app.sh "<resourceId>" "<targetPath>"`

Progress reporting and ETA logic remain the same.
```

- [ ] **Step 6: Update output structure section**

Add on-prem directory structure:

```markdown
## Output Structure

### Cloud
(existing structure unchanged)

### On-Prem
```
.qlik-sync/
└── <hostname>/
    ├── stream/
    │   └── <stream-name> (<streamId>)/
    │       └── <app-name> (<appId>)/
    │           ├── script.qvs
    │           ├── measures.json
    │           ├── dimensions.json
    │           └── variables.json
    └── personal/
        └── <owner-name> (<ownerId>)/
            └── <app-name> (<appId>)/
                └── ...
```
```

- [ ] **Step 7: Update cli-commands.md reference**

Add QRS command reference to `skills/sync/references/cli-commands.md`:

```markdown
## On-Prem: qlik qrs app full

List all apps with full metadata from QRS API.

\`\`\`bash
qlik qrs app full --json
\`\`\`

**Key output fields per app:**
- `id` — app GUID
- `name` — app name
- `stream` — stream object (null if unpublished), with `id` and `name`
- `owner` — owner object with `id`, `userId`, `name`, `userDirectory`
- `description`
- `published`
- `lastReloadTime`

## On-Prem: qlik qrs stream ls

List streams.

\`\`\`bash
qlik qrs stream ls --json
\`\`\`

## On-Prem: App Export (2-step)

Step 1 — create export ticket:
\`\`\`bash
qlik qrs app export create <appId> --skipdata --json
\`\`\`

Step 2 — download QVF:
\`\`\`bash
qlik qrs download app get <filename>.qvf --appId <appId> --exportticketid <ticket> --output-file <path>
\`\`\`

## qlik-parser extract

Extract artifacts from a QVF file (on-prem only).

\`\`\`bash
qlik-parser extract --source <path-to-qvf> --out <output-dir> --script --measures --dimensions --variables
\`\`\`

**Output files:**
- `script.qvs` — reload script
- `measures.json` — master measures
- `dimensions.json` — master dimensions
- `variables.json` — variables
```

- [ ] **Step 8: Commit and push**

```bash
git add skills/sync/SKILL.md skills/sync/references/cli-commands.md
git commit -m "docs(sync): update SKILL.md for multi-tenant cloud+on-prem dispatch"
git push
```

---

### Task 8: Update setup skill for multi-tenant + on-prem

Update setup SKILL.md and tests for multi-tenant config and on-prem auth flow.

**Files:**
- Modify: `skills/setup/SKILL.md`
- Modify: `tests/test-setup.sh`

- [ ] **Step 1: Update setup SKILL.md**

Key changes to `skills/setup/SKILL.md`:

After Step 2 (Check for Existing Context), add tenant type detection:

```markdown
## Step 2.5: Detect Tenant Type

Based on the server URL:
- URL contains `.qlikcloud.com` → Cloud tenant
- Otherwise → On-prem Qlik Sense Enterprise

Confirm with the user:
> Detected this as a **[Cloud/On-prem]** Qlik tenant. Is that correct?

For **on-prem** tenants:
- Context creation uses `--server-type Windows --insecure`:
  ```bash
  qlik context create <name> --server https://server/jwt --api-key <JWT> --insecure --server-type Windows
  ```
- Check for qlik-parser: `which qlik-parser`
  - If missing: "On-prem sync requires qlik-parser. Download from https://github.com/mattiasthalen/qlik-parser/releases"
```

Update Step 4 (Connectivity Test):

```markdown
### Connectivity test
- **Cloud:** `qlik app ls --limit 1 --json`
- **On-prem:** `qlik qrs app ls --json`
```

Update Step 5 (Create Local Workspace) for multi-tenant config:

```markdown
## Step 5: Create Local Workspace

If `.qlik-sync/config.json` exists:
- Read existing config
- If v0.1.0 format, migrate to v0.2.0 first
- Append new tenant to `tenants` array

If new:
```json
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "<context-name>",
      "server": "<tenant-url>",
      "type": "<cloud|on-prem>",
      "lastSync": null
    }
  ]
}
```
```

- [ ] **Step 2: Update test-setup.sh**

Add content checks for on-prem mentions:

```bash
# On-prem support checks
assert_contains "mentions on-prem detection" "$CONTENT" "qlikcloud.com"
assert_contains "mentions qlik-parser" "$CONTENT" "qlik-parser"
assert_contains "mentions server-type Windows" "$CONTENT" "server-type Windows"
assert_contains "mentions multi-tenant config" "$CONTENT" "tenants"
```

- [ ] **Step 3: Run tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 4: Commit and push**

```bash
git add skills/setup/SKILL.md tests/test-setup.sh
git commit -m "feat(setup): add on-prem auth flow and multi-tenant config to setup skill"
git push
```

---

### Task 9: Update sync-finalize.sh for multi-tenant index

Update finalize to write tenant metadata into index.json.

**Files:**
- Modify: `skills/sync/scripts/sync-finalize.sh`
- Modify: `tests/test-sync-finalize.sh`

- [ ] **Step 1: Write failing test for tenant metadata in index**

Add to `tests/test-sync-finalize.sh` after existing tests:

```bash
# Test 4: Index includes tenant metadata
echo ""
echo "--- Test 4: Tenant metadata in index ---"
WORKDIR3="$TMPDIR_BASE/test-finalize-tenant"
mkdir -p "$WORKDIR3/.qlik-sync"
cat > "$WORKDIR3/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {"context": "test-ctx", "server": "https://test-tenant.qlikcloud.com", "type": "cloud", "lastSync": null}
  ]
}
JSON

PREP_TENANT="$TMPDIR_BASE/prep-tenant.json"
cat > "$PREP_TENANT" <<'JSON'
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
      "description": "",
      "tags": [],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "test-tenant (test-tenant-id)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false,
      "skipReason": ""
    }
  ]
}
JSON

RESULTS_TENANT="$TMPDIR_BASE/results-tenant.json"
echo '[{"resourceId": "app-001", "status": "synced"}]' > "$RESULTS_TENANT"

(cd "$WORKDIR3" && bash "$FINALIZE_SCRIPT" "$PREP_TENANT" "$RESULTS_TENANT") >/dev/null

INDEX3="$WORKDIR3/.qlik-sync/index.json"
assert_json_field "app-001 has tenant field" "$INDEX3" '.apps["app-001"].tenant' "test-tenant (test-tenant-id)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-finalize.sh`
Expected: FAIL — tenant field not in index

- [ ] **Step 3: Update sync-finalize.sh**

In `skills/sync/scripts/sync-finalize.sh`, update the jq expression that builds `APPS_OBJ` to include `tenant`:

```bash
TENANT_DIR="$TENANT ($TENANT_ID)"

APPS_OBJ="$(jq --arg tenantDir "$TENANT_DIR" '
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
      path: (.targetPath + "/"),
      tenant: $tenantDir
    }
  }] | from_entries
' "$PREP_FILE")"
```

Where `TENANT_DIR` is constructed from existing `TENANT` and `TENANT_ID` variables. Handle empty tenantId for on-prem:

```bash
if [ -n "$TENANT_ID" ]; then
  TENANT_DIR="$TENANT ($TENANT_ID)"
else
  TENANT_DIR="$TENANT"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync-finalize.sh`
Expected: All tests pass

- [ ] **Step 5: Update v0.2.0 lastSync handling**

Ensure finalize handles both v0.1.0 and v0.2.0 config when writing lastSync. This was already done in Task 3 Step 6.

- [ ] **Step 6: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 7: Commit and push**

```bash
git add skills/sync/scripts/sync-finalize.sh tests/test-sync-finalize.sh
git commit -m "feat(sync): add tenant field to index entries in finalize"
git push
```

---

### Task 10: Update sync-tenant.sh wrapper and end-to-end test

Update the convenience wrapper to handle multi-tenant dispatch and update the e2e test.

**Files:**
- Modify: `skills/sync/scripts/sync-tenant.sh`
- Modify: `tests/test-sync-script.sh`

- [ ] **Step 1: Update sync-tenant.sh**

Replace `skills/sync/scripts/sync-tenant.sh` entirely. The wrapper reads config, determines tenant type, and calls the right scripts:

```bash
#!/bin/bash
# sync-tenant.sh — Convenience wrapper that calls prep/app/finalize
# Usage: sync-tenant.sh [--space "Name"] [--stream "Name"] [--app "Pattern"] [--id <GUID>] [--force] [--tenant "ctx"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

# --- Parse flags (pass through to prep scripts) ---
FLAGS=()
TENANT_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tenant) TENANT_FILTER="$2"; FLAGS+=("$1" "$2"); shift 2 ;;
    --space|--stream|--app|--id) FLAGS+=("$1" "$2"); shift 2 ;;
    --force) FLAGS+=("$1"); shift ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

CONFIG_FILE=".qlik-sync/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. Run setup first." >&2
  exit 1
fi

TENANTS_JSON="$(read_tenant_config "$CONFIG_FILE" "$TENANT_FILTER")"
TENANT_COUNT="$(echo "$TENANTS_JSON" | jq 'length')"

if [ "$TENANT_COUNT" -eq 0 ]; then
  echo "Error: no matching tenant found." >&2
  exit 1
fi

PREP_FILE="$(mktemp)"
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$PREP_FILE" "$RESULTS_FILE"' EXIT

for i in $(seq 0 $((TENANT_COUNT - 1))); do
  TENANT_TYPE="$(echo "$TENANTS_JSON" | jq -r ".[$i].type")"

  # Choose prep and app scripts based on type
  if [ "$TENANT_TYPE" = "on-prem" ]; then
    PREP_SCRIPT="$SCRIPT_DIR/sync-onprem-prep.sh"
    APP_SCRIPT="$SCRIPT_DIR/sync-onprem-app.sh"
  else
    PREP_SCRIPT="$SCRIPT_DIR/sync-cloud-prep.sh"
    APP_SCRIPT="$SCRIPT_DIR/sync-cloud-app.sh"
  fi

  # Run prep
  bash "$PREP_SCRIPT" "${FLAGS[@]}" > "$PREP_FILE"

  APP_COUNT="$(jq '.totalApps' "$PREP_FILE")"
  if [ "$APP_COUNT" -eq 0 ]; then
    echo "No apps found."
    continue
  fi

  # Loop apps
  echo '[]' > "$RESULTS_FILE"
  IDX=0
  while IFS= read -r app_json; do
    IDX=$((IDX + 1))
    resource_id="$(jq -r '.resourceId' <<< "$app_json")"
    app_name="$(jq -r '.name' <<< "$app_json")"
    target_path="$(jq -r '.targetPath' <<< "$app_json")"
    space_type="$(jq -r '.spaceType' <<< "$app_json")"
    space_name="$(jq -r '.spaceName' <<< "$app_json")"
    skip="$(jq -r '.skip' <<< "$app_json")"

    if [ "$skip" = "true" ]; then
      echo "[$IDX/$APP_COUNT] SKIP: $space_type/$space_name / $app_name"
      jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "skipped"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    else
      echo "[$IDX/$APP_COUNT] Syncing: $space_type/$space_name / $app_name..."
      if bash "$APP_SCRIPT" "$resource_id" "$target_path" 2>&1; then
        jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "synced"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
      else
        echo "  WARNING: Failed to sync $app_name ($resource_id)" >&2
        jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "error", "error": "sync failed"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
      fi
    fi
  done < <(jq -c '.apps[]' "$PREP_FILE")

  # Finalize
  bash "$SCRIPT_DIR/sync-finalize.sh" "$PREP_FILE" "$RESULTS_FILE"
done
```

- [ ] **Step 2: Update test-sync-script.sh**

Update `tests/test-sync-script.sh`:
- Update `setup_workdir` to write v0.2.0 config format
- Keep all existing assertions — directory structure, index, resume, force, space filter, lastSync should all still work

In `setup_workdir`:

```bash
setup_workdir() {
  local workdir="$TMPDIR_BASE/test-$$-$RANDOM"
  mkdir -p "$workdir/.qlik-sync"
  cat > "$workdir/.qlik-sync/config.json" <<'JSON'
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "test-ctx",
      "server": "https://test-tenant.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    }
  ]
}
JSON
  echo "$workdir"
}
```

- [ ] **Step 3: Run all tests**

Run: `just test`
Expected: All tests pass

- [ ] **Step 4: Commit and push**

```bash
git add skills/sync/scripts/sync-tenant.sh tests/test-sync-script.sh
git commit -m "feat(sync): update wrapper for multi-tenant cloud+on-prem dispatch"
git push
```

---

### Task 11: Mark PR ready and update PR description

**Files:** None (git/GitHub operations only)

- [ ] **Step 1: Run full test suite**

Run: `just test`
Expected: All tests pass

- [ ] **Step 2: Update PR description**

```bash
gh pr edit 9 --body "$(cat <<'EOF'
## Summary
- Add on-prem Qlik Sense Enterprise (QSEoW) support to sync skill
- Multi-tenant config (v0.2.0) allowing cloud and on-prem tenants side by side
- On-prem uses `qlik qrs` commands + `qlik-parser` for extraction
- Rename cloud scripts to `sync-cloud-*` prefix, add `sync-onprem-*` counterparts
- Shared helpers in `sync-lib.sh`, shared `sync-finalize.sh`
- Updated setup skill for on-prem auth flow and type detection

## Closes
- #5

## Test plan
- [ ] `just test` passes all tests
- [ ] Cloud sync still works end-to-end (test-sync-script.sh)
- [ ] On-prem prep produces correct JSON (test-sync-onprem-prep.sh)
- [ ] On-prem app export+parse chain works (test-sync-onprem-app.sh)
- [ ] Config migration v0.1.0 → v0.2.0 (test-sync-lib.sh)
- [ ] Finalize handles tenant field (test-sync-finalize.sh)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Mark PR ready for review**

```bash
gh pr ready 9
```
