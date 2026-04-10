---
name: sync
description: >
  Use when the user says "sync qlik", "pull qlik apps", "download
  qlik environment", "extract all apps", "sync this space", or wants
  to refresh the local copy of their Qlik apps. Also use when sync
  failed partway and needs to resume, or when apps need re-syncing
  after changes on the tenant.
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep.json:*)"
  - "Bash(cat /tmp/qlik-sync-results.json:*)"
  - "Bash(echo:*)"
  - Bash(qlik app ls:*)
  - Bash(date:*)
  - Read
  - Write
---

# Qlik Sync

Pull apps from a Qlik Cloud tenant to a local `.qlik-sync/` working copy. Each app is extracted into its own directory organized by tenant, space, and app name.

For detailed CLI command syntax, load the reference: `references/cli-commands.md`

## Prerequisites

Check that `.qlik-sync/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

## Step 1: Parse User Intent

Translate the user's request into script flags:

| User says | Script flags |
|-----------|-------------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |

Flags can be combined: `--space "Finance Prod" --force`

## Step 2: Warn on Scale (Optional)

If syncing all apps without filters, check the app count first:

```bash
qlik app ls --json --limit 1 | jq length
```

If the tenant has more than 50 apps, warn the user:
> Found a large number of apps. Consider filtering by space with `--space "SpaceName"`. Continue with full sync?

Wait for confirmation before proceeding.

## Step 3: Run Prep

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh [flags] > /tmp/qlik-sync-prep.json
cat /tmp/qlik-sync-prep.json
```

Read the JSON output. Report to the user:
> Found **N** apps (**X** to sync, **Y** already synced)

## Step 4: Sync Loop with Progress

Loop through each app in the prep JSON. Track timing for ETA.

Initialize a results array. For each app:

1. If `skip` is `true`: report `[N/Total] SKIP: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "skipped"}` to results.

2. If `skip` is `false`: run sync and report progress:
   ```bash
   bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh "<resourceId>" "<targetPath>"
   ```
   - On success (exit 0): report `[N/Total] Synced: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "synced"}` to results.
   - On failure (exit 1): report `[N/Total] ERROR: <spaceType>/<spaceName> / <appName>` and append `{"resourceId": "<id>", "status": "error", "error": "unbuild failed"}` to results. Continue to next app.

3. **ETA:** After 3+ non-skipped apps, track average time per app and report estimated remaining time: `(~Xm remaining)` or `(~Xs remaining)`.

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

After sync, apps are organized as:

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
    │   └── ...
    ├── data/
    │   └── ...
    ├── personal/
    │   └── <username> (<ownerId>)/
    │       └── analytics/
    │           └── ...
    └── unknown/
        └── <spaceId>/
            └── ...
```
