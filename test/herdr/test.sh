#!/bin/bash
set -e
source dev-container-features-test-lib

check "herdr on PATH" which herdr
check "herdr help" herdr --help

reportResults
