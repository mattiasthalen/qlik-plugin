# qs setup + sync catch-up implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Catch the plugin's setup and sync skills up to qs 0.1.0 — setup becomes a pure `qs setup` wrapper, sync gets accurate on-prem wording and `--threads` / `--retries` intent rows. Ship as v0.5.0.

**Architecture:** Two-skill refactor. Both skills stay thin wrappers around `qs`. Plugin retains only what qs does not own: prereq check, `.gitignore`, intent-table translation, and orchestration hand-offs. qs owns qlik context creation, cloud/on-prem detection, connectivity test, and `qlik/config.json` v0.2.0 read/write.

**Tech Stack:** Bash test suite (`just test` / `tests/*.sh`), Markdown skill files with YAML frontmatter, JSON plugin manifest.

**Reference:** `docs/architecture/specs/2026-04-15-qs-setup-catchup-design.md`

**Worktree:** `.worktrees/qs-setup-catchup` on branch `feat/qs-setup-catchup`. Draft PR #19.

---

## File Structure

Files this plan touches:

- **Create:** *(none)*
- **Modify:**
  - `.claude-plugin/plugin.json` — version bump 0.4.1 → 0.5.0
  - `skills/setup/SKILL.md` — rewrite as `qs setup` wrapper (~30 lines body)
  - `skills/sync/SKILL.md` — four surgical edits (on-prem wording, two intent rows, command template)
  - `tests/test-setup.sh` — drop obsolete assertions, add new ones
  - `tests/test-sync.sh` — add assertions for new flags and wording

No file splits. All files in this plan have a single responsibility and stay focused.

---

## Task 1: Bump plugin version to 0.5.0

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `tests/test-setup.sh:12`

- [ ] **Step 1: Update the version assertion in tests/test-setup.sh**

Edit `tests/test-setup.sh` line 12. Change:

```bash
assert_json_field "plugin version is 0.4.1" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.4.1"
```

to:

```bash
assert_json_field "plugin version is 0.5.0" "$REPO_ROOT/.claude-plugin/plugin.json" ".version" "0.5.0"
```

- [ ] **Step 2: Run test to verify it fails**

Run from the worktree root:

```bash
bash tests/test-setup.sh
```

Expected: FAIL on `plugin version is 0.5.0` because `plugin.json` still reads `0.4.1`. Other assertions may also fail later in the file — that's expected and will be fixed in Task 2. The version assertion is the one that must fail here.

- [ ] **Step 3: Update .claude-plugin/plugin.json**

Edit `.claude-plugin/plugin.json`. Change:

```json
"version": "0.4.1",
```

to:

```json
"version": "0.5.0",
```

Leave every other field untouched.

- [ ] **Step 4: Run test to verify version assertion passes**

Run:

```bash
bash tests/test-setup.sh 2>&1 | grep "version is 0.5.0"
```

Expected: `PASS: plugin version is 0.5.0`

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json tests/test-setup.sh
git commit -m "chore(plugin): bump version to 0.5.0"
git push
```

---

## Task 2: Rewrite setup skill as `qs setup` wrapper

**Files:**
- Modify: `tests/test-setup.sh:34-50` (content assertions)
- Modify: `skills/setup/SKILL.md` (full rewrite of body)

### Step group A — tests first

- [ ] **Step 1: Update content assertions in tests/test-setup.sh**

Replace lines 32–50 of `tests/test-setup.sh` (everything from the `# Content checks —` comment down to the blank line before `test_summary`). Old block:

```bash
# Content checks — skill should teach these key behaviors
CONTENT=$(cat "$SETUP_SKILL")
assert_contains "mentions qlik prerequisite" "$CONTENT" "which qlik"
assert_contains "mentions qs prerequisite" "$CONTENT" "which qs"
assert_contains "mentions context create" "$CONTENT" "qlik context create"
assert_contains "mentions context login" "$CONTENT" "qlik context login"
assert_contains "mentions connectivity test" "$CONTENT" "qlik app ls"
assert_contains "mentions qlik directory" "$CONTENT" "qlik/"
assert_contains "mentions config.json" "$CONTENT" "config.json"
assert_contains "mentions .gitignore" "$CONTENT" ".gitignore"

# Multi-tenant config check (cloud-only)
assert_contains "mentions multi-tenant config" "$CONTENT" "tenants"

# v0.1.0 migration must set type field
assert_contains "migration sets type cloud" "$CONTENT" 'type.*cloud'

# v0.2.0 append must not modify existing tenants
assert_contains "append preserves existing tenants" "$CONTENT" "do not modify existing tenants"
```

New block:

```bash
# Content checks — skill delegates to qs setup and keeps only prereqs + .gitignore + hand-off
CONTENT=$(cat "$SETUP_SKILL")
assert_contains "probes local qs.exe" "$CONTENT" "./qs.exe"
assert_contains "probes local qs" "$CONTENT" "./qs"
assert_contains "falls back to PATH" "$CONTENT" "command -v qs"
assert_contains "prepends PWD to PATH" "$CONTENT" 'PATH="$PWD:$PATH"'
assert_contains "delegates to qs setup" "$CONTENT" "qs setup"
assert_contains "mentions qlik directory" "$CONTENT" "qlik/"
assert_contains "mentions config.json" "$CONTENT" "config.json"
assert_contains "mentions .gitignore" "$CONTENT" ".gitignore"
assert_contains "mentions auto-resume to sync" "$CONTENT" "sync"

# Negative assertions — old manual flow must be gone
if echo "$CONTENT" | grep -q "qlik context create"; then
  echo "  FAIL: should not drive qlik context create manually"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not drive qlik context create manually"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$CONTENT" | grep -q "qlik context login"; then
  echo "  FAIL: should not mention qlik context login"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not mention qlik context login"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

if echo "$CONTENT" | grep -q "qlik app ls"; then
  echo "  FAIL: should not run qlik app ls directly"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: does not run qlik app ls directly"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
```

- [ ] **Step 2: Run test to verify content assertions fail**

Run:

```bash
bash tests/test-setup.sh
```

Expected: FAIL. Old skill still contains `qlik context create`, `qlik context login`, `qlik app ls`, and does not contain `delegates to qs setup`. The `does not drive qlik context create manually` negative assertion and others will FAIL. Capture: `Results: N failed` line shows at least 3 failures.

### Step group B — implementation

- [ ] **Step 3: Rewrite skills/setup/SKILL.md**

Replace the entire file with:

````markdown
---
name: setup
description: >
  Use when the user says "set up qlik", "configure qlik", "connect to
  my qlik tenant", or wants to connect Claude to their Qlik tenant.
  Also use when a qs setup run fails or tenant connection needs
  troubleshooting.
allowed-tools:
  - Bash(command:*)
  - Bash(test:*)
  - Bash(qs setup:*)
  - Bash(./qs setup:*)
  - Bash(./qs.exe setup:*)
  - Bash(grep:*)
  - Read
  - Write
---

# Qlik Setup

Configure a Qlik tenant connection so Claude can sync and inspect apps locally. This skill is a thin wrapper around `qs setup`, which owns the interactive flow (context creation, cloud/on-prem detection, connectivity test, and `qlik/config.json` writes).

## Step 1: Locate qs

Probe for a `qs` binary in priority order — project-local first, then PATH — and prepend the project directory to `PATH` so a project-local `qlik` / `qlik.exe` is also discoverable when `qs` shells out:

```bash
if [ -x ./qs.exe ]; then
  QS=./qs.exe
elif [ -x ./qs ]; then
  QS=./qs
elif command -v qs > /dev/null 2>&1; then
  QS=qs
else
  echo "qs not found." >&2
  echo "Install from https://github.com/mattiasthalen/qlik-sync/releases or drop qs / qs.exe next to this project." >&2
  exit 1
fi
export PATH="$PWD:$PATH"
```

If the probe fails, stop and wait for the user to install `qs` (or drop it into the project folder) before continuing. `qs setup` checks for `qlik-cli` internally and reports its own error if it is also missing.

## Step 2: Run qs setup

Run `qs setup` in the foreground so the user can answer its prompts directly in their terminal:

```bash
"$QS" setup
```

`qs setup` will:

- List existing qlik contexts
- Prompt for a context name and server URL
- Detect cloud vs on-prem from the URL
- Prompt for an API key if the context does not already exist
- Create the qlik context (with `--server-type Windows --insecure` for on-prem)
- Set the context active
- Run a connectivity test (`qlik app ls --limit 1` for cloud, `qlik qrs app count` for on-prem)
- Write or update `qlik/config.json` in v0.2.0 format (appending to `tenants`, preserving existing entries)

Do not pipe stdin. Let the user interact with `qs setup` directly.

## Step 3: Verify

After `qs setup` exits 0, read `qlik/config.json` and report the tenant list to the user:

> Setup complete. Configured tenants: `<context-name-1>`, `<context-name-2>`, ...

If `qs setup` exits non-zero, surface its stderr verbatim and suggest common causes:

- API key expired → regenerate at `https://<tenant-url>/settings/api-keys`
- Wrong tenant URL → re-run `qs setup` with the correct URL
- Network error → check VPN, proxy, and that the tenant URL is reachable

## Step 4: Update .gitignore

Check whether `qlik/` is already ignored:

```bash
grep -q 'qlik/' .gitignore 2>/dev/null
```

If the grep exits non-zero, append it:

```bash
echo 'qlik/' >> .gitignore
```

The `qlik/` directory contains connection context references and should not be committed.

## Step 5: Auto-resume to sync

If setup was triggered as a prerequisite for sync (the user's original intent was to sync), invoke the `sync` skill automatically after this step completes. Do not ask the user to re-invoke `/qlik:sync`.

## Done

Report to the user:
> Qlik setup complete. Your workspace is ready at `qlik/`. Run `/qlik:sync` to pull apps from your tenant.
````

- [ ] **Step 4: Run test to verify assertions pass**

Run:

```bash
bash tests/test-setup.sh
```

Expected: `Results: N/N passed, 0 failed` — all assertions including the negative ones pass.

- [ ] **Step 5: Commit**

```bash
git add skills/setup/SKILL.md tests/test-setup.sh
git commit -m "feat(setup): rewrite skill as thin qs setup wrapper"
git push
```

---

## Task 3: Fix sync skill wording, add missing flag rows, and add binary discovery

**Files:**
- Modify: `tests/test-sync.sh` (add assertions)
- Modify: `skills/sync/SKILL.md` frontmatter (`allowed-tools`)
- Modify: `skills/sync/SKILL.md` Prerequisites section (binary discovery)
- Modify: `skills/sync/SKILL.md` intent table + Step 2 command template
- Modify: `skills/sync/SKILL.md` Troubleshooting section (on-prem line)

### Step group A — tests first

- [ ] **Step 1: Add assertions to tests/test-sync.sh**

Edit `tests/test-sync.sh`. Find the block ending at line 28 with `assert_contains "mentions force flag" "$SKILL_CONTENT" "\-\-force"`. Immediately after that line, add:

```bash
assert_contains "mentions threads flag" "$SKILL_CONTENT" "\-\-threads"
assert_contains "mentions retries flag" "$SKILL_CONTENT" "\-\-retries"

# Binary discovery — project-local first, PATH fallback, $PWD prepended
assert_contains "probes local qs.exe" "$SKILL_CONTENT" "./qs.exe"
assert_contains "falls back to PATH" "$SKILL_CONTENT" "command -v qs"
assert_contains "prepends PWD to PATH" "$SKILL_CONTENT" 'PATH="$PWD:$PATH"'

# On-prem wording must reflect current qs behaviour (skip-with-warning, cloud continues)
assert_contains "mentions on-prem skip warning" "$SKILL_CONTENT" "Skipping on-prem tenant"
assert_contains "mentions cloud continues to sync" "$SKILL_CONTENT" "cloud tenants in the same config continue to sync"

# Stale wording must be gone
if echo "$SKILL_CONTENT" | grep -q "qs does not yet support on-prem sync"; then
  echo "  FAIL: stale on-prem wording still present"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  echo "  PASS: stale on-prem wording removed"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
```

- [ ] **Step 2: Run test to verify new assertions fail**

Run:

```bash
bash tests/test-sync.sh
```

Expected: FAIL. Current skill does not mention `--threads`, `--retries`, binary discovery, or the new on-prem wording, and still contains `qs does not yet support on-prem sync`. At least 7 assertions fail.

### Step group B — implementation

- [ ] **Step 3a: Update frontmatter allow-list in skills/sync/SKILL.md**

Open `skills/sync/SKILL.md`. In the frontmatter, replace the current `allowed-tools` block:

```yaml
allowed-tools:
  - Bash(qs sync:*)
  - Bash(qs version:*)
  - Bash(which:*)
  - Read
```

with:

```yaml
allowed-tools:
  - Bash(command:*)
  - Bash(test:*)
  - Bash(qs sync:*)
  - Bash(./qs sync:*)
  - Bash(./qs.exe sync:*)
  - Bash(qs version:*)
  - Read
```

- [ ] **Step 3b: Replace the Prerequisites section in skills/sync/SKILL.md**

Find the Prerequisites section. Current body (roughly lines 21–37):

```markdown
## Prerequisites

Check that `qs` is installed:

\`\`\`bash
which qs
\`\`\`

If missing, tell the user:
> Install qs from https://github.com/mattiasthalen/qlik-sync/releases and make sure `qs` is on your PATH.

Stop and wait for the user to install `qs` before continuing.

Check that `qlik/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik Cloud connection.

**Auto-resume after setup:** ...
```

Replace the `which qs` block and the "Install qs from..." message with the binary-discovery snippet:

```markdown
## Prerequisites

Probe for a `qs` binary in priority order — project-local first, then PATH — and prepend the project directory to `PATH` so a project-local `qlik` / `qlik.exe` is also discoverable when `qs` shells out:

\`\`\`bash
if [ -x ./qs.exe ]; then
  QS=./qs.exe
elif [ -x ./qs ]; then
  QS=./qs
elif command -v qs > /dev/null 2>&1; then
  QS=qs
else
  echo "qs not found." >&2
  echo "Install from https://github.com/mattiasthalen/qlik-sync/releases or drop qs / qs.exe next to this project." >&2
  exit 1
fi
export PATH="$PWD:$PATH"
\`\`\`

If the probe fails, stop and wait for the user to install `qs` (or drop it next to the project) before continuing.

Check that `qlik/config.json` exists. If not, tell the user:
> Run `/qlik:setup` first to configure your Qlik tenant.

**Auto-resume after setup:** unchanged — keep the existing paragraph.
```

(Leave the existing auto-resume paragraph in place; only the probe block and the install-link wording change.)

- [ ] **Step 4: Update the intent table in skills/sync/SKILL.md**

Open `skills/sync/SKILL.md`. Find the intent table (starts around line 42, header `| User says | Flags |`). The existing rows end with:

```
| "sync my-cloud tenant" | `--tenant "context-name"` |
```

Add these two rows immediately after, before the "Flags can be combined" line:

```
| "use 10 threads" / "more parallelism" | `--threads 10` |
| "retry 5 times" / "more retries" | `--retries 5` |
```

- [ ] **Step 5: Update the command template in Step 2 of skills/sync/SKILL.md**

Find the code block around line 55–57:

```bash
qs sync [--space "..."] [--app "..."] [--id "..."] [--tenant "..."] [--force]
```

Replace with:

```bash
"$QS" sync [--space "..."] [--app "..."] [--id "..."] [--tenant "..."] [--threads N] [--retries N] [--force]
```

- [ ] **Step 6: Update the on-prem troubleshooting line in skills/sync/SKILL.md**

Find the Troubleshooting section. Current text:

```
- **"Skipping on-prem tenant"** → `qs` does not yet support on-prem sync. Cloud tenants work normally.
```

Replace with:

```
- **"Skipping on-prem tenant"** → `qs sync` currently skips on-prem tenants with a warning; cloud tenants in the same config continue to sync normally. On-prem sync is on the qs roadmap.
```

- [ ] **Step 7: Run test to verify assertions pass**

Run:

```bash
bash tests/test-sync.sh
```

Expected: `Results: N/N passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
git add skills/sync/SKILL.md tests/test-sync.sh
git commit -m "fix(sync): binary discovery, on-prem wording, threads/retries rows"
git push
```

---

## Task 4: Full suite verification

**Files:** *(no edits; verification only)*

- [ ] **Step 1: Run the full test suite**

```bash
just test
```

Expected: every test file reports `Results: N/N passed, 0 failed`. No section reports failures.

- [ ] **Step 2: If anything fails, fix inline**

If `test-setup.sh`, `test-sync.sh`, `test-inspect.sh`, or `test-project.sh` reports a failure, read the failing assertion, locate the offending file, fix it, re-run `just test`. Do not proceed until the full suite is green.

- [ ] **Step 3: Commit any fixes (if needed)**

```bash
git add <fixed-files>
git commit -m "fix: address test suite regression from catch-up"
git push
```

If step 1 was already green, skip this step — no empty commit.

---

## Task 5: Manual verification in devcontainer

**Files:** *(no edits; smoke test only; results are recorded in the PR checklist, not committed)*

- [ ] **Step 1: Fresh setup flow — cloud tenant**

From a clean state (no `qlik/` directory):

```bash
rm -rf qlik
```

Invoke the setup skill as the user would (e.g. via `/qlik:setup`). Answer `qs setup`'s prompts with a cloud tenant URL and a real API key. Expected outcome:

- `qlik/config.json` exists, schema version `0.2.0`, one entry in `tenants` with `"type": "cloud"` and `"lastSync": null`
- `.gitignore` contains exactly one `qlik/` line
- The skill reports the configured tenant back to the user

- [ ] **Step 2: Re-run setup over existing config**

Invoke the setup skill again. Answer `qs setup` with the same context name. Expected outcome:

- `qlik/config.json` still has exactly one entry for that context (no duplicate tenants)
- `.gitignore` still contains exactly one `qlik/` line (no duplicate lines)

- [ ] **Step 3: Cloud sync unchanged**

Invoke the sync skill (e.g. `/qlik:sync`). Expected outcome:

- `qs sync` runs, cloud tenant pulls normally
- Exit code 0, apps land under `qlik/<tenant>/<space>/analytics/<app>/`
- Skill reports `Sync complete. Run /qlik:inspect to explore your apps.`

- [ ] **Step 4: (Optional) On-prem skip warning**

If an on-prem tenant URL is available, invoke `/qlik:setup` with it. Verify `qs setup` reports `Detected tenant type: on-prem`, creates the qlik context, and writes the tenant entry with `"type": "on-prem"` to `qlik/config.json`. Then invoke `/qlik:sync`. Expected:

- `qs sync` prints `Skipping on-prem tenant "<name>" (not yet supported)`
- Any cloud tenants in the same config still sync
- Skill's troubleshooting section matches the observed behaviour

- [ ] **Step 5: Mark the PR ready for review**

Once manual verification is green, update PR #19:

```bash
gh pr ready 19
```

If any manual step fails, do NOT mark ready — leave the PR as draft, fix the underlying issue (create a new sub-task in this plan if needed), re-run, and only then mark ready.

---

## Done criteria

- `.claude-plugin/plugin.json` version is `0.5.0`
- `skills/setup/SKILL.md` probes `./qs.exe` → `./qs` → PATH, prepends `$PWD` to `PATH`, and runs `"$QS" setup`; contains no manual `qlik context create` / `qlik context login` / `qlik app ls` drive
- `skills/sync/SKILL.md` uses the same binary-discovery snippet and invokes `"$QS" sync`; intent table includes `--threads` and `--retries` rows; troubleshooting wording matches the updated on-prem line
- `tests/test-setup.sh` and `tests/test-sync.sh` assertions updated to match (including binary-discovery probes)
- `just test` is green
- Manual verification Steps 1–3 in Task 5 pass (Step 4 optional)
- Draft PR #19 marked ready
