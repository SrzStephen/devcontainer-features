
# Hermes Agent (hermes)

Installs Hermes Agent (Nous Research) for the remote user, with optional plugins and agent skills.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/hermes:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| plugins | Comma-separated list of Hermes plugins to install and enable (hermes plugins install ENTRY --enable). Each entry is a curated catalog name (e.g. snyk), an owner/repo shorthand or a Git URL. Skipped when empty. | string | - |
| skills | Comma-separated list of agent skill sources to install globally for Hermes Agent via the skills CLI (npm install -g skills). Each entry accepts owner/repo shorthand (e.g. vercel-labs/agent-skills) or a full GitHub URL. Node.js is installed on demand. Skipped when empty. | string | - |

## Compatibility

| OS              | Supported | Notes                                                                       |
| --------------- | --------- | --------------------------------------------------------------------------- |
| Debian / Ubuntu | ✓ tested  | Installed for the remote user with the official Hermes Agent install script |
| Alpine Linux    | ✓ tested  | `libstdc++` is installed first, which the Hermes Node.js runtime needs       |

**Architectures:** x86_64, aarch64 (as supported by the Hermes installer)

The feature installs `curl` and `git` if they are missing, then (on Alpine) `libstdc++`, then runs the official installer (`https://hermes-agent.nousresearch.com/install.sh`) as the remote user with `--non-interactive --skip-browser --skip-computer-use`. The setup wizard is skipped, and the Chromium and cua-driver downloads are left out to keep the image small. Run `hermes pm install chromium` or `hermes pm install cua-driver` later if you need them. Hermes lives in `~/.hermes` and the `hermes` command in `~/.local/bin`, which is added to `PATH` in `.profile` and `.bashrc`. If the installer fails the build fails.

## Plugins

The `plugins` option takes a comma-separated list. Each entry is installed and enabled for the remote user with `hermes plugins install <entry> --enable`.

- A bare name such as `snyk` is looked up in the curated Hermes plugin catalog. Catalog entries are pinned to a reviewed revision. Browse them with `hermes plugins browse` or `hermes plugins search`.
- An `owner/repo` shorthand or a Git URL installs straight from that repository and bypasses the catalog review and pinning, so only use sources you trust.
- An unknown name fails the build with a clear error.
- Entries may only contain letters, digits and the characters dot, underscore, slash, colon, at sign, tilde, plus and hyphen, and must not start with a dash. Anything else fails the build before any command runs. Blank entries are ignored.

## Agent Skills

The `skills` option takes a comma-separated list of skill sources, for example `vercel-labs/agent-skills` or a full GitHub URL. Each entry is installed globally for the remote user with `skills add <source> -g -y -a hermes-agent`, so the skills land in `~/.hermes/skills`. The option is blank by default.

Node.js is installed on demand, and only when at least one non-blank entry is given. The skills CLI needs Node 22.20 or newer, which is newer than the distro packages. An existing npm is reused when its Node.js is 22.20 or newer; otherwise nvm (pinned and checksum-verified) is downloaded into `/usr/local/share/nvm`, installs the latest Node 22 release (the unofficial musl builds on Alpine), and `node`, `npm` and `npx` are linked into `/usr/local/bin`. The skills CLI itself is then installed with `npm install -g skills`. Blank values such as a lone comma or spaces install nothing. The same entry rules as for plugins apply.

## Persisting state

`~/.hermes` holds Hermes configuration, installed plugins, skills, sessions and the Hermes checkout itself. It is a good candidate for a named volume mount if you want state to survive container rebuilds. A new, empty named volume mounted over it is seeded by Docker with the directory's contents and ownership from the image, including the Hermes checkout, so no `chown` is needed. Once the volume exists it overrides the image: plugins added or changed in the `plugins` option, or a newer Hermes checkout after a rebuild, do not reach it. Add them by hand or recreate the volume.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
