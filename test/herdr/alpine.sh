#!/bin/bash
set -e
source dev-container-features-test-lib

check "herdr on PATH" which herdr
check "herdr help" herdr --help
check "herdr under user home" test -x "${HOME}/.local/bin/herdr"

reportResults
