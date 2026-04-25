import shutil

import pytest

from tests.conftest import PARAMS, built_docker_image, docker_run


@pytest.mark.docker
@pytest.mark.slow
@pytest.mark.timeout(900)
@pytest.mark.parametrize("tc,image", PARAMS)
def test_feature_installs(tc, image, project_root):
    if not shutil.which("docker"):
        pytest.skip("docker not available")

    with built_docker_image(tc, image, project_root) as tag:
        for binary in tc.binaries:
            out = docker_run(tag, f"which {binary}")
            assert out.returncode == 0, (
                f"{binary} not found on PATH in {image} "
                f"({tc.feature_id} {tc.option_id})\n{out.stderr}"
            )

            out = docker_run(tag, f"{binary} --help")
            assert out.returncode == 0, (
                f"{binary} --help exited {out.returncode} in {image} "
                f"({tc.feature_id} {tc.option_id})\n{out.stderr}"
            )
