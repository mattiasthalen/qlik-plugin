---
name: sync
description: >
  Pull Qlik Sense apps from cloud tenant to local working copy. Use
  when the user says "sync qlik", "pull qlik apps", "download qlik
  environment", "extract all apps", "sync this space", or wants to
  refresh the local copy of their Qlik apps. Supports filtering by
  space name, app name pattern, or single app ID. Handles large
  tenants (200-800 apps) with resume-on-failure.
---

# Qlik Sync

Pull apps from a Qlik Cloud tenant to a local `.qlik-sync/` working copy. Each app is extracted into its own directory with load scripts, measures, dimensions, variables, connections, and sheet objects.

For detailed CLI command syntax, load the reference: `references/cli-commands.md`

## Prerequisites

Check that `.qlik-sync/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

## Step 1: Parse Arguments

Support these argument patterns:
- **No arguments** — sync all apps on the tenant
- **Space name** — e.g., `Finance Prod` — sync only apps in that space
- **App name pattern** — e.g., `Sales*` — sync apps matching the pattern
- **App ID** — a full GUID — sync a single specific app
- **`--force`** — re-sync apps even if already present locally

Determine which mode from the user's input.

## Step 2: List Apps

### All apps (no filter):

```bash
qlik app ls --json --limit 1000
```

### Filter by space:

First resolve the space name to an ID:

```bash
qlik space ls --json --name "<space-name>"
```

Extract the space ID from the result, then:

```bash
qlik app ls --json --limit 1000 --spaceId <space-id>
```

### Filter by app name:

List all apps and filter locally:

```bash
qlik app ls --json --limit 1000
```

Then filter the JSON output where `name` matches the pattern using `jq`.

### Single app by ID:

No need to list — proceed directly to unbuild with the given ID.

## Step 3: Warn on Scale

If the app list contains more than 50 apps, warn the user:
> Found **N** apps to sync. This may take a while — each app requires a WebSocket connection to the Qlik Engine. Consider filtering by space to sync a subset. Continue with all N apps?

Wait for confirmation before proceeding.

## Step 4: Unbuild Each App

For each app in the list:

1. **Check for resume** — if `.qlik-sync/apps/<resourceId>/config.yml` exists and `--force` was NOT passed, skip this app:
   > Skipping "<app-name>" (already synced). Use --force to re-sync.

2. **Run unbuild:**

```bash
qlik app unbuild --app <resourceId> --dir .qlik-sync/apps/<resourceId>/
```

3. **Report progress:**
   > Syncing app 3/47: Sales Dashboard...

### Error Handling During Unbuild

- **Permission denied (403):** Log a warning and continue:
  > Warning: Skipped "<app-name>" — permission denied.
- **Auth expired (401):** Stop and tell the user:
  > Authentication expired mid-sync. Run `qlik context login` to re-authenticate, then run sync again — it will resume from where it stopped.
- **Timeout / WebSocket error:** Retry once. If it fails again, skip with a warning:
  > Warning: Skipped "<app-name>" — connection timed out after retry.
- **Any other error:** Log the error, skip the app, continue with the rest.

## Step 5: Build Index

After all apps are unbuilt, build `.qlik-sync/index.json` from the `qlik app ls` output collected in Step 2.

Structure:

```json
{
  "lastSync": "<current ISO 8601 timestamp>",
  "context": "<from config.json>",
  "server": "<from config.json>",
  "appCount": <number of successfully synced apps>,
  "apps": {
    "<resourceId>": {
      "name": "<name (top-level)>",
      "space": "<space name from lookup>",
      "spaceId": "<resourceAttributes.spaceId>",
      "owner": "<resourceAttributes.ownerId>",
      "description": "<resourceAttributes.description>",
      "tags": ["<meta.tags[].name>"],
      "published": <resourceAttributes.published>,
      "lastReloadTime": "<resourceAttributes.lastReloadTime>",
      "path": "apps/<resourceId>/"
    }
  }
}
```

**Field mapping from `qlik app ls --json` output:**
- App ID (index key): `resourceId`
- Name: `name` (top-level)
- Space ID: `resourceAttributes.spaceId`
- Owner: `resourceAttributes.ownerId`
- Description: `resourceAttributes.description`
- Published: `resourceAttributes.published`
- Last reload: `resourceAttributes.lastReloadTime`
- Tags: `meta.tags` (array of objects — extract `.name` from each)

To resolve space names from space IDs, run `qlik space ls --json` once and build a lookup map.

If this is a partial sync (space filter or app filter), merge with the existing `index.json` rather than overwriting — preserve entries for apps not included in this sync.

## Step 6: Update Config

Update `lastSync` in `.qlik-sync/config.json` to the current timestamp.

## Done

Report summary to the user:
> Sync complete. **N** apps synced, **M** skipped (already synced), **K** failed. Index written to `.qlik-sync/index.json`. Run `/qlik:inspect` to explore.
