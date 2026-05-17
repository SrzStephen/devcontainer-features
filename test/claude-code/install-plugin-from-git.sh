#!/bin/bash
set -e
source dev-container-features-test-lib

check "claude is on PATH" which claude
check "claude --help exits 0" claude --help
check "superpowers marketplace registered" \
    test -d "${HOME}/.claude/plugins/marketplaces/superpowers-marketplace"
check "superpowers plugin cached" \
    test -d "${HOME}/.claude/plugins/cache/superpowers-marketplace/superpowers"
check "superpowers plugin recorded in installed_plugins.json" \
    jq -e '.plugins["superpowers@superpowers-marketplace"]' \
    "${HOME}/.claude/plugins/installed_plugins.json"

reportResults
