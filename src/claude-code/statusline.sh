#!/bin/bash
# Claude Code status line script
# Drop this in ~/.claude/statusline.sh and wire it up in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
#
# Reads the Claude Code statusLine JSON payload from stdin and prints a
# compact, colourful single-line status bar.

# ---------------------------------------------------------------------------
# ANSI helpers
# ---------------------------------------------------------------------------
reset="\033[0m"
bold="\033[1m"
dim="\033[2m"

# Foreground colours (256-colour)
fg_white="\033[97m"
fg_grey="\033[37m"
fg_cyan="\033[96m"
fg_green="\033[92m"
fg_yellow="\033[93m"
fg_orange="\033[38;5;214m"
fg_red="\033[91m"
fg_magenta="\033[95m"
fg_dark="\033[38;5;240m"

# Separator / icon constants
SEP="${fg_dark}│${reset}"

# ---------------------------------------------------------------------------
# Read stdin once
# ---------------------------------------------------------------------------
input=$(cat)

# ---------------------------------------------------------------------------
# 1. Model name — shorten "Claude X.Y Zname" → "zname-X.Y"
# ---------------------------------------------------------------------------
model_display=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"')

# Convert e.g. "Claude 3.5 Sonnet" → "sonnet-3.5", "Claude Sonnet 4.6" → "sonnet-4.6"
model_short=$(printf '%s' "$model_display" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/^claude[[:space:]]*//' \
  | sed -E 's/^([a-z]+)[[:space:]]+([0-9]+\.[0-9]+)$/\1-\2/' \
  | sed -E 's/^([0-9]+\.[0-9]+)[[:space:]]+([a-z]+)$/\2-\1/')

effort_level=$(printf '%s' "$input" | jq -r '.effort.level // empty')
effort_text=""
if [ -n "$effort_level" ] && [ "$effort_level" != "none" ]; then
  case "$effort_level" in
    low)    effort_text=" Low"    ;;
    medium) effort_text=" Medium" ;;
    high)   effort_text=" High"   ;;
    xhigh)  effort_text=" XHigh"  ;;
    max)    effort_text=" Max"    ;;
    *)      effort_text=" ${effort_level}" ;;
  esac
fi

model_str="${bold}${fg_cyan}🤖 ${model_short}${effort_text}${reset}"

# ---------------------------------------------------------------------------
# 2. Current directory
# ---------------------------------------------------------------------------
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')
dirname="${cwd##*/}"
dir_str="${fg_grey}📁 ${dirname}${reset}"

# ---------------------------------------------------------------------------
# 3. Git branch / worktree
# ---------------------------------------------------------------------------
git_worktree=$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')

if [ -n "$git_worktree" ]; then
  branch_name="$git_worktree"
else
  branch_name=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

if [ -n "$branch_name" ]; then
  git_str="${fg_magenta}🌿 ${branch_name}${reset}"
else
  git_str=""
fi

# ---------------------------------------------------------------------------
# 4. Repo link (OSC 8 hyperlink — Cmd/Ctrl+click in iTerm2, Kitty, WezTerm)
# ---------------------------------------------------------------------------
repo_host=$(printf '%s' "$input"  | jq -r '.workspace.repo.host  // empty')
repo_owner=$(printf '%s' "$input" | jq -r '.workspace.repo.owner // empty')
repo_name_j=$(printf '%s' "$input" | jq -r '.workspace.repo.name // empty')

repo_url=""
repo_display=""
if [ -n "$repo_host" ] && [ -n "$repo_owner" ] && [ -n "$repo_name_j" ]; then
  repo_url="https://${repo_host}/${repo_owner}/${repo_name_j}"
  repo_display="${repo_owner}/${repo_name_j}"
else
  remote_raw=$(git remote get-url origin 2>/dev/null)
  if [ -n "$remote_raw" ]; then
    repo_url=$(printf '%s' "$remote_raw" \
      | sed 's/git@github\.com:/https:\/\/github.com\//' \
      | sed 's/\.git$//')
    repo_display=$(basename "$repo_url")
  fi
fi

if [ -n "$repo_url" ]; then
  repo_str=$(printf '\033]8;;%s\a🔗 %s\033]8;;\a' "$repo_url" "$repo_display")
else
  repo_str=""
fi

# ---------------------------------------------------------------------------
# 5. Context window bar + token breakdown + window size
# ---------------------------------------------------------------------------
used_pct=$(printf '%s' "$input"  | jq -r '.context_window.used_percentage    // empty')
ctx_total=$(printf '%s' "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(printf '%s' "$input"  | jq -r '.context_window.context_window_size // 200000')
ctx_used_k=$(( ctx_total / 1000 ))
ctx_size_k=$(( ctx_size  / 1000 ))

_fmt_k() {
  local n=$1
  if [ "$n" -ge 1000 ]; then
    awk "BEGIN { printf \"%.1fk\", $n/1000 }"
  else
    printf '%d' "$n"
  fi
}

if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")

  # Pick colour by usage level
  if   [ "$used_int" -ge 85 ]; then bar_color="$fg_red"
  elif [ "$used_int" -ge 60 ]; then bar_color="$fg_orange"
  elif [ "$used_int" -ge 35 ]; then bar_color="$fg_yellow"
  else                               bar_color="$fg_green"
  fi

  # Build a 10-cell filled/empty bar  ▓░
  bar_width=10
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))
  bar=""
  for _ in $(seq 1 "$filled"); do bar="${bar}▓"; done
  for _ in $(seq 1 "$empty");  do bar="${bar}░"; done

  ctx_str="${bar_color}${bar} ${used_int}%${reset} ${dim}${ctx_used_k}k/${ctx_size_k}k${reset}"

  # Token breakdown — only available after the first API call
  tok_in=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.input_tokens               // empty')
  tok_cr=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.cache_read_input_tokens     // empty')
  tok_cw=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
  tok_out=$(printf '%s' "$input" | jq -r '.context_window.current_usage.output_tokens               // empty')

  if [ -n "$tok_in" ]; then
    tok_str="${fg_white}in:$(_fmt_k "$tok_in")${reset} ${fg_green}cr:$(_fmt_k "$tok_cr")${reset} ${fg_yellow}cw:$(_fmt_k "$tok_cw")${reset} ${dim}out:$(_fmt_k "$tok_out")${reset}"
    ctx_str="${ctx_str}  ${tok_str}"
  fi
else
  ctx_str="${fg_grey}ctx: --${reset}"
fi

# ---------------------------------------------------------------------------
# 5b. Lines added / deleted
# ---------------------------------------------------------------------------
lines_added=$(printf '%s' "$input"   | jq -r '.cost.total_lines_added   // empty')
lines_removed=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // empty')

if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  added_n=${lines_added:-0}
  removed_n=${lines_removed:-0}
  lines_str="${fg_green}+${added_n}${reset}${fg_dark}/${reset}${fg_red}-${removed_n}${reset}"
else
  lines_str=""
fi

# ---------------------------------------------------------------------------
# 7. Rate limits (5h and 7d) with full reset countdown
# ---------------------------------------------------------------------------
_format_reset() {
  local ts="$1"
  [ -z "$ts" ] && return
  local now diff
  now=$(date +%s)
  diff=$(( ts - now ))
  [ "$diff" -le 0 ] && printf 'now' && return
  if [ "$diff" -lt 86400 ]; then
    date -d "@${ts}" "+%H:%M %Z" 2>/dev/null
  else
    date -d "@${ts}" "+%a %H:%M %Z" 2>/dev/null
  fi
}

five_pct=$(printf '%s' "$input"        | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets_at=$(printf '%s' "$input"  | jq -r '.rate_limits.five_hour.resets_at       // empty')
seven_pct=$(printf '%s' "$input"       | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_resets_at=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at       // empty')

rate_parts=""

if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  if   [ "$five_int" -ge 80 ]; then rc="$fg_red"
  elif [ "$five_int" -ge 50 ]; then rc="$fg_orange"
  else                               rc="$fg_green"
  fi
  five_reset_str=$(_format_reset "$five_resets_at")
  five_str="${rc}5h:${five_int}%${reset}"
  [ -n "$five_reset_str" ] && five_str="${five_str} ${dim}(resets at ${five_reset_str})${reset}"
  rate_parts="$five_str"
fi

if [ -n "$seven_pct" ]; then
  seven_int=$(printf '%.0f' "$seven_pct")
  if   [ "$seven_int" -ge 80 ]; then rc="$fg_red"
  elif [ "$seven_int" -ge 50 ]; then rc="$fg_orange"
  else                               rc="$fg_green"
  fi
  seven_reset_str=$(_format_reset "$seven_resets_at")
  seven_str="${rc}7d:${seven_int}%${reset}"
  [ -n "$seven_reset_str" ] && seven_str="${seven_str} ${dim}(resets at ${seven_reset_str})${reset}"
  if [ -n "$rate_parts" ]; then
    rate_parts="${rate_parts}  ${SEP}  ${seven_str}"
  else
    rate_parts="$seven_str"
  fi
fi

# ---------------------------------------------------------------------------
# Assemble the line
# ---------------------------------------------------------------------------
line="${model_str}  ${SEP}  ${dir_str}"

if [ -n "$git_str" ]; then
  line="${line}  ${SEP}  ${git_str}"
fi

if [ -n "$repo_str" ]; then
  line="${line}  ${SEP}  ${repo_str}"
fi

line="${line}  ${SEP}  ${ctx_str}"

if [ -n "$lines_str" ]; then
  line="${line}  ${SEP}  ${lines_str}"
fi

printf "%b\n" "$line"
[ -n "$rate_parts" ] && printf "%b\n" "$rate_parts"
