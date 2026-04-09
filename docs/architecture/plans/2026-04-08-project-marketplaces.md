# Project-Level Marketplace Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register codex and caveman plugin marketplaces at the project level so they survive devcontainer rebuilds.

**Architecture:** Add `extraKnownMarketplaces` to the existing `.claude/settings.json`. No new files, no scripts.

**Tech Stack:** JSON configuration

---

### Task 1: Add marketplace registrations to project settings

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Add `extraKnownMarketplaces` to `.claude/settings.json`**

Current content:

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "codex@openai-codex": true,
    "caveman@caveman": true
  }
}
```

Replace with:

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "codex@openai-codex": true,
    "caveman@caveman": true
  },
  "extraKnownMarketplaces": {
    "openai-codex": {
      "source": {
        "source": "github",
        "repo": "openai/codex-plugin-cc"
      }
    },
    "caveman": {
      "source": {
        "source": "github",
        "repo": "JuliusBrussee/caveman"
      }
    }
  }
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `python3 -m json.tool .claude/settings.json > /dev/null`
Expected: no output (valid JSON)

- [ ] **Step 3: Commit and push**

```bash
git add .claude/settings.json
git commit -m "fix(plugins): register codex and caveman marketplaces at project level"
git push
```
