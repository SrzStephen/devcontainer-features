#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "claude --help exits 0" claude --help
check "settings.json has permissions.defaultMode=plan" \
    jq -e '.permissions.defaultMode == "plan"' /root/.claude/settings.json

reportResults
