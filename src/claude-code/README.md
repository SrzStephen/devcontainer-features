
# Claude Code (claude-code)

Installs Claude Code CLI and optionally configures plugin marketplaces, plugins, attribution settings and custom statusline.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/claude-code:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| marketplace | Plugin marketplace to register. Accepts owner/repo shorthand (e.g. obra/superpowers-marketplace) or a full GitHub URL (e.g. https://github.com/obra/superpowers-marketplace). Skipped when empty. | string | - |
| plugin | Plugin to install after the marketplace is configured. Accepts plugin-name@marketplace-name format (e.g. superpowers@superpowers-marketplace) or a full GitHub URL. Skipped when empty. | string | - |
| removeAttribution | When true, injects empty commit and pr attribution strings into ~/.claude/settings.json, suppressing Co-Authored-By lines from Claude Code commits. | boolean | false |
| statusline | When true, installs statusline.sh to ~/.claude/statusline-command.sh and configures it as the Claude Code status line in ~/.claude/settings.json. | boolean | false |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/SrzStephen/devcontainer-features/blob/main/src/claude-code/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
