#!/bin/bash
set -e
source dev-container-features-test-lib

check "act is on PATH" which act
check "act --version exits 0" act --version

reportResults
