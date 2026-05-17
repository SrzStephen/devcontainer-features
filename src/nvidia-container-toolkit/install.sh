#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo or set 'remoteUser' to root."
    exit 1
fi

if ! dpkg -s ca-certificates curl gnupg2 > /dev/null 2>&1; then
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y
    fi
    apt-get install -y --no-install-recommends ca-certificates curl gnupg2
fi

# Add NVIDIA Container Toolkit apt repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -sL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -y

if [ "${VERSION}" = "latest" ]; then
    apt-get install -y --no-install-recommends \
        nvidia-container-toolkit \
        nvidia-container-toolkit-base \
        libnvidia-container-tools \
        libnvidia-container1
else
    PKG_VERSION="${VERSION}-1"
    apt-get install -y --no-install-recommends \
        "nvidia-container-toolkit=${PKG_VERSION}" \
        "nvidia-container-toolkit-base=${PKG_VERSION}" \
        "libnvidia-container-tools=${PKG_VERSION}" \
        "libnvidia-container1=${PKG_VERSION}"
fi

echo "NVIDIA Container Toolkit installation complete."
