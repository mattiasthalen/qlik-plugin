# qs setup + sync catch-up — decisions

## Decision 1: Scope of the catch-up

**Context:** qs 0.1.0 released with `qs setup` (interactive cloud + on-prem tenant configuration) and a `--stream` flag on `qs sync`. The plugin still drives setup manually via `qlik-cli` (~150 lines, cloud-only) and the sync skill tells users "qs does not yet support on-prem sync". Three catch-up scopes were considered.

**Options considered:**

- **A) Full catch-up (setup + sync)** *(chosen)* — Rewrite setup skill as `qs setup` wrapper and fix sync skill's on-prem wording + missing flag rows. Biggest drift reduction in one pass. Ship as v0.5.0.
- **B) Setup skill only** *(rejected)* — Leaves sync skill's stale on-prem claim in place. Two visits for the same user-facing area.
- **C) Sync skill only** *(rejected)* — Fastest, but leaves ~120 lines of duplicated setup drift and a second UX path (Claude-driven vs qs setup).
- **D) Just fix the stale claim** *(rejected)* — Minimum viable; does not justify a release.

**Decision:** Option A. Catch both skills up to qs 0.1.0 in a single v0.5.0 release.

## Decision 2: How thin should the setup skill become?

**Context:** `qs setup` already lists existing qlik contexts, prompts for name/URL/API key, detects cloud vs on-prem, creates the qlik context (with `--server-type Windows --insecure` for on-prem), tests connectivity (`qlik app ls` for cloud, `qlik qrs app count` for on-prem), and writes/updates `qlik/config.json` v0.2.0. It has no flags — it is fully interactive via stdin.

**Options considered:**

- **Pure wrapper** *(chosen)* — Skill runs `qs setup` and lets qs own the whole interactive flow. Plugin keeps only `which qs` prereq check, `.gitignore` append, and sync auto-resume. ~30 lines, down from ~150.
- **Wrapper + auth guidance** *(rejected)* — Keep API-key / OAuth walkthroughs as reference. Rejected because qs setup already prompts for an API key and reports its own errors; duplicating the walkthrough risks drift.
- **Hybrid (skill drives interactively)** *(rejected)* — Claude gathers inputs in chat and pipes them to `qs setup` via stdin heredoc. Rejected because qs setup has no flags, prompt order is unstable across qs versions, and piping stdin would break silently on any prompt change.

**Decision:** Pure wrapper. qs owns context creation, connectivity test, and config.json. Plugin owns `which qs`, `.gitignore`, and hand-offs.

## Decision 3: How should the sync skill handle on-prem?

**Context:** Verified by reading `qs` source at `cmd/sync.go:79-82`: `qs sync` explicitly skips tenants where `Type != "cloud"` with a warning "Skipping on-prem tenant %q (not yet supported)". The `--stream` flag is wired into filters but short-circuited upstream of execution. Cloud tenants in the same config continue to sync normally.

**Options considered:**

- **Minimal rewording + missing flag rows** *(chosen)* — Replace the stale "qs does not yet support on-prem sync" line with an accurate description of skip-with-warning behavior; add `--threads` and `--retries` rows to the intent table; leave `--stream` out of the table because exposing it would mislead users.
- **Restructure intent table by tenant type** *(rejected)* — Split into Cloud / On-prem sections. Rejected because on-prem has zero working flags today; the split would document a capability that doesn't exist.
- **Add dedicated on-prem troubleshooting section** *(rejected)* — Rejected for the same reason: no on-prem execution path to troubleshoot.

**Decision:** Minimal rewording + add `--threads`/`--retries` rows. Reassess when qs sync implements on-prem execution.

## Decision 4: Plugin version bump

**Context:** CLAUDE.md memory requires bumping plugin version before shipping. Current version is 0.4.1. Changes include a user-facing setup flow change (Claude no longer walks the user through qlik-cli manually; qs setup does it) and corrected sync skill documentation.

**Options considered:**

- **0.5.0 (minor)** *(chosen)* — The setup skill's user-facing flow changes materially, which is more than a patch. Aligns with the full-catch-up scope decision.
- **0.4.2 (patch)** *(rejected)* — Understates the setup skill rewrite.
- **1.0.0 (major)** *(rejected)* — Premature; the plugin's public contract (skill names, config.json format) is unchanged.

**Decision:** Bump to 0.5.0.

## Decision 5: Binary discovery order for `qs` and `qlik`

**Context:** Users may drop `qs.exe` / `qs` and `qlik.exe` / `qlik` next to their project instead of installing them globally, especially on Windows where adding to PATH is clunkier. A `which qs` prereq check only inspects PATH and would miss a project-local binary. `qs` itself calls `exec.Command("qlik", ...)` via Go's `LookPath`, which also searches PATH, so even if the skill finds a local `qs`, `qs` will fail to invoke `qlik` unless the project folder is prepended to `PATH` for the duration of the call.

**Options considered:**

- **Prefer local binary, fall back to PATH, prepend project folder to PATH for the call** *(chosen)* — Setup and sync skills probe for `./qs.exe`, then `./qs`, then a PATH-resident `qs`. Whichever is found is stored in a shell variable and invoked with `PATH="$PWD:$PATH"` so `qs` can pick up `qlik` / `qlik.exe` from the project folder too. Plugin stays a wrapper; no binary is bundled.
- **PATH only, document project-local as unsupported** *(rejected)* — Simplest skill, but breaks the drop-in-project workflow that Windows users commonly rely on.
- **PATH first, fall back to local binary** *(rejected)* — Inverts intent. If a user drops a local binary it is almost always because they want to pin a specific version; PATH-first would hide it.
- **Let `qs` handle it — skip the prereq check** *(rejected)* — Loses the install-link hint when the binary is missing and gives worse error messages.

**Decision:** Prefer local, then PATH, and always prepend `$PWD` to `PATH` when invoking `qs` so child `qlik` calls discover project-local binaries too. Apply to both setup and sync skills.
