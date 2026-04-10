#!/bin/bash
# sync-tenant.sh — Convenience wrapper that calls prep/app/finalize
# Usage: sync-tenant.sh [--space "Name"] [--stream "Name"] [--app "Pattern"] [--id <GUID>] [--force] [--tenant "ctx"]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sync-lib.sh"

# --- Parse flags (pass through to prep scripts) ---
FLAGS=()
TENANT_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tenant) TENANT_FILTER="$2"; FLAGS+=("$1" "$2"); shift 2 ;;
    --space|--stream|--app|--id) FLAGS+=("$1" "$2"); shift 2 ;;
    --force) FLAGS+=("$1"); shift ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

CONFIG_FILE=".qlik-sync/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found. Run setup first." >&2
  exit 1
fi

TENANTS_JSON="$(read_tenant_config "$CONFIG_FILE" "$TENANT_FILTER")"
TENANT_COUNT="$(echo "$TENANTS_JSON" | jq 'length')"

if [ "$TENANT_COUNT" -eq 0 ]; then
  echo "Error: no matching tenant found." >&2
  exit 1
fi

PREP_FILE="$(mktemp)"
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$PREP_FILE" "$RESULTS_FILE"' EXIT

for i in $(seq 0 $((TENANT_COUNT - 1))); do
  TENANT_TYPE="$(echo "$TENANTS_JSON" | jq -r ".[$i].type")"

  if [ "$TENANT_TYPE" = "on-prem" ]; then
    PREP_SCRIPT="$SCRIPT_DIR/sync-onprem-prep.sh"
    APP_SCRIPT="$SCRIPT_DIR/sync-onprem-app.sh"
  else
    PREP_SCRIPT="$SCRIPT_DIR/sync-cloud-prep.sh"
    APP_SCRIPT="$SCRIPT_DIR/sync-cloud-app.sh"
  fi

  # Run prep — handle empty FLAGS array safely
  if [ ${#FLAGS[@]} -gt 0 ]; then
    bash "$PREP_SCRIPT" "${FLAGS[@]}" > "$PREP_FILE" 2>&1 || { cat "$PREP_FILE"; exit 1; }
  else
    bash "$PREP_SCRIPT" > "$PREP_FILE" 2>&1 || { cat "$PREP_FILE"; exit 1; }
  fi

  APP_COUNT="$(jq '.totalApps' "$PREP_FILE")"
  if [ "$APP_COUNT" -eq 0 ]; then
    echo "No apps found."
    continue
  fi

  # Loop apps
  echo '[]' > "$RESULTS_FILE"
  IDX=0
  while IFS= read -r app_json; do
    IDX=$((IDX + 1))
    resource_id="$(jq -r '.resourceId' <<< "$app_json")"
    app_name="$(jq -r '.name' <<< "$app_json")"
    target_path="$(jq -r '.targetPath' <<< "$app_json")"
    space_type="$(jq -r '.spaceType' <<< "$app_json")"
    space_name="$(jq -r '.spaceName' <<< "$app_json")"
    skip="$(jq -r '.skip' <<< "$app_json")"

    if [ "$skip" = "true" ]; then
      echo "[$IDX/$APP_COUNT] SKIP: $space_type/$space_name / $app_name"
      jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "skipped"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    else
      echo "[$IDX/$APP_COUNT] Syncing: $space_type/$space_name / $app_name..."
      if bash "$APP_SCRIPT" "$resource_id" "$target_path" 2>&1; then
        jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "synced"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
      else
        echo "  WARNING: Failed to sync $app_name ($resource_id)" >&2
        jq --arg id "$resource_id" '. += [{"resourceId": $id, "status": "error", "error": "sync failed"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
      fi
    fi
  done < <(jq -c '.apps[]' "$PREP_FILE")

  # Finalize
  bash "$SCRIPT_DIR/sync-finalize.sh" "$PREP_FILE" "$RESULTS_FILE"
done
