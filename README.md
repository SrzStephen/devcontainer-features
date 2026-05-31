# devcontainer-features

[![CI](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml/badge.svg)](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml)

A collection of devcontainer features for tools commonly used in local development workflows.

## Features

| Feature                                                            | Description                                             | Reference                                                             | Debian/Ubuntu | Alpine |
| ------------------------------------------------------------------ | ------------------------------------------------------- | --------------------------------------------------------------------- | ------------- | ------ |
| [act](src/act/README.md)                                           | Run GitHub Actions locally                              | `ghcr.io/SrzStephen/devcontainer-features/act:0`                      | ✓             | ✓      |
| [agentcore](src/agentcore/README.md)                               | AWS Bedrock AgentCore CLI                               | `ghcr.io/SrzStephen/devcontainer-features/agentcore:0`                | ✓             | ✓      |
| [aws-sam-cli](src/aws-sam-cli/README.md)                           | AWS Serverless Application Model (SAM) CLI              | `ghcr.io/SrzStephen/devcontainer-features/aws-sam-cli:0`              | ✓             | —      |
| [bash-language-server](src/bash-language-server/README.md)         | Bash Language Server                                    | `ghcr.io/SrzStephen/devcontainer-features/bash-language-server:0`     | ✓             | ✓      |
| [claude-code](src/claude-code/README.md)                           | Claude Code CLI with optional plugin/marketplace config | `ghcr.io/SrzStephen/devcontainer-features/claude-code:0`              | ✓             | ✓      |
| [gitlab-ci-local](src/gitlab-ci-local/README.md)                   | Run GitLab CI pipelines locally                         | `ghcr.io/SrzStephen/devcontainer-features/gitlab-ci-local:0`          | ✓             | ✓      |
| [just](src/just/README.md)                                         | Just command runner (includes just-lsp)                 | `ghcr.io/SrzStephen/devcontainer-features/just:0`                     | ✓             | ✓      |
| [kiro-cli](src/kiro-cli/README.md)                                 | Kiro CLI                                                | `ghcr.io/SrzStephen/devcontainer-features/kiro-cli:0`                 | ✓             | ✓      |
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

```bash
just        # lint + test everything
just lint   # shellcheck + prettier
just test   # all feature tests (x86)
```

See [TESTING.md](TESTING.md) for the full testing guide, including arm64 local testing and CI structure.

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
