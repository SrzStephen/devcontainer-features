#!/bin/bash
# Run the installer again with a plugin that is not in the catalog: it must
# fail with a clear message.
set -e
source dev-container-features-test-lib

INSTALL_SH="$(find / -path '*/hermes/install.sh' -not -path '/proc/*' 2>/dev/null | head -1)"

rc=0
sudo env PLUGINS='no-such-plugin-zzz' bash "${INSTALL_SH}" >/tmp/plugins-missing.log 2>&1 || rc=$?

check "install.sh found" test -n "${INSTALL_SH}"
check "install.sh exits non-zero" test "${rc}" -ne 0
check "clear error printed" grep -q "failed to install Hermes plugin: no-such-plugin-zzz" /tmp/plugins-missing.log

reportResults
