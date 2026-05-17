DEBIAN := "debian:bookworm"
ALPINE := "alpine:3.20"

default: all

all: lint test

lint:
	find src -name "*.sh" | xargs shellcheck

test: test-claude-code test-just test-kiro test-nvidia-container-toolkit

test-claude-code:
	devcontainer features test -f claude-code --base-image {{DEBIAN}} -p .
	devcontainer features test -f claude-code --base-image {{ALPINE}} -p .

test-just:
	devcontainer features test -f just --base-image {{DEBIAN}} -p .
	devcontainer features test -f just --base-image {{ALPINE}} -p .

test-kiro:
	devcontainer features test -f kiro --base-image {{DEBIAN}} -p .

test-nvidia-container-toolkit:
	devcontainer features test -f nvidia-container-toolkit --base-image {{DEBIAN}} -p .

generate-docs:
	npx --yes @devcontainers/cli@latest features generate-docs -p . -n SrzStephen/devcontainer-features
