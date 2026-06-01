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

# Resolve a version. "latest" is resolved via the github.com releases/latest
# redirect (no GitHub API); any other value is treated as an exact version and
# passed through unchanged. Partial versions are not supported.
resolve_version() {
    local repo="$1" version="$2" result
    if [ "${version}" = "latest" ]; then
        result="$(curl -fsSL "https://github.com/${repo}/releases/latest" \
            -o /dev/null -w '%{url_effective}' | sed 's|.*/||; s/^v//' || true)"
    else
        result="${version}"
    fi
    if [ -z "${result}" ]; then
        echo "ERROR: Failed to resolve version for ${repo}" >&2
        return 1
    fi
    echo "${result}"
}

# Download a URL to a destination with up to 3 retries.
download() {
    local url="$1" dest="$2" attempt
    for attempt in 1 2 3; do
        if curl -fsSL "${url}" -o "${dest}"; then
            return 0
        elif [ "${attempt}" -lt 3 ]; then
            echo "Download attempt ${attempt} failed, retrying in 5s..." >&2
            sleep 5
        fi
    done
    echo "ERROR: Failed to download ${url} after 3 attempts" >&2
    return 1
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
    # Upstream does not publish a checksums file for these release assets, so no
    # integrity verification is possible here beyond HTTPS transport.
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    archive="${tmp}/gitlab-ci-local.tar.gz"
    gcl_url="https://github.com/firecow/gitlab-ci-local/releases/download/${GCL_VERSION}/gitlab-ci-local-linux-${ARCH}.tar.gz"
    download "${gcl_url}" "${archive}"
    tar xzf "${archive}" -C "${tmp}"
    mv "${tmp}/gitlab-ci-local" /usr/local/bin/gitlab-ci-local
fi

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "gitlab-ci-local ${GCL_VERSION} installed."
echo "Done!"
