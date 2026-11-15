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
#   user); curl, tar and sha256sum on PATH; the SKILLS variable (comma-separated
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
# distro packages. Install the latest Node 22 release into /usr/local from the
# official tarball (nodejs.org, or the unofficial musl builds on Alpine),
# verifying the published SHA-256 checksum. Skipped when a suitable node and npx
# are already present.
_ensure_node() {
    local _nodever="" _major=0 _minor=0 _arch _base _suffix="" _ver _file _sums _expected _tmp
    if command -v node &>/dev/null && command -v npx &>/dev/null; then
        _nodever="$(node -p 'process.versions.node' 2>/dev/null || true)"
        _major="${_nodever%%.*}"
        _minor="${_nodever#*.}"
        _minor="${_minor%%.*}"
        if [ "${_major:-0}" -gt 22 ] 2>/dev/null ||
            { [ "${_major:-0}" -eq 22 ] && [ "${_minor:-0}" -ge 20 ]; } 2>/dev/null; then
            return 0
        fi
    fi

    case "$(uname -m)" in
        x86_64) _arch=x64 ;;
        aarch64 | arm64) _arch=arm64 ;;
        *) echo "ERROR: unsupported architecture for Node.js install: $(uname -m)" >&2; return 1 ;;
    esac
    _base="https://nodejs.org/dist"
    if command -v apk &>/dev/null; then
        _base="https://unofficial-builds.nodejs.org/download/release"
        _suffix="-musl"
        apk add --no-cache libstdc++
    fi

    _ver="$(curl -fsSL "https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt" | grep -oE 'node-v22\.[0-9]+\.[0-9]+' | head -1 | sed 's/^node-//')"
    [ -n "${_ver}" ] || { echo "ERROR: could not determine latest Node.js 22 version" >&2; return 1; }
    _file="node-${_ver}-linux-${_arch}${_suffix}.tar.gz"
    _sums="$(curl -fsSL "${_base}/${_ver}/SHASUMS256.txt")"
    _expected="$(printf '%s\n' "${_sums}" | grep " ${_file}\$" | cut -d' ' -f1)"
    [ -n "${_expected}" ] || { echo "ERROR: no checksum published for ${_file}" >&2; return 1; }

    _tmp="$(mktemp -d)"
    echo "Installing Node.js ${_ver} (${_arch}${_suffix})..."
    if ! curl -fsSL -o "${_tmp}/${_file}" "${_base}/${_ver}/${_file}"; then
        echo "ERROR: failed to download ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    if [ "$(sha256sum "${_tmp}/${_file}" | cut -d' ' -f1)" != "${_expected}" ]; then
        echo "ERROR: checksum mismatch for ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    if ! tar -xzf "${_tmp}/${_file}" -C /usr/local --strip-components=1 --no-same-owner \
        --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'; then
        echo "ERROR: failed to extract ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    rm -rf "${_tmp}"
}

# install_skills <agent>: install each SKILLS entry for the given agent id using
# the skills CLI. Does nothing (and installs no Node) when SKILLS is blank.
install_skills() {
    local _agent="$1" _entry
    local -a _entries
    validate_skills || return 1
    mapfile -t _entries < <(_skills_entries)
    [ "${#_entries[@]}" -gt 0 ] || return 0

    _ensure_node
    for _entry in "${_entries[@]}"; do
        echo "Installing skills: ${_entry} (agent: ${_agent})"
        run_as_user "npx -y skills add ${_entry} -g -y -a ${_agent}"
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
