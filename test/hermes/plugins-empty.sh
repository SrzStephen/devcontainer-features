#!/bin/bash
set -e
source dev-container-features-test-lib

check "no snyk plugin dir" bash -c '! ls ~/.hermes/plugins/snyk'
check "snyk not listed" bash -c '! hermes plugins list | grep -q snyk'

reportResults
