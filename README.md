# devcontainer-features

[![CI](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml/badge.svg)](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml)

A collection of devcontainer features for tools commonly used in local development workflows.

## Features

| Feature                                                            | Description                                             | Reference                                                             | Debian/Ubuntu | Alpine |
| ------------------------------------------------------------------ | ------------------------------------------------------- | --------------------------------------------------------------------- | ------------- | ------ |
| [act](src/act/README.md)                                           | Run GitHub Actions locally                              | `ghcr.io/SrzStephen/devcontainer-features/act:0`                      | ✓             | ✓      |
| [claude-code](src/claude-code/README.md)                           | Claude Code CLI with optional plugin/marketplace config | `ghcr.io/SrzStephen/devcontainer-features/claude-code:0`              | ✓             | ✓      |
| [gitlab-ci-local](src/gitlab-ci-local/README.md)                   | Run GitLab CI pipelines locally                         | `ghcr.io/SrzStephen/devcontainer-features/gitlab-ci-local:0`          | ✓             | ✓      |
| [just](src/just/README.md)                                         | Just command runner (includes just-lsp)                 | `ghcr.io/SrzStephen/devcontainer-features/just:0`                     | ✓             | ✓      |
| [kiro-cli](src/kiro-cli/README.md)                                 | Kiro CLI                                                | `ghcr.io/SrzStephen/devcontainer-features/kiro-cli:0`                 | ✓             | —      |
| [nvidia-container-toolkit](src/nvidia-container-toolkit/README.md) | NVIDIA Container Toolkit for GPU containers             | `ghcr.io/SrzStephen/devcontainer-features/nvidia-container-toolkit:0` | ✓             | —      |
| [prek](src/prek/README.md)                                         | Pre-commit and pre-push hook runner                     | `ghcr.io/SrzStephen/devcontainer-features/prek:0`                     | ✓             | ✓      |

## Usage

Add a feature to your `.devcontainer/devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/SrzStephen/devcontainer-features/just:0": {}
    }
}
```

See each feature's README for available options.

## Development

**Prerequisites:** [`just`](https://github.com/casey/just), [`shellcheck`](https://www.shellcheck.net/), [`devcontainer` CLI](https://github.com/devcontainers/cli), Docker

| Command               | Description                                                       |
| --------------------- | ----------------------------------------------------------------- |
| `just`                | Lint and test everything                                          |
| `just lint`           | Shellcheck all `.sh` files                                        |
| `just test`           | Run all feature tests                                             |
| `just test-<feature>` | Test a single feature (e.g. `just test-act`)                      |
| `just generate-docs`  | Regenerate each feature's README from `devcontainer-feature.json` |
| `just act-ci`         | Run the CI workflow locally with `act`                            |
| `just act-validate`   | Run the validate workflow locally with `act`                      |
| `just act-dry`        | Dry-run both workflows without executing jobs                     |
| `just act-all`        | Run both workflows locally with `act`                             |

### Commit format

Pre-commit enforces [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:

```
feat(kiro-cli): add version option for pinning specific releases
fix: lowercase feature id to match devcontainer spec
feat!: breaking change with migration notes in footer
```
