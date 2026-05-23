#!/bin/bash
set -e
source dev-container-features-test-lib

check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli version matches pinned value" bash -c "kiro-cli --version 2>&1 | grep -q '2.3.0'"

reportResults
