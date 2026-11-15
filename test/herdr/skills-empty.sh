#!/bin/bash
set -e
source dev-container-features-test-lib

check "no npx" bash -c '! command -v npx'

reportResults
