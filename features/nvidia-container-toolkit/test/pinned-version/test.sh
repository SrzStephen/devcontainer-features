#!/bin/bash
set -e
source dev-container-features-test-lib

check "nvidia-ctk is on PATH" which nvidia-ctk
check "nvidia-ctk --help exits 0" nvidia-ctk --help
check "nvidia-ctk version is 1.17.8" bash -c "nvidia-ctk --version | grep -q '1\.17\.8'"

reportResults
