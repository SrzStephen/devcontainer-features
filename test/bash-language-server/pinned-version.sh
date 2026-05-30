#!/bin/bash
set -e
source dev-container-features-test-lib

check "bash-language-server is on PATH" which bash-language-server
check "bash-language-server --version exits 0" bash-language-server --version
check "bash-language-server version is 4.10.1" bash -c "bash-language-server --version | grep -q '4.10.1'"

reportResults
