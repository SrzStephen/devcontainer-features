#!/bin/bash
set -e
source dev-container-features-test-lib

check "running as non-root" test "$(id -u)" -ne 0
check "skill installed in user home" test -n "$(ls "${HOME}/.kiro/skills" 2>/dev/null)"
check "skills owned by user" test "$(stat -c %U "${HOME}/.kiro/skills")" = "$(id -un)"

reportResults
