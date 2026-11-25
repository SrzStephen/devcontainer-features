#!/bin/bash
set -e
source dev-container-features-test-lib

# Kiro 3.3.0 ships only kiro-cli (kiro-cli-chat and kiro-cli-term were removed);
# the install must succeed without them and must not leave stray binaries.
check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli --help exits 0" kiro-cli --help
check "kiro-cli version matches pinned value" bash -c "kiro-cli --version 2>&1 | grep -q '3.3.0'"
check "kiro-cli-chat is not installed" bash -c "[ ! -e /usr/local/bin/kiro-cli-chat ]"
check "kiro-cli-term is not installed" bash -c "[ ! -e /usr/local/bin/kiro-cli-term ]"
check "xdg-open is available" which xdg-open

reportResults
