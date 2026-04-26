#!/bin/sh
# Bootstrap: install bash on Alpine if needed, then re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
    command -v apk >/dev/null 2>&1 && apk add --no-cache bash >/dev/null 2>&1
    exec bash -- "$0" "$@"
fi
set -euo pipefail

MARKETPLACE="${MARKETPLACE:-""}"
PLUGIN="${PLUGIN:-""}"
REMOVE_ATTRIBUTION="${REMOVEATTRIBUTION:-"false"}"

REMOTE_USER="${_REMOTE_USER:-"vscode"}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-"/home/${REMOTE_USER}"}"
CLAUDE_BIN="${REMOTE_USER_HOME}/.local/bin/claude"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

run_as_user() {
    if command -v runuser &>/dev/null; then
        runuser -l "${REMOTE_USER}" -c "${*}"
    else
        su -l "${REMOTE_USER}" -c "${*}"
    fi
}

# Strip https://github.com/ prefix so both short (owner/repo) and full URL
# forms normalise to the owner/repo shorthand that the claude CLI expects.
normalize_gh_ref() {
    local ref="$1"
    echo "${ref#https://github.com/}"
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

_install_pkg() {
    if command -v apk &>/dev/null; then
        apk add --no-cache "$@"
    else
        apt-get update -y
        apt-get install -y --no-install-recommends "$@"
    fi
}

if ! command -v curl &>/dev/null; then
    _install_pkg curl ca-certificates
fi

if [ "${REMOVE_ATTRIBUTION}" = "true" ] && ! command -v jq &>/dev/null; then
    _install_pkg jq
fi

# ---------------------------------------------------------------------------
# Install Claude Code
# ---------------------------------------------------------------------------

echo "Installing Claude Code via https://claude.ai/install.sh..."
run_as_user 'curl -fsSL https://claude.ai/install.sh | bash'

# Ensure ~/.local/bin is on PATH in the user's login profile.
USER_PROFILE="${REMOTE_USER_HOME}/.profile"
if ! grep -q '\.local/bin' "${USER_PROFILE}" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${USER_PROFILE}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${USER_PROFILE}"
fi

if [ -x "${CLAUDE_BIN}" ]; then
    echo "Claude Code $(run_as_user "${CLAUDE_BIN} --version") installed."
else
    echo "Warning: claude binary not found at ${CLAUDE_BIN} after installation."
fi

# ---------------------------------------------------------------------------
# Attribution
# ---------------------------------------------------------------------------

if [ "${REMOVE_ATTRIBUTION}" = "true" ]; then
    CLAUDE_SETTINGS="${REMOTE_USER_HOME}/.claude/settings.json"
    CLAUDE_SETTINGS_DIR="$(dirname "${CLAUDE_SETTINGS}")"

    mkdir -p "${CLAUDE_SETTINGS_DIR}"
    chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS_DIR}"

    if [ -f "${CLAUDE_SETTINGS}" ] && jq -e '.attribution' "${CLAUDE_SETTINGS}" &>/dev/null; then
        echo "Attribution already configured in ${CLAUDE_SETTINGS}, skipping."
    elif [ -f "${CLAUDE_SETTINGS}" ]; then
        tmp=$(mktemp)
        jq '. + {"attribution": {"commit": "", "pr": ""}}' "${CLAUDE_SETTINGS}" > "${tmp}"
        mv "${tmp}" "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Attribution removed from Claude settings."
    else
        printf '{"attribution":{"commit":"","pr":""}}\n' > "${CLAUDE_SETTINGS}"
        chown "${REMOTE_USER}:${REMOTE_USER}" "${CLAUDE_SETTINGS}"
        echo "Attribution removed from Claude settings."
    fi
fi

# ---------------------------------------------------------------------------
# Marketplace
# ---------------------------------------------------------------------------

if [ -n "${MARKETPLACE}" ]; then
    MARKETPLACE_REF=$(normalize_gh_ref "${MARKETPLACE}")
    echo "Adding plugin marketplace: ${MARKETPLACE_REF}"
    run_as_user "${CLAUDE_BIN} plugin marketplace add ${MARKETPLACE_REF}"
fi

# ---------------------------------------------------------------------------
# Plugin
# ---------------------------------------------------------------------------

if [ -n "${PLUGIN}" ]; then
    PLUGIN_REF=$(normalize_gh_ref "${PLUGIN}")
    echo "Installing plugin: ${PLUGIN_REF}"
    run_as_user "${CLAUDE_BIN} plugin install ${PLUGIN_REF}"
fi

echo "Done!"
