
# Bash Language Server (bash-language-server)

Installs bash-language-server via npm. Optionally installs shellcheck and shfmt if not already present.

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
| installShellfmt | When true, installs shfmt via the system package manager if shfmt is not already on PATH. | boolean | true |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/SrzStephen/devcontainer-features/blob/main//tmp/publish-src/bash-language-server/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
