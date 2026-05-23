#!/bin/bash
set -e
source dev-container-features-test-lib

check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli --help exits 0" kiro-cli --help

reportResults
