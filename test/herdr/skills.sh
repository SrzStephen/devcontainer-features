#!/bin/bash
set -e
source dev-container-features-test-lib

check "npx present" which npx
check "claude skills installed" test -n "$(ls ~/.claude/skills 2>/dev/null)"

reportResults
