#!/bin/bash
set -e
source dev-container-features-test-lib

check "agentcore is on PATH" which agentcore
check "agentcore --help exits 0" agentcore --help

reportResults
