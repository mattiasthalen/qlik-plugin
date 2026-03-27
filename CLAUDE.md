# Rules

- NEVER write rules as "do X". Always phrase rules as "NEVER do Y" to clearly define what to avoid.

# Git Workflow

- NEVER commit directly to main.
- NEVER use non-conventional commit formats. See .claude/rules/conventional-commits.md
- NEVER leave commits unpushed.
- NEVER use raw git for remote operations when a CLI is available for the remote platform (e.g., `gh` for GitHub, `az repos` for Azure DevOps).
- NEVER rely on global git email. Before committing, check `git config --local user.email`. If not set, prompt the user.
- NEVER open PRs without `--auto-merge` (e.g., `gh pr create --auto-merge`).

# Superpowers

- NEVER store plans and design specs in `docs/plans/`. Store plans in `docs/superpowers/plans/` and design specs in `docs/superpowers/specs/`.
- NEVER default plans to sequential execution. Optimize for parallelization.
- NEVER dispatch parallel subagents into the same worktree. Each subagent MUST use `isolation: "worktree"`.
