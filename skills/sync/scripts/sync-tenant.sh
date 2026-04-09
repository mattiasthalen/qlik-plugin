#!/bin/bash
# sync-tenant.sh — Sync Qlik Cloud apps to local filesystem
# Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
set -euo pipefail

# --- Parse flags ---
SPACE_FILTER=""
APP_FILTER=""
ID_FILTER=""
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --space) SPACE_FILTER="$2"; shift 2 ;;
    --app)   APP_FILTER="$2"; shift 2 ;;
    --id)    ID_FILTER="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: sync-tenant.sh [--space \"Name\"] [--app \"Pattern\"] [--id <GUID>] [--force]" >&2
      exit 1
      ;;
  esac
done

# --- Read config ---
CONFIG_FILE=".qlik-sync/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. Run setup first." >&2
  exit 1
fi

CONTEXT="$(jq -r '.context // empty' "$CONFIG_FILE")"
SERVER="$(jq -r '.server // empty' "$CONFIG_FILE")"

if [ -z "$CONTEXT" ] || [ -z "$SERVER" ]; then
  echo "Error: config.json missing context or server." >&2
  exit 1
fi

# Extract tenant domain from server URL
TENANT="$(echo "$SERVER" | sed -E 's|https?://([^.]+)\..*|\1|')"

# --- Check dependencies ---
if ! command -v qlik >/dev/null 2>&1; then
  echo "Error: qlik CLI not found on PATH." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found on PATH." >&2
  exit 1
fi

# --- Fetch spaces and build lookup ---
SPACES_JSON="$(qlik space ls --json)"

# Build a space lookup file (id -> name) using temp file
SPACE_LOOKUP="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP"' EXIT
echo "$SPACES_JSON" | jq -r '.[] | "\(.id)\t\(.name)"' > "$SPACE_LOOKUP"

resolve_space() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo "Personal"
    return
  fi
  local name
  name="$(grep "^${space_id}	" "$SPACE_LOOKUP" | cut -f2)"
  if [ -n "$name" ]; then
    echo "$name"
  else
    echo "Unknown (${space_id:0:8})"
  fi
}

# --- Resolve space ID for space filter ---
SPACE_ID_FILTER=""
if [ -n "$SPACE_FILTER" ]; then
  SPACE_ID_FILTER="$(grep "	${SPACE_FILTER}$" "$SPACE_LOOKUP" | cut -f1)"
  if [ -z "$SPACE_ID_FILTER" ]; then
    echo "Error: space '$SPACE_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
if [ -n "$ID_FILTER" ]; then
  # Single app by ID — construct a one-element array
  APPS_JSON="$(qlik app ls --json --limit 1000 | jq "[.[] | select(.resourceId == \"$ID_FILTER\")]")"
elif [ -n "$SPACE_ID_FILTER" ]; then
  APPS_JSON="$(qlik app ls --json --limit 1000 --spaceId "$SPACE_ID_FILTER")"
else
  APPS_JSON="$(qlik app ls --json --limit 1000)"
fi

# Apply app name filter if set
if [ -n "$APP_FILTER" ]; then
  APPS_JSON="$(echo "$APPS_JSON" | jq "[.[] | select(.name | test(\"$APP_FILTER\"))]")"
fi

APP_COUNT="$(echo "$APPS_JSON" | jq 'length')"

if [ "$APP_COUNT" -eq 0 ]; then
  echo "No apps found matching filters."
  exit 0
fi

# Determine if this is a partial sync (filtered)
PARTIAL=false
if [ -n "$SPACE_FILTER" ] || [ -n "$APP_FILTER" ] || [ -n "$ID_FILTER" ]; then
  PARTIAL=true
fi

# --- Sanitize folder name ---
sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

# --- Sync loop using process substitution to avoid subshell ---
SYNCED=0
SKIPPED=0
ERRORS=0
IDX=0

# Build apps index entries in a temp file
INDEX_ENTRIES="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$INDEX_ENTRIES"' EXIT

while IFS= read -r app_line; do
  IDX=$((IDX + 1))

  resource_id="$(echo "$app_line" | jq -r '.resourceId')"
  app_name="$(echo "$app_line" | jq -r '.name')"
  space_id="$(echo "$app_line" | jq -r '.resourceAttributes.spaceId // empty')"
  owner_id="$(echo "$app_line" | jq -r '.resourceAttributes.ownerId // empty')"
  description="$(echo "$app_line" | jq -r '.resourceAttributes.description // empty')"
  published="$(echo "$app_line" | jq -r '.resourceAttributes.published // false')"
  last_reload="$(echo "$app_line" | jq -r '.resourceAttributes.lastReloadTime // empty')"
  tags="$(echo "$app_line" | jq -c '[.meta.tags[]?.name]')"

  space_name="$(resolve_space "$space_id")"
  short_id="${resource_id:0:8}"

  safe_space="$(sanitize "$space_name")"
  safe_app="$(sanitize "$app_name")"
  rel_path="$TENANT/$safe_space/$safe_app ($short_id)/"
  full_path=".qlik-sync/$rel_path"

  # Resume: skip if config.yml exists unless --force
  if [ "$FORCE" = false ] && [ -f "$full_path/config.yml" ]; then
    SKIPPED=$((SKIPPED + 1))
    echo "[$IDX/$APP_COUNT] SKIP: $space_name / $app_name"
  else
    echo "[$IDX/$APP_COUNT] Syncing: $space_name / $app_name..."
    mkdir -p "$full_path"
    if qlik app unbuild --app "$resource_id" --dir "$full_path" >/dev/null 2>&1; then
      SYNCED=$((SYNCED + 1))
    else
      ERRORS=$((ERRORS + 1))
      echo "  WARNING: Failed to unbuild $app_name ($resource_id)" >&2
    fi
  fi

  # Build index entry (one JSON object per line)
  cat >> "$INDEX_ENTRIES" <<ENTRY
$(jq -n \
  --arg id "$resource_id" \
  --arg name "$app_name" \
  --arg space "$space_name" \
  --arg spaceId "$space_id" \
  --arg owner "$owner_id" \
  --arg desc "$description" \
  --argjson tags "$tags" \
  --argjson published "$published" \
  --arg reload "$last_reload" \
  --arg path "$rel_path" \
  '{($id): {name: $name, space: $space, spaceId: $spaceId, owner: $owner, description: $desc, tags: $tags, published: $published, lastReloadTime: $reload, path: $path}}')
ENTRY

done < <(echo "$APPS_JSON" | jq -c '.[]')

# --- Build index.json ---
INDEX_FILE=".qlik-sync/index.json"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Merge all app entries into one object
APPS_OBJ="$(jq -s 'add // {}' "$INDEX_ENTRIES")"

# If partial sync, merge into existing index
if [ "$PARTIAL" = true ] && [ -f "$INDEX_FILE" ]; then
  EXISTING_APPS="$(jq '.apps // {}' "$INDEX_FILE")"
  APPS_OBJ="$(echo "$EXISTING_APPS" "$APPS_OBJ" | jq -s '.[0] * .[1]')"
fi

FINAL_COUNT="$(echo "$APPS_OBJ" | jq 'length')"

jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT" \
  --argjson appCount "$FINAL_COUNT" \
  --argjson apps "$APPS_OBJ" \
  '{lastSync: $lastSync, context: $context, server: $server, tenant: $tenant, appCount: $appCount, apps: $apps}' \
  > "$INDEX_FILE"

# --- Update config.json lastSync ---
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# --- Summary ---
echo ""
echo "Sync complete: $SYNCED synced, $SKIPPED skipped, $ERRORS errors (${FINAL_COUNT} apps in index)"

exit 0
