# Plugin Repackaging ADR

## ADR-001: Plugin architecture — pure shell hook

- **Date:** 2026-04-01
- **Status:** accepted

### Context
Primer needs to scaffold files and install plugin dependencies on session start. Need to choose the implementation approach.

### Options Considered
- **Pure shell hook** — single bash script, mirrors superpowers pattern, no dependencies
- **Node.js script** — richer formatting, adds runtime dependency
- **Multi-hook architecture** — separate hooks per concern, more files to maintain

### Decision
Pure shell hook. It's the simplest approach, has no dependencies, and follows the same pattern as superpowers (which is already proven). Bash is sufficient for file copying, checksum comparison, and printing warnings.

### Consequences
- Hook logic lives in one file, easy to reason about
- Cross-platform support via `run-hook.cmd` polyglot wrapper (same as superpowers)
- If logic grows complex enough to warrant splitting, can refactor later

---

## ADR-002: Stale file detection — simple diff over manifest tracking

- **Date:** 2026-04-01
- **Status:** accepted

### Context
When template files are updated in a new plugin version, need to detect which project files are out of date and offer updates.

### Options Considered
- **Simple diff** — checksum template vs project, list all differences, user opts in to overwrite and reviews `git diff`
- **Manifest tracking** — store checksums at scaffold time, distinguish "user customized" from "template updated", only flag template updates

### Decision
Simple diff for v1. The user is reviewing `git diff` after any overwrite regardless, so distinguishing who changed the file adds complexity without meaningful benefit.

### Consequences
- Users may get warned about files they intentionally customized — acceptable noise for v1
- If this proves too noisy, manifest tracking can be added as a future enhancement
- No additional state files to manage

---

## ADR-003: .gitignore handling — smart append over scaffold-or-skip

- **Date:** 2026-04-01
- **Status:** accepted

### Context
`.gitignore` is unique among scaffolded files — projects almost always already have one, and it needs entries added rather than being replaced.

### Options Considered
- **Scaffold only if missing, warn otherwise** — same as other files, imperfect for existing projects
- **Don't scaffold, just warn** — check for required entries, output copy-paste snippet
- **Smart append** — check for each required entry, append missing ones under a `# primer` block

### Decision
Smart append. It's the correct behavior for an additive file. Entries are grouped under `# primer` for attribution and easy identification.

### Consequences
- Existing `.gitignore` files get entries appended non-destructively
- `# primer` comment block makes it clear which entries came from the plugin
- Only missing entries are appended — idempotent on repeated runs

---

## ADR-004: Plugin naming — primer

- **Date:** 2026-04-01
- **Status:** accepted

### Context
Needed a name for the repackaged claude-template plugin that conveys its purpose as a project bootstrapper.

### Options Considered
- **claude-kickstart / claude-bootstrap / claude-scaffold** — descriptive but generic, claude- prefix feels redundant in plugin context
- **bedrock / foundation** — evocative but heavy for a bootstrapper
- **primer** — "first coat that prepares the surface", clean and memorable

### Decision
Primer. It's short, evocative of preparation/bootstrapping, and doesn't use the `claude-` prefix.

### Consequences
- Repo renamed from `claude-template` to `primer` on GitHub
- Marketplace name: `primer`
- Plugin name: `primer`

---

## ADR-005: Scaffolding scope — .claude/ and docs/ only

- **Date:** 2026-04-01
- **Status:** accepted

### Context
Need to decide which files the plugin scaffolds into projects.

### Options Considered
- **Full scaffolding** — .claude/, docs/, README.md, .gitignore as a file
- **Minimal** — just .claude/rules/
- **.claude/ and docs/** — the convention structure without project-specific files like README

### Decision
Scaffold `.claude/` (settings, rules, skills/agents/commands gitkeeps) and `docs/superpowers/` (plans, specs, adr gitkeeps), plus `CLAUDE.md`. Handle `.gitignore` via smart-append separately.

### Consequences
- Projects get the full convention structure without opinionated project files
- `.gitignore` entries are appended rather than a template file being dropped in
- README and other project-specific files are the user's responsibility

---

## ADR-006: Existing file handling — never overwrite, warn about staleness

- **Date:** 2026-04-01
- **Status:** accepted

### Context
When a project already has files that primer would scaffold, need to decide whether to overwrite, skip, or warn.

### Options Considered
- **Never overwrite** — only create missing files, ignore existing ones entirely
- **Prompt/warn with opt-in overwrite** — flag stale files, let user overwrite and review git diff
- **Versioned sync** — track scaffold version, auto-update on plugin upgrade

### Decision
Warn about stale files, let the user explicitly opt in to overwriting via `PRIMER_UPDATE=1` env var, then review with `git diff`. Git is the safety net.

### Consequences
- No accidental overwrites of user customizations
- User has full control over when and what to update
- Simple UX: set env var, run session, review diff

---

## ADR-007: Early exit via committed version marker

- **Date:** 2026-04-01
- **Status:** accepted

### Context
The session-start hook runs on every session start. Walking template files and computing checksums on every session is wasteful when nothing has changed (99% of sessions).

### Options Considered
- **`.claude/.primer-version` committed** — shared across team, version check is a single file read, early exit on match
- **`.claude/.primer-version` gitignored** — per-developer, each person re-scaffolds independently
- **External cache (temp/home dir)** — outside project, not tied to repo state

### Decision
Committed `.claude/.primer-version`. When the plugin version matches the marker, the hook exits immediately. The marker is committed so the whole team benefits when one person updates primer.

### Consequences
- 99% of sessions: single file read then exit — near-zero overhead
- Plugin update triggers a full scaffold/check run, then writes the new version
- Version marker shows up in git history, making plugin updates visible in commits
