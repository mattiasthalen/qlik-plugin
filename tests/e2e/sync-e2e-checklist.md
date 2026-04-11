# Sync E2E Verification Checklist

Run this checklist against a real Qlik Cloud tenant after making changes to sync skills or qs configuration.

## Prerequisites

- [ ] A Qlik Cloud tenant with at least 2 apps in different spaces
- [ ] `qlik` CLI installed and authenticated (`qlik context ls` shows active context)
- [ ] `qs` CLI installed (`qs version` returns a version)
- [ ] Clean `qlik/` directory (delete if exists from prior runs)

## Checklist

### Setup → Sync Handoff
- [ ] **1. Start with no config** — delete `qlik/` if it exists
- [ ] **2. Say "sync my tenant X"** — agent should detect missing config and run setup automatically
- [ ] **3. Complete setup** — provide tenant URL and API key when prompted
- [ ] **4. Verify auto-resume** — after setup completes, sync should start without the agent asking you to re-invoke `/qlik:sync`
- [ ] Expected: Sync begins immediately after setup finishes

### Full Sync
- [ ] **5. Sync completes** — `qs sync` pulls all apps successfully
- [ ] **6. Check config** — `qlik/config.json` has `lastSync` timestamp updated
- [ ] **7. Check index** — `qlik/index.json` exists, entry count matches prep report
- [ ] **8. Spot-check app** — pick one app directory under `qlik/`, verify `script.qvs` exists with valid content

### Resume (Skip Detection)
- [ ] **9. Re-run sync** — `qs sync` without `--force`
- [ ] **10. Verify skips** — all apps should be marked "skip" with "already synced" reason
- [ ] Expected: No API calls to `qlik app unbuild`

### Force Re-sync
- [ ] **11. Force single app** — `qs sync --force --id <app-id>`
- [ ] **12. Verify re-sync** — only the targeted app is re-synced, others untouched

### Prep Caching
- [ ] **13. Run prep twice** — run `qs prep` manually twice within 5 minutes
- [ ] **14. Verify cache hit** — second run returns instantly (no API delay)
- [ ] **15. Verify --force bypass** — run with `--force`, verify it makes API calls (takes 30-60s)

## Results

| Step | Pass/Fail | Notes |
|------|-----------|-------|
| 1-4  |           |       |
| 5-8  |           |       |
| 9-10 |           |       |
| 11-12|           |       |
| 13-15|           |       |

**Tested by:** _______________
**Date:** _______________
**Tenant:** _______________
