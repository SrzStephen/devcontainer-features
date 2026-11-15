
# Kiro CLI (kiro-cli)

Installs the Kiro cli.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/kiro-cli:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Kiro CLI to install. Use 'latest' for the newest available, or a full version like '2.3.0'. | string | latest |
| disableAutoupdates | Disable automatic background updates for Kiro CLI. | boolean | false |
| defaultModel | Default chat model (chat.defaultModel), e.g. 'claude-sonnet-4.6'. Empty means the setting is not touched. | string | - |
| agentEngine | Agent engine (chat.agentEngine): 'v1', 'v2' or 'v3'. Empty means the setting is not touched. | string | - |
| disableGreeting | Disable the Kiro CLI greeting (chat.greeting.enabled=false). When false, the setting is not touched. | boolean | true |

## Compatibility

| OS              | Supported  | Notes                                                                          |
| --------------- | ---------- | ------------------------------------------------------------------------------ |
| Debian / Ubuntu | ✓ tested   | x86_64 uses .deb extraction; arm64 and musl systems use zip                   |
| Alpine Linux    | ✓ supported | Not tested in CI; install script handles musl automatically                    |

**Architectures:** x86_64, aarch64

## Libc selection

The installer automatically detects the system's libc:

- **musl** (Alpine and similar): selects `kirocli-*-linux-musl.zip`
- **glibc ≥ 2.34** (Debian 12+, Ubuntu 22.04+): uses `.deb` on x86_64 or the standard zip on arm64
- **glibc < 2.34** (older distros): falls back to the musl zip for compatibility

## Settings options

`defaultModel`, `agentEngine` and `disableGreeting` are applied with `kiro-cli settings` for root and, when different, the remote user.

- `defaultModel` (default empty): sets `chat.defaultModel`. Must match `^[A-Za-z0-9._:/-]+
# Kiro CLI (kiro-cli)

Installs the Kiro cli.

## Example Usage

```json
"features": {
    "#{Registry}/#{Namespace}/kiro-cli:#{Version}": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Kiro CLI to install. Use 'latest' for the newest available, or a full version like '2.3.0'. | string | latest |
| disableAutoupdates | Disable automatic background updates for Kiro CLI. | boolean | false |
| defaultModel | Default chat model (chat.defaultModel), e.g. 'claude-sonnet-4.6'. Empty means the setting is not touched. | string | - |
| agentEngine | Agent engine (chat.agentEngine): 'v1', 'v2' or 'v3'. Empty means the setting is not touched. | string | - |
| disableGreeting | Disable the Kiro CLI greeting (chat.greeting.enabled=false). When false, the setting is not touched. | boolean | true |
#{Customizations}
.
- `agentEngine` (default empty): sets `chat.agentEngine`. Must be empty, `v1`, `v2` or `v3`.
- `disableGreeting` (default `true`): runs `kiro-cli settings chat.greeting.enabled false`.

An empty `defaultModel` or `agentEngine` means the setting is not touched and `kiro-cli settings` is not run for it. Setting `disableGreeting` to `false` likewise leaves the greeting setting untouched.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
