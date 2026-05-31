
# prek (prek)

Installs prek, a pre-commit and pre-push hook runner.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/prek:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of prek to install. Use 'latest' for the newest available. | string | latest |

## Compatibility

| OS              | Supported | Notes                                        |
| --------------- | --------- | -------------------------------------------- |
| Debian / Ubuntu | ✓ tested  | Primary target                               |
| Alpine Linux    | ✓ tested  | Uses musl static binaries; no glibc required |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
