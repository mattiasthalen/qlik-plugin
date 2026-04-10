#!/bin/bash
# sync-prep.sh — Fetch and resolve Qlik app list for sync
# Usage: sync-prep.sh [--space "Name"] [--app "Pattern"] [--id <GUID>] [--force]
# Outputs JSON to stdout with app list and resolved metadata
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

# Placeholder — will output JSON in next tasks
echo "{}"
