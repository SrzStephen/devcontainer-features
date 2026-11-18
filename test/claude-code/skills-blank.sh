#!/bin/bash
set -e
source dev-container-features-test-lib

check "no npx" bash -c '! command -v npx'
check "no skills dir" test -z "$(ls ~/.claude/skills 2>/dev/null)"

reportResults
