#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

MARKETPLACE="${MARKETPLACE:-""}"
PLUGIN="${PLUGIN:-""}"
REMOVE_ATTRIBUTION="${REMOVEATTRIBUTION:-"false"}"
STATUSLINE="${STATUSLINE:-"false"}"
PLAN_MODE="${PLANMODE:-"false"}"
DEFAULT_TO_AGENTS_VIEW="${DEFAULTTOAGENTSVIEW:-"true"}"
SKILLS="${SKILLS:-""}"

REMOTE_USER="${_REMOTE_USER:-"vscode"}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-"/home/${REMOTE_USER}"}"
CLAUDE_BIN="${REMOTE_USER_HOME}/.local/bin/claude"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

run_as_user() {
    if command -v runuser &>/dev/null; then
        runuser -l "${REMOTE_USER}" -c "${*}"
    else
        su -l "${REMOTE_USER}" -c "${*}"
    fi
}

# Normalise a GitHub reference for the claude CLI.
# Full HTTPS URLs pass through unchanged; owner/repo shorthands are expanded
# to full HTTPS so git clones use HTTPS (SSH keys are unavailable during
# container builds); other values (e.g. plugin@marketplace) pass through.
normalize_gh_ref() {
    local ref="$1"
    case "$ref" in
        https://*|http://*) echo "$ref" ;;
        */*) echo "https://github.com/${ref}" ;;
        *) echo "$ref" ;;
    esac
}

# Reject refs containing shell metacharacters before they are interpolated into
# the command string passed to su/runuser, preventing command injection from
# untrusted option values.
validate_ref() {
    local ref="$1"
    if ! printf '%s' "$ref" | grep -qE '^[A-Za-z0-9._/:@~+-]+$'; then
        echo "ERROR: refusing unsafe reference (only A-Za-z0-9 . _ / : @ ~ + - are allowed): ${ref}" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

_install_pkg() {
    if command -v apk &>/dev/null; then
        apk add --no-cache "$@"
    else
        if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
            apt-get update -y
        fi
        apt-get install -y --no-install-recommends "$@"
    fi
}

# ---------------------------------------------------------------------------
# Agent skills (canonical helpers, shared verbatim across features)
#
# requires: bash with set -e; run_as_user (runs a command string as the remote
#   user); curl and sha256sum on PATH; the SKILLS variable (comma-separated
#   list, may be empty or unset). Usage: validate_skills early, then
#   install_skills <agent> once the agent itself is installed.
# ---------------------------------------------------------------------------

# Print each non-blank, whitespace-trimmed entry of the comma-separated SKILLS
# option on its own line.
_skills_entries() {
    local _entry
    local -a _raw
    IFS=',' read -ra _raw <<< "${SKILLS:-}"
    for _entry in "${_raw[@]}"; do
        _entry="${_entry#"${_entry%%[![:space:]]*}"}"
        _entry="${_entry%"${_entry##*[![:space:]]}"}"
        [ -n "${_entry}" ] && printf '%s\n' "${_entry}"
    done
    return 0
}

# Fail before anything runs if any SKILLS entry contains characters outside the
# allow-list, since entries are interpolated into a shell command string, or
# starts with a dash, which the skills CLI would parse as an option.
validate_skills() {
    local _entry
    while IFS= read -r _entry; do
        if [ "${_entry:0:1}" = "-" ]; then
            echo "ERROR: refusing unsafe skills entry (must not start with a dash): ${_entry}" >&2
            return 1
        fi
        if ! printf '%s' "${_entry}" | grep -qE '^[A-Za-z0-9._/:@~+-]+$'; then
            echo "ERROR: refusing unsafe skills entry (only A-Za-z0-9 . _ / : @ ~ + - are allowed): ${_entry}" >&2
            return 1
        fi
    done < <(_skills_entries)
}

# The skills CLI requires Node.js >= 22.20, newer than the Debian and Alpine
# distro packages. An existing npm is reused when its node is new enough;
# otherwise nvm (pinned and checksum-verified) is downloaded into
# /usr/local/share/nvm and installs the latest Node 22 release (the unofficial
# musl builds on Alpine), and node, npm and npx are linked into /usr/local/bin.
NVM_VERSION="v0.41.0"
NVM_SHA256="e7ffd3d192735da61e5eb04e68f1aca4a293af4cd0000864568d6de7aa8f6fc4"

_node_ok() {
    local _nodever _major _minor
    command -v node &>/dev/null || return 1
    _nodever="$(node -p 'process.versions.node' 2>/dev/null || true)"
    _major="${_nodever%%.*}"
    _minor="${_nodever#*.}"
    _minor="${_minor%%.*}"
    [ "${_major:-0}" -gt 22 ] 2>/dev/null ||
        { [ "${_major:-0}" -eq 22 ] && [ "${_minor:-0}" -ge 20 ]; } 2>/dev/null
}

_ensure_npm() {
    local _nvm_dir=/usr/local/share/nvm _node_bin _tool
    if command -v npm &>/dev/null && _node_ok; then
        return 0
    fi
    if command -v npm &>/dev/null; then
        echo "Existing npm found, but its Node.js is older than 22.20; installing Node 22 with nvm"
    fi

    if command -v apk &>/dev/null; then
        apk add --no-cache libstdc++
    fi

    echo "Installing nvm ${NVM_VERSION}..."
    mkdir -p "${_nvm_dir}"
    if ! curl -fsSL -o "${_nvm_dir}/nvm.sh" "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/nvm.sh"; then
        echo "ERROR: failed to download nvm ${NVM_VERSION}" >&2
        return 1
    fi
    if [ "$(sha256sum "${_nvm_dir}/nvm.sh" | cut -d' ' -f1)" != "${NVM_SHA256}" ]; then
        echo "ERROR: checksum mismatch for nvm ${NVM_VERSION}" >&2
        rm -f "${_nvm_dir}/nvm.sh"
        return 1
    fi

    # nvm.sh is not safe under set -e, so drive it from a separate shell.
    # shellcheck disable=SC2016
    if ! _node_bin="$(NVM_DIR="${_nvm_dir}" bash -c '
        if [ -f /etc/alpine-release ]; then
            export NVM_NODEJS_ORG_MIRROR=https://unofficial-builds.nodejs.org/download/release
        fi
        . "${NVM_DIR}/nvm.sh" --no-use || exit 1
        nvm install 22 >&2 || exit 1
        dirname "$(command -v node)"
    ')" || [ ! -x "${_node_bin}/node" ]; then
        echo "ERROR: nvm failed to install Node.js 22" >&2
        return 1
    fi
    for _tool in node npm npx; do
        ln -sf "${_node_bin}/${_tool}" "/usr/local/bin/${_tool}"
    done
    hash -r
}

# install_skills <agent>: install each SKILLS entry for the given agent id using
# the skills CLI, installed globally with npm. Does nothing (and installs no
# Node) when SKILLS is blank.
install_skills() {
    local _agent="$1" _entry
    local -a _entries
    validate_skills || return 1
    mapfile -t _entries < <(_skills_entries)
    [ "${#_entries[@]}" -gt 0 ] || return 0

    _ensure_npm
    if ! command -v skills &>/dev/null; then
        echo "Installing the skills CLI with npm..."
        npm install -g --prefix /usr/local skills
    fi
    for _entry in "${_entries[@]}"; do
        echo "Installing skills: ${_entry} (agent: ${_agent})"
        run_as_user "skills add ${_entry} -g -y -a ${_agent}"
    done
}

validate_skills

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

if { [ -n "${MARKETPLACE}" ] || [ -n "${PLUGIN}" ]; } && ! command -v git &>/dev/null; then
    _install_pkg git ca-certificates
fi

if { [ "${REMOVE_ATTRIBUTION}" = "true" ] || [ "${STATUSLINE}" = "true" ] || [ "${PLAN_MODE}" = "true" ] || [ -n "${DEFAULT_TO_AGENTS_VIEW}" ] || [ -n "${MARKETPLACE}" ] || [ -n "${PLUGIN}" ]; } && ! command -v jq &>/dev/null; then
    _install_pkg jq
fi

# ---------------------------------------------------------------------------
# Install Claude Code
# ---------------------------------------------------------------------------

echo "Installing Claude Code via https://claude.ai/install.sh..."
run_as_user 'curl -fsSL https://claude.ai/install.sh | bash'

# Ensure ~/.local/bin is on PATH in login and interactive shells.
for _dotfile in "${REMOTE_USER_HOME}/.profile" "${REMOTE_USER_HOME}/.bashrc"; do
    if ! grep -q '\.local/bin' "${_dotfile}" 2>/dev/null; then
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${_dotfile}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${_dotfile}"
    fi
done
unset _dotfile

if [ -x "${CLAUDE_BIN}" ]; then
    echo "Claude Code $(run_as_user "${CLAUDE_BIN} --version") installed."
else
    echo "Warning: claude binary not found at ${CLAUDE_BIN} after installation."
fi

# ---------------------------------------------------------------------------
# Attribution
# ---------------------------------------------------------------------------

if [ "${REMOVE_ATTRIBUTION}" = "true" ]; then
    CLAUDE_SETTINGS="${REMOTE_USER_HOME}/.claude/settings.json"
    CLAUDE_SETTINGS_DIR="$(dirname "${CLAUDE_SETTINGS}")"

    mkdir -p "${CLAUDE_SETTINGS_DIR}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}"

    if [ -f "${CLAUDE_SETTINGS}" ] && jq -e '.attribution' "${CLAUDE_SETTINGS}" &>/dev/null; then
        echo "Attribution already configured in ${CLAUDE_SETTINGS}, skipping."
    elif [ -f "${CLAUDE_SETTINGS}" ]; then
        tmp=$(mktemp)
        jq '. + {"attribution": {"commit": "", "pr": ""}}' "${CLAUDE_SETTINGS}" > "${tmp}"
        mv "${tmp}" "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Attribution removed from Claude settings."
    else
        printf '{"attribution":{"commit":"","pr":""}}\n' > "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Attribution removed from Claude settings."
    fi
fi

# ---------------------------------------------------------------------------
# Plan Mode
# ---------------------------------------------------------------------------

if [ "${PLAN_MODE}" = "true" ]; then
    CLAUDE_SETTINGS="${REMOTE_USER_HOME}/.claude/settings.json"
    CLAUDE_SETTINGS_DIR="$(dirname "${CLAUDE_SETTINGS}")"

    mkdir -p "${CLAUDE_SETTINGS_DIR}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}"

    if [ -f "${CLAUDE_SETTINGS}" ] && jq -e '.permissions.defaultMode' "${CLAUDE_SETTINGS}" &>/dev/null; then
        echo "permissions.defaultMode already configured in ${CLAUDE_SETTINGS}, skipping."
    elif [ -f "${CLAUDE_SETTINGS}" ]; then
        tmp=$(mktemp)
        jq '. + {"permissions": (.permissions // {} | . + {"defaultMode": "plan"})}' "${CLAUDE_SETTINGS}" > "${tmp}"
        mv "${tmp}" "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Plan mode set as default in ${CLAUDE_SETTINGS}."
    else
        printf '{"permissions":{"defaultMode":"plan"}}\n' > "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Plan mode set as default in ${CLAUDE_SETTINGS}."
    fi
fi

# ---------------------------------------------------------------------------
# Default to agents view
# ---------------------------------------------------------------------------

case "${DEFAULT_TO_AGENTS_VIEW}" in
    true | false) ;;
    *) echo "ERROR: defaultToAgentsView must be 'true' or 'false', got: ${DEFAULT_TO_AGENTS_VIEW}" >&2; exit 1 ;;
esac

CLAUDE_SETTINGS="${REMOTE_USER_HOME}/.claude/settings.json"
CLAUDE_SETTINGS_DIR="$(dirname "${CLAUDE_SETTINGS}")"

mkdir -p "${CLAUDE_SETTINGS_DIR}"
chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}"

if [ -f "${CLAUDE_SETTINGS}" ] && jq -e 'has("defaultToAgentsView")' "${CLAUDE_SETTINGS}" &>/dev/null; then
    echo "defaultToAgentsView already configured in ${CLAUDE_SETTINGS}, skipping."
elif [ -f "${CLAUDE_SETTINGS}" ]; then
    tmp=$(mktemp)
    jq --argjson v "${DEFAULT_TO_AGENTS_VIEW}" '. + {"defaultToAgentsView": $v}' "${CLAUDE_SETTINGS}" > "${tmp}"
    mv "${tmp}" "${CLAUDE_SETTINGS}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
    echo "defaultToAgentsView set to ${DEFAULT_TO_AGENTS_VIEW} in ${CLAUDE_SETTINGS}."
else
    printf '{"defaultToAgentsView":%s}\n' "${DEFAULT_TO_AGENTS_VIEW}" > "${CLAUDE_SETTINGS}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
    echo "defaultToAgentsView set to ${DEFAULT_TO_AGENTS_VIEW} in ${CLAUDE_SETTINGS}."
fi

# ---------------------------------------------------------------------------
# Statusline
# ---------------------------------------------------------------------------

if [ "${STATUSLINE}" = "true" ]; then
    CLAUDE_SETTINGS="${REMOTE_USER_HOME}/.claude/settings.json"
    CLAUDE_SETTINGS_DIR="$(dirname "${CLAUDE_SETTINGS}")"
    SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

    mkdir -p "${CLAUDE_SETTINGS_DIR}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}"

    cp "${SCRIPT_DIR}/statusline.sh" "${CLAUDE_SETTINGS_DIR}/statusline-command.sh"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}/statusline-command.sh"
    chmod +x "${CLAUDE_SETTINGS_DIR}/statusline-command.sh"
    echo "Statusline script installed to ${CLAUDE_SETTINGS_DIR}/statusline-command.sh."

    if [ -f "${CLAUDE_SETTINGS}" ] && jq -e '.statusLine' "${CLAUDE_SETTINGS}" &>/dev/null; then
        echo "statusLine already configured in ${CLAUDE_SETTINGS}, skipping."
    elif [ -f "${CLAUDE_SETTINGS}" ]; then
        tmp=$(mktemp)
        jq '. + {"statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}}' "${CLAUDE_SETTINGS}" > "${tmp}"
        mv "${tmp}" "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "statusLine configured in ${CLAUDE_SETTINGS}."
    else
        printf '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}\n' > "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "statusLine configured in ${CLAUDE_SETTINGS}."
    fi
fi

# ---------------------------------------------------------------------------
# Marketplace
# ---------------------------------------------------------------------------

if [ -n "${MARKETPLACE}" ]; then
    IFS=',' read -ra _marketplaces <<< "${MARKETPLACE}"
    for _m in "${_marketplaces[@]}"; do
        _m="$(echo "$_m" | xargs)"
        [ -z "$_m" ] && continue
        _m_ref=$(normalize_gh_ref "$_m")
        validate_ref "$_m_ref"
        echo "Adding plugin marketplace: ${_m_ref}"
        run_as_user "${CLAUDE_BIN} plugin marketplace add ${_m_ref}"
    done
fi

# ---------------------------------------------------------------------------
# Plugin
# ---------------------------------------------------------------------------

if [ -n "${PLUGIN}" ]; then
    IFS=',' read -ra _plugins <<< "${PLUGIN}"
    for _p in "${_plugins[@]}"; do
        _p="$(echo "$_p" | xargs)"
        [ -z "$_p" ] && continue
        _p_ref=$(normalize_gh_ref "$_p")
        validate_ref "$_p_ref"
        echo "Installing plugin: ${_p_ref}"
        run_as_user "${CLAUDE_BIN} plugin install ${_p_ref}"
    done
fi

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

install_skills claude-code

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "Done!"
