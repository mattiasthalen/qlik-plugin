# Sync Progress Decisions

## Decision 1: Progress Delivery Mechanism

### Context
Sync script emits progress lines (`[3/47] Syncing: Space / App...`) to stdout, but the Bash tool blocks until the script finishes. Users see no output during sync — only the final summary. Issues #3 and #4.

### Options considered

1. **Periodic polling** — Script writes progress to a temp file, skill polls at intervals
   - Pro: Minimal script changes
   - Con: Creates a file just for progress tracking — feels like a workaround
   - **Rejected**

2. **Streaming output** — Rely on Bash tool streaming stdout
   - Pro: No changes needed
   - Con: Bash tool doesn't stream — blocks until completion. Doesn't solve the problem.
   - **Rejected**

3. **Move loop to skill level** — Split script into prep/app/finalize phases, skill drives the loop
   - Pro: Claude naturally reports between each app. No temp files, no polling. Progress is organic.
   - Pro: Sets up #6 (parallel sync with multiple agents) — agents can each take a batch
   - Con: More Bash invocations, but each is small and fast
   - **Chosen**

### Decision
Move the sync loop from the script to the skill. Split `sync-tenant.sh` into three scripts: `sync-prep.sh` (fetch + resolve), `sync-app.sh` (unbuild one app), `sync-finalize.sh` (build index). Skill orchestrates the loop and reports progress with ETA after a timing baseline.

---

## Decision 2: Script Decomposition Strategy

### Context
With the loop moving to the skill, the monolithic `sync-tenant.sh` needs to be restructured. Two approaches: pure skill orchestration vs. script phases.

### Options considered

1. **Pure skill orchestration** — Skill does everything (fetch, resolve, unbuild, index)
   - Pro: Maximum control, no scripts
   - Con: Complex SKILL.md, harder to test, fragile if Claude misinterprets
   - **Rejected**

2. **Prep + App + Finalize scripts** — Scripts handle data plumbing, skill handles orchestration
   - Pro: Clean separation — bash for jq/file ops, skill for user interaction
   - Pro: Each script is independently testable
   - Con: Three entry points instead of one
   - **Chosen**

3. **Single script with callback mode** — `--progress-callback` outputs JSON lines
   - Pro: Single script
   - Con: Still blocks on Bash call — doesn't solve delivery without polling
   - **Rejected**

### Decision
Split into three scripts. Keep `sync-tenant.sh` as convenience wrapper for CLI usage. Skill uses the three scripts individually.

---

## Decision 3: Progress Format

### Context
Need to decide how progress is displayed to the user during sync.

### Options considered

1. **Current format** — `[N/Total] Action: Space / App`
   - Pro: Already exists, clear and readable
   - **Chosen**

2. **With timing per-line** — `[3/47] Synced: Space / App (2.3s)`
   - Pro: More detail
   - Con: Adds noise, not clearly useful per-line
   - **Rejected**

3. **With emoji/symbols** — `✓ [3/47] Synced: ...`
   - Pro: Visual distinction
   - Con: User prefers no emoji unless requested
   - **Rejected**

### Decision
Keep current format. Add ETA after first few apps establish a timing baseline (smart ETA). Counter is always shown, ETA appears after ~3 apps.
