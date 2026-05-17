#!/bin/bash
set -e
source dev-container-features-test-lib

check "just is on PATH" which just
check "just --help exits 0" just --help
check "just-lsp is on PATH" which just-lsp
check "bashrc has just completions" grep -q 'just --completions' "${HOME}/.bashrc"

reportResults
