#!/bin/bash
set -e
source dev-container-features-test-lib

check "sam is on PATH" which sam
check "sam --version exits 0" sam --version

reportResults
