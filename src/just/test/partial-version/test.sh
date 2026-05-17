#!/bin/bash
set -e
source dev-container-features-test-lib

check "just is on PATH" which just
check "just --help exits 0" just --help
check "just version starts with 1" bash -c "just --version | grep -q '^just 1\.'"
check "just-lsp is on PATH" which just-lsp
check "just-lsp --help exits 0" just-lsp --help

reportResults
