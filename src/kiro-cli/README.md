
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
| disableAutoupdates | Disable automatic background updates for Kiro CLI. | boolean | false |

## Compatibility

| OS              | Supported  | Notes                                                                          |
| --------------- | ---------- | ------------------------------------------------------------------------------ |
| Debian / Ubuntu | ✓ tested   | x86_64 uses .deb extraction; arm64 and musl systems use zip                   |
| Alpine Linux    | ✓ tested   | Uses musl-linked zip (`kirocli-*-linux-musl.zip`); glibc < 2.34 also supported |

**Architectures:** x86_64, aarch64

## Libc selection

The installer automatically detects the system's libc:

- **musl** (Alpine and similar): selects `kirocli-*-linux-musl.zip`
- **glibc ≥ 2.34** (Debian 12+, Ubuntu 22.04+): uses `.deb` on x86_64 or the standard zip on arm64
- **glibc < 2.34** (older distros): falls back to the musl zip for compatibility


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
