# Extract Rules from CLAUDE.md into .claude/rules/

## Goal

Move all rules from CLAUDE.md into separate topic files under `.claude/rules/`. Leave CLAUDE.md empty.

## New Files

### `.claude/rules/rule-style.md`
- Meta-rule: NEVER write rules as "do X", phrase as "NEVER do Y"

### `.claude/rules/git-workflow.md`
- NEVER commit directly to main
- NEVER use non-conventional commit formats (ref: conventional-commits.md)
- NEVER leave commits unpushed
- NEVER use raw git for remote operations when a CLI is available
- NEVER rely on global git email
- NEVER open PRs as ready (always draft)
- NEVER enable auto-merge on draft PRs
- NEVER enable auto-merge on PRs from external contributors
- NEVER use squash or rebase merges

### `.claude/rules/repo-setup.md`
- NEVER leave default branch unprotected
- NEVER leave auto-merge disabled on new repos
- NEVER leave auto-delete of merged branches disabled on new repos

### `.claude/rules/superpowers.md`
- NEVER store plans/specs in docs/plans/
- NEVER default plans to sequential execution
- NEVER dispatch parallel subagents into same worktree
- NEVER use isolation: "worktree" on non-main branches

## Unchanged

- `.claude/rules/conventional-commits.md` — stays as-is
- `CLAUDE.md` — emptied (file kept, no content)

## Format

Each rule file: `# Title` heading followed by NEVER-phrased bullet list.
