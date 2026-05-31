
# just (just)

Installs just, a handy way to save and run project-specific commands via justfile.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/just:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of just to install. Use 'latest' for the newest available. | string | latest |
| lspVersion | Version of just-lsp to install. Set to 'false' to skip installation. | string | latest |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
