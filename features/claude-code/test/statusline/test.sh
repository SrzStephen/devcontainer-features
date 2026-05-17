#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "claude --help exits 0" claude --help
check "statusline script installed" test -f /root/.claude/statusline-command.sh
check "settings.json has statusLine.type=command" \
    jq -e '.statusLine.type == "command"' /root/.claude/settings.json

reportResults
