# Parallel Sync Decisions

## Decision 1: Parallelism Level

### Context
Sync processes apps sequentially, which is slow for large environments (issue #6). Need to decide where parallelism lives.

### Options considered

1. **Bash-level parallelism** — `xargs -P` or background jobs within sync script
   - Pro: Minimal architecture change
   - Con: stdout interleaving, fragile error tracking, no distributed benefit
   - **Rejected**

2. **Claude Code agent-level parallelism** — skill spawns multiple agents, each handling a batch
   - Pro: Clean isolation per batch, leverages Claude Code's native agent model
   - Pro: Each agent independent — clean error reporting
   - Con: Token cost scales with agent count
   - **Chosen**

### Decision
Use Claude Code agent-level parallelism. Skill dispatches multiple agents, each calling `sync-app.sh` for its batch of apps.

---

## Decision 2: Script Architecture

### Context
With #3 restructuring sync into prep/app/finalize scripts, need to decide if parallel sync needs additional scripts.

### Options considered

1. **New worker script** — `sync-worker.sh` handles batch orchestration
   - Pro: Encapsulates batch logic in bash
   - Con: Extra file, batch orchestration is skill-level concern
   - **Rejected**

2. **Dispatch logic in SKILL.md** — skill splits batches, spawns agents, collects results
   - Pro: Orchestration is what skills are for — splitting arrays, spawning agents, collecting results
   - Pro: No new scripts to maintain
   - **Chosen**

### Decision
No new scripts. Dispatch logic lives in SKILL.md. Agents reuse `sync-app.sh` from #3.

---

## Decision 3: Index Building Strategy

### Context
With multiple agents syncing concurrently, need to decide how index.json gets built.

### Options considered

1. **Agents return results, dispatcher finalizes once** — each agent produces results JSON array, skill concatenates all into one, calls `sync-finalize.sh` once
   - Pro: Single finalize call, no merge conflicts, fits existing interface
   - **Chosen**

2. **Each agent calls finalize** — produces partial indexes that need merging
   - Pro: Agents self-contained
   - Con: Requires index merge logic, risk of conflicts
   - **Rejected**

### Decision
Agents return results JSON arrays. Skill concatenates and calls `sync-finalize.sh` once with merged results.

---

## Decision 4: Error Handling

### Context
Agents can fail mid-batch (crash, timeout, network error). Need a strategy.

### Options considered

1. **Best-effort** — collect results from successful agents, mark missing apps as errors, finalize with what we have
   - Pro: Matches current resume-on-failure pattern, user re-runs for failed apps
   - **Chosen**

2. **Retry failed batches** — re-dispatch failed batch to new agent
   - Pro: Higher success rate
   - Con: Adds complexity, unclear when to give up
   - **Rejected**

3. **Abort all** — stop everything on any agent failure
   - Pro: Simple
   - Con: Wastes successful work
   - **Rejected**

### Decision
Best-effort. Failed agent batches marked as errors in results. User can re-run to retry.

---

## Decision 5: Concurrency Control

### Context
Need to decide how many agents to spawn and how to distribute apps.

### Options considered

1. **Fixed batch size (10), variable agents** — always 10 per agent, agent count scales
   - Pro: Predictable per-agent load
   - Con: Could spawn too many agents for large tenants
   - **Rejected**

2. **Auto-scaled, capped at 5** — `agents = min(nonSkipApps, 5)`, distribute evenly, remainder to last agent
   - Pro: Maximum parallelism up to cap, no config needed
   - Pro: Single code path — always dispatch agents, no sequential fallback
   - **Chosen**

### Decision
`agents = min(nonSkipApps, 5)`. First N-1 agents get `floor(apps/agents)`, last agent gets the rest. No manual override.

---

## Decision 6: Progress Reporting

### Context
Need to decide granularity of progress during parallel sync.

### Options considered

1. **Batch-level progressive** — report as each agent completes: "Batch N/M complete: X synced, Y errors"
   - Pro: User sees progress as work completes, maintains organic feel from #3
   - **Chosen**

2. **All-or-nothing** — wait for all agents, report once
   - Pro: Simplest
   - Con: No visibility during sync
   - **Rejected**

3. **Per-app from agents** — agents report per-app, skill relays
   - Pro: Most granular
   - Con: Agent output not visible to user, defeats parallelism to relay
   - **Rejected**

### Decision
Progressive batch-level reporting. Skipped apps reported immediately before dispatch. Batch completions reported as agents finish.
