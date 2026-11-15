#!/bin/bash
set -e
source dev-container-features-test-lib

check "npx present" which npx
check "skill installed" test -n "$(ls ~/.kiro/skills 2>/dev/null)"

reportResults
