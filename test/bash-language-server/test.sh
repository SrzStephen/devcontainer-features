#!/bin/bash
set -e
source dev-container-features-test-lib

check "bash-language-server is on PATH" which bash-language-server
check "bash-language-server --version exits 0" bash-language-server --version
check "shellcheck is on PATH" which shellcheck

reportResults
