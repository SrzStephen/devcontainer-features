#!/bin/bash
set -e
source dev-container-features-test-lib

check "herdr binary exists for vscode" test -x /home/vscode/.local/bin/herdr
check "herdr on PATH" which herdr
check "herdr on PATH in login shell" bash -lc 'command -v herdr'

reportResults
