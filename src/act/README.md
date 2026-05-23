# act (act)

Installs act, a tool to run GitHub Actions locally.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/act:0": {}
}
```

## Options

| Options Id | Description                                                       | Type   | Default Value |
| ---------- | ----------------------------------------------------------------- | ------ | ------------- |
| version    | Version of act to install. Use 'latest' for the newest available. | string | latest        |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

**Runtime note:** `act` requires Docker to be available at runtime to execute GitHub Actions workflows.

---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json). Add additional notes to a `NOTES.md`._
