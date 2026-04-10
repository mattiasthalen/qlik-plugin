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

# Run all tests
test:
	@bash tests/test-setup.sh
	@bash tests/test-sync.sh
	@bash tests/test-sync-lib.sh
	@bash tests/test-sync-cloud-prep.sh
	@bash tests/test-sync-onprem-prep.sh
	@bash tests/test-sync-cloud-app.sh
	@bash tests/test-sync-finalize.sh
	@bash tests/test-sync-onprem-app.sh
	@bash tests/test-sync-script.sh
	@bash tests/test-inspect.sh
	@bash tests/test-project.sh

# Run a specific test file
test-one FILE:
	@bash tests/{{FILE}}
