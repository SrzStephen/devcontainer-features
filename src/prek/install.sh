#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

PREK_VERSION="${VERSION:-"latest"}"

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

# Verify a file's sha256 against the entry for ${asset} in a checksums file
# (format: "<sha256>  <filename>", one asset per line).
verify_checksum() {
    local file="$1" checksums="$2" asset="$3" expected actual
    expected="$(awk -v f="${asset}" '$2 == f {print $1}' "${checksums}")"
    if [ -z "${expected}" ]; then
        echo "ERROR: no checksum found for ${asset}" >&2
        return 1
    fi
    actual="$(sha256sum "${file}" | cut -d' ' -f1)"
    if [ "${actual}" != "${expected}" ]; then
        echo "ERROR: checksum mismatch for ${asset}" >&2
        echo "  expected: ${expected}" >&2
        echo "  actual:   ${actual}" >&2
        return 1
    fi
    echo "Verified checksum for ${asset}."
}

export DEBIAN_FRONTEND=noninteractive

if command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl ca-certificates
else
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y
    fi
    apt-get install -y --no-install-recommends curl ca-certificates
fi

case "$(uname -m)" in
    x86_64)  ARCH="x86_64-unknown-linux-musl" ;;
    aarch64) ARCH="aarch64-unknown-linux-musl" ;;
    *)
        echo "(!) Architecture $(uname -m) unsupported"
        exit 1
        ;;
esac

PREK_VERSION="$(resolve_version j178/prek "${PREK_VERSION}")"

echo "Downloading prek ${PREK_VERSION}..."
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
asset="prek-${ARCH}.tar.gz"
base_url="https://github.com/j178/prek/releases/download/v${PREK_VERSION}"
archive="${tmp}/${asset}"
download "${base_url}/${asset}" "${archive}"
download "${base_url}/${asset}.sha256" "${tmp}/checksums.txt"
verify_checksum "${archive}" "${tmp}/checksums.txt" "${asset}"
tar xzf "${archive}" -C "${tmp}"
mv "${tmp}/prek-${ARCH}/prek" /usr/local/bin/prek

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "prek ${PREK_VERSION} installed."
echo "Done!"
