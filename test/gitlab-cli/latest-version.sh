#!/bin/bash
set -e
source dev-container-features-test-lib

check "glab is on PATH" which glab
check "glab --version exits 0" glab --version

reportResults
