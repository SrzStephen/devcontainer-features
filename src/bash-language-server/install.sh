#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

VERSION="${VERSION:-"latest"}"
INSTALL_SHELLCHECK="${INSTALLSHELLCHECK:-"true"}"
INSTALL_SHELLFMT="${INSTALLSHELLFMT:-"true"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Dependencies: Node.js / npm
# ---------------------------------------------------------------------------

if ! command -v npm &>/dev/null; then
    echo "npm not found, installing Node.js..."
    if command -v apk &>/dev/null; then
        apk add --no-cache nodejs npm
    else
        if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
            apt-get update -y
        fi
        apt-get install -y --no-install-recommends nodejs npm
    fi
fi

# ---------------------------------------------------------------------------
# Install bash-language-server
# ---------------------------------------------------------------------------

if [ "${VERSION}" = "latest" ]; then
    echo "Installing bash-language-server (latest)..."
    npm install -g bash-language-server
else
    echo "Installing bash-language-server@${VERSION}..."
    npm install -g "bash-language-server@${VERSION}"
fi

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

if command -v bash-language-server &>/dev/null; then
    echo "bash-language-server $(bash-language-server --version 2>/dev/null || true) installed."
else
    echo "Warning: bash-language-server not found on PATH after installation." >&2
fi

# ---------------------------------------------------------------------------
# Optional: install shellcheck binary
# ---------------------------------------------------------------------------

if [ "${INSTALL_SHELLCHECK}" = "true" ]; then
    if command -v shellcheck &>/dev/null; then
        echo "shellcheck already installed at $(command -v shellcheck), skipping."
    else
        echo "Installing shellcheck..."
        if command -v apk &>/dev/null; then
            apk add --no-cache shellcheck
        else
            if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
                apt-get update -y
            fi
            apt-get install -y --no-install-recommends shellcheck
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Optional: install shellfmt (shfmt) binary
# ---------------------------------------------------------------------------

if [ "${INSTALL_SHELLFMT}" = "true" ]; then
    if command -v shfmt &>/dev/null; then
        echo "shfmt already installed at $(command -v shfmt), skipping."
    else
        echo "Installing shfmt..."
        if command -v apk &>/dev/null; then
            apk add --no-cache shfmt
        else
            if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
                apt-get update -y
            fi
            apt-get install -y --no-install-recommends shfmt
        fi
    fi
fi

rm -rf /var/lib/apt/lists/*

echo "Done!"
