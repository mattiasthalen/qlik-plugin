---
name: sync
description: >
  Use when the user says "sync qlik", "pull qlik apps", "download
  qlik environment", "extract all apps", "sync this space", or wants
  to refresh the local copy of their Qlik apps. Also use when sync
  failed partway and needs to resume, or when apps need re-syncing
  after changes on the tenant.
allowed-tools:
  - Bash(qs sync:*)
  - Bash(qs version:*)
  - Bash(which:*)
  - Read
---

# Qlik Sync

Pull apps from Qlik Cloud tenants to a local `qlik/` working copy using the `qs` CLI. Each app is extracted into its own directory organized by tenant, space, and app name.

## Prerequisites

Check that `qs` is installed:

```bash
which qs
```

If missing, tell the user:
> Install qs from https://github.com/mattiasthalen/qlik-sync/releases and make sure `qs` is on your PATH.

Check that `qlik/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

**Auto-resume after setup:** If setup was triggered as a prerequisite for sync (i.e., the user's original intent was to sync), resume the sync automatically after setup completes. Do not ask the user to re-invoke `/qlik:sync`.

## Step 1: Parse User Intent

Translate the user's request into `qs sync` flags:

| User says | Flags |
|-----------|-------|
| "sync all apps" | (no flags) |
| "sync Finance Prod" / "sync this space" | `--space "Finance Prod"` |
| "sync Sales*" / "sync apps matching Sales" | `--app "Sales"` |
| "sync 204be326-..." | `--id 204be326-...` |
| "force re-sync" / "re-download everything" | `--force` |
| "sync my-cloud tenant" | `--tenant "context-name"` |

Flags can be combined: `--space "Finance Prod" --force`

## Step 2: Run qs sync

```bash
qs sync [--space "..."] [--app "..."] [--id "..."] [--tenant "..."] [--force]
```

The `qs` CLI handles:
- API calls and filtering
- Concurrent app downloads (Go goroutines)
- 5-minute prep cache (bypass with `--force`)
- Resume detection (skips already-synced apps)
- Exponential backoff retries on failure
- Building and merging `qlik/index.json`

## Step 3: Handle Results

Check the exit code:
- **Exit code 0:** All apps synced successfully
- **Exit code 1:** Fatal error (auth failure, config missing, network error)
- **Exit code 2:** Partial sync — some apps failed

Report to the user:
> Sync complete. Run `/qlik:inspect` to explore your apps.

If exit code 2, list which apps failed from the output and suggest:
> Some apps failed to sync. Retry specific apps with `/qlik:sync --id <app-id> --force`.

### Troubleshooting

- **"config.json not found"** → suggest running `/qlik:setup`
- **401/auth errors** → suggest re-authenticating: `qlik context login`
- **"Skipping on-prem tenant"** → `qs` does not yet support on-prem sync. Cloud tenants work normally.
- **Network errors** → check VPN/proxy and tenant URL

## Output Structure

```
qlik/
├── config.json
├── index.json
└── <tenant-domain> (<tenantId>)/
    ├── shared/
    │   └── <space-name> (<spaceId>)/
    │       └── analytics/
    │           └── <app-name> (<resourceId>)/
    │               ├── script.qvs
    │               ├── measures.json
    │               ├── dimensions.json
    │               ├── variables.json
    │               ├── connections.yml
    │               ├── app-properties.json
    │               └── objects/
    ├── managed/
    └── personal/
```
