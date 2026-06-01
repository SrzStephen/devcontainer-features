
# GitLab CLI (gitlab-cli)

Installs the GitLab CLI (glab) for interacting with GitLab repositories and CI/CD pipelines.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/gitlab-cli:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of glab to install (e.g. '1.50.0'). Use 'latest' for the newest available. | string | latest |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
