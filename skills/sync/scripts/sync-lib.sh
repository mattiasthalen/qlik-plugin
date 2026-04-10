#!/bin/bash
# sync-lib.sh — Shared helpers for sync scripts

sanitize() {
  echo "$1" | tr '/\\:*?"<>|' '_________'
}

normalize_app_type() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}
