#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

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

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

# ---------------------------------------------------------------------------
# Node.js 20+
# ---------------------------------------------------------------------------

NODE_MAJOR=0
if command -v node &>/dev/null; then
    NODE_MAJOR="$(node --version | sed 's/v//' | cut -d. -f1)"
fi

if [ "${NODE_MAJOR}" -lt 20 ]; then
    echo "Node.js 20+ not found, installing..."
    if command -v apk &>/dev/null; then
        _install_pkg nodejs npm
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y --no-install-recommends nodejs
    fi
    echo "Node.js $(node --version) installed."
fi

# ---------------------------------------------------------------------------
# AgentCore CLI
# ---------------------------------------------------------------------------

echo "Installing AWS AgentCore CLI..."
npm install -g @aws/agentcore

if command -v agentcore &>/dev/null; then
    echo "AgentCore CLI $(agentcore --version 2>&1 | head -1) installed."
else
    echo "Warning: agentcore command not found after installation."
fi

rm -rf /var/lib/apt/lists/*
echo "Done!"
