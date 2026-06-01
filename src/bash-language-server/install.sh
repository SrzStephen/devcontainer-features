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
# Helpers
# ---------------------------------------------------------------------------

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

# Try to install packages via the system package manager. Returns non-zero
# (without printing errors) when a package is unavailable, so callers can fall
# back to a binary download.
_try_install_pkg() {
    if command -v apk &>/dev/null; then
        apk add --no-cache "$@" 2>/dev/null
    else
        if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
            apt-get update -y >/dev/null 2>&1 || true
        fi
        apt-get install -y --no-install-recommends "$@" 2>/dev/null
    fi
}

# Resolve a version. "latest" is resolved via the github.com releases/latest
# redirect (no GitHub API); any other value is treated as an exact version.
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

# Install shfmt from the mvdan/sh release binary (latest), verified against the
# upstream sha256sums.txt.
install_shfmt_binary() {
    local arch ver tmp asset base
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) echo "Warning: no shfmt binary available for $(uname -m), skipping." >&2; return 0 ;;
    esac
    ver="$(resolve_version mvdan/sh latest)"
    tmp="$(mktemp -d)"
    asset="shfmt_v${ver}_linux_${arch}"
    base="https://github.com/mvdan/sh/releases/download/v${ver}"
    echo "Downloading shfmt v${ver} binary..."
    download "${base}/${asset}" "${tmp}/shfmt"
    download "${base}/sha256sums.txt" "${tmp}/sha256sums.txt"
    verify_checksum "${tmp}/shfmt" "${tmp}/sha256sums.txt" "${asset}"
    install -m 0755 "${tmp}/shfmt" /usr/local/bin/shfmt
    rm -rf "${tmp}"
    echo "shfmt v${ver} installed (binary)."
}

# Install shellcheck from the koalaman/shellcheck release archive (latest).
# Upstream publishes no checksums file, so integrity relies on HTTPS transport.
install_shellcheck_binary() {
    local arch ver tmp
    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) echo "Warning: no shellcheck binary available for $(uname -m), skipping." >&2; return 0 ;;
    esac
    # The release ships only .tar.xz archives; ensure xz is available to unpack.
    if ! command -v xz &>/dev/null; then
        if command -v apk &>/dev/null; then
            _install_pkg xz
        else
            _install_pkg xz-utils
        fi
    fi
    ver="$(resolve_version koalaman/shellcheck latest)"
    tmp="$(mktemp -d)"
    echo "Downloading shellcheck v${ver} binary..."
    download "https://github.com/koalaman/shellcheck/releases/download/v${ver}/shellcheck-v${ver}.linux.${arch}.tar.xz" "${tmp}/shellcheck.tar.xz"
    tar xJf "${tmp}/shellcheck.tar.xz" -C "${tmp}"
    install -m 0755 "${tmp}/shellcheck-v${ver}/shellcheck" /usr/local/bin/shellcheck
    rm -rf "${tmp}"
    echo "shellcheck v${ver} installed (binary)."
}

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

# ---------------------------------------------------------------------------
# Dependencies: Node.js 20+
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
# Verify and ensure /usr/bin symlink
# ---------------------------------------------------------------------------

if command -v bash-language-server &>/dev/null; then
    echo "bash-language-server $(bash-language-server --version 2>/dev/null || true) installed."
    BLS_BIN="$(command -v bash-language-server)"
    if [ "${BLS_BIN}" != "/usr/bin/bash-language-server" ] && [ ! -e /usr/bin/bash-language-server ]; then
        ln -s "${BLS_BIN}" /usr/bin/bash-language-server
        echo "Symlinked ${BLS_BIN} -> /usr/bin/bash-language-server"
    fi
else
    echo "Warning: bash-language-server not found on PATH after installation." >&2
fi

# ---------------------------------------------------------------------------
# Optional: install shellcheck (package manager, with binary fallback)
# ---------------------------------------------------------------------------

if [ "${INSTALL_SHELLCHECK}" = "true" ]; then
    if command -v shellcheck &>/dev/null; then
        echo "shellcheck already installed at $(command -v shellcheck), skipping."
    elif _try_install_pkg shellcheck; then
        echo "shellcheck installed via system package manager."
    else
        echo "shellcheck unavailable via package manager, falling back to binary download..."
        install_shellcheck_binary
    fi
fi

# ---------------------------------------------------------------------------
# Optional: install shellfmt (shfmt) (package manager, with binary fallback)
# ---------------------------------------------------------------------------

if [ "${INSTALL_SHELLFMT}" = "true" ]; then
    if command -v shfmt &>/dev/null; then
        echo "shfmt already installed at $(command -v shfmt), skipping."
    elif _try_install_pkg shfmt; then
        echo "shfmt installed via system package manager."
    else
        echo "shfmt unavailable via package manager, falling back to binary download..."
        install_shfmt_binary
    fi
fi

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

echo "Done!"
