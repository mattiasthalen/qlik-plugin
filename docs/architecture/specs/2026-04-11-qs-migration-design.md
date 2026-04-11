# qs Migration Design Spec

## Overview

Migrate the plugin's sync engine from bash scripts + Claude Code agent parallelism to `qs` (mattiasthalen/qlik-sync), a Go CLI. Plugin becomes a UX layer over `qs`: guided setup, thin sync wrapper, AI-powered inspect.

## Architecture

```
User ──► /qlik:setup ──► configures qlik-cli context (plugin-native)
     ──► /qlik:sync  ──► qs sync [flags] (thin wrapper)
     ──► /qlik:inspect ──► reads qlik/ directory (offline, plugin-native)
```

`qs` owns: sync execution, concurrency, caching, retry, index building.
Plugin owns: guided setup UX, sync invocation + reporting, offline inspect + search.

## Components

### 1. Setup Skill (`/qlik:setup`)

**Changes:**
- Add `qs` to prerequisite check (`which qs`)
- Remove `jq` prereq (was bash script dependency)
- Remove `qlik-parser` prereq (was on-prem dependency)
- Replace `.qlik-sync/` references with `qlik/`
- Update `.gitignore` entry from `.qlik-sync/` to `qlik/`
- Config written to `qlik/config.json` (same v0.2.0 format — compatible)

**Unchanged:**
- Guided flow: context creation, auth method selection, connectivity test
- Multi-tenant support
- Auto-resume into sync after setup

### 2. Sync Skill (`/qlik:sync`)

**Replace entire sync orchestration with:**

```
qs sync [--space <name>] [--app <regex>] [--id <guid>] [--tenant <context>] [--force]
```

**Skill responsibilities:**
- Parse user intent into `qs sync` flags
- Run `qs sync` via bash, capture output
- Report results to user (synced/skipped/errored counts)
- Handle exit codes: 0 = success, 1 = fatal error, 2 = partial sync
- On partial sync (exit 2): report which apps failed, suggest `--force --id <id>` retry
- On-prem tenants: `qs` prints "not yet supported" — skill surfaces this message

**Delete:**
- `skills/sync/scripts/sync-cloud-prep.sh`
- `skills/sync/scripts/sync-cloud-app.sh`
- `skills/sync/scripts/sync-onprem-prep.sh`
- `skills/sync/scripts/sync-onprem-app.sh`
- `skills/sync/scripts/sync-finalize.sh`
- `skills/sync/scripts/sync-lib.sh`
- All agent parallelism logic from SKILL.md
- `/tmp/qlik-sync-prep-*` cache references (qs manages its own cache)
- `/tmp/qlik-sync-results.json` references

### 3. Inspect Skill (`/qlik:inspect`)

**Changes:**
- Replace all `.qlik-sync/` path references with `qlik/`
- Read `qlik/index.json` for app lookup
- `path` field no longer has trailing slash (no functional impact on POSIX)
- Per-app `tenant` field absent from index entries (inspect doesn't use it)

**Unchanged:**
- All search capabilities: measures, dimensions, variables, connections, scripts
- Compare across apps
- Filter by space, owner, publish status
- Handles missing files gracefully (on-prem apps have fewer files — reads what exists)

**On-prem readiness:**
- Cloud apps: full unbuild output (script.qvs, measures.json, dimensions.json, variables.json, connections.yml, config.yml, app-properties.json, objects/)
- On-prem apps (future): parser output only (script.qvs, measures.json, dimensions.json, variables.json)
- Inspect reads whatever files exist per app directory — no code change needed when on-prem lands

### 4. Tests

**Delete:**
- Tests for deleted bash scripts (prep, app sync, finalize, lib)
- Tests for agent parallelism

**Update:**
- Setup prereq tests: check for `qs` instead of `jq`/`qlik-parser`
- Path references: `.qlik-sync/` → `qlik/`

**Add:**
- Test that sync skill invokes `qs sync` with correct flags
- Test that sync skill handles exit codes 0, 1, 2 correctly

## Data Flow

### Sync
```
User invokes /qlik:sync
  → Skill parses intent into flags
  → Skill runs: qs sync --space "Finance" --app "Sales.*"
  → qs: queries API, filters, syncs concurrently, builds index
  → qs: writes to qlik/<tenant>/<space>/<app>/
  → qs: updates qlik/index.json
  → qs: exits 0 (all ok) or 2 (partial)
  → Skill reads exit code + output, reports to user
```

### Inspect
```
User invokes /qlik:inspect
  → Skill reads qlik/index.json
  → Skill searches/filters based on user query
  → Reads individual app files as needed
  → Reports results
```

## Migration Notes

- `qs` and plugin use identical config.json v0.2.0 format — no migration needed
- `qs` and plugin use identical directory structure under tenant root — same `qlik app unbuild` output
- index.json is compatible with two minor differences (no trailing slash on path, no per-app tenant field) — neither affects inspect
- Users with existing `.qlik-sync/` directories need to re-sync to `qlik/` (one-time)
