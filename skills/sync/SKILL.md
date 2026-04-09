---
name: sync
description: >
  Use when the user says "sync qlik", "pull qlik apps", "download
  qlik environment", "extract all apps", "sync this space", or wants
  to refresh the local copy of their Qlik apps. Also use when sync
  failed partway and needs to resume, or when apps need re-syncing
  after changes on the tenant.
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh:*)"
  - Bash(qlik app ls:*)
  - Read
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

## Step 3: Run Sync Script

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh [flags]
```

The script handles:
- Listing apps (with optional space/name/ID filter)
- Resolving space names from space IDs
- Unbuilding each app to `.qlik-sync/<tenant>/<space>/<app-name> (<short-id>)/`
- Skipping already-synced apps (resume on failure) unless `--force`
- Building `.qlik-sync/index.json` with all app metadata
- Updating `.qlik-sync/config.json` with `lastSync` timestamp

Progress is reported to stdout: `[3/47] Syncing: Finance Prod / Sales Dashboard...`

## Step 4: Report Results

Read the script's stdout output and report to the user. The last line contains the summary.

If the script exits with an error, help diagnose:
- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors in output** → suggest `qlik context login` to re-authenticate, then re-run sync (resume will skip already-synced apps)
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

## Done

Report to the user:
> Sync complete. Run `/qlik:inspect` to explore your apps.
