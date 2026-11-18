#!/bin/bash
set -e
source dev-container-features-test-lib

check "hermes on PATH" which hermes
check "hermes version" hermes --version
check "hermes under vscode home" test -x "${HOME}/.local/bin/hermes"

reportResults
