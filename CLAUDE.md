# Rules

- NEVER write rules as "do X". Always phrase rules as "NEVER do Y" to clearly define what to avoid.

# Git Workflow

- NEVER commit directly to main.
- NEVER use non-conventional commit formats. See .claude/rules/conventional-commits.md
- NEVER leave commits unpushed.
- NEVER use raw git for remote operations when a CLI is available for the remote platform (e.g., `gh` for GitHub, `az repos` for Azure DevOps).
- NEVER rely on global git email. Before committing, check `git config --local user.email`. If not set, prompt the user.
- NEVER open PRs without enabling auto-merge (e.g., `gh pr merge --auto --merge` after `gh pr create`).
- NEVER use squash or rebase merges. Always use regular merge commits (`--merge`).

# Repo Setup

- NEVER leave a new repo without branch protection on the default branch. Require at least one approving review with admin enforcement.
- NEVER leave auto-merge disabled on a new repo.

# Superpowers

- NEVER store plans and design specs in `docs/plans/`. Store plans in `docs/superpowers/plans/` and design specs in `docs/superpowers/specs/`.
- NEVER default plans to sequential execution. Optimize for parallelization.
- NEVER dispatch parallel subagents into the same worktree. Each subagent MUST use `isolation: "worktree"`.
