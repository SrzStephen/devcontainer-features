#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

ACT_VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Resolve "latest", "0", or "0.2" to a full version; pass through "0.2.88".
resolve_version() {
    local repo="$1" version="$2" tmp dot_count result
    if [ "${version}" = "latest" ]; then
        result="$(curl -fsSL "https://github.com/${repo}/releases/latest" \
            -o /dev/null -w '%{url_effective}' | sed 's|.*/||; s/^v//' || true)"
    else
        dot_count="$(printf '%s' "${version}" | tr -cd '.' | wc -c)"
        if [ "${dot_count}" -lt 2 ]; then
            tmp="$(mktemp)"
            local -a curl_opts=(-fsSL)
            if [ -n "${GITHUB_TOKEN:-}" ]; then
                curl_opts+=(-H "Authorization: token ${GITHUB_TOKEN}")
            fi
            curl "${curl_opts[@]}" "https://api.github.com/repos/${repo}/releases?per_page=100" -o "${tmp}"
            result="$(grep '"tag_name"' "${tmp}" | cut -d'"' -f4 | sed 's/^v//' | grep -m1 "^${version//./\\.}\\." || true)"
            rm -f "${tmp}"
        else
            result="${version}"
        fi
    fi
    if [ -z "${result}" ]; then
        echo "ERROR: Failed to resolve version for ${repo}" >&2
        return 1
    fi
    echo "${result}"
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
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
    *)
        echo "(!) Architecture $(uname -m) unsupported"
        exit 1
        ;;
esac

ACT_VERSION="$(resolve_version nektos/act "${ACT_VERSION}")"

echo "Downloading act ${ACT_VERSION}..."
tmp="$(mktemp -d)"
archive="${tmp}/act.tar.gz"
act_url="https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_${ARCH}.tar.gz"
for attempt in 1 2 3; do
    if curl -fsSL "${act_url}" -o "${archive}"; then
        break
    elif [ "${attempt}" -lt 3 ]; then
        echo "Download attempt ${attempt} failed, retrying in 5s..."
        sleep 5
    else
        echo "ERROR: Failed to download act after 3 attempts"
        exit 1
    fi
done
tar xzf "${archive}" -C "${tmp}"
mv "${tmp}/act" /usr/local/bin/act
rm -rf "${tmp}"

rm -rf /var/lib/apt/lists/*

echo "act ${ACT_VERSION} installed."
echo "Done!"
