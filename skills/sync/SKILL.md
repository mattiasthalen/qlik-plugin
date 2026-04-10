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

## Step 4: Sync Loop with Progress

Loop through each app in the prep JSON. Track timing for ETA.

For each non-skipped app, call the appropriate script:
- **Cloud:** `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-app.sh "<resourceId>" "<targetPath>"`
- **On-prem:** `bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-app.sh "<resourceId>" "<targetPath>"`

progress reporting and ETA logic:
- If `skip` is true: report `[N/Total] SKIP: <spaceType>/<spaceName> / <appName>`
- On success: report `[N/Total] Synced: <spaceType>/<spaceName> / <appName>`
- On failure: report `[N/Total] ERROR: <spaceType>/<spaceName> / <appName>`
- After 3+ non-skipped apps, include ETA

After the loop, write results to `/tmp/qlik-sync-results.json`.

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
