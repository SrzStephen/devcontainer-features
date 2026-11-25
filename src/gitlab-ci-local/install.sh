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
    # libstdc++/libgcc are runtime deps of the musl Node build used below.
    apk add --no-cache curl ca-certificates libstdc++ libgcc
else
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y
    fi
    apt-get install -y --no-install-recommends curl ca-certificates
fi

GCL_VERSION="$(resolve_version firecow/gitlab-ci-local "${GCL_VERSION}")"

# Node major used to run gitlab-ci-local on musl. Recent gitlab-ci-local releases
# require Node >= 24, newer than what older Alpine releases package.
NODE_MAJOR="24"
NODE_MIRROR="https://unofficial-builds.nodejs.org/download/release"
GCL_PREFIX="/usr/local/lib/gitlab-ci-local"

# Install a private, checksum-verified musl Node build into ${GCL_PREFIX}/node.
install_musl_node() {
    local node_arch node_version tarball tmp_node
    case "${ARCH}" in
        x86_64)  node_arch="x64" ;;
        aarch64) node_arch="arm64" ;;
        *)
            echo "(!) Architecture ${ARCH} unsupported on musl"
            exit 1
            ;;
    esac
    # index.tab is newest-first. awk must consume all input (no early `exit`)
    # or curl hits SIGPIPE and fails the pipeline under pipefail.
    node_version="$(curl -fsSL "${NODE_MIRROR}/index.tab" \
        | awk -F'\t' -v major="v${NODE_MAJOR}." -v f="linux-${node_arch}-musl" \
            '!found && NR > 1 && index($1, major) == 1 && index($3, f) { print $1; found = 1 }')"
    if [ -z "${node_version}" ]; then
        echo "ERROR: No musl Node ${NODE_MAJOR}.x build found for ${node_arch}" >&2
        exit 1
    fi
    echo "Installing Node ${node_version} (linux-${node_arch}-musl) for gitlab-ci-local..."
    tarball="node-${node_version}-linux-${node_arch}-musl.tar.xz"
    tmp_node="$(mktemp -d)"
    download "${NODE_MIRROR}/${node_version}/${tarball}" "${tmp_node}/${tarball}"
    download "${NODE_MIRROR}/${node_version}/SHASUMS256.txt" "${tmp_node}/SHASUMS256.txt"
    (cd "${tmp_node}" && grep " ${tarball}\$" SHASUMS256.txt | sha256sum -c -)
    rm -rf "${GCL_PREFIX}/node"
    mkdir -p "${GCL_PREFIX}/node"
    tar xJf "${tmp_node}/${tarball}" -C "${GCL_PREFIX}/node" --strip-components=1
    rm -rf "${tmp_node}"
}

# The pre-built binary is glibc-linked and gcompat cannot run it (e.g.
# "__pthread_key_create: symbol not found"). On musl, install the npm package
# under a private Node runtime and expose it via a wrapper on PATH.
if _is_musl; then
    install_musl_node
    echo "Installing gitlab-ci-local ${GCL_VERSION} via npm..."
    PATH="${GCL_PREFIX}/node/bin:${PATH}" npm install -g --no-fund --no-audit \
        --prefix "${GCL_PREFIX}" "gitlab-ci-local@${GCL_VERSION}"
    cat > /usr/local/bin/gitlab-ci-local <<EOF
#!/bin/sh
PATH="${GCL_PREFIX}/node/bin:\${PATH}" exec "${GCL_PREFIX}/bin/gitlab-ci-local" "\$@"
EOF
    chmod 0755 /usr/local/bin/gitlab-ci-local
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
