# Fix CLI Output Shapes — Design Spec

## Problem

Test fixtures and skills assumed a flat `qlik app ls --json` output structure based on documentation. Real qlik-cli v3.0.0 output nests fields differently. Fixtures, mock binary, skills, and CLI reference all need updating.

## Verified Real Output Shapes

### qlik app ls --json

```json
{
  "name": "Sales Dashboard",
  "resourceId": "204be326-6892-494d-a186-376e6d1f6c85",
  "resourceType": "app",
  "resourceAttributes": {
    "id": "204be326-6892-494d-a186-376e6d1f6c85",
    "name": "Sales Dashboard",
    "spaceId": "space-guid",
    "owner": "auth0|...",
    "ownerId": "user-guid",
    "description": "Monthly sales KPIs",
    "published": false,
    "lastReloadTime": "2026-03-26T13:28:28.259Z",
    "createdDate": "2025-01-15T10:00:00Z",
    "modifiedDate": "2026-04-08T14:30:00Z",
    "usage": "ANALYTICS",
    "hasSectionAccess": false
  },
  "resourceCreatedAt": "2026-03-26T13:18:06Z",
  "resourceUpdatedAt": "2026-03-26T13:28:37Z",
  "ownerId": "user-guid",
  "creatorId": "user-guid",
  "tenantId": "tenant-guid",
  "meta": {
    "tags": [],
    "collections": [],
    "isFavorited": false,
    "actions": []
  },
  "links": {
    "self": { "href": "..." },
    "open": { "href": "..." }
  },
  "collectionIds": [],
  "id": "item-id",
  "createdAt": "...",
  "updatedAt": "..."
}
```

**Key field mappings for index building:**
- App ID: `resourceId` (or `resourceAttributes.id`)
- Name: `name` (top-level)
- Space ID: `resourceAttributes.spaceId`
- Owner: `resourceAttributes.ownerId` (GUID) — `resourceAttributes.owner` is an auth0 string, less useful
- Description: `resourceAttributes.description`
- Published: `resourceAttributes.published`
- Last reload: `resourceAttributes.lastReloadTime`
- Tags: `meta.tags` (array, may contain objects with `id` and `name` fields)

### qlik space ls --json

```json
{
  "id": "space-guid",
  "name": "AI",
  "type": "shared",
  "ownerId": "user-guid",
  "tenantId": "tenant-guid",
  "description": "",
  "meta": { "actions": [...], "roles": [], "assignableRoles": [...] },
  "links": { "self": { "href": "..." }, "assignments": { "href": "..." } },
  "createdAt": "2024-11-05T08:24:35.633Z",
  "createdBy": "user-guid",
  "updatedAt": "..."
}
```

### qlik app unbuild output

Files are correct. Minor differences:
- `connections.yml` uses `connections:` key wrapper (not a flat YAML list)
- `app-properties.json` has `qLastReloadTime`, `qSavedInProductVersion`, `qUsage`, `hassectionaccess`
- Objects include non-sheet types: `loadmodel`, `singlepublic`

### qlik context ls

Tabular by default (not JSON). Fields: `name`, `server`, `current`, `comment`.

## Files to Change

### 1. tests/fixtures/app-ls-response.json
Rewrite 5 apps in real v3.0.0 structure with `resourceId`, `resourceAttributes`, `meta`.

### 2. tests/fixtures/space-ls-response.json
Add `tenantId`, `meta`, `links`, `createdAt`, `createdBy`, `updatedAt` fields.

### 3. tests/fixtures/context-ls-response.json
Change to tabular string output (matching real `qlik context ls` default), or keep JSON but match real structure.

### 4. tests/fixtures/unbuild-output/app-properties.json
Add `qLastReloadTime`, `qSavedInProductVersion`, `qUsage`, `hassectionaccess`.

### 5. tests/fixtures/unbuild-output/connections.yml
Wrap under `connections:` key.

### 6. tests/mock-qlik/qlik
Update `app ls` spaceId filter: read from `resourceAttributes.spaceId` via jq.

### 7. skills/sync/SKILL.md
Update index-building step field paths:
- `resourceId` for app ID
- `resourceAttributes.spaceId`, `resourceAttributes.ownerId`, `resourceAttributes.description`, `resourceAttributes.published`, `resourceAttributes.lastReloadTime`
- `meta.tags`
- `name` (top-level, unchanged)

### 8. skills/sync/references/cli-commands.md
Update "Key output fields" section to show real nesting.

### 9. skills/setup/SKILL.md
Update `qlik context ls` reference — note it outputs tabular by default.

### 10. Tests
Existing grep-based tests should still pass (check content strings, not structure). Verify and fix if needed.
