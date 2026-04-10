#!/bin/bash
# sync-prep.sh — Fetch and resolve Qlik app list for sync
# Usage: sync-prep.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
# Outputs JSON to stdout with app list and resolved metadata
set -euo pipefail

# --- Source shared helpers ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

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
      echo "Usage: sync-prep.sh [--space \"Name\"] [--app \"Pattern\"] [--id <GUID>] [--force]" >&2
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
APPS_FILE="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$APPS_FILE"' EXIT

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

# --- Resolve space ID for space filter ---
SPACE_ID_FILTER=""
if [ -n "$SPACE_FILTER" ]; then
  SPACE_ID_FILTER="$(grep "	${SPACE_FILTER}	" "$SPACE_LOOKUP" 2>/dev/null | cut -f1 || true)"
  if [ -z "$SPACE_ID_FILTER" ]; then
    echo "Error: space '$SPACE_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
if [ -n "$ID_FILTER" ]; then
  qlik app ls --json --limit 1000 | jq "[.[] | select(.resourceId == \"$ID_FILTER\")]" > "$APPS_FILE"
elif [ -n "$SPACE_ID_FILTER" ]; then
  qlik app ls --json --limit 1000 --spaceId "$SPACE_ID_FILTER" > "$APPS_FILE"
else
  qlik app ls --json --limit 1000 > "$APPS_FILE"
fi

if [ -n "$APP_FILTER" ]; then
  jq --arg pat "$APP_FILTER" '[.[] | select(.name | test($pat))]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

APP_COUNT="$(jq 'length' "$APPS_FILE")"

if [ "$APP_COUNT" -eq 0 ]; then
  echo '{"tenant":"","tenantId":"","context":"'"$CONTEXT"'","server":"'"$SERVER"'","totalApps":0,"apps":[]}'
  exit 0
fi

TENANT_ID="$(jq -r '.[0].tenantId // empty' "$APPS_FILE")"
TENANT_DIR="$TENANT_DOMAIN ($TENANT_ID)"

# --- Build app entries ---
APP_ENTRIES="$(mktemp)"
trap 'rm -f "$SPACE_LOOKUP" "$USER_CACHE" "$APPS_FILE" "$APP_ENTRIES"' EXIT

while IFS= read -r app_line; do
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

  if [ "$space_type" = "personal" ]; then
    owner_name="$(resolve_username "$owner_id")"
    space_folder="$(sanitize "$owner_name") ($owner_id)"
  elif [ "$space_type" = "unknown" ]; then
    space_folder="$space_id"
    space_name="$space_id"
    owner_name="$(resolve_username "$owner_id")"
  else
    space_folder="$(sanitize "$space_name") ($space_id)"
    owner_name="$(resolve_username "$owner_id")"
  fi

  safe_app="$(sanitize "$app_name")"
  app_folder="$safe_app ($resource_id)"

  target_path="$TENANT_DIR/$space_type/$space_folder/$app_type/$app_folder"
  full_path=".qlik-sync/$target_path"

  # Resume check
  skip=false
  skip_reason=""
  if [ "$FORCE" = false ] && [ -f "$full_path/config.yml" ]; then
    skip=true
    skip_reason="already synced (use --force to re-sync)"
  fi

  jq -n \
    --arg resourceId "$resource_id" \
    --arg name "$app_name" \
    --arg spaceId "$space_id" \
    --arg spaceName "$space_name" \
    --arg spaceType "$space_type" \
    --arg appType "$app_type" \
    --arg ownerId "$owner_id" \
    --arg ownerName "$owner_name" \
    --arg description "$description" \
    --argjson tags "$tags" \
    --argjson published "$published" \
    --arg lastReloadTime "$last_reload" \
    --arg targetPath "$target_path" \
    --argjson skip "$skip" \
    --arg skipReason "$skip_reason" \
    '{resourceId: $resourceId, name: $name, spaceId: $spaceId, spaceName: $spaceName, spaceType: $spaceType, appType: $appType, ownerId: $ownerId, ownerName: $ownerName, description: $description, tags: $tags, published: $published, lastReloadTime: $lastReloadTime, targetPath: $targetPath, skip: $skip, skipReason: $skipReason}' \
    >> "$APP_ENTRIES"

done < <(jq -c '.[]' "$APPS_FILE")

# --- Output final JSON ---
jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "$TENANT_ID" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}'
