DEBIAN := "debian:bookworm"
ALPINE := "alpine:3.20"
REPO := "SrzStephen/devcontainer-features"

default: all

all: lint test

lint:
	find src -name "*.sh" -exec shellcheck {} +
	prettier --check "**/*.{json,yaml,yml,md}"

test: test-claude-code test-just test-kiro-cli test-nvidia-container-toolkit test-act test-gitlab-ci-local test-prek

setup-qemu:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

test-arm64: test-claude-code-arm64 test-just-arm64 test-kiro-cli-arm64 test-nvidia-container-toolkit-arm64 test-act-arm64 test-gitlab-ci-local-arm64 test-prek-arm64

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

test-claude-code-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f claude-code --base-image {{DEBIAN}} -p .
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f claude-code --base-image {{ALPINE}} -p .

test-just-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f just --base-image {{DEBIAN}} -p .
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f just --base-image {{ALPINE}} -p .

test-kiro-cli-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f kiro-cli --base-image {{DEBIAN}} -p .

test-nvidia-container-toolkit-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f nvidia-container-toolkit --base-image {{DEBIAN}} -p .

test-act-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f act --base-image {{DEBIAN}} -p .
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f act --base-image {{ALPINE}} -p .

test-gitlab-ci-local-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f gitlab-ci-local --base-image {{DEBIAN}} -p .
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f gitlab-ci-local --base-image {{ALPINE}} -p .

test-prek-arm64:
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f prek --base-image {{DEBIAN}} -p .
	DOCKER_DEFAULT_PLATFORM=linux/arm64 devcontainer features test -f prek --base-image {{ALPINE}} -p .

generate-docs:
	npx --yes @devcontainers/cli@latest features generate-docs -p . -n {{REPO}}

act-ci:
	act -W .github/workflows/ci.yml

act-validate:
	act pull_request -W .github/workflows/validate.yml

act-dry:
	act -n -W .github/workflows/ci.yml
	act pull_request -n -W .github/workflows/validate.yml

act-all: act-ci act-validate
