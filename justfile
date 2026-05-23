DEBIAN := "debian:bookworm"
ALPINE := "alpine:3.20"
REPO := "SrzStephen/devcontainer-features"

default: all

all: lint test

lint:
	find src -name "*.sh" -exec shellcheck {} +

test: test-claude-code test-just test-kiro-cli test-nvidia-container-toolkit test-act test-gitlab-ci-local test-prek

test-claude-code:
	devcontainer features test -f claude-code --base-image {{DEBIAN}} -p .
	devcontainer features test -f claude-code --base-image {{ALPINE}} -p .

test-just:
	devcontainer features test -f just --base-image {{DEBIAN}} -p .
	devcontainer features test -f just --base-image {{ALPINE}} -p .

test-kiro-cli:
	devcontainer features test -f kiro-cli --base-image {{DEBIAN}} -p .

test-nvidia-container-toolkit:
	devcontainer features test -f nvidia-container-toolkit --base-image {{DEBIAN}} -p .

test-act:
	devcontainer features test -f act --base-image {{DEBIAN}} -p .
	devcontainer features test -f act --base-image {{ALPINE}} -p .

test-gitlab-ci-local:
	devcontainer features test -f gitlab-ci-local --base-image {{DEBIAN}} -p .
	devcontainer features test -f gitlab-ci-local --base-image {{ALPINE}} -p .

test-prek:
	devcontainer features test -f prek --base-image {{DEBIAN}} -p .
	devcontainer features test -f prek --base-image {{ALPINE}} -p .

generate-docs:
	npx --yes @devcontainers/cli@latest features generate-docs -p . -n {{REPO}}

act-ci:
	act -W .github/workflows/ci.yml

act-validate:
	act -W .github/workflows/validate.yml

act-dry:
	act -n -W .github/workflows/ci.yml
	act -n -W .github/workflows/validate.yml

act-all: act-ci act-validate
