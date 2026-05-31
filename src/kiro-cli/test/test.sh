#!/bin/bash
set -e
source dev-container-features-test-lib

check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli-chat is on PATH" which kiro-cli-chat
check "kiro-cli-term is on PATH" which kiro-cli-term
check "kiro-cli --help exits 0" kiro-cli --help

reportResults
