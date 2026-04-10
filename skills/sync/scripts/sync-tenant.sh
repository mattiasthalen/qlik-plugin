#!/bin/bash
# sync-tenant.sh — Sync Qlik Cloud apps to local filesystem
# Convenience wrapper that calls sync-cloud-prep.sh, sync-cloud-app.sh, sync-finalize.sh
# Usage: sync-tenant.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Run prep phase ---
PREP_FILE="$(mktemp)"
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$PREP_FILE" "$RESULTS_FILE"' EXIT

bash "$SCRIPT_DIR/sync-cloud-prep.sh" "$@" > "$PREP_FILE"

TOTAL_APPS="$(jq '.totalApps' "$PREP_FILE")"

if [ "$TOTAL_APPS" -eq 0 ]; then
  echo "No apps found matching filters."
  exit 0
fi

# --- Sync loop ---
IDX=0
echo "[]" > "$RESULTS_FILE"

while IFS= read -r app_line; do
  IDX=$((IDX + 1))

  resource_id="$(jq -r '.resourceId' <<< "$app_line")"
  app_name="$(jq -r '.name' <<< "$app_line")"
  space_name="$(jq -r '.spaceName' <<< "$app_line")"
  space_type="$(jq -r '.spaceType' <<< "$app_line")"
  owner_name="$(jq -r '.ownerName' <<< "$app_line")"
  target_path="$(jq -r '.targetPath' <<< "$app_line")"
  skip="$(jq -r '.skip' <<< "$app_line")"

  # Display space
  if [ "$space_type" = "personal" ]; then
    display_space="personal/$owner_name"
  elif [ "$space_type" = "unknown" ]; then
    display_space="unknown/$(jq -r '.spaceId' <<< "$app_line")"
  else
    display_space="$space_type/$space_name"
  fi

  if [ "$skip" = "true" ]; then
    echo "[$IDX/$TOTAL_APPS] SKIP: $display_space / $app_name"
    jq --arg id "$resource_id" '. + [{resourceId: $id, status: "skipped"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
  else
    echo "[$IDX/$TOTAL_APPS] Syncing: $display_space / $app_name..."
    if bash "$SCRIPT_DIR/sync-cloud-app.sh" "$resource_id" "$target_path" 2>/dev/null; then
      jq --arg id "$resource_id" '. + [{resourceId: $id, status: "synced"}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    else
      echo "  WARNING: Failed to unbuild $app_name ($resource_id)" >&2
      jq --arg id "$resource_id" --arg err "unbuild failed" '. + [{resourceId: $id, status: "error", error: $err}]' "$RESULTS_FILE" > "${RESULTS_FILE}.tmp" && mv "${RESULTS_FILE}.tmp" "$RESULTS_FILE"
    fi
  fi

done < <(jq -c '.apps[]' "$PREP_FILE")

# --- Finalize ---
echo ""
bash "$SCRIPT_DIR/sync-finalize.sh" "$PREP_FILE" "$RESULTS_FILE"
