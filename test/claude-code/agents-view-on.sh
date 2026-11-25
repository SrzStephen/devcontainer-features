#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "settings.json has defaultToAgentsView=true" \
    jq -e '.defaultToAgentsView == true' /root/.claude/settings.json

reportResults
