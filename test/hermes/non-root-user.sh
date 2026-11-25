#!/bin/bash
set -e
source dev-container-features-test-lib

check "hermes binary exists for vscode" test -x /home/vscode/.local/bin/hermes
check "hermes on PATH" which hermes
check "hermes home owned by user" test "$(stat -c %U /home/vscode/.hermes)" = "vscode"

reportResults
