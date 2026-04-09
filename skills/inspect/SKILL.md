---
name: inspect
description: >
  Use when the user says "find measure", "search qlik scripts", "which
  apps use QVD", "show me the load script", "compare measures", "list
  apps in space", "what connections does this app use", "show variables",
  "compare expressions", "find field", or wants to explore their synced
  Qlik environment. Works offline against .qlik-sync/ cache.
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Qlik Inspect

Search, navigate, and compare across the local `.qlik-sync/` cache. This skill works entirely offline — no API calls, no network required. All data comes from the synced files on disk.

## Prerequisites

Check that `.qlik-sync/index.json` exists. If not, tell the user:
> Run `/qlik:sync` first to pull apps from your Qlik Cloud tenant.

Load `.qlik-sync/index.json` to understand what apps are available and where they live on disk.

## Resolving App References

Users will refer to apps by name, not ID. Use the index to resolve:
1. Read `.qlik-sync/index.json`
2. Find the app entry matching the name (case-insensitive, partial match OK)
3. Use the `path` field to locate files: `.qlik-sync/<path>/`

If multiple apps match a partial name, list the matches and ask which one.

## Query Types

### Search Across All Apps

**Find a measure by name or expression:**

Use Grep to search across all `measures.json` files:
- By name: grep for the measure name across all `measures.json` files under `.qlik-sync/`
- By expression: grep for the expression pattern (e.g., `Sum(Amount)`)

When showing results, include the app name (from index), measure title, and full expression (`qMeasure.qDef`).

**Find a dimension by name or field:**

Grep across all `dimensions.json` files:
- By name: search `qMetaDef.title`
- By field: search `qDim.qFieldDefs`

**Search all load scripts:**

Grep across all `script.qvs` files for a pattern:
- QVD filenames: e.g., `Sales.qvd`
- Table names: e.g., `Sales:`
- Field names: e.g., `CustomerID`
- Connection names: e.g., `LIB CONNECT TO`
- Any text pattern the user specifies

Show matching lines with context (a few lines before/after) and the app name.

**Find data connections:**

Grep across all `connections.yml` files for connection names, types, or connection strings.

### Navigate a Specific App

**Show load script:**

Read `.qlik-sync/<path>/script.qvs` where `<path>` is from the app's `path` field in `index.json` and display with QVS syntax highlighting (use ```qvs code fence).

**List measures:**

Read `.qlik-sync/<path>/measures.json` where `<path>` is from `index.json` and present as a table:

| Name | Expression | Description |
|------|-----------|-------------|
| Total Revenue | Sum(Amount) | Sum of all sales amounts |

**List dimensions:**

Read `.qlik-sync/<path>/dimensions.json` where `<path>` is from `index.json` and present as a table:

| Name | Field(s) | Description |
|------|----------|-------------|
| Customer | CustomerID | Customer identifier |

**List variables:**

Read `.qlik-sync/<path>/variables.json` where `<path>` is from `index.json` and present as a table:

| Name | Definition | Comment |
|------|-----------|---------|
| vCurrentYear | =Year(Today()) | Current year for default selections |

**Show connections:**

Read `.qlik-sync/<path>/connections.yml` where `<path>` is from `index.json` and list name, type, and connection string.

**Show sheet objects:**

List files in `.qlik-sync/<path>/objects/` where `<path>` is from `index.json` and read individual sheets to show their structure.

### Compare Across Apps

**Diff a measure between two apps:**

1. Read `measures.json` from both apps
2. Find the measure by name in each
3. Compare the `qMeasure.qDef` expressions
4. Show side-by-side or diff format highlighting differences

**Find similar measures across apps:**

1. User provides a measure name or expression pattern
2. Grep across all `measures.json` files
3. Group results by expression — show which apps share identical definitions and which differ

**Compare load scripts:**

1. Read both `script.qvs` files
2. Show a diff highlighting additions, removals, and changes

### Filter and List

**List apps in a space:**

Filter `index.json` by space name and present as a table:

| Name | Space | Owner | Published | Last Reload |
|------|-------|-------|-----------|-------------|

**List apps by owner:**

Filter `index.json` by owner field.

**List published/unpublished:**

Filter `index.json` by `published` field.

**Show sync status:**

Read `.qlik-sync/config.json` for last sync time. Count apps in index. Report:
> Last synced: <timestamp>. **N** apps in local cache across **M** spaces.

## Presenting Results

- **Measures/dimensions:** Always show both the name AND the full expression/field definition.
- **Load scripts:** Use ```qvs code fences for syntax highlighting.
- **Comparisons:** Use diff format or side-by-side tables.
- **Large result sets:** If more than 20 matches, summarize first, then offer to show details.
- **App references:** Always include the app name alongside results so the user knows which app each result comes from.

## Error Handling

- **App not in index:** Suggest re-syncing: "This app isn't in the local cache. Run `/qlik:sync` to refresh."
- **Corrupt JSON file:** Report which app and file are affected: "Could not parse `measures.json` for app '<name>'. Try re-syncing this app: `/qlik:sync <app-id> --force`"
- **Stale cache:** If the user mentions an app or measure that should exist but doesn't, suggest re-syncing.
