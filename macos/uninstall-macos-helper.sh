#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/FedoraTouchIDPAM"
PLIST="$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

echo "macOS Touch ID helper LaunchAgent removed."
echo "Helper files remain at:"
echo "  $APP_SUPPORT"
