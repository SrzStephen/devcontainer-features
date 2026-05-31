#!/bin/sh
# shellcheck shell=bash
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

VERSION="${VERSION:-"latest"}"
DISABLE_AUTOUPDATES="${DISABLEAUTOUPDATES:-"false"}"

if [ "${VERSION}" != "latest" ] && ! echo "${VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: version must be 'latest' or a full version like '2.3.0' (got: '${VERSION}')" >&2
    exit 1
fi

BASE_URL="https://prod.download.cli.kiro.dev/stable/${VERSION}"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    apt-get update -y
    apt-get install -y --no-install-recommends curl ca-certificates
fi

# ---------------------------------------------------------------------------
# Libc detection
# ---------------------------------------------------------------------------

# Returns 0 if the system uses musl libc or glibc < 2.34.
# Kiro provides a musl-linked zip that works for both cases.
_use_musl() {
    # musl libc (Alpine and similar): dynamic linker present at /lib/ld-musl-*
    if ls /lib/ld-musl-* >/dev/null 2>&1; then
        return 0
    fi
    # glibc older than 2.34: use musl zip for compatibility
    local ver major minor
    ver="$(ldd --version 2>/dev/null | awk 'NR==1{print $NF}')"
    if echo "${ver}" | grep -qE '^[0-9]+\.[0-9]+'; then
        major="$(echo "${ver}" | cut -d. -f1)"
        minor="$(echo "${ver}" | cut -d. -f2)"
        if [ "${major}" -lt 2 ] || { [ "${major}" -eq 2 ] && [ "${minor}" -lt 34 ]; }; then
            return 0
        fi
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Install Kiro
# ---------------------------------------------------------------------------

ARCH="$(uname -m)"

# Prefer .deb on Debian/Ubuntu x86_64 glibc systems, but extract binaries directly to
# avoid pulling in GUI library deps (libwebkit2gtk-4.1-0, libgtk-3-0, etc.) that
# are only required by kiro-cli-desktop, not the headless CLI.
# On arm64 or musl systems, the .deb is not suitable — fall through to the zip path.
if command -v dpkg &>/dev/null && [ "${ARCH}" = "x86_64" ] && ! _use_musl; then
    echo "Installing Kiro via .deb package..."
    TMP_DEB="$(mktemp --suffix=.deb)"
    if command -v curl &>/dev/null; then
        curl -fsSL "${BASE_URL}/kiro-cli.deb" -o "${TMP_DEB}"
    else
        wget -qO "${TMP_DEB}" "${BASE_URL}/kiro-cli.deb"
    fi
    TMP_EXTRACT="$(mktemp -d)"
    dpkg-deb -x "${TMP_DEB}" "${TMP_EXTRACT}"
    install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli" /usr/local/bin/kiro-cli
    install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli-chat" /usr/local/bin/kiro-cli-chat
    install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli-term" /usr/local/bin/kiro-cli-term
    rm -rf "${TMP_EXTRACT}" "${TMP_DEB}"
else
    # Zip-based install for arm64, musl, and non-Debian systems.
    if ! command -v unzip &>/dev/null; then
        if command -v apk &>/dev/null; then
            apk add --no-cache unzip
        else
            apt-get update -y
            apt-get install -y --no-install-recommends unzip
        fi
    fi
    if ! command -v unzip &>/dev/null; then
        echo "Error: unzip is required for non-Debian systems." >&2
        exit 1
    fi

    # Select architecture- and libc-appropriate zip.
    if _use_musl; then
        case "${ARCH}" in
            x86_64)  ZIP="kirocli-x86_64-linux-musl.zip" ;;
            aarch64) ZIP="kirocli-aarch64-linux-musl.zip" ;;
            *)
                echo "Error: unsupported architecture: ${ARCH}" >&2
                exit 1
                ;;
        esac
    else
        case "${ARCH}" in
            x86_64)  ZIP="kirocli-x86_64-linux.zip" ;;
            aarch64) ZIP="kirocli-aarch64-linux.zip" ;;
            *)
                echo "Error: unsupported architecture: ${ARCH}" >&2
                exit 1
                ;;
        esac
    fi

    echo "Installing Kiro via zip archive (${ZIP})..."
    TMP_DIR="$(mktemp -d)"
    if command -v curl &>/dev/null; then
        curl -fsSL "${BASE_URL}/${ZIP}" -o "${TMP_DIR}/kiro.zip"
    else
        wget -qO "${TMP_DIR}/kiro.zip" "${BASE_URL}/${ZIP}"
    fi
    unzip -q "${TMP_DIR}/kiro.zip" -d "${TMP_DIR}"
    install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli" /usr/local/bin/kiro-cli
    install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli-chat" /usr/local/bin/kiro-cli-chat
    install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli-term" /usr/local/bin/kiro-cli-term
    rm -rf "${TMP_DIR}"
fi

rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Autoupdate settings
# ---------------------------------------------------------------------------

if [ "${DISABLE_AUTOUPDATES}" = "true" ]; then
    echo "Disabling Kiro CLI autoupdates..."
    kiro-cli settings "app.disableAutoupdates" "true" 2>/dev/null || \
        echo "Warning: could not apply autoupdate setting for root" >&2
    # Also apply for the non-root container user when different from root.
    if [ "${_REMOTE_USER:-root}" != "root" ]; then
        su "${_REMOTE_USER}" -c 'kiro-cli settings "app.disableAutoupdates" "true"' 2>/dev/null || \
            echo "Warning: could not apply autoupdate setting for ${_REMOTE_USER}" >&2
    fi
fi

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

if command -v kiro-cli &>/dev/null; then
    echo "Kiro $(kiro-cli --version 2>/dev/null || true) installed."
else
    echo "Warning: kiro-cli not found on PATH after installation." >&2
fi

echo "Done!"
