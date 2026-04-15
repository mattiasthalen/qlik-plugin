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

## Step 1: Prepare and run qs setup

Probe for a `qs` binary in priority order — project-local first, then PATH — prepend the project directory to `PATH` so a project-local `qlik` / `qlik.exe` is also discoverable when `qs` shells out, then hand control to `qs setup`. Run the whole thing as one command so `$QS` lives long enough to reach the invocation:

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
"$QS" setup
```

`qs setup` is interactive — it prints existing contexts, prompts for name / URL / API key, detects cloud vs on-prem, creates the qlik context, runs a connectivity test, and writes `qlik/config.json`. See `qs setup --help` for up-to-date details. Do not pipe stdin; let the user answer the prompts in their terminal.

If the probe fails, stop and wait for the user to install `qs` (or drop it into the project folder) before continuing. `qs setup` checks for `qlik-cli` internally and reports its own error if it is also missing.

## Step 2: Verify

After `qs setup` exits 0, read `qlik/config.json` and report the tenant list to the user:

> Setup complete. Configured tenants: `<context-name-1>`, `<context-name-2>`, ...

If `qs setup` exits non-zero, surface its stderr verbatim and suggest common causes:

- API key expired → regenerate at `https://<tenant-url>/settings/api-keys`
- Wrong tenant URL → re-run `qs setup` with the correct URL
- Network error → check VPN, proxy, and that the tenant URL is reachable

## Step 3: Update .gitignore

Check whether `qlik/` is already ignored:

```bash
grep -q 'qlik/' .gitignore 2>/dev/null
```

If the grep exits non-zero, append it:

```bash
echo 'qlik/' >> .gitignore
```

The `qlik/` directory contains connection context references and should not be committed.

## Step 4: Auto-resume to sync

If setup was triggered as a prerequisite for sync (the user's original intent was to sync), invoke the `sync` skill automatically after this step completes. Do not ask the user to re-invoke `/qlik:sync`.

## Done

Report to the user:
> Qlik setup complete. Your workspace is ready at `qlik/`. Run `/qlik:sync` to pull apps from your tenant.
