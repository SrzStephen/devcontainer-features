#!/bin/bash
set -e
source dev-container-features-test-lib

check "plugin listed" bash -c "herdr plugin list | grep -q examples.dev-layout-bootstrap"
check "plugin enabled" bash -c "herdr plugin list | grep examples.dev-layout-bootstrap | grep -q enabled"

reportResults
