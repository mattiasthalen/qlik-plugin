# Qlik Plugin Decisions

## Decision 1: v0.1.0 Scope — Read-Only First

### Context
Plugin has 5 potential skills (setup, sync, push, reload, inspect). Need to decide what ships first for a public release.

### Options considered

1. **All 5 skills** — full read/write/reload cycle
   - Pro: Complete story from day one
   - Con: Push/reload involve production writes — high risk for v0.1.0, harder to test safely
   - **Rejected**

2. **Setup + sync + inspect (read-only)** — "git clone for Qlik"
   - Pro: Highest-value experience (explore entire tenant locally) with lowest risk (no writes)
   - Pro: Inspect is cheap to build and enables the core use case (ask Claude about your Qlik environment)
   - Con: No round-trip editing yet
   - **Chosen**

3. **Setup + sync + push** — round-trip without inspect
   - Pro: Enables editing workflow
   - Con: Inspect (Claude grepping local files) is the highest-value skill for the "teach Claude about Qlik" story
   - **Rejected**

### Decision
Ship v0.1.0 as read-only: setup + sync + inspect. Push and reload move to v0.2.0. The core value proposition is making Qlik logic locally available for Claude to reason about — writes can wait.

---

## Decision 2: Auth Scope — Cloud-Only for v0.1.0

### Context
qlik-cli supports both cloud (OAuth) and on-prem (JWT). Need to decide auth scope.

### Options considered

1. **Cloud-only auth**
   - Pro: Can verify against real tenant during development
   - Pro: `qlik app unbuild` is SaaS-only — on-prem can't use the core sync feature anyway
   - Con: Excludes on-prem users
   - **Chosen**

2. **Both cloud and on-prem**
   - Pro: Broader audience
   - Con: Can't test on-prem, and unbuild doesn't work there — misleading to offer it
   - **Rejected**

### Decision
Cloud-only for v0.1.0. On-prem support is blocked by `qlik app unbuild` being SaaS-only. Revisit when on-prem has equivalent functionality or we build an alternative extraction path.

---

## Decision 3: Architecture — Skills-as-Instructions vs Script-Wrapped

### Context
Original spec had bash scripts (`sync-tenant.sh`, `build-index.sh`) doing the heavy lifting, with skills calling scripts. Research into real Claude Code plugins showed a different pattern: skills are instructional documents that teach Claude how to operate tools directly.

### Options considered

1. **Script-heavy** — bash scripts handle pagination, looping, indexing; skills call scripts
   - Pro: Testable with mock binaries, portable
   - Con: Rigid — can't adapt to CLI output changes without script updates
   - Con: Duplicates Claude's native capabilities (looping, JSON processing, error handling)
   - Con: Doesn't match how successful plugins work
   - **Rejected**

2. **Skills-as-instructions** — skills teach Claude the qlik-cli; Claude orchestrates directly
   - Pro: Matches real plugin patterns (superpowers, caveman)
   - Pro: More powerful — Claude adapts to unexpected output, handles errors contextually
   - Pro: Less code to maintain
   - Pro: Claude can explain what it's doing as it goes
   - Con: Harder to unit test (testing becomes integration testing against real/mock CLI)
   - **Chosen**

3. **Hybrid** — skills orchestrate, thin helper scripts for heavy operations (parallel unbuild)
   - Pro: Best of both — Claude orchestrates, scripts handle parallelism
   - Con: Premature optimization; can add scripts later if needed
   - **Rejected for v0.1.0, viable for future**

### Decision
Skills-as-instructions. No `scripts/` directory in v0.1.0. Skills are rich instructional documents teaching Claude how to use qlik-cli. If parallel unbuild becomes a bottleneck at scale, add a helper script in a future version.

---

## Decision 4: CLI Installation — Prerequisite Only

### Context
Need to decide how much installer magic the setup skill provides.

### Options considered

1. **Full auto-install** — detect OS, download binary, manage PATH
   - Pro: Seamless first experience
   - Con: Fragile (GitHub rate limits, PATH issues, permission differences across OS)
   - **Rejected**

2. **Guided manual** — detect OS, tell user exact command, verify after
   - Pro: Same UX with less breakage
   - Con: Still maintaining OS-specific install instructions
   - **Rejected**

3. **Prerequisite check only** — verify `qlik` on PATH, link to docs if missing
   - Pro: Simple, maintainable, user takes responsibility for their own toolchain
   - Pro: qlik-cli install docs are maintained upstream
   - Con: Less hand-holding
   - **Chosen**

### Decision
Prerequisite check only. Setup skill verifies `qlik` and `jq` are on PATH, links to official install docs if missing, then guides auth flow.

---

## Decision 5: Index Richness — Rich Metadata

### Context
After sync, an `index.json` maps app IDs to metadata. Need to decide how much metadata to capture.

### Options considered

1. **Minimal** — app ID, name, path
   - **Rejected** — too little for meaningful search/filter

2. **Moderate** — name, space, owner, lastReload, path
   - **Rejected** — data is available, no reason to leave it out

3. **Rich** — name, space, owner, lastReload, description, tags, published status, path
   - Pro: Enables richer inspect queries at zero additional sync cost (data comes from `qlik app ls --json`)
   - Con: None — it's just plucking more fields from existing JSON
   - **Chosen**

### Decision
Rich index. Include all useful metadata from `qlik app ls --json` output.

---

## Decision 6: Scale Strategy — Space Filtering + Resume

### Context
Real tenant sizes are 200-800 apps (prod + dev + extract + transform). Sequential unbuild of 500+ apps is slow.

### Options considered

1. **Sequential, no filtering** — unbuild everything every time
   - **Rejected** — too slow for 500+ apps

2. **Space filtering + resume + progress reporting**
   - Pro: Users sync what they need (e.g., just "Finance Prod" space)
   - Pro: Resume-on-failure prevents restarting from scratch
   - Pro: Progress reporting gives confidence during long syncs
   - **Chosen**

3. **Parallel unbuild**
   - Deferred to future — add helper script if sequential is too slow even with filtering
   - **Rejected for v0.1.0**

### Decision
Space filtering and resume-on-failure in v0.1.0. Progress reporting via Claude's natural output. Parallel unbuild deferred.

---

## Decision 7: Testing Strategy — Mock-Based + Devcontainer Integration

### Context
Need to test skill-guided workflows. Skills are markdown (not directly testable), but the CLI interactions they describe are.

### Options considered

1. **No tests** — manual testing only
   - **Rejected** — public plugin needs reliability

2. **Mock-based tests** — fake `qlik` binary returning canned JSON, test the expected command sequences
   - Pro: TDD-compatible, no real tenant needed
   - Pro: Tests validate that skills describe correct commands and handle expected output
   - **Chosen (primary)**

3. **Integration tests** — run against real tenant
   - Pro: Validates real CLI behavior
   - Con: Requires auth, network, real apps
   - **Chosen (secondary)** — qlik-cli added to devcontainer for manual integration testing

### Decision
Mock-based tests as primary automated testing. qlik-cli installed in devcontainer for integration testing by developers who sign in.

---

## Decision 8: Future Direction — Go CLI

### Context
Bash scripts (if added later) will eventually hit complexity limits as push/reload add write operations.

### Decision
Future migration path: each operation that outgrows bash becomes a Go subcommand. No Go code in v0.1.0. Noted as architectural direction for v0.2.0+.

---

## Decision 9: Pagination — No Script Logic Needed

### Context
Original spec described scripts managing pagination loops for `qlik app ls`.

### Discovery
`qlik-cli` handles pagination internally. `qlik app ls --json --limit 1000` auto-paginates behind the scenes — the CLI makes multiple API requests transparently.

### Decision
No pagination logic in skills or scripts. Teach Claude to use `--limit` flag with a value higher than expected app count. CLI handles the rest.

---

## Decision 10: Fixture Data Shape — Real Structure, Fictional Data

### Context
Integration testing against a real Qlik Cloud tenant (v3.0.0) revealed that `qlik app ls --json` output is structurally different from our test fixtures. The real output nests most fields under `resourceAttributes`, uses `resourceId` for the app GUID, and stores tags in `meta.tags` as objects. Our fixtures assumed a flat structure based on documentation rather than verified CLI output.

### Options considered

1. **Minimal fix** — update fixture structure only, keep fictional data
   - Pro: Quick
   - Con: Same approach
   - **Rejected** (same as chosen, just less precise naming)

2. **Real data from tenant** — capture actual output as fixtures
   - Pro: Most accurate
   - Con: Ties to specific tenant, may contain sensitive info
   - **Rejected**

3. **Real structure, fictional data** — use verified v3.0.0 output shape with fictional app names/IDs
   - Pro: Tests stay clean and self-documenting, structure matches production
   - Pro: Mock binary and skills use correct field paths
   - **Chosen**

### Decision
Rewrite all fixtures to match real qlik-cli v3.0.0 output structure. Keep fictional app names and IDs for readable tests. Update mock binary, skills, and CLI reference to use correct field paths (`resourceId`, `resourceAttributes.*`, `meta.tags`).

---

## Decision 11: Sync Architecture — Bash Script Bridge

### Context
Integration testing against a real 134-app tenant revealed that the sync workflow is purely mechanical: list apps, resolve spaces, loop unbuild, build index. Claude orchestrating this loop wastes tokens and is slow. Additionally, duplicate app names (30 apps named "Test App") cause folder collisions, and some space IDs don't resolve via `qlik space ls`.

### Options considered

1. **Go CLI now** — build a Go binary for sync in v0.1.0
   - Pro: Fast, proper, handles all edge cases
   - Con: Adds Go toolchain dependency, premature for v0.1.0
   - **Rejected for v0.1.0**

2. **Keep skills-only** — fix duplicate handling in the skill, Claude still orchestrates the loop
   - Pro: No new code
   - Con: Slow (Claude runs 134 sequential commands), wasteful, error-prone
   - **Rejected**

3. **Bash script bridge** — `sync-tenant.sh` handles the mechanical loop, skill calls the script
   - Pro: Claude handles interactive parts (parsing intent, reporting), script handles deterministic work
   - Pro: Same interface when Go replaces the script later
   - Pro: Testable with mock qlik binary
   - **Chosen**

### Decision
Add `skills/sync/scripts/sync-tenant.sh` that reads `.qlik-sync/config.json`, runs the full sync loop, handles duplicate names (append short ID), resolves spaces (Unknown for unresolved), and builds `index.json`. Sync skill calls this script instead of orchestrating CLI commands directly.

---

## Decision 12: Output Directory Structure — tenant/space/app

### Context
Original spec used `.qlik-sync/apps/<app-id>/`. Real-world testing showed this is unusable — you can't tell which app is which without cross-referencing the index. Need human-readable directory names.

### Options considered

1. **Flat by app ID** — `.qlik-sync/apps/<app-id>/`
   - **Rejected** — unreadable

2. **tenant/space/app (short-id)** — `.qlik-sync/two.eu/Finance Prod/Sales Dashboard (204be326)/`
   - Pro: Human-readable, organized by space, short ID prevents collisions
   - Pro: Always append short ID — predictable, no collision logic needed
   - **Chosen**

3. **tenant/space/app with dedup suffix** — append `(2)`, `(3)` for duplicates only
   - **Rejected** — unpredictable folder names, order-dependent

### Decision
Output structure is `.qlik-sync/<tenant-domain>/<space-name>/<app-name> (<short-resourceId>)/`. Short ID is first 8 chars of `resourceId`, always appended. Unresolved spaces use `Unknown (<short-spaceId>)`. Personal space apps go under `Personal/`.
