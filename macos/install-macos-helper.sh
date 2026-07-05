#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_DIR="$PROJECT_DIR/bridge"
PROVISIONING_FILE="$PROJECT_DIR/provisioning/fedora-touchid-pam.env"
APP_SUPPORT="$HOME/Library/Application Support/FedoraTouchIDPAM"
BIN="$APP_SUPPORT/fedora-touchid-helper"
CONFIG="$APP_SUPPORT/config.env"
PLIST="$HOME/Library/LaunchAgents/com.fedora-touchid-pam.helper.plist"

if [[ ! -f "$PROVISIONING_FILE" ]]; then
  echo "Missing provisioning file: $PROVISIONING_FILE" >&2
  echo "Run fedora/install-fedora-sudo.sh inside Fedora first." >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc is missing. Install Xcode Command Line Tools first:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PROVISIONING_FILE"

mkdir -p "$APP_SUPPORT" "$HOME/Library/LaunchAgents" "$BRIDGE_DIR/requests" "$BRIDGE_DIR/responses" "$BRIDGE_DIR/processed" "$BRIDGE_DIR/state"
swiftc "$PROJECT_DIR/macos/FedoraTouchIDHelper.swift" \
  -framework Foundation \
  -framework LocalAuthentication \
  -framework CryptoKit \
  -o "$BIN"
chmod 0700 "$BIN"

cat > "$CONFIG" <<EOF
BRIDGE_DIR=$BRIDGE_DIR
SECRET_HEX=$SECRET_HEX
ALLOWED_USERS=${ALLOWED_USERS:-}
POLL_INTERVAL_SECONDS=0.5
EOF
chmod 0600 "$CONFIG"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.fedora-touchid-pam.helper</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>$CONFIG</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$APP_SUPPORT/helper.log</string>
  <key>StandardErrorPath</key>
  <string>$APP_SUPPORT/helper.err</string>
</dict>
</plist>
EOF
chmod 0644 "$PLIST"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.fedora-touchid-pam.helper"

rm -f "$PROVISIONING_FILE"

echo "macOS Touch ID helper installed and started."
echo "Bridge: $BRIDGE_DIR"
echo "Logs:"
echo "  $APP_SUPPORT/helper.log"
echo "  $APP_SUPPORT/helper.err"
