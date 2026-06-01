#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

JUST_VERSION="${VERSION:-"latest"}"
JUST_LSP_VERSION="${LSPVERSION:-"latest"}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-"/home/${_REMOTE_USER:-"vscode"}"}"

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
# (format: "<sha256>  <filename>", one asset per line; a leading "./" on the
# filename is tolerated).
verify_checksum() {
    local file="$1" checksums="$2" asset="$3" expected actual
    expected="$(awk -v f="${asset}" '{ sub(/^\.\//, "", $2) } $2 == f {print $1}' "${checksums}")"
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
    x86_64 | aarch64) ;;
    *)
        echo "(!) Architecture $(uname -m) unsupported"
        exit 1
        ;;
esac

JUST_VERSION="$(resolve_version casey/just "${JUST_VERSION}")"

MACHINE="$(uname -m)"

echo "Downloading just ${JUST_VERSION}..."
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
just_asset="just-${JUST_VERSION}-${MACHINE}-unknown-linux-musl.tar.gz"
just_base="https://github.com/casey/just/releases/download/${JUST_VERSION}"
archive="${tmp}/${just_asset}"
download "${just_base}/${just_asset}" "${archive}"
download "${just_base}/SHA256SUMS" "${tmp}/just-sums.txt"
verify_checksum "${archive}" "${tmp}/just-sums.txt" "${just_asset}"
tar xzf "${archive}" -C "${tmp}"
mv "${tmp}/just" /usr/local/bin/just
mkdir -p "/usr/share/man/man1"
mv "${tmp}/just.1" "/usr/share/man/man1/just.1"

# Enable bash completions once (idempotent across container rebuilds).
COMPLETION_LINE='source <(just --completions bash)'
if [ -f "${REMOTE_USER_HOME}/.bashrc" ] && ! grep -qF "${COMPLETION_LINE}" "${REMOTE_USER_HOME}/.bashrc"; then
    printf '\n%s\n' "${COMPLETION_LINE}" >> "${REMOTE_USER_HOME}/.bashrc"
fi

if [ "${JUST_LSP_VERSION}" != "false" ]; then
    JUST_LSP_VERSION="$(resolve_version terror/just-lsp "${JUST_LSP_VERSION}")"
    echo "Downloading just-lsp ${JUST_LSP_VERSION}..."
    lsp_asset="just-lsp-${JUST_LSP_VERSION}-${MACHINE}-unknown-linux-musl.tar.gz"
    lsp_base="https://github.com/terror/just-lsp/releases/download/${JUST_LSP_VERSION}"
    lsp_archive="${tmp}/${lsp_asset}"
    download "${lsp_base}/${lsp_asset}" "${lsp_archive}"
    download "${lsp_base}/SHA256SUMS" "${tmp}/lsp-sums.txt"
    verify_checksum "${lsp_archive}" "${tmp}/lsp-sums.txt" "${lsp_asset}"
    tar xzf "${lsp_archive}" -C "${tmp}"
    mv "${tmp}/just-lsp" /usr/local/bin/just-lsp
    echo "just-lsp ${JUST_LSP_VERSION} installed."
fi

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "Done!"
