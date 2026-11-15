#!/bin/bash
# A failing build cannot be expressed as a scenario, so run the installer
# directly with a hostile SKILLS value and assert it is refused.
set -e
source dev-container-features-test-lib

INSTALL_SH="$(find / -path '*/kiro-cli/install.sh' -not -path '/proc/*' 2>/dev/null | head -1)"

rm -f /tmp/pwned
rc=0
SKILLS='a;touch /tmp/pwned' bash "${INSTALL_SH}" >/tmp/skills-invalid.log 2>&1 || rc=$?

check "install.sh found" test -n "${INSTALL_SH}"
check "install.sh exits non-zero" test "${rc}" -ne 0
check "error message printed" grep -q "unsafe" /tmp/skills-invalid.log
check "no injected file" test ! -e /tmp/pwned

# An entry starting with a dash would be parsed as an option by the skills CLI.
rc=0
SKILLS='--help' bash "${INSTALL_SH}" >/tmp/skills-invalid-dash.log 2>&1 || rc=$?
check "dash entry exits non-zero" test "${rc}" -ne 0
check "dash entry error printed" grep -q "start with a dash" /tmp/skills-invalid-dash.log

reportResults
