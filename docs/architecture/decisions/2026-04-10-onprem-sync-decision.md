# On-Prem Sync Decisions

## Decision 1: On-Prem Extraction Strategy

### Context
`qlik app unbuild` works via WebSocket to the Qlik Engine. On-prem engines are often behind firewalls/virtual proxies, making WebSocket unreliable. Need a reliable extraction method for on-prem apps.

### Options considered

1. **Try unbuild first, fall back to export + qlik-parser**
   - Pro: Full output when unbuild works
   - Con: Unpredictable failures, complex retry logic
   - **Rejected**

2. **Always export + qlik-parser for on-prem**
   - Pro: Reliable, uses QRS REST API (always available)
   - Pro: qlik-parser is purpose-built for QVF extraction
   - Con: Subset of data (no config.yml, connections.yml, objects/)
   - **Chosen**

3. **Always try unbuild for on-prem**
   - Pro: Same output as cloud
   - Con: Fails in locked-down networks
   - **Rejected**

### Decision
On-prem always uses export (via `qlik qrs app export create` + `qlik qrs download app get`) followed by `qlik-parser extract`. Produces script.qvs, measures.json, dimensions.json, variables.json. Subset output is an acceptable trade-off for reliability.

---

## Decision 2: Config Schema — Multi-Tenant

### Context
Need to support both cloud and on-prem tenants. Current config.json is single-tenant.

### Options considered

1. **Single-tenant config with type field**
   - Pro: Simple
   - Con: Can't sync multiple environments
   - **Rejected**

2. **Multi-tenant config — array of tenants**
   - Pro: Sync all tenants at once or filter by name
   - Pro: Directory structure already namespaces by tenant
   - **Chosen**

3. **One config per tenant in separate directories**
   - Pro: Full isolation
   - Con: Fragments the workspace, complicates index
   - **Rejected**

### Decision
Multi-tenant config with `tenants` array. Each tenant has `context`, `server`, `type`, `lastSync`. Version bumped to 0.2.0. Setup handles migration from old format.

---

## Decision 3: On-Prem Directory Structure

### Context
On-prem uses streams (publish targets) instead of spaces. No app types on-prem.

### Options considered

1. **Streams mapped to hierarchy: tenant/stream/stream-name/app/**
   - Pro: Mirrors on-prem mental model (streams = publish targets)
   - Pro: Unpublished → tenant/personal/owner-name/app/
   - **Chosen**

2. **Flat: tenant/published/stream-name/app/ and tenant/unpublished/owner/app/**
   - Pro: Simple
   - Con: Loses stream semantics
   - **Rejected**

3. **Unified vocabulary — normalize streams into space types**
   - Pro: Consistent with cloud
   - Con: Misleading — streams aren't spaces
   - **Rejected**

### Decision
On-prem: `tenant/stream/stream-name (stream-id)/app-name (app-id)/` for published apps, `tenant/personal/owner-name (user-id)/app-name (app-id)/` for unpublished. No app-type level.

---

## Decision 4: Tenant Type Detection

### Context
Need to determine whether a server is cloud or on-prem during setup.

### Options considered

1. **Ask tenant type explicitly**
   - Pro: Always correct
   - Con: Extra step
   - **Rejected**

2. **Auto-detect from URL, confirm with user**
   - Pro: `.qlikcloud.com` → cloud, else → on-prem. Simple heuristic.
   - Pro: User confirms, so misdetection is harmless
   - **Chosen**

3. **Read from qlik context server-type**
   - Pro: Uses existing config
   - Con: Not always set
   - **Rejected**

### Decision
Auto-detect from URL pattern, confirm with user.

---

## Decision 5: qlik-parser Dependency

### Context
qlik-parser is a Go binary only needed for on-prem. How to handle installation.

### Options considered

1. **Check PATH, guide if missing, fail sync if not found**
   - Pro: Simple, user controls installation
   - **Chosen**

2. **Auto-download from GitHub releases**
   - Pro: Seamless
   - Con: Network dependency, platform detection complexity
   - **Rejected**

3. **Bundle in devcontainer**
   - Pro: Always available
   - Con: Unnecessary for cloud-only users
   - **Rejected**

### Decision
Check `which qlik-parser` at sync time. If missing, error with link to releases page.

---

## Decision 6: Script Architecture

### Context
Need to support two different sync backends. PR #8 already splits sync into three phases (prep/app/finalize).

### Options considered

1. **Single script with branching**
   - Pro: One entry point
   - Con: Cloud and on-prem CLI commands differ fundamentally, tangled logic
   - **Rejected**

2. **Two script sets + shared lib**
   - Pro: Clean separation (sync-cloud-*.sh and sync-onprem-*.sh)
   - Pro: Shared helpers in sync-lib.sh (sanitize, index, config)
   - Pro: Independent testing with different mocks
   - Pro: Builds on PR #8 three-phase decomposition
   - **Chosen**

### Decision
Five scripts: sync-cloud-{prep,app}.sh, sync-onprem-{prep,app}.sh, and shared sync-finalize.sh, plus sync-lib.sh for shared helpers. Both prep scripts output identical JSON format so the skill loop and finalize are type-agnostic.
