#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

PLUGINS="${PLUGINS:-""}"
SKILLS="${SKILLS:-""}"

REMOTE_USER="${_REMOTE_USER:-"vscode"}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-"/home/${REMOTE_USER}"}"
HERMES_BIN="${REMOTE_USER_HOME}/.local/bin/hermes"

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

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

# Print each non-blank, whitespace-trimmed entry of the comma-separated PLUGINS
# option on its own line.
_plugins_entries() {
    local _entry
    local -a _raw
    IFS=',' read -ra _raw <<< "${PLUGINS:-}"
    for _entry in "${_raw[@]}"; do
        _entry="${_entry#"${_entry%%[![:space:]]*}"}"
        _entry="${_entry%"${_entry##*[![:space:]]}"}"
        [ -n "${_entry}" ] && printf '%s\n' "${_entry}"
    done
    return 0
}

# Fail before anything runs if any PLUGINS entry contains characters outside the
# allow-list (entries are interpolated into a shell command string) or starts
# with a dash, which the hermes CLI would parse as an option.
validate_plugins() {
    local _entry
    while IFS= read -r _entry; do
        if [ "${_entry:0:1}" = "-" ]; then
            echo "ERROR: refusing unsafe plugins entry (must not start with a dash): ${_entry}" >&2
            return 1
        fi
        if ! printf '%s' "${_entry}" | grep -qE '^[A-Za-z0-9._/:@~+-]+$'; then
            echo "ERROR: refusing unsafe plugins entry (only A-Za-z0-9 . _ / : @ ~ + - are allowed): ${_entry}" >&2
            return 1
        fi
    done < <(_plugins_entries)
}

# Install and enable each PLUGINS entry. A failing install (for example an
# unknown catalog name) aborts the build.
install_hermes_plugins() {
    local _entry
    while IFS= read -r _entry; do
        echo "Installing Hermes plugin: ${_entry}"
        if ! run_as_user "${HERMES_BIN} plugins install ${_entry} --enable"; then
            echo "ERROR: failed to install Hermes plugin: ${_entry}" >&2
            return 1
        fi
    done < <(_plugins_entries)
}

validate_plugins

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

# The Hermes installer clones its checkout with git.
if ! command -v git &>/dev/null; then
    _install_pkg git ca-certificates
fi

# On musl hosts the Node.js runtime Hermes downloads needs the system libstdc++.
if command -v apk &>/dev/null; then
    apk add --no-cache libstdc++
fi

# ---------------------------------------------------------------------------
# Install Hermes Agent
# ---------------------------------------------------------------------------

# --non-interactive skips the setup wizard; --skip-browser and
# --skip-computer-use leave out the Chromium and cua-driver downloads (undo
# later with `hermes pm install chromium` / `hermes pm install cua-driver`).
echo "Installing Hermes Agent via https://hermes-agent.nousresearch.com/install.sh..."
if ! run_as_user 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive --skip-browser --skip-computer-use'; then
    echo "ERROR: the Hermes Agent installer failed." >&2
    exit 1
fi

# Ensure ~/.local/bin is on PATH in login and interactive shells.
for _dotfile in "${REMOTE_USER_HOME}/.profile" "${REMOTE_USER_HOME}/.bashrc"; do
    if ! grep -q '\.local/bin' "${_dotfile}" 2>/dev/null; then
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${_dotfile}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${_dotfile}"
    fi
done
unset _dotfile

if [ ! -x "${HERMES_BIN}" ]; then
    echo "ERROR: hermes binary not found at ${HERMES_BIN} after installation." >&2
    exit 1
fi
echo "$(run_as_user "${HERMES_BIN} --version" | head -1) installed."

install_hermes_plugins

install_skills hermes-agent

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "Done!"
