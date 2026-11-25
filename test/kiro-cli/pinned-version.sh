#!/bin/bash
set -e
source dev-container-features-test-lib

# Kiro 2.x ships kiro-cli, kiro-cli-chat and kiro-cli-term; all three must be installed.
check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli version matches pinned value" bash -c "kiro-cli --version 2>&1 | grep -q '2.3.0'"
check "kiro-cli-chat is installed and executable" bash -c "[ -x /usr/local/bin/kiro-cli-chat ]"
check "kiro-cli-term is installed and executable" bash -c "[ -x /usr/local/bin/kiro-cli-term ]"
check "xdg-open is available" which xdg-open

reportResults
