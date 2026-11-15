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
DEFAULT_MODEL="${DEFAULTMODEL:-""}"
AGENT_ENGINE="${AGENTENGINE:-""}"
DISABLE_GREETING="${DISABLEGREETING:-"true"}"

if [ "${VERSION}" != "latest" ] && ! echo "${VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: version must be 'latest' or a full version like '2.3.0' (got: '${VERSION}')" >&2
    exit 1
fi

case "${AGENT_ENGINE}" in
    ""|v1|v2|v3) ;;
    *)
        echo "Error: agentEngine must be empty, 'v1', 'v2' or 'v3' (got: '${AGENT_ENGINE}')" >&2
        exit 1
        ;;
esac

if [ -n "${DEFAULT_MODEL}" ] && ! echo "${DEFAULT_MODEL}" | grep -qE '^[A-Za-z0-9._:/-]+$'; then
    echo "Error: defaultModel contains invalid characters (got: '${DEFAULT_MODEL}')" >&2
    exit 1
fi

SKILLS="${SKILLS:-""}"
REMOTE_USER="${_REMOTE_USER:-"root"}"

run_as_user() {
    if command -v runuser &>/dev/null; then
        runuser -l "${REMOTE_USER}" -c "${*}"
    else
        su -l "${REMOTE_USER}" -c "${*}"
    fi
}

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


# ---------------------------------------------------------------------------
# Agent skills (canonical helpers, shared verbatim across features)
#
# requires: bash with set -e; run_as_user (runs a command string as the remote
#   user); curl, tar and sha256sum on PATH; the SKILLS variable (comma-separated
#   list, may be empty or unset). Usage: validate_skills early, then
#   install_skills <agent> once the agent itself is installed.
# ---------------------------------------------------------------------------

# Print each non-blank, whitespace-trimmed entry of the comma-separated SKILLS
# option on its own line.
_skills_entries() {
    local _entry
    local -a _raw
    IFS=',' read -ra _raw <<< "${SKILLS:-}"
    for _entry in "${_raw[@]}"; do
        _entry="${_entry#"${_entry%%[![:space:]]*}"}"
        _entry="${_entry%"${_entry##*[![:space:]]}"}"
        [ -n "${_entry}" ] && printf '%s\n' "${_entry}"
    done
    return 0
}

# Fail before anything runs if any SKILLS entry contains characters outside the
# allow-list, since entries are interpolated into a shell command string, or
# starts with a dash, which the skills CLI would parse as an option.
validate_skills() {
    local _entry
    while IFS= read -r _entry; do
        if [ "${_entry:0:1}" = "-" ]; then
            echo "ERROR: refusing unsafe skills entry (must not start with a dash): ${_entry}" >&2
            return 1
        fi
        if ! printf '%s' "${_entry}" | grep -qE '^[A-Za-z0-9._/:@~+-]+$'; then
            echo "ERROR: refusing unsafe skills entry (only A-Za-z0-9 . _ / : @ ~ + - are allowed): ${_entry}" >&2
            return 1
        fi
    done < <(_skills_entries)
}

# The skills CLI requires Node.js >= 22.20, newer than the Debian and Alpine
# distro packages. Install the latest Node 22 release into /usr/local from the
# official tarball (nodejs.org, or the unofficial musl builds on Alpine),
# verifying the published SHA-256 checksum. Skipped when a suitable node and npx
# are already present.
_ensure_node() {
    local _nodever="" _major=0 _minor=0 _arch _base _suffix="" _ver _file _sums _expected _tmp
    if command -v node &>/dev/null && command -v npx &>/dev/null; then
        _nodever="$(node -p 'process.versions.node' 2>/dev/null || true)"
        _major="${_nodever%%.*}"
        _minor="${_nodever#*.}"
        _minor="${_minor%%.*}"
        if [ "${_major:-0}" -gt 22 ] 2>/dev/null ||
            { [ "${_major:-0}" -eq 22 ] && [ "${_minor:-0}" -ge 20 ]; } 2>/dev/null; then
            return 0
        fi
    fi

    case "$(uname -m)" in
        x86_64) _arch=x64 ;;
        aarch64 | arm64) _arch=arm64 ;;
        *) echo "ERROR: unsupported architecture for Node.js install: $(uname -m)" >&2; return 1 ;;
    esac
    _base="https://nodejs.org/dist"
    if command -v apk &>/dev/null; then
        _base="https://unofficial-builds.nodejs.org/download/release"
        _suffix="-musl"
        apk add --no-cache libstdc++
    fi

    _ver="$(curl -fsSL "https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt" | grep -oE 'node-v22\.[0-9]+\.[0-9]+' | head -1 | sed 's/^node-//')"
    [ -n "${_ver}" ] || { echo "ERROR: could not determine latest Node.js 22 version" >&2; return 1; }
    _file="node-${_ver}-linux-${_arch}${_suffix}.tar.gz"
    _sums="$(curl -fsSL "${_base}/${_ver}/SHASUMS256.txt")"
    _expected="$(printf '%s\n' "${_sums}" | grep " ${_file}\$" | cut -d' ' -f1)"
    [ -n "${_expected}" ] || { echo "ERROR: no checksum published for ${_file}" >&2; return 1; }

    _tmp="$(mktemp -d)"
    echo "Installing Node.js ${_ver} (${_arch}${_suffix})..."
    if ! curl -fsSL -o "${_tmp}/${_file}" "${_base}/${_ver}/${_file}"; then
        echo "ERROR: failed to download ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    if [ "$(sha256sum "${_tmp}/${_file}" | cut -d' ' -f1)" != "${_expected}" ]; then
        echo "ERROR: checksum mismatch for ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    if ! tar -xzf "${_tmp}/${_file}" -C /usr/local --strip-components=1 --no-same-owner \
        --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'; then
        echo "ERROR: failed to extract ${_file}" >&2
        rm -rf "${_tmp}"
        return 1
    fi
    rm -rf "${_tmp}"
}

# install_skills <agent>: install each SKILLS entry for the given agent id using
# the skills CLI. Does nothing (and installs no Node) when SKILLS is blank.
install_skills() {
    local _agent="$1" _entry
    local -a _entries
    validate_skills || return 1
    mapfile -t _entries < <(_skills_entries)
    [ "${#_entries[@]}" -gt 0 ] || return 0

    _ensure_node
    for _entry in "${_entries[@]}"; do
        echo "Installing skills: ${_entry} (agent: ${_agent})"
        run_as_user "npx -y skills add ${_entry} -g -y -a ${_agent}"
    done
}

validate_skills

if [ -n "$(_skills_entries)" ] && ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
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

# Download a URL to a destination (curl or wget) with up to 3 retries.
fetch() {
    local url="$1" dest="$2" attempt
    for attempt in 1 2 3; do
        if command -v curl &>/dev/null; then
            curl -fsSL "${url}" -o "${dest}" && return 0
        else
            wget -qO "${dest}" "${url}" && return 0
        fi
        if [ "${attempt}" -lt 3 ]; then
            echo "Download attempt ${attempt} failed, retrying in 5s..." >&2
            sleep 5
        fi
    done
    echo "ERROR: Failed to download ${url} after 3 attempts" >&2
    return 1
}

# Verify a file against a sidecar .sha256 file containing a bare hash.
verify_sha256_bare() {
    local file="$1" sumfile="$2" expected actual
    expected="$(tr -d '[:space:]' < "${sumfile}")"
    actual="$(sha256sum "${file}" | cut -d' ' -f1)"
    if [ "${actual}" != "${expected}" ]; then
        echo "ERROR: checksum mismatch for $(basename "${file}")" >&2
        echo "  expected: ${expected}" >&2
        echo "  actual:   ${actual}" >&2
        return 1
    fi
    echo "Verified checksum for $(basename "${file}")."
}

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
    fetch "${BASE_URL}/kiro-cli.deb" "${TMP_DEB}"
    fetch "${BASE_URL}/kiro-cli.deb.sha256" "${TMP_DEB}.sha256"
    verify_sha256_bare "${TMP_DEB}" "${TMP_DEB}.sha256"
    TMP_EXTRACT="$(mktemp -d)"
    dpkg-deb -x "${TMP_DEB}" "${TMP_EXTRACT}"
    install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli" /usr/local/bin/kiro-cli
    if [ -f "${TMP_EXTRACT}/usr/bin/kiro-cli-chat" ]; then install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli-chat" /usr/local/bin/kiro-cli-chat; fi
    if [ -f "${TMP_EXTRACT}/usr/bin/kiro-cli-term" ]; then install -m 0755 "${TMP_EXTRACT}/usr/bin/kiro-cli-term" /usr/local/bin/kiro-cli-term; fi
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
    fetch "${BASE_URL}/${ZIP}" "${TMP_DIR}/kiro.zip"
    fetch "${BASE_URL}/${ZIP}.sha256" "${TMP_DIR}/kiro.zip.sha256"
    verify_sha256_bare "${TMP_DIR}/kiro.zip" "${TMP_DIR}/kiro.zip.sha256"
    unzip -q "${TMP_DIR}/kiro.zip" -d "${TMP_DIR}"
    install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli" /usr/local/bin/kiro-cli
    if [ -f "${TMP_DIR}/kirocli/bin/kiro-cli-chat" ]; then install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli-chat" /usr/local/bin/kiro-cli-chat; fi
    if [ -f "${TMP_DIR}/kirocli/bin/kiro-cli-term" ]; then install -m 0755 "${TMP_DIR}/kirocli/bin/kiro-cli-term" /usr/local/bin/kiro-cli-term; fi
    rm -rf "${TMP_DIR}"
fi

# ---------------------------------------------------------------------------
# xdg-utils (provides xdg-open)
# ---------------------------------------------------------------------------

if command -v apk &>/dev/null; then
    apk add --no-cache xdg-utils
elif command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y --no-install-recommends xdg-utils
fi

if command -v apt-get &>/dev/null; then
    rm -rf /var/lib/apt/lists/*
fi

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

# Apply a kiro-cli setting for root and, when different, the remote user.
apply_kiro_setting() {
    local key="$1" value="$2"
    kiro-cli settings "${key}" "${value}" 2>/dev/null || \
        echo "Warning: could not apply ${key} for root" >&2
    if [ "${_REMOTE_USER:-root}" != "root" ]; then
        su "${_REMOTE_USER}" -c "kiro-cli settings \"${key}\" \"${value}\"" 2>/dev/null || \
            echo "Warning: could not apply ${key} for ${_REMOTE_USER}" >&2
    fi
}

if [ "${DISABLE_AUTOUPDATES}" = "true" ]; then
    echo "Disabling Kiro CLI autoupdates..."
    apply_kiro_setting "app.disableAutoupdates" "true"
fi

if [ -n "${DEFAULT_MODEL}" ]; then
    echo "Setting Kiro CLI default model to ${DEFAULT_MODEL}..."
    apply_kiro_setting "chat.defaultModel" "${DEFAULT_MODEL}"
fi

if [ -n "${AGENT_ENGINE}" ]; then
    echo "Setting Kiro CLI agent engine to ${AGENT_ENGINE}..."
    apply_kiro_setting "chat.agentEngine" "${AGENT_ENGINE}"
fi

if [ "${DISABLE_GREETING}" = "true" ]; then
    echo "Disabling Kiro CLI greeting..."
    apply_kiro_setting "chat.greeting.enabled" "false"
fi

install_skills kiro-cli

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

if command -v kiro-cli &>/dev/null; then
    echo "Kiro $(kiro-cli --version 2>/dev/null || true) installed."
else
    echo "Warning: kiro-cli not found on PATH after installation." >&2
fi

echo "Done!"
