# Parallel Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parallelize sync by dispatching multiple Claude Code agents, each syncing a batch of apps concurrently.

**Architecture:** Extend the sync skill's Step 4 (sequential loop) to dispatch up to 5 parallel agents. Each agent calls `sync-app.sh` for its batch of apps and returns a results JSON array. The skill collects results progressively, concatenates them, and calls `sync-finalize.sh` once. No new scripts — changes are SKILL.md + allowed-tools + tests only.

**Tech Stack:** Claude Code skills (SKILL.md), Agent tool, bash, jq

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `skills/sync/SKILL.md` | Modify | Add `Agent` to allowed-tools, replace sequential loop with parallel dispatch |
| `tests/test-sync.sh` | Modify | Add assertions for parallel sync instructions in SKILL.md |

---

### Task 1: Add parallel sync test assertions

**Files:**
- Modify: `tests/test-sync.sh:24-40`

- [ ] **Step 1: Write failing tests for parallel sync content in SKILL.md**

Add these assertions after the existing sync SKILL.md tests block (after line 38, before `test_summary`):

```bash
echo ""
echo "=== parallel sync tests ==="
assert_contains "mentions Agent in allowed-tools" "$SKILL_CONTENT" "Agent"
assert_contains "mentions batch splitting" "$SKILL_CONTENT" "min(nonSkipApps, 5)"
assert_contains "mentions distribution rule" "$SKILL_CONTENT" "floor"
assert_contains "mentions progressive reporting" "$SKILL_CONTENT" "Batch"
assert_contains "mentions zero non-skip handling" "$SKILL_CONTENT" "0 non-skip"
assert_contains "mentions results concatenation" "$SKILL_CONTENT" "concatenate"
assert_contains "mentions agent failure handling" "$SKILL_CONTENT" "agent failed"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test-sync.sh`
Expected: 7 FAIL (Agent, batch splitting, distribution, progressive reporting, zero non-skip, concatenation, agent failure — none exist in SKILL.md yet)

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/test-sync.sh
git commit -m "test(sync): add failing tests for parallel sync instructions"
git push
```

---

### Task 2: Add Agent to allowed-tools

**Files:**
- Modify: `skills/sync/SKILL.md:1-20` (frontmatter)

- [ ] **Step 1: Add Agent to allowed-tools in frontmatter**

Add `- Agent` to the `allowed-tools` list in the YAML frontmatter, after the existing entries:

```yaml
allowed-tools:
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-prep.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-app.sh:*)"
  - "Bash(bash ${CLAUDE_SKILL_ROOT}/scripts/sync-finalize.sh:*)"
  - "Bash(cat /tmp/qlik-sync-prep.json:*)"
  - "Bash(cat /tmp/qlik-sync-results.json:*)"
  - "Bash(echo:*)"
  - Bash(qlik app ls:*)
  - Bash(date:*)
  - Read
  - Write
  - Agent
```

- [ ] **Step 2: Run tests to verify Agent assertion passes**

Run: `bash tests/test-sync.sh`
Expected: "mentions Agent in allowed-tools" PASS. Other 6 parallel tests still FAIL.

- [ ] **Step 3: Commit**

```bash
git add skills/sync/SKILL.md
git commit -m "feat(sync): add Agent to allowed-tools for parallel dispatch"
git push
```

---

### Task 3: Replace sequential loop with parallel dispatch in SKILL.md

**Files:**
- Modify: `skills/sync/SKILL.md:72-87` (Step 4)

- [ ] **Step 1: Replace Step 4 content**

Replace the entire "## Step 4: Sync Loop with Progress" section with this parallel dispatch flow:

```markdown
## Step 4: Parallel Sync

### 4a: Report skips

For each app in the prep JSON where `skip` is `true`:
- Report `[N/Total] SKIP: <spaceType>/<spaceName> / <appName> (<skipReason>)`
- Append `{"resourceId": "<id>", "status": "skipped"}` to the results array

### 4b: Split into batches

Filter apps where `skip` is `false`. Calculate agent count: `min(nonSkipApps, 5)`.

Distribution: first N-1 batches get `floor(nonSkipApps / agents)` apps, last batch gets the rest.

If 0 non-skip apps remain, skip to Step 5 (finalize).

### 4c: Dispatch agents

Resolve `${CLAUDE_SKILL_ROOT}` to an absolute path. Report to user:
> Dispatching **N** parallel agents...

Spawn all agents simultaneously using the Agent tool. Each agent receives this prompt (fill in the values):

```
Sync batch {batchNumber} of {totalBatches} for parallel sync.

For each app in the list below, run:
  bash {resolvedSkillRoot}/scripts/sync-app.sh "{resourceId}" "{targetPath}"

After processing all apps, return a JSON array of results:
[
  {"resourceId": "app-001", "status": "synced"},
  {"resourceId": "app-002", "status": "error", "error": "unbuild failed: ..."}
]

Rules:
- Process apps sequentially within your batch
- On sync-app.sh failure (non-zero exit), mark status "error" with stderr as error message
- Continue to next app on failure — do not abort batch
- Return the complete results array when done

Apps to sync:
{JSON array of app objects for this batch}
```

### 4d: Collect results progressively

As each agent completes, parse its returned JSON results array and report:
> Batch **N**/**M** complete: **X** synced, **Y** errors

If an agent fails entirely (crash/timeout), mark all apps in that Batch as errors:
`{"resourceId": "<id>", "status": "error", "error": "agent failed"}`
Report: `Batch N/M FAILED: agent error`

### 4e: Concatenate results

After all agents complete, concatenate all agent result arrays with the skip results into a single results array. Write to `/tmp/qlik-sync-results.json`.
```

- [ ] **Step 2: Run tests to verify parallel assertions pass**

Run: `bash tests/test-sync.sh`
Expected: All 7 parallel sync assertions PASS. All previous assertions still PASS.

- [ ] **Step 3: Commit**

```bash
git add skills/sync/SKILL.md
git commit -m "feat(sync): replace sequential loop with parallel agent dispatch"
git push
```

---

### Task 4: Verify all tests pass and update PR

**Files:**
- None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `just test`
Expected: All tests pass across all test files.

- [ ] **Step 2: Commit any fixes if needed**

If any tests fail, fix and commit before proceeding.

- [ ] **Step 3: Update PR from draft to ready**

```bash
gh pr ready 10
```
