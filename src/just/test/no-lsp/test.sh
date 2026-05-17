#!/bin/bash
set -e
source dev-container-features-test-lib

check "just is on PATH" which just
check "just --help exits 0" just --help
check "just-lsp is not installed" bash -c "! which just-lsp"

reportResults
