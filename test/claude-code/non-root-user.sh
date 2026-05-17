#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "claude --help exits 0" claude --help
check "claude installed in user home" test -f "${HOME}/.local/bin/claude"

reportResults
