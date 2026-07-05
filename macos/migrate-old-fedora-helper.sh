#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_PLIST="$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist"
OLD_SUPPORT="$HOME/Library/Application Support/FedoraTouchIDPAM"
NEW_LABEL="com.parallels-touchid-pam.helper"

"$PROJECT_DIR/macos/install-macos-helper.sh"

launchctl bootout "gui/$(id -u)" "$OLD_PLIST" >/dev/null 2>&1 || true
rm -f "$OLD_PLIST"
rm -rf "$OLD_SUPPORT"

echo
echo "Old Fedora-only helper removed."
echo "New generic helper status:"
launchctl print "gui/$(id -u)/$NEW_LABEL" | sed -n '1,40p'
echo
"$PROJECT_DIR/macos/list-vms.sh"
