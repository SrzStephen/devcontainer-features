#!/bin/bash
set -e
source dev-container-features-test-lib

check "nvidia-ctk is on PATH" which nvidia-ctk
check "nvidia-ctk --help exits 0" nvidia-ctk --help

reportResults
