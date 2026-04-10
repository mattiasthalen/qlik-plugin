# On-Prem Sync Design

**Issue:** #5 (support on-prem Qlik via app download and qlik-parser)
**Decision doc:** `docs/architecture/decisions/2026-04-10-onprem-sync-decision.md`
**Depends on:** PR #8 (sync progress — three-phase decomposition)

## Overview

Add on-prem Qlik Sense Enterprise (QSEoW) support to the sync skill. On-prem uses `qlik qrs` commands for listing/exporting and `qlik-parser` for extraction. Multi-tenant config allows mixing cloud and on-prem tenants.

## Config Schema (v0.2.0)

```json
{
  "version": "0.2.0",
  "tenants": [
    {
      "context": "my-cloud",
      "server": "https://mytenant.eu.qlikcloud.com",
      "type": "cloud",
      "lastSync": null
    },
    {
      "context": "my-qseow",
      "server": "https://qseow.corp.local/jwt",
      "type": "on-prem",
      "lastSync": null
    }
  ]
}
```

Migration from v0.1.0: wrap existing single-tenant fields into `tenants` array, auto-detect type from server URL.

## Directory Structure

### Cloud (unchanged)

```
.qlik-sync/
└── mytenant.eu (tenant-id-123)/
    ├── managed/
    │   └── Finance Prod (space-001)/
    │       └── analytics/
    │           └── Sales Dashboard (app-001)/
    │               ├── config.yml
    │               ├── script.qvs
    │               ├── measures.json
    │               ├── dimensions.json
    │               ├── variables.json
    │               ├── connections.yml
    │               └── objects/
    ├── shared/
    ├── personal/
    └── unknown/
```

### On-Prem

```
.qlik-sync/
└── qseow.corp.local (server-node-id)/
    ├── stream/
    │   └── Finance (stream-id-abc)/
    │       └── Sales Dashboard (app-guid)/
    │           ├── script.qvs
    │           ├── measures.json
    │           ├── dimensions.json
    │           └── variables.json
    └── personal/
        └── CORP\jsmith (user-id)/
            └── My App (app-guid)/
                └── ...
```

No app-type level on-prem. No config.yml, connections.yml, or objects/ (qlik-parser subset).

## Script Architecture

Builds on PR #8's three-phase decomposition. Six scripts + shared lib.

### sync-lib.sh — Shared Helpers

```bash
sanitize()           # folder name sanitization (tr '/\\:*?"<>|' '_')
build_index_entry()  # create JSON index entry for one app
merge_index()        # build/merge index.json (partial or full)
update_last_sync()   # stamp tenant's lastSync in config.json
print_summary()      # format "N synced, M skipped, E errors"
read_tenant_config() # parse config.json, return tenant by name or all
resolve_username()   # user ID → name lookup with temp file cache
```

### sync-cloud-prep.sh

Refactored from PR #8's `sync-prep.sh`. Cloud-specific listing and resolution.

**Commands used:**
- `qlik space ls --json` — fetch spaces, build lookup
- `qlik app ls --json --limit 1000 [--spaceId <id>]` — fetch apps

**Output:** JSON object with `apps` array. Each app has `resourceId`, `name`, `spaceName`, `spaceType`, `appType`, `ownerName`, `targetPath`, `skip`. Same format as PR #8.

### sync-cloud-app.sh

Refactored from PR #8's `sync-app.sh`.

```bash
bash sync-cloud-app.sh <resourceId> <targetPath>
# mkdir -p .qlik-sync/<targetPath>
# qlik app unbuild --app <resourceId> --dir .qlik-sync/<targetPath>
```

### sync-cloud-finalize.sh

Refactored from PR #8's `sync-finalize.sh`. Uses sync-lib.sh helpers.

### sync-onprem-prep.sh

On-prem listing and resolution.

**Commands used:**
- `qlik qrs stream ls --json` — fetch streams, build lookup
- `qlik qrs app full --json` — fetch all apps with full metadata

**QRS app full response fields:**
- `id` — app GUID
- `name` — app name
- `stream` — stream object (null if unpublished), with `id` and `name`
- `owner` — owner object with `id`, `userId`, `name`, `userDirectory`
- `description`
- `published`
- `lastReloadTime`

**Output:** Same JSON format as cloud prep. Differences:
- `spaceType` = `"stream"` (published) or `"personal"` (unpublished)
- `appType` = `null`
- `targetPath` uses stream hierarchy (no app-type level)
- `spaceName` = stream name (published) or owner display name (personal)

**Filters:**
- `--stream "Name"` (maps to `--space` in SKILL.md, remapped for on-prem)
- `--app "Pattern"` — name regex filter
- `--id <guid>` — single app
- `--force` — override skip

### sync-onprem-app.sh

Three-step extraction for one app.

```bash
bash sync-onprem-app.sh <appId> <targetPath>
```

Steps:
1. `qlik qrs app export create <appId> --skipdata --json` → extract download ticket
2. `qlik qrs download app get <appId>.qvf --appId <appId> --exportticketid <ticket> --output-file /tmp/<appId>.qvf`
3. `qlik-parser extract --source /tmp/<appId>.qvf --out .qlik-sync/<targetPath> --script --measures --dimensions --variables`
4. `rm /tmp/<appId>.qvf` — cleanup

Exit 0 on success, 1 on any step failure.

### sync-onprem-finalize.sh

Same logic as cloud finalize — uses sync-lib.sh helpers. Identical interface.

Could be a single `sync-finalize.sh` shared by both, since it only reads prep JSON + results JSON (type-agnostic).

## SKILL.md Changes

### Updated dispatch logic

```
Step 1: Parse config.json
Step 2: For each tenant (or --tenant filter):
  - If type == "cloud": use sync-cloud-*.sh
  - If type == "on-prem": use sync-onprem-*.sh
Step 3: Run prep → loop apps → finalize (per PR #8 flow)
```

### Updated allowed-tools

Add on-prem scripts and qlik-parser:
```yaml
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-finalize.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-onprem-finalize.sh:*)"
  - Bash(qlik app ls:*)
  - Bash(qlik qrs app:*)
  - Bash(qlik qrs stream:*)
  - Read
  - Write
```

### New flags

- `--tenant "name"` — sync only one tenant (by context name)
- `--stream "Name"` — on-prem equivalent of `--space` (SKILL.md maps user intent)

## Setup Skill Changes

### Tenant type detection

After user provides server URL:
- URL contains `.qlikcloud.com` → `type: "cloud"`
- Otherwise → `type: "on-prem"`
- Confirm with user before proceeding

### On-prem auth guidance

Guide user through JWT context creation:
```bash
qlik context create <name> --server https://server/jwt --api-key <JWT> --insecure --server-type Windows
```

### On-prem dependency check

Check `which qlik-parser`. If missing, inform user:
> On-prem sync requires qlik-parser. Download from https://github.com/mattiasthalen/qlik-parser/releases and add to PATH.

Don't block setup — only needed at sync time.

### Multi-tenant config

- No existing config → create fresh with tenants array
- Old v0.1.0 config → migrate: wrap into tenants array, detect type
- Existing v0.2.0 config → append new tenant to array

### Connectivity test

- Cloud: `qlik app ls --limit 1 --json`
- On-prem: `qlik qrs app ls --json` with context that has `--server-type Windows`

## Index Schema (updated)

```json
{
  "lastSync": "2026-04-10T12:00:00Z",
  "tenants": {
    "mytenant.eu (tenant-123)": {
      "type": "cloud",
      "context": "my-cloud",
      "server": "https://mytenant.eu.qlikcloud.com",
      "appCount": 47
    },
    "qseow.corp.local (node-456)": {
      "type": "on-prem",
      "context": "my-qseow",
      "server": "https://qseow.corp.local/jwt",
      "appCount": 12
    }
  },
  "apps": {
    "app-001": {
      "name": "Sales Dashboard",
      "space": "Finance Prod",
      "spaceId": "space-001",
      "spaceType": "managed",
      "appType": "analytics",
      "owner": "user-001",
      "ownerName": "jane.doe",
      "description": "Monthly sales KPIs",
      "tags": ["finance"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "path": "mytenant.eu (tenant-123)/managed/Finance Prod (space-001)/analytics/Sales Dashboard (app-001)/",
      "tenant": "mytenant.eu (tenant-123)"
    },
    "app-guid-789": {
      "name": "HR Report",
      "space": "HR Stream",
      "spaceId": "stream-abc",
      "spaceType": "stream",
      "appType": null,
      "owner": "user-456",
      "ownerName": "CORP\\jsmith",
      "description": "HR quarterly report",
      "tags": [],
      "published": true,
      "lastReloadTime": "2026-04-07T06:00:00Z",
      "path": "qseow.corp.local (node-456)/stream/HR Stream (stream-abc)/HR Report (app-guid-789)/",
      "tenant": "qseow.corp.local (node-456)"
    }
  }
}
```

## Inspect Compatibility

Inspect skill works unchanged. Grep/Read against `.qlik-sync/` paths. On-prem apps have fewer files but same core artifacts. If user asks for connections or objects on an on-prem app, report: "Connections/objects not available for on-prem apps (qlik-parser doesn't extract them)."

## Testing

### New mocks

**`mock-qlik-qrs/`** — extends mock `qlik` binary to handle:
- `qrs app full --json` → returns `qrs-app-full-response.json`
- `qrs stream ls --json` → returns `qrs-stream-ls-response.json`
- `qrs app export create <id> --skipdata --json` → returns export ticket JSON
- `qrs download app get` → copies fixture QVF to output path

**`mock-qlik-parser/`** — mock `qlik-parser` binary:
- `extract --source <qvf> --out <dir> --script --measures --dimensions --variables`
- Creates fixture files in output directory

### New fixtures

- `qrs-app-full-response.json` — QRS app listing with stream/owner objects
- `qrs-stream-ls-response.json` — stream listing
- `qrs-export-response.json` — export ticket response
- `fixture.qvf` — empty file (mock doesn't read it)
- `qlik-parser-output/` — script.qvs, measures.json, dimensions.json, variables.json

### Test files

| Test file | Covers |
|---|---|
| `test-sync-cloud-prep.sh` | Cloud prep: filters, space resolution, skip logic, JSON output |
| `test-sync-cloud-app.sh` | Cloud app: unbuild call, directory creation, exit codes |
| `test-sync-onprem-prep.sh` | On-prem prep: QRS listing, stream resolution, JSON output |
| `test-sync-onprem-app.sh` | On-prem app: export+download+parse chain, QVF cleanup, exit codes |
| `test-sync-finalize.sh` | Index build, merge, config update, summary |
| `test-sync-lib.sh` | Unit tests for shared helpers |
| `test-setup.sh` | Updated: multi-tenant config, migration, type detection |

### Config migration test

Old format input:
```json
{"context": "x", "server": "https://x.qlikcloud.com", "lastSync": null, "version": "0.1.0"}
```

Expected output:
```json
{"version": "0.2.0", "tenants": [{"context": "x", "server": "https://x.qlikcloud.com", "type": "cloud", "lastSync": null}]}
```
