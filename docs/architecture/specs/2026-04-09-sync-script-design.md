# Sync Script Bridge — Design Spec

## Problem

The sync skill currently teaches Claude to orchestrate a loop of `qlik app unbuild` calls. Real-world testing against a 134-app tenant showed this is slow, token-wasteful, and can't handle duplicate app names or unresolved spaces. The sync workflow is purely mechanical — it belongs in a script.

## Architecture Change

**Before:** Sync skill = instructional document teaching Claude the full loop
**After:** Sync skill = thin orchestrator that parses user intent into flags and calls `sync-tenant.sh`

The script handles all mechanical work. The skill handles all interactive work.

## Script: `skills/sync/scripts/sync-tenant.sh`

### Interface

```
Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
```

Reads `.qlik-sync/config.json` for context and server. Flags filter the sync scope.

### Behavior

1. **Read config** — parse `.qlik-sync/config.json` for `context`, `server`. Extract tenant domain from server URL (`https://two.eu.qlikcloud.com` → `two.eu`).

2. **List apps** — `qlik app ls --json --limit 1000`. If `--space` provided, resolve space name to ID via `qlik space ls --json`, then filter with `--spaceId`. If `--app` provided, filter by name pattern locally with jq. If `--id` provided, skip listing.

3. **Resolve spaces** — `qlik space ls --json` once, build ID → name lookup map.

4. **Unbuild loop** — for each app:
   - Resolve space name from lookup. If not found: `Unknown (<first-8-chars-of-spaceId>)`. If empty/null: `Personal`.
   - Build folder path: `.qlik-sync/<tenant>/<space>/<app-name> (<first-8-chars-of-resourceId>)/`
   - Sanitize folder names: replace `/\:*?"<>|` with `_`, trim trailing whitespace.
   - **Resume check:** if `<folder>/config.yml` exists and `--force` not set, skip.
   - Run `qlik app unbuild --app <resourceId> --dir <folder>/`
   - On error: log warning to stderr, increment fail counter, continue.
   - Report progress to stdout: `[3/47] Syncing: Finance Prod / Sales Dashboard...`

5. **Build index** — construct `.qlik-sync/index.json`:
   ```json
   {
     "lastSync": "<ISO 8601>",
     "context": "<from config>",
     "server": "<from config>",
     "tenant": "<tenant-domain>",
     "appCount": <count>,
     "apps": {
       "<resourceId>": {
         "name": "<name>",
         "space": "<resolved space name>",
         "spaceId": "<resourceAttributes.spaceId>",
         "owner": "<resourceAttributes.ownerId>",
         "description": "<resourceAttributes.description>",
         "tags": ["<meta.tags[].name>"],
         "published": <resourceAttributes.published>,
         "lastReloadTime": "<resourceAttributes.lastReloadTime>",
         "path": "<tenant>/<space>/<app-name> (<short-id>)/"
       }
     }
   }
   ```
   If partial sync (filtered), merge with existing `index.json`.

6. **Update config** — set `lastSync` in `.qlik-sync/config.json`.

7. **Print summary** to stdout:
   ```
   Sync complete. 87 synced, 47 skipped, 0 failed.
   ```

### Exit Codes

- `0` — success (partial failures still exit 0, logged to stderr)
- `1` — fatal error (no config.json, auth failure on first call, jq missing)

### Dependencies

- `qlik` on PATH
- `jq` on PATH
- `.qlik-sync/config.json` exists (created by setup skill)

## Sync SKILL.md Changes

The skill shrinks to:

1. **Verify** `.qlik-sync/config.json` exists → suggest `/qlik:setup` if not
2. **Parse user intent** into flags:
   - "sync all" → no flags
   - "sync Finance Prod" → `--space "Finance Prod"`
   - "sync Sales*" → `--app "Sales*"`
   - "sync 204be326-..." → `--id 204be326-...`
   - "force re-sync" → `--force`
3. **Call script:** `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh [flags]`
4. **Read output** and report to user
5. **Error handling:** if script fails, help diagnose (auth expired → suggest `qlik context login`, network → check VPN)

References to `cli-commands.md` stay for context, but the skill no longer teaches the loop.

## Testing

### `tests/test-sync-script.sh`

Tests the script directly using mock qlik binary:

1. **Setup:** create temp dir, write config.json, prepend `tests/mock-qlik/` to PATH
2. **Full sync:** run script, verify directory structure:
   - `test-tenant/Finance Prod/Sales Dashboard (app-001)/config.yml` exists
   - `test-tenant/HR Dev/HR Analytics (app-002)/config.yml` exists
   - All 5 fixture apps synced
3. **Index built:** verify `index.json` has 5 apps, correct field paths
4. **Resume:** run script again without `--force`, verify apps skipped (no re-unbuild)
5. **Force:** run with `--force`, verify apps re-synced
6. **Space filter:** run with `--space "Finance Prod"`, verify only 3 apps synced
7. **Duplicate names:** (if fixtures have dupes) verify short ID prevents collision

### Existing tests

`tests/test-sync.sh` (SKILL.md content tests) updated to check for `sync-tenant.sh` reference instead of inline CLI commands.

## Files Changed

| File | Change |
|------|--------|
| `skills/sync/scripts/sync-tenant.sh` | Create — the sync script |
| `skills/sync/SKILL.md` | Rewrite — thin orchestrator calling script |
| `tests/test-sync-script.sh` | Create — script behavior tests |
| `tests/test-sync.sh` | Modify — update content checks for new SKILL.md |

## What Stays the Same

- `skills/setup/SKILL.md` — unchanged
- `skills/inspect/SKILL.md` — unchanged (reads local cache, doesn't care how it got there)
- `skills/sync/references/cli-commands.md` — unchanged
- All fixtures and mock binary — unchanged
- `plugin.json`, README, LICENSE — unchanged
