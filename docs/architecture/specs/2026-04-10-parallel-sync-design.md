# Parallel Sync Design

**Issue:** #6 (parallelize sync with multiple agents)
**Depends on:** #3/#4 (sync progress — prep/app/finalize script split), on-prem sync
**Decision doc:** `docs/architecture/decisions/2026-04-10-parallel-sync-decision.md`

## Overview

Extend the sync skill to dispatch multiple Claude Code agents in parallel, each syncing a batch of apps via the tenant-appropriate app script (`sync-cloud-app.sh` or `sync-onprem-app.sh`). Skill orchestrates prep, batch splitting, agent dispatch, progressive reporting, and finalization. Parallel dispatch happens per-tenant.

## Architecture

```
User: "sync my apps"
         │
         ▼
┌───────────────────────────────────────────────────┐
│              Sync Skill (SKILL.md)                │
│                                                   │
│  1. Parse intent → flags                          │
│  2. For each tenant:                              │
│     a. Run sync-{cloud|onprem}-prep.sh → prep.json│
│     b. Report: "Found 47 apps (12 skip, 35 sync)"│
│     c. Report skips: [1/47] SKIP: Space / App     │
│     d. Split 35 non-skip apps into batches        │
│     e. Dispatch ──┬──▶ Agent 1 (9 apps)           │
│                   ├──▶ Agent 2 (9 apps)           │
│                   ├──▶ Agent 3 (9 apps)           │
│                   └──▶ Agent 4 (8 apps)           │
│     f. As each completes:                         │
│        "Batch 1/4 complete: 9 synced, 0 errors"  │
│     g. Concatenate all results + skips            │
│     h. Run sync-finalize.sh → index.json          │
│  3. Report summary                                │
└───────────────────────────────────────────────────┘

Each Agent:
┌──────────────────────────────────────────────┐
│  Receives: batch of app objects + script path│
│  For each app:                               │
│    sync-{cloud|onprem}-app.sh <id> <path>    │
│  Returns: results JSON array                 │
│  [{"resourceId":"...",                       │
│    "status":"synced|error"}]                 │
└──────────────────────────────────────────────┘
```

## Batch Splitting

**Formula:** `agents = min(nonSkipApps, 5)`

Distribution: first N-1 agents get `floor(apps / agents)`, last agent gets the rest.

| To sync | Agents | Distribution        |
|---------|--------|---------------------|
| 1       | 1      | 1                   |
| 3       | 3      | 1, 1, 1             |
| 6       | 5      | 1, 1, 1, 1, 2      |
| 10      | 5      | 2, 2, 2, 2, 2      |
| 47      | 5      | 9, 9, 9, 9, 11     |
| 100     | 5      | 20, 20, 20, 20, 20 |

Skipped apps excluded from batches — reported by skill before dispatch.

## Agent Contract

### Prompt template

```
Sync batch {N} of {M} for parallel sync.

For each app in the list below, run:
  bash {syncAppScript} "{resourceId}" "{targetPath}"

After processing all apps, return a JSON array of results:
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "error", "error": "unbuild failed: ..."}
]

Rules:
- Process apps sequentially within your batch
- On script failure (non-zero exit), mark status "error" with stderr as error message
- Continue to next app on failure — do not abort batch
- Return the complete results array when done

Apps to sync:
{JSON array of app objects from prep}
```

Where `{syncAppScript}` is resolved by the skill to the absolute path of:
- `sync-cloud-app.sh` for cloud tenants
- `sync-onprem-app.sh` for on-prem tenants

### Agent allowed-tools

Agents use Bash tool within their own context. Each agent calls:
- `Bash(bash <resolvedPath>/scripts/sync-cloud-app.sh <resourceId> <targetPath>)` (cloud)
- `Bash(bash <resolvedPath>/scripts/sync-onprem-app.sh <resourceId> <targetPath>)` (on-prem)

The `${CLAUDE_SKILL_ROOT}` path must be resolved by the skill and passed as a literal in the agent prompt.

### Agent return value

JSON array of results:
```json
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "error", "error": "stderr from sync-app.sh"}
]
```

### Agent failure

If an agent crashes or times out, skill marks all apps in that batch:
```json
{"resourceId": "app-XXX", "status": "error", "error": "agent failed"}
```

## Skill Flow (SKILL.md)

### Updated allowed-tools

```yaml
allowed-tools:
  # Existing (cloud + on-prem prep/app + finalize)
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
  - Bash(which:*)
  - Bash(date:*)
  - Read
  - Write
  # New for #6 (parallel dispatch)
  - Agent
```

### Orchestration steps

1. **Parse user intent** — translate request to flags (same as current)

2. **Warn on scale** — if >50 apps, prompt user before proceeding (same as current)

3. **For each tenant** in config (or filtered by `--tenant`):

   a. **Run prep** — cloud or on-prem prep script based on tenant type:
      ```bash
      bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh [flags] > /tmp/qlik-sync-prep.json
      # or
      bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-prep.sh [flags] > /tmp/qlik-sync-prep.json
      ```

   b. **Report plan:**
      - Read prep JSON, count skip vs non-skip apps
      - "Found 47 apps (12 already synced, 35 to sync)"

   c. **Report skips** — for each app with `skip: true`:
      - `[N/Total] SKIP: SpaceName / AppName (skipReason)`

   d. **Split batches:**
      - Filter non-skip apps from prep JSON
      - Calculate: `agents = min(nonSkipApps, 5)`
      - First N-1 batches: `floor(nonSkipApps / agents)` apps
      - Last batch: remaining apps
      - If 0 non-skip apps: skip to step g

   e. **Dispatch agents:**
      - Resolve `${CLAUDE_SKILL_ROOT}` to absolute path
      - Determine script: `sync-cloud-app.sh` (cloud) or `sync-onprem-app.sh` (on-prem)
      - Spawn all agents simultaneously
      - Report: "Dispatching {agents} parallel agents..."

   f. **Collect results progressively:**
      - As each agent completes, report: `Batch N/M complete: X synced, Y errors`
      - On agent failure: mark batch apps as errors, report: `Batch N/M FAILED: agent error`
      - After all agents done, concatenate all result arrays

   g. **Build combined results:**
      - Merge: skip results + all agent results
      - Write to `/tmp/qlik-sync-results.json`

   h. **Run finalize:**
      ```bash
      bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh /tmp/qlik-sync-prep.json /tmp/qlik-sync-results.json
      ```

4. **Report summary** from finalize stdout

## Progress Output Example

```
=== Cloud tenant: my-tenant.qlikcloud.com ===
Found 47 apps (12 already synced, 35 to sync)

[1/47] SKIP: Finance Prod / Sales Dashboard (already synced)
[2/47] SKIP: Finance Prod / Budget Report (already synced)
... (10 more skips)

Dispatching 4 parallel agents...

Batch 1/4 complete: 9 synced, 0 errors
Batch 3/4 complete: 9 synced, 0 errors
Batch 2/4 complete: 8 synced, 1 error
Batch 4/4 complete: 8 synced, 0 errors

Sync complete: 34 synced, 12 skipped, 1 error (47 apps in index)

=== On-prem tenant: qlik-server.corp.local ===
Found 15 apps (0 already synced, 15 to sync)

Dispatching 5 parallel agents...
...
```

Note: batch completion order may differ from dispatch order.

## Testing

### test-sync.sh (updated)

Skill-level validation that SKILL.md contains:
- Agent dispatch instructions
- Batch splitting logic (min of nonSkipApps and 5)
- Distribution rule (floor for first N-1, remainder to last)
- Progressive batch reporting instructions
- Zero non-skip apps handling (skip to finalize)
- Results concatenation before finalize
- Agent failure handling (mark batch as errors)

### Manual integration test scenarios

Agent dispatch is skill-level orchestration — can't be automated with mock-qlik:

1. **Small sync (3 apps)** — 3 agents spawned, 1 app each
2. **Medium sync (25 apps)** — 5 agents, distribution 5,5,5,5,5
3. **Agent failure** — verify other batches complete, failed batch marked as errors
4. **All skipped** — no agents spawned, straight to finalize
5. **Mixed skip/sync** — only non-skip apps dispatched to agents
6. **Multi-tenant** — cloud + on-prem tenants each get their own parallel dispatch

## No New Scripts

All changes are in `skills/sync/SKILL.md`. No new bash scripts needed — agents reuse `sync-cloud-app.sh` and `sync-onprem-app.sh`.

## Migration

- SKILL.md Step 4 replaced with parallel dispatch
- `allowed-tools` adds `Agent`
- No breaking changes — parallel dispatch is transparent to user
- Works with both cloud and on-prem tenants
- Existing `.qlik-sync/` data fully compatible
