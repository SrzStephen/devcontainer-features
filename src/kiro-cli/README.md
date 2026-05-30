
# Kiro cli (kiro-cli)

Installs the Kiro cli.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/kiro-cli:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Kiro CLI to install. Use 'latest' for the newest available, or a full version like '2.3.0'. | string | latest |

## Compatibility

| OS              | Supported  | Notes                                                       |
| --------------- | ---------- | ----------------------------------------------------------- |
| Debian / Ubuntu | ✓ tested   | Primary target                                              |
| Alpine Linux    | not tested | Binary hosted on AWS; no Alpine-specific artifact available |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
