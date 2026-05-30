#!/bin/bash
set -e
source dev-container-features-test-lib

check "not running as root" bash -c "[ \"$(id -u)\" != '0' ]"
check "bash-language-server is on PATH" which bash-language-server
check "bash-language-server --version exits 0" bash-language-server --version
check "shellcheck is on PATH" which shellcheck
check "shfmt is on PATH" which shfmt

reportResults
