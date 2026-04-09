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

# Extract tenant domain — keep region (e.g., two.eu from https://two.eu.qlikcloud.com)
TENANT_DOMAIN="$(echo "$SERVER" | sed -E 's|https?://(.+)\.qlikcloud\.com.*|\1|')"

# --- Check dependencies ---
for cmd in qlik jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found on PATH." >&2
    exit 1
  fi
done

# --- Fetch spaces and build lookup ---
SPACES_JSON="$(qlik space ls --json)"

SPACE_LOOKUP="$(mktemp)"
USER_CACHE="$(mktemp)"
INDEX_ENTRIES="$(mktemp)"
APPS_FILE="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$INDEX_ENTRIES" "$APPS_FILE"' EXIT

# Build space lookup: id -> name\ttype
echo "$SPACES_JSON" | jq -r '.[] | "\(.id)\t\(.name)\t\(.type)"' > "$SPACE_LOOKUP"

resolve_space_name() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo ""
    return
  fi
  grep "^${space_id}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f2 || true
}

resolve_space_type() {
  local space_id="$1"
  if [ -z "$space_id" ] || [ "$space_id" = "null" ]; then
    echo "personal"
    return
  fi
  local stype
  stype="$(grep "^${space_id}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f3 || true)"
  if [ -n "$stype" ]; then
    echo "$stype"
  else
    echo "unknown"
  fi
}

resolve_username() {
  local user_id="$1"
  local cached
  cached="$(grep "^${user_id}	" "$USER_CACHE" 2>/dev/null | cut -f2 || true)"
  if [ -n "$cached" ]; then
    echo "$cached"
    return
  fi
  local uname
  uname="$(qlik user get "$user_id" --json < /dev/null 2>/dev/null | jq -r '.name // .email // empty')"
  if [ -z "$uname" ]; then
    uname="$user_id"
  fi
  printf '%s\t%s\n' "$user_id" "$uname" >> "$USER_CACHE"
  echo "$uname"
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# --- Resolve space ID for space filter ---
SPACE_ID_FILTER=""
if [ -n "$SPACE_FILTER" ]; then
  SPACE_ID_FILTER="$(grep "	${SPACE_FILTER}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f1 || true)"
  if [ -z "$SPACE_ID_FILTER" ]; then
    echo "Error: space '$SPACE_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps (write to temp file to avoid bash variable size/escaping issues) ---
if [ -n "$ID_FILTER" ]; then
  qlik app ls --json --limit 1000 | jq "[.[] | select(.resourceId == \"$ID_FILTER\")]" > "$APPS_FILE"
elif [ -n "$SPACE_ID_FILTER" ]; then
  qlik app ls --json --limit 1000 --spaceId "$SPACE_ID_FILTER" > "$APPS_FILE"
else
  qlik app ls --json --limit 1000 > "$APPS_FILE"
fi

if [ -n "$APP_FILTER" ]; then
  jq "[.[] | select(.name | test(\"$APP_FILTER\"))]" "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

APP_COUNT="$(jq 'length' "$APPS_FILE")"

if [ "$APP_COUNT" -eq 0 ]; then
  echo "No apps found matching filters."
  exit 0
fi

# Get tenant ID from first app
TENANT_ID="$(jq -r '.[0].tenantId // empty' "$APPS_FILE")"
TENANT_DIR="$TENANT_DOMAIN ($TENANT_ID)"

PARTIAL=false
if [ -n "$SPACE_FILTER" ] || [ -n "$APP_FILTER" ] || [ -n "$ID_FILTER" ]; then
  PARTIAL=true
fi

# --- Sanitize folder name ---
sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

# --- Sync loop ---
SYNCED=0
SKIPPED=0
ERRORS=0
IDX=0

while IFS= read -r app_line; do
  IDX=$((IDX + 1))

  resource_id="$(jq -r '.resourceId' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  space_id="$(jq -r '.resourceAttributes.spaceId // empty' <<< "$app_line")"
  owner_id="$(jq -r '.resourceAttributes.ownerId // empty' <<< "$app_line")"
  description="$(jq -r '.resourceAttributes.description // empty' <<< "$app_line")"
  published="$(jq -r '.resourceAttributes.published // false' <<< "$app_line")"
  last_reload="$(jq -r '.resourceAttributes.lastReloadTime // empty' <<< "$app_line")"
  usage="$(jq -r '.resourceAttributes.usage // "ANALYTICS"' <<< "$app_line")"
  tags="$(jq -c '[.meta.tags[]?.name]' <<< "$app_line")"

  space_type="$(resolve_space_type "$space_id")"
  space_name="$(resolve_space_name "$space_id")"
  app_type="$(normalize_app_type "$usage")"

  # Build space folder name based on type
  if [ "$space_type" = "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
    space_folder="$(sanitize "$owner_name") ($owner_id)"
  elif [ "$space_type" = "unknown" ]; then
    space_folder="$space_id"
    space_name="$space_id"
  else
    space_folder="$(sanitize "$space_name") ($space_id)"
  fi

  safe_app="$(sanitize "$app_name")"
  app_folder="$safe_app ($resource_id)"

  # Full 5-level path: tenant/space-type/space/app-type/app/
  rel_path="$TENANT_DIR/$space_type/$space_folder/$app_type/$app_folder/"
  full_path=".qlik-sync/$rel_path"

  # Display for progress
  if [ "$space_type" = "personal" ]; then
    display_space="personal/$owner_name"
  elif [ "$space_type" = "unknown" ]; then
    display_space="unknown/$space_id"
  else
    display_space="$space_type/$space_name"
  fi

  # Resume check
  if [ "$FORCE" = false ] && [ -f "$full_path/config.yml" ]; then
    SKIPPED=$((SKIPPED + 1))
    echo "[$IDX/$APP_COUNT] SKIP: $display_space / $app_name"
  else
    echo "[$IDX/$APP_COUNT] Syncing: $display_space / $app_name..."
    mkdir -p "$full_path"
    if qlik app unbuild --app "$resource_id" --dir "$full_path" < /dev/null >/dev/null 2>&1; then
      SYNCED=$((SYNCED + 1))
    else
      ERRORS=$((ERRORS + 1))
      echo "  WARNING: Failed to unbuild $app_name ($resource_id)" >&2
    fi
  fi

  # Resolve owner name for index (may already be cached for personal)
  if [ "$space_type" != "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
  fi

  # Build index entry
  cat >> "$INDEX_ENTRIES" <<ENTRY
$(jq -n \
  --arg id "$resource_id" \
  --arg name "$app_name" \
  --arg space "$space_name" \
  --arg spaceId "$space_id" \
  --arg spaceType "$space_type" \
  --arg appType "$app_type" \
  --arg owner "$owner_id" \
  --arg ownerName "$owner_name" \
  --arg desc "$description" \
  --argjson tags "$tags" \
  --argjson published "$published" \
  --arg reload "$last_reload" \
  --arg path "$rel_path" \
  '{($id): {name: $name, space: $space, spaceId: $spaceId, spaceType: $spaceType, appType: $appType, owner: $owner, ownerName: $ownerName, description: $desc, tags: $tags, published: $published, lastReloadTime: $reload, path: $path}}')
ENTRY

done < <(jq -c '.[]' "$APPS_FILE")

# --- Build index.json ---
INDEX_FILE=".qlik-sync/index.json"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

APPS_OBJ_FILE="$(mktemp)"
jq -s 'add // {}' "$INDEX_ENTRIES" > "$APPS_OBJ_FILE"

if [ "$PARTIAL" = true ] && [ -f "$INDEX_FILE" ]; then
  jq --slurpfile new "$APPS_OBJ_FILE" '(.apps // {}) + $new[0]' "$INDEX_FILE" > "${APPS_OBJ_FILE}.merged"
  mv "${APPS_OBJ_FILE}.merged" "$APPS_OBJ_FILE"
fi

FINAL_COUNT="$(jq 'length' "$APPS_OBJ_FILE")"

jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "$TENANT_ID" \
  --argjson appCount "$FINAL_COUNT" \
  --slurpfile apps "$APPS_OBJ_FILE" \
  '{lastSync: $lastSync, context: $context, server: $server, tenant: $tenant, tenantId: $tenantId, appCount: $appCount, apps: $apps[0]}' \
  > "$INDEX_FILE"

rm -f "$APPS_OBJ_FILE"

# --- Update config.json ---
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# --- Summary ---
echo ""
echo "Sync complete: $SYNCED synced, $SKIPPED skipped, $ERRORS errors (${FINAL_COUNT} apps in index)"

exit 0
