# Sandbox Improvements Design

## Overview

Three improvements to the primer template repo's developer experience: justfile usability, git signing setup, and stale plugin cleanup.

## 1. Justfile: Default Help + Claude Recipe

### Current State

Running `just` with no arguments executes the first recipe (`setup-git`), which is destructive for someone just exploring.

### Changes

- Add a default recipe that runs `just --list` to show all available tasks with descriptions.
- Add a `claude` recipe that launches `claude --dangerously-skip-permissions`.

### Justfile After

```justfile
# Show available tasks
default:
    @just --list

# Run interactive GitHub auth + SSH signing setup
setup-git:
    ./scripts/setup-git.sh

# Launch Claude Code with all permissions
claude:
    claude --dangerously-skip-permissions

# Sync template from upstream
sync-template:
    ./scripts/sync-template.sh
```

## 2. setup-git.sh: Request Signing Scope Upfront

### Current State

`gh auth login` does not request the `admin:ssh_signing_key` scope. The subsequent `gh ssh-key add --type signing` fails unless the user manually refreshes the token.

### Change

Replace:

```bash
gh auth login
```

With:

```bash
gh auth login -h github.com -s admin:ssh_signing_key
```

This requests the signing scope during initial auth, eliminating the need for a separate refresh.

## 3. Clean Up Stale Primer Plugin Reference

### Current State

`~/.claude/settings.json` contains a `primer` entry in `extraKnownMarketplaces` from when primer was a plugin. This causes Claude Code to attempt resolving the primer marketplace on startup.

### Change

Remove the `primer` entry from `extraKnownMarketplaces` in `~/.claude/settings.json`.

**Note:** This is a user-scope change, not a project-scope change. It only applies to the current user's machine.
