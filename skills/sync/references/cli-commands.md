# Qlik CLI Command Reference

Reference for qlik-cli commands used by the sync skill. Load this when you need exact command syntax or flag details.

## qlik app ls

List all apps the authenticated user can access.

```bash
qlik app ls --json --limit 1000
```

The CLI handles pagination internally — `--limit 1000` will auto-paginate if the tenant has more apps than the per-request maximum.

**Filter by space:**

```bash
qlik app ls --json --limit 1000 --spaceId <space-id>
```

**Output structure per app (v3.0.0):**

The output is a JSON array. Each app object has this structure:
- `name` — app display name (top-level)
- `resourceId` — app GUID (use this as the app identifier)
- `resourceType` — always `"app"`
- `resourceAttributes.id` — same as `resourceId`
- `resourceAttributes.spaceId` — ID of the space containing the app (empty string if personal space)
- `resourceAttributes.owner` — auth0 identity string
- `resourceAttributes.ownerId` — owner user GUID
- `resourceAttributes.description` — app description text
- `resourceAttributes.published` — boolean
- `resourceAttributes.lastReloadTime` — ISO 8601 timestamp of last successful reload
- `resourceAttributes.usage` — `"ANALYTICS"` or other types
- `meta.tags` — array of tag objects, each with `id` and `name` fields
- `ownerId` — owner user GUID (top-level, same as `resourceAttributes.ownerId`)
- `links.open.href` — direct URL to open the app in Qlik Cloud

**Example jq to extract app ID and name:**
```bash
qlik app ls --json --limit 1000 | jq '.[] | {id: .resourceId, name: .name}'
```

## qlik space ls

List spaces to resolve space names to IDs.

```bash
qlik space ls --json --name "Finance Prod"
```

**Key output fields:**
- `id` — space GUID
- `name` — space display name
- `type` — `managed` or `shared`
- `ownerId` — owner user GUID
- `tenantId` — tenant GUID
- `description` — space description
- `createdAt` — ISO 8601 creation timestamp
- `createdBy` — creator user GUID

## qlik app unbuild

Extract an app's logic layer to local files via WebSocket connection to the engine.

```bash
qlik app unbuild --app <app-id> --dir <output-directory>
```

**Output files:**
- `config.yml` — binds all resources together
- `app-properties.json` — application metadata
- `script.qvs` — reload script
- `measures.json` — master measure definitions
- `dimensions.json` — master dimension definitions
- `variables.json` — variable definitions
- `connections.yml` — data connection definitions (passwords excluded)
- `objects/` — sheet and visualization objects as JSON

## Known Limitations

- **SaaS-only:** `qlik app unbuild` works only on Qlik Cloud (SaaS). It does not work on client-managed (on-prem) deployments.
- **Passwords excluded:** Connection definitions cannot export passwords. They must be handled manually.
- **Undeterministic output:** Some objects may produce slightly different JSON on repeated unbuild — this is a known qlik-cli behavior.
- **No bookmarks:** Bookmarks are not supported by unbuild/build.
- **WebSocket required:** Each unbuild opens a WebSocket to the Qlik Engine. Large apps may take longer. If the connection times out, retry once.
- **Special characters:** Variables containing special characters or super/subscripts may not round-trip correctly through unbuild/build.

## On-Prem: qlik qrs app full

List all apps with full metadata from QRS API.

```bash
qlik qrs app full --json
```

**Key output fields per app:**
- `id` — app GUID
- `name` — app name
- `stream` — stream object (null if unpublished), with `id` and `name`
- `owner` — owner object with `id`, `userId`, `name`, `userDirectory`
- `description`
- `published`
- `lastReloadTime`

## On-Prem: qlik qrs stream ls

```bash
qlik qrs stream ls --json
```

**Key output fields:**
- `id` — stream GUID
- `name` — stream display name

## On-Prem: App Export (2-step)

Step 1 — create export ticket:
```bash
qlik qrs app export create <appId> --skipdata --json
```

Returns JSON with `exportTicketId` field.

Step 2 — download QVF:
```bash
qlik qrs download app get <filename>.qvf --appId <appId> --exportticketid <ticket> --output-file <path>
```

## qlik-parser extract

Extract artifacts from a QVF file (on-prem only).

```bash
qlik-parser extract --source <path-to-qvf> --out <output-dir> --script --measures --dimensions --variables
```

**Output files:**
- `script.qvs` — reload script
- `measures.json` — master measures
- `dimensions.json` — master dimensions
- `variables.json` — variables

**Note:** qlik-parser produces a subset of what `qlik app unbuild` provides — no `config.yml`, `connections.yml`, or `objects/` directory.
