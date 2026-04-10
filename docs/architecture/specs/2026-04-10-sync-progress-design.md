# Sync Progress Design

**Issues:** #3 (sync task shows no status in chat), #4 (add progress indicator for sync operations)
**Decision doc:** `docs/architecture/decisions/2026-04-10-sync-progress-decision.md`

## Overview

Restructure sync from a single monolithic script call into a skill-driven loop with three script phases. Claude orchestrates the loop, reports progress naturally between each app, and provides ETA after establishing a timing baseline.

## Architecture

```
┌─────────────┐     JSON      ┌──────────┐
│ sync-prep.sh │──────────────▶│  Skill   │
└─────────────┘               │  (loop)  │
                              │          │
                   per app    │  tracks  │
              ┌──────────────▶│  timing  │
              │   exit code   │  + ETA   │
┌─────────────┐               │          │
│ sync-app.sh  │◀──────────────│          │
└─────────────┘    args       │          │
                              │          │
┌──────────────────┐  files   │          │
│ sync-finalize.sh  │◀─────────│          │
└──────────────────┘          └──────────┘
```

## Scripts

### sync-prep.sh

**Purpose:** Fetch app list, resolve spaces/owners, determine skip status, output structured JSON.

**Interface:**
```bash
bash sync-prep.sh [--space "Name"] [--app "Pattern"] [--id "uuid"] [--force]
# stdout: JSON object (see format below)
# stderr: errors/warnings
# exit 0: success, exit 1: failure (no config, auth error, etc.)
```

**Output JSON:**
```json
{
  "tenant": "my-tenant",
  "tenantId": "abc-123",
  "context": "my-context",
  "server": "https://my-tenant.qlikcloud.com",
  "totalApps": 47,
  "apps": [
    {
      "resourceId": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "spaceName": "Finance Prod",
      "spaceType": "managed",
      "appType": "analytics",
      "ownerId": "user-001",
      "ownerName": "jane.doe",
      "description": "Monthly sales KPIs",
      "tags": ["finance", "monthly"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "targetPath": "my-tenant (abc-123)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)",
      "skip": false
    },
    {
      "resourceId": "app-002",
      "name": "Old Report",
      "spaceName": "Finance Prod",
      "targetPath": "...",
      "skip": true,
      "skipReason": "already synced (use --force to re-sync)"
    }
  ]
}
```

**Responsibilities:**
- Read `.qlik-sync/config.json` for context/server
- Fetch spaces via `qlik space ls --json`, build lookup
- Fetch apps based on filters (`--space`, `--app`, `--id`, or all)
- Resolve space names, types, owner names
- Determine `targetPath` using existing directory structure logic
- Check resume status: if `config.yml` exists in target path and `--force` not set, mark `skip: true`
- All resolution happens once upfront — no per-app API calls during loop

### sync-app.sh

**Purpose:** Sync a single app — create directory and unbuild.

**Interface:**
```bash
bash sync-app.sh <resourceId> <targetPath>
# Creates: .qlik-sync/<targetPath>/
# Runs: qlik app unbuild --app <resourceId> --dir .qlik-sync/<targetPath>
# stdout: nothing (skill handles all user-facing output)
# stderr: error details if unbuild fails
# exit 0: success, exit 1: failure
```

**Responsibilities:**
- `mkdir -p .qlik-sync/<targetPath>`
- `qlik app unbuild --app <resourceId> --dir .qlik-sync/<targetPath>`
- Clean exit codes — 0 success, 1 failure

### sync-finalize.sh

**Purpose:** Build/merge index.json and update config.

**Interface:**
```bash
bash sync-finalize.sh <prep-json-file> <results-json-file>
# prep-json-file: saved output from sync-prep.sh
# results-json-file: JSON array built by skill during loop
# stdout: summary line ("35 synced, 12 skipped, 0 errors (47 apps in index)")
# exit 0: success
```

**Results JSON format (built by skill):**
```json
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "skipped"},
  {"resourceId": "app-003", "status": "error", "error": "unbuild failed"}
]
```

**Responsibilities:**
- Build index entries from prep metadata + results
- If partial sync and existing index.json: merge (update synced apps, keep others)
- Write `.qlik-sync/index.json`
- Update `.qlik-sync/config.json` with `lastSync` timestamp
- Output human-readable summary to stdout

### sync-tenant.sh (updated)

**Purpose:** Convenience wrapper that calls all three phases. Keeps CLI usage working.

**Interface:** Same as current — `bash sync-tenant.sh [flags]`

**Implementation:** Calls prep → loops apps (calling sync-app per app) → calls finalize. Outputs progress lines to stdout as before.

## Skill (SKILL.md) Changes

### Updated allowed-tools

```yaml
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep-*.json:*)"
  - "Bash(cat /tmp/qlik-sync-results-*.json:*)"
  - Bash(qlik app ls:*)
  - Bash(date:*)
  - Read
  - Write
```

### Skill Flow

1. **Parse user intent** — same as current (translate to flags)
2. **Warn on scale** — same as current (>50 apps prompt)
3. **Run prep:**
   ```bash
   bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh [flags] > /tmp/qlik-sync-prep-$$.json
   ```
4. **Report plan:** "Found 47 apps (12 already synced, 35 to sync)"
5. **Loop through apps** from prep JSON:
   - Record start time
   - For each app:
     - If `skip: true` → report `[N/Total] SKIP: Space / App` → append to results
     - Else → run `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh <id> <path>`
     - On success → report `[N/Total] Synced: Space / App`
     - On failure → report `[N/Total] ERROR: Space / App` → continue
     - After 3+ synced apps, include ETA: `(~Xm remaining)`
     - Append result to results JSON
6. **Write results** to `/tmp/qlik-sync-results-$$.json`
7. **Run finalize:**
   ```bash
   bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh /tmp/qlik-sync-prep-$$.json /tmp/qlik-sync-results-$$.json
   ```
8. **Report summary** from finalize stdout

### ETA Calculation

- Track wall-clock time for each non-skipped app
- After 3 apps synced, compute rolling average seconds-per-app
- Remaining estimate = average × remaining non-skip apps
- Display as `~Xm remaining` or `~Xs remaining`

## Testing

### test-sync-prep.sh
- Outputs valid JSON with correct structure
- Respects `--space` filter (only matching apps)
- Respects `--app` filter (name pattern matching)
- Respects `--id` filter (single app)
- Marks apps as `skip: true` when already synced
- `--force` overrides skip
- Resolves space names and types correctly
- Resolves owner names correctly
- Builds correct `targetPath`

### test-sync-app.sh
- Creates target directory
- Calls `qlik app unbuild` with correct args
- Returns exit 0 on success
- Returns exit 1 on unbuild failure
- Does not write to stdout

### test-sync-finalize.sh
- Builds correct index.json from prep + results
- Merges partial sync with existing index
- Updates config.json lastSync
- Outputs correct summary line
- Handles all-skipped case
- Handles all-error case

### test-sync-script.sh (updated)
- Wrapper still works end-to-end
- Calls all three phases in sequence

### test-sync.sh (updated)
- Skill-level validation of SKILL.md instructions

All tests use existing `helpers.sh` and `mock-qlik/` fixtures.

## Migration

- `sync-tenant.sh` refactored into three scripts + updated wrapper
- No breaking changes to CLI usage (wrapper preserves interface)
- SKILL.md updated with new flow
- Existing `.qlik-sync/` data fully compatible
