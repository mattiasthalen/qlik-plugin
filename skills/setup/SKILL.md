---
name: setup
description: >
  Use when the user says "set up qlik", "configure qlik", "connect to
  my qlik tenant", or wants to connect Claude to their Qlik Cloud
  environment. Also use when qlik-cli auth fails or tenant connection
  needs troubleshooting.
allowed-tools:
  - Bash(which:*)
  - Bash(qlik context:*)
  - Bash(qlik app ls:*)
  - Bash(qlik version:*)
  - Bash(mkdir:*)
  - Bash(grep:*)
  - Read
  - Write
---

# Qlik Setup

Set up a Qlik Cloud connection so Claude can sync and inspect apps locally.

## Step 1: Check Prerequisites

Verify both tools are installed:

```bash
which qlik
which qs
```

If `qlik` is missing, tell the user:
> Install qlik-cli from https://qlik.dev/toolkits/qlik-cli/ and make sure `qlik` is on your PATH.

If `qs` is missing, tell the user:
> Install qs from https://github.com/mattiasthalen/qlik-sync/releases and make sure `qs` is on your PATH.

Stop and wait for the user to install missing tools before continuing.

## Step 2: Check for Existing Context

```bash
qlik context ls
```

Note: `qlik context ls` outputs a table by default (not JSON). Look for the row marked with `*` in the `current` column to identify the active context.

If output shows an existing context, ask the user:
> You already have a qlik context configured: `<context-name>` pointing to `<server>`. Do you want to use this one, or create a new context?

If they want to reuse it, skip to Step 4.

## Step 3: Create Context and Authenticate

Ask the user for their Qlik Cloud tenant URL (e.g., `https://mytenant.us.qlikcloud.com`) and a context name (e.g., their tenant subdomain like `my-tenant`).

### API Key Auth (recommended for Qlik Cloud)

1. Ask the user to generate an API key at `https://<tenant-url>/settings/api-keys`
   - Requires the "Manage API keys" permission (Developer role or custom role)
   - The key is only shown once — copy it immediately
2. Create the context with the key:

```bash
qlik context create <context-name> --server https://<tenant-url> --api-key <API_KEY>
```

### Alternative: OAuth Login

```bash
qlik context create <context-name> --server https://<tenant-url>
qlik context login
```

### Troubleshooting Auth

- **API key gives 401:** Key may have expired. Generate a new one at `/settings/api-keys`.
- **"Manage API keys" not available:** Enable API keys in Management Console → Settings → Feature Control, or add the permission via a custom role.
- **Wrong tenant:** Run `qlik context ls` to verify the server URL, then recreate the context with the correct URL.

## Step 4: Test Connectivity

### Connectivity test

```bash
qlik app ls --limit 1 --json
```

Verify the output is valid JSON containing at least one app. Report to the user:
> Connected successfully! Found apps on your tenant.

### Troubleshooting Connectivity

- **401 Unauthorized:** Auth token may have expired. Run `qlik context login` again.
- **Network error / timeout:** Check VPN connection, proxy settings, and that the tenant URL is correct.
- **Empty result `[]`:** The connection works but you may not have access to any apps. Check your Qlik Cloud permissions.

## Step 5: Create Local Workspace

```bash
mkdir -p qlik
```

If `qlik/config.json` exists:
- Read existing config
- If v0.1.0 format (no `version` field or `version: "0.1.0"`), migrate to v0.2.0: wrap existing tenant into `tenants` array
- If v0.2.0 format, append new tenant to `tenants` array

If no existing config, create new:

```json
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "<context-name>",
      "server": "<tenant-url>",
      "type": "cloud",
      "lastSync": null
    }
  ]
}
```

Use the context name and server URL from the `qlik context ls` output.

## Step 6: Update .gitignore

Check if `qlik/` is already in `.gitignore`:

```bash
grep -q 'qlik/' .gitignore 2>/dev/null
```

If not found, append it:

```bash
echo 'qlik/' >> .gitignore
```

The `qlik/` directory may contain connection context references and should not be committed.

## Done

Report to the user:
> Qlik setup complete. Your workspace is ready at `qlik/`. Run `/qlik:sync` to pull apps from your tenant.
