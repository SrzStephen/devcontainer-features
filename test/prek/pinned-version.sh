#!/bin/bash
set -e
source dev-container-features-test-lib

check "prek is on PATH" which prek
check "prek --version exits 0" prek --version

reportResults
