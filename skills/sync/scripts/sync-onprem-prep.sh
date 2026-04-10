#!/bin/bash
# sync-onprem-prep.sh — Fetch and resolve Qlik on-prem app list for sync
# Usage: sync-onprem-prep.sh [--stream "Name"] [--app "Pattern"] [--id <GUID>] [--force] [--tenant <context>]
# Outputs JSON to stdout with app list and resolved metadata
set -euo pipefail

# --- Source shared helpers ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

# --- Parse flags ---
STREAM_FILTER=""
APP_FILTER=""
ID_FILTER=""
FORCE=false
TENANT_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --stream) STREAM_FILTER="$2"; shift 2 ;;
    --app)    APP_FILTER="$2"; shift 2 ;;
    --id)     ID_FILTER="$2"; shift 2 ;;
    --tenant) TENANT_FILTER="$2"; shift 2 ;;
    --force)  FORCE=true; shift ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: sync-onprem-prep.sh [--stream \"Name\"] [--app \"Pattern\"] [--id <GUID>] [--tenant <context>] [--force]" >&2
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

TENANTS_JSON="$(read_tenant_config "$CONFIG_FILE" "$TENANT_FILTER")"
# Filter to on-prem tenants only
TENANTS_JSON="$(echo "$TENANTS_JSON" | jq '[.[] | select(.type == "on-prem")]')"
TENANT_COUNT="$(echo "$TENANTS_JSON" | jq 'length')"
if [ "$TENANT_COUNT" -eq 0 ]; then
  echo "Error: no matching on-prem tenant found." >&2
  exit 1
fi
TENANT_JSON="$(echo "$TENANTS_JSON" | jq '.[0]')"
CONTEXT="$(echo "$TENANT_JSON" | jq -r '.context')"
SERVER="$(echo "$TENANT_JSON" | jq -r '.server')"

if [ -z "$CONTEXT" ] || [ -z "$SERVER" ]; then
  echo "Error: config.json missing context or server." >&2
  exit 1
fi

TENANT_DOMAIN="$(echo "$SERVER" | sed -E 's|https?://([^/:]+).*|\1|')"

# --- Cache check ---
CACHE_KEY="${CONTEXT}"
if [ -n "$STREAM_FILTER" ]; then CACHE_KEY="${CACHE_KEY}-s-${STREAM_FILTER}"; fi
if [ -n "$APP_FILTER" ]; then CACHE_KEY="${CACHE_KEY}-a-${APP_FILTER}"; fi
if [ -n "$ID_FILTER" ]; then CACHE_KEY="${CACHE_KEY}-i-${ID_FILTER}"; fi
WORKDIR_HASH="$(pwd | md5sum | cut -c1-8)"
CACHE_FILE="/tmp/qlik-sync-prep-${CACHE_KEY}-${WORKDIR_HASH}.json"
if check_cache "$CACHE_FILE" "$FORCE"; then
  exit 0
fi

# --- Check dependencies ---
for cmd in qlik jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd not found on PATH." >&2
    exit 1
  fi
done

# --- Fetch streams and build lookup ---
STREAMS_JSON="$(qlik qrs stream ls --json)"

STREAM_LOOKUP="$(mktemp)"
APPS_FILE="$(mktemp)"
trap 'rm -f "$STREAM_LOOKUP" "$APPS_FILE"' EXIT

echo "$STREAMS_JSON" | jq -r '.[] | "\(.id)\t\(.name)"' > "$STREAM_LOOKUP"

# --- Resolve stream ID for stream filter ---
STREAM_ID_FILTER=""
if [ -n "$STREAM_FILTER" ]; then
  STREAM_ID_FILTER="$(grep "	${STREAM_FILTER}$" "$STREAM_LOOKUP" 2>/dev/null | cut -f1 || true)"
  if [ -z "$STREAM_ID_FILTER" ]; then
    echo "Error: stream '$STREAM_FILTER' not found." >&2
    exit 1
  fi
fi

# --- Fetch apps ---
qlik qrs app full --json > "$APPS_FILE"

# Apply ID filter
if [ -n "$ID_FILTER" ]; then
  jq --arg id "$ID_FILTER" '[.[] | select(.id == $id)]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

# Apply stream filter
if [ -n "$STREAM_ID_FILTER" ]; then
  jq --arg sid "$STREAM_ID_FILTER" '[.[] | select(.stream != null and .stream.id == $sid)]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

# Apply app name filter
if [ -n "$APP_FILTER" ]; then
  jq --arg pat "$APP_FILTER" '[.[] | select(.name | test($pat))]' "$APPS_FILE" > "${APPS_FILE}.tmp" && mv "${APPS_FILE}.tmp" "$APPS_FILE"
fi

APP_COUNT="$(jq 'length' "$APPS_FILE")"

if [ "$APP_COUNT" -eq 0 ]; then
  echo '{"tenant":"'"$TENANT_DOMAIN"'","tenantId":"","context":"'"$CONTEXT"'","server":"'"$SERVER"'","totalApps":0,"apps":[]}'
  exit 0
fi

# --- Build app entries ---
APP_ENTRIES="$(mktemp)"
trap 'rm -f "$STREAM_LOOKUP" "$APPS_FILE" "$APP_ENTRIES"' EXIT

while IFS= read -r app_line; do
  resource_id="$(jq -r '.id' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  description="$(jq -r '.description // empty' <<< "$app_line")"
  published="$(jq -r '.published // false' <<< "$app_line")"
  last_reload="$(jq -r '.lastReloadTime // empty' <<< "$app_line")"
  tags="$(jq -c '[.tags[]?.name // empty]' <<< "$app_line")"

  stream_id="$(jq -r '.stream.id // empty' <<< "$app_line")"
  stream_name="$(jq -r '.stream.name // empty' <<< "$app_line")"
  owner_id="$(jq -r '.owner.id // empty' <<< "$app_line")"
  owner_name="$(jq -r '.owner.name // empty' <<< "$app_line")"

  # Determine space type and build path
  if [ -n "$stream_id" ] && [ "$stream_id" != "null" ]; then
    space_type="stream"
    space_name="$stream_name"
    space_id="$stream_id"
    space_folder="$(sanitize "$stream_name") ($stream_id)"
  else
    space_type="personal"
    space_name=""
    space_id=""
    space_folder="$(sanitize "$owner_name") ($owner_id)"
  fi

  safe_app="$(sanitize "$app_name")"
  app_folder="$safe_app ($resource_id)"

  # On-prem: no app-type level in path
  target_path="$TENANT_DOMAIN/$space_type/$space_folder/$app_folder"
  full_path=".qlik-sync/$target_path"

  # Resume check — uses script.qvs for on-prem
  skip=false
  skip_reason=""
  if [ "$FORCE" = false ] && [ -f "$full_path/script.qvs" ]; then
    skip=true
    skip_reason="already synced (use --force to re-sync)"
  fi

  jq -n \
    --arg resourceId "$resource_id" \
    --arg name "$app_name" \
    --arg spaceId "$space_id" \
    --arg spaceName "$space_name" \
    --arg spaceType "$space_type" \
    --arg ownerId "$owner_id" \
    --arg ownerName "$owner_name" \
    --arg description "$description" \
    --argjson tags "$tags" \
    --argjson published "$published" \
    --arg lastReloadTime "$last_reload" \
    --arg targetPath "$target_path" \
    --argjson skip "$skip" \
    --arg skipReason "$skip_reason" \
    '{resourceId: $resourceId, name: $name, spaceId: $spaceId, spaceName: $spaceName, spaceType: $spaceType, appType: null, ownerId: $ownerId, ownerName: $ownerName, description: $description, tags: $tags, published: $published, lastReloadTime: $lastReloadTime, targetPath: $targetPath, skip: $skip, skipReason: $skipReason}' \
    >> "$APP_ENTRIES"

done < <(jq -c '.[]' "$APPS_FILE")

# --- Output final JSON ---
OUTPUT="$(jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}')"

echo "$OUTPUT" | tee "$CACHE_FILE"
