#!/bin/sh
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

JUST_VERSION="${VERSION:-"latest"}"
JUST_LSP_VERSION="${LSPVERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Resolve "latest", "1", or "1.40" to a full version; pass through "1.40.0".
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
            grep '"tag_name"' "${tmp}" | cut -d'"' -f4 | sed 's/^v//' | grep -m1 "^${version}\."
        else
            echo "${version}"
        fi
    fi
    rm -f "${tmp}"
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
    x86_64)  architecture="amd64" ;;
    aarch64) architecture="arm64" ;;
    *)
        echo "(!) Architecture $(uname -m) unsupported"
        exit 1
        ;;
esac

JUST_VERSION="$(resolve_version casey/just "${JUST_VERSION}")"

echo "Downloading just ${JUST_VERSION}..."
tmp="$(mktemp -d)"
curl -sL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" | tar xz -C "${tmp}"
mv "${tmp}/just" /usr/local/bin/just
mkdir -p "/usr/share/man/man1"
mv "${tmp}/just.1" "/usr/share/man/man1/just.1"
rm -rf "${tmp}"

echo -e "\nsource <(just --completions bash)\n" >> "$_REMOTE_USER_HOME/.bashrc"

if [ "${JUST_LSP_VERSION}" != "false" ]; then
    JUST_LSP_VERSION="$(resolve_version terror/just-lsp "${JUST_LSP_VERSION}")"
    echo "Downloading just-lsp ${JUST_LSP_VERSION}..."
    tmp="$(mktemp -d)"
    curl -sL "https://github.com/terror/just-lsp/releases/download/${JUST_LSP_VERSION}/just-lsp-${JUST_LSP_VERSION}-$(uname -m)-unknown-linux-musl.tar.gz" | tar xz -C "${tmp}"
    mv "${tmp}/just-lsp" /usr/local/bin/just-lsp
    rm -rf "${tmp}"
    echo "just-lsp ${JUST_LSP_VERSION} installed."
fi

rm -rf /var/lib/apt/lists/*

echo "Done!"
