
# Claude Code (claude-code)

Installs Claude Code CLI and optionally configures plugin marketplaces, plugins, attribution settings and custom statusline.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/claude-code:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| marketplace | Comma-separated list of plugin marketplaces to register. Each entry accepts owner/repo shorthand (e.g. obra/superpowers-marketplace) or a full GitHub URL (e.g. https://github.com/obra/superpowers-marketplace). Skipped when empty. | string | - |
| plugin | Comma-separated list of plugins to install after marketplaces are configured. Each entry accepts plugin-name@marketplace-name format (e.g. superpowers@superpowers-marketplace) or a full GitHub URL. Skipped when empty. | string | - |
| removeAttribution | When true, injects empty commit and pr attribution strings into ~/.claude/settings.json, suppressing Co-Authored-By lines from Claude Code commits. | boolean | false |
| statusline | When true, installs statusline.sh to ~/.claude/statusline-command.sh and configures it as the Claude Code status line in ~/.claude/settings.json. | boolean | false |
| skills | Comma-separated list of agent skill sources to install globally for Claude Code via the skills CLI (npm install -g skills). Each entry accepts owner/repo shorthand (e.g. vercel-labs/agent-skills) or a full GitHub URL. Node.js is installed on demand. Skipped when empty. | string | - |
| planMode | When true, sets plan mode as the default permission mode in ~/.claude/settings.json, so Claude plans before executing actions. | boolean | true |
| defaultToAgentsView | Value written to the defaultToAgentsView setting in ~/.claude/settings.json. When true (the default), Claude Code opens to the agents view on start. Set to false to disable. | boolean | true |

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

## Agent Skills

The `skills` option takes a comma-separated list of skill sources, for example `vercel-labs/agent-skills` or a full GitHub URL. Each entry is installed globally for the remote user with `skills add <source> -g -y -a claude-code`, so the skills land in `~/.claude/skills`. The option is blank by default.

Node.js is installed on demand, and only when at least one non-blank entry is given. The skills CLI needs Node 22.20 or newer, which is newer than the distro packages. An existing npm is reused when its Node.js is 22.20 or newer; otherwise nvm (pinned and checksum-verified) is downloaded into `/usr/local/share/nvm`, installs the latest Node 22 release (the unofficial musl builds on Alpine), and `node`, `npm` and `npx` are linked into `/usr/local/bin`. The skills CLI itself is then installed with `npm install -g skills`. Blank values such as a lone comma or spaces install nothing. Entries may only contain letters, digits and the characters dot, underscore, slash, colon, at sign, tilde, plus and hyphen; anything else fails the build before any command runs.

## Claude Code Status Line

The Claude Code status line runs the script `~/.claude/statusline.sh` on each assistant response. It displays a persistent status bar at the bottom of the Claude Code interface.

### What it shows

| Segment      | Example                               | Description                                                 |
| ------------ | ------------------------------------- | ----------------------------------------------------------- |
| 🤖 Model     | `🤖 Sonnet`                           | Current model name                                          |
| 📁 Directory | `📁 devcontainer-features`            | Current working directory (basename only)                   |
| 🌿 Branch    | `🌿 main`                             | Git branch (omitted outside a git repo)                     |
| 🔗 Repo      | `🔗 SrzStephen/devcontainer-features` | Clickable OSC 8 hyperlink to remote (Cmd/Ctrl+click)        |
| ctx          | `ctx: 15k/200k (8%)`                  | Context window: tokens used / max size / percentage         |
| 5h           | `5h: 24% (resets in 1h 45m)`          | 5-hour rate limit usage and time until reset (Pro/Max only) |
| 7d           | `7d: 41% (resets in 3d 5h)`           | 7-day rate limit usage and time until reset (Pro/Max only)  |

### Example output

```
🤖 Sonnet | 📁 devcontainer-features | 🌿 main | 🔗 SrzStephen/devcontainer-features | ctx: 15k/200k (8%) | 5h: 24% (resets in 1h 45m) | 7d: 41% (resets in 3d 5h)
```

The `🔗` segment is a clickable hyperlink in terminals that support OSC 8 (iTerm2, Kitty, WezTerm). It opens the GitHub repository in your browser. If your terminal doesn't support hyperlinks, set `FORCE_HYPERLINK=1` before launching Claude Code.

### Configuration

`~/.claude/settings.json`:

```json
{
    "statusLine": {
        "type": "command",
        "command": "~/.claude/statusline.sh"
    }
}
```

The rate limit segments (`5h`, `7d`) only appear for Claude.ai Pro/Max subscribers after the first API response in a session. The reset countdown is computed live from the Unix timestamp provided by the API.

### Docs

https://code.claude.com/docs/en/statusline


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
