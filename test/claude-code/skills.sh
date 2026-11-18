#!/bin/bash
set -e
source dev-container-features-test-lib

check "npm present" which npm
check "skills CLI present" which skills
check "skill installed" test -n "$(ls ~/.claude/skills 2>/dev/null)"

reportResults
