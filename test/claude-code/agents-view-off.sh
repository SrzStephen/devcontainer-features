#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "settings.json has defaultToAgentsView=false" \
    jq -e '.defaultToAgentsView == false' /root/.claude/settings.json

reportResults
