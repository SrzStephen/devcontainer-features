# bash Language Server (bash-language-server)

Installs [bash-language-server](https://github.com/bash-lsp/bash-language-server) via npm. Optionally installs shellcheck if not already present.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/bash-language-server:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of bash-language-server to install. Use 'latest' for the newest available. | string | latest |
| installShellcheck | When true, installs shellcheck via the system package manager if shellcheck is not already on PATH. | boolean | true |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
