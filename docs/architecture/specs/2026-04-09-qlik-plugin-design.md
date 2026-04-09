# qlik — Claude Code Plugin for Qlik Cloud

## Overview

A Claude Code plugin that teaches Claude how to use `qlik-cli` to extract, navigate, and search Qlik Sense app metadata across a cloud tenant. Makes load scripts, master measures, dimensions, variables, sheet objects, connections, and app metadata locally available — without touching data.

**v0.1.0 scope:** Setup + Sync + Inspect (read-only). Push and reload deferred to v0.2.0.

**Architecture:** Skills-as-instructions. No wrapper scripts. Skills are rich instructional documents that teach Claude the qlik-cli. Claude orchestrates directly.

## Plugin Structure

```
qlik-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── setup/
│   │   └── SKILL.md
│   ├── sync/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── cli-commands.md
│   └── inspect/
│       └── SKILL.md
├── tests/
│   ├── mock-qlik/
│   │   └── qlik                 # fake qlik binary (bash script)
│   ├── fixtures/
│   │   ├── app-ls-response.json
│   │   └── unbuild-output/      # sample unbuild directory
│   ├── test-setup.sh
│   ├── test-sync.sh
│   └── test-inspect.sh
├── README.md
└── LICENSE
```

## plugin.json

```json
{
  "name": "qlik",
  "description": "Extract, inspect, and search Qlik Sense cloud apps. Syncs load scripts, master measures, dimensions, variables, objects, and connections to a local working copy.",
  "version": "0.1.0",
  "author": {
    "name": ""
  },
  "repository": "https://github.com/<user>/qlik-plugin",
  "license": "MIT"
}
```

## Skill 1: setup

### SKILL.md Frontmatter

```yaml
---
name: setup
description: >
  Set up qlik-cli for use with Claude Code. Use when the user says
  "set up qlik", "configure qlik", "connect to my qlik tenant",
  "install qlik cli", or wants to connect Claude to their Qlik Cloud
  environment. Verifies prerequisites (qlik binary, jq), guides
  OAuth authentication, tests connectivity, and creates the local
  workspace.
---
```

### Behavior

The skill teaches Claude to:

1. **Check prerequisites** — verify `qlik` and `jq` are on PATH via `which qlik` and `which jq`. If missing, link to:
   - qlik-cli: https://qlik.dev/toolkits/qlik-cli/
   - jq: https://jqlang.github.io/jq/download/
   - Stop and ask user to install before continuing.

2. **Check for existing context** — run `qlik context ls` to see if user already has a configured context. If so, offer to reuse it.

3. **Guide context creation** — ask user for their tenant URL (e.g., `https://tenant.region.qlikcloud.com`), then:
   ```bash
   qlik context create --server https://<tenant>.qlikcloud.com
   qlik context login
   ```
   The `login` command opens a browser for OAuth. Claude waits for user to confirm they've authenticated.

4. **Test connectivity** — run `qlik app ls --limit 1 --json` and verify it returns valid JSON. Report success or diagnose failure (auth expired, network issue, wrong URL).

5. **Create workspace** — create `.qlik-sync/` directory in project root. Write `.qlik-sync/config.json`:
   ```json
   {
     "context": "<context-name>",
     "server": "https://<tenant>.qlikcloud.com",
     "lastSync": null,
     "version": "0.1.0"
   }
   ```

6. **Update .gitignore** — append `.qlik-sync/` to `.gitignore` if not already present (may contain sensitive connection info).

### Error Handling

- If `qlik context login` fails: suggest checking browser, clearing cookies, trying `qlik context login --help`
- If connectivity test fails with 401: suggest re-running `qlik context login`
- If connectivity test fails with network error: suggest checking VPN, proxy, tenant URL

## Skill 2: sync

### SKILL.md Frontmatter

```yaml
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
```

### Behavior

The skill teaches Claude to:

1. **Verify setup** — check `.qlik-sync/config.json` exists. If not, tell user to run `/qlik:setup` first.

2. **Parse arguments** — support these patterns:
   - No args: sync all apps
   - Space filter: `--space "Finance Prod"` or space name as argument
   - App name pattern: `--name "Sales*"` or partial name
   - Single app ID: full GUID

3. **List apps** — run `qlik app ls --json --limit 1000`. Parse the JSON output to extract app metadata. If filtering by space, use `qlik app ls --json --limit 1000 --spaceId <space-id>` (look up space ID first with `qlik space ls --json --name "<space-name>"`).

4. **Warn on scale** — if app count exceeds 50, warn the user about expected duration and suggest space filtering if they synced all.

5. **Unbuild each app** — for each app, run:
   ```bash
   qlik app unbuild --app <app-id> --dir .qlik-sync/apps/<app-id>/
   ```
   Report progress: "Syncing app 3/47: Sales Dashboard..."

   **Resume logic:** before unbuild, check if `.qlik-sync/apps/<app-id>/config.yml` already exists. If it does and user didn't pass `--force`, skip it. This enables resume-on-failure — just re-run sync.

6. **Build index** — after all apps are unbuilt, construct `.qlik-sync/index.json` by combining:
   - Metadata from `qlik app ls --json` output (name, space, owner, description, tags, published status, lastReloadTime)
   - Local path mapping

   ```json
   {
     "lastSync": "2026-04-09T14:30:00Z",
     "context": "my-cloud-tenant",
     "server": "https://tenant.region.qlikcloud.com",
     "appCount": 47,
     "apps": {
       "<app-id>": {
         "name": "Sales Dashboard",
         "space": "Finance Prod",
         "spaceId": "<space-id>",
         "owner": "user@company.com",
         "description": "Monthly sales KPIs",
         "tags": ["finance", "monthly"],
         "published": true,
         "lastReloadTime": "2026-04-08T02:00:00Z",
         "path": "apps/<app-id>/"
       }
     }
   }
   ```

7. **Update config** — write `lastSync` timestamp to `.qlik-sync/config.json`.

### Local Directory Layout (after sync)

```
.qlik-sync/
├── config.json
├── index.json
└── apps/
    ├── <app-id-1>/
    │   ├── app-properties.json
    │   ├── config.yml
    │   ├── script.qvs
    │   ├── measures.json
    │   ├── dimensions.json
    │   ├── variables.json
    │   ├── connections.yml
    │   └── objects/
    │       ├── <sheet-id>.json
    │       └── ...
    └── <app-id-2>/
        └── ...
```

### Error Handling

- Permission denied on specific app: log warning, skip, continue with remaining apps
- Auth expired mid-sync: detect 401, suggest `qlik context login`, then resume
- WebSocket timeout on large app: retry once, then skip with warning
- Disk space: no explicit check, but if unbuild fails with write error, report clearly

### references/cli-commands.md

A reference document the skill can load on-demand containing:
- Full `qlik app ls` output schema (all available fields)
- `qlik app unbuild` flags and behavior
- `qlik space ls` usage for space ID lookup
- Known limitations (SaaS-only, password export, undeterministic output for some objects)

## Skill 3: inspect

### SKILL.md Frontmatter

```yaml
---
name: inspect
description: >
  Search and navigate the local Qlik app cache. Use when the user says
  "find measure", "search qlik scripts", "which apps use QVD",
  "show me the load script", "compare measures", "list apps in space",
  "what connections does this app use", or wants to explore their synced
  Qlik environment. Works entirely offline against .qlik-sync/ — no
  API calls needed.
---
```

### Behavior

The skill teaches Claude to:

1. **Verify sync exists** — check `.qlik-sync/index.json` exists. If not, tell user to run `/qlik:sync` first.

2. **Load the index** — read `.qlik-sync/index.json` to understand what's available.

3. **Handle these query types:**

   **Search across all apps:**
   - Find a measure/dimension by name or expression: grep across all `measures.json` / `dimensions.json` files
   - Search all load scripts for a pattern (QVD filename, table name, field name): grep across all `script.qvs` files
   - Find which apps use a specific data connection: grep across all `connections.yml` files

   **Navigate specific apps:**
   - Show the load script for an app (by name or ID): look up path in index, read `script.qvs`
   - List all measures/dimensions/variables in an app: read the respective JSON files
   - Show sheet objects: list and read files in `objects/` directory

   **Compare across apps:**
   - Diff a measure definition between two apps: read both `measures.json`, find matching measure, show differences
   - Find all apps with similar measure definitions: grep for expression patterns
   - Compare load scripts between apps: read both `script.qvs` files

   **Filter and list:**
   - List all apps in a space: filter index by space name
   - List all apps by owner: filter index by owner
   - List all published/unpublished apps: filter by published status
   - Show sync status: read config.json for last sync time, count apps

4. **Present results clearly** — when showing measures or dimensions, include both the name and the full expression. When showing load scripts, use QVS syntax highlighting. When comparing, show side-by-side or diff format.

### Error Handling

- Stale cache: if user asks about an app not in the index, suggest re-syncing
- Corrupt JSON: if a file can't be parsed, report which app and file, suggest re-syncing that specific app

## Testing Strategy

### Mock-Based Tests

A fake `qlik` binary (`tests/mock-qlik/qlik`) — a bash script that returns canned JSON based on the subcommand invoked. Test files validate expected behavior.

**tests/mock-qlik/qlik:**
- `qlik version` → returns version string
- `qlik context ls` → returns context JSON
- `qlik app ls --json` → returns `fixtures/app-ls-response.json`
- `qlik app unbuild --app <id> --dir <dir>` → copies `fixtures/unbuild-output/` to `<dir>`
- `qlik space ls --json` → returns space list JSON

**tests/fixtures/app-ls-response.json:**
Canned response with 3-5 apps across 2 spaces, covering: published/unpublished, different owners, various tags.

**tests/fixtures/unbuild-output/:**
Sample unbuild directory with realistic `script.qvs`, `measures.json`, `dimensions.json`, `variables.json`, `connections.yml`, `app-properties.json`, `config.yml`, and a couple of objects.

**Test files:**
- `test-setup.sh` — verify prerequisite checks, config creation, gitignore update
- `test-sync.sh` — verify app listing, unbuild invocation, index building, resume logic, space filtering
- `test-inspect.sh` — verify search across apps, measure comparison, script grep, index filtering

### Integration Testing

qlik-cli added to devcontainer (`devcontainer.json` feature or post-create script). Developers sign in with `qlik context login` and test against a real tenant manually.

## Devcontainer Changes

Add qlik-cli installation to `.devcontainer/devcontainer.json` or its setup script:

```bash
# Install qlik-cli (Linux/amd64)
curl -sL https://github.com/qlik-oss/qlik-cli/releases/latest/download/qlik-Linux-x86_64.tar.gz | tar xz -C /usr/local/bin qlik
```

## Known Limitations (v0.1.0)

- **SaaS-only** — `qlik app unbuild` does not work on client-managed (on-prem) deployments
- **No write-back** — push and reload deferred to v0.2.0
- **No parallel unbuild** — sequential sync may be slow for 200+ apps; mitigate with space filtering
- **Connection passwords not exported** — `unbuild` cannot extract passwords from data connections
- **Undeterministic unbuild** — some objects may produce slightly different output on re-sync
- **No bookmarks** — not supported by `unbuild`
- **No data extraction** — by design, never touches actual data

## Future Roadmap

- **v0.2.0:** Push skill (write back script/measure/dimension changes), Reload skill (trigger and monitor app reload)
- **v0.3.0:** On-prem support (pending qlik-cli capabilities), parallel unbuild helper
- **Future:** Go CLI migration for complex operations, data lineage parsing from load scripts, data model extraction
