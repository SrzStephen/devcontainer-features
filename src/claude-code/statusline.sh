#!/bin/bash
# Claude Code status line script
# Drop this in ~/.claude/statusline-command.sh and wire it up in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" } }
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
# 1. Model name  — shorten "Claude X.Y Zname" → "zname-X.Y"
# ---------------------------------------------------------------------------
model_display=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"')

# Convert e.g. "Claude 3.5 Sonnet" → "sonnet-3.5", "Claude Sonnet 4.6" → "sonnet-4.6"
# Strategy: lowercase, strip leading "claude ", then rearrange "name ver" → "name-ver"
model_short=$(printf '%s' "$model_display" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/^claude[[:space:]]*//' \
  | sed -E 's/^([a-z]+)[[:space:]]+([0-9]+\.[0-9]+)$/\1-\2/' \
  | sed -E 's/^([0-9]+\.[0-9]+)[[:space:]]+([a-z]+)$/\2-\1/')

model_str="${bold}${fg_cyan} ${model_short}${reset}"

# ---------------------------------------------------------------------------
# 2. Git branch / worktree
# ---------------------------------------------------------------------------
git_worktree=$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')

if [ -n "$git_worktree" ]; then
  branch_name="$git_worktree"
else
  # Fall back to reading git directly from the cwd
  branch_name=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

if [ -n "$branch_name" ]; then
  git_str="${fg_magenta} ${branch_name}${reset}"
else
  git_str=""
fi

# ---------------------------------------------------------------------------
# 3. Context window bar + token breakdown
# ---------------------------------------------------------------------------
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

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

  ctx_str="${bar_color}${bar} ${used_int}%${reset}"

  # Token breakdown — only available after the first API call
  tok_in=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.input_tokens               // empty')
  tok_cr=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.cache_read_input_tokens     // empty')
  tok_cw=$(printf '%s' "$input"  | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
  tok_out=$(printf '%s' "$input" | jq -r '.context_window.current_usage.output_tokens               // empty')

  if [ -n "$tok_in" ]; then
    # in: fresh input (white)  cr: cache read / green (cheap)  cw: cache write / yellow  out: dim
    tok_str="${fg_white}in:$(_fmt_k "$tok_in")${reset} ${fg_green}cr:$(_fmt_k "$tok_cr")${reset} ${fg_yellow}cw:$(_fmt_k "$tok_cw")${reset} ${dim}out:$(_fmt_k "$tok_out")${reset}"
    ctx_str="${ctx_str}  ${tok_str}"
  fi
else
  ctx_str="${fg_grey}ctx: --${reset}"
fi

# ---------------------------------------------------------------------------
# 3b. Lines added / deleted
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
# 4. Effort level
# ---------------------------------------------------------------------------
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')

if [ -n "$effort" ]; then
  case "$effort" in
    low)    effort_icon="▱▱▱" ; effort_color="$fg_grey"   ;;
    medium) effort_icon="▰▱▱" ; effort_color="$fg_yellow"  ;;
    high)   effort_icon="▰▰▱" ; effort_color="$fg_orange"  ;;
    xhigh)  effort_icon="▰▰▰" ; effort_color="$fg_red"     ;;
    max)    effort_icon="▰▰▰" ; effort_color="${bold}${fg_red}" ;;
    *)      effort_icon="$effort" ; effort_color="$fg_grey" ;;
  esac
  effort_str="${effort_color} ${effort_icon}${reset}"
else
  effort_str=""
fi

# ---------------------------------------------------------------------------
# 5 & 6. Rate limits
# ---------------------------------------------------------------------------
five_pct=$(printf '%s' "$input"      | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at       // empty')
seven_pct=$(printf '%s' "$input"     | jq -r '.rate_limits.seven_day.used_percentage  // empty')

rate_parts=""

if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  if   [ "$five_int" -ge 80 ]; then rc="$fg_red"
  elif [ "$five_int" -ge 50 ]; then rc="$fg_orange"
  else                               rc="$fg_green"
  fi

  five_reset_str=""
  if [ -n "$five_resets_at" ]; then
    reset_epoch=$(date -d "$five_resets_at" +%s 2>/dev/null)
    if [ -n "$reset_epoch" ]; then
      diff_secs=$(( reset_epoch - $(date +%s) ))
      if [ "$diff_secs" -gt 0 ]; then
        hours_left=$(awk "BEGIN { printf \"%.1f\", $diff_secs / 3600 }")
        five_reset_str=" ${dim}↻${hours_left}h${reset}"
      fi
    fi
  fi

  rate_parts="${rc}5h:${five_int}%${reset}${five_reset_str}"
fi

if [ -n "$seven_pct" ]; then
  seven_int=$(printf '%.0f' "$seven_pct")
  if   [ "$seven_int" -ge 80 ]; then rc="$fg_red"
  elif [ "$seven_int" -ge 50 ]; then rc="$fg_orange"
  else                               rc="$fg_green"
  fi
  if [ -n "$rate_parts" ]; then
    rate_parts="${rate_parts} ${fg_dark}·${reset} ${rc}7d:${seven_int}%${reset}"
  else
    rate_parts="${rc}7d:${seven_int}%${reset}"
  fi
fi

if [ -n "$rate_parts" ]; then
  rate_str=" ${rate_parts}"
else
  rate_str=""
fi

# ---------------------------------------------------------------------------
# Assemble the line
# ---------------------------------------------------------------------------
line="${model_str}"

if [ -n "$git_str" ]; then
  line="${line}  ${SEP}  ${git_str}"
fi

line="${line}  ${SEP}  ${ctx_str}"

if [ -n "$lines_str" ]; then
  line="${line}  ${SEP}  ${lines_str}"
fi

if [ -n "$effort_str" ]; then
  line="${line}  ${SEP}  ${effort_str}"
fi

if [ -n "$rate_str" ]; then
  line="${line}  ${SEP} ${rate_str}"
fi

printf "%b\n" "$line"
