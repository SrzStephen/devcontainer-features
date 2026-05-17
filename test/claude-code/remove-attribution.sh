#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "claude --help exits 0" claude --help
check "settings.json exists" test -f "${HOME}/.claude/settings.json"
check "attribution.commit is empty string" \
    jq -e '.attribution.commit == ""' "${HOME}/.claude/settings.json"
check "attribution.pr is empty string" \
    jq -e '.attribution.pr == ""' "${HOME}/.claude/settings.json"

reportResults
