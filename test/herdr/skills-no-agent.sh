#!/bin/bash
# skills is set but skillsAgent is empty: the build succeeds (herdr is there)
# and no Node was installed; re-running the installer logs the warning.
set -e
source dev-container-features-test-lib

check "herdr installed" which herdr
check "no npx" bash -c '! command -v npx'
check "warning emitted when re-run" bash -c 'out="$(sudo env SKILLS=x/y bash "$(find / -path "*/herdr/install.sh" -not -path "/proc/*" 2>/dev/null | head -1)" 2>&1)"; echo "$out" | grep -q "skillsAgent is empty"'
check "still no npx after re-run" bash -c '! command -v npx'

reportResults
