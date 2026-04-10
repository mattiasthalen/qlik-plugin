#!/bin/bash
# sync-app.sh — Sync a single Qlik app (mkdir + unbuild)
# Usage: sync-app.sh <resourceId> <targetPath>
# stdout: nothing (skill handles all user-facing output)
# stderr: error details if unbuild fails
# exit 0: success, exit 1: failure
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-app.sh <resourceId> <targetPath>" >&2
  exit 1
fi

RESOURCE_ID="$1"
TARGET_PATH="$2"
FULL_PATH=".qlik-sync/$TARGET_PATH"

mkdir -p "$FULL_PATH"
qlik app unbuild --app "$RESOURCE_ID" --dir "$FULL_PATH" < /dev/null >/dev/null 2>&1
