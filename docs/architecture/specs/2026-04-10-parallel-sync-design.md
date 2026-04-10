# Parallel Sync Design

**Issue:** #6 (parallelize sync with multiple agents)
**Depends on:** #3/#4 (sync progress — prep/app/finalize script split)
**Decision doc:** `docs/architecture/decisions/2026-04-10-parallel-sync-decision.md`

## Overview

Extend the sync skill to dispatch multiple Claude Code agents in parallel, each syncing a batch of apps via `sync-app.sh`. Skill orchestrates prep, batch splitting, agent dispatch, progressive reporting, and finalization.

## Architecture

```
User: "sync my apps"
         │
         ▼
┌─────────────────────────────────────────────┐
│              Sync Skill (SKILL.md)          │
│                                             │
│  1. Parse intent → flags                    │
│  2. Run sync-prep.sh → prep.json            │
│  3. Report: "Found 47 apps (12 skip, 35 sync)" │
│  4. Report skips: [1/47] SKIP: Space / App  │
│  5. Split 35 non-skip apps into batches     │
│  6. Dispatch agents ──┬──▶ Agent 1 (9 apps) │
│                       ├──▶ Agent 2 (9 apps) │
│                       ├──▶ Agent 3 (9 apps) │
│                       └──▶ Agent 4 (8 apps) │
│  7. As each completes:                      │
│     "Batch 1/4 complete: 9 synced, 0 errors"│
│  8. Concatenate all results + skips          │
│  9. Run sync-finalize.sh → index.json       │
│ 10. Report summary                          │
└─────────────────────────────────────────────┘

Each Agent:
┌────────────────────────────────┐
│  Receives: batch of app objects│
│  For each app:                 │
│    sync-app.sh <id> <path>     │
│  Returns: results JSON array   │
│  [{"resourceId":"...",         │
│    "status":"synced|error"}]   │
└────────────────────────────────┘
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
  bash {SKILL_ROOT}/scripts/sync-app.sh {resourceId} {targetPath}

After processing all apps, return a JSON array of results:
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "error", "error": "unbuild failed: ..."}
]

Rules:
- Process apps sequentially within your batch
- On sync-app.sh failure (non-zero exit), mark status "error" with stderr as error message
- Continue to next app on failure — do not abort batch
- Return the complete results array when done

Apps to sync:
{JSON array of app objects from prep}
```

### Agent allowed-tools

Agents use Bash tool within their own context. Each agent calls:
- `Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh <resourceId> <targetPath>)`

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
  # From #3 (prep/app/finalize)
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep.json:*)"
  - "Bash(cat /tmp/qlik-sync-results.json:*)"
  - Bash(qlik app ls:*)
  - Bash(date:*)
  - Read
  - Write
  # New for #6 (parallel dispatch)
  - Agent
```

### Orchestration steps

1. **Parse user intent** — translate request to flags (same as #3)

2. **Warn on scale** — if >50 apps, prompt user before proceeding (same as #3)

3. **Run prep:**
   ```bash
   bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh [flags] > /tmp/qlik-sync-prep.json
   ```

4. **Report plan:**
   - Read prep JSON
   - Count skip vs non-skip apps
   - "Found 47 apps (12 already synced, 35 to sync)"

5. **Report skips** — for each app with `skip: true`:
   - `[N/Total] SKIP: SpaceName / AppName (skipReason)`

6. **Split batches:**
   - Filter non-skip apps from prep JSON
   - Calculate: `agents = min(nonSkipApps, 5)`
   - First N-1 batches: `floor(nonSkipApps / agents)` apps
   - Last batch: remaining apps
   - If 0 non-skip apps: skip to step 9

7. **Dispatch agents:**
   - Spawn all agents simultaneously
   - Each agent gets its batch of app objects + sync-app.sh path
   - Report: "Dispatching {agents} parallel agents..."

8. **Collect results progressively:**
   - As each agent completes, report: `Batch N/M complete: X synced, Y errors`
   - On agent failure: mark batch apps as errors, report: `Batch N/M FAILED: agent error`
   - After all agents done, concatenate all result arrays

9. **Build combined results:**
   - Merge: skip results + all agent results
   - Write to `/tmp/qlik-sync-results.json`

10. **Run finalize:**
    ```bash
    bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh /tmp/qlik-sync-prep.json /tmp/qlik-sync-results.json
    ```

11. **Report summary** from finalize stdout

## Progress Output Example

```
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

## No New Scripts

All changes are in `skills/sync/SKILL.md`. No new bash scripts needed — agents reuse `sync-app.sh` from #3.

## Migration

- SKILL.md gains parallel dispatch path alongside #3's sequential loop
- `allowed-tools` adds `Agent`
- No breaking changes — parallel dispatch is transparent to user
- Existing `.qlik-sync/` data fully compatible
