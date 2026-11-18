#!/bin/bash
set -e
source dev-container-features-test-lib

check "defaultModel applied" bash -c "kiro-cli settings chat.defaultModel | grep -q 'claude-sonnet-4.6'"
check "agentEngine applied" bash -c "kiro-cli settings chat.agentEngine | grep -q 'v3'"
check "greeting disabled" bash -c "kiro-cli settings chat.greeting.enabled | grep -q 'false'"

reportResults
