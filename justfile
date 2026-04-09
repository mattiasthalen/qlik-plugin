# Show available tasks
default:
	@just --list

# Run interactive GitHub auth + SSH signing setup
setup-git:
	./scripts/setup-git.sh

# Launch Claude Code with all permissions and remote control
claude:
	claude --dangerously-skip-permissions --remote-control

# Sync template from upstream
sync-template:
	./scripts/sync-template.sh
