---
name: setup
description: >
  Use when the user says "set up qlik", "configure qlik", "connect to
  my qlik tenant", or wants to connect Claude to their Qlik tenant.
  Also use when a qs setup run fails or tenant connection needs
  troubleshooting.
allowed-tools:
  - Bash(command:*)
  - Bash(test:*)
  - Bash(qs setup:*)
  - Bash(./qs setup:*)
  - Bash(./qs.exe setup:*)
  - Bash(grep:*)
  - Read
  - Write
---

# Qlik Setup

Configure a Qlik tenant connection so Claude can sync and inspect apps locally. This skill is a thin wrapper around `qs setup`, which owns the interactive flow (context creation, cloud/on-prem detection, connectivity test, and `qlik/config.json` writes).

## Step 1: Locate qs

Probe for a `qs` binary in priority order — project-local first, then PATH — and prepend the project directory to `PATH` so a project-local `qlik` / `qlik.exe` is also discoverable when `qs` shells out:

```bash
if [ -x ./qs.exe ]; then
  QS=./qs.exe
elif [ -x ./qs ]; then
  QS=./qs
elif command -v qs > /dev/null 2>&1; then
  QS=qs
else
  echo "qs not found." >&2
  echo "Install from https://github.com/mattiasthalen/qlik-sync/releases or drop qs / qs.exe next to this project." >&2
  exit 1
fi
export PATH="$PWD:$PATH"
```

If the probe fails, stop and wait for the user to install `qs` (or drop it into the project folder) before continuing. `qs setup` checks for `qlik-cli` internally and reports its own error if it is also missing.

## Step 2: Run qs setup

Run `qs setup` in the foreground so the user can answer its prompts directly in their terminal:

```bash
"$QS" setup
```

`qs setup` will:

- List existing qlik contexts
- Prompt for a context name and server URL
- Detect cloud vs on-prem from the URL
- Prompt for an API key if the context does not already exist
- Create the qlik context (with `--server-type Windows --insecure` for on-prem)
- Set the context active
- Run a connectivity test (list one app for cloud, `qlik qrs app count` for on-prem)
- Write or update `qlik/config.json` in v0.2.0 format (appending to `tenants`, preserving existing entries)

Do not pipe stdin. Let the user interact with `qs setup` directly.

## Step 3: Verify

After `qs setup` exits 0, read `qlik/config.json` and report the tenant list to the user:

> Setup complete. Configured tenants: `<context-name-1>`, `<context-name-2>`, ...

If `qs setup` exits non-zero, surface its stderr verbatim and suggest common causes:

- API key expired → regenerate at `https://<tenant-url>/settings/api-keys`
- Wrong tenant URL → re-run `qs setup` with the correct URL
- Network error → check VPN, proxy, and that the tenant URL is reachable

## Step 4: Update .gitignore

Check whether `qlik/` is already ignored:

```bash
grep -q 'qlik/' .gitignore 2>/dev/null
```

If the grep exits non-zero, append it:

```bash
echo 'qlik/' >> .gitignore
```

The `qlik/` directory contains connection context references and should not be committed.

## Step 5: Auto-resume to sync

If setup was triggered as a prerequisite for sync (the user's original intent was to sync), invoke the `sync` skill automatically after this step completes. Do not ask the user to re-invoke `/qlik:sync`.

## Done

Report to the user:
> Qlik setup complete. Your workspace is ready at `qlik/`. Run `/qlik:sync` to pull apps from your tenant.
