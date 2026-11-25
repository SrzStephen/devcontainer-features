#!/bin/bash
set -e
source dev-container-features-test-lib

check "no plugins installed" bash -c "herdr plugin list | grep -q 'No plugins installed'"

reportResults
