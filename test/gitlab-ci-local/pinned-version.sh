#!/bin/bash
set -e
source dev-container-features-test-lib

check "gitlab-ci-local is on PATH" which gitlab-ci-local
check "gitlab-ci-local --version exits 0" gitlab-ci-local --version

reportResults
