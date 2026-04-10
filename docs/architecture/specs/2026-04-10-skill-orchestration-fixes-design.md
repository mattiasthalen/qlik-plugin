# Skill Orchestration Fixes — Design Spec

**Date:** 2026-04-10
**Approach:** B (skill + script changes)

## Problem

Four issues surfaced during real-world sync sessions:

1. **Setup→sync handoff breaks flow** — sync detects missing config, triggers setup, but after setup completes the agent asks the user to re-invoke sync instead of resuming automatically.
2. **Prep scripts get backgrounded** — network-calling scripts (`sync-cloud-prep.sh`, `sync-onprem-prep.sh`) take 30-60s, causing the Claude Code harness to auto-background them. Output lands in a temp file instead of inline, leading to empty reads and confusion.
3. **No recovery guidance for backgrounded commands** — when commands go to background, the skill has no troubleshooting guidance, so the agent retries blindly.
4. **Redundant API calls on retry** — failed reads cause the agent to re-run prep scripts, hitting Qlik APIs again unnecessarily.

## Changes

### 1. Auto-Resume After Setup (sync SKILL.md)

Add to the Prerequisites section of `skills/sync/SKILL.md`:

> **Auto-resume after setup:** If setup was triggered as a prerequisite for sync (i.e., the user's original intent was to sync), resume the sync automatically after setup completes. Do not ask the user to re-invoke `/qlik:sync`.

No changes to setup SKILL.md — setup remains independent.

### 2. Execution Notes (sync SKILL.md)

Add an "Execution Notes" section before Step 1:

> **Execution Notes:**
> - Prep scripts (`sync-cloud-prep.sh`, `sync-onprem-prep.sh`) make multiple API calls and may take 30-60 seconds. Always use `timeout: 120000` on these Bash calls.
> - App sync scripts (`sync-cloud-app.sh`, `sync-onprem-app.sh`) also involve network calls. Use `timeout: 120000`.
> - Finalize script is local-only and fast — default timeout is fine.

### 3. Troubleshooting Section (sync SKILL.md)

Add a "Troubleshooting" section at end of sync SKILL.md:

- **Empty output from prep script**: Command may have been backgrounded. Re-run with explicit `timeout: 120000`. If `/tmp/qlik-sync-prep.json` exists and is recent, read it instead of re-running.
- **Auth errors (401)**: Suggest `qlik context login` to re-authenticate.
- **Network timeout**: Check VPN/proxy, verify tenant URL.
- **Partial sync failures**: Use `--force` with specific `--id` to retry failed apps.

### 4. Prep Script Caching (sync-cloud-prep.sh, sync-onprem-prep.sh)

Add TTL-based caching at the top of each prep script, after flag parsing:

1. Compute cache path: `/tmp/qlik-sync-prep-<context>.json` (where `<context>` is the tenant context name from config). This prevents cross-tenant cache collisions.
2. Check if the cache file exists.
3. Check if it's less than 5 minutes old (`find -mmin -5`).
4. If both true and `--force` is not set, output cached file contents to stdout and exit 0.
5. Otherwise, proceed with normal API calls and write output to the cache path before exiting.

`--force` bypasses the cache.

The SKILL.md instructions for reading prep output should use the same tenant-keyed path: `/tmp/qlik-sync-prep-<context>.json`.

### 5. Developer E2E Verification Checklist

Add `tests/e2e/sync-e2e-checklist.md` — a manual checklist for developers/agents to verify sync against a real Qlik Cloud tenant after making plugin changes.

Steps:

1. Run `/qlik:setup` — configure a real cloud tenant.
2. Run `/qlik:sync` — full sync (no filters).
3. Verify `.qlik-sync/config.json` has `lastSync` updated.
4. Verify `.qlik-sync/index.json` has entries matching app count from prep report.
5. Spot-check one app directory — `script.qvs` exists with valid content.
6. Run `/qlik:sync` again (no `--force`) — verify all apps marked "skip" (resume works).
7. Run `/qlik:sync --force --id <app-id>` — verify single app re-synced.
8. Run prep script twice within 5 minutes — verify second run uses cache (fast return, no API calls).
9. Verify setup→sync handoff: start with no config, say "sync my tenant X" — confirm setup runs then sync resumes automatically without re-prompting.

Each step has an expected outcome. Developer marks pass/fail.

## Files Changed

| File | Change |
|------|--------|
| `skills/sync/SKILL.md` | Add auto-resume note, execution notes, troubleshooting section |
| `skills/sync/scripts/sync-cloud-prep.sh` | Add TTL cache check after flag parsing |
| `skills/sync/scripts/sync-onprem-prep.sh` | Add TTL cache check after flag parsing |
| `tests/test-sync-cloud-prep.sh` | Add tests for cache hit, cache miss, cache bypass with --force |
| `tests/test-sync-onprem-prep.sh` | Add tests for cache hit, cache miss, cache bypass with --force |
| `tests/test-sync.sh` | Add assertions for new SKILL.md content (execution notes, troubleshooting, auto-resume) |
| `tests/e2e/sync-e2e-checklist.md` | New file — developer e2e verification checklist |

## Out of Scope

- Setup skill chaining mechanism (unnecessary complexity)
- Script-side progress indicators (timeout guidance is sufficient)
- CI-automated e2e tests (requires stored credentials infrastructure)
