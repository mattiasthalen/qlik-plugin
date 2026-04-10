#!/bin/bash
# sync-onprem-app.sh — Export, download, and parse a single on-prem Qlik app
# Usage: sync-onprem-app.sh <appId> <targetPath>
# stdout: nothing (skill handles all user-facing output)
# stderr: error details on failure
# exit 0: success, exit 1: failure
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: sync-onprem-app.sh <appId> <targetPath>" >&2
  exit 1
fi

APP_ID="$1"
TARGET_PATH="$2"
FULL_PATH=".qlik-sync/$TARGET_PATH"
QVF_PATH="/tmp/${APP_ID}.qvf"

# Cleanup QVF on exit (success or failure)
trap 'rm -f "$QVF_PATH"' EXIT

# Step 1: Create export ticket
TICKET="$(qlik qrs app export create "$APP_ID" --skipdata --json < /dev/null | jq -r '.exportTicketId')"

if [ -z "$TICKET" ] || [ "$TICKET" = "null" ]; then
  echo "Error: failed to get export ticket for $APP_ID" >&2
  exit 1
fi

# Step 2: Download QVF
qlik qrs download app get "${APP_ID}.qvf" --appId "$APP_ID" --exportticketid "$TICKET" --output-file "$QVF_PATH" < /dev/null >/dev/null

if [ ! -f "$QVF_PATH" ]; then
  echo "Error: QVF download failed for $APP_ID" >&2
  exit 1
fi

# Step 3: Parse with qlik-parser
mkdir -p "$FULL_PATH"
qlik-parser extract --source "$QVF_PATH" --out "$FULL_PATH" --script --measures --dimensions --variables >/dev/null
