# qs Migration Decisions

## Decision 1: Sync Engine

### Context
`mattiasthalen/qlik-sync` (`qs`) shipped v0.1.0 — a Go CLI that syncs Qlik Cloud apps to local files. The plugin currently does the same work via bash scripts + Claude Code agent parallelism. Two sync engines = maintenance burden.

### Options considered

1. **Full migration to `qs`** — replace all bash sync scripts, `qs` becomes sole sync engine
   - Pro: Single engine, native Go concurrency, compiled binary, exponential retries
   - Pro: No agent token cost for parallelism
   - Pro: Clean separation — `qs` = engine, plugin = UX layer
   - Con: On-prem not yet supported in `qs` v0.1.0
   - **Chosen**

2. **Gradual migration** — `qs` for cloud, keep bash scripts for on-prem
   - Pro: On-prem continues working immediately
   - Con: Two sync engines to maintain
   - Con: Different code paths = different bugs
   - **Rejected**

3. **Abstraction layer** — interface over either backend
   - Pro: Flexibility to swap engines
   - Con: YAGNI — `qs` will cover both eventually
   - Con: Complexity for no real benefit
   - **Rejected**

### Decision
Full migration to `qs`. On-prem sync unavailable until `qs` adds support. The QVF/QVW parser already exists in `qs` internals — wiring it up is a matter of time, not architecture.

---

## Decision 2: Output Directory

### Context
`qs` writes to `qlik/` by default. Plugin currently uses `.qlik-sync/`. Inspect skill hardcodes `.qlik-sync/` paths.

### Options considered

1. **Adopt `qlik/`** — update inspect to read from `qlik/`, match `qs` default
   - Pro: Consistent with `qs` standalone usage
   - Pro: Cleaner name, not hidden directory
   - **Chosen**

2. **Configure `qs --config .qlik-sync`** — force `qs` to use old directory name
   - Pro: No inspect changes needed
   - Con: Diverges from `qs` defaults, confusing for users who also use `qs` standalone
   - **Rejected**

3. **Support both directories** — inspect checks both `qlik/` and `.qlik-sync/`
   - Pro: Backwards compatible
   - Con: Complexity, ambiguous which is authoritative
   - **Rejected**

### Decision
Adopt `qlik/` as the canonical directory. Update all inspect references from `.qlik-sync/` to `qlik/`.

---

## Decision 3: Setup Skill

### Context
`qs` has its own `qs setup` command. Plugin has a guided setup experience. Need to decide ownership of setup flow.

### Options considered

1. **Keep plugin's guided setup** — add `qs` as prereq, setup still configures `qlik-cli` context
   - Pro: Plugin's guided UX is the unique value — interactive, explains each step
   - Pro: `qs` piggybacks on `qlik-cli` contexts, no separate config needed
   - **Chosen**

2. **Delegate to `qs setup`** — plugin just calls `qs setup`
   - Pro: Less plugin code
   - Con: Loses guided experience, `qs setup` is basic CLI prompts
   - **Rejected**

### Decision
Keep plugin's guided setup. `qs` becomes a required prereq (checked alongside `qlik-cli`). Drop `jq` and `qlik-parser` prereqs (bash script dependencies).

---

## Decision 4: On-Prem Strategy

### Context
Plugin currently supports on-prem via QRS API + `qlik-parser`. `qs` has on-prem stubbed (skips with message). `qs` already has QVF/QVW parser internals ready.

### Options considered

1. **Drop on-prem sync, keep inspect ready** — on-prem unavailable until `qs` adds it, but inspect handles both file structures
   - Pro: Clean cut, no legacy code
   - Pro: Inspect already handles missing files gracefully (reads what exists)
   - Con: On-prem users temporarily lose sync capability
   - **Chosen**

2. **Keep on-prem bash scripts as fallback**
   - Pro: On-prem continues working
   - Con: Maintaining two engines is exactly what we're trying to eliminate
   - **Rejected**

### Decision
Drop on-prem sync entirely from plugin. Inspect supports both cloud (full unbuild output) and on-prem (script + measures + dimensions + variables only) file structures — ready for when `qs` adds on-prem support.
