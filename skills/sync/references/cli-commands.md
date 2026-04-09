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

**Key output fields per app:**
- `id` — app GUID
- `name` — app display name
- `spaceId` — ID of the space containing the app
- `owner` — owner email or user ID
- `description` — app description text
- `tags` — array of tag strings
- `published` — boolean
- `lastReloadTime` — ISO 8601 timestamp of last successful reload

## qlik space ls

List spaces to resolve space names to IDs.

```bash
qlik space ls --json --name "Finance Prod"
```

**Key output fields:**
- `id` — space GUID
- `name` — space display name
- `type` — `managed` or `shared`
- `ownerId` — owner user ID

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
