#!/bin/bash
set -e
source dev-container-features-test-lib

check "no npx" bash -c '! command -v npx'
check "no vercel skill" test ! -e ~/.hermes/skills/web-design-guidelines

reportResults
