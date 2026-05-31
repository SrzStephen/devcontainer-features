
# NVIDIA Container Toolkit (nvidia-container-toolkit)

Installs the NVIDIA Container Toolkit (nvidia-container-toolkit) for GPU-accelerated containers.

## Example Usage

```json
"features": {
    "ghcr.io/SrzStephen/devcontainer-features/nvidia-container-toolkit:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of nvidia-container-toolkit to install (e.g. '1.17.8'). Use 'latest' for the newest available. | string | latest |

## Compatibility

| OS              | Supported     | Notes                                 |
| --------------- | ------------- | ------------------------------------- |
| Debian / Ubuntu | ✓ tested      | Installed via NVIDIA apt repository   |
| Alpine Linux    | not supported | Requires apt; Alpine is not supported |

**Architectures:** x86_64, aarch64

## Setup

### Requirements

For NVIDIA Container Toolkit to work inside a devcontainer, the following must be present on the **host machine** (not inside the container):

- **NVIDIA GPU** with a supported driver installed
- **NVIDIA Container Toolkit** (`nvidia-container-toolkit`) installed and configured on the host
- **Docker** configured to use the NVIDIA runtime (either as the default runtime or via `--runtime=nvidia`)

The feature installs supporting packages inside the container, but GPU access depends entirely on the host being properly configured. If the host lacks the driver or toolkit, the container will not see any GPU devices.

### Running on Windows (WSL2)

On Windows, GPU passthrough to containers requires WSL2 (Windows Subsystem for Linux 2):

1. **WSL2** must be installed and set as the default version (`wsl --set-default-version 2`)
2. **NVIDIA drivers for WSL** must be installed on the Windows host — install the standard NVIDIA Game Ready or Studio driver (≥ 520); do **not** install a separate Linux driver inside WSL
3. **Docker Desktop** (with WSL2 backend enabled) or Docker Engine installed directly inside the WSL2 distro
4. **NVIDIA Container Toolkit** must be installed inside the WSL2 distro (not on the Windows host):
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
     | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
     | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo service docker restart
   ```
5. Verify GPU access from inside WSL: `nvidia-smi`

Once the host (WSL2 distro) is configured, devcontainers using this feature will have GPU access automatically.

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/SrzStephen/devcontainer-features/blob/main//tmp/publish-src/nvidia-container-toolkit/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
