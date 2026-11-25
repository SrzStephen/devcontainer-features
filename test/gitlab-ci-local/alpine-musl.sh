#!/bin/bash
set -e
source dev-container-features-test-lib

check "gitlab-ci-local is on PATH" which gitlab-ci-local
# Regression: the glibc pre-built binary failed here under gcompat with
# "Error relocating ...: __pthread_key_create: symbol not found".
check "gitlab-ci-local --version exits 0" gitlab-ci-local --version
check "gitlab-ci-local --version prints a version" bash -c "gitlab-ci-local --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "private node runtime is Node 24+" bash -c "[ \"\$(/usr/local/lib/gitlab-ci-local/node/bin/node -p 'process.versions.node.split(\".\")[0]')\" -ge 24 ]"
check "no global node is added to PATH" bash -c "! command -v node"

reportResults
