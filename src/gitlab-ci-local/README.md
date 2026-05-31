
# gitlab-ci-local (gitlab-ci-local)

Installs gitlab-ci-local, a tool to run GitLab CI pipelines locally.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/gitlab-ci-local:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of gitlab-ci-local to install. Use 'latest' for the newest available. | string | latest |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

**Runtime note:** `gitlab-ci-local` requires Docker to be available at runtime to execute pipeline jobs.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
