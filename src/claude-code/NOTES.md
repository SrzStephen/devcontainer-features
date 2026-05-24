## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

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
