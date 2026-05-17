# devcontainer-features

[![CI](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml/badge.svg)](https://github.com/SrzStephen/devcontainer-features/actions/workflows/ci.yml)



## Usage

```bash
devcontainer-features --help
```

## Development

Common tasks are managed via [just](https://github.com/casey/just):

| Command         | Description                        |
|-----------------|------------------------------------|
| `just`          | Run lint, typecheck, and tests     |
| `just lint`     | Lint and check formatting          |
| `just lint-fix` | Auto-fix lint and formatting       |
| `just typecheck`| Run type checking                  |
| `just test`     | Run tests                          |
| `just test-fast`| Run tests in parallel (no cov)     |
| `just pre-commit`| Run pre-commit on all files       |
| `just setup`    | Install deps and pre-commit hooks  |
| `just generate-docs` | Generate README.md for each feature |


## Setup

This repository is set up to run out of a [devcontainer](https://code.visualstudio.com/docs/devcontainers/create-dev-container) via Visual Studio Code.

The usual steps

## Python
* install [uv](https://docs.astral.sh/uv/getting-started/installation/)
* run `uv sync --all-groups` to install dependencies

## Pre-commit
Pre-commit gets installed as part of the `uv` dev dependencies

Register pre-commit to run the `.pre-commit-config.yaml` on commit via `uv run pre-commit install`

Run ad hoc with `uv run pre-commit`

### Commit format
pre-commit in this repository is set to enforce [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/).
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:
```
feat: allow provided config object to extend other configs
feat!: send an email to the customer when a product is shipped
feat(api)!: send an email to the customer when a product is shipped
```



## Just

* install [just](https://github.com/casey/just?tab=readme-ov-file#installation)


