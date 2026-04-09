# Deep Directory Hierarchy, User Resolution, CLI Whitelist — Design Spec

## Changes

Four changes to the sync script, skills, and test infrastructure:

1. **Deep hierarchy** — 5-level directory structure with full UUIDs
2. **Space types** — categorical folders: shared, managed, data, personal
3. **App types** — categorical folders: analytics, dataflow-prep, data-preparation
4. **Personal user resolution** — resolve ownerId to username via `qlik user get`
5. **CLI whitelist** — `allowed-tools` frontmatter on all skills
6. **Tenant domain fix** — preserve region in domain extraction

## Directory Structure

```
.qlik-sync/
├── config.json
├── index.json
└── two.eu (HZJStxN8fU4wAACgYWkVDikvxiYl_rcH)/
    ├── shared/
    │   └── Finance Prod (6729d6437148a152088fc669)/
    │       ├── analytics/
    │       │   └── Sales Dashboard (204be326-6892-494d-a186-376e6d1f6c85)/
    │       │       ├── script.qvs
    │       │       └── ...
    │       └── dataflow-prep/
    │           └── ...
    ├── managed/
    │   └── QTC_E2E_Managed (685bd56cc98286ffde46bf1c)/
    │       └── analytics/
    │           └── ...
    ├── data/
    │   └── Northwind To Fabric (68b015aa596237224f522ce8)/
    │       └── ...
    ├── personal/
    │   └── mattiasthalen (67a22cde721ee28f3692ce97)/
    │       └── analytics/
    │           └── Test App (abc12345-6789-...)/
    └── unknown/
        └── 68dd34e1d316fb426d60a35e/
            └── analytics/
                └── Liveresultat (xyz-...)/
```

### Naming Rules

| Level | Format | Example |
|-------|--------|---------|
| Tenant | `<domain> (<tenantId>)` | `two.eu (HZJStxN8fU4wAACgYWkVDikvxiYl_rcH)` |
| Space type | `<type>` (lowercase) | `shared`, `managed`, `data`, `personal`, `unknown` |
| Space | `<name> (<spaceId>)` | `Finance Prod (6729d6437148a152088fc669)` |
| Personal space | `<username> (<ownerId>)` | `mattiasthalen (67a22cde721ee28f3692ce97)` |
| Unknown space | `<spaceId>` (just the UUID) | `68dd34e1d316fb426d60a35e` |
| App type | `<usage>` (lowercase, underscores→hyphens) | `analytics`, `dataflow-prep`, `data-preparation` |
| App | `<name> (<full-resourceId>)` | `Sales Dashboard (204be326-6892-494d-a186-376e6d1f6c85)` |

### Domain Extraction

Server URL `https://two.eu.qlikcloud.com` → domain `two.eu`

Extract by removing `https://` prefix and `.qlikcloud.com` suffix (including any trailing path).

### Tenant ID

From `qlik app ls` output: top-level `tenantId` field (same for all apps on a tenant).

### App Type Normalization

`resourceAttributes.usage` → lowercase, underscores replaced with hyphens:
- `ANALYTICS` → `analytics`
- `DATAFLOW_PREP` → `dataflow-prep`
- `DATA_PREPARATION` → `data-preparation`

## User Resolution

For apps with empty/null `spaceId` (personal space):

1. Collect unique `ownerId` values across all personal-space apps
2. For each unique owner: `qlik user get <ownerId> --json`
3. Extract `name` field (or `email` as fallback)
4. Cache results to avoid repeat API calls

Add `qlik user get` to mock binary for testing.

## CLI Whitelist

### Setup SKILL.md frontmatter:
```yaml
allowed-tools:
  - Bash(which:*)
  - Bash(qlik context:*)
  - Bash(qlik app ls:*)
  - Bash(qlik version:*)
  - Bash(mkdir:*)
  - Bash(grep:*)
  - Read
  - Write
```

### Sync SKILL.md frontmatter:
```yaml
allowed-tools:
  - Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-tenant.sh:*)
  - Bash(qlik app ls:*)
  - Read
```

### Inspect SKILL.md frontmatter:
```yaml
allowed-tools:
  - Read
  - Glob
  - Grep
```

Any qlik command not in these lists (e.g., `qlik app build`, `qlik app delete`, `qlik reload create`) requires user approval.

## Index Changes

The `path` field reflects the full hierarchy:

```json
{
  "apps": {
    "204be326-6892-494d-a186-376e6d1f6c85": {
      "name": "Sales Dashboard",
      "space": "Finance Prod",
      "spaceId": "6729d6437148a152088fc669",
      "spaceType": "shared",
      "appType": "analytics",
      "owner": "user-001",
      "ownerName": "mattiasthalen",
      "description": "Monthly sales KPIs",
      "tags": ["finance", "monthly"],
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "path": "two.eu (HZJStxN8f...)/shared/Finance Prod (6729d643...)/analytics/Sales Dashboard (204be326...)/"
    }
  }
}
```

New fields: `spaceType`, `appType`, `ownerName`.

## Files Changed

| File | Change |
|------|--------|
| `skills/sync/scripts/sync-tenant.sh` | Rewrite — deep hierarchy, full IDs, user resolution, app types |
| `skills/setup/SKILL.md` | Add `allowed-tools` frontmatter |
| `skills/sync/SKILL.md` | Add `allowed-tools` frontmatter, update output structure docs |
| `skills/inspect/SKILL.md` | Add `allowed-tools` frontmatter |
| `tests/mock-qlik/qlik` | Add `user get` subcommand |
| `tests/fixtures/user-get-response.json` | Create — canned user response |
| `tests/test-sync-script.sh` | Update — test new directory structure and user resolution |
| `tests/fixtures/app-ls-response.json` | May need `usage` field if not already present |
