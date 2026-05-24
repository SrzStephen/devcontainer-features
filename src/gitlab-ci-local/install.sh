#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

GCL_VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Resolve "latest", "4", or "4.72" to a full version; pass through "4.72.0".
resolve_version() {
    local repo="$1" version="$2" tmp dot_count
    tmp="$(mktemp)"
    if [ "${version}" = "latest" ]; then
        curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" -o "${tmp}"
        grep -m1 '"tag_name"' "${tmp}" | cut -d'"' -f4 | sed 's/^v//'
    else
        dot_count="$(printf '%s' "${version}" | tr -cd '.' | wc -c)"
        if [ "${dot_count}" -lt 2 ]; then
            curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=100" -o "${tmp}"
            grep '"tag_name"' "${tmp}" | cut -d'"' -f4 | sed 's/^v//' | grep -m1 "^${version//./\\.}\\."
        else
            echo "${version}"
        fi
    fi
    rm -f "${tmp}"
}

export DEBIAN_FRONTEND=noninteractive

ARCH="$(uname -m)"

# Detect musl libc (Alpine and similar).
_is_musl() {
    ls /lib/ld-musl-* >/dev/null 2>&1
}

if command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl ca-certificates gcompat
else
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y
    fi
    apt-get install -y --no-install-recommends curl ca-certificates
fi

GCL_VERSION="$(resolve_version firecow/gitlab-ci-local "${GCL_VERSION}")"

# The pre-built binary is glibc-linked. On musl+aarch64 (Alpine arm64), gcompat
# is insufficient — fall back to npm which works on all libcs.
if _is_musl && [ "${ARCH}" = "aarch64" ]; then
    echo "Detected musl libc on aarch64 — installing gitlab-ci-local ${GCL_VERSION} via npm..."
    if ! command -v npm >/dev/null 2>&1; then
        apk add --no-cache nodejs npm
    fi
    npm install -g "gitlab-ci-local@${GCL_VERSION}"
else
    case "${ARCH}" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)
            echo "(!) Architecture ${ARCH} unsupported"
            exit 1
            ;;
    esac
    echo "Downloading gitlab-ci-local ${GCL_VERSION}..."
    tmp="$(mktemp -d)"
    archive="${tmp}/gitlab-ci-local.tar.gz"
    gcl_url="https://github.com/firecow/gitlab-ci-local/releases/download/${GCL_VERSION}/gitlab-ci-local-linux-${ARCH}.tar.gz"
    for attempt in 1 2 3; do
        if curl -fsSL "${gcl_url}" -o "${archive}"; then
            break
        elif [ "${attempt}" -lt 3 ]; then
            echo "Download attempt ${attempt} failed, retrying in 5s..."
            sleep 5
        else
            echo "ERROR: Failed to download gitlab-ci-local after 3 attempts"
            exit 1
        fi
    done
    tar xzf "${archive}" -C "${tmp}"
    mv "${tmp}/gitlab-ci-local" /usr/local/bin/gitlab-ci-local
    rm -rf "${tmp}"
fi

rm -rf /var/lib/apt/lists/*

echo "gitlab-ci-local ${GCL_VERSION} installed."
echo "Done!"
