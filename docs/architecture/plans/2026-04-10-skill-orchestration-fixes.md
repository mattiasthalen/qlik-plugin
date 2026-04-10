# Skill Orchestration Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four skill orchestration issues — setup→sync handoff, command timeouts, troubleshooting guidance, and redundant API calls — plus add a developer e2e verification checklist.

**Architecture:** Changes span two layers: SKILL.md instructions (agent behavior guidance) and prep scripts (TTL-based caching). No new dependencies. Caching uses filesystem timestamps via `find -mmin`.

**Tech Stack:** Bash, jq, Claude Code skill markdown

---

## File Structure

| File | Role |
|------|------|
| `skills/sync/SKILL.md` | Agent instructions — add auto-resume, execution notes, troubleshooting |
| `skills/sync/scripts/sync-lib.sh` | Shared helpers — add `check_cache` function |
| `skills/sync/scripts/sync-cloud-prep.sh` | Cloud prep — integrate cache check |
| `skills/sync/scripts/sync-onprem-prep.sh` | On-prem prep — integrate cache check |
| `tests/test-sync-lib.sh` | Tests for new `check_cache` function |
| `tests/test-sync-cloud-prep.sh` | Tests for cloud prep caching |
| `tests/test-sync-onprem-prep.sh` | Tests for on-prem prep caching |
| `tests/test-sync.sh` | Tests for new SKILL.md content |
| `tests/e2e/sync-e2e-checklist.md` | Developer e2e verification checklist |

---

### Task 1: Add `check_cache` to sync-lib.sh

**Files:**
- Modify: `skills/sync/scripts/sync-lib.sh:49` (append)
- Test: `tests/test-sync-lib.sh`

- [ ] **Step 1: Write failing test for cache hit**

Add to `tests/test-sync-lib.sh` at the end, before `test_summary`:

```bash
# Test: check_cache returns cached content when fresh
echo ""
echo "--- Test: check_cache hit ---"
CACHE_DIR="$(mktemp -d)"
CACHE_FILE="$CACHE_DIR/qlik-sync-prep-test-ctx.json"
echo '{"cached":true}' > "$CACHE_FILE"
TESTS_RUN=$((TESTS_RUN + 1))
CACHE_RESULT="$(check_cache "$CACHE_FILE" false)"
CACHE_EXIT=$?
if [ "$CACHE_EXIT" -eq 0 ] && [ "$CACHE_RESULT" = '{"cached":true}' ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: cache hit returns content"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: cache hit expected content, got exit=$CACHE_EXIT output=$CACHE_RESULT"
fi
rm -rf "$CACHE_DIR"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync-lib.sh`
Expected: FAIL — `check_cache: command not found`

- [ ] **Step 3: Write failing test for cache miss (stale file)**

Add to `tests/test-sync-lib.sh` before `test_summary`:

```bash
# Test: check_cache returns non-zero for stale cache
echo ""
echo "--- Test: check_cache miss (stale) ---"
CACHE_DIR2="$(mktemp -d)"
CACHE_FILE2="$CACHE_DIR2/qlik-sync-prep-old.json"
echo '{"cached":true}' > "$CACHE_FILE2"
touch -t 200001010000 "$CACHE_FILE2"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "$CACHE_FILE2" false >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: stale cache should miss"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: stale cache returns non-zero"
fi
rm -rf "$CACHE_DIR2"
```

- [ ] **Step 4: Write failing test for cache bypass with --force**

Add to `tests/test-sync-lib.sh` before `test_summary`:

```bash
# Test: check_cache bypassed when force=true
echo ""
echo "--- Test: check_cache bypass with force ---"
CACHE_DIR3="$(mktemp -d)"
CACHE_FILE3="$CACHE_DIR3/qlik-sync-prep-force.json"
echo '{"cached":true}' > "$CACHE_FILE3"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "$CACHE_FILE3" true >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: force should bypass cache"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: force bypasses cache"
fi
rm -rf "$CACHE_DIR3"
```

- [ ] **Step 5: Write failing test for cache miss (no file)**

Add to `tests/test-sync-lib.sh` before `test_summary`:

```bash
# Test: check_cache returns non-zero when no file exists
echo ""
echo "--- Test: check_cache miss (no file) ---"
TESTS_RUN=$((TESTS_RUN + 1))
if check_cache "/tmp/nonexistent-cache-file.json" false >/dev/null 2>&1; then
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: missing file should miss"
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: missing file returns non-zero"
fi
```

- [ ] **Step 6: Run tests to verify all four fail**

Run: `bash tests/test-sync-lib.sh`
Expected: 4 FAIL — `check_cache: command not found`

- [ ] **Step 7: Implement check_cache in sync-lib.sh**

Append to `skills/sync/scripts/sync-lib.sh` after line 49:

```bash
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
```

- [ ] **Step 8: Run tests to verify all pass**

Run: `bash tests/test-sync-lib.sh`
Expected: All PASS

- [ ] **Step 9: Commit**

```bash
git add skills/sync/scripts/sync-lib.sh tests/test-sync-lib.sh
git commit -m "feat(sync): add check_cache helper for TTL-based prep caching"
git push
```

---

### Task 2: Integrate caching into sync-cloud-prep.sh

**Files:**
- Modify: `skills/sync/scripts/sync-cloud-prep.sh:31-54` (add cache check after flag parsing, before config read)
- Modify: `skills/sync/scripts/sync-cloud-prep.sh:216-223` (tee output to cache file)
- Test: `tests/test-sync-cloud-prep.sh`

- [ ] **Step 1: Write failing test for cache hit**

Add to `tests/test-sync-cloud-prep.sh` before `test_summary`:

```bash
# Test 9: Cache hit — fresh cache file skips API calls
echo ""
echo "--- Test 9: Cache hit ---"
rm -f /tmp/qlik-sync-prep-test-ctx.json
WORKDIR7="$(setup_workdir)"
# Run once to populate cache
FIRST_OUTPUT="$(run_prep "$WORKDIR7")"
# Cache file should exist
CACHE_FILE="/tmp/qlik-sync-prep-test-ctx.json"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -f "$CACHE_FILE" ]; then
  # Run again — should return cached output
  SECOND_OUTPUT="$(run_prep "$WORKDIR7")"
  if [ "$FIRST_OUTPUT" = "$SECOND_OUTPUT" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: second run returns cached output"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: cached output differs from first run"
  fi
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: cache file not created at $CACHE_FILE"
fi
```

- [ ] **Step 2: Write failing test for cache bypass with --force**

Add to `tests/test-sync-cloud-prep.sh` before `test_summary`:

```bash
# Test 10: Cache bypass with --force
echo ""
echo "--- Test 10: Cache bypass with --force ---"
# Cache file should still exist from Test 9
TESTS_RUN=$((TESTS_RUN + 1))
FORCE_OUTPUT="$(run_prep "$WORKDIR7" --force)"
FORCE_APPS="$(echo "$FORCE_OUTPUT" | jq '.totalApps')"
if [ "$FORCE_APPS" = "6" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: --force bypasses cache and fetches fresh data"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 6 apps with --force, got $FORCE_APPS"
fi
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash tests/test-sync-cloud-prep.sh`
Expected: 2 FAIL — cache file not created

- [ ] **Step 4: Implement caching in sync-cloud-prep.sh**

After the flag parsing loop (line 31) and before the config read section (line 33), add:

```bash
# --- Cache check ---
CACHE_FILE="/tmp/qlik-sync-prep-${TENANT_FILTER:-default}.json"
```

This won't work yet because we need the tenant context name for the cache key. The context is read from config later. So instead, add the cache check after the config read section resolves `CONTEXT` (after line 53). Insert after line 53 (`TENANT_DOMAIN=...`):

```bash
# --- Cache check ---
CACHE_FILE="/tmp/qlik-sync-prep-${CONTEXT}.json"
if check_cache "$CACHE_FILE" "$FORCE"; then
  exit 0
fi
```

Then wrap the final JSON output (lines 216-223) to also write to cache. Replace the final `jq -n` block:

```bash
# --- Output final JSON ---
OUTPUT="$(jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "$TENANT_ID" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}')"

echo "$OUTPUT" | tee "$CACHE_FILE"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-sync-cloud-prep.sh`
Expected: All PASS

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `just test`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add skills/sync/scripts/sync-cloud-prep.sh tests/test-sync-cloud-prep.sh
git commit -m "feat(sync): add TTL cache to cloud prep script"
git push
```

---

### Task 3: Integrate caching into sync-onprem-prep.sh

**Files:**
- Modify: `skills/sync/scripts/sync-onprem-prep.sh:57` (add cache check after TENANT_DOMAIN)
- Modify: `skills/sync/scripts/sync-onprem-prep.sh:177-184` (tee output to cache file)
- Test: `tests/test-sync-onprem-prep.sh`

- [ ] **Step 1: Write failing test for cache hit**

Add to `tests/test-sync-onprem-prep.sh` before `test_summary`:

```bash
# Test 6: Cache hit — fresh cache file skips API calls
echo ""
echo "--- Test 6: Cache hit ---"
rm -f /tmp/qlik-sync-prep-onprem-ctx.json
WORKDIR5="$(setup_workdir)"
FIRST_OUTPUT="$(run_prep "$WORKDIR5")"
CACHE_FILE="/tmp/qlik-sync-prep-onprem-ctx.json"
TESTS_RUN=$((TESTS_RUN + 1))
if [ -f "$CACHE_FILE" ]; then
  SECOND_OUTPUT="$(run_prep "$WORKDIR5")"
  if [ "$FIRST_OUTPUT" = "$SECOND_OUTPUT" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: second run returns cached output"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: cached output differs from first run"
  fi
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: cache file not created at $CACHE_FILE"
fi
```

- [ ] **Step 2: Write failing test for cache bypass with --force**

Add to `tests/test-sync-onprem-prep.sh` before `test_summary`:

```bash
# Test 7: Cache bypass with --force
echo ""
echo "--- Test 7: Cache bypass with --force ---"
TESTS_RUN=$((TESTS_RUN + 1))
FORCE_OUTPUT="$(run_prep "$WORKDIR5" --force)"
FORCE_APPS="$(echo "$FORCE_OUTPUT" | jq '.totalApps')"
if [ "$FORCE_APPS" = "3" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: --force bypasses cache and fetches fresh data"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: expected 3 apps with --force, got $FORCE_APPS"
fi
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash tests/test-sync-onprem-prep.sh`
Expected: 2 FAIL — cache file not created

- [ ] **Step 4: Implement caching in sync-onprem-prep.sh**

After line 57 (`TENANT_DOMAIN=...`), insert:

```bash
# --- Cache check ---
CACHE_FILE="/tmp/qlik-sync-prep-${CONTEXT}.json"
if check_cache "$CACHE_FILE" "$FORCE"; then
  exit 0
fi
```

Replace the final `jq -n` block (lines 177-184):

```bash
# --- Output final JSON ---
OUTPUT="$(jq -n \
  --arg tenant "$TENANT_DOMAIN" \
  --arg tenantId "" \
  --arg context "$CONTEXT" \
  --arg server "$SERVER" \
  --argjson totalApps "$APP_COUNT" \
  --slurpfile apps "$APP_ENTRIES" \
  '{tenant: $tenant, tenantId: $tenantId, context: $context, server: $server, totalApps: $totalApps, apps: $apps}')"

echo "$OUTPUT" | tee "$CACHE_FILE"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-sync-onprem-prep.sh`
Expected: All PASS

- [ ] **Step 6: Run full test suite**

Run: `just test`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add skills/sync/scripts/sync-onprem-prep.sh tests/test-sync-onprem-prep.sh
git commit -m "feat(sync): add TTL cache to on-prem prep script"
git push
```

---

### Task 4: Update sync SKILL.md — auto-resume, execution notes, troubleshooting

**Files:**
- Modify: `skills/sync/SKILL.md`
- Test: `tests/test-sync.sh`

- [ ] **Step 1: Write failing tests for new SKILL.md content**

Add to `tests/test-sync.sh` before `test_summary`:

```bash
echo ""
echo "=== skill orchestration tests ==="
assert_contains "mentions auto-resume after setup" "$SKILL_CONTENT" "resume the sync automatically"
assert_contains "mentions timeout 120000" "$SKILL_CONTENT" "timeout: 120000"
assert_contains "has execution notes section" "$SKILL_CONTENT" "Execution Notes"
assert_contains "has troubleshooting section" "$SKILL_CONTENT" "Troubleshooting"
assert_contains "mentions backgrounded commands" "$SKILL_CONTENT" "backgrounded"
assert_contains "mentions cache file path" "$SKILL_CONTENT" "qlik-sync-prep-"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-sync.sh`
Expected: 6 FAIL — content not found

- [ ] **Step 3: Add auto-resume note to Prerequisites section**

In `skills/sync/SKILL.md`, after the prerequisites check block (after line 41, `> Run /qlik:setup first...`), add:

```markdown

**Auto-resume after setup:** If setup was triggered as a prerequisite for sync (i.e., the user's original intent was to sync), resume the sync automatically after setup completes. Do not ask the user to re-invoke `/qlik:sync`.
```

- [ ] **Step 4: Add Execution Notes section before Step 1**

In `skills/sync/SKILL.md`, insert before `## Step 1: Parse User Intent` (line 43):

```markdown
## Execution Notes

- Prep scripts (`sync-cloud-prep.sh`, `sync-onprem-prep.sh`) make multiple API calls and may take 30-60 seconds. Always use `timeout: 120000` on these Bash calls.
- App sync scripts (`sync-cloud-app.sh`, `sync-onprem-app.sh`) also involve network calls. Use `timeout: 120000`.
- Finalize script is local-only and fast — default timeout is fine.
- Prep scripts write output to `/tmp/qlik-sync-prep-<context>.json` with a 5-minute TTL cache. Re-runs within 5 minutes reuse cached API responses unless `--force` is passed.

```

- [ ] **Step 5: Update SKILL.md prep output paths**

Update the Bash commands in Step 3 that reference `/tmp/qlik-sync-prep.json` to use the tenant-keyed path. In the Cloud Tenant section:

```bash
bash ${CLAUDE_SKILL_ROOT}/scripts/sync-cloud-prep.sh [flags]
```

Remove the `> /tmp/qlik-sync-prep.json` redirect (the script now writes to cache internally). Read the output from the script's stdout, or from `/tmp/qlik-sync-prep-<context>.json`.

Same for the On-Prem Tenant section.

- [ ] **Step 6: Add Troubleshooting section at end of SKILL.md**

Append to `skills/sync/SKILL.md` after the Output Structure section:

```markdown
## Troubleshooting

- **Empty output from prep script**: The command may have been backgrounded by the harness. Re-run with explicit `timeout: 120000`. If `/tmp/qlik-sync-prep-<context>.json` exists and is recent, read it directly with `cat` instead of re-running the script.
- **Auth errors (401)**: Token may have expired. Suggest `qlik context login` to re-authenticate.
- **Network timeout**: Check VPN/proxy settings and verify the tenant URL is correct.
- **Partial sync failures**: Use `--force` with a specific `--id` to retry individual failed apps.
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bash tests/test-sync.sh`
Expected: All PASS

- [ ] **Step 8: Run full test suite**

Run: `just test`
Expected: All PASS

- [ ] **Step 9: Commit**

```bash
git add skills/sync/SKILL.md tests/test-sync.sh
git commit -m "docs(sync): add auto-resume, execution notes, and troubleshooting to skill"
git push
```

---

### Task 5: Developer E2E Verification Checklist

**Files:**
- Create: `tests/e2e/sync-e2e-checklist.md`

- [ ] **Step 1: Create the checklist file**

```markdown
# Sync E2E Verification Checklist

Run this checklist against a real Qlik Cloud tenant after making changes to sync scripts or skill instructions.

## Prerequisites

- [ ] A Qlik Cloud tenant with at least 2 apps in different spaces
- [ ] `qlik` CLI installed and authenticated (`qlik context ls` shows active context)
- [ ] Clean `.qlik-sync/` directory (delete if exists from prior runs)

## Checklist

### Setup → Sync Handoff
- [ ] **1. Start with no config** — delete `.qlik-sync/` if it exists
- [ ] **2. Say "sync my tenant X"** — agent should detect missing config and run setup automatically
- [ ] **3. Complete setup** — provide tenant URL and API key when prompted
- [ ] **4. Verify auto-resume** — after setup completes, sync should start without the agent asking you to re-invoke `/qlik:sync`
- [ ] Expected: Sync begins immediately after setup finishes

### Full Sync
- [ ] **5. Sync completes** — all apps pulled successfully
- [ ] **6. Check config** — `.qlik-sync/config.json` has `lastSync` timestamp updated
- [ ] **7. Check index** — `.qlik-sync/index.json` exists, entry count matches prep report
- [ ] **8. Spot-check app** — pick one app directory, verify `script.qvs` exists with valid content

### Resume (Skip Detection)
- [ ] **9. Re-run sync** — `/qlik:sync` without `--force`
- [ ] **10. Verify skips** — all apps should be marked "skip" with "already synced" reason
- [ ] Expected: No API calls to `qlik app unbuild`

### Force Re-sync
- [ ] **11. Force single app** — `/qlik:sync --force --id <app-id>`
- [ ] **12. Verify re-sync** — only the targeted app is re-synced, others untouched

### Prep Caching
- [ ] **13. Run prep twice** — run the prep script manually twice within 5 minutes
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
```

- [ ] **Step 2: Commit**

```bash
mkdir -p tests/e2e
git add tests/e2e/sync-e2e-checklist.md
git commit -m "docs(test): add developer e2e verification checklist for sync"
git push
```

---

### Task 6: Version Bump

**Files:**
- Modify: version file (check current location)

- [ ] **Step 1: Identify version location**

Check where version is defined — likely `README.md` or a manifest file. Current version is `0.2.0` per recent commit `c55b174`.

- [ ] **Step 2: Bump version**

Bump to `0.3.0` (new feature: caching).

- [ ] **Step 3: Commit**

```bash
git add <version-file>
git commit -m "chore(plugin): bump version to 0.3.0"
git push
```
