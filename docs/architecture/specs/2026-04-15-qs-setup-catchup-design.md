# qs setup + sync catch-up — design

## Goal

Catch the plugin's `setup` and `sync` skills up to `qs` 0.1.0 so the plugin delegates all tenant configuration to `qs setup` and stops asserting that `qs` lacks on-prem support. Ship as plugin v0.5.0.

## Context

`qs` 0.1.0 introduced `qs setup`, an interactive command that lists existing qlik contexts, prompts for name / server URL / API key, auto-detects cloud vs on-prem from the URL, creates the qlik context (passing `--server-type Windows --insecure` for on-prem), sets it active, runs a connectivity test (`qlik app ls --limit 1` for cloud, `qlik qrs app count` for on-prem), and writes or updates `qlik/config.json` in v0.2.0 format. Source verified at `/tmp/qlik-sync/cmd/setup.go`.

`qs sync` 0.1.0 accepts `--stream`, `--threads`, `--retries`, `--tenant`, `--force`, `--space`, `--app`, and `--id`. However, `cmd/sync.go:79-82` short-circuits any tenant whose `Type != "cloud"` with the message `Skipping on-prem tenant %q (not yet supported)`. Cloud tenants in the same config continue to sync normally. The `--stream` flag is wired into filter structs but execution never runs for on-prem tenants.

Today the plugin's `setup` skill (~150 lines) drives all of this manually: prereq checks, `qlik context ls` parsing, context creation (cloud-only, API-key or OAuth walkthrough), connectivity test, `mkdir -p qlik`, `qlik/config.json` v0.1.0 → v0.2.0 migration, and `.gitignore` append. The plugin's `sync` skill tells users `qs does not yet support on-prem sync`, which was true in 0.0.x but is now inaccurate (qs setup supports on-prem config, qs sync skips with a warning).

## Non-goals

- Implementing on-prem sync execution. That remains on the `qs` roadmap.
- Exposing the `--stream` flag in the sync skill's intent table. Flag is a no-op today.
- Restructuring the sync skill's intent table. Only additive edits.
- Changing `qlik/config.json` schema. `qs setup` already owns v0.2.0.
- Changing the `inspect` skill.

## Architecture

Two-skill refactor. Both skills remain thin wrappers around `qs`:

```
skills/setup/SKILL.md   ──► runs `qs setup`   (was: manual qlik context flow, ~150 lines)
skills/sync/SKILL.md    ──► runs `qs sync`    (existing wrapper; fix stale on-prem claim + flag gaps)
skills/inspect/SKILL.md ──► unchanged
```

Plugin owns only what `qs` does not:

- Binary discovery — find `qs` (and indirectly `qlik`) whether they sit on `PATH` or next to the project.
- `.gitignore` append — `qs setup` writes to `qlik/config.json` but does not touch git.
- Natural-language → `qs sync` flag translation — the intent table stays in the sync skill.
- Orchestration hand-offs — if the user's original intent was to sync and setup ran as a prereq, auto-resume the sync after setup returns.

`qs` owns: qlik context creation, cloud/on-prem detection, connectivity test, `qlik/config.json` read / write / migrate.

### Binary discovery

Both skills use the same shell snippet to pick a `qs` binary and prepare the environment:

```bash
if [ -x ./qs.exe ]; then
  QS=./qs.exe
elif [ -x ./qs ]; then
  QS=./qs
elif command -v qs > /dev/null 2>&1; then
  QS=qs
else
  echo "qs not found. Install from https://github.com/mattiasthalen/qlik-sync/releases or drop qs / qs.exe next to this project." >&2
  exit 1
fi
export PATH="$PWD:$PATH"
```

Order: local Windows binary, then local Unix binary, then anything on `PATH`. The `export PATH="$PWD:$PATH"` matters because `qs` invokes `qlik` / `qlik.exe` via Go's `exec.LookPath`, which only searches `PATH`. Prepending `$PWD` lets `qs` pick up a project-local `qlik` binary the same way the skill picks up a project-local `qs`.

Skills then invoke `"$QS" setup` or `"$QS" sync ...` — never a bare `qs`. The snippet lives at the top of both skill bodies so the read-through is obvious.

## Components

### 1. `skills/setup/SKILL.md` (rewrite)

Target length ~40 lines of body plus frontmatter. Flow:

1. **Prereqs and binary discovery.** Run the binary-discovery snippet (see Architecture → Binary discovery). If no `qs` is found locally or on PATH, tell the user to install from `https://github.com/mattiasthalen/qlik-sync/releases` or drop the binary next to the project, and stop. Do not check for `qlik` separately — `qs setup` does it internally and reports its own error, and the snippet already prepends `$PWD` to `PATH` so a project-local `qlik` is discoverable.
2. **Run `qs setup`.** Execute `"$QS" setup` in the foreground so the user can answer its interactive prompts directly in their terminal. Claude does not pipe stdin.
3. **Verify.** After `qs setup` exits 0, read `qlik/config.json` and report the tenant list to the user.
4. **`.gitignore`.** Run `grep -q 'qlik/' .gitignore`. If absent, append `qlik/`.
5. **Auto-resume.** If the user's original intent was to sync and setup ran as a prereq, invoke the sync skill.
6. **Failure path.** If `qs setup` exits non-zero, surface its stderr verbatim and suggest common causes: API key expired, wrong URL, network error.

Dropped from the old skill: API-key auth walkthrough, OAuth alt, `qlik context ls` table parsing, context-reuse question, `qlik/config.json` v0.1.0 → v0.2.0 migration logic, `mkdir -p qlik`, cloud-only restriction, Step 4 connectivity test, Step 5 config writing.

**Frontmatter `allowed-tools`:**

```yaml
allowed-tools:
  - Bash(command:*)
  - Bash(test:*)
  - Bash(qs setup:*)
  - Bash(./qs setup:*)
  - Bash(./qs.exe setup:*)
  - Bash(grep:*)
  - Read
  - Write
```

Drops from current allow-list: `Bash(which:*)`, `Bash(qlik context:*)`, `Bash(qlik app ls:*)`, `Bash(qlik version:*)`, `Bash(mkdir:*)`. Adds `Bash(command:*)` (portable replacement for `which`) and `Bash(./qs setup:*)` / `Bash(./qs.exe setup:*)` for project-local binaries.

**Frontmatter `description`:** keep the existing phrasing ("Use when the user says 'set up qlik', …") but drop the Qlik-Cloud-specific language. Generic wording covers both cloud and on-prem.

### 2. `skills/sync/SKILL.md` (surgical edits)

Five in-place edits plus an allow-list tweak, no restructure:

**Edit 0 — prereq section.** Replace the current `which qs` block with the binary-discovery snippet from Architecture → Binary discovery. Store the chosen binary in `$QS` and prepend `$PWD` to `PATH`. Subsequent `qs sync` invocations in the skill body use `"$QS" sync ...`.

**Edit 0b — `allowed-tools`.** Add `Bash(./qs sync:*)` and `Bash(./qs.exe sync:*)` alongside the existing `Bash(qs sync:*)`. Add `Bash(command:*)` and `Bash(test:*)`. Drop `Bash(which:*)`.


**Edit A — line 84 (troubleshooting entry).** Replace:

```
- "Skipping on-prem tenant" → qs does not yet support on-prem sync. Cloud tenants work normally.
```

with:

```
- "Skipping on-prem tenant" → qs sync currently skips on-prem tenants with a warning; cloud tenants in the same config continue to sync normally. On-prem sync is on the qs roadmap.
```

**Edit B — intent table (Step 1).** Add two rows after the existing rows:

```
| "use 10 threads" / "more parallelism"  | --threads 10    |
| "retry 5 times" / "more retries"       | --retries 5     |
```

**Edit C — `--stream` stays out of the intent table.** Do not add a row. `qs` parses the flag but skips on-prem execution, so exposing it would mislead users.

**Edit D — Step 2 command template.** Update the command line to use `$QS` and mention the new flags:

```bash
"$QS" sync [--space "..."] [--app "..."] [--id "..."] [--tenant "..."] [--threads N] [--retries N] [--force]
```

Leave exit-code handling and the output-structure section unchanged.

### 3. `.claude-plugin/plugin.json`

- `version`: `0.4.1` → `0.5.0`.
- `description`: leave unchanged. The description says "cloud apps"; sync execution is still cloud-only, so the copy is still accurate.

### 4. `README.md`

Scan for any language that duplicates the old setup-skill walkthrough (manual `qlik context create`, API-key generation URL). If present, replace with a pointer to `qs setup`. If absent, no change.

## Data flow

Setup (new):

```
user → /qlik:setup
      → skill: which qs
      → skill: qs setup           (interactive, stdin/stdout through user's terminal)
           → qs: CheckPrerequisites (checks qlik)
           → qs: qlik context ls
           → qs: prompt name / URL / API key
           → qs: DetectTenantType(URL)
           → qs: qlik context create [+ --server-type/--insecure for on-prem]
           → qs: qlik context use <name>
           → qs: connectivity test
           → qs: write qlik/config.json v0.2.0
      → skill: read qlik/config.json, report tenants
      → skill: grep + append qlik/ to .gitignore
      → skill: if sync was the intent, invoke sync skill
```

Sync (unchanged execution, updated wording):

```
user → /qlik:sync <natural language>
      → skill: which qs
      → skill: read qlik/config.json
      → skill: translate intent → flags (now includes --threads, --retries)
      → skill: qs sync [flags]
           → qs: prep tenants, skip on-prem with warning
           → qs: parallel cloud sync
      → skill: report exit code, troubleshoot if needed (updated on-prem wording)
```

## Error handling

- **`qs` missing.** Setup and sync skills stop with an install-or-drop-locally hint before running `qs setup` / `qs sync`. The hint points at the releases page and mentions the project-local fallback.
- **`qlik` missing.** `qs setup` internally calls `CheckPrerequisites()` for `qlik` and prints its own error. Because the plugin already prepended `$PWD` to `PATH`, a project-local `qlik` / `qlik.exe` is picked up automatically. No plugin-side check for `qlik`.
- **`qs setup` non-zero exit.** Surface stderr verbatim. Do not second-guess `qs`'s error message. Suggest: regenerate API key, verify tenant URL, check network / VPN / proxy.
- **`qlik/config.json` missing after `qs setup` 0-exit.** Should be impossible (`qs setup` writes it before returning 0). If it happens, report as a bug in `qs`, do not attempt to write config.json from the plugin.
- **`.gitignore` missing.** Create it with a single `qlik/` line.
- **Sync skill on-prem-only config.** `qs sync` prints the skip warning for every tenant and exits with a summary. Current skill already handles this via the troubleshooting line; only wording changes.

## Test plan

No new automated tests. The wrapper adds no logic worth testing beyond what `qs`'s own tests already cover.

**Existing test suite (`just test`):**

- `tests/test-setup.sh` asserts setup-skill content: must be updated to reflect the new flow (drop assertions about API-key walkthrough, add assertion for `qs setup` invocation + `.gitignore` append).
- `tests/test-sync.sh` asserts sync-skill content: must be updated to reflect the new troubleshooting wording and the two new intent-table rows.
- `tests/test-inspect.sh` and `tests/test-project.sh` unchanged.

**Manual verification in devcontainer:**

1. Fresh state: delete `qlik/`, run `/qlik:setup`, answer `qs setup` prompts for a cloud tenant, verify `qlik/config.json` v0.2.0 and `.gitignore` contain `qlik/`.
2. Re-run `/qlik:setup` over existing config, choose the same context, verify no duplicate tenant entries and `.gitignore` still has exactly one `qlik/` line.
3. Run `/qlik:sync` against the cloud tenant, verify unchanged behavior.
4. (Optional) Run `/qlik:setup` with an on-prem URL to confirm `qs setup` detects on-prem and stores the entry. Run `/qlik:sync`, verify the sync skill reports the "Skipping on-prem tenant" warning and cloud tenants still sync (if any are configured).

## Risks and trade-offs

- **Coupling to `qs` prompt order.** The pure-wrapper decision means the plugin cannot parse `qs setup` output to drive logic. Any post-step that depends on `qs setup`'s prompts is fragile. Mitigation: the plugin only reads `qlik/config.json` after `qs setup` returns 0, not the stdout stream.
- **Drift between plugin and `qs` versions.** If `qs` changes its `qlik/config.json` schema (e.g. v0.3.0), the plugin's Read step must keep up. Mitigation: read only the `tenants` array; fail soft if shape is unexpected.
- **Loss of plugin-level tenant URL validation.** The old skill validated URLs before calling `qlik context create`. `qs setup` owns this now; any URL errors surface through `qs` stderr.
- **On-prem expectations.** Users who set up an on-prem tenant may expect `/qlik:sync` to work. The updated troubleshooting line is the only signal. Acceptable until `qs` implements on-prem sync.

## Rollout

1. Update skill files and plugin.json on `feat/qs-setup-catchup` (this branch).
2. Update `tests/test-setup.sh` and `tests/test-sync.sh` to match new content.
3. Run `just test`, confirm green.
4. Manual verification in devcontainer (steps 1–3 above).
5. Mark PR ready for review.
