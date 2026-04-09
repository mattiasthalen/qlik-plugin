# qlik — Claude Code Plugin for Qlik Cloud

Extract, inspect, and search Qlik Sense cloud apps from Claude Code. Syncs load scripts, master measures, dimensions, variables, objects, and connections to a local working copy.

## Prerequisites

- [Claude Code](https://claude.ai/code)
- [qlik-cli](https://qlik.dev/toolkits/qlik-cli/) — `qlik` binary on your PATH
- [jq](https://jqlang.github.io/jq/download/) — `jq` binary on your PATH
- A Qlik Cloud tenant with API access

## Install

```bash
claude plugin add mattiasthalen/qlik-plugin
```

## Skills

### `/qlik:setup` — Connect to Your Tenant

Verifies prerequisites, guides OAuth authentication, and creates the local workspace.

```
/qlik:setup
```

### `/qlik:sync` — Pull Apps Locally

Extracts app metadata from your tenant to `.qlik-sync/`. Supports filtering by space, app name, or app ID.

```
/qlik:sync
/qlik:sync Finance Prod
/qlik:sync --force
```

### `/qlik:inspect` — Search and Explore

Search and navigate the local cache. No API calls needed.

```
"Which apps write to Sales.qvd?"
"Show me the load script for Sales Dashboard"
"Compare the Revenue measure across all apps"
"List all apps in the Finance Prod space"
```

## What Gets Synced

Per app, `qlik app unbuild` extracts:
- `script.qvs` — reload script
- `measures.json` — master measures
- `dimensions.json` — master dimensions
- `variables.json` — variables
- `connections.yml` — data connections (passwords excluded)
- `objects/` — sheets and visualizations
- `app-properties.json` — app metadata

Data is never extracted or touched.

## Limitations

- **Cloud only** — `qlik app unbuild` is SaaS-only (no on-prem support yet)
- **Read only** — v0.1.0 is read-only; push and reload coming in v0.2.0
- **No parallel sync** — large tenants should filter by space
- **No bookmarks** — not supported by qlik-cli unbuild
- **Connection passwords** — cannot be exported by unbuild

## License

MIT
