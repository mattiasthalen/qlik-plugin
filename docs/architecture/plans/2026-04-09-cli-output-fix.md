# CLI Output Shape Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all fixtures, mock binary, skills, and CLI reference to match real qlik-cli v3.0.0 output structure.

**Architecture:** Fixture-first — update test data to real shapes, fix mock binary to filter correctly, then update skills to reference correct field paths. Tests are grep-based and mostly structure-agnostic, so few test changes needed.

**Tech Stack:** Bash, JSON, YAML, Markdown

**Working directory:** `/workspaces/qlik-plugin/.worktrees/qlik-plugin-v010/`

---

## File Map

| File | Change | Responsibility |
|------|--------|---------------|
| `tests/fixtures/app-ls-response.json` | Rewrite | Match real v3.0.0 nested structure |
| `tests/fixtures/space-ls-response.json` | Rewrite | Add real fields (tenantId, meta, links, etc.) |
| `tests/fixtures/context-ls-response.json` | Rewrite | Match real tabular output format |
| `tests/fixtures/unbuild-output/app-properties.json` | Rewrite | Add qLastReloadTime, qSavedInProductVersion, qUsage |
| `tests/fixtures/unbuild-output/connections.yml` | Rewrite | Wrap under `connections:` key |
| `tests/mock-qlik/qlik` | Modify | Update spaceId filter jq path, version string |
| `skills/sync/SKILL.md` | Modify | Update index field paths to resourceAttributes.* |
| `skills/sync/references/cli-commands.md` | Modify | Update key output fields to show real nesting |
| `skills/setup/SKILL.md` | Modify | Note context ls is tabular by default, update context create syntax |
| `tests/test-sync.sh` | Modify | Add test for resourceId in cli-commands.md |

---

## Task 1: Update Fixtures

**Files:**
- Modify: `tests/fixtures/app-ls-response.json`
- Modify: `tests/fixtures/space-ls-response.json`
- Modify: `tests/fixtures/context-ls-response.json`
- Modify: `tests/fixtures/unbuild-output/app-properties.json`
- Modify: `tests/fixtures/unbuild-output/connections.yml`

- [ ] **Step 1: Rewrite `tests/fixtures/app-ls-response.json`**

```json
[
  {
    "name": "Sales Dashboard",
    "resourceId": "app-001",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-001",
      "name": "Sales Dashboard",
      "spaceId": "space-001",
      "owner": "auth0|user001hash",
      "ownerId": "user-001",
      "description": "Monthly sales KPIs",
      "published": true,
      "lastReloadTime": "2026-04-08T02:00:00Z",
      "createdDate": "2025-01-15T10:00:00Z",
      "modifiedDate": "2026-04-08T14:30:00Z",
      "usage": "ANALYTICS",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-01-15T10:00:00Z",
    "resourceUpdatedAt": "2026-04-08T14:30:00Z",
    "ownerId": "user-001",
    "creatorId": "user-001",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [
        { "id": "tag-fin", "name": "finance" },
        { "id": "tag-mon", "name": "monthly" }
      ],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-001" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-001" }
    },
    "collectionIds": [],
    "id": "item-001",
    "createdAt": "2025-01-15T10:00:00Z",
    "updatedAt": "2026-04-08T14:30:00Z"
  },
  {
    "name": "HR Analytics",
    "resourceId": "app-002",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-002",
      "name": "HR Analytics",
      "spaceId": "space-002",
      "owner": "auth0|hradminhash",
      "ownerId": "user-002",
      "description": "Employee metrics",
      "published": true,
      "lastReloadTime": "2026-04-07T12:00:00Z",
      "createdDate": "2025-03-01T09:00:00Z",
      "modifiedDate": "2026-04-07T12:30:00Z",
      "usage": "ANALYTICS",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-03-01T09:00:00Z",
    "resourceUpdatedAt": "2026-04-07T12:30:00Z",
    "ownerId": "user-002",
    "creatorId": "user-002",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [
        { "id": "tag-hr", "name": "hr" }
      ],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-002" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-002" }
    },
    "collectionIds": [],
    "id": "item-002",
    "createdAt": "2025-03-01T09:00:00Z",
    "updatedAt": "2026-04-07T12:30:00Z"
  },
  {
    "name": "Sales Dashboard DEV",
    "resourceId": "app-003",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-003",
      "name": "Sales Dashboard DEV",
      "spaceId": "space-001",
      "owner": "auth0|user001hash",
      "ownerId": "user-001",
      "description": "Dev copy of Sales Dashboard",
      "published": false,
      "lastReloadTime": "2026-04-09T09:00:00Z",
      "createdDate": "2025-06-01T08:00:00Z",
      "modifiedDate": "2026-04-09T09:30:00Z",
      "usage": "ANALYTICS",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-06-01T08:00:00Z",
    "resourceUpdatedAt": "2026-04-09T09:30:00Z",
    "ownerId": "user-001",
    "creatorId": "user-001",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [
        { "id": "tag-fin", "name": "finance" },
        { "id": "tag-dev", "name": "dev" }
      ],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-003" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-003" }
    },
    "collectionIds": [],
    "id": "item-003",
    "createdAt": "2025-06-01T08:00:00Z",
    "updatedAt": "2026-04-09T09:30:00Z"
  },
  {
    "name": "Finance Extract",
    "resourceId": "app-004",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-004",
      "name": "Finance Extract",
      "spaceId": "space-001",
      "owner": "auth0|etlhash",
      "ownerId": "user-003",
      "description": "QVD extract for finance data",
      "published": false,
      "lastReloadTime": "2026-04-09T01:00:00Z",
      "createdDate": "2025-02-01T07:00:00Z",
      "modifiedDate": "2026-04-09T01:30:00Z",
      "usage": "ANALYTICS",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-02-01T07:00:00Z",
    "resourceUpdatedAt": "2026-04-09T01:30:00Z",
    "ownerId": "user-003",
    "creatorId": "user-003",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [
        { "id": "tag-fin", "name": "finance" },
        { "id": "tag-ext", "name": "extract" }
      ],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-004" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-004" }
    },
    "collectionIds": [],
    "id": "item-004",
    "createdAt": "2025-02-01T07:00:00Z",
    "updatedAt": "2026-04-09T01:30:00Z"
  },
  {
    "name": "HR Transform",
    "resourceId": "app-005",
    "resourceType": "app",
    "resourceAttributes": {
      "id": "app-005",
      "name": "HR Transform",
      "spaceId": "space-002",
      "owner": "auth0|hradminhash",
      "ownerId": "user-002",
      "description": "Transform layer for HR",
      "published": false,
      "lastReloadTime": "2026-04-08T06:00:00Z",
      "createdDate": "2025-04-01T11:00:00Z",
      "modifiedDate": "2026-04-08T06:30:00Z",
      "usage": "ANALYTICS",
      "hasSectionAccess": false
    },
    "resourceCreatedAt": "2025-04-01T11:00:00Z",
    "resourceUpdatedAt": "2026-04-08T06:30:00Z",
    "ownerId": "user-002",
    "creatorId": "user-002",
    "tenantId": "test-tenant-id",
    "meta": {
      "tags": [
        { "id": "tag-hr", "name": "hr" },
        { "id": "tag-xfm", "name": "transform" }
      ],
      "collections": [],
      "isFavorited": false,
      "actions": []
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/items/item-005" },
      "open": { "href": "https://test-tenant.us.qlikcloud.com/sense/app/app-005" }
    },
    "collectionIds": [],
    "id": "item-005",
    "createdAt": "2025-04-01T11:00:00Z",
    "updatedAt": "2026-04-08T06:30:00Z"
  }
]
```

- [ ] **Step 2: Rewrite `tests/fixtures/space-ls-response.json`**

```json
[
  {
    "id": "space-001",
    "name": "Finance Prod",
    "type": "managed",
    "ownerId": "user-001",
    "tenantId": "test-tenant-id",
    "description": "",
    "meta": {
      "actions": ["create", "read", "update", "delete"],
      "roles": [],
      "assignableRoles": ["consumer", "producer", "facilitator"]
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/spaces/space-001" },
      "assignments": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/spaces/space-001/assignments" }
    },
    "createdAt": "2024-06-01T10:00:00Z",
    "createdBy": "user-001",
    "updatedAt": "2024-06-01T10:00:00Z"
  },
  {
    "id": "space-002",
    "name": "HR Dev",
    "type": "shared",
    "ownerId": "user-002",
    "tenantId": "test-tenant-id",
    "description": "",
    "meta": {
      "actions": ["create", "read", "update", "delete"],
      "roles": [],
      "assignableRoles": ["consumer", "producer"]
    },
    "links": {
      "self": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/spaces/space-002" },
      "assignments": { "href": "https://test-tenant.us.qlikcloud.com/api/v1/spaces/space-002/assignments" }
    },
    "createdAt": "2024-08-15T14:00:00Z",
    "createdBy": "user-002",
    "updatedAt": "2024-08-15T14:00:00Z"
  }
]
```

- [ ] **Step 3: Rewrite `tests/fixtures/context-ls-response.json`**

Real `qlik context ls` outputs tabular text, not JSON. Rename to `context-ls-response.txt` and update mock to match:

```
name           server                                   current     comment
test-tenant    https://test-tenant.us.qlikcloud.com     *
```

- [ ] **Step 4: Rewrite `tests/fixtures/unbuild-output/app-properties.json`**

```json
{
  "qTitle": "Sales Dashboard",
  "qDescription": "Monthly sales KPIs",
  "qLastReloadTime": "2026-04-08T02:00:00.000Z",
  "qSavedInProductVersion": "12.2756.0",
  "qThumbnail": {},
  "description": "",
  "qUsage": "ANALYTICS",
  "published": true,
  "hassectionaccess": false,
  "createdDate": "2025-01-15T10:00:00Z",
  "modifiedDate": "2026-04-08T14:30:00Z"
}
```

- [ ] **Step 5: Rewrite `tests/fixtures/unbuild-output/connections.yml`**

```yaml
connections:
  - name: Finance_DB
    type: folder
    connectionString: "/data/finance/"
    space: ""
  - name: HR_Source
    type: ODBC
    connectionString: "CUSTOM CONNECT TO \"provider=ODBC;dsn=HR_Prod\""
    space: ""
```

- [ ] **Step 6: Verify mock still works with updated fixtures**

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json | jq length`
Expected: `5`

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json | jq '.[0].resourceId' -r`
Expected: `app-001`

- [ ] **Step 7: Commit**

```bash
git add tests/fixtures/
git commit -m "fix(qlik): update fixtures to match real qlik-cli v3.0.0 output"
git push
```

---

## Task 2: Update Mock Binary

**Files:**
- Modify: `tests/mock-qlik/qlik`

- [ ] **Step 1: Run existing tests to see current state**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-inspect.sh && bash tests/test-project.sh`
Expected: All pass (grep-based tests don't check JSON structure)

- [ ] **Step 2: Update `tests/mock-qlik/qlik`**

Replace the full file with:

```bash
#!/bin/bash
# Mock qlik binary for testing
# Returns canned responses matching qlik-cli v3.0.0 output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/../fixtures"

case "$1" in
  version)
    echo "qlik version 3.0.0"
    ;;
  context)
    case "$2" in
      ls)
        cat "$FIXTURES_DIR/context-ls-response.txt"
        ;;
      create)
        echo ""
        ;;
      use)
        echo "Context: $3"
        ;;
      rm)
        echo "Context: <NONE>"
        ;;
      login)
        echo "Login successful"
        ;;
      *)
        echo "Unknown context subcommand: $2" >&2
        exit 1
        ;;
    esac
    ;;
  app)
    case "$2" in
      ls)
        # Check for --spaceId filter
        SPACE_FILTER=""
        for arg in "$@"; do
          case "$arg" in
            --spaceId) SPACE_FILTER="next" ;;
            *)
              if [ "$SPACE_FILTER" = "next" ]; then
                SPACE_FILTER="$arg"
              fi
              ;;
          esac
        done
        if [ -n "$SPACE_FILTER" ] && [ "$SPACE_FILTER" != "next" ]; then
          jq "[.[] | select(.resourceAttributes.spaceId == \"$SPACE_FILTER\")]" "$FIXTURES_DIR/app-ls-response.json"
        else
          cat "$FIXTURES_DIR/app-ls-response.json"
        fi
        ;;
      unbuild)
        # Parse --app and --dir flags
        APP_ID=""
        DIR=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --app) APP_ID="$2"; shift 2 ;;
            --dir) DIR="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        if [ -z "$APP_ID" ] || [ -z "$DIR" ]; then
          echo "Error: --app and --dir required" >&2
          exit 1
        fi
        mkdir -p "$DIR"
        cp -r "$FIXTURES_DIR/unbuild-output/"* "$DIR/"
        # Stamp the app ID into config.yml for verification
        echo "appId: $APP_ID" > "$DIR/config.yml"
        echo "\"unbuild\" command is experimental and it may change between releases"
        ;;
      *)
        echo "Unknown app subcommand: $2" >&2
        exit 1
        ;;
    esac
    ;;
  space)
    case "$2" in
      ls)
        # Check for --name filter
        NAME_FILTER=""
        for arg in "$@"; do
          case "$arg" in
            --name) NAME_FILTER="next" ;;
            *)
              if [ "$NAME_FILTER" = "next" ]; then
                NAME_FILTER="$arg"
              fi
              ;;
          esac
        done
        if [ -n "$NAME_FILTER" ] && [ "$NAME_FILTER" != "next" ]; then
          jq "[.[] | select(.name == \"$NAME_FILTER\")]" "$FIXTURES_DIR/space-ls-response.json"
        else
          cat "$FIXTURES_DIR/space-ls-response.json"
        fi
        ;;
      *)
        echo "Unknown space subcommand: $2" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unknown command: $1" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 3: Verify mock works**

Run: `PATH="tests/mock-qlik:$PATH" qlik version`
Expected: `qlik version 3.0.0`

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json --spaceId space-001 | jq length`
Expected: `3`

Run: `PATH="tests/mock-qlik:$PATH" qlik space ls --json --name "Finance Prod" | jq '.[0].id' -r`
Expected: `space-001`

Run: `PATH="tests/mock-qlik:$PATH" qlik context ls`
Expected: tabular output with `test-tenant`

- [ ] **Step 4: Run all existing tests**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-inspect.sh && bash tests/test-project.sh`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add tests/mock-qlik/qlik
git commit -m "fix(qlik): update mock binary for v3.0.0 output structure"
git push
```

---

## Task 3: Update CLI Reference

**Files:**
- Modify: `skills/sync/references/cli-commands.md`
- Modify: `tests/test-sync.sh` (add resourceId check)

- [ ] **Step 1: Add test for resourceId in cli-commands.md**

In `tests/test-sync.sh`, find the line:

```bash
assert_contains "documents pagination" "$CONTENT" "limit"
```

Add after it:

```bash
assert_contains "documents resourceId" "$CONTENT" "resourceId"
assert_contains "documents resourceAttributes" "$CONTENT" "resourceAttributes"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync.sh`
Expected: FAIL on "documents resourceId"

- [ ] **Step 3: Update `skills/sync/references/cli-commands.md`**

Replace the "Key output fields per app" section (lines 21-29) with:

```markdown
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
```

Also update the space ls section (lines 39-43) to:

```markdown
**Key output fields:**
- `id` — space GUID
- `name` — space display name
- `type` — `managed` or `shared`
- `ownerId` — owner user GUID
- `tenantId` — tenant GUID
- `description` — space description
- `createdAt` — ISO 8601 creation timestamp
- `createdBy` — creator user GUID
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-sync.sh`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add skills/sync/references/cli-commands.md tests/test-sync.sh
git commit -m "fix(qlik): update CLI reference for v3.0.0 field paths"
git push
```

---

## Task 4: Update Sync Skill Field Paths

**Files:**
- Modify: `skills/sync/SKILL.md`

- [ ] **Step 1: Run existing sync tests**

Run: `bash tests/test-sync.sh`
Expected: All pass (grep tests check for string presence, not field paths)

- [ ] **Step 2: Update index structure in `skills/sync/SKILL.md`**

Replace lines 109-128 (the JSON block in Step 5: Build Index) with:

```json
{
  "lastSync": "<current ISO 8601 timestamp>",
  "context": "<from config.json>",
  "server": "<from config.json>",
  "appCount": <number of successfully synced apps>,
  "apps": {
    "<resourceId>": {
      "name": "<name (top-level)>",
      "space": "<space name from lookup>",
      "spaceId": "<resourceAttributes.spaceId>",
      "owner": "<resourceAttributes.ownerId>",
      "description": "<resourceAttributes.description>",
      "tags": ["<meta.tags[].name>"],
      "published": <resourceAttributes.published>,
      "lastReloadTime": "<resourceAttributes.lastReloadTime>",
      "path": "apps/<resourceId>/"
    }
  }
}
```

Also add a note after the JSON block:

```markdown
**Field mapping from `qlik app ls --json` output:**
- App ID (index key): `resourceId`
- Name: `name` (top-level)
- Space ID: `resourceAttributes.spaceId`
- Owner: `resourceAttributes.ownerId`
- Description: `resourceAttributes.description`
- Published: `resourceAttributes.published`
- Last reload: `resourceAttributes.lastReloadTime`
- Tags: `meta.tags` (array of objects — extract `.name` from each)
```

- [ ] **Step 3: Update the unbuild command in Step 4**

Replace the unbuild command reference to use `resourceId`:

Find:
```
qlik app unbuild --app <app-id> --dir .qlik-sync/apps/<app-id>/
```

Replace with:
```
qlik app unbuild --app <resourceId> --dir .qlik-sync/apps/<resourceId>/
```

And update resume logic reference:

Find:
```
if `.qlik-sync/apps/<app-id>/config.yml` exists
```

Replace with:
```
if `.qlik-sync/apps/<resourceId>/config.yml` exists
```

- [ ] **Step 4: Run tests to verify nothing broke**

Run: `bash tests/test-sync.sh`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add skills/sync/SKILL.md
git commit -m "fix(qlik): update sync skill field paths for v3.0.0"
git push
```

---

## Task 5: Update Setup Skill

**Files:**
- Modify: `skills/setup/SKILL.md`

- [ ] **Step 1: Update context create syntax**

In `skills/setup/SKILL.md`, find:

```bash
qlik context create --server https://<tenant-url>
```

Replace with:

```bash
qlik context create <context-name> --server https://<tenant-url>
```

And add a note:
```
Ask the user to pick a context name (e.g., their tenant name like `my-tenant`) or use the tenant subdomain.
```

- [ ] **Step 2: Update context ls note**

In Step 2 (Check for Existing Context), after the `qlik context ls` command, add:

```
Note: `qlik context ls` outputs a table by default (not JSON). Look for the row marked with `*` in the `current` column to identify the active context.
```

- [ ] **Step 3: Add API key auth option**

After the OAuth section in Step 3, add:

```markdown
### Alternative: API Key Auth

If OAuth browser login is not available (e.g., headless environment), use an API key instead:

1. Ask the user to generate an API key at `https://<tenant-url>/settings/api-keys`
   - Requires the "Manage API keys" permission (Developer role or custom role)
2. Create the context with the key:

```bash
qlik context create <context-name> --server https://<tenant-url> --api-key <API_KEY>
```

3. Skip to Step 4 (Test Connectivity).
```

- [ ] **Step 4: Run tests**

Run: `bash tests/test-setup.sh`
Expected: All pass (existing tests check for `qlik context create` and `qlik context login` — both still present)

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md
git commit -m "fix(qlik): update setup skill for v3.0.0 context commands and API key auth"
git push
```

---

## Task 6: Run Full Test Suite and Verify

- [ ] **Step 1: Run all tests**

Run: `bash tests/test-setup.sh && bash tests/test-sync.sh && bash tests/test-inspect.sh && bash tests/test-project.sh`
Expected: All pass

- [ ] **Step 2: Verify mock with space filter uses new structure**

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json --spaceId space-001 | jq '.[0].name' -r`
Expected: `Sales Dashboard`

Run: `PATH="tests/mock-qlik:$PATH" qlik app ls --json --spaceId space-002 | jq length`
Expected: `2`

- [ ] **Step 3: Verify git log**

Run: `git log --oneline -8`
Expected: Clean conventional commits for the fix.
