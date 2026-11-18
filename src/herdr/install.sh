#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

PLUGINS="${PLUGINS:-""}"

REMOTE_USER="${_REMOTE_USER:-"vscode"}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-"/home/${REMOTE_USER}"}"
# The herdr installer puts the binary here unless HERDR_INSTALL_DIR is set.
HERDR_BIN="${REMOTE_USER_HOME}/.local/bin/herdr"

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
# with a dash, which the herdr CLI would parse as an option.
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

# Install each PLUGINS entry (owner/repo[/subdir]) from GitHub. A failing
# install (for example an unknown repository) aborts the build.
install_herdr_plugins() {
    local _entry
    while IFS= read -r _entry; do
        echo "Installing herdr plugin: ${_entry}"
        if ! run_as_user "${HERDR_BIN} plugin install ${_entry} --yes"; then
            echo "ERROR: failed to install herdr plugin: ${_entry}" >&2
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

# `herdr plugin install` clones plugin repositories with git.
if ! command -v git &>/dev/null; then
    _install_pkg git ca-certificates
fi

# ---------------------------------------------------------------------------
# Install herdr
# ---------------------------------------------------------------------------

echo "Installing herdr via https://herdr.dev/install.sh..."
if ! run_as_user 'curl -fsSL https://herdr.dev/install.sh | sh'; then
    echo "ERROR: the herdr installer failed." >&2
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

if [ ! -x "${HERDR_BIN}" ]; then
    echo "ERROR: herdr binary not found at ${HERDR_BIN} after installation." >&2
    exit 1
fi
echo "$(run_as_user "${HERDR_BIN} --version" | head -1) installed."

install_herdr_plugins

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "Done!"
