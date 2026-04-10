#!/bin/bash
# sync-finalize.sh — Build/merge index.json and update config
# Usage: sync-finalize.sh <prep-json-file> <results-json-file>
# stdout: summary line
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-finalize.sh <prep-json-file> <results-json-file>" >&2
  exit 1
fi

PREP_FILE="$1"
RESULTS_FILE="$2"
CONFIG_FILE=".qlik-sync/config.json"
INDEX_FILE=".qlik-sync/index.json"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Read prep metadata
TENANT="$(jq -r '.tenant' "$PREP_FILE")"
TENANT_ID="$(jq -r '.tenantId' "$PREP_FILE")"
CONTEXT="$(jq -r '.context' "$PREP_FILE")"
SERVER="$(jq -r '.server' "$PREP_FILE")"
TOTAL_APPS="$(jq -r '.totalApps' "$PREP_FILE")"

# Build apps object from prep data
# Each app entry keyed by resourceId, with trailing slash on path
APPS_OBJ="$(jq '
  [.apps[] | {
    key: .resourceId,
    value: {
      name: .name,
      space: .spaceName,
      spaceId: .spaceId,
      spaceType: .spaceType,
      appType: .appType,
      owner: .ownerId,
      ownerName: .ownerName,
      description: .description,
      tags: .tags,
      published: .published,
      lastReloadTime: .lastReloadTime,
      path: (.targetPath + "/")
    }
  }] | from_entries
' "$PREP_FILE")"

# Merge with existing index if partial sync
# When syncing fewer apps than the index already tracks, preserve existing entries
if [ -f "$INDEX_FILE" ]; then
  EXISTING_COUNT="$(jq '.appCount // 0' "$INDEX_FILE")"
  if [ "$TOTAL_APPS" -le "$EXISTING_COUNT" ]; then
    EXISTING_APPS="$(jq '.apps // {}' "$INDEX_FILE")"
    APPS_OBJ="$(jq -n --argjson existing "$EXISTING_APPS" --argjson new "$APPS_OBJ" '$existing + $new')"
  fi
fi

FINAL_COUNT="$(echo "$APPS_OBJ" | jq 'length')"

# Write index.json
jq -n \
  --arg lastSync "$NOW" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --arg tenant "$TENANT" \
  --arg tenantId "$TENANT_ID" \
  --argjson appCount "$FINAL_COUNT" \
  --argjson apps "$APPS_OBJ" \
  '{lastSync: $lastSync, context: $context, server: $server, tenant: $tenant, tenantId: $tenantId, appCount: $appCount, apps: $apps}' \
  > "$INDEX_FILE"

# Update config.json
jq --arg ts "$NOW" '.lastSync = $ts' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Summary from results
SYNCED="$(jq '[.[] | select(.status == "synced")] | length' "$RESULTS_FILE")"
SKIPPED="$(jq '[.[] | select(.status == "skipped")] | length' "$RESULTS_FILE")"
ERRORS="$(jq '[.[] | select(.status == "error")] | length' "$RESULTS_FILE")"

echo "Sync complete: $SYNCED synced, $SKIPPED skipped, $ERRORS errors (${FINAL_COUNT} apps in index)"
