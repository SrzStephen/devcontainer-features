## Compatibility

| OS              | Supported | Notes                                                              |
| --------------- | --------- | ------------------------------------------------------------------ |
| Debian / Ubuntu | ✓ tested  | Installed for the remote user with the official herdr install script |
| Alpine Linux    | ✓ tested  | The herdr release binary runs on musl; no extra packages needed     |

**Architectures:** x86_64, aarch64 (as supported by the herdr installer)

The feature installs `curl` and `git` if they are missing, then runs the official installer (`https://herdr.dev/install.sh`) as the remote user. The installer verifies the SHA-256 checksum of the release binary and puts it in `~/.local/bin/herdr`, which is added to `PATH` in `.profile` and `.bashrc`. There is no version option; the latest stable release is installed. If the installer fails the build fails.

## Plugins

The `plugins` option takes a comma-separated list of `owner/repo` or `owner/repo/subdir` entries, for example `ogulcancelik/herdr-plugin-examples/dev-layout-bootstrap`. Each is installed for the remote user with `herdr plugin install <entry> --yes` and appears in `herdr plugin list`.

- Plugins are cloned from GitHub, so the build needs network access (and `git`, which the feature installs if missing). Private repositories are not supported because there is no credential available at build time.
- A plugin that declares build commands needs those tools in the image. For example `rust-release-check` runs `cargo build --release`, so installing it fails unless Rust is present. A failed install fails the build.
- A nonexistent repository fails the build with `failed to install herdr plugin: <entry>`.
- Entries may only contain letters, digits and the characters dot, underscore, slash, colon, at sign, tilde, plus and hyphen, and must not start with a dash. Anything else fails the build before any command runs. Blank entries are ignored.
- Plugins can run code on your behalf, so only install sources you trust.

## Agent Skills

herdr is not an agent itself, so skills are installed for another agent that you also run inside herdr. Set `skillsAgent` to that agent's skills id (for example `claude-code`, `kiro-cli` or `hermes-agent`; `universal` is the nearest to a neutral target) and `skills` to a comma-separated list of sources such as `vercel-labs/agent-skills` or a full GitHub URL. Each entry is installed globally for the remote user with `npx -y skills add <source> -g -y -a <skillsAgent>`.

- If `skills` has entries but `skillsAgent` is empty, a warning is printed and nothing is installed (no Node.js either). The build still succeeds.
- Node.js is installed on demand, and only when skills will actually be installed. The skills CLI needs Node 22.20 or newer, so the latest Node 22 release is downloaded from nodejs.org, checksum-verified and unpacked into `/usr/local`. An existing Node 22.20 or newer is reused.
- `skillsAgent` follows the same character rules as plugin entries and must not start with a dash.
- This feature does not install the target agent; add its own feature (for example `claude-code`) alongside it.

## Persisting sessions

herdr keeps everything under `~/.config/herdr` (verified on herdr 0.9.5 in a Linux container):

| Path                                               | Contents                                                       |
| -------------------------------------------------- | -------------------------------------------------------------- |
| `~/.config/herdr/config.toml`                      | Configuration (override the path with `HERDR_CONFIG_PATH`)     |
| `~/.config/herdr/session.json`                     | Saved layout: workspaces, tabs and panes, written by the server |
| `~/.config/herdr/session-snapshots/`               | Session snapshots                                              |
| `~/.config/herdr/plugins/github-installations/`    | Installed plugin checkouts                                     |
| `~/.config/herdr/plugins/config/<plugin-id>`       | Per-plugin config directories                                  |
| `~/.config/herdr/plugins.json`                     | Plugin registry                                                |
| `~/.config/herdr/herdr.sock`, `herdr-client.sock`  | API and client sockets (created while the server runs)         |
| `~/.config/herdr/herdr*.log`                       | Logs                                                           |

To keep layouts across container rebuilds, mount that directory as a named volume. To resume agent conversations natively, also mount the agents' own config directories, such as `~/.claude`:

```jsonc
"mounts": [
  "source=herdr-config,target=/home/vscode/.config/herdr,type=volume",
  "source=claude-config,target=/home/vscode/.claude,type=volume"
],
"postCreateCommand": "sudo chown -R vscode:vscode /home/vscode/.config/herdr /home/vscode/.claude"
```

Things to know:

- A new, empty named volume mounted over a directory that exists in the image is seeded by Docker with that directory's contents and ownership. The `chown` in the `postCreateCommand` above is only needed when the path did not exist in the image (otherwise it is harmless). Adjust `vscode` and the paths to your remote user.
- Once a volume exists it overrides the image. Plugins added or changed in the `plugins` option after that do not reach it, so install them by hand with `herdr plugin install owner/repo --yes`, or recreate the volume.
- Sockets and running processes do not survive a rebuild. Only layouts and resumable agent sessions are restored.
