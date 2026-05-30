#!/bin/bash
set -e
source dev-container-features-test-lib

check "kiro-cli is on PATH" which kiro-cli
check "kiro-cli --help exits 0" kiro-cli --help
check "autoupdates setting is disabled" bash -c 'kiro-cli settings "app.disableAutoupdates" 2>/dev/null | grep -qi "true"'

reportResults
