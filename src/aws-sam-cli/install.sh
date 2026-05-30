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

# The official SAM CLI Linux installer requires glibc; Alpine (musl) is not supported.
if command -v apk &>/dev/null; then
    echo "(!) The AWS SAM CLI official Linux installer requires glibc and is not compatible with Alpine Linux."
    exit 1
fi

case "$(uname -m)" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
    *)
        echo "(!) Architecture $(uname -m) is not supported."
        exit 1
        ;;
esac

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

if ! command -v unzip &>/dev/null; then
    _install_pkg unzip
fi

# ---------------------------------------------------------------------------
# AWS SAM CLI
# ---------------------------------------------------------------------------

echo "Downloading AWS SAM CLI for ${ARCH}..."
tmp="$(mktemp -d)"
sam_url="https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-${ARCH}.zip"

for attempt in 1 2 3; do
    if curl -fsSL "${sam_url}" -o "${tmp}/aws-sam-cli.zip"; then
        break
    elif [ "${attempt}" -lt 3 ]; then
        echo "Download attempt ${attempt} failed, retrying in 5s..."
        sleep 5
    else
        echo "ERROR: Failed to download AWS SAM CLI after 3 attempts."
        exit 1
    fi
done

unzip -q "${tmp}/aws-sam-cli.zip" -d "${tmp}/sam-installation"
"${tmp}/sam-installation/install"
rm -rf "${tmp}"

rm -rf /var/lib/apt/lists/*

if command -v sam &>/dev/null; then
    echo "AWS SAM CLI $(sam --version) installed."
else
    echo "Warning: sam command not found after installation."
fi

echo "Done!"
