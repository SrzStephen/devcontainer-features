#!/bin/bash
set -e
source dev-container-features-test-lib

check "gitlab-ci-local is on PATH" which gitlab-ci-local
check "gitlab-ci-local reports pinned version" bash -c "gitlab-ci-local --version | grep -x '4.72.0'"

reportResults
