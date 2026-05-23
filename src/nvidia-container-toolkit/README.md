# NVIDIA Container Toolkit (nvidia-container-toolkit)

Installs the NVIDIA Container Toolkit (nvidia-container-toolkit) for GPU-accelerated containers.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/nvidia-container-toolkit:1": {}
}
```

## Options

| Options Id | Description                                                                                            | Type   | Default Value |
| ---------- | ------------------------------------------------------------------------------------------------------ | ------ | ------------- |
| version    | Version of nvidia-container-toolkit to install (e.g. '1.17.8'). Use 'latest' for the newest available. | string | latest        |

## Compatibility

| OS              | Supported     | Notes                                 |
| --------------- | ------------- | ------------------------------------- |
| Debian / Ubuntu | ✓ tested      | Installed via NVIDIA apt repository   |
| Alpine Linux    | not supported | Requires apt; Alpine is not supported |

**Architectures:** x86_64, aarch64

---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json). Add additional notes to a `NOTES.md`._
