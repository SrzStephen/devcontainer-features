#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-"latest"}"

if [ "${VERSION}" != "latest" ] && ! echo "${VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: version must be 'latest' or a full version like '2.3.0' (got: '${VERSION}')" >&2
    exit 1
fi

BASE_URL="https://desktop-release.q.us-east-1.amazonaws.com/${VERSION}"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    apt-get update -y
    apt-get install -y --no-install-recommends curl ca-certificates
fi

# ---------------------------------------------------------------------------
# Install Kiro
# ---------------------------------------------------------------------------

ARCH="$(uname -m)"

# Prefer .deb on Debian/Ubuntu x86_64 systems, but extract binaries directly to
# avoid pulling in GUI library deps (libwebkit2gtk-4.1-0, libgtk-3-0, etc.) that
# are only required by kiro-cli-desktop, not the headless CLI.
# On arm64, the .deb is x86_64-only — fall through to the zip path instead.
if command -v dpkg &>/dev/null && [ "${ARCH}" = "x86_64" ]; then
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
    rm -rf "${TMP_EXTRACT}" "${TMP_DEB}"
else
    # Zip-based install for non-Debian systems
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

    case "${ARCH}" in
        x86_64)  ZIP="kirocli-x86_64-linux.zip" ;;
        aarch64) ZIP="kirocli-aarch64-linux.zip" ;;
        *)
            echo "Error: unsupported architecture: ${ARCH}" >&2
            exit 1
            ;;
    esac

    echo "Installing Kiro via zip archive (${ZIP})..."
    TMP_DIR="$(mktemp -d)"
    if command -v curl &>/dev/null; then
        curl -fsSL "${BASE_URL}/${ZIP}" -o "${TMP_DIR}/kiro.zip"
    else
        wget -qO "${TMP_DIR}/kiro.zip" "${BASE_URL}/${ZIP}"
    fi
    unzip -q "${TMP_DIR}/kiro.zip" -d "${TMP_DIR}"
    install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli" /usr/local/bin/kiro-cli
    rm -rf "${TMP_DIR}"
fi

rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

if command -v kiro-cli &>/dev/null; then
    echo "Kiro $(kiro-cli --version 2>/dev/null || true) installed."
else
    echo "Warning: kiro-cli not found on PATH after installation." >&2
fi

echo "Done!"
