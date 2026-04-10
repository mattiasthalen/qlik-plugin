#!/bin/bash
# sync-lib.sh — Shared helpers for sync scripts

sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# read_tenant_config <config-file> <tenant-filter>
# Outputs JSON array of tenant objects
# Handles v0.1.0 (single-tenant) and v0.2.0 (multi-tenant) formats
# If tenant-filter is non-empty, returns only matching tenant by context name
read_tenant_config() {
  local config_file="$1"
  local tenant_filter="$2"

  local version
  version="$(jq -r '.version // "0.1.0"' "$config_file")"

  local tenants
  if [ "$version" = "0.2.0" ]; then
    tenants="$(jq '.tenants' "$config_file")"
  else
    tenants="$(jq '[{
      context: .context,
      server: .server,
      lastSync: .lastSync,
      type: (if (.server // "" | test("qlikcloud\\.com")) then "cloud" else "on-prem" end)
    }]' "$config_file")"
  fi

  if [ -n "$tenant_filter" ]; then
    echo "$tenants" | jq --arg name "$tenant_filter" '[.[] | select(.context == $name)]'
  else
    echo "$tenants"
  fi
}

detect_tenant_type() {
  local server="$1"
  if echo "$server" | grep -q 'qlikcloud\.com'; then
    echo "cloud"
  else
    echo "on-prem"
  fi
}

# check_cache <cache_file> <force>
# If cache file exists, is <5min old, and force is not "true", prints contents and returns 0.
# Otherwise returns 1.
check_cache() {
  local cache_file="$1"
  local force="$2"

  if [ "$force" = "true" ]; then
    return 1
  fi

  if [ ! -f "$cache_file" ]; then
    return 1
  fi

  if [ -z "$(find "$(dirname "$cache_file")" -name "$(basename "$cache_file")" -mmin -5 2>/dev/null)" ]; then
    return 1
  fi

  cat "$cache_file"
  return 0
}
