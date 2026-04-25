import json
import os
import shutil
import subprocess
import tempfile
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import pytest


@dataclass
class FeatureTestCase:
    feature_id: str
    options: dict[str, str]
    binaries: list[str]
    supported_images: list[str]

    @property
    def env_options(self) -> dict[str, str]:
        return {k.upper(): v for k, v in self.options.items()}

    @property
    def option_id(self) -> str:
        return "-".join(f"{k}={v}" for k, v in sorted(self.options.items())) or "defaults"


DEBIAN = "debian:bookworm"
ALPINE = "alpine:3.20"
ALL_IMAGES = [DEBIAN, ALPINE]

TEST_CASES = [
    FeatureTestCase("just", {"version": "latest", "lspVersion": "latest"}, ["just", "just-lsp"], ALL_IMAGES),
    FeatureTestCase("just", {"version": "latest", "lspVersion": "false"}, ["just"],              ALL_IMAGES),
    FeatureTestCase("just", {"version": "1",      "lspVersion": "latest"}, ["just", "just-lsp"], ALL_IMAGES),
    FeatureTestCase("kiro", {}, ["kiro-cli"], ALL_IMAGES),
    FeatureTestCase("claude-code", {},                            ["claude"], ALL_IMAGES),
    FeatureTestCase("claude-code", {"removeAttribution": "true"}, ["claude"], ALL_IMAGES),
    FeatureTestCase("nvidia-container-toolkit", {"version": "latest"}, ["nvidia-ctk"], [DEBIAN]),
    FeatureTestCase("nvidia-container-toolkit", {"version": "1.17.8"}, ["nvidia-ctk"], [DEBIAN]),
]

PARAMS = [
    pytest.param(tc, image, id=f"{tc.feature_id}-{image.split(':')[0]}-{tc.option_id}")
    for tc in TEST_CASES
    for image in tc.supported_images
]


@pytest.fixture(scope="session")
def project_root() -> Path:
    return Path(__file__).parent.parent


def docker_run(tag: str, cmd: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["docker", "run", "--rm", tag, "bash", "-lc", cmd],
        capture_output=True,
        text=True,
    )


def _generate_dockerfile(tc: FeatureTestCase, image: str) -> str:
    lines = [f"FROM {image}"]
    if image.startswith("alpine"):
        lines.append("RUN apk add --no-cache bash")
    lines.append("ENV _REMOTE_USER=root")
    lines.append("ENV _REMOTE_USER_HOME=/root")
    for key, value in tc.env_options.items():
        lines.append(f"ENV {key}={value}")
    lines.append(f"COPY features/{tc.feature_id}/install.sh /tmp/install.sh")
    lines.append("RUN bash /tmp/install.sh")
    return "\n".join(lines) + "\n"


@contextmanager
def built_docker_image(tc: FeatureTestCase, image: str, project_root: Path) -> Iterator[str]:
    tag = f"devcontainer-feature-test-{tc.feature_id}-{abs(hash(tc.option_id))}"
    dockerfile = _generate_dockerfile(tc, image)
    with tempfile.NamedTemporaryFile("w", suffix=".Dockerfile", delete=False) as f:
        f.write(dockerfile)
        dockerfile_path = f.name
    result = subprocess.run(
        ["docker", "build", "-t", tag, "-f", dockerfile_path, str(project_root)],
        capture_output=True,
        text=True,
    )
    os.unlink(dockerfile_path)
    assert result.returncode == 0, f"docker build failed\n{result.stderr}"
    try:
        yield tag
    finally:
        subprocess.run(["docker", "rmi", "-f", tag], capture_output=True)


@contextmanager
def built_devcontainer_image(tc: FeatureTestCase, image: str, project_root: Path) -> Iterator[str]:
    tag = f"devcontainer-feature-test-dc-{tc.feature_id}-{abs(hash(tc.option_id))}"
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        (tmp / ".devcontainer").mkdir()
        feature_dst = tmp / "features" / tc.feature_id
        feature_dst.parent.mkdir(parents=True)
        shutil.copytree(project_root / "features" / tc.feature_id, feature_dst)
        config = {
            "image": image,
            "features": {f"./features/{tc.feature_id}": tc.options},
        }
        (tmp / ".devcontainer" / "devcontainer.json").write_text(json.dumps(config))
        result = subprocess.run(
            ["devcontainer", "build", "--workspace-folder", tmpdir, "--image-name", tag],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"devcontainer build failed\n{result.stderr}"
        try:
            yield tag
        finally:
            subprocess.run(["docker", "rmi", "-f", tag], capture_output=True)
