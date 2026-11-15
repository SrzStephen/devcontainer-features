#!/bin/bash
set -e
source dev-container-features-test-lib

check "greeting disabled by default" bash -c "kiro-cli settings chat.greeting.enabled | grep -q 'false'"
check "settings file exists" test -f ~/.kiro/settings/cli.json
check "defaultModel untouched" bash -c "! grep -qs 'defaultModel' ~/.kiro/settings/cli.json"
check "agentEngine untouched" bash -c "! grep -qs 'agentEngine' ~/.kiro/settings/cli.json"

reportResults
