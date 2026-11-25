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

- `defaultModel` (default empty): sets `chat.defaultModel`. Only letters, digits and the characters `.`, `_`, `:`, `/` and `-` are allowed.
- `agentEngine` (default empty): sets `chat.agentEngine`. Must be empty, `v1`, `v2` or `v3`.
- `disableGreeting` (default `true`): runs `kiro-cli settings chat.greeting.enabled false`.

An empty `defaultModel` or `agentEngine` means the setting is not touched and `kiro-cli settings` is not run for it. Setting `disableGreeting` to `false` likewise leaves the greeting setting untouched.

## Agent Skills

The `skills` option takes a comma-separated list of skill sources, for example `vercel-labs/agent-skills` or a full GitHub URL. Each entry is installed globally for the remote user with `skills add <source> -g -y -a kiro-cli`, so the skills land in `~/.kiro/skills`. The option is blank by default.

Node.js is installed on demand, and only when at least one non-blank entry is given. The skills CLI needs Node 22.20 or newer, which is newer than the distro packages. An existing npm is reused when its Node.js is 22.20 or newer; otherwise nvm (pinned and checksum-verified) is downloaded into `/usr/local/share/nvm`, installs the latest Node 22 release (the unofficial musl builds on Alpine), and `node`, `npm` and `npx` are linked into `/usr/local/bin`. The skills CLI itself is then installed with `npm install -g skills`. Blank values such as a lone comma or spaces install nothing. Entries may only contain letters, digits and the characters dot, underscore, slash, colon, at sign, tilde, plus and hyphen, and must not start with a dash; anything else fails the build before any command runs.
