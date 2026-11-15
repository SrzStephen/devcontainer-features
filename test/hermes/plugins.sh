#!/bin/bash
set -e
source dev-container-features-test-lib

check "plugin listed" bash -c "hermes plugins list | grep -q snyk"
check "plugin enabled" bash -c "hermes plugins show snyk | grep -q 'Status: enabled'"
check "plugin dir exists" test -d ~/.hermes/plugins/snyk

reportResults
