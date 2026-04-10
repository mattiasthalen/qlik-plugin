---
name: sync
description: >
  Use when the user says "sync qlik", "pull qlik apps", "download
  qlik environment", "extract all apps", "sync this space", or wants
  to refresh the local copy of their Qlik apps. Also use when sync
  failed partway and needs to resume, or when apps need re-syncing
  after changes on the tenant.
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
  - Bash(which:*)
  - Bash(date:*)
  - Read
  - Write
  - Agent
---

# Qlik Sync

Pull apps from Qlik Cloud or on-prem Qlik Sense Enterprise tenants to a local `.qlik-sync/` working copy. Each app is extracted into its own directory organized by tenant, space/stream, and app name.

Supports:
- **Cloud:** Uses `qlik app unbuild` to extract app contents
- **On-prem:** Uses `qlik qrs` to export apps, then `qlik-parser` to extract contents

For detailed CLI command syntax, load the reference: `references/cli-commands.md`

## Prerequisites

Check that `.qlik-sync/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

## Step 1: Parse User Intent

Translate the user's request into script flags:

| User says | Script flags |
|-----------|-------------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` (cloud) or `--stream "Finance Prod"` (on-prem) |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |
| "sync my-cloud tenant" / "sync just on-prem" | `--tenant "context-name"` |

Flags can be combined: `--space "Finance Prod" --force`

## Step 2: Warn on Scale (Optional)

If syncing all apps without filters, check the app count first:

```bash
qlik app ls --json --limit 1 | jq length
```

If the tenant has more than 50 apps, warn the user:
> Found a large number of apps. Consider filtering by space with `--space "SpaceName"`. Continue with full sync?

Wait for confirmation before proceeding.

## Step 3: Read Config and Dispatch

Read `.qlik-sync/config.json` to get tenant list. If `--tenant` flag specified, filter to that tenant.

For each tenant:

### Cloud Tenant

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh [flags] > /tmp/qlik-sync-prep.json
cat /tmp/qlik-sync-prep.json
```

Report: Found **N** apps (**X** to sync, **Y** already synced)

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

Note: For on-prem, map `--space` to `--stream` when calling the prep script.

## Step 4: Parallel Sync

### 4a: Report skips

For each app in the prep JSON where `skip` is `true`:
- Report `[N/Total] SKIP: <spaceType>/<spaceName> / <appName> (<skipReason>)`
- Append `{"resourceId": "<id>", "status": "skipped"}` to the results array

### 4b: Split into batches

Filter apps where `skip` is `false`. Calculate agent count: `min(nonSkipApps, 5)`.

Distribution: first N-1 batches get `floor(nonSkipApps / agents)` apps, last batch gets the rest.

If 0 non-skip apps remain, skip to Step 5 (finalize).

### 4c: Dispatch agents

Resolve `${CLAUDE_SKILL_ROOT}` to an absolute path. Determine the app script based on tenant type:
- **Cloud:** `{resolvedSkillRoot}/scripts/sync-cloud-app.sh`
- **On-prem:** `{resolvedSkillRoot}/scripts/sync-onprem-app.sh`

Report to user:
> Dispatching **N** parallel agents...

Spawn all agents simultaneously using the Agent tool. Each agent receives this prompt (fill in the values):

> Sync batch {batchNumber} of {totalBatches} for parallel sync.
>
> Run all commands from: {workingDirectory}
>
> For each app in the list below, run:
>   bash {syncAppScript} "{resourceId}" "{targetPath}"
>
> After processing all apps, return a JSON array of results:
> [
>   {"resourceId": "app-001", "status": "synced"},
>   {"resourceId": "app-002", "status": "error", "error": "unbuild failed: ..."}
> ]
>
> Rules:
> - Process apps sequentially within your batch
> - On script failure (non-zero exit), mark status "error" with stderr as error message
> - Continue to next app on failure — do not abort batch
> - Return the complete results array when done
>
> Apps to sync:
> {JSON array of app objects for this batch}

Where `{syncAppScript}` is the resolved absolute path to `sync-cloud-app.sh` or `sync-onprem-app.sh`.

### 4d: Collect results progressively

As each agent completes, parse its returned JSON results array and report:
> Batch **N**/**M** complete: **X** synced, **Y** errors (ETA: ~Z min remaining)

If an agent fails entirely (crash/timeout), mark all apps in that batch as errors:
`{"resourceId": "<id>", "status": "error", "error": "agent failed"}`
Report: `Batch N/M FAILED: agent error`

### 4e: Concatenate results

After all agents complete, concatenate all agent result arrays with the skip results into a single results array. Write to `/tmp/qlik-sync-results.json`.

## Step 5: Finalize

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh /tmp/qlik-sync-prep.json /tmp/qlik-sync-results.json
```

## Step 6: Report Results

Read the finalize stdout for the summary line. Report to the user:
> Sync complete. **X** synced, **Y** skipped, **Z** errors (**N** apps in index).
> Run `/qlik:inspect` to explore your apps.

If there were errors, list the failed apps and suggest re-running with `--force` for those specific apps.

If the script exits with an error, help diagnose:
- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors** → suggest `qlik context login` to re-authenticate
- **Network errors** → suggest checking VPN/proxy and tenant URL

## Output Structure

### Cloud
```
.qlik-sync/
├── config.json
├── index.json
└── <tenant-domain> (<tenantId>)/
    ├── shared/
    │   └── <space-name> (<spaceId>)/
    │       └── analytics/
    │           └── <app-name> (<full-resourceId>)/
    │               ├── script.qvs
    │               └── ...
    ├── managed/
    ├── personal/
    └── unknown/
```

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
