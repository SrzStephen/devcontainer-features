#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

GLAB_VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Resolve "latest" to the current release version; pass through exact versions.
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

export DEBIAN_FRONTEND=noninteractive

if command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl ca-certificates gcompat
else
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y
    fi
    apt-get install -y --no-install-recommends curl ca-certificates
fi

case "$(uname -m)" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
    *)
        echo "(!) Architecture $(uname -m) unsupported"
        exit 1
        ;;
esac

GLAB_VERSION="$(resolve_version gitlab-org/cli "${GLAB_VERSION}")"

echo "Downloading glab ${GLAB_VERSION}..."
tmp="$(mktemp -d)"
archive="${tmp}/glab.tar.gz"
glab_url="https://github.com/gitlab-org/cli/releases/download/v${GLAB_VERSION}/glab_${GLAB_VERSION}_Linux_${ARCH}.tar.gz"
for attempt in 1 2 3; do
    if curl -fsSL "${glab_url}" -o "${archive}"; then
        break
    elif [ "${attempt}" -lt 3 ]; then
        echo "Download attempt ${attempt} failed, retrying in 5s..."
        sleep 5
    else
        echo "ERROR: Failed to download glab after 3 attempts"
        exit 1
    fi
done
tar xzf "${archive}" -C "${tmp}"
mv "${tmp}/bin/glab" /usr/local/bin/glab
rm -rf "${tmp}"

rm -rf /var/lib/apt/lists/*

echo "glab ${GLAB_VERSION} installed."
echo "Done!"
